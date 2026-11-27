#pragma once

#include <include/cef_client.h>
#include <include/cef_display_handler.h>
#include <include/cef_life_span_handler.h>

#include <QSet>
#include <QMutex>

class CefStrayBrowserClient : public CefClient,
                              public CefLifeSpanHandler,
                              public CefDisplayHandler
{
public:
    CefRefPtr<CefLifeSpanHandler> GetLifeSpanHandler() override { return this; }
    CefRefPtr<CefDisplayHandler> GetDisplayHandler() override { return this; }

    void OnAfterCreated(CefRefPtr<CefBrowser> browser) override;
    void OnBeforeClose(CefRefPtr<CefBrowser> browser) override;
    void OnAddressChange(CefRefPtr<CefBrowser> browser,
                         CefRefPtr<CefFrame> frame,
                         const CefString &url) override;

private:
    // hands the page to our UI once, then closes the Chrome window
    void adopt(CefRefPtr<CefBrowser> browser, const QString &url);

    QMutex m_mutex;
    QSet<int> m_adopted;

    IMPLEMENT_REFCOUNTING(CefStrayBrowserClient);
};
