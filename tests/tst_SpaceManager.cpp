#include <QtTest>
#include <QPointer>

#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTemporaryDir>

#include "BookmarkModel.h"
#include "BrowserController.h"
#include "SidebarModel.h"
#include "Space.h"
#include "SpaceManager.h"
#include "BrowserTab.h"

// Spaces organise the sidebar; they do not isolate anything else. These cover
// the list itself and what switching one does to folders, tabs and bookmarks.
class TestSpaceManager : public QObject
{
    Q_OBJECT

    QTemporaryDir m_dir;

private slots:
    void initTestCase()
    {
        QVERIFY(m_dir.isValid());
        // keep the real ~/.illuminate out of reach
        Space::setSpacesRootDir(m_dir.path());
    }

    void cleanupTestCase()
    {
        Space::setSpacesRootDir(QString());
    }

    void init()
    {
        // each test starts from a clean install
        QDir(m_dir.path()).removeRecursively();
        QDir().mkpath(m_dir.path());
    }

    void aFreshInstallHasOneSpace()
    {
        SpaceManager spaces(nullptr);
        QCOMPARE(spaces.spaces().size(), 1);
        QVERIFY(spaces.activeSpace());
        QCOMPARE(spaces.activeSpace()->name(), QStringLiteral("Default"));
    }

    void spacesAndTheActiveOneSurviveARestart()
    {
        QString activeId;
        {
            SpaceManager spaces(nullptr);
            spaces.createSpace(QStringLiteral("Work"), QColor(QStringLiteral("#2DA7A1")));
            spaces.createSpace(QStringLiteral("Play"));
            spaces.activeSpace()->setName(QStringLiteral("Renamed"));
            spaces.activeSpace()->setColor(QColor(QStringLiteral("#E86F67")));
            activeId = spaces.activeSpace()->id();
        }

        SpaceManager spaces(nullptr);
        QCOMPARE(spaces.spaces().size(), 3);
        QCOMPARE(spaces.activeSpace()->id(), activeId);
        QCOMPARE(spaces.activeSpace()->name(), QStringLiteral("Renamed"));
        QCOMPARE(spaces.activeSpace()->color(), QColor(QStringLiteral("#E86F67")));
        QCOMPARE(spaces.spaceById(activeId), spaces.activeSpace());
    }

    void themeColorSurvivesARestart()
    {
        {
            SpaceManager spaces(nullptr);
            spaces.activeSpace()->setThemeColor(QColor(QStringLiteral("#33aa66")));
            spaces.createSpace(QStringLiteral("Plain"));
        }

        SpaceManager spaces(nullptr);
        QCOMPARE(spaces.spaces().at(0).value<Space *>()->themeColor(), QColor(QStringLiteral("#33aa66")));
        QVERIFY(!spaces.spaces().at(1).value<Space *>()->themeColor().isValid());
    }

    // From before themes became a single seed: a colour set per mode still
    // carries its accent over; a palette name alone no longer means anything
    void oldColourSetsBecomeSeedsAndPaletteNamesAreIgnored()
    {
        const QString file = Space::dataDir() + QDir::separator() + QStringLiteral("spaces.json");
        QDir().mkpath(Space::dataDir());
        QFile out(file);
        QVERIFY(out.open(QIODevice::WriteOnly));
        auto space = [](const QString &id, const QString &palette) {
            QJsonObject obj;
            obj[QStringLiteral("id")] = id;
            obj[QStringLiteral("name")] = palette;
            obj[QStringLiteral("color")] = QStringLiteral("#4A90E2");
            obj[QStringLiteral("themePalette")] = palette;
            return obj;
        };
        QJsonObject custom = space(QStringLiteral("33333333-3333-3333-3333-333333333333"), QStringLiteral("violet"));
        custom[QStringLiteral("themeColors")] = QJsonObject{
            {QStringLiteral("light"), QJsonObject{{QStringLiteral("accent"), QStringLiteral("#2e8b57")}}},
            {QStringLiteral("dark"), QJsonObject{{QStringLiteral("accent"), QStringLiteral("#8fd4ad")}}}
        };
        const QJsonArray list{
            space(QStringLiteral("11111111-1111-1111-1111-111111111111"), QStringLiteral("blue")),
            space(QStringLiteral("22222222-2222-2222-2222-222222222222"), QStringLiteral("violet")),
            custom
        };
        out.write(QJsonDocument(QJsonObject{{QStringLiteral("version"), 1},
                                            {QStringLiteral("spaces"), list}}).toJson());
        out.close();

        SpaceManager spaces(nullptr);
        QCOMPARE(spaces.spaces().size(), 3);
        // palette names alone: the default theme
        QVERIFY(!spaces.spaces().at(0).value<Space *>()->themeColor().isValid());
        QVERIFY(!spaces.spaces().at(1).value<Space *>()->themeColor().isValid());

        // a colour set wins over any palette name next to it
        const QColor customSeed = spaces.spaces().at(2).value<Space *>()->themeColor();
        QVERIFY(customSeed.isValid());
        QVERIFY(qAbs(customSeed.hslHue() - QColor(QStringLiteral("#2e8b57")).hslHue()) <= 1);
        // the spaces themselves still load, names and all
        QCOMPARE(spaces.spaces().at(1).value<Space *>()->name(), QStringLiteral("violet"));
    }

