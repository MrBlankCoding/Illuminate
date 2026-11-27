#pragma once

#include <QObject>
#include <QPointer>
#include <QQuickItem>
#include <QtQml/qqmlregistration.h>

class PopupCloser : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit PopupCloser(QObject *parent = nullptr);

    Q_INVOKABLE void watch(QObject *popup);
    Q_INVOKABLE void unwatch(QObject *popup);

private:
    bool eventFilter(QObject *watched, QEvent *event) override;
    bool tryCloseTopmost(QMouseEvent *me);
    QVector<QPointer<QObject>> m_popups;
};
