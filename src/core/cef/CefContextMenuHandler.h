#pragma once

#include <include/cef_context_menu_handler.h>
#include <QPointer>

#include "CefMainBrowserId.h"

class CefBrowserWrapper;

class CefContextMenuHandlerImpl : public CefContextMenuHandler
{
public:
    explicit CefContextMenuHandlerImpl(CefBrowserWrapper *wrapper, CefMainBrowserId *mainBrowser);
    // the wrapper a live page moved to (CefBrowserWrapper::adoptPage)
    void setWrapper(CefBrowserWrapper *wrapper);

    // action popups get no menu; pages keep Chrome's own
    void OnBeforeContextMenu(CefRefPtr<CefBrowser> browser,
                             CefRefPtr<CefFrame> frame,
                             CefRefPtr<CefContextMenuParams> params,
                             CefRefPtr<CefMenuModel> model) override;

    // "Inspect" goes through showDevTools so it matches the toggle
    bool OnContextMenuCommand(CefRefPtr<CefBrowser> browser,
                              CefRefPtr<CefFrame> frame,
                              CefRefPtr<CefContextMenuParams> params,
                              int command_id,
                              EventFlags event_flags) override;

private:
    QPointer<CefBrowserWrapper> m_wrapper;
    // shared with the client to distinguish the main browser
    CefMainBrowserId *m_mainBrowser = nullptr;

    IMPLEMENT_REFCOUNTING(CefContextMenuHandlerImpl);
};
