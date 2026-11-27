#include "browser/CefBrowserWrapperPrivate.h"

#include <include/cef_task.h>

#include <functional>
#include <memory>

using namespace CefBrowserWrapperPrivate;

namespace {
class ClosureTask final : public CefTask
{
public:
    explicit ClosureTask(std::function<void()> callback) : m_callback(std::move(callback)) {}
    void Execute() override { m_callback(); }
private:
    std::function<void()> m_callback;
    IMPLEMENT_REFCOUNTING(ClosureTask);
};
}

void CefBrowserWrapper::setBrowser(CefRefPtr<CefBrowser> browser)
{
    BrowserLogger::instance().debug("Diag", QString("CefBrowserWrapper::setBrowser id=%1 hostWindow=%2 url=%3")
        .arg(browser ? browser->GetIdentifier() : 0).arg(m_hostWindow?"yes":"no", m_url.toString()));
    m_browser = browser;
    m_creatingBrowser = false;
    if (m_browser)
        m_hasLoadedOnce = false;
    if (const int id = browser ? browser->GetIdentifier() : 0; id != m_browserId)
    {
        m_browserId = id;
        emit browserIdChanged();
    }
    if (!m_hostWindow)
    {
        m_nativeRect = QRect();
        m_nativeVisible = false;
        m_nativeCornerRadius = 0;
    }

    if (!m_browser)
    {
        clearAudible();
        onFullscreenModeChanged(false);
        if (std::exchange(m_recreateWhenClosed, false))
            QTimer::singleShot(0, this, &CefBrowserWrapper::recreateBrowser);
        return;
    }

    updateNativeGeometry();
    if (m_inputSuppressed)
        applyInputSuppression();
    if (m_lifecycleState != Active)
        notifyWindowRenderingHidden(true);
    if (!qFuzzyCompare(m_zoomFactor, 1.0))
        applyZoom(m_browser, m_zoomFactor);
    // a page brought back keeps the tab's mute
    if (m_audioMuted)
        m_browser->GetHost()->SetAudioMuted(true);

    m_renderProcessPid = 0;
    emit renderProcessPidChanged(m_renderProcessPid);

    if (!m_url.isEmpty() && m_url != m_createdUrl)
    {
        if (auto frame = m_browser->GetMainFrame())
            frame->LoadURL(qUrlToCefString(m_url));
    }
}

void CefBrowserWrapper::createBrowser(void *nativeWindowHandle, const QRect &geometry)
{
    BrowserLogger::instance().debug("Diag", QString("CefBrowserWrapper::createBrowser url=%1 native=%2 geom=%3x%4 chrome=%5")
        .arg(m_url.toString()).arg(nativeWindowHandle ? "yes":"no").arg(geometry.width()).arg(geometry.height()).arg(CefManager::chromeStyle()?"yes":"no"));
    if (m_browser || m_creatingBrowser || m_hostWindow) {
        BrowserLogger::instance().debug("Diag", QString("CefBrowserWrapper::createBrowser skipped browser=%1 creating=%2 host=%3")
            .arg(m_browser?"yes":"no", m_creatingBrowser?"yes":"no", m_hostWindow?"yes":"no"));
        return;
    }

    m_creatingBrowser = true;

    CefWindowInfo windowInfo;
    setAsChild(windowInfo, nativeWindowHandle, toNativeRect(geometry, window()));
    // Chrome style still embeds in our window: no Chrome toolbar or tab strip
    if (CefManager::chromeStyle())
        windowInfo.runtime_style = CEF_RUNTIME_STYLE_CHROME;

    CefBrowserSettings settings;
    if (m_backgroundColor.isValid())
        settings.background_color = m_backgroundColor.rgba();

    // what the renderer needs to know before the page's first script runs
    CefRefPtr<CefDictionaryValue> extraInfo;
    if (m_actionTabId != 0)
    {
        extraInfo = CefDictionaryValue::Create();
        extraInfo->SetInt(ExtensionPopupProtocol::kTabIdKey, m_actionTabId);
    }

    if (CefManager::chromeStyle())
    {
        createHostWindow(settings, extraInfo);
        return;
    }

    m_createdUrl = m_url;
    const CefString initialUrl = m_url.isEmpty() ? CefString() : qUrlToCefString(m_url);
    QPointer<CefBrowserWrapper> guard(this);
    CefRefPtr<CefClient> client = m_client;
    CefProfile *profile = m_profile;
    CefPostTask(TID_UI, new ClosureTask(
        [guard, client, profile, windowInfo, initialUrl, settings, extraInfo]() {
            if (!guard)
                return;
            CefProfile *resolvedProfile = profile ? profile : CefManager::defaultProfile();
            const auto requestContext = resolvedProfile ? resolvedProfile->requestContext() : nullptr;
            if (!requestContext) {
                QMetaObject::invokeMethod(guard.data(), [guard]() {
                    if (!guard)
                        return;
                    guard->m_creatingBrowser = false;
                    BrowserLogger::instance().error("CEF", "Could not create request context for browser tab");
                }, Qt::QueuedConnection);
                return;
            }
            if (!CefBrowserHost::CreateBrowser(windowInfo, client, initialUrl, settings, extraInfo, requestContext))
            {
                QMetaObject::invokeMethod(guard.data(), [guard]() {
                    if (!guard)
                        return;
                    guard->m_creatingBrowser = false;
                    qWarning() << "[CEF] CreateBrowser failed for" << guard->m_url;
                }, Qt::QueuedConnection);
            }
        }));
}

