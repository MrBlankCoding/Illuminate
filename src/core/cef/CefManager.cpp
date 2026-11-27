#include "CefManager.h"
#include "../utils/cef_helpers.h"
#include "../utils/BrowserLogger.h"
#include <include/base/cef_compiler_specific.h>
#include "CefProfile.h"
#include "CefStrayBrowserClient.h"
#include "CefRenderProcessHandler.h"
#include <include/cef_browser.h>
#include "SystemInfo.h"

#include <QCoreApplication>
#include <QDir>
#include <QElapsedTimer>
#include <QFile>
#include <QFileInfo>
#include <QMetaObject>
#include <QMutexLocker>
#include <QScopedValueRollback>
#include <QSettings>
#include <QThread>
#include <QTimer>

#include <algorithm>
#include <chrono>
#include <vector>

#include <include/cef_version.h>

QStringList CefManager::s_extraFlags;

namespace
{

constexpr int kMaxPumpDelayMs = 1000 / 30;
constexpr auto kBrowserCloseTimeout = std::chrono::seconds(10);
constexpr char kBrowserLanguageKey[] = "general/language";
constexpr const char *kCustomSchemes[] = {"illuminate", "newtab"};
constexpr const char *kListSwitches[] = {
    "enable-features",
    "disable-features",
    "enable-blink-features",
    "disable-blink-features",
};

bool isListSwitch(const QString &name)
{
    for (const char *listSwitch : kListSwitches)
    {
        if (name == QLatin1String(listSwitch))
            return true;
    }
    return false;
}

QString mergeLists(const QString &existing, const QString &added)
{
    QStringList merged;
    const QStringList items = (existing + QLatin1Char(',') + added)
                                  .split(QLatin1Char(','), Qt::SkipEmptyParts);
    for (const QString &item : items)
    {
        if (!merged.contains(item))
            merged.append(item);
    }
    return merged.join(QLatin1Char(','));
}

// Returns false if the flag is malformed and was skipped.
bool applyChromiumFlag(const CefRefPtr<CefCommandLine> &commandLine, const QString &flag)
{
    if (!flag.startsWith(QLatin1String("--")))
        return false;

    const QString body = flag.mid(2);
    if (body.isEmpty())
        return false;

    const int eq = body.indexOf(QLatin1Char('='));
    if (eq < 0)
    {
        commandLine->AppendSwitch(qStringToCef(body));
        return true;
    }
    if (eq == 0)
        return false;

    const QString key = body.left(eq);
    QString value = body.mid(eq + 1);
    if (isListSwitch(key))
    {
        const CefString existing = commandLine->GetSwitchValue(qStringToCef(key));
        if (!existing.empty())
            value = mergeLists(QString::fromStdString(existing.ToString()), value);
    }
    commandLine->AppendSwitchWithValue(qStringToCef(key), qStringToCef(value));
    return true;
}

CefMainArgs makeMainArgs(int argc, char **argv)
{
#if defined(OS_WIN)
    Q_UNUSED(argc);
    Q_UNUSED(argv);
    return CefMainArgs(::GetModuleHandle(nullptr));
#else
    return CefMainArgs(argc, argv);
#endif
}

} // namespace

CefManager &CefManager::instance()
{
    static CefRefPtr<CefManager> s_instance(new CefManager());
    return *s_instance.get();
}

void CefManager::setChromiumFlags(const QStringList &flags)
{
    s_extraFlags = flags;
}

CefProfile *CefManager::defaultProfile()
{
    return CefProfile::instance();
}

bool CefManager::chromeStyle()
{
    static const QString style = qEnvironmentVariable("ILLUMINATE_ALLOY_STYLE");
#ifdef Q_OS_MACOS
    static const bool chrome = style.isEmpty() || style == QLatin1String("0");
#else
    static const bool chrome = !style.isNull() && style == QLatin1String("0");
#endif
    return chrome;
}

// Stack protector is disabled for this function, see cef#3912.
NO_STACK_PROTECTOR int CefManager::executeProcess(int argc, char **argv)
{
    const CefMainArgs mainArgs = makeMainArgs(argc, argv);
    return CefExecuteProcess(mainArgs, CefRefPtr<CefApp>(&instance()), nullptr);
}

