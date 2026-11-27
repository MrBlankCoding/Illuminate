#include "CefQuickItem.h"
#include "CefBrowserWrapper.h"
#include <QQuickWindow>
#include <QTimer>

CefQuickItem::CefQuickItem(QQuickItem *parent)
    : QQuickItem(parent)
{
    setFlag(ItemHasContents, true);
}

CefQuickItem::~CefQuickItem() = default;

void CefQuickItem::setBrowser(CefBrowserWrapper *browser)
{
    if (m_browser != browser)
    {
        m_browser = browser;
        emit browserChanged();
        if (isComponentComplete() && window())
            initializeBrowserHost();
    }
}

void CefQuickItem::componentComplete()
{
    QQuickItem::componentComplete();
    if (window() && m_browser)
        initializeBrowserHost();
}

void CefQuickItem::itemChange(ItemChange change, const ItemChangeData &data)
{
    QQuickItem::itemChange(change, data);
    if (change == ItemSceneChange && window() && m_browser)
    {
        initializeBrowserHost();
    }
}

void CefQuickItem::geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry)
{
    QQuickItem::geometryChange(newGeometry, oldGeometry);
    updateNativeGeometry();
}

void CefQuickItem::initializeBrowserHost()
{
    if (m_initialized || !window() || !m_browser)
        return;

    m_initialized = true;

    // Map item position to top-level window coordinates
    const QPointF scenePos = mapToScene(QPointF(0, 0));
    const QRect rect(scenePos.toPoint(), QSize(static_cast<int>(width()), static_cast<int>(height())));

    void *winId = reinterpret_cast<void *>(window()->winId());
    QTimer::singleShot(0, this, [this, winId, rect]() {
        if (m_browser)
            m_browser->createBrowser(winId, rect);
    });
}

void CefQuickItem::updateNativeGeometry()
{
    if (!window() || !m_browser)
        return;

    const QPointF scenePos = mapToScene(QPointF(0, 0));
    const QRect rect(scenePos.toPoint(), QSize(static_cast<int>(width()), static_cast<int>(height())));
    m_browser->updateGeometry(rect);
}
