#include "SystemInfo.h"

#include <QCoreApplication>
#include <QDir>
#include <QSettings>
#include <QSysInfo>
#include <QQmlEngine>
#include <QJSEngine>

#if defined(Q_OS_MACOS)
#include <sys/sysctl.h>
#elif defined(Q_OS_LINUX)
#include <QFile>
#include <QRegularExpression>
#elif defined(Q_OS_WIN)
#include <windows.h>
#endif

SystemInfo *SystemInfo::instance()
{
    static SystemInfo info;
    return &info;
}

SystemInfo *SystemInfo::create(QQmlEngine *, QJSEngine *)
{
    QJSEngine::setObjectOwnership(instance(), QJSEngine::CppOwnership);
    return instance();
}

SystemInfo::SystemInfo(QObject *parent)
    : QObject(parent)
{
    detectHardware();
}

void SystemInfo::detectHardware()
{
#if defined(Q_OS_MACOS)
    // total physical memory via sysctl
    int mib[2] = {CTL_HW, HW_MEMSIZE};
    uint64_t memBytes = 0;
    size_t len = sizeof(memBytes);
    if (sysctl(mib, 2, &memBytes, &len, nullptr, 0) == 0)
        m_totalMemoryMB = static_cast<int>(memBytes / (1024 * 1024));

    // CPU cores (physical)
    mib[0] = CTL_HW;
    mib[1] = HW_NCPU;
    int ncpu = 0;
    len = sizeof(ncpu);
    if (sysctl(mib, 2, &ncpu, &len, nullptr, 0) == 0)
        m_cpuCoreCount = ncpu > 0 ? ncpu : 1;

#elif defined(Q_OS_LINUX)
    QFile meminfo("/proc/meminfo");
    if (meminfo.open(QIODevice::ReadOnly)) {
        const QByteArray data = meminfo.readAll();
        const QRegularExpression re("MemTotal:\\s*([0-9]+) kB");
        const auto match = re.match(QString::fromLatin1(data));
        if (match.hasMatch())
            m_totalMemoryMB = match.captured(1).toInt() / 1024;
    }
    // /proc/cpuinfo count of processors
    QFile cpuinfo("/proc/cpuinfo");
    if (cpuinfo.open(QIODevice::ReadOnly))
        m_cpuCoreCount = cpuinfo.readAll().count("processor");

    if (m_cpuCoreCount <= 0)
        m_cpuCoreCount = 1;

#elif defined(Q_OS_WIN)
    MEMORYSTATUSEX statex;
    statex.dwLength = sizeof(statex);
    GlobalMemoryStatusEx(&statex);
    m_totalMemoryMB = static_cast<int>(statex.ullTotalPhys / (1024 * 1024));

    SYSTEM_INFO sysinfo;
    GetSystemInfo(&sysinfo);
    m_cpuCoreCount = static_cast<int>(sysinfo.dwNumberOfProcessors);
    if (m_cpuCoreCount <= 0)
        m_cpuCoreCount = 1;

#else
    m_cpuCoreCount = QThread::idealThreadCount();
    if (m_cpuCoreCount <= 0)
        m_cpuCoreCount = 1;
#endif

    // tier classification
    if (m_totalMemoryMB <= 0)
        m_totalMemoryMB = 8192; // fallback

    if (m_totalMemoryMB < 6144)        // < 6 GB
    {
        m_memoryTier = "low";
        m_lowEndDevice = true;
        m_maxTabs = 16;
        m_httpCacheLimitMB = 256;
        m_forceGpu = false;
        m_gpuRasterization = false;
    }
    else if (m_totalMemoryMB < 12288)  // 6–12 GB
    {
        m_memoryTier = "mid";
        m_maxTabs = 24;
        m_httpCacheLimitMB = 512;
        m_forceGpu = false;
        m_gpuRasterization = true;
    }
    else                              // > 12 GB
    {
        m_memoryTier = "high";
        m_maxTabs = 48;
        m_httpCacheLimitMB = 1024;
        m_forceGpu = true;
        m_gpuRasterization = true;
    }

    if (m_cpuCoreCount <= 2)
        m_cpuTier = "low";
    else if (m_cpuCoreCount <= 4)
        m_cpuTier = "mid";
    else
        m_cpuTier = "high";

    QStringList flags;

#if defined(Q_OS_LINUX)
    if (qEnvironmentVariable("XDG_SESSION_TYPE") == QLatin1String("wayland")
        || !qEnvironmentVariable("WAYLAND_DISPLAY").isEmpty())
    {
        flags << "--disable-vulkan";
    }
#endif

    QStringList enabledFeatures;
    enabledFeatures << "HighEfficiencyModeAvailable" << "HighEfficiencyMultistateMode"
                    << "MemorySaverModeAggressiveness";
    QStringList disabledFeatures;
    disabledFeatures << "SpareRendererForSitePerProcess" << "IntensiveDisking"
                     << "RendererCodeIntegrity" << "AutoplayIgnoreWebPreferences"
                     << "InterestGroupBidding" << "IPH_BatterySaverMode"
                     << "UserEducationExperience";

    disabledFeatures << "GlicActorUi";
#if defined(Q_OS_MACOS)
    // Opt into Chromium's VideoToolbox HEVC encode/decode paths. These are
    // runtime features; the CEF binary must also have the HEVC parser and
    // platform decoder compiled in for them to take effect.
    enabledFeatures << "PlatformHEVCDecoderSupport" << "PlatformHEVCEncoderSupport"
                    << "PlatformHEVCHbdEncoderSupport";
    disabledFeatures << "MacWebContentsOcclusion";
#endif
    flags << "--enable-features=" + enabledFeatures.join(QLatin1Char(','));
    flags << "--process-per-site";

#if defined(Q_OS_WIN)
    m_forceGpu = false;
    m_gpuRasterization = false;
    flags << "--disable-gpu";
    disabledFeatures << "WebGPU";
#else
    if (m_gpuRasterization)
        flags << "--enable-gpu-rasterization";
    else
        flags << "--disable-gpu-rasterization";
#endif

    // memory savings for low-end devices
    if (m_lowEndDevice)
    {
        flags << "--enable-low-end-device-mode"
              << "--disable-gpu-memory-buffer-compositing"
              << "--disable-hang-monitor"
              << "--memory-reclaim-threshold=536870912"
              << "--max-active-webgl-chunks=1"
              << "--disable-extensions-http-throttling";
    }
    else
    {
        flags << "--max-active-webgl-chunks=4"
              << "--memory-reclaim-threshold=" + QString::number(m_totalMemoryMB * 1024 * 1024 / 2);
    }

    // disk cache limit (MB -> bytes)
    QSettings userSettings(QDir::homePath() + QDir::separator() + ".illuminate"
                               + QDir::separator() + "settings.ini",
                           QSettings::IniFormat);
    const int userCacheMb = userSettings.value(QLatin1String("network/maxDiskCacheSize"), 0).toInt();
    if (userCacheMb > 0)
        m_httpCacheLimitMB = userCacheMb;

    flags << "--disk-cache-size=" + QString::number(static_cast<qint64>(m_httpCacheLimitMB) * 1024 * 1024);

    flags << "--disable-features=" + disabledFeatures.join(QLatin1Char(','));

    m_chromiumFlags = flags;

    // emit signals
    emit flagsChanged();
    emit memoryChanged();
    emit cpuChanged();
}

int SystemInfo::totalMemoryMB() const { return m_totalMemoryMB; }
int SystemInfo::cpuCoreCount() const { return m_cpuCoreCount; }
QString SystemInfo::memoryTier() const { return m_memoryTier; }
QString SystemInfo::cpuTier() const { return m_cpuTier; }
QStringList SystemInfo::chromiumFlags() const { return m_chromiumFlags; }
int SystemInfo::httpCacheLimitMB() const { return m_httpCacheLimitMB; }
int SystemInfo::maxTabs() const { return m_maxTabs; }
bool SystemInfo::gpuRasterization() const { return m_gpuRasterization; }
bool SystemInfo::forceGpu() const { return m_forceGpu; }
bool SystemInfo::lowEndDevice() const { return m_lowEndDevice; }
