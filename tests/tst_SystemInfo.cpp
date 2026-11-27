#include <QtTest>

#include <algorithm>
#include <QQmlEngine>

#include "SystemInfo.h"

class TestSystemInfo : public QObject
{
    Q_OBJECT

private slots:
    void singletonIsStable()
    {
        QCOMPARE(SystemInfo::instance(), SystemInfo::instance());
    }

    void hardwareValuesArePositive()
    {
        const SystemInfo *info = SystemInfo::instance();
        QVERIFY(info->totalMemoryMB() > 0);
        QVERIFY(info->cpuCoreCount() > 0);
    }

    void memoryTierHasMatchingLimits()
    {
        const SystemInfo *info = SystemInfo::instance();
        if (info->memoryTier() == QStringLiteral("low"))
        {
            QVERIFY(info->lowEndDevice());
            QCOMPARE(info->maxTabs(), 16);
            QCOMPARE(info->httpCacheLimitMB(), 256);
            QVERIFY(!info->forceGpu());
        }
        else if (info->memoryTier() == QStringLiteral("mid"))
        {
            QVERIFY(!info->lowEndDevice());
            QCOMPARE(info->maxTabs(), 24);
            QCOMPARE(info->httpCacheLimitMB(), 512);
            QVERIFY(!info->forceGpu());
        }
        else
        {
            QCOMPARE(info->memoryTier(), QStringLiteral("high"));
            QVERIFY(!info->lowEndDevice());
            QCOMPARE(info->maxTabs(), 48);
            QCOMPARE(info->httpCacheLimitMB(), 1024);
            QVERIFY(info->forceGpu());
        }
    }

    void cpuTierMatchesDetectedCoreCount()
    {
        const SystemInfo *info = SystemInfo::instance();
        if (info->cpuCoreCount() <= 2)
            QCOMPARE(info->cpuTier(), QStringLiteral("low"));
        else if (info->cpuCoreCount() <= 4)
            QCOMPARE(info->cpuTier(), QStringLiteral("mid"));
        else
            QCOMPARE(info->cpuTier(), QStringLiteral("high"));
    }

    void chromiumFlagsIncludeMemoryAndCacheConfiguration()
    {
        const QStringList flags = SystemInfo::instance()->chromiumFlags();
        QVERIFY(flags.contains(QStringLiteral("--process-per-site")));
        QVERIFY(flags.contains(QStringLiteral("--disk-cache-size=%1")
                                   .arg(SystemInfo::instance()->httpCacheLimitMB() * 1024 * 1024)));
        QVERIFY(flags.contains(QStringLiteral("--enable-features=HighEfficiencyModeAvailable,HighEfficiencyMultistateMode,MemorySaverModeAggressiveness"))
                || std::any_of(flags.cbegin(), flags.cend(), [](const QString &flag) {
                    return flag.startsWith(QStringLiteral("--enable-features="))
                        && flag.contains(QStringLiteral("MemorySaverModeAggressiveness"));
                }));
    }

    void chromiumFlagsContainExactlyOneGpuRasterizationPolicy()
    {
        const QStringList flags = SystemInfo::instance()->chromiumFlags();
        const int enabled = flags.count(QStringLiteral("--enable-gpu-rasterization"));
        const int disabled = flags.count(QStringLiteral("--disable-gpu-rasterization"));
        QCOMPARE(enabled + disabled, 1);
        QCOMPARE(enabled == 1, SystemInfo::instance()->gpuRasterization());
    }

    void backgroundDiscardPolicyIsExposed()
    {
        QVERIFY(SystemInfo::instance()->discardBackgroundTabs());
    }

    void singletonFactoryReturnsTheSharedInstance()
    {
        QQmlEngine engine;
        QCOMPARE(SystemInfo::create(&engine, nullptr), SystemInfo::instance());
    }
};

QTEST_GUILESS_MAIN(TestSystemInfo)
#include "tst_SystemInfo.moc"
