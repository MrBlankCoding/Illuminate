#include "browser/CefBrowserWrapperPrivate.h"

using namespace CefBrowserWrapperPrivate;

bool CefBrowserWrapper::chromeStyle() const
{
    return CefManager::chromeStyle();
}

void CefBrowserWrapper::setZoomFactor(qreal factor)
{
    factor = factor > 0 ? std::clamp(factor, kMinZoomFactor, kMaxZoomFactor) : 1.0;
    if (qFuzzyCompare(m_zoomFactor, factor))
        return;

    m_zoomFactor = factor;
    emit zoomFactorChanged();
    applyZoom(m_browser, m_zoomFactor);
}

void CefBrowserWrapper::setLifecycleState(int state)
{
    if (m_lifecycleState != state)
    {
        m_lifecycleState = state;
        emit lifecycleStateChanged();

        notifyWindowRenderingHidden(state != Active);
    }
}

void CefBrowserWrapper::setKeepVisibleWhileLoading(bool keepVisible)
{
    if (m_keepVisibleWhileLoading == keepVisible)
        return;

    m_keepVisibleWhileLoading = keepVisible;
    emit keepVisibleWhileLoadingChanged();
    updateNativeGeometry();
}

void CefBrowserWrapper::refreshNativeView(bool raiseAboveSiblings)
{
    if (!window() || !isVisible())
        return;

    // Reposition if needed, then restore this tab above sibling CEF windows.
#ifdef __APPLE__
    // CEF's macOS Chrome-style view is hosted in a child NSWindow. AppKit can
    // change that window's frame while focus moves between the child and Qt;
    // invalidate the cached frame so updateHostWindow reapplies the QML item
    // bounds before restoring it.
    if (m_hostWindowReady)
        m_nativeRect = QRect();
#endif
    updateNativeGeometry();
    if (!raiseAboveSiblings || !m_nativeVisible)
        return;
    if (m_hostWindowReady)
    {
        QPointer<CefBrowserWrapper> guard(this);
        if (!m_focusTarget)
            cefSetChildWindowCanTakeKey(m_hostWindow->nativeHandle(), false);
        m_hostWindow->restore([guard]() {
            if (!guard || !guard->m_hostWindowReady)
                return;
            cefSetChildWindowCanTakeKey(guard->m_hostWindow->nativeHandle(), !guard->m_inputSuppressed);
            if (!guard->window() || !guard->isVisible())
                return;
            cefRaiseChildWindow(nativeHandleOf(guard->window()), guard->m_hostWindow->nativeHandle());
        });
    }
#ifdef _WIN32
    else if (auto host = hostOf(m_browser))
        cefRaiseChildWindow(nativeHandleOf(window()), host->GetWindowHandle());
#elif defined(ILLUMINATE_HAS_X11)
    else if (auto host = hostOf(m_browser))
        cefRaiseChildWindow(nativeHandleOf(window()), reinterpret_cast<void *>(host->GetWindowHandle()));
#endif
}

void CefBrowserWrapper::setBackgroundColor(const QColor &color)
{
    if (m_backgroundColor != color)
    {
        m_backgroundColor = color;
        if (m_hostWindow)
            cefSetChildWindowBackgroundColor(m_hostWindow->nativeHandle(), color);
        emit backgroundColorChanged();
    }
}

void CefBrowserWrapper::setCornerRadius(qreal radius)
{
    radius = (std::max)(qreal(0), radius);
    if (qFuzzyIsNull(m_cornerRadius - radius))
        return;

    m_cornerRadius = radius;
    emit cornerRadiusChanged();

    if (m_hostWindowReady)
    {
        m_nativeCornerRadius = m_cornerRadius;
        cefSetChildWindowCornerRadius(m_hostWindow->nativeHandle(), m_cornerRadius);
    }
    else if (auto host = hostOf(m_browser))
    {
        m_nativeCornerRadius = m_cornerRadius;
        cefSetNativeViewCornerRadius(host->GetWindowHandle(), m_cornerRadius);
    }
}

void CefBrowserWrapper::setInputSuppressed(bool suppressed)
{
    if (m_inputSuppressed == suppressed)
        return;
    m_inputSuppressed = suppressed;
    emit inputSuppressedChanged();
    applyInputSuppression();
}

void CefBrowserWrapper::setFocusTarget(bool target)
{
    if (m_focusTarget == target)
        return;
    m_focusTarget = target;
    emit focusTargetChanged();
}

void CefBrowserWrapper::applyInputSuppression()
{
    auto host = hostOf(m_browser);
    if (!host)
        return;

    if (m_inputSuppressed)
    {
        // the page's own window holds key focus; give it back to ours
        if (m_hostWindow && window()) {
            cefSetChildWindowCanTakeKey(m_hostWindow->nativeHandle(), false);
            cefFocusParentWindow(nativeHandleOf(window()));
        } else {
            m_restoreFocus = cefResignNativeFocus(host->GetWindowHandle());
        }
        host->SetFocus(false);
    }
    else
    {
        m_restoreFocus = false;
        if (m_hostWindow)
            cefSetChildWindowCanTakeKey(m_hostWindow->nativeHandle(), true);
        host->SetFocus(true);
    }
}
// notifications
void CefBrowserWrapper::notifyWindowRenderingHidden(bool hidden)
{
    auto host = hostOf(m_browser);
    if (host && host->IsWindowRenderingDisabled())
        host->WasHidden(hidden);
}

void CefBrowserWrapper::notifyWindowRenderingResized()
{
    // see notifyWindowRenderingHidden(): only valid for off-screen rendering
    auto host = hostOf(m_browser);
    if (host && host->IsWindowRenderingDisabled())
        host->WasResized();
}