void CefBrowserWrapper::createHostWindow(const CefBrowserSettings &settings,
                                         CefRefPtr<CefDictionaryValue> extraInfo)
{
    m_createdUrl = m_url;
    const QRect screen = toNativeRect(screenRect(), window());
    const QRect native = toNativeRect(sceneRect(), window());
#ifdef __APPLE__
    const QRect hostBounds = screen;
#else
    const QRect hostBounds = native;
#endif
    QPointer<CefBrowserWrapper> guard = this;
    m_hostWindow = new CefHostWindow(CefRect(hostBounds.x(), hostBounds.y(), hostBounds.width(), hostBounds.height()),
                                     [guard]() {
                                         if (guard)
                                             guard->onHostWindowReady();
                                     });
    CefRefPtr<CefHostWindow> hostWindow = m_hostWindow;
    CefRefPtr<CefClient> client = m_client;
    CefProfile *profile = m_profile;
    const CefString initialUrl = m_url.isEmpty() ? CefString() : qUrlToCefString(m_url);
    CefPostTask(TID_UI, new ClosureTask(
        [guard, hostWindow, client, profile, initialUrl, settings, extraInfo]() {
            CefProfile *resolvedProfile = profile ? profile : CefManager::defaultProfile();
            const auto requestContext = resolvedProfile ? resolvedProfile->requestContext() : nullptr;
            if (!requestContext) {
                QMetaObject::invokeMethod(guard.data(), [guard]() {
                    if (!guard)
                        return;
                    guard->m_creatingBrowser = false;
                    BrowserLogger::instance().error("CEF", "Could not create request context for host window");
                }, Qt::QueuedConnection);
                return;
            }
            hostWindow->create(client, initialUrl, settings, extraInfo, requestContext);
        }));
}

// the window exists: hang it off ours, then size and show it like a view
void CefBrowserWrapper::onHostWindowReady()
{
    if (!m_hostWindow || !window())
        return;
    m_hostWindowReady = true;
    cefAttachChildWindow(nativeHandleOf(window()), m_hostWindow->nativeHandle());
    cefSetChildWindowBackgroundColor(m_hostWindow->nativeHandle(), m_backgroundColor);
    m_nativeCornerRadius = m_cornerRadius;
    cefSetChildWindowCornerRadius(m_hostWindow->nativeHandle(), m_cornerRadius);
    m_nativeRect = QRect();
    if (m_actionTabId != 0)
    {
        cefStopObservingKeyLoss(std::exchange(m_focusObserver, nullptr));
        QPointer<CefBrowserWrapper> guard(this);
        m_focusObserver = cefObserveKeyLoss(m_hostWindow->nativeHandle(), [guard]() {
            if (guard)
                emit guard->nativeFocusLost();
        });
    }
    updateHostWindow();
    if (isVisible())
        refreshNativeView(true);
}

