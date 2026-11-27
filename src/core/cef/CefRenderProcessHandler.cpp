#include "CefRenderProcessHandler.h"
#include "ExtensionPopupProtocol.h"
#include "PageMediaProtocol.h"

#include <include/cef_process_message.h>
#include <include/cef_v8.h>

#include <string>
#include <string_view>

namespace
{

constexpr char kBridgeScript[] = R"JS((function (tabId, post, minWidth, minHeight, maxWidth, maxHeight) {
  'use strict';

  const WINDOW_ID_CURRENT = -2;
  const hasTab = tabId > 0;
  let patched = false;
  let target = null;

  function split(args) {
    const last = args[args.length - 1];
    return typeof last === 'function' ? [args.slice(0, -1), last] : [args, null];
  }

  // callback form works for every manifest version
  function call(fn, ...args) {
    return new Promise((resolve, reject) => {
      fn(...args, result => {
        const error = chrome.runtime && chrome.runtime.lastError;
        if (error)
          reject(new Error(error.message));
        else
          resolve(result);
      });
    });
  }

  function reply(promise, callback) {
    if (!callback)
      return promise;
    promise.then(result => callback(result), () => callback());
  }

  function wrap(api, name, makeWrapper) {
    const original = api && api[name];
    if (typeof original !== 'function')
      return;
    try {
      Object.defineProperty(api, name, {
        value: makeWrapper(original.bind(api)),
        configurable: true, enumerable: true, writable: true
      });
    } catch (e) {}
  }

  function patchApis() {
    if (patched)
      return true;
    const tabs = globalThis.chrome && chrome.tabs;
    if (!tabs || typeof tabs.query !== 'function')
      return false;
    patched = true;

    const getTab = tabs.get.bind(tabs);
    const targetTab = () => target || (target = hasTab ? call(getTab, tabId) : Promise.resolve(null));
    const inCurrentWindow = info => !!info && (info.currentWindow === true
      || info.lastFocusedWindow === true || info.windowId === WINDOW_ID_CURRENT);

    wrap(tabs, 'query', query => function (...rawArgs) {
      const [args, callback] = split(rawArgs);
      if (!inCurrentWindow(args[0]))
        return query(...rawArgs);
      return reply(targetTab().then(tab => {
        if (!tab)
          return [];
        const scoped = Object.assign({}, args[0], { windowId: tab.windowId });
        delete scoped.currentWindow;
        delete scoped.lastFocusedWindow;
        return call(query, scoped);
      }), callback);
    });

    // a popup is not a tab
    wrap(tabs, 'getCurrent', () => function (...rawArgs) {
      return reply(Promise.resolve(undefined), split(rawArgs)[1]);
    });

    // the tab these default to is the current window's active one
    for (const name of ['update', 'reload', 'goBack', 'goForward', 'detectLanguage',
                        'getZoom', 'getZoomSettings', 'executeScript', 'insertCSS', 'removeCSS']) {
      wrap(tabs, name, original => function (...args) {
        return hasTab && typeof args[0] !== 'number' ? original(tabId, ...args) : original(...args);
      });
    }

    wrap(tabs, 'captureVisibleTab', capture => function (...rawArgs) {
      if (!hasTab || typeof rawArgs[0] === 'number')
        return capture(...rawArgs);
      const [args, callback] = split(rawArgs);
      return reply(targetTab().then(tab => call(capture, tab.windowId, ...args)), callback);
    });

    const windows = chrome.windows;
    if (hasTab && windows && typeof windows.get === 'function') {
      const getWindow = windows.get.bind(windows);
      for (const name of ['getCurrent', 'getLastFocused']) {
        wrap(windows, name, () => function (...rawArgs) {
          const [args, callback] = split(rawArgs);
          return reply(targetTab().then(tab => call(getWindow, tab.windowId, ...args)), callback);
        });
      }
    }
    return true;
  }

  // the extension bindings normally exist by now; if not, before the body
  if (!patchApis())
    document.addEventListener('readystatechange', patchApis, { once: true });

  // Chrome closes the popup for both
  window.close = () => post('close');
  window.addEventListener('keydown', event => {
    if (event.key === 'Escape' && !event.defaultPrevented)
      post('close');
  });

  // Chrome lays a popup out at its preferred size: the document's max-content
  // width, and its height at that width. Measure the same, letting percentage
  // heights fall back to auto so a 100% tall page doesn't just echo our size.
  let reported = '';
  let mutations = null;
  let queued = false;

