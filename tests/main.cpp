#include <QtQuickTest>
#include <QApplication>
#include <QDir>
#include <QObject>
#include <QTemporaryDir>
#include <QQmlContext>
#include <QQmlEngine>
#include <QSettings>

#include "BookmarkModel.h"
#include "DownloadModel.h"
#include "BrowserController.h"
#include "BrowserSettings.h"
#include "ShortcutRegistry.h"
#include "Space.h"
#include "SystemIntegration.h"

class Setup : public QObject
{
    Q_OBJECT

    QTemporaryDir m_dir;
    Space *m_space = nullptr;
    BrowserController *m_browser = nullptr;
    BrowserSettings *m_prefs = nullptr;
    BookmarkModel *m_bookmarks = nullptr;
    ShortcutRegistry *m_shortcuts = nullptr;
    SystemIntegration *m_system = nullptr;

public:
    ~Setup() override
    {
        BrowserController::setQmlInstance(nullptr);
        BrowserSettings::setQmlInstance(nullptr);
        BookmarkModel::setQmlInstance(nullptr);
        ShortcutRegistry::setQmlInstance(nullptr);
        SystemIntegration::setQmlInstance(nullptr);
        delete m_system;
        delete m_shortcuts;
        delete m_bookmarks;
        delete m_prefs;
        delete m_browser;
        m_browser = nullptr;
        delete m_space;
        m_space = nullptr;
    }

public slots:
    void applicationAvailable()
    {
        QCoreApplication::setOrganizationName("illuminate");
        QCoreApplication::setOrganizationDomain("illuminate.local");
        QCoreApplication::setApplicationName("qmltests");
        // keep every QSettings write in the scratch directory
        QSettings::setDefaultFormat(QSettings::IniFormat);
        QSettings::setPath(QSettings::IniFormat, QSettings::UserScope, m_dir.filePath(QStringLiteral("settings")));

        m_space = new Space(QStringLiteral("qml-test-space"), QStringLiteral("QML Tests"),
                            QColor(QStringLiteral("#345678")), this);
        m_space->setStorageDir(m_dir.filePath(QStringLiteral("space")));
        QDir().mkpath(m_space->storageDir());
        m_browser = new BrowserController(m_space, this,
                                           m_dir.filePath(QStringLiteral("browser-settings.ini")));
        BrowserController::setQmlInstance(m_browser);

        // the singletons main() registers, so components can be created, not just compiled
        m_prefs = new BrowserSettings(nullptr, m_dir.filePath(QStringLiteral("prefs.ini")));
        BrowserSettings::setQmlInstance(m_prefs);
        m_bookmarks = new BookmarkModel(nullptr);
        m_bookmarks->setSpace(m_space);
        BookmarkModel::setQmlInstance(m_bookmarks);
        m_shortcuts = new ShortcutRegistry(nullptr);
        ShortcutRegistry::setQmlInstance(m_shortcuts);
        m_system = new SystemIntegration(nullptr);
        SystemIntegration::setQmlInstance(m_system);
    }

    // the app's QML module is linked in statically; its qmldir lives at
    // qrc:/illuminate/ui, so tests can `import illuminate.ui`
    void qmlEngineAvailable(QQmlEngine *engine)
    {
        engine->addImportPath(QStringLiteral("qrc:/"));
        // the list CefDownloadHandler feeds, to check QML's Downloads is the same one
        engine->rootContext()->setContextProperty(QStringLiteral("cppDownloads"), &DownloadModel::instance());
    }
};

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    Setup setup;
    return quick_test_main_with_setup(argc, argv, "qmltests",
                                      QUICK_TEST_SOURCE_DIR, &setup);
}

#include "main.moc"
