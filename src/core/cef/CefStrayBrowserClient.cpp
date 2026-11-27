#include "CefStrayBrowserClient.h"
#include "CefManager.h"
#include "../menus/AppMenu.h"
#include "../utils/cef_helpers.h"
#include "../utils/BrowserLogger.h"

#include <QCoreApplication>
#include <QMetaObject>
#include <QMutexLocker>
#include <QUrl>

#ifdef __APPLE__
void cefHideNativeWindow(void *view); // CefManager_mac.mm
#elif defined(_WIN32)
#include <windows.h>
static void cefHideNativeWindow(cef_window_handle_t hwnd)
{
    if (HWND root = hwnd ? GetAncestor(hwnd, GA_ROOT) : nullptr)
        ShowWindow(root, SW_HIDE);
}
#else
static void cefHideNativeWindow(cef_window_handle_t) {}
#endif

namespace
{
// nothing worth a tab yet: the window is still on its way somewhere
bool isPending(const QString &url)
{
    return url.isEmpty() || url == QLatin1String("about:blank");
}
}

void CefStrayBrowserClient::OnAfterCreated(CefRefPtr<CefBrowser> browser)
{
    CefManager::instance().browserCreated(browser);
    if (auto host = browser->GetHost())
        cefHideNativeWindow(host->GetWindowHandle());

    const QString url = cefStringToQString(browser->GetMainFrame()->GetURL());
    if (!isPending(url))
        adopt(browser, url);
}

void CefStrayBrowserClient::OnBeforeClose(CefRefPtr<CefBrowser> browser)
{
    CefManager::instance().browserClosed(browser);
    QMutexLocker lock(&m_mutex);
    m_adopted.remove(browser->GetIdentifier());
}

void CefStrayBrowserClient::OnAddressChange(CefRefPtr<CefBrowser> browser,
                                            CefRefPtr<CefFrame> frame,
                                            const CefString &url)
{
    const QString address = cefStringToQString(url);
    if (frame->IsMain() && !isPending(address))
        adopt(browser, address);
}

void CefStrayBrowserClient::adopt(CefRefPtr<CefBrowser> browser, const QString &url)
{
    {
        QMutexLocker lock(&m_mutex);
        if (m_adopted.contains(browser->GetIdentifier()))
            return;
        m_adopted.insert(browser->GetIdentifier());
    }

    QString destination = url;
    const QUrl parsedUrl(url);
    const QString scheme = parsedUrl.scheme().toLower();
    const QString host = parsedUrl.host().toLower();
    if (scheme == QLatin1String("chrome")
        && (host == QLatin1String("newtab") || host == QLatin1String("new-tab-page")))
    {
        // An empty tab.open payload uses BrowserController::newTab()'s normal
        // new-tab path, which opens the app's command bar. Passing the internal
        // newtab:// URL explicitly creates the page without that interaction.
        destination.clear();
        BrowserLogger::instance().debug("CEF", "Routing Chromium's new-tab page to the app new-tab flow");
    }

    BrowserLogger::instance().info("CEF", "Chrome opened a window of its own; moving it to a tab: " + url);
    QMetaObject::invokeMethod(QCoreApplication::instance(), [destination]() {
        if (AppMenu *menu = AppMenu::instance())
            menu->trigger(QStringLiteral("tab.open"), destination);
    }, Qt::QueuedConnection);

    QMetaObject::invokeMethod(QCoreApplication::instance(), [browser]() {
        if (auto host = browser->GetHost())
            host->CloseBrowser(true);
    }, Qt::QueuedConnection);
}
