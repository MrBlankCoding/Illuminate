#include "CefHostWindow.h"
#include "CefPopupWindow.h"
#include "../utils/BrowserLogger.h"

#include <QtGlobal>
#include <QCoreApplication>
#include <QMetaObject>

#include <include/cef_task.h>
#include <include/base/cef_callback.h>
#include <include/wrapper/cef_closure_task.h>
#include <include/views/cef_view.h>

#include <utility>

#ifdef __APPLE__
void cefSetChildWindowGeometry(void *parentView, void *childHandle, const QRect &rect, bool visible); // CefBrowserWrapper_mac.mm
#endif

CefHostWindow::CefHostWindow(const CefRect &bounds, std::function<void()> ready)
    : m_bounds(bounds), m_ready(std::move(ready))
{
}

void CefHostWindow::create(CefRefPtr<CefClient> client,
                           const CefString &url,
                           const CefBrowserSettings &settings,
                           CefRefPtr<CefDictionaryValue> extraInfo,
                           CefRefPtr<CefRequestContext> requestContext)
{
    BrowserLogger::instance().debug("Diag", QString("CefHostWindow::create onUI=%1 url=%2")
        .arg(CefCurrentlyOn(TID_UI) ? "yes" : "no", QString::fromStdString(url.ToString())));
    if (!CefCurrentlyOn(TID_UI))
    {
        CefRefPtr<CefHostWindow> self(this);
        CefPostTask(TID_UI, CefCreateClosureTask(base::BindOnce(
            &CefHostWindow::create, self, client, url, settings, extraInfo, requestContext)));
        return;
    }

    m_browserView = CefBrowserView::CreateBrowserView(client, url, settings, extraInfo, requestContext, this);
    if (!m_browserView) {
        BrowserLogger::instance().error("CEF", "Could not create browser view for host window");
        return;
    }
    CefWindow::CreateTopLevelWindow(this);
}

void CefHostWindow::OnWindowCreated(CefRefPtr<CefWindow> window)
{
    BrowserLogger::instance().debug("Diag", QString("CefHostWindow::OnWindowCreated closing=%1 hasView=%2")
        .arg(m_closing ? "yes" : "no", m_browserView ? "yes" : "no"));
    if (!window || !m_browserView) {
        BrowserLogger::instance().error("CEF", "Host window was created without a browser view");
        return;
    }
    m_window = window;
    m_nativeHandle.store(window->GetWindowHandle(), std::memory_order_release);
    // its tab went away while the window was still being made: don't leave
    // a page running in a window nobody owns
    if (m_closing)
    {
        BrowserLogger::instance().debug("Diag", "CefHostWindow::OnWindowCreated closing early");
        window->Close();
        return;
    }
    CefBoxLayoutSettings layoutSettings;
    layoutSettings.horizontal = false;
    m_windowLayout = window->SetToBoxLayout(layoutSettings);
    window->AddChildView(m_browserView);
    m_windowLayout->SetFlexForView(m_browserView, 1);
    if (m_ready)
    {
        auto callback = std::exchange(m_ready, nullptr);
        if (QCoreApplication::instance())
        {
            QMetaObject::invokeMethod(QCoreApplication::instance(), [callback]() { callback(); }, Qt::QueuedConnection);
        }
        else
        {
            callback();
        }
    }
}

void CefHostWindow::OnWindowChanged(CefRefPtr<CefView> view, bool added)
{
    if (!added || view != m_browserView || !m_window || m_chromeToolbar)
        return;

    m_chromeToolbar = m_browserView->GetChromeToolbar();
    if (!m_chromeToolbar) {
        BrowserLogger::instance().error("CEF", "Chrome toolbar was unavailable for browser view");
        return;
    }

    m_window->AddChildViewAt(m_chromeToolbar, 0);
    // Chrome toolbar sizing is finalized when the window is laid out. Without
    // this pass the toolbar can remain at zero height in an embedded window.
    m_window->Layout();
}

// popups the page opened with window.open() get a window of their own
CefRefPtr<CefBrowserViewDelegate> CefHostWindow::GetDelegateForPopupBrowserView(
    CefRefPtr<CefBrowserView> browserView,
    const CefBrowserSettings &settings,
    CefRefPtr<CefClient> client,
    bool isDevtools)
{
    Q_UNUSED(settings);
    Q_UNUSED(client);
    if (isDevtools)
        return this;
    return CefPopupWindow::delegateFor(browserView, m_bounds);
}

bool CefHostWindow::OnPopupBrowserViewCreated(CefRefPtr<CefBrowserView> browserView,
                                              CefRefPtr<CefBrowserView> popupBrowserView,
                                              bool isDevtools)
{
    Q_UNUSED(browserView);
    return !isDevtools && CefPopupWindow::open(popupBrowserView);
}

