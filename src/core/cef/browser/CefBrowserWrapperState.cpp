#include "browser/CefBrowserWrapperPrivate.h"

using namespace CefBrowserWrapperPrivate;

void CefBrowserWrapper::onUrlChanged(const QString &url)
{
    const QUrl newUrl(url);
    if (m_url != newUrl)
    {
        m_url = newUrl;
        emit urlChanged();
    }
}

void CefBrowserWrapper::onTitleChanged(const QString &title)
{
    if (m_title != title)
    {
        m_title = title;
        emit titleChanged();
    }
}

void CefBrowserWrapper::onIconChanged(const QString &iconUrl)
{
    const QUrl newIcon(iconUrl);
    if (m_icon != newIcon)
    {
        m_icon = newIcon;
        emit iconChanged();
    }
}

void CefBrowserWrapper::onLoadingStateChanged(bool isLoading, bool canGoBack, bool canGoForward)
{
    BrowserLogger::instance().debug("Diag", QString("CefBrowserWrapper::onLoadingStateChanged loading=%1 canBack=%2 canFwd=%3 url=%4")
        .arg(isLoading?"1":"0", canGoBack?"1":"0", canGoForward?"1":"0", m_url.toString()));
    if (!isLoading)
        m_hasLoadedOnce = true;
    if (m_loading != isLoading)
    {
        m_loading = isLoading;
        emit loadingChanged();
        updateNativeGeometry();
    }
    if (m_hasLoadedOnce)
        updateNativeGeometry();
    if (m_canGoBack != canGoBack)
    {
        m_canGoBack = canGoBack;
        emit canGoBackChanged();
    }
    if (m_canGoForward != canGoForward)
    {
        m_canGoForward = canGoForward;
        emit canGoForwardChanged();
    }
}

void CefBrowserWrapper::onLoadProgressChanged(int progress)
{
    if (m_loadProgress != progress)
    {
        m_loadProgress = progress;
        emit loadProgressChanged(progress);
    }
}

void CefBrowserWrapper::onPdfPrintFinished(const QString &path, bool ok)
{
    emit pdfPrintingFinished(path, ok);
}