bool CefManager::initialize(int argc, char **argv)
{
    CefManager &self = instance();
    if (self.m_initialized)
        return true;

    const CefMainArgs mainArgs = makeMainArgs(argc, argv);
    CefRefPtr<CefApp> app(&self);

    CefSettings settings;
    settings.no_sandbox = true;

#ifdef __APPLE__
    // CEF requires absolute, clean paths here
    const QString frameworkPath = QFileInfo(QCoreApplication::applicationDirPath()
        + QStringLiteral("/../Frameworks/Chromium Embedded Framework.framework")).canonicalFilePath();
    if (frameworkPath.isEmpty()) {
        BrowserLogger::instance().error("CEF", "Chromium Embedded Framework.framework missing from the app bundle");
        return false;
    }
    CefString(&settings.framework_dir_path) = qStringToCef(frameworkPath);
    BrowserLogger::instance().info("CEF", "Framework directory: " + frameworkPath);

    settings.multi_threaded_message_loop = false;
    settings.external_message_pump = true;
    self.m_externalPump = true;
    installCefAppProtocol();
    // Sub-processes are found by CEF at
    // Contents/Frameworks/illuminate Helper*.app, so browser_subprocess_path stays empty.
#else
    settings.multi_threaded_message_loop = true;

    const QString cefRoot = QString::fromLocal8Bit(qgetenv("CEF_ROOT"));
    if (!cefRoot.isEmpty()) {
        const QString resourcesPath = cefRoot + QStringLiteral("/Resources");
        if (QFile::exists(resourcesPath + QStringLiteral("/resources.pak"))) {
            CefString(&settings.resources_dir_path) = qStringToCef(resourcesPath);
            CefString(&settings.locales_dir_path) = qStringToCef(resourcesPath + QStringLiteral("/locales"));
            BrowserLogger::instance().info("CEF", "Resources path: " + resourcesPath);
        }
    }
#endif

    const QString rootCache = CefProfile::rootCachePath();
    if (!QDir().mkpath(rootCache))
        BrowserLogger::instance().warning("CEF", "Could not create cache directory: " + rootCache);
    CefString(&settings.cache_path) = qStringToCef(rootCache);
    CefString(&settings.root_cache_path) = qStringToCef(rootCache);
    settings.persist_session_cookies = true;
    
    const QStringList profileDirs = QDir(rootCache).entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QString &profileDir : profileDirs)
        QDir(rootCache + QStringLiteral("/") + profileDir + QStringLiteral("/Sessions")).removeRecursively();

    const bool success = CefInitialize(mainArgs, settings, app, nullptr);
    self.m_initialized = success;
    if (success) {
        BrowserLogger::instance().info("CEF", QStringLiteral("CEF %1 initialized")
            .arg(QString::fromLatin1(CEF_VERSION)));
        if (self.m_externalPump)
            self.scheduleMessagePumpWork(0);
    } else {
        BrowserLogger::instance().error("CEF", QStringLiteral("CefInitialize failed (exit code %1)")
            .arg(CefGetExitCode()));
    }

    return success;
}

void CefManager::browserCreated(CefRefPtr<CefBrowser> browser)
{
    if (!browser)
        return;

    QMutexLocker lock(&m_browsersMutex);
    m_browsers.push_back(browser);
}

void CefManager::browserClosed(CefRefPtr<CefBrowser> browser)
{
    if (!browser)
        return;

    QMutexLocker lock(&m_browsersMutex);
    std::erase_if(m_browsers, [&](const CefRefPtr<CefBrowser> &b) { return b->IsSame(browser); });
}

void CefManager::closeAllBrowsers()
{
    m_shuttingDown = true;
    {
        std::vector<CefRefPtr<CefBrowser>> browsers;
        {
            QMutexLocker lock(&m_browsersMutex);
            browsers = m_browsers;
        }
        for (const auto &browser : browsers)
        {
            if (auto host = browser->GetHost())
                host->CloseBrowser(true);
        }
    }

    const auto openBrowserCount = [this]() {
        QMutexLocker lock(&m_browsersMutex);
        return m_browsers.size();
    };

    QElapsedTimer timer;
    timer.start();
    while (std::chrono::milliseconds(timer.elapsed()) < kBrowserCloseTimeout && openBrowserCount() > 0)
    {
        if (m_externalPump)
            CefDoMessageLoopWork();
        QCoreApplication::processEvents(QEventLoop::AllEvents, 5);
        // processEvents() returns immediately when idle; don't spin a core
        QThread::msleep(2);
    }
    QCoreApplication::processEvents();

    QMutexLocker lock(&m_browsersMutex);
    if (!m_browsers.empty())
        BrowserLogger::instance().warning("CEF", QStringLiteral("%1 browser(s) still open at shutdown")
            .arg(static_cast<int>(m_browsers.size())));
    m_browsers.clear();

    // ponytail: 10 pump cycles drain post-close tasks. Increase if complex WebWorkers/renderers hang on exit.
    if (m_externalPump)
    {
        for (int i = 0; i < 10; ++i)
        {
            CefDoMessageLoopWork();
            QCoreApplication::processEvents(QEventLoop::AllEvents, 5);
            QThread::msleep(5);
        }
    }
}

