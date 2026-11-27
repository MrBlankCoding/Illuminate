#include "browser/CefBrowserWrapperPrivate.h"

using namespace CefBrowserWrapperPrivate;

void CefBrowserWrapper::componentComplete()
{
    QQuickItem::componentComplete();
    if (window())
        initializeBrowserHost();
}

void CefBrowserWrapper::itemChange(ItemChange change, const ItemChangeData &data)
{
    QQuickItem::itemChange(change, data);
    if (change == ItemSceneChange)
    {
        QObject::disconnect(m_frameConnection);
        QObject::disconnect(m_windowXConnection);
        QObject::disconnect(m_windowYConnection);
        QObject::disconnect(m_windowScreenConnection);
        QObject::disconnect(m_windowVisibilityConnection);
        QObject::disconnect(m_windowActivationConnection);
        QObject::disconnect(m_windowActiveConnection);
        if (data.window)
        {
            m_frameConnection = connect(data.window, &QQuickWindow::afterAnimating,
                                        this, &CefBrowserWrapper::updateNativeGeometry);
            // Native title-bar moves can finish without another Qt animation
            // frame. Track the top-level window directly so its CEF child
            // window receives the final global position as soon as it changes.
            m_windowXConnection = connect(data.window, &QWindow::xChanged,
                                          this, &CefBrowserWrapper::updateNativeGeometry);
            m_windowYConnection = connect(data.window, &QWindow::yChanged,
                                          this, &CefBrowserWrapper::updateNativeGeometry);
            m_windowScreenConnection = connect(data.window, &QWindow::screenChanged,
                                               this, &CefBrowserWrapper::updateNativeGeometry);
            m_windowVisibilityConnection = connect(data.window, &QWindow::visibilityChanged, this,
                [this, window = data.window]() {
                    if (window != this->window() || !isVisible())
                        return;
                    if (!window->isVisible() || window->visibility() == QWindow::Minimized) {
                        updateNativeGeometry();
                        return;
                    }
                    m_nativeRect = QRect();
                    refreshNativeView(true);
                });
            m_windowActivationConnection = connect(data.window, &QWindow::activeChanged, this,
                [this, window = data.window]() {
                    if (!window->isActive() || window != this->window() || !isVisible())
                        return;
                    m_nativeRect = QRect();
                    refreshNativeView(true);
                });

            m_windowActiveConnection = connect(qGuiApp, &QGuiApplication::applicationStateChanged, this,
                                               [this, window = data.window](Qt::ApplicationState state) {
                if (state != Qt::ApplicationActive || window != this->window() || !isVisible())
                    return;

                if (!window->isActive())
                    return;

                m_nativeRect = QRect();
                refreshNativeView(true);
            });
            if (m_hostWindowReady)
                onHostWindowReady();
            initializeBrowserHost();
        }
        else if (m_hostWindowReady)
        {
            m_nativeVisible = false;
            m_hostWindow->setVisible(false);
            cefDetachChildWindow(m_hostWindow->nativeHandle());
        }
        else if (auto host = hostOf(m_browser))
        {
            if (m_nativeVisible)
            {
                m_nativeVisible = false;
                cefSetNativeViewGeometry(host->GetWindowHandle(), m_nativeRect, false);
            }
        }
    }
    else if (change == ItemVisibleHasChanged)
    {
        updateNativeGeometry();
#ifndef __APPLE__
        if (isVisible())
        {
            QPointer<CefBrowserWrapper> guard(this);
            QTimer::singleShot(0, this, [guard]() {
                if (guard && guard->isVisible())
                    guard->refreshNativeView(true);
            });
        }
#endif
    }
}

void CefBrowserWrapper::geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry)
{
    QQuickItem::geometryChange(newGeometry, oldGeometry);
    updateNativeGeometry();
}
