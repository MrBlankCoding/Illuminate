#pragma once

#include <QObject>
#include <QString>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

class QQmlEngine;
class QJSEngine;

class MemoryMonitor : public QObject
{
    Q_OBJECT
    QML_NAMED_ELEMENT(MemoryMonitor)
    QML_SINGLETON

    // what "bytes" means on this platform, e.g. "Physical footprint"
    Q_PROPERTY(QString metricName READ metricName CONSTANT)

public:
    static MemoryMonitor &instance();
    static MemoryMonitor *create(QQmlEngine *, QJSEngine *);

    QString metricName() const;

    // History storage on disk (bytes)
    Q_INVOKABLE qint64 historySizeBytes() const;

    // Cache storage on disk (bytes)
    Q_INVOKABLE qint64 diskCacheSizeBytes() const;

    // { total: bytes, processes: [{ pid, type, bytes, self }] }, heaviest first
    Q_INVOKABLE QVariantMap snapshot() const;
};