void CefBrowserWrapper::updateHostWindow()
{
    if (!m_hostWindowReady || !window())
        return;

    const QRect screen = toNativeRect(screenRect(), window());
    const QRect native = toNativeRect(sceneRect(), window());
    const bool windowVisible = window()->isVisible() && window()->visibility() != QWindow::Minimized;
    const bool visible = CefNativeViewVisibility::shouldShow(
        windowVisible, isVisible(), m_loading, m_keepVisibleWhileLoading);
    if (screen == m_nativeRect && visible == m_nativeVisible)
        return;
    BrowserLogger::instance().debug("Diag", QString("CefBrowserWrapper::updateHostWindow screen=%1,%2 %3x%4 visible=%5->%6 loading=%7 keep=%8 winVis=%9")
        .arg(screen.x()).arg(screen.y()).arg(screen.width()).arg(screen.height())
        .arg(m_nativeVisible?"1":"0", visible?"1":"0", m_loading?"1":"0", m_keepVisibleWhileLoading?"1":"0", windowVisible?"1":"0"));
    const bool showing = visible && !m_nativeVisible;
    m_nativeRect = screen;
    m_nativeVisible = visible;

#ifdef __APPLE__
    const QRect hostBounds = screen;
#else
    const QRect hostBounds = native;
#endif
    m_hostWindow->setBounds(CefRect(hostBounds.x(), hostBounds.y(), hostBounds.width(), hostBounds.height()),
                            nativeHandleOf(window()), sceneRect(), visible);
    if (showing)
    {
        void *handle = m_hostWindow->nativeHandle();
        cefSetChildWindowCanTakeKey(handle, !m_inputSuppressed && m_focusTarget
                                                && cefChildWindowIsKey(nativeHandleOf(window())));
        m_hostWindow->setVisible(true);
        cefSetChildWindowCanTakeKey(handle, !m_inputSuppressed);
        cefRaiseChildWindow(nativeHandleOf(window()), handle);
        if (std::exchange(m_focusWhenShown, false))
        {
            // after CEF's UI thread has run the Show() queued above
            QPointer<CefBrowserWrapper> guard(this);
            QTimer::singleShot(0, this, [guard]() {
                if (guard)
                    guard->takeFocus();
            });
        }
    }
    else
    {
        m_hostWindow->setVisible(visible);
    }
#if !defined(__APPLE__)
    // an HWND on Windows, an XID (unsigned long) on Linux
    cefSetNativeViewGeometry(reinterpret_cast<cef_window_handle_t>(m_hostWindow->nativeHandle()), native, visible);
#endif
    if (m_nativeCornerRadius != m_cornerRadius)
    {
        m_nativeCornerRadius = m_cornerRadius;
        cefSetChildWindowCornerRadius(m_hostWindow->nativeHandle(), m_cornerRadius);
    }
}

// where the item is on screen: what a window of its own is positioned by
QRect CefBrowserWrapper::screenRect() const
{
    if (!window())
        return sceneRect();

    const QRect windowBounds(QPoint(0, 0), window()->size());
    const QRect visibleScene = sceneRect().intersected(windowBounds);
    if (visibleScene.isEmpty())
        return QRect(visibleScene.topLeft(), QSize(0, 0));
    return QRect(window()->mapToGlobal(visibleScene.topLeft()), visibleScene.size());
}

void CefBrowserWrapper::initializeBrowserHost()
{
    if (m_creatingBrowser || m_browser || !window())
        return;

    QTimer::singleShot(0, this, [this]()
                       {
        if (window())
            createBrowser(nativeHandleOf(window()), sceneRect()); });
}

QRect CefBrowserWrapper::sceneRect() const
{
    return mapRectToScene(QRectF(0, 0, width(), height())).toAlignedRect();
}

void CefBrowserWrapper::updateNativeGeometry()
{
    if (m_hostWindow)
    {
        updateHostWindow();
        return;
    }
    if (!window() || !m_browser)
        return;
    updateGeometry(sceneRect());
}

