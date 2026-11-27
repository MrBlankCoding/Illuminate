#include "CefTabClient.h"
#include "CefManager.h"
#include "CefBrowserWrapper.h"
#include "CefLoadHandler.h"
#include "CefDisplayHandler.h"
#include "CefContextMenuHandler.h"
#include "CefDownloadHandler.h"
#include "CefPermissionHandler.h"
#include "CefRequestHandler.h"
#include "CefPopupWindow.h"
#include "BeforeUnloadRequest.h"
#include "CefChromeCommands.h"
#include "ExtensionPopupProtocol.h"
#include "PageMediaProtocol.h"
#include "../menus/AppMenu.h"

#include <QDebug>

#include <include/cef_command_ids.h>
#include <include/cef_task.h>
#include <include/base/cef_callback.h>
#include <include/wrapper/cef_closure_task.h>
#include "../utils/cef_helpers.h"
#include "../utils/ShortcutBridge.h"

#include <QCoreApplication>
#include <QMetaObject>
#include <QQuickWindow>

CefTabClient::CefTabClient(CefBrowserWrapper *wrapper)
    : m_wrapper(wrapper),
      m_loadHandler(new CefLoadHandlerImpl(wrapper, &m_mainBrowser)),
      m_displayHandler(new CefDisplayHandlerImpl(wrapper, &m_mainBrowser)),
      m_contextMenuHandler(new CefContextMenuHandlerImpl(wrapper, &m_mainBrowser)),
      m_downloadHandler(new CefDownloadHandlerImpl()),
      m_permissionHandler(new CefPermissionHandlerImpl(wrapper)),
      m_requestHandler(new CefRequestHandlerImpl(wrapper, &m_mainBrowser))
{
}

void CefTabClient::retarget(CefBrowserWrapper *wrapper)
{
    m_wrapper = wrapper;
    m_loadHandler->setWrapper(wrapper);
    m_displayHandler->setWrapper(wrapper);
    m_contextMenuHandler->setWrapper(wrapper);
    m_permissionHandler->setWrapper(wrapper);
    m_requestHandler->setWrapper(wrapper);
}

CefRefPtr<CefLoadHandler> CefTabClient::GetLoadHandler() { return m_loadHandler; }
CefRefPtr<CefDisplayHandler> CefTabClient::GetDisplayHandler() { return m_displayHandler; }
CefRefPtr<CefContextMenuHandler> CefTabClient::GetContextMenuHandler() { return m_contextMenuHandler; }
CefRefPtr<CefDownloadHandler> CefTabClient::GetDownloadHandler() { return m_downloadHandler; }
CefRefPtr<CefPermissionHandler> CefTabClient::GetPermissionHandler() { return m_permissionHandler; }
CefRefPtr<CefRequestHandler> CefTabClient::GetRequestHandler() { return m_requestHandler; }

// an action popup's page reporting its size or asking to close
bool CefTabClient::OnProcessMessageReceived(CefRefPtr<CefBrowser> browser,
                                            CefRefPtr<CefFrame> frame,
                                            CefProcessId source_process,
                                            CefRefPtr<CefProcessMessage> message)
{
    Q_UNUSED(source_process);
    // a frame of the page started or stopped playing sound
    if (message->GetName().ToString() == PageMediaProtocol::kMessage)
    {
        if (!isMainBrowser(browser) || !frame || !m_wrapper)
            return true;
        const QString frameId = cefStringToQString(frame->GetIdentifier());
        const bool audible = message->GetArgumentList()->GetBool(0);
        QMetaObject::invokeMethod(m_wrapper, [wrapper = m_wrapper, frameId, audible]() {
            if (wrapper)
                wrapper->onFrameAudible(frameId, audible);
        }, Qt::QueuedConnection);
        return true;
    }

    if (!isMainBrowser(browser) || !frame || !frame->IsMain() || !m_wrapper
        || message->GetName().ToString() != ExtensionPopupProtocol::kMessage)
        return false;

    CefRefPtr<CefListValue> args = message->GetArgumentList();
    const QString kind = cefStringToQString(args->GetString(0));
    const int width = args->GetSize() > 1 ? args->GetInt(1) : 0;
    const int height = args->GetSize() > 2 ? args->GetInt(2) : 0;
    QMetaObject::invokeMethod(m_wrapper, [wrapper = m_wrapper, kind, width, height]() {
        if (wrapper)
            wrapper->onActionPopupMessage(kind, width, height);
    }, Qt::QueuedConnection);
    return true;
}