    void eachSpaceGetsItsOwnStorageDirectory()
    {
        SpaceManager spaces(nullptr);
        Space *work = spaces.createSpace(QStringLiteral("Work"));
        Space *play = spaces.createSpace(QStringLiteral("Play"));

        QVERIFY(!work->storageDir().isEmpty());
        QVERIFY(work->storageDir() != play->storageDir());
        QVERIFY(QDir(work->storageDir()).exists());
        QVERIFY(work->sidebarFilePath() != play->sidebarFilePath());
    }

    void theLastSpaceCannotBeDeleted()
    {
        SpaceManager spaces(nullptr);
        spaces.deleteSpace(spaces.activeSpace());
        QCOMPARE(spaces.spaces().size(), 1);
        QVERIFY(spaces.activeSpace());
    }

    void deletingTheActiveSpaceMovesToItsNeighbour()
    {
        SpaceManager spaces(nullptr);
        Space *first = spaces.createSpace(QStringLiteral("First"));
        Space *second = spaces.createSpace(QStringLiteral("Second"));
        spaces.setActiveSpace(second);

        spaces.deleteSpace(second);
        QCOMPARE(spaces.spaces().size(), 2);
        QCOMPARE(spaces.activeSpace(), first);
    }

    void cyclingWrapsAround()
    {
        SpaceManager spaces(nullptr);
        Space *a = spaces.activeSpace();
        Space *b = spaces.createSpace(QStringLiteral("B"));
        Space *c = spaces.createSpace(QStringLiteral("C"));

        spaces.cycleSpace(1);
        QCOMPARE(spaces.activeSpace(), b);
        spaces.cycleSpace(1);
        QCOMPARE(spaces.activeSpace(), c);
        spaces.cycleSpace(1);
        QCOMPARE(spaces.activeSpace(), a);
        spaces.cycleSpace(-1);
        QCOMPARE(spaces.activeSpace(), c);
    }

    void eachSpaceKeepsItsOwnFoldersAndTabs()
    {
        SpaceManager spaces(nullptr);
        Space *personal = spaces.activeSpace();
        Space *work = spaces.createSpace(QStringLiteral("Work"));

        BrowserController browser(personal, nullptr, m_dir.filePath(QStringLiteral("browser-settings.ini")));
        // main.cpp wires the two together; the test does the same by hand
        QObject::connect(&spaces, &SpaceManager::activeSpaceChanged,
                         &spaces, [&]() { browser.setActiveSpace(spaces.activeSpace()); });

        SidebarModel *sidebar = browser.sidebar();
        browser.newTab(QStringLiteral("https://example.com/personal"));
        sidebar->createFolder({}, QStringLiteral("Personal"));
        QCOMPARE(sidebar->folderCount(), 1);

        spaces.setActiveSpace(work);
        QCOMPARE(browser.space(), work);
        // the new space has nothing of its own, so it shows nothing
        QCOMPARE(sidebar->folderCount(), 0);

        // and going back finds the first space's folder where it was left
        spaces.setActiveSpace(personal);
        QCOMPARE(browser.space(), personal);
        QCOMPARE(sidebar->folderCount(), 1);
        QCOMPARE(sidebar->index(0).data(SidebarModel::TitleRole).toString(),
                 QStringLiteral("Personal"));
    }

