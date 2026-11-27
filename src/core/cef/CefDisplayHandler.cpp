#include "CefDisplayHandler.h"
#include "CefBrowserWrapper.h"
#include "../utils/cef_helpers.h"
#include "../utils/BrowserLogger.h"

#include <QMetaObject>
#include <QUrl>

namespace
{

    // fall back to globe on sites with no favicon
    bool isDecodableUrl(const QString &url)
    {
        if (url.isEmpty())
            return false;

        if (url.startsWith(QLatin1String("data:"), Qt::CaseInsensitive))
        {
            const qsizetype comma = url.indexOf(QLatin1Char(','));
            return comma >= 0 && comma < url.size() - 1;
        }

        const QUrl parsed(url);
        if (!parsed.isValid())
            return false;

        const QString scheme = parsed.scheme().toLower();
        return scheme == QLatin1String("http") ||
               scheme == QLatin1String("https") ||
               scheme == QLatin1String("qrc") ||
               scheme == QLatin1String("file");
    }
}

CefDisplayHandlerImpl::CefDisplayHandlerImpl(CefBrowserWrapper *wrapper, CefMainBrowserId *mainBrowser)
    : m_wrapper(wrapper), m_mainBrowser(mainBrowser)
{
}

void CefDisplayHandlerImpl::OnTitleChange(CefRefPtr<CefBrowser> browser, const CefString &title)
{
    if (!m_wrapper || !m_mainBrowser || !m_mainBrowser->matches(browser))
        return;

    const QString t = cefStringToQString(title);
    QMetaObject::invokeMethod(m_wrapper, [wrapper = m_wrapper, t]()
                              {
        if (wrapper)
            wrapper->onTitleChanged(t); }, Qt::QueuedConnection);
}

void CefDisplayHandlerImpl::OnFaviconURLChange(CefRefPtr<CefBrowser> browser,
                                               const std::vector<CefString> &icon_urls)
{
    if (!m_wrapper || !m_mainBrowser || !m_mainBrowser->matches(browser))
        return;

    // Prefer first decodable URL; CEF may list unsupported candidates first.
    QString iconUrl;
    for (const CefString &candidate : icon_urls)
    {
        const QString url = cefStringToQString(candidate);
        if (!isDecodableUrl(url))
            continue;
        iconUrl = url;
        break;
    }

    // nothing usable: an empty URL clears any favicon the tab had before
    QMetaObject::invokeMethod(m_wrapper, [wrapper = m_wrapper, iconUrl]()
                              {
        if (wrapper)
            wrapper->onIconChanged(iconUrl); }, Qt::QueuedConnection);
}

void CefDisplayHandlerImpl::OnLoadingProgressChange(CefRefPtr<CefBrowser> browser, double progress)
{
    if (!m_wrapper || !m_mainBrowser || !m_mainBrowser->matches(browser))
        return;

    const int p = static_cast<int>(progress * 100);
    QMetaObject::invokeMethod(m_wrapper, [wrapper = m_wrapper, p]()
                              {
        if (wrapper)
            wrapper->onLoadProgressChanged(p); }, Qt::QueuedConnection);
}

void CefDisplayHandlerImpl::OnFullscreenModeChange(CefRefPtr<CefBrowser> browser, bool fullscreen)
{
    if (!m_wrapper || !m_mainBrowser || !m_mainBrowser->matches(browser))
        return;

    QMetaObject::invokeMethod(m_wrapper, [wrapper = m_wrapper, fullscreen]()
                              {
        if (wrapper)
            wrapper->onFullscreenModeChanged(fullscreen); }, Qt::QueuedConnection);
}

bool CefDisplayHandlerImpl::OnConsoleMessage(CefRefPtr<CefBrowser> browser,
                                             cef_log_severity_t level,
                                             const CefString &message,
                                             const CefString &source,
                                             int line)
{
    if (!m_wrapper || !m_mainBrowser || !m_mainBrowser->matches(browser))
        return false;

    const QString msg = cefStringToQString(message);
    const QString src = cefStringToQString(source);

    QMetaObject::invokeMethod(m_wrapper, [wrapper = m_wrapper, level, msg, src, line]()
                              {
        if (wrapper)
            emit wrapper->javaScriptConsoleMessage(static_cast<int>(level), msg, line, src); }, Qt::QueuedConnection);

    return false;
}

void CefDisplayHandlerImpl::setWrapper(CefBrowserWrapper *wrapper)
{
    m_wrapper = wrapper;
}
