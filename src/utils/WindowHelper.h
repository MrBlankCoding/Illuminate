#pragma once

#include <QObject>
#include <QQuickWindow>
#include <QtQml/qqmlregistration.h>

class WindowHelper : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
public:
    using QObject::QObject;

    Q_INVOKABLE void applyTitleBarStyle(QQuickWindow *window, qreal barHeight);
    Q_INVOKABLE void showSystemMenu(QQuickWindow *window);
    Q_INVOKABLE void setWindowButtonsVisible(QQuickWindow *window, bool visible);
    Q_INVOKABLE void haptic(const QString &kind = QStringLiteral("snap"));
};
