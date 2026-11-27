#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QThread>
#include <QtQml/qqmlregistration.h>

class QQmlEngine;
class QJSEngine;

class SystemInfo : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(int totalMemoryMB READ totalMemoryMB NOTIFY memoryChanged)
    Q_PROPERTY(int cpuCoreCount READ cpuCoreCount NOTIFY cpuChanged)
    Q_PROPERTY(QString memoryTier READ memoryTier NOTIFY memoryChanged)
    Q_PROPERTY(QString cpuTier READ cpuTier NOTIFY cpuChanged)
    Q_PROPERTY(QStringList chromiumFlags READ chromiumFlags NOTIFY flagsChanged)
    Q_PROPERTY(int httpCacheLimitMB READ httpCacheLimitMB NOTIFY flagsChanged)
    Q_PROPERTY(int maxTabs READ maxTabs NOTIFY flagsChanged)
    Q_PROPERTY(bool gpuRasterization READ gpuRasterization NOTIFY flagsChanged)
    Q_PROPERTY(bool forceGpu READ forceGpu NOTIFY flagsChanged)
    Q_PROPERTY(bool lowEndDevice READ lowEndDevice NOTIFY flagsChanged)
    Q_PROPERTY(bool discardBackgroundTabs READ discardBackgroundTabs CONSTANT)

public:
    static SystemInfo *instance();
    static SystemInfo *create(QQmlEngine *, QJSEngine *);

    int totalMemoryMB() const;
    int cpuCoreCount() const;
    QString memoryTier() const;
    QString cpuTier() const;
    QStringList chromiumFlags() const;
    int httpCacheLimitMB() const;
    int maxTabs() const;
    bool gpuRasterization() const;
    bool forceGpu() const;
    bool lowEndDevice() const;
    bool discardBackgroundTabs() const { return true; }

signals:
    void memoryChanged();
    void cpuChanged();
    void flagsChanged();

private:
    explicit SystemInfo(QObject *parent = nullptr);
    void detectHardware();

    int m_totalMemoryMB = 0;
    int m_cpuCoreCount = 1;
    QString m_memoryTier;
    QString m_cpuTier;
    QStringList m_chromiumFlags;
    int m_httpCacheLimitMB = 1024;
    int m_maxTabs = 32;
    bool m_gpuRasterization = true;
    bool m_forceGpu = true;
    bool m_lowEndDevice = false;
};