void CefBrowserWrapper::updateGeometry(const QRect &geometry)
{
    auto host = hostOf(m_browser);
    if (!host)
        return;

    // cache
    const QRect nativeRect = toNativeRect(geometry, window());
    const bool visible = isVisible() && window() && window()->isVisible()
        && window()->visibility() != QWindow::Minimized
        && (m_loading || m_hasLoadedOnce || m_keepVisibleWhileLoading);
    if (nativeRect == m_nativeRect && visible == m_nativeVisible)
        return;

    BrowserLogger::instance().debug("Diag", QString("CefBrowserWrapper::updateGeometry rect=%1,%2 %3x%4 visible=%5->%6 itemVis=%7 winVis=%8 minimized=%9 loading=%10")
        .arg(nativeRect.x()).arg(nativeRect.y()).arg(nativeRect.width()).arg(nativeRect.height())
        .arg(m_nativeVisible?"1":"0", visible?"1":"0", isVisible()?"1":"0",
             (window()&&window()->isVisible())?"1":"0",
             (window()&&window()->visibility()==QWindow::Minimized)?"1":"0",
             m_loading?"1":"0"));
    const bool resized = nativeRect.size() != m_nativeRect.size();
    m_nativeRect = nativeRect;
    m_nativeVisible = visible;

    const auto handle = host->GetWindowHandle();
    cefSetNativeViewGeometry(handle, nativeRect, visible);
    if (m_nativeCornerRadius != m_cornerRadius)
    {
        m_nativeCornerRadius = m_cornerRadius;
        cefSetNativeViewCornerRadius(handle, m_cornerRadius);
    }
    if (resized)
        notifyWindowRenderingResized();
}

bool CefBrowserWrapper::hasPage() const
{
    return m_browser && (!m_hostWindow || m_hostWindowReady);
}

bool CefBrowserWrapper::adoptPage(CefBrowserWrapper *donor)
{
    if (!donor || donor == this || !donor->hasPage())
        return false;
    if (m_browser || m_creatingBrowser || m_hostWindow)
        return false;
    // the page's native window hangs off one top-level window
    if (!window() || donor->window() != window())
        return false;

    // the client CEF reports this page to comes along; the donor gets ours,
    // so each wrapper still has one of its own
    std::swap(m_client, donor->m_client);
    m_client->retarget(this);
    donor->m_client->retarget(donor);

    m_browser = std::exchange(donor->m_browser, nullptr);
    m_hostWindow = std::exchange(donor->m_hostWindow, nullptr);
    m_hostWindowReady = std::exchange(donor->m_hostWindowReady, false);
    m_browserId = std::exchange(donor->m_browserId, 0);

    // the page as it stands: this wrapper must not load anything over it
    m_url = donor->m_url;
    m_createdUrl = m_url;
    m_title = donor->m_title;
    m_icon = donor->m_icon;
    m_loading = donor->m_loading;
    m_loadProgress = donor->m_loadProgress;
    m_canGoBack = donor->m_canGoBack;
    m_canGoForward = donor->m_canGoForward;
    m_zoomFactor = donor->m_zoomFactor;
    m_renderProcessPid = donor->m_renderProcessPid;
    m_audible.adopt(donor->m_audible);
    donor->m_audible.clear();
    donor->m_nativeRect = QRect();
    donor->m_nativeVisible = false;
    donor->m_creatingBrowser = false;

    // and shown as ours: our geometry, corners, background, input and mute
    m_nativeRect = QRect();
    m_nativeVisible = false;
    m_nativeCornerRadius = -1;
    if (m_hostWindow)
    {
        cefSetChildWindowBackgroundColor(m_hostWindow->nativeHandle(), m_backgroundColor);
        updateHostWindow();
    }
    else
    {
        updateNativeGeometry();
    }
    if (m_inputSuppressed)
        applyInputSuppression();
    if (auto host = hostOf(m_browser))
        host->SetAudioMuted(m_audioMuted);

    emit browserIdChanged();
    emit urlChanged();
    emit titleChanged();
    emit iconChanged();
    emit loadingChanged();
    emit loadProgressChanged(m_loadProgress);
    emit canGoBackChanged();
    emit canGoForwardChanged();
    emit zoomFactorChanged();
    emit renderProcessPidChanged(m_renderProcessPid);
    if (isVisible())
        refreshNativeView(true);
    return true;
}