void CefHostWindow::OnWindowDestroyed(CefRefPtr<CefWindow> window)
{
    BrowserLogger::instance().debug("Diag", "CefHostWindow::OnWindowDestroyed");
    Q_UNUSED(window);
    m_nativeHandle.store(nullptr, std::memory_order_release);
    m_browserView = nullptr;
    m_chromeToolbar = nullptr;
    m_windowLayout = nullptr;
    m_window = nullptr;
}

void CefHostWindow::setBounds(const CefRect &bounds, void *parentView, const QRect &geometry, bool visible)
{
    BrowserLogger::instance().debug("Diag", QString("CefHostWindow::setBounds onUI=%1 bounds=%2,%3 %4x%5 visible=%6 hasWindow=%7")
        .arg(CefCurrentlyOn(TID_UI)?"yes":"no").arg(bounds.x).arg(bounds.y).arg(bounds.width).arg(bounds.height).arg(visible?"yes":"no", m_window?"yes":"no"));
    if (!CefCurrentlyOn(TID_UI))
    {
        CefRefPtr<CefHostWindow> self(this);
        CefPostTask(TID_UI, CefCreateClosureTask(base::BindOnce(
            &CefHostWindow::setBounds, self, bounds, parentView, geometry, visible)));
        return;
    }

    const bool boundsChanged = m_bounds.x != bounds.x || m_bounds.y != bounds.y
        || m_bounds.width != bounds.width || m_bounds.height != bounds.height;
    if (boundsChanged)
    {
        m_bounds = bounds;
        if (m_window)
            m_window->SetBounds(bounds);
    }
#ifdef __APPLE__
    if (m_window && parentView)
        cefSetChildWindowGeometry(parentView, m_window->GetWindowHandle(), geometry, visible);
#else
    Q_UNUSED(parentView);
    Q_UNUSED(geometry);
    Q_UNUSED(visible);
#endif
}

void CefHostWindow::setVisible(bool visible)
{
    BrowserLogger::instance().debug("Diag", QString("CefHostWindow::setVisible onUI=%1 visible=%2 hasWindow=%3")
        .arg(CefCurrentlyOn(TID_UI)?"yes":"no", visible?"yes":"no", m_window?"yes":"no"));
    if (!CefCurrentlyOn(TID_UI))
    {
        CefRefPtr<CefHostWindow> self(this);
        CefPostTask(TID_UI, CefCreateClosureTask(base::BindOnce(
            &CefHostWindow::setVisible, self, visible)));
        return;
    }

    if (!m_window || visible == m_visible)
        return;
    m_visible = visible;
    if (visible)
    {
        m_window->Show();
    }
    else
    {
        CefRefPtr<CefHostWindow> self(this);
        CefPostDelayedTask(TID_UI, CefCreateClosureTask(base::BindOnce(
            [](CefRefPtr<CefHostWindow> host) {
                if (!host->m_closing && !host->m_visible && host->m_window)
                    host->m_window->Hide();
            }, self)), 50);
    }
}

void CefHostWindow::restore(std::function<void()> afterRestore)
{
    if (!CefCurrentlyOn(TID_UI))
    {
        CefRefPtr<CefHostWindow> self(this);
        CefPostTask(TID_UI, CefCreateClosureTask(base::BindOnce(
            &CefHostWindow::restore, self, std::move(afterRestore))));
        return;
    }

    if (!m_window || m_closing)
        return;
    m_visible = true;
    m_window->Show();

    // CEF may process Show() on its UI thread while the Qt/NSWindow ordering
    // work must run on the application thread. Queue the callback only after
    // Show() has executed so callers can safely raise the restored native
    // window without racing the asynchronous CEF task.
    if (afterRestore)
    {
        if (QCoreApplication *app = QCoreApplication::instance())
            QMetaObject::invokeMethod(app, [callback = std::move(afterRestore)]() { callback(); },
                                      Qt::QueuedConnection);
        else
            afterRestore();
    }
}

void CefHostWindow::close()
{
    if (!CefCurrentlyOn(TID_UI))
    {
        CefRefPtr<CefHostWindow> self(this);
        CefPostTask(TID_UI, CefCreateClosureTask(base::BindOnce(&CefHostWindow::close, self)));
        return;
    }

    m_closing = true;
    m_ready = nullptr;
    if (m_window)
        m_window->Close();
}

void *CefHostWindow::nativeHandle() const
{
    return reinterpret_cast<void *>(m_nativeHandle.load(std::memory_order_acquire));
}
