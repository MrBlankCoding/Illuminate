#include <QApplication>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickWindow>
#include <QDir>
#include <QFileInfo>
#include <QFileOpenEvent>
#include <QLocalServer>
#include <QLocalSocket>
#include <QWindow>

#include <algorithm>
#include <memory>
#include <utility>

#include "core/browser/BrowserSettings.h"
#include "core/menus/ShortcutRegistry.h"
#include "core/cef/CefManager.h"
#include "core/menus/AppMenu.h"
#include "core/models/BookmarkModel.h"
#include "core/browser/BrowserController.h"
#include "core/spaces/SpaceManager.h"
#include "core/system/PermissionHandler.h"

#include "core/system/SystemInfo.h"
#include "core/system/SystemIntegration.h"
#include "core/models/DownloadModel.h"
#include "utils/BrowserLogger.h"
#include <include/base/cef_compiler_specific.h>

#include <QByteArray>

static void activateWindows()
{
    for (QWindow *window : QGuiApplication::topLevelWindows())
    {
        if (!window->isVisible())
            continue;
        if (window->windowState() & Qt::WindowMinimized)
            window->showNormal();
        window->raise();
        window->requestActivate();
    }
}

// links passed on the command line
static QStringList urlsFromArguments(const QStringList &args)
{
    QStringList urls;
    for (qsizetype i = 1; i < args.size(); ++i)
    {
        const QString &arg = args.at(i);
        if (arg.startsWith(QLatin1Char('-')))
            continue;

        if (!arg.contains(QLatin1String("://")) && !QFileInfo::exists(arg))
            continue;
        const QUrl url = QUrl::fromUserInput(arg, QDir::currentPath(), QUrl::AssumeLocalFile);
        if (url.isValid())
            urls << url.toString();
    }
    return urls;
}

// only one instance
static bool claimSingleInstance(QLocalServer &server, const QStringList &urls)
{
    // per user: Windows has no USER, so everyone would share one pipe
    QString user = qEnvironmentVariable("USER");
    if (user.isEmpty())
        user = qEnvironmentVariable("USERNAME");
    const QString name = QStringLiteral("illuminate-") + user;

    QLocalSocket probe;
    probe.connectToServer(name);
    if (probe.waitForConnected(500))
    {
        QByteArray message = "activate\n";
        for (const QString &url : urls)
            message += "open " + url.toUtf8() + '\n';
        probe.write(message);
        probe.waitForBytesWritten(500);
        return false;
    }

    // clear a socket
    // it crashed
    QLocalServer::removeServer(name);
    if (!server.listen(name))
        BrowserLogger::instance().warning("Main", "Single-instance server failed: " + server.errorString());
    return true;
}

static void listenForSecondLaunches(QLocalServer &server, BrowserController &controller)
{
    QObject::connect(&server, &QLocalServer::newConnection, &server, [&server, &controller]()
                     {
        while (QLocalSocket *client = server.nextPendingConnection())
        {
            QObject::connect(client, &QLocalSocket::readyRead, client, [client, &controller]() {
                while (client->canReadLine())
                {
                    const QByteArray line = client->readLine().trimmed();
                    if (line.startsWith("open "))
                        controller.newTab(QString::fromUtf8(line.mid(5)));
                }
                activateWindows();
            });
            QObject::connect(client, &QLocalSocket::disconnected, client, &QObject::deleteLater);
        } });
}

// macOS delivers default-browser links as FileOpen events, not argv
class UrlOpenFilter : public QObject
{
public:
    explicit UrlOpenFilter(BrowserController &controller, QObject *parent = nullptr)
        : QObject(parent), m_controller(controller) {}

protected:
    bool eventFilter(QObject *watched, QEvent *event) override
    {
        if (event->type() == QEvent::FileOpen)
        {
            const QUrl url = static_cast<QFileOpenEvent *>(event)->url();
            if (url.isValid())
            {
                m_controller.newTab(url.toString());
                activateWindows();
                return true;
            }
        }
        return QObject::eventFilter(watched, event);
    }

private:
    BrowserController &m_controller;
};

