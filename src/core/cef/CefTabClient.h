#pragma once

#include <include/cef_client.h>
#include <include/cef_command_handler.h>
#include <include/cef_focus_handler.h>
#include <include/cef_jsdialog_handler.h>
#include <include/cef_keyboard_handler.h>
#include <include/cef_life_span_handler.h>
#include <QPointer>

#include "CefMainBrowserId.h"

class CefBrowserWrapper;
class CefLoadHandlerImpl;
class CefDisplayHandlerImpl;
class CefContextMenuHandlerImpl;
class CefDownloadHandlerImpl;
class CefPermissionHandlerImpl;
class CefRequestHandlerImpl;

class CefTabClient : public CefClient,
                     public CefLifeSpanHandler,
                     public CefKeyboardHandler,
                     public CefFocusHandler,
                     public CefCommandHandler,
                     public CefJSDialogHandler
{
public:
    explicit CefTabClient(CefBrowserWrapper *wrapper);
    ~CefTabClient() override = default;

    // CefClient overrides
    CefRefPtr<CefLifeSpanHandler> GetLifeSpanHandler() override { return this; }
    CefRefPtr<CefKeyboardHandler> GetKeyboardHandler() override { return this; }
    CefRefPtr<CefFocusHandler> GetFocusHandler() override { return this; }
    CefRefPtr<CefCommandHandler> GetCommandHandler() override { return this; }
    CefRefPtr<CefJSDialogHandler> GetJSDialogHandler() override { return this; }
    CefRefPtr<CefLoadHandler> GetLoadHandler() override;
    CefRefPtr<CefDisplayHandler> GetDisplayHandler() override;
    CefRefPtr<CefContextMenuHandler> GetContextMenuHandler() override;
    CefRefPtr<CefDownloadHandler> GetDownloadHandler() override;
    CefRefPtr<CefPermissionHandler> GetPermissionHandler() override;
    CefRefPtr<CefRequestHandler> GetRequestHandler() override;
    bool OnProcessMessageReceived(CefRefPtr<CefBrowser> browser,
                                  CefRefPtr<CefFrame> frame,
                                  CefProcessId source_process,
                                  CefRefPtr<CefProcessMessage> message) override;

    // CefLifeSpanHandler overrides
    bool OnBeforePopup(CefRefPtr<CefBrowser> browser,
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
                       bool *no_javascript_access) override;

    void OnBeforePopupAborted(CefRefPtr<CefBrowser> browser, int popup_id) override;
    void OnAfterCreated(CefRefPtr<CefBrowser> browser) override;
    bool DoClose(CefRefPtr<CefBrowser> browser) override;
    void OnBeforeClose(CefRefPtr<CefBrowser> browser) override;

    // CefKeyboardHandler overrides
    bool OnPreKeyEvent(CefRefPtr<CefBrowser> browser,
                       const CefKeyEvent &event,
                       CefEventHandle os_event,
                       bool *is_keyboard_shortcut) override;

    // CefFocusHandler overrides
    bool OnSetFocus(CefRefPtr<CefBrowser> browser, FocusSource source) override;
    void OnGotFocus(CefRefPtr<CefBrowser> browser) override;
    bool OnBeforeUnloadDialog(CefRefPtr<CefBrowser> browser,
                              const CefString &message_text,
                              bool is_reload,
                              CefRefPtr<CefJSDialogCallback> callback) override;
    void OnResetDialogState(CefRefPtr<CefBrowser> browser) override;

    // CefCommandHandler overrides (Chrome style only)
    bool OnChromeCommand(CefRefPtr<CefBrowser> browser,
                         int command_id,
                         cef_window_open_disposition_t disposition) override;

    void retarget(CefBrowserWrapper *wrapper);

    bool isMainBrowser(const CefRefPtr<CefBrowser> &browser) const
    {
        return m_mainBrowser.matches(browser);
    }

private:
    QPointer<CefBrowserWrapper> m_wrapper;
    CefMainBrowserId m_mainBrowser;

    CefRefPtr<CefLoadHandlerImpl> m_loadHandler;
    CefRefPtr<CefDisplayHandlerImpl> m_displayHandler;
    CefRefPtr<CefContextMenuHandlerImpl> m_contextMenuHandler;
    CefRefPtr<CefDownloadHandlerImpl> m_downloadHandler;
    CefRefPtr<CefPermissionHandlerImpl> m_permissionHandler;
    CefRefPtr<CefRequestHandlerImpl> m_requestHandler;

    IMPLEMENT_REFCOUNTING(CefTabClient);
};