  function intrinsic(styles, property) {
    const value = styles && styles.get(property);
    return !value || value.unit === 'percent'
      || (typeof CSSKeywordValue !== 'undefined' && value instanceof CSSKeywordValue);
  }

  function measure() {
    const root = document.documentElement;
    if (!root)
      return;
    const saved = root.getAttribute('style');
    const styles = root.computedStyleMap ? root.computedStyleMap() : null;
    if (intrinsic(styles, 'width')) {
      root.style.setProperty('width', 'max-content', 'important');
      root.style.setProperty('max-width', maxWidth + 'px', 'important');
    }
    if (intrinsic(styles, 'height'))
      root.style.setProperty('height', 'auto', 'important');
    const rect = root.getBoundingClientRect();
    // what overflows the root (positioned menus, wide rows) is part of the
    // size too, as in Chrome. This never reads below the current viewport,
    // which starts tiny, so the popup grows to fit but won't shrink back.
    const overflowWidth = root.scrollWidth;
    const overflowHeight = root.scrollHeight;
    if (saved === null)
      root.removeAttribute('style');
    else
      root.setAttribute('style', saved);
    if (mutations)
      mutations.takeRecords();

    const width = Math.min(maxWidth, Math.max(minWidth, Math.ceil(Math.max(rect.width, overflowWidth))));
    const height = Math.min(maxHeight, Math.max(minHeight, Math.ceil(Math.max(rect.height, overflowHeight))));
    if (width + 'x' + height !== reported) {
      reported = width + 'x' + height;
      post('resize', width, height);
    }
  }

  // microtasks and load events still run while the popup is hidden;
  // timers and resize observers wait for it to show
  function remeasure() {
    if (queued)
      return;
    queued = true;
    queueMicrotask(() => {
      queued = false;
      measure();
    });
  }

  document.addEventListener('DOMContentLoaded', () => {
    measure();
    mutations = new MutationObserver(remeasure);
    mutations.observe(document.documentElement,
      { attributes: true, childList: true, characterData: true, subtree: true });
    const resizes = new ResizeObserver(remeasure);
    resizes.observe(document.documentElement);
    if (document.body)
      resizes.observe(document.body);
    if (document.fonts)
      document.fonts.ready.then(remeasure);
  }, { once: true });
  window.addEventListener('load', remeasure);
  // images and stylesheets change the size without touching the DOM
  document.addEventListener('load', remeasure, true);
}))JS";

constexpr std::string_view kExtensionScheme = "chrome-extension://";
constexpr char kMediaScript[] = R"JS((function (post) {
  'use strict';
  const known = new Set();
  let reported = false;
  let timer = 0;

  // buffering counts as playing: the player will carry on by itself
  function audible(media) {
    return !media.paused && !media.ended && !media.muted && media.volume > 0;
  }

  function check() {
    timer = 0;
    let now = false;
    for (const media of known) {
      if (audible(media)) {
        now = true;
      } else if (!media.isConnected && (media.paused || media.ended)) {
        known.delete(media);
      }
    }
    if (now !== reported) {
      reported = now;
      post(now);
    }
  }

  function schedule() {
    if (!timer)
      timer = setTimeout(check, 150);
  }

  const events = ['play', 'playing', 'pause', 'ended', 'volumechange', 'emptied', 'waiting'];
  function track(media) {
    if (!(media instanceof HTMLMediaElement) || known.has(media))
      return;
    known.add(media);
    // listening on the element itself also covers players never put in the page
    for (const type of events)
      media.addEventListener(type, schedule);
  }

  // media events don't bubble, but the capture phase still passes the document
  for (const type of events)
    document.addEventListener(type, event => { track(event.target); schedule(); }, true);

  // new Audio().play() never enters the document
  const proto = HTMLMediaElement.prototype;
  const play = proto.play;
  Object.defineProperty(proto, 'play', {
    configurable: true, enumerable: true, writable: true,
    value: { play() { track(this); schedule(); return play.apply(this, arguments); } }.play
  });

  window.addEventListener('pagehide', () => {
    if (reported) {
      reported = false;
      post(false);
    }
  });
}))JS";

// post(audible): the media watcher reporting its frame's state
class MediaPostHandler final : public CefV8Handler
{
public:
    bool Execute(const CefString &name,
                 CefRefPtr<CefV8Value> object,
                 const CefV8ValueList &arguments,
                 CefRefPtr<CefV8Value> &retval,
                 CefString &exception) override
    {
        CefRefPtr<CefV8Context> context = CefV8Context::GetCurrentContext();
        CefRefPtr<CefFrame> frame = context ? context->GetFrame() : nullptr;
        if (!frame || arguments.empty())
            return true;
        CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create(PageMediaProtocol::kMessage);
        message->GetArgumentList()->SetBool(0, arguments[0]->IsBool() && arguments[0]->GetBoolValue());
        frame->SendProcessMessage(PID_BROWSER, message);
        return true;
    }

private:
    IMPLEMENT_REFCOUNTING(MediaPostHandler);
};

