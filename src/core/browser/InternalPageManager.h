#pragma once

#include <QObject>
#include <QString>
#include <QtQml/qqmlregistration.h>

class QQmlEngine;
class QJSEngine;

class InternalPageManager : public QObject
{
    Q_OBJECT
    QML_NAMED_ELEMENT(InternalPages)
    QML_SINGLETON

public:
    static InternalPageManager &instance();
    static InternalPageManager *create(QQmlEngine *, QJSEngine *);

    Q_INVOKABLE static bool isInternal(const QString &url);
    Q_INVOKABLE static QString qmlSource(const QString &url);
    Q_INVOKABLE static QString title(const QString &url);
    Q_INVOKABLE static QString iconUrl(const QString &url);
};