    // a folder with tabs in it, there and back: the folder and its tabs come
    // back with their space, and never show in a space without folders
    void foldersWithTabsStayInTheirOwnSpace()
    {
        SpaceManager spaces(nullptr);
        Space *personal = spaces.activeSpace();
        Space *work = spaces.createSpace(QStringLiteral("Work"));

        BrowserController browser(personal, nullptr, m_dir.filePath(QStringLiteral("browser-settings.ini")));
        QObject::connect(&spaces, &SpaceManager::activeSpaceChanged,
                         &spaces, [&]() { browser.setActiveSpace(spaces.activeSpace()); });

        SidebarModel *sidebar = browser.sidebar();
        browser.newTab(QStringLiteral("https://example.com/filed"));
        BrowserTab *filed = browser.tabModel()->tabAt(browser.activeIndex());
        const QString folder = sidebar->createFolder({}, QStringLiteral("Reading"));
        sidebar->addToFolder(filed->id(), folder);
        QCOMPARE(sidebar->folderCount(), 1);

        const auto kinds = [sidebar]() {
            QStringList out;
            for (int i = 0; i < sidebar->rowCount(); ++i)
                out << sidebar->index(i).data(SidebarModel::KindRole).toString();
            return out;
        };

        spaces.setActiveSpace(work);
        QCOMPARE(sidebar->folderCount(), 0);
        QVERIFY2(!kinds().contains(QStringLiteral("folder")), qPrintable(kinds().join(',')));
        for (int i = 0; i < browser.tabModel()->rowCount(); ++i)
            QVERIFY(browser.tabModel()->tabAt(i)->url() != QUrl(QStringLiteral("https://example.com/filed")));

        spaces.setActiveSpace(personal);
        QCOMPARE(sidebar->folderCount(), 1);
        QCOMPARE(kinds().count(QStringLiteral("folder")), 1);
        // the folder's tab came back with it, alive and in the tab model
        bool found = false;
        for (int i = 0; i < browser.tabModel()->rowCount(); ++i)
            found = found || browser.tabModel()->tabAt(i)->url() == QUrl(QStringLiteral("https://example.com/filed"));
        QVERIFY(found);
        QCOMPARE(sidebar->index(1).data(SidebarModel::UrlRole).toUrl(), QUrl(QStringLiteral("https://example.com/filed")));

        spaces.setActiveSpace(work);
        QCOMPARE(sidebar->folderCount(), 0);
        QVERIFY2(!kinds().contains(QStringLiteral("folder")), qPrintable(kinds().join(',')));
    }

    // the page kept ready for a space runs in that space's own profile
    void eachSpaceHasItsOwnProfile()
    {
        SpaceManager spaces(nullptr);
        Space *personal = spaces.activeSpace();
        Space *work = spaces.createSpace(QStringLiteral("Work"));
        BrowserController browser(personal, nullptr, m_dir.filePath(QStringLiteral("browser-settings.ini")));
        QCOMPARE(browser.profileForSpace(personal), browser.webProfile());
        QVERIFY(browser.profileForSpace(work) != browser.profileForSpace(personal));
        QCOMPARE(browser.profileForSpace(work), browser.profileForSpace(work));
        QCOMPARE(browser.profileForSpace(nullptr), browser.webProfile());
    }

    // the outgoing space's page can only be kept if it's still there to keep
    void spaceAboutToChangeComesWhileTheOldSpaceIsStillShowing()
    {
        SpaceManager spaces(nullptr);
        Space *personal = spaces.activeSpace();
        Space *work = spaces.createSpace(QStringLiteral("Work"));
        BrowserController browser(personal, nullptr, m_dir.filePath(QStringLiteral("browser-settings.ini")));
        browser.newTab(QStringLiteral("https://example.com/kept"));

        Space *spaceAtSignal = nullptr;
        QString urlAtSignal;
        int tabsAtSignal = 0;
        QObject::connect(&browser, &BrowserController::spaceAboutToChange, &browser, [&]() {
            spaceAtSignal = browser.space();
            urlAtSignal = browser.activeUrl();
            tabsAtSignal = browser.tabModel()->rowCount();
        });
        browser.setActiveSpace(work);

        QCOMPARE(spaceAtSignal, personal);
        QCOMPARE(urlAtSignal, QStringLiteral("https://example.com/kept"));
        QVERIFY(tabsAtSignal >= 1);
        // and what was in front is what the space remembers
        QCOMPARE(personal->lastActiveUrl(), QStringLiteral("https://example.com/kept"));
    }