bool CefTabClient::OnBeforePopup(CefRefPtr<CefBrowser> browser,
                                 CefRefPtr<CefFrame> frame,
                                 int popup_id,
                                 const CefString &target_url,
                                 const CefString &target_frame_name,
                                 WindowOpenDisposition target_disposition,
                                 bool user_gesture,
                                 const CefPopupFeatures &popupFeatures,
                                 CefWindowInfo &windowInfo,
                                 CefRefPtr<CefClient> &client,
                                 CefBrowserSettings &settings,
                                 CefRefPtr<CefDictionaryValue> &extra_info,
                                 bool *no_javascript_access)
{
    Q_UNUSED(frame);
    Q_UNUSED(popup_id);
    Q_UNUSED(target_frame_name);
    Q_UNUSED(user_gesture);
    Q_UNUSED(windowInfo);
    Q_UNUSED(settings);
    Q_UNUSED(extra_info);
    Q_UNUSED(no_javascript_access);

    const QUrl url = cefStringToQUrl(target_url);
    if (url.scheme().compare(QStringLiteral("chrome-extension"), Qt::CaseInsensitive) == 0)
    {
        return false;
    }

    // window.open() with features (OAuth sign-in like Google's, payment
    // flows): let CEF create a real popup. Reopening it as a tab would drop
    // window.opener, so the popup could never report back to the page.
    if (target_disposition == CEF_WOD_NEW_POPUP)
    {
        CefPopupWindow::rememberFeatures(browser->GetIdentifier(), popupFeatures);
        return false;
    }

    // window.open() of a blank tab the page fills in afterwards ("open in new
    // tab" once a link is ready). The page needs a real window to fill in, so
    // let CEF make one, hidden; the stray client moves the page into a tab as
    // soon as it goes somewhere.
    if (url.isEmpty() || url.toString() == QLatin1String("about:blank"))
    {
        CefPopupWindow::rememberHiddenTab(browser->GetIdentifier());
        client = CefManager::instance().GetDefaultClient();
        return false;
    }

    if (m_wrapper)
    {
        const bool background = target_disposition == CEF_WOD_NEW_BACKGROUND_TAB;
        QMetaObject::invokeMethod(m_wrapper, [wrapper = m_wrapper, url, background]() {
            if (wrapper)
                emit wrapper->newWindowRequested(url, background);
        }, Qt::QueuedConnection);
    }

    return true; // Cancel default CEF popup window
}

void CefTabClient::OnBeforePopupAborted(CefRefPtr<CefBrowser> browser, int popup_id)
{
    Q_UNUSED(popup_id);
    CefPopupWindow::forgetFeatures(browser->GetIdentifier());
}

void CefTabClient::OnAfterCreated(CefRefPtr<CefBrowser> browser)
{
    CefManager::instance().browserCreated(browser);

    if (!m_mainBrowser.claim(browser->GetIdentifier()))
    {
        return;
    }

    if (m_wrapper)
    {
        QMetaObject::invokeMethod(QCoreApplication::instance(), [wrapper = m_wrapper, browser]() {
            if (wrapper) {
                qDebug() << "[Diag] CefTabClient::OnAfterCreated delivering browser" << browser->GetIdentifier() << "to wrapper";
                wrapper->setBrowser(browser);
            } else if (auto host = browser->GetHost()) {
                qDebug() << "[Diag] CefTabClient::OnAfterCreated wrapper gone, closing browser" << browser->GetIdentifier();
                host->CloseBrowser(true);
            }
        }, Qt::QueuedConnection);
    }
    else if (auto host = browser->GetHost())
    {
        qDebug() << "[Diag] CefTabClient::OnAfterCreated no wrapper, closing browser" << browser->GetIdentifier();
        host->CloseBrowser(true);
    }
}

bool CefTabClient::DoClose(CefRefPtr<CefBrowser> browser)
{
    // Not where the tab learns its page is gone: Chrome style closes the page
    // through Chrome's tab strip and never calls this. OnBeforeClose, which
    // every close ends in, reports it instead.
    Q_UNUSED(browser);
    return false;
}

void CefTabClient::OnBeforeClose(CefRefPtr<CefBrowser> browser)
{
    CefManager::instance().browserClosed(browser);

    if (!m_mainBrowser.release(browser))
    {
        return;
    }

    if (m_wrapper)
    {
        QMetaObject::invokeMethod(m_wrapper, [wrapper = m_wrapper]() {
            if (wrapper)
                wrapper->onBrowserClosed();
        }, Qt::QueuedConnection);
    }
}

