#pragma once

#include <include/cef_render_process_handler.h>

#include <map>

// Renderer side of extension action popups. A popup is an ordinary browser of
// its own here, not one hanging off the page like in Chrome, so this gives the
// popup's page that page's context back and reports its size and closing.
// Runs in the helper processes: no Qt.
class CefRenderProcessHandlerImpl : public CefRenderProcessHandler
{
public:
    void OnBrowserCreated(CefRefPtr<CefBrowser> browser,
                          CefRefPtr<CefDictionaryValue> extra_info) override;
    void OnBrowserDestroyed(CefRefPtr<CefBrowser> browser) override;
    void OnContextCreated(CefRefPtr<CefBrowser> browser,
                          CefRefPtr<CefFrame> frame,
                          CefRefPtr<CefV8Context> context) override;

private:
    // popup browser id -> the tab it acts on; renderer main thread only
    std::map<int, int> m_actionTabs;

    IMPLEMENT_REFCOUNTING(CefRenderProcessHandlerImpl);
};
