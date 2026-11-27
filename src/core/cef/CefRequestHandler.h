#pragma once

#include <include/cef_request_handler.h>
#include <QHash>
#include <QPointer>

class CefBrowserWrapper;
class CefMainBrowserId;

class CefRequestHandlerImpl : public CefRequestHandler
{
public:
    CefRequestHandlerImpl(CefBrowserWrapper *wrapper, const CefMainBrowserId *mainBrowser);
    // the wrapper a live page moved to (CefBrowserWrapper::adoptPage)
    void setWrapper(CefBrowserWrapper *wrapper);
    static constexpr qint64 kCrashLoopWindowMs = 60 * 1000;
    // where a crashed page goes, carrying the address to reload
    static QUrl crashPageFor(const QString &pageUrl);

    bool OnBeforeBrowse(CefRefPtr<CefBrowser> browser,
                        CefRefPtr<CefFrame> frame,
                        CefRefPtr<CefRequest> request,
                        bool user_gesture,
                        bool is_redirect) override;

    bool OnOpenURLFromTab(CefRefPtr<CefBrowser> browser,
                          CefRefPtr<CefFrame> frame,
                          const CefString &target_url,
                          WindowOpenDisposition target_disposition,
                          bool user_gesture) override;

    bool OnCertificateError(CefRefPtr<CefBrowser> browser,
                            cef_errorcode_t cert_error,
                            const CefString &request_url,
                            CefRefPtr<CefSSLInfo> ssl_info,
                            CefRefPtr<CefCallback> callback) override;

    void OnRenderProcessTerminated(CefRefPtr<CefBrowser> browser,
                                   TerminationStatus status,
                                   int error_code,
                                   const CefString &error_string) override;

private:
    QPointer<CefBrowserWrapper> m_wrapper;
    const CefMainBrowserId *m_mainBrowser;
    // CEF UI thread only: browser id -> when it was last reloaded after a crash
    QHash<int, qint64> m_lastCrashReload;

    IMPLEMENT_REFCOUNTING(CefRequestHandlerImpl);
};