    // coming back to a space finds the very same tabs, in order, without
    // reading them back; the one in front is ready, the rest load when opened
    void aSpaceComesBackWithItsOwnTabs()
    {
        SpaceManager spaces(nullptr);
        Space *personal = spaces.activeSpace();
        Space *work = spaces.createSpace(QStringLiteral("Work"));
        BrowserController browser(personal, nullptr, m_dir.filePath(QStringLiteral("browser-settings.ini")));
        QObject::connect(&spaces, &SpaceManager::activeSpaceChanged,
                         &spaces, [&]() { browser.setActiveSpace(spaces.activeSpace()); });

        browser.newTab(QStringLiteral("https://example.com/one"));
        browser.newTab(QStringLiteral("https://example.com/two"));
        browser.newTab(QStringLiteral("https://example.com/three"));
        browser.activateTab(2);
        QList<BrowserTab *> before;
        for (int i = 0; i < browser.tabModel()->rowCount(); ++i)
            before << browser.tabModel()->tabAt(i);
        BrowserTab *two = browser.tabModel()->tabAt(2);
        two->setLoading(true);
        two->setAudible(true);
        browser.tabModel()->tabAt(3)->setAudible(true);

        spaces.setActiveSpace(work);
        QVERIFY(browser.hasResidentTabs(personal->id()));
        for (BrowserTab *tab : before)
            QVERIFY(browser.tabModel()->indexOf(tab) < 0);

        spaces.setActiveSpace(personal);
        QVERIFY(!browser.hasResidentTabs(personal->id()));
        QCOMPARE(browser.tabModel()->rowCount(), before.size());
        for (int i = 0; i < before.size(); ++i)
            QCOMPARE(browser.tabModel()->tabAt(i), before.at(i));
        QCOMPARE(browser.activeIndex(), 2);
        QCOMPARE(browser.activeUrl(), QStringLiteral("https://example.com/two"));

        // their pages went with their views: nothing still spinning or playing
        QVERIFY(!two->loading());
        QVERIFY(!two->audible());
        QVERIFY(!browser.tabModel()->tabAt(3)->audible());
        // the one in front is awake, the others wait to be opened
        QVERIFY(!two->suspended());
        QVERIFY(browser.tabModel()->tabAt(1)->suspended());
        QVERIFY(browser.tabModel()->tabAt(3)->suspended());
    }

    void aDeletedSpaceLetsGoOfItsTabs()
    {
        SpaceManager spaces(nullptr);
        Space *personal = spaces.activeSpace();
        Space *work = spaces.createSpace(QStringLiteral("Work"));
        BrowserController browser(personal, nullptr, m_dir.filePath(QStringLiteral("browser-settings.ini")));
        browser.newTab(QStringLiteral("https://example.com/left"));
        QPointer<BrowserTab> left = browser.tabModel()->tabAt(1);

        browser.setActiveSpace(work);
        QVERIFY(browser.hasResidentTabs(personal->id()));
        browser.keepResidentSpaces({work->id()});
        QVERIFY(!browser.hasResidentTabs(personal->id()));
        QVERIFY(left.isNull());
    }

    void bookmarksFollowTheActiveSpace()
    {
        SpaceManager spaces(nullptr);
        Space *personal = spaces.activeSpace();
        Space *work = spaces.createSpace(QStringLiteral("Work"));

        BookmarkModel bookmarks(nullptr);
        bookmarks.setSpace(personal);
        bookmarks.toggleBookmark(QStringLiteral("Personal site"), QStringLiteral("https://example.com/a"));
        QCOMPARE(bookmarks.rowCount(), 1);

        bookmarks.setSpace(work);
        QCOMPARE(bookmarks.rowCount(), 0);
        bookmarks.toggleBookmark(QStringLiteral("Work site"), QStringLiteral("https://example.com/b"));
        QCOMPARE(bookmarks.rowCount(), 1);
        QVERIFY(!bookmarks.isBookmarked(QStringLiteral("https://example.com/a")));

        bookmarks.setSpace(personal);
        QCOMPARE(bookmarks.rowCount(), 1);
        QVERIFY(bookmarks.isBookmarked(QStringLiteral("https://example.com/a")));
        QVERIFY(!bookmarks.isBookmarked(QStringLiteral("https://example.com/b")));
    }
};

QTEST_GUILESS_MAIN(TestSpaceManager)
#include "tst_SpaceManager.moc"