bool isWebPage(const std::string &url)
{
    return url.rfind("https://", 0) == 0 || url.rfind("http://", 0) == 0 || url.rfind("file://", 0) == 0;
}

void installMediaWatcher(CefRefPtr<CefV8Context> context)
{
    CefRefPtr<CefV8Value> install;
    CefRefPtr<CefV8Exception> exception;
    if (!context->Eval(kMediaScript, "illuminate://media-watcher.js", 1, install, exception)
        || !install || !install->IsFunction())
        return;
    install->ExecuteFunctionWithContext(context, nullptr, {
        CefV8Value::CreateFunction("post", new MediaPostHandler()),
    });
}

// post(kind, ...ints): forwards to the browser process
class PostHandler final : public CefV8Handler
{
public:
    bool Execute(const CefString &name,
                 CefRefPtr<CefV8Value> object,
                 const CefV8ValueList &arguments,
                 CefRefPtr<CefV8Value> &retval,
                 CefString &exception) override
    {
        if (arguments.empty() || !arguments[0]->IsString())
            return true;
        CefRefPtr<CefV8Context> context = CefV8Context::GetCurrentContext();
        CefRefPtr<CefFrame> frame = context ? context->GetFrame() : nullptr;
        if (!frame || !frame->IsMain())
            return true;

        CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create(ExtensionPopupProtocol::kMessage);
        CefRefPtr<CefListValue> args = message->GetArgumentList();
        args->SetString(0, arguments[0]->GetStringValue());
        for (size_t i = 1; i < arguments.size() && i < 3; ++i)
        {
            const CefRefPtr<CefV8Value> &value = arguments[i];
            args->SetInt(i, value->IsInt() ? value->GetIntValue() : static_cast<int>(value->GetDoubleValue()));
        }
        frame->SendProcessMessage(PID_BROWSER, message);
        return true;
    }

private:
    IMPLEMENT_REFCOUNTING(PostHandler);
};

} // namespace

void CefRenderProcessHandlerImpl::OnBrowserCreated(CefRefPtr<CefBrowser> browser,
                                                   CefRefPtr<CefDictionaryValue> extra_info)
{
    if (extra_info && extra_info->HasKey(ExtensionPopupProtocol::kTabIdKey))
        m_actionTabs[browser->GetIdentifier()] = extra_info->GetInt(ExtensionPopupProtocol::kTabIdKey);
}

void CefRenderProcessHandlerImpl::OnBrowserDestroyed(CefRefPtr<CefBrowser> browser)
{
    m_actionTabs.erase(browser->GetIdentifier());
}

void CefRenderProcessHandlerImpl::OnContextCreated(CefRefPtr<CefBrowser> browser,
                                                   CefRefPtr<CefFrame> frame,
                                                   CefRefPtr<CefV8Context> context)
{
    // every web frame: an embedded player has sound as much as the page
    if (isWebPage(frame->GetURL().ToString()) && m_actionTabs.find(browser->GetIdentifier()) == m_actionTabs.end())
        installMediaWatcher(context);

    if (!frame->IsMain())
        return;
    const auto popup = m_actionTabs.find(browser->GetIdentifier());
    if (popup == m_actionTabs.end())
        return;
    // only the extension's own page gets the bridge, not wherever it navigates
    if (frame->GetURL().ToString().rfind(kExtensionScheme, 0) != 0)
        return;

    CefRefPtr<CefV8Value> install;
    CefRefPtr<CefV8Exception> exception;
    if (!context->Eval(kBridgeScript, "illuminate://action-popup-bridge.js", 1, install, exception)
        || !install || !install->IsFunction())
        return;

    install->ExecuteFunctionWithContext(context, nullptr, {
        CefV8Value::CreateInt(popup->second),
        CefV8Value::CreateFunction("post", new PostHandler()),
        CefV8Value::CreateInt(ExtensionPopupProtocol::kMinWidth),
        CefV8Value::CreateInt(ExtensionPopupProtocol::kMinHeight),
        CefV8Value::CreateInt(ExtensionPopupProtocol::kMaxWidth),
        CefV8Value::CreateInt(ExtensionPopupProtocol::kMaxHeight),
    });
}