#if defined(Q_OS_WIN)
// whatttttttttt
extern "C" {
__declspec(dllexport) unsigned long NvOptimusEnablement = 1;
__declspec(dllexport) int AmdPowerXpressRequestHighPerformance = 1;
}
#endif

// base/cef_compiler_specific.h, cef#3912).
NO_STACK_PROTECTOR int main(int argc, char *argv[])
{
    // CEF can launch before our application
    const int subprocessExitCode = CefManager::executeProcess(argc, argv);
    if (subprocessExitCode >= 0)
        return subprocessExitCode;

#if defined(Q_OS_LINUX)
    // CEF's Linux native child-window API uses X11 window IDs. On Wayland,
    // default to Qt's X11 backend when XWayland is available so the CEF view
    // can be parented inside the Qt shell.
    const bool useXcbForEmbedding = qEnvironmentVariableIsEmpty("QT_QPA_PLATFORM")
        && !qEnvironmentVariableIsEmpty("WAYLAND_DISPLAY")
        && !qEnvironmentVariableIsEmpty("DISPLAY");
    if (useXcbForEmbedding)
        qputenv("QT_QPA_PLATFORM", "xcb");
#endif

    QStringList flagsList = SystemInfo::instance()->chromiumFlags();
#if defined(Q_OS_LINUX)
    if (std::none_of(flagsList.cbegin(), flagsList.cend(), [](const QString &flag) {
            return flag.startsWith(QStringLiteral("--ozone-platform="));
        }))
        flagsList << QStringLiteral("--ozone-platform=x11");
#endif
    if (qEnvironmentVariableIsSet("ILLUMINATE_VERBOSE_CEF"))
    {
        flagsList += QStringLiteral("--enable-logging");
        flagsList += QStringLiteral("--v=1");
        flagsList += QStringLiteral("--vmodule=*=2");
    }

    CefManager::setChromiumFlags(flagsList);

    QCoreApplication::setAttribute(Qt::AA_ShareOpenGLContexts);
    QQuickWindow::setDefaultAlphaBuffer(true);
    if (!qEnvironmentVariableIsSet("QSG_ATLAS_WIDTH"))
        qputenv("QSG_ATLAS_WIDTH", "1024");
    if (!qEnvironmentVariableIsSet("QSG_ATLAS_HEIGHT"))
        qputenv("QSG_ATLAS_HEIGHT", "1024");



    QApplication app(argc, argv);
    app.setApplicationName("illuminate");
    app.setOrganizationName("illuminate");
    app.setApplicationVersion(QStringLiteral(ILLUMINATE_VERSION));

#if defined(Q_OS_LINUX)
    app.setDesktopFileName(QStringLiteral("illuminate.desktop"));
#endif

    BrowserLogger::instance().installAsQtHandler();
    if (!CefManager::initialize(argc, argv))
        BrowserLogger::instance().error("Main", "CEF failed to initialize; web pages will not load");

    const QStringList launchUrls = urlsFromArguments(app.arguments());
    QLocalServer instanceServer;
    if (!claimSingleInstance(instanceServer, launchUrls))
    {
        BrowserLogger::instance().info("Main", "Already running; activated the existing window");
        return 0;
    }


    PermissionHandler permissionHandler(nullptr);
    ShortcutRegistry shortcutRegistry(nullptr);
    SpaceManager spaces(nullptr);
    BookmarkModel bookmarks(nullptr);

    // QML establishes befor eengine load
    BrowserSettings browserSettings(nullptr);
    BrowserSettings::setQmlInstance(&browserSettings);

    BrowserLogger::instance().info("Main", "illuminate starting up");

    BrowserLogger::instance().info("Main", QString("Qt %1").arg(qVersion()));
    BrowserController controller(spaces.activeSpace());

    // Each space owns its tabs, bookmarks and Chromium profile data.
    bookmarks.setSpace(spaces.activeSpace());
    QObject::connect(&spaces, &SpaceManager::activeSpaceChanged, &spaces, [&]() {
        controller.setActiveSpace(spaces.activeSpace());
        bookmarks.setSpace(spaces.activeSpace());
    });
    // a deleted space's tabs, kept in memory since it was left, go with it
    QObject::connect(&spaces, &SpaceManager::spacesChanged, &spaces, [&]() {
        QStringList ids;
        for (const QVariant &entry : spaces.spaces())
            if (Space *space = entry.value<Space *>())
                ids.append(space->id());
        controller.keepResidentSpaces(ids);
    });

    BrowserController::setQmlInstance(&controller);
    SpaceManager::setQmlInstance(&spaces);

    PermissionHandler::setQmlInstance(&permissionHandler);
    ShortcutRegistry::setQmlInstance(&shortcutRegistry);
    BookmarkModel::setQmlInstance(&bookmarks);
    qmlRegisterSingletonType<PermissionHandler>("illuminate.ui", 1, 0, "DefaultBrowser", PermissionHandler::create);

    AppMenu appMenu(nullptr);
    AppMenu::setQmlInstance(&appMenu);

    SystemIntegration systemIntegration(nullptr);
    SystemIntegration::setQmlInstance(&systemIntegration);
    const auto offerActivePage = [&controller, &systemIntegration]() {
        systemIntegration.setCurrentPage(QUrl(controller.activeUrl()), controller.activeTitle());
    };
    QObject::connect(&controller, &BrowserController::activeUrlChanged, &systemIntegration, offerActivePage);
    QObject::connect(&controller, &BrowserController::activeTitleChanged, &systemIntegration, offerActivePage);
    DownloadModel &downloads = DownloadModel::instance();
    QObject::connect(&downloads, &DownloadModel::progressChanged, &systemIntegration, [&downloads, &systemIntegration]() {
        systemIntegration.setActiveDownloads(downloads.activeCount());
    });

    listenForSecondLaunches(instanceServer, controller);
    UrlOpenFilter urlOpenFilter(controller);
    app.installEventFilter(&urlOpenFilter);
    for (const QString &url : launchUrls)
        controller.newTab(url);

    std::unique_ptr<QQmlApplicationEngine> engine;
    bool shuttingDown = false;
    QObject::connect(&app, &QCoreApplication::aboutToQuit, [&controller, &engine, &shuttingDown]() {
        if (std::exchange(shuttingDown, true))
            return;
        controller.saveSession();

        CefManager::instance().closeAllBrowsers();
        controller.destroyAdoptedWindows();
        engine.reset();
        CefManager::shutdown();
    });
    engine = std::make_unique<QQmlApplicationEngine>();
    engine->addImportPath("qrc:/");

    QObject::connect(
        engine.get(), &QQmlApplicationEngine::warnings,
        [](const QList<QQmlError> &warnings)
        {
            for (const QQmlError &w : warnings)
                BrowserLogger::instance().warning("QML", w.toString());
        });

    const QUrl root("qrc:/illuminate/ui/pages/BrowserWindow.qml");
    QObject::connect(
        engine.get(), &QQmlApplicationEngine::objectCreated,
        &app, [&](QObject *obj, const QUrl &url)
        {
            if (url != root) return;
            if (!obj) {
                BrowserLogger::instance().error("Main", "Root QML object failed to create — exiting");
                QCoreApplication::exit(1);
                return;
            } },
        Qt::QueuedConnection);

    BrowserLogger::instance().info("Main", "Loading root QML: " + root.toString());

    engine->load(root);

    const int exitCode = app.exec();
    BrowserLogger::instance().info("Main", QString("Event loop exited with code %1").arg(exitCode));
    return exitCode;
}