bool CefTabClient::OnBeforeUnloadDialog(CefRefPtr<CefBrowser> browser,
                                        const CefString &message_text,
                                        bool is_reload,
                                        CefRefPtr<CefJSDialogCallback> callback)
{
    Q_UNUSED(message_text); // Chromium no longer lets pages word it themselves
    if (!isMainBrowser(browser))
        return false; // popups keep Chromium's own dialog
    // Its tab is already gone (a space switch, the tab removed): the page is
    // being torn down on purpose. Asking now would put a dialog, and the page
    // behind it, over whatever the window shows next; let it go.
    if (!m_wrapper)
    {
        callback->Continue(true, CefString());
        return true;
    }

    QMetaObject::invokeMethod(m_wrapper, [wrapper = m_wrapper, is_reload, callback]() {
        // created here so it lives on the Qt thread; the callback hops back to CEF's
        auto *request = new BeforeUnloadRequest(is_reload, [callback](bool leave) {
            CefPostTask(TID_UI, base::BindOnce(
                [](CefRefPtr<CefJSDialogCallback> cb, bool ok) { cb->Continue(ok, CefString()); },
                callback, leave));
        });
        if (!wrapper)
        {
            delete request; // stays
            return;
        }
        wrapper->onBeforeUnloadRequested(request);
    }, Qt::QueuedConnection);
    return true;
}

void CefTabClient::OnResetDialogState(CefRefPtr<CefBrowser> browser)
{
    if (!isMainBrowser(browser) || !m_wrapper)
        return;
    QMetaObject::invokeMethod(m_wrapper, [wrapper = m_wrapper]() {
        if (wrapper)
            wrapper->dismissBeforeUnload();
    }, Qt::QueuedConnection);
}

bool CefTabClient::OnPreKeyEvent(CefRefPtr<CefBrowser> browser,
                                 const CefKeyEvent &event,
                                 CefEventHandle os_event,
                                 bool *is_keyboard_shortcut)
{
    Q_UNUSED(os_event);
    Q_UNUSED(is_keyboard_shortcut);

    if (!isMainBrowser(browser))
        return false;

    constexpr int kVkeyEscape = 0x1B;
    if (event.type == KEYEVENT_RAWKEYDOWN && event.windows_key_code == kVkeyEscape
        && browser->GetHost()->IsFullscreen())
    {
        browser->GetHost()->ExitFullscreen(true);
        return true;
    }

    if (event.type == KEYEVENT_RAWKEYDOWN && m_wrapper)
    {
        if (ShortcutBridge::dispatchKeyPress(m_wrapper->window(),
                                             event.windows_key_code,
                                             event.modifiers))
            return true;
    }

    return false;
}

bool CefTabClient::OnSetFocus(CefRefPtr<CefBrowser> browser, FocusSource source)
{
    if (!isMainBrowser(browser) || !m_wrapper || !m_wrapper->inputSuppressed())
        return false;

    // A direct click in the page is an explicit handoff back from Qt UI.
    // Let CEF take focus, then move Qt's logical focus to the CefBrowser item
    // so the shared QML focus state releases native input suppression.
    if (source == FOCUS_SOURCE_SYSTEM) {
        emit m_wrapper->nativeFocusRequested();
        return false;
    }
    return true;
}

void CefTabClient::OnGotFocus(CefRefPtr<CefBrowser> browser)
{
    if (isMainBrowser(browser) && m_wrapper)
        emit m_wrapper->nativeFocusRequested();
}

bool CefTabClient::OnChromeCommand(CefRefPtr<CefBrowser> browser,
                                   int command_id,
                                   cef_window_open_disposition_t disposition)
{
    Q_UNUSED(disposition);

    if (!isMainBrowser(browser))
        return false;

    ChromeCommandRoute route = routeChromeCommand(command_id);
    // Chrome would open it in a tab strip we don't have
    if (command_id == IDC_VIEW_SOURCE)
    {
        const QString url = QString::fromStdString(browser->GetMainFrame()->GetURL().ToString());
        route = {ChromeCommandRoute::Action, QStringLiteral("tab.open"), QStringLiteral("view-source:") + url};
    }

    switch (route.kind)
    {
    case ChromeCommandRoute::Chrome:
        return false;
    case ChromeCommandRoute::Blocked:
        return true;
    case ChromeCommandRoute::Action:
        QMetaObject::invokeMethod(QCoreApplication::instance(), [route]() {
            if (AppMenu *menu = AppMenu::instance())
                menu->trigger(route.action, route.payload);
        }, Qt::QueuedConnection);
        return true;
    }
    return false;
}
