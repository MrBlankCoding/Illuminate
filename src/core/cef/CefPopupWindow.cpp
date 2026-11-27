#include "CefPopupWindow.h"
#include "../utils/BrowserLogger.h"

#include <include/cef_task.h>

#include <QtGlobal>

#include <algorithm>
#include <map>
#include <optional>
#include <vector>

namespace
{
constexpr int kDefaultWidth = 500;
constexpr int kDefaultHeight = 640;
constexpr int kMinWidth = 320;
constexpr int kMinHeight = 240;

struct PendingPopup
{
    CefPopupFeatures features{};
    bool hidden = false;
};

// UI thread only: CEF calls OnBeforePopup, then creates the popup's view
std::map<int, PendingPopup> &pendingFeatures()
{
    static std::map<int, PendingPopup> features;
    return features;
}

// delegates handed out for popup views that have not been put in a window yet
std::vector<CefRefPtr<CefPopupWindow>> &pendingPopups()
{
    static std::vector<CefRefPtr<CefPopupWindow>> popups;
    return popups;
}
}

CefRect CefPopupWindow::boundsFor(const CefPopupFeatures *features, const CefRect &anchor)
{
    int width = kDefaultWidth;
    int height = kDefaultHeight;
    if (features && features->widthSet)
        width = std::max(features->width, kMinWidth);
    if (features && features->heightSet)
        height = std::max(features->height, kMinHeight);

    int x = anchor.x + (anchor.width - width) / 2;
    int y = anchor.y + (anchor.height - height) / 2;
    if (features && features->xSet)
        x = features->x;
    if (features && features->ySet)
        y = features->y;
    return CefRect(x, y, width, height);
}

void CefPopupWindow::rememberFeatures(int openerBrowserId, const CefPopupFeatures &features)
{
    pendingFeatures()[openerBrowserId] = {features, false};
}

void CefPopupWindow::rememberHiddenTab(int openerBrowserId)
{
    pendingFeatures()[openerBrowserId] = {CefPopupFeatures{}, true};
}

void CefPopupWindow::forgetFeatures(int openerBrowserId)
{
    pendingFeatures().erase(openerBrowserId);
}

CefRefPtr<CefBrowserViewDelegate> CefPopupWindow::delegateFor(CefRefPtr<CefBrowserView> opener,
                                                              const CefRect &anchor)
{
    std::optional<PendingPopup> pending;
    if (CefRefPtr<CefBrowser> browser = opener ? opener->GetBrowser() : nullptr)
    {
        auto &all = pendingFeatures();
        if (auto it = all.find(browser->GetIdentifier()); it != all.end())
        {
            pending = it->second;
            all.erase(it);
        }
    }

    const bool hidden = pending && pending->hidden;
    const CefPopupFeatures *features = pending && !hidden ? &pending->features : nullptr;
    CefRefPtr<CefPopupWindow> popup = new CefPopupWindow(boundsFor(features, anchor), hidden);
    pendingPopups().push_back(popup);
    return popup;
}

bool CefPopupWindow::open(CefRefPtr<CefBrowserView> popupView)
{
    auto &pending = pendingPopups();
    auto it = std::find_if(pending.begin(), pending.end(), [&](const CefRefPtr<CefPopupWindow> &popup) {
        return popup->m_browserView && popup->m_browserView->IsSame(popupView);
    });
    if (it == pending.end())
        return false;

    CefRefPtr<CefPopupWindow> popup = *it;
    pending.erase(it);
    CefWindow::CreateTopLevelWindow(popup);
    return true;
}

void CefPopupWindow::OnBrowserCreated(CefRefPtr<CefBrowserView> browserView, CefRefPtr<CefBrowser> browser)
{
    Q_UNUSED(browser);
    if (!m_browserView)
        m_browserView = browserView;
}

void CefPopupWindow::OnWindowChanged(CefRefPtr<CefView> view, bool added)
{
    if (!added || !m_browserView || !view->IsSame(m_browserView) || !m_window || m_toolbar)
        return;

    // a location bar, so the person can see where they are signing in
    m_toolbar = m_browserView->GetChromeToolbar();
    if (!m_toolbar)
        return;
    m_window->AddChildViewAt(m_toolbar, 0);
    m_window->Layout();
}

CefRefPtr<CefBrowserViewDelegate> CefPopupWindow::GetDelegateForPopupBrowserView(
    CefRefPtr<CefBrowserView> browserView,
    const CefBrowserSettings &settings,
    CefRefPtr<CefClient> client,
    bool isDevtools)
{
    Q_UNUSED(settings);
    Q_UNUSED(client);
    if (isDevtools)
        return this;
    return delegateFor(browserView, m_window ? m_window->GetBounds() : m_bounds);
}

bool CefPopupWindow::OnPopupBrowserViewCreated(CefRefPtr<CefBrowserView> browserView,
                                               CefRefPtr<CefBrowserView> popupBrowserView,
                                               bool isDevtools)
{
    Q_UNUSED(browserView);
    return !isDevtools && open(popupBrowserView);
}

void CefPopupWindow::OnWindowCreated(CefRefPtr<CefWindow> window)
{
    m_window = window;
    if (!m_browserView)
    {
        BrowserLogger::instance().error("CEF", "Popup window was created without a browser view");
        return;
    }

    CefBoxLayoutSettings layoutSettings;
    layoutSettings.horizontal = false;
    CefRefPtr<CefBoxLayout> layout = window->SetToBoxLayout(layoutSettings);
    window->AddChildView(m_browserView);
    layout->SetFlexForView(m_browserView, 1);
    if (m_hidden)
        return;
    window->Show();
    m_browserView->RequestFocus();
}

void CefPopupWindow::OnWindowDestroyed(CefRefPtr<CefWindow> window)
{
    Q_UNUSED(window);
    m_toolbar = nullptr;
    m_browserView = nullptr;
    m_window = nullptr;
}

// let the page run its unload handlers first; CEF asks again once it is done
bool CefPopupWindow::CanClose(CefRefPtr<CefWindow> window)
{
    Q_UNUSED(window);
    CefRefPtr<CefBrowser> browser = m_browserView ? m_browserView->GetBrowser() : nullptr;
    return !browser || browser->GetHost()->TryCloseBrowser();
}