void CefManager::shutdown()
{
    CefManager &self = instance();
    if (!self.m_initialized)
        return;

    self.m_shuttingDown = true;
    self.m_initialized = false;
    if (self.m_pumpTimer)
        self.m_pumpTimer->stop();
    self.closeAllBrowsers();
    // request contexts hold CEF refs that must go before CefShutdown
    CefProfile::releaseAllRequestContexts();
    self.m_strayClient = nullptr;
    self.m_renderHandler = nullptr;

    // ponytail: 20 pump cycles drain request context and UI teardown tasks before CefShutdown.
    if (self.m_externalPump)
    {
        for (int i = 0; i < 20; ++i)
        {
            CefDoMessageLoopWork();
            QCoreApplication::processEvents(QEventLoop::AllEvents, 5);
            QThread::msleep(5);
        }
    }

    CefShutdown();
    BrowserLogger::instance().info("CEF", "CEF shutdown complete");
}


void CefManager::OnBeforeCommandLineProcessing(const CefString &process_type,
                                               CefRefPtr<CefCommandLine> command_line)
{
    const bool isBrowserProcess = process_type.empty();

    // Append flags from SystemInfo if not already passed
    QStringList flags = s_extraFlags;
    if (flags.isEmpty())
    {
        if (SystemInfo *si = SystemInfo::instance())
            flags = si->chromiumFlags();
    }

    for (const QString &flag : flags)
    {
        if (!applyChromiumFlag(command_line, flag) && isBrowserProcess)
            BrowserLogger::instance().warning("CEF", "Ignoring malformed Chromium flag: " + flag);
    }

    if (!isBrowserProcess)
        return;

    // browser UI language; an empty value means "system default"
    QSettings browserLanguageSettings;
    const QString language =
        browserLanguageSettings.value(QLatin1String(kBrowserLanguageKey), QString()).toString();
    if (!language.isEmpty())
        command_line->AppendSwitchWithValue(qStringToCef("lang"), qStringToCef(language));

    QSettings cacheSettings(QDir::homePath() + QDir::separator() + ".illuminate"
                                + QDir::separator() + "settings.ini",
                            QSettings::IniFormat);
    const int userCacheMb = cacheSettings.value(QLatin1String("network/maxDiskCacheSize"), 0).toInt();
    if (userCacheMb > 0)
    {
        const QString cacheFlag = QStringLiteral("--disk-cache-size=%1")
                                      .arg(static_cast<qint64>(userCacheMb) * 1024 * 1024);
        applyChromiumFlag(command_line, cacheFlag);
    }

    // TODO: remove in production
#ifdef Q_OS_MACOS
    if (!command_line->HasSwitch("use-mock-keychain"))
        command_line->AppendSwitch("use-mock-keychain");
#endif
}

void CefManager::OnRegisterCustomSchemes(CefRawPtr<CefSchemeRegistrar> registrar)
{
    for (const char *scheme : kCustomSchemes)
        registrar->AddCustomScheme(scheme, CEF_SCHEME_OPTION_STANDARD | CEF_SCHEME_OPTION_SECURE);
}

CefRefPtr<CefRenderProcessHandler> CefManager::GetRenderProcessHandler()
{
    if (!m_renderHandler)
        m_renderHandler = new CefRenderProcessHandlerImpl();
    return m_renderHandler;
}

CefRefPtr<CefClient> CefManager::GetDefaultClient()
{
    if (!m_strayClient)
        m_strayClient = new CefStrayBrowserClient();
    return m_strayClient;
}

void CefManager::OnContextInitialized()
{
    BrowserLogger::instance().info("CEF", "CEF context initialized");
}

void CefManager::OnScheduleMessagePumpWork(int64_t delay_ms)
{
    // may be called from any thread; the pump itself runs on the Qt main thread
    QCoreApplication *app = QCoreApplication::instance();
    if (!app)
        return;

    QMetaObject::invokeMethod(app, [delay_ms]() {
        instance().scheduleMessagePumpWork(delay_ms);
    }, Qt::QueuedConnection);
}

void CefManager::scheduleMessagePumpWork(int64_t delayMs)
{
    if (!m_externalPump || !m_initialized || m_shuttingDown)
        return;

    if (!m_pumpTimer) {
        m_pumpTimer = new QTimer(qApp);
        m_pumpTimer->setSingleShot(true);
        m_pumpTimer->setTimerType(Qt::PreciseTimer);
        QObject::connect(m_pumpTimer, &QTimer::timeout, qApp, []() {
            instance().doMessageLoopWork();
        });
    }

    const int delay = static_cast<int>(std::clamp<int64_t>(delayMs, 0, int64_t(kMaxPumpDelayMs)));
    // keep whichever deadline comes first
    if (m_pumpTimer->isActive() && m_pumpTimer->remainingTime() <= delay)
        return;
    m_pumpTimer->start(delay);
}

void CefManager::doMessageLoopWork()
{
    if (!m_initialized || m_shuttingDown || m_inPumpWork)
        return;

    {
        QScopedValueRollback<bool> inPump(m_inPumpWork, true);
        CefDoMessageLoopWork();
    }

    if (m_pumpTimer && !m_pumpTimer->isActive())
        m_pumpTimer->start(kMaxPumpDelayMs);
}
