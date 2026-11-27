#include "PopupCloser.h"

#include <QApplication>
#include <QEvent>
#include <QMetaObject>
#include <QMouseEvent>
#include <QQuickItem>
#include <QQuickWindow>
#include <QRectF>

#include <algorithm>

PopupCloser::PopupCloser(QObject *parent)
    : QObject(parent)
{
    qApp->installEventFilter(this);
}

void PopupCloser::watch(QObject *popup)
{
    if (!popup || m_popups.contains(popup))
        return;

    m_popups.append(popup);
    connect(popup, &QObject::destroyed, this, [this]() {
        m_popups.erase(std::remove_if(m_popups.begin(), m_popups.end(),
                                      [](const QPointer<QObject> &entry) { return entry.isNull(); }),
                       m_popups.end());
    });
}

void PopupCloser::unwatch(QObject *popup)
{
    m_popups.removeAll(popup);
}

bool PopupCloser::eventFilter(QObject *watched, QEvent *event)
{
    Q_UNUSED(watched)

    if (event->type() == QEvent::MouseButtonPress)
    {
        if (QMouseEvent *me = static_cast<QMouseEvent *>(event))
            if (tryCloseTopmost(me))
                return false;
    }
    else if (event->type() == QEvent::KeyPress)
    {
        QKeyEvent *ke = static_cast<QKeyEvent *>(event);
        if (ke->key() == Qt::Key_Escape)
            tryCloseTopmost(nullptr);
    }

    return false;
}

bool PopupCloser::tryCloseTopmost(QMouseEvent *me)
{
    if (m_popups.isEmpty())
        return false;

    QObject *popup = nullptr;
    for (int i = m_popups.size() - 1; i >= 0; --i)
    {
        QObject *candidate = m_popups[i];
        if (!candidate)
        {
            m_popups.removeAt(i);
            continue;
        }

        QVariant visible = candidate->property("visible");
        if (!visible.isValid())
            visible = candidate->property("isVisible");
        if (visible.isValid() && visible.toBool())
        {
            popup = candidate;
            break;
        }
    }

    if (!popup)
        return false;

    // Escape: always close.
    if (!me)
    {
        QMetaObject::invokeMethod(popup, "close");
        return true;
    }

    const QVariant parentValue = popup->property("parent");
    QQuickItem *parentItem = parentValue.value<QQuickItem *>();
    if (parentItem)
    {
        const QPointF topLeft = parentItem->mapToGlobal(QPointF(
            popup->property("x").toReal(), popup->property("y").toReal()));
        const QSizeF size(popup->property("width").toReal(), popup->property("height").toReal());
        if (QRectF(topLeft, size).contains(me->globalPosition()))
            return false;
    }
    else if (QQuickItem *item = qobject_cast<QQuickItem *>(popup))
    {
        if (QQuickWindow *popupWindow = item->window();
            popupWindow && QRectF(popupWindow->geometry()).contains(me->globalPosition()))
            return false;
    }

    QMetaObject::invokeMethod(popup, "close");
    return true;
}
