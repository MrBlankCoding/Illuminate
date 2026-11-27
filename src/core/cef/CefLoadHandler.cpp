#include "CefLoadHandler.h"
#include "CefBrowserWrapper.h"
#include "../utils/cef_helpers.h"
#include "../utils/BrowserLogger.h"

#include <QFile>
#include <QMetaObject>

namespace {

CefString pageInitScript()
{
    return qStringToCef(QStringLiteral("delete Navigator.prototype.gpu;"));
}

} // namespace

CefLoadHandlerImpl::CefLoadHandlerImpl(CefBrowserWrapper *wrapper, CefMainBrowserId *mainBrowser)
    : m_wrapper(wrapper), m_mainBrowser(mainBrowser)
{
}

void CefLoadHandlerImpl::OnLoadingStateChange(CefRefPtr<CefBrowser> browser,
                                              bool isLoading,
                                              bool canGoBack,
                                              bool canGoForward)
{
    if (!m_wrapper || !m_mainBrowser || !m_mainBrowser->matches(browser))
        return;

    QMetaObject::invokeMethod(m_wrapper, [wrapper = m_wrapper, isLoading, canGoBack, canGoForward]() {
        if (wrapper)
            wrapper->onLoadingStateChanged(isLoading, canGoBack, canGoForward);
    }, Qt::QueuedConnection);
}

void CefLoadHandlerImpl::OnLoadStart(CefRefPtr<CefBrowser> browser,
                                     CefRefPtr<CefFrame> frame,
                                     TransitionType transition_type)
{
    Q_UNUSED(transition_type);
    if (!m_wrapper || !m_mainBrowser || !m_mainBrowser->matches(browser) || !frame->IsMain())
        return;

    const QString url = cefStringToQString(frame->GetURL());
    frame->ExecuteJavaScript(pageInitScript(), frame->GetURL(), 0);

    QMetaObject::invokeMethod(m_wrapper, [wrapper = m_wrapper, url]() {
        if (wrapper)
            wrapper->onUrlChanged(url);
    }, Qt::QueuedConnection);
}

void CefLoadHandlerImpl::OnLoadEnd(CefRefPtr<CefBrowser> browser,
                                   CefRefPtr<CefFrame> frame,
                                   int httpStatusCode)
{
    Q_UNUSED(httpStatusCode);
    if (!m_wrapper || !m_mainBrowser || !m_mainBrowser->matches(browser) || !frame->IsMain())
        return;

    QMetaObject::invokeMethod(m_wrapper, [wrapper = m_wrapper]() {
        if (wrapper)
            wrapper->onLoadProgressChanged(100);
    }, Qt::QueuedConnection);
}

void CefLoadHandlerImpl::OnLoadError(CefRefPtr<CefBrowser> browser,
                                     CefRefPtr<CefFrame> frame,
                                     ErrorCode errorCode,
                                     const CefString &errorText,
                                     const CefString &failedUrl)
{
    Q_UNUSED(browser);
    if (!frame->IsMain())
        return;

    BrowserLogger::instance().warning("CEF", QString("Load error %1: %2 (%3)")
        .arg(QString::number(errorCode), cefStringToQString(errorText), cefStringToQString(failedUrl)));
}

void CefLoadHandlerImpl::setWrapper(CefBrowserWrapper *wrapper)
{
    m_wrapper = wrapper;
}
