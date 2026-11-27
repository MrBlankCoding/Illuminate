#include <QtTest>
#include <QDir>
#include <QSettings>
#include <QTemporaryDir>
#include <QFile>

#include <memory>

#include "BrowserController.h"
#include "BrowserTab.h"
#include "SidebarModel.h"
#include "Space.h"

class TestBrowserController : public QObject
{
    Q_OBJECT

    QTemporaryDir m_dir;

    // a space backed by a scratch directory, so nothing touches ~/.illuminate
    Space *makeSpace(const QString &id, const QString &name)
    {
        auto *space = new Space(id, name, QColor(QStringLiteral("#4A90E2")));
        space->setStorageDir(m_dir.filePath(id));
        return space;
    }

private slots:
    void initTestCase()
    {
        QVERIFY(m_dir.isValid());
        QSettings::setDefaultFormat(QSettings::IniFormat);
        QSettings::setPath(QSettings::IniFormat, QSettings::UserScope, m_dir.path());
        QCoreApplication::setOrganizationName(QStringLiteral("illuminate_tests"));
        QCoreApplication::setApplicationName(QStringLiteral("tst_browsercontroller"));
    }

    void init()
    {
        QFile::remove(m_dir.filePath(QStringLiteral("browser-settings.ini")));
        QSettings().clear();
    }

    void sessionSaveRestoresTabsAndActivePage()
    {
        std::unique_ptr<Space> space(makeSpace(QStringLiteral("session-roundtrip"), QStringLiteral("Session")));
        BrowserController first(space.get(), nullptr, m_dir.filePath(QStringLiteral("session-settings.ini")));
        first.newTab(QStringLiteral("https://one.example/"));
        first.newTab(QStringLiteral("https://background.example/"), true);
        first.newTab(QStringLiteral("https://two.example/"));
        first.saveSession();

        BrowserController restored(space.get(), nullptr, m_dir.filePath(QStringLiteral("restored-settings.ini")));

        QCOMPARE(restored.tabModel()->rowCount(), 4);
        QCOMPARE(restored.activeUrl(), QStringLiteral("https://two.example/"));
        QVERIFY(restored.tabModel()->tabAt(1)->suspended());
        QVERIFY(restored.tabModel()->tabAt(2)->suspended());
        QVERIFY(!restored.tabModel()->tabAt(3)->suspended());
    }

    void corruptSessionFallsBackToInitialTab()
    {
        std::unique_ptr<Space> space(makeSpace(QStringLiteral("session-corrupt"), QStringLiteral("Corrupt")));
        QFile file(space->sessionFilePath());
        QVERIFY(QDir().mkpath(space->storageDir()));
        QVERIFY(file.open(QIODevice::WriteOnly));
        file.write("{ invalid json");
        file.close();

        BrowserController browser(space.get(), nullptr, m_dir.filePath(QStringLiteral("corrupt-settings.ini")));

        QCOMPARE(browser.tabModel()->rowCount(), 1);
        QVERIFY(!browser.activeUrl().isEmpty());
    }

    void themeColorPreviewsSavesAndResets()
    {
        std::unique_ptr<Space> space(makeSpace(QStringLiteral("theme-test"), QStringLiteral("Theme Test")));
        BrowserController browser(space.get(), nullptr, m_dir.filePath(QStringLiteral("browser-settings.ini")));
        QSignalSpy colorSpy(&browser, &BrowserController::themeColorChanged);
        QSignalSpy saveSpy(space.get(), &Space::themeChanged);
        QVERIFY(!browser.themeColor().isValid());

        const QColor seed = QColor::fromHslF(0.3f, 0.8f, 0.5f);
        browser.previewThemeColor(seed);
        QCOMPARE(browser.themeColor(), seed);
        QCOMPARE(colorSpy.size(), 1);
        QCOMPARE(saveSpy.size(), 0);

        // the release after a drag saves the colour the preview already shows
        browser.setThemeColor(seed);
        QCOMPARE(colorSpy.size(), 1);
        QCOMPARE(saveSpy.size(), 1);

        browser.setThemeColor(QColor());
        QCOMPARE(browser.themeColor(), seed);

        browser.resetThemeColor();
        QVERIFY(!browser.themeColor().isValid());
        QCOMPARE(colorSpy.size(), 2);
        QCOMPARE(saveSpy.size(), 2);
        browser.resetThemeColor();
        QCOMPARE(colorSpy.size(), 2);
    }

    void themeColorFollowsTheActiveSpace()
    {
        std::unique_ptr<Space> work(makeSpace(QStringLiteral("theme-work"), QStringLiteral("Work")));
        std::unique_ptr<Space> play(makeSpace(QStringLiteral("theme-play"), QStringLiteral("Play")));
        play->setThemeColor(QColor(QStringLiteral("#cc3366")));
        BrowserController browser(work.get(), nullptr, m_dir.filePath(QStringLiteral("browser-settings.ini")));
        QSignalSpy colorSpy(&browser, &BrowserController::themeColorChanged);

        browser.setActiveSpace(play.get());
        QCOMPARE(browser.themeColor(), QColor(QStringLiteral("#cc3366")));
        QVERIFY(colorSpy.size() >= 1);
    }

    void closingTheActiveTabDoesNotRequestAWindowClose()
    {
        std::unique_ptr<Space> space(makeSpace(QStringLiteral("close-test"), QStringLiteral("Close Test")));
        BrowserController browser(space.get(), nullptr, m_dir.filePath(QStringLiteral("browser-settings.ini")));
        browser.newTab(QStringLiteral("https://example.com/a"));
        browser.newTab(QStringLiteral("https://example.com/b"));
        QCOMPARE(browser.tabModel()->rowCount(), 3);

        browser.activateTab(1);
        QCOMPARE(browser.activeIndex(), 1);

        QSignalSpy closeSpy(&browser, &BrowserController::closeWindowRequested);
        browser.closeTab(browser.activeIndex());

        QCOMPARE(browser.tabModel()->rowCount(), 2);
        QCOMPARE(closeSpy.size(), 0);
    }

    void closeOtherTabsClosesEveryOtherTab()
    {
        std::unique_ptr<Space> space(makeSpace(QStringLiteral("close-others"), QStringLiteral("Close Others")));
        BrowserController browser(space.get(), nullptr, m_dir.filePath(QStringLiteral("browser-settings.ini")));
        for (int i = 0; i < 6; ++i)
            browser.newTab(QStringLiteral("https://example.com/%1").arg(i), true);
        browser.newTab(QStringLiteral("https://example.com/keep"));
        const int keepIndex = browser.tabModel()->rowCount() - 1;
        const QString keepId = browser.tabModel()->tabAt(keepIndex)->id();
        QVERIFY(browser.tabModel()->rowCount() >= 7);

        browser.closeOtherTabs(keepIndex);

        QCOMPARE(browser.tabModel()->rowCount(), 1);
        QCOMPARE(browser.tabModel()->tabAt(0)->id(), keepId);
        QCOMPARE(browser.activeIndex(), 0);
    }

    void reopenClosedTabRestoresMostRecentlyClosedPage()
    {
        std::unique_ptr<Space> space(makeSpace(QStringLiteral("reopen-test"), QStringLiteral("Reopen Test")));
        BrowserController browser(space.get(), nullptr, m_dir.filePath(QStringLiteral("browser-settings.ini")));
        browser.newTab(QStringLiteral("https://example.com/first"));
        browser.newTab(QStringLiteral("https://example.com/second"));
        const int closedIndex = browser.activeIndex();
        browser.closeTab(closedIndex);
        QCOMPARE(browser.tabModel()->rowCount(), 2);

        browser.reopenLastClosedTab();
        QCOMPARE(browser.tabModel()->rowCount(), 3);
        QCOMPARE(browser.tabModel()->tabAt(browser.activeIndex())->url(), QUrl(QStringLiteral("https://example.com/second")));
    }

    void reopenedTabReturnsToItsPlace()
    {
        std::unique_ptr<Space> space(makeSpace(QStringLiteral("reopen-place"), QStringLiteral("Reopen Place")));
        BrowserController browser(space.get(), nullptr, m_dir.filePath(QStringLiteral("browser-settings.ini")));
        for (int i = 0; i < 4; ++i)
            browser.newTab(QStringLiteral("https://example.com/%1").arg(i));

        const int index = 1;
        const QUrl url = browser.tabModel()->tabAt(index)->url();
        browser.activateTab(index);
        browser.closeTab(index);
        browser.reopenLastClosedTab();
        QCOMPARE(browser.tabModel()->tabAt(index)->url(), url);
        QCOMPARE(browser.activeIndex(), index);
    }

    void reopenedTabReturnsToItsFolder()
    {
        std::unique_ptr<Space> space(makeSpace(QStringLiteral("reopen-folder"), QStringLiteral("Reopen Folder")));
        BrowserController browser(space.get(), nullptr, m_dir.filePath(QStringLiteral("browser-settings.ini")));
        browser.newTab(QStringLiteral("https://example.com/a"));
        browser.newTab(QStringLiteral("https://example.com/b"));
        browser.newTab(QStringLiteral("https://example.com/c"));
        SidebarModel *sidebar = browser.sidebar();
        const QString folder = sidebar->createFolder({}, QStringLiteral("Work"));
        const QString a = browser.tabModel()->tabAt(1)->id();
        const QString b = browser.tabModel()->tabAt(2)->id();
        QVERIFY(sidebar->moveNode(a, folder, 0));
        QVERIFY(sidebar->moveNode(b, folder, 1));
        QCOMPARE(sidebar->placementOf(b), qMakePair(folder, 1));

        BrowserTab *tab = browser.tabModel()->tabAt(2);
        QCOMPARE(tab->id(), b);
        browser.closeTab(2);
        browser.reopenLastClosedTab();

        BrowserTab *reopened = browser.tabModel()->tabAt(browser.activeIndex());
        QCOMPARE(reopened->url(), QUrl(QStringLiteral("https://example.com/b")));
        QCOMPARE(sidebar->placementOf(reopened->id()), qMakePair(folder, 1));
    }

    void initialControllerHasAnInitialTab()
    {
        std::unique_ptr<Space> space(makeSpace(QStringLiteral("initial-tab"), QStringLiteral("Initial")));
        BrowserController browser(space.get(), nullptr, m_dir.filePath(QStringLiteral("browser-settings.ini")));
        QCOMPARE(browser.tabModel()->rowCount(), 1);
        QCOMPARE(browser.activeIndex(), 0);
        QCOMPARE(browser.activeUrl(), QStringLiteral("illuminate://setup"));
        QCOMPARE(browser.activeTitle(), QStringLiteral("New Tab"));
        QVERIFY(browser.isFirstRun());
    }

    void backgroundTabDoesNotStealSelection()
    {
        std::unique_ptr<Space> space(makeSpace(QStringLiteral("background-tab"), QStringLiteral("Background")));
        BrowserController browser(space.get(), nullptr, m_dir.filePath(QStringLiteral("browser-settings.ini")));
        const int activeBefore = browser.activeIndex();

        browser.newTab(QStringLiteral("https://background.example/path"), true);

        QCOMPARE(browser.activeIndex(), activeBefore);
        QCOMPARE(browser.tabModel()->rowCount(), 2);
        const BrowserTab *background = browser.tabModel()->tabAt(1);
        QVERIFY(background->suspended());
        QCOMPARE(background->url(), QUrl(QStringLiteral("https://background.example/path")));
        QCOMPARE(background->title(), QStringLiteral("background.example"));
    }

    void activatingTabAtVisualPositionUsesSidebarOrder()
    {
        std::unique_ptr<Space> space(makeSpace(QStringLiteral("visual-order"), QStringLiteral("Visual")));
        BrowserController browser(space.get(), nullptr, m_dir.filePath(QStringLiteral("browser-settings.ini")));
        browser.newTab(QStringLiteral("https://one.example"));
        browser.newTab(QStringLiteral("https://two.example"));
        const QList<int> order = browser.sidebar()->visualTabOrder();
        QVERIFY(order.size() >= 3);

        browser.activateTabAt(1);

        QCOMPARE(browser.activeIndex(), order.at(1));
        browser.activateTabAt(-1);
        QCOMPARE(browser.activeIndex(), order.last());
    }

    void invalidTabActivationIsIgnored()
    {
        std::unique_ptr<Space> space(makeSpace(QStringLiteral("invalid-activation"), QStringLiteral("Invalid")));
        BrowserController browser(space.get(), nullptr, m_dir.filePath(QStringLiteral("browser-settings.ini")));
        QSignalSpy spy(&browser, &BrowserController::activeIndexChanged);
        browser.activateTab(-1);
        browser.activateTab(browser.tabModel()->rowCount());
        QCOMPARE(browser.activeIndex(), 0);
        QCOMPARE(spy.size(), 0);
    }

    void closeInactiveTabPreservesActiveTab()
    {
        std::unique_ptr<Space> space(makeSpace(QStringLiteral("close-inactive"), QStringLiteral("Close")));
        BrowserController browser(space.get(), nullptr, m_dir.filePath(QStringLiteral("browser-settings.ini")));
        browser.newTab(QStringLiteral("https://first.example"));
        browser.newTab(QStringLiteral("https://second.example"));
        const int active = browser.activeIndex();
        const QString activeUrl = browser.activeUrl();
        QSignalSpy navigationSpy(&browser, &BrowserController::navigationRequested);

        browser.closeTab(0);

        QCOMPARE(browser.tabModel()->rowCount(), 2);
        QCOMPARE(browser.activeUrl(), activeUrl);
        QCOMPARE(browser.activeIndex(), active - 1);
        QCOMPARE(navigationSpy.size(), 0);
    }

    void firstRunCompletionReplacesSetupWithNewTab()
    {
        std::unique_ptr<Space> space(makeSpace(QStringLiteral("finish-setup"), QStringLiteral("Setup")));
        BrowserController browser(space.get(), nullptr, m_dir.filePath(QStringLiteral("browser-settings.ini")));
        QSignalSpy firstRunSpy(&browser, &BrowserController::firstRunChanged);
        QSignalSpy newTabSpy(&browser, &BrowserController::newTabOpened);

        browser.completeFirstRun();

        QVERIFY(!browser.isFirstRun());
        QCOMPARE(browser.activeUrl(), QStringLiteral("newtab://newtab"));
        QCOMPARE(firstRunSpy.size(), 1);
        QCOMPARE(newTabSpy.size(), 1);
    }

    void tabMetadataCallbacksResolveStableIds()
    {
        std::unique_ptr<Space> space(makeSpace(QStringLiteral("tab-metadata"), QStringLiteral("Metadata")));
        BrowserController browser(space.get(), nullptr, m_dir.filePath(QStringLiteral("browser-settings.ini")));
        browser.newTab(QStringLiteral("https://first.example"));
        const BrowserTab *tab = browser.tabModel()->tabAt(browser.activeIndex());
        const QString tabId = tab->id();
        QSignalSpy titleSpy(&browser, &BrowserController::activeTitleChanged);
        QSignalSpy urlSpy(&browser, &BrowserController::activeUrlChanged);

        browser.updateTabTitle(tabId, QStringLiteral("First"));
        browser.updateTabUrl(tabId, QStringLiteral("https://updated.example"));
        browser.updateTabLoading(tabId, true);
        browser.updateTabProgress(tabId, 42);
        browser.updateTabIcon(tabId, QStringLiteral("icon://updated"));
        browser.updateTabRenderProcessPid(tabId, 1024);

        QCOMPARE(browser.activeTitle(), QStringLiteral("First"));
        QCOMPARE(browser.activeUrl(), QStringLiteral("https://updated.example"));
        QVERIFY(browser.activeLoading());
        QCOMPARE(browser.activeProgress(), 42);
        QCOMPARE(browser.activeIconUrl(), QStringLiteral("icon://updated"));
        QCOMPARE(tab->renderProcessPid(), qint64(1024));
        QCOMPARE(titleSpy.size(), 1);
        QVERIFY(urlSpy.size() >= 1);
    }

    void unknownTabIdsAndInvalidIndicesDoNotCrashOrMutateState()
    {
        std::unique_ptr<Space> space(makeSpace(QStringLiteral("invalid-callbacks"), QStringLiteral("Invalid")));
        BrowserController browser(space.get(), nullptr, m_dir.filePath(QStringLiteral("browser-settings.ini")));
        browser.onTitleChanged(-1, QStringLiteral("No tab"));
        browser.onUrlChanged(99, QStringLiteral("https://invalid.example"));
        browser.updateTabTitle(QStringLiteral("missing"), QStringLiteral("No tab"));
        browser.updateTabUrl(QStringLiteral("missing"), QStringLiteral("https://invalid.example"));
        browser.updateTabLoading(QStringLiteral("missing"), true);
        browser.updateTabProgress(QStringLiteral("missing"), 99);
        browser.updateTabIcon(QStringLiteral("missing"), QStringLiteral("icon"));
        browser.updateTabRenderProcessPid(QStringLiteral("missing"), 88);
        QCOMPARE(browser.tabModel()->rowCount(), 1);
        QCOMPARE(browser.activeUrl(), QStringLiteral("illuminate://setup"));
    }

    // closing a tab: a live page is asked first (beforeunload) and reports back
    // through onTabCloseApproved(); pages without a web view close straight away

    void tabsWithoutALivePageCloseImmediately()
    {
        std::unique_ptr<Space> space(makeSpace(QStringLiteral("close-now"), QStringLiteral("Close Now")));
        BrowserController browser(space.get(), nullptr, m_dir.filePath(QStringLiteral("browser-settings.ini")));
        browser.newTab(QStringLiteral("https://one.example"));
        browser.newTab(QStringLiteral("https://two.example"));
        QCOMPARE(browser.tabModel()->rowCount(), 3);

        browser.closeTab(1);
        QCOMPARE(browser.tabModel()->rowCount(), 2);
    }

    void approvedCloseRemovesThatTab()
    {
        std::unique_ptr<Space> space(makeSpace(QStringLiteral("close-approved"), QStringLiteral("Approved")));
        BrowserController browser(space.get(), nullptr, m_dir.filePath(QStringLiteral("browser-settings.ini")));
        browser.newTab(QStringLiteral("https://one.example"));
        browser.newTab(QStringLiteral("https://two.example"));
        const BrowserTab *active = browser.tabModel()->tabAt(browser.activeIndex());
        const QString doomed = browser.tabModel()->tabAt(1)->id();

        browser.onTabCloseApproved(doomed);

        QCOMPARE(browser.tabModel()->rowCount(), 2);
        for (int i = 0; i < browser.tabModel()->rowCount(); ++i)
            QVERIFY(browser.tabModel()->tabAt(i)->id() != doomed);
        QCOMPARE(browser.tabModel()->tabAt(browser.activeIndex()), active);
    }

    void approvedCloseOfTheActiveTabSelectsANeighbour()
    {
        std::unique_ptr<Space> space(makeSpace(QStringLiteral("close-active"), QStringLiteral("Active")));
        BrowserController browser(space.get(), nullptr, m_dir.filePath(QStringLiteral("browser-settings.ini")));
        browser.newTab(QStringLiteral("https://one.example"));
        browser.newTab(QStringLiteral("https://two.example"));
        const QString activeId = browser.tabModel()->tabAt(browser.activeIndex())->id();

        browser.onTabCloseApproved(activeId);

        QCOMPARE(browser.tabModel()->rowCount(), 2);
        const BrowserTab *nowActive = browser.tabModel()->tabAt(browser.activeIndex());
        QVERIFY(nowActive);
        QVERIFY(nowActive->id() != activeId);
    }

    // a page closing itself (window.close()) must not leave an empty tab behind
    void approvedCloseOfTheOnlyTabLeavesANewTabThatCanBeReopened()
    {
        std::unique_ptr<Space> space(makeSpace(QStringLiteral("close-only"), QStringLiteral("Only")));
        BrowserController browser(space.get(), nullptr, m_dir.filePath(QStringLiteral("browser-settings.ini")));
        browser.newTab(QStringLiteral("https://only.example/page"));
        browser.closeTab(0); // the setup page
        QTRY_COMPARE(browser.tabModel()->rowCount(), 1);
        QCoreApplication::processEvents();
        BrowserTab *only = browser.tabModel()->tabAt(0);
        QCOMPARE(only->url(), QUrl(QStringLiteral("https://only.example/page")));

        browser.onTabCloseApproved(only->id());

        QCOMPARE(browser.tabModel()->rowCount(), 1);
        QCOMPARE(browser.tabModel()->tabAt(0)->url(), QUrl(QStringLiteral("newtab://newtab")));
        QCoreApplication::processEvents();
        browser.reopenLastClosedTab();
        QCOMPARE(browser.tabModel()->tabAt(browser.activeIndex())->url(), QUrl(QStringLiteral("https://only.example/page")));
    }

    void approvedClosesCanBeReopened()
    {
        std::unique_ptr<Space> space(makeSpace(QStringLiteral("close-reopen"), QStringLiteral("Reopen")));
        BrowserController browser(space.get(), nullptr, m_dir.filePath(QStringLiteral("browser-settings.ini")));
        browser.newTab(QStringLiteral("https://kept.example"));
        browser.newTab(QStringLiteral("https://closed.example"));
        browser.onTabCloseApproved(browser.tabModel()->tabAt(2)->id());
        QCOMPARE(browser.tabModel()->rowCount(), 2);
        QCoreApplication::processEvents();

        browser.reopenLastClosedTab();
        QCOMPARE(browser.tabModel()->rowCount(), 3);
        QCOMPARE(browser.tabModel()->tabAt(browser.activeIndex())->url(), QUrl(QStringLiteral("https://closed.example")));
    }

    void approvalsForUnknownOrAlreadyClosedTabsAreIgnored()
    {
        std::unique_ptr<Space> space(makeSpace(QStringLiteral("close-stale"), QStringLiteral("Stale")));
        BrowserController browser(space.get(), nullptr, m_dir.filePath(QStringLiteral("browser-settings.ini")));
        browser.newTab(QStringLiteral("https://one.example"));
        browser.newTab(QStringLiteral("https://two.example"));
        const QString id = browser.tabModel()->tabAt(1)->id();

        browser.onTabCloseApproved(QStringLiteral("no-such-tab"));
        browser.onTabCloseApproved(QString());
        QCOMPARE(browser.tabModel()->rowCount(), 3);

        browser.onTabCloseApproved(id);
        QCOMPARE(browser.tabModel()->rowCount(), 2);
        QCoreApplication::processEvents();
        // the page's close can be reported again as its browser goes away
        browser.onTabCloseApproved(id);
        QCoreApplication::processEvents();
        QCOMPARE(browser.tabModel()->rowCount(), 2);
    }

    // the page is already gone by now; dropping this would leave an empty tab
    void approvalDuringAnotherCloseIsRetriedNotDropped()
    {
        std::unique_ptr<Space> space(makeSpace(QStringLiteral("close-retry"), QStringLiteral("Retry")));
        BrowserController browser(space.get(), nullptr, m_dir.filePath(QStringLiteral("browser-settings.ini")));
        browser.newTab(QStringLiteral("https://one.example"));
        browser.newTab(QStringLiteral("https://two.example"));
        browser.newTab(QStringLiteral("https://three.example"));
        const QString second = browser.tabModel()->tabAt(2)->id();

        browser.closeTab(1);                 // a close in progress until the event loop turns
        browser.onTabCloseApproved(second);  // arrives in the same turn
        QCOMPARE(browser.tabModel()->rowCount(), 3);

        QTRY_COMPARE(browser.tabModel()->rowCount(), 2);
        for (int i = 0; i < browser.tabModel()->rowCount(); ++i)
            QVERIFY(browser.tabModel()->tabAt(i)->id() != second);
    }

    // links opened with ⌘/middle-click or "Open Link in New Tab"
    void backgroundLinksOpenWithoutSwitching()
    {
        std::unique_ptr<Space> space(makeSpace(QStringLiteral("open-background"), QStringLiteral("Background")));
        BrowserController browser(space.get(), nullptr, m_dir.filePath(QStringLiteral("browser-settings.ini")));
        browser.newTab(QStringLiteral("https://source.example"));
        const int active = browser.activeIndex();
        const QString source = browser.tabModel()->tabAt(active)->id();

        browser.openTabFrom(source, QStringLiteral("https://linked.example/page"), true);

        QCOMPARE(browser.tabModel()->rowCount(), 3);
        QCOMPARE(browser.activeIndex(), active);
        const BrowserTab *opened = browser.tabModel()->tabAt(2);
        QCOMPARE(opened->url(), QUrl(QStringLiteral("https://linked.example/page")));
        QVERIFY(opened->suspended()); // loads when first shown
    }

    void foregroundLinksSwitchToTheNewTab()
    {
        std::unique_ptr<Space> space(makeSpace(QStringLiteral("open-foreground"), QStringLiteral("Foreground")));
        BrowserController browser(space.get(), nullptr, m_dir.filePath(QStringLiteral("browser-settings.ini")));
        const QString source = browser.tabModel()->tabAt(browser.activeIndex())->id();
        browser.openTabFrom(source, QStringLiteral("https://linked.example"));
        QCOMPARE(browser.activeUrl(), QStringLiteral("https://linked.example"));
    }

    // a blank window.open() used to land here and open the command bar
    void emptyLinksOpenNothing()
    {
        std::unique_ptr<Space> space(makeSpace(QStringLiteral("open-empty"), QStringLiteral("Empty")));
        BrowserController browser(space.get(), nullptr, m_dir.filePath(QStringLiteral("browser-settings.ini")));
        QSignalSpy newTabSpy(&browser, &BrowserController::newTabOpened);
        const QString source = browser.tabModel()->tabAt(browser.activeIndex())->id();

        browser.openTabFrom(source, QString());
        browser.openTabFrom(source, QStringLiteral("   "));
        browser.openTabFrom(QStringLiteral("no-such-tab"), QStringLiteral("https://example.com"));

        QCOMPARE(browser.tabModel()->rowCount(), 1);
        QCOMPARE(newTabSpy.size(), 0);
    }

    void loadInTabTargetsThatTabEvenWhenItIsNotActive()
    {
        std::unique_ptr<Space> space(makeSpace(QStringLiteral("load-in-tab"), QStringLiteral("Load")));
        BrowserController browser(space.get(), nullptr, m_dir.filePath(QStringLiteral("browser-settings.ini")));
        browser.newTab(QStringLiteral("https://one.example"));
        browser.newTab(QStringLiteral("https://two.example"));
        BrowserTab *background = browser.tabModel()->tabAt(1);
        QSignalSpy loadSpy(&browser, &BrowserController::loadRequested);

        browser.loadInTab(background->id(), QStringLiteral("https://reloaded.example/after-crash"));

        QCOMPARE(background->url(), QUrl(QStringLiteral("https://reloaded.example/after-crash")));
        QCOMPARE(browser.activeUrl(), QStringLiteral("https://two.example"));
        QCOMPARE(loadSpy.size(), 1);
        QCOMPARE(loadSpy.at(0).at(0).toString(), background->id());

        browser.loadInTab(QStringLiteral("missing"), QStringLiteral("https://x.example"));
        browser.loadInTab(background->id(), QString());
        QCOMPARE(loadSpy.size(), 1);
    }

    // closing the window or quitting asks each live page first

    void closingAllPagesWithNothingToAskFinishesStraightAway()
    {
        std::unique_ptr<Space> space(makeSpace(QStringLiteral("close-all"), QStringLiteral("Close All")));
        BrowserController browser(space.get(), nullptr, m_dir.filePath(QStringLiteral("browser-settings.ini")));
        browser.newTab(QStringLiteral("https://one.example"));
        browser.newTab(QStringLiteral("https://two.example"));
        QSignalSpy closedSpy(&browser, &BrowserController::allPagesClosed);
        QSignalSpy cancelledSpy(&browser, &BrowserController::closeAllPagesCancelled);

        browser.closeAllPages();

        QCOMPARE(closedSpy.size(), 1);
        QCOMPARE(cancelledSpy.size(), 0);
        QVERIFY(!browser.closingAllPages());
        // the tabs stay: they're saved with the session on the way out
        QCOMPARE(browser.tabModel()->rowCount(), 3);
    }

    void closingAllPagesCanRunAgain()
    {
        std::unique_ptr<Space> space(makeSpace(QStringLiteral("close-all-again"), QStringLiteral("Again")));
        BrowserController browser(space.get(), nullptr, m_dir.filePath(QStringLiteral("browser-settings.ini")));
        QSignalSpy closedSpy(&browser, &BrowserController::allPagesClosed);
        browser.closeAllPages();
        browser.closeAllPages();
        QCOMPARE(closedSpy.size(), 2);
    }

    void stayingOutsideAWindowCloseChangesNothing()
    {
        std::unique_ptr<Space> space(makeSpace(QStringLiteral("stay-alone"), QStringLiteral("Stay")));
        BrowserController browser(space.get(), nullptr, m_dir.filePath(QStringLiteral("browser-settings.ini")));
        browser.newTab(QStringLiteral("https://one.example"));
        QSignalSpy cancelledSpy(&browser, &BrowserController::closeAllPagesCancelled);
        const QString id = browser.tabModel()->tabAt(1)->id();

        browser.onTabBeforeUnloadShown(id);
        browser.onTabCloseCancelled(id);

        QCOMPARE(cancelledSpy.size(), 0);
        QCOMPARE(browser.tabModel()->rowCount(), 2);
    }

    void thePageCheckTimeoutIsShortButHuman()
    {
        QVERIFY(BrowserController::kPageCheckTimeoutMs >= 1000);
        QVERIFY(BrowserController::kPageCheckTimeoutMs <= 10000);
    }

    // a background page retitling itself ("(2) Inbox") gets a dot until it's looked at
    void backgroundTitleChangesMarkActivityUntilTheTabIsShown()
    {
        std::unique_ptr<Space> space(makeSpace(QStringLiteral("activity"), QStringLiteral("Activity")));
        BrowserController browser(space.get(), nullptr, m_dir.filePath(QStringLiteral("browser-settings.ini")));
        browser.newTab(QStringLiteral("https://mail.example"));
        browser.newTab(QStringLiteral("https://news.example"));
        BrowserTab *mail = browser.tabModel()->tabAt(1);
        BrowserTab *news = browser.tabModel()->tabAt(2);
        for (BrowserTab *tab : {mail, news})
        {
            browser.updateTabTitle(tab->id(), QStringLiteral("Loaded"));
            tab->setLoading(true);
            tab->setLoading(false);
        }
        QTest::qWait(BrowserTab::kActivityGraceMs + 100);
        QCOMPARE(browser.tabModel()->tabAt(browser.activeIndex()), news);

        browser.updateTabTitle(mail->id(), QStringLiteral("(1) Inbox"));
        QVERIFY(mail->hasActivity());
        // the tab in front never needs a dot
        browser.updateTabTitle(news->id(), QStringLiteral("Breaking"));
        QVERIFY(!news->hasActivity());
        // the same title again is nothing new
        mail->setHasActivity(false);
        browser.updateTabTitle(mail->id(), QStringLiteral("(1) Inbox"));
        QVERIFY(!mail->hasActivity());

        browser.updateTabTitle(mail->id(), QStringLiteral("(2) Inbox"));
        QVERIFY(mail->hasActivity());
        browser.activateTab(1);
        QVERIFY(!mail->hasActivity());
    }

    void titlesSetWhileLoadingAreNotActivity()
    {
        std::unique_ptr<Space> space(makeSpace(QStringLiteral("activity-loading"), QStringLiteral("Loading")));
        BrowserController browser(space.get(), nullptr, m_dir.filePath(QStringLiteral("browser-settings.ini")));
        browser.newTab(QStringLiteral("https://slow.example"));
        browser.newTab(QStringLiteral("https://front.example"));
        BrowserTab *slow = browser.tabModel()->tabAt(1);
        browser.updateTabTitle(slow->id(), QStringLiteral("Loading…"));
        slow->setLoading(true);
        browser.updateTabTitle(slow->id(), QStringLiteral("Slow Example"));
        QVERIFY(!slow->hasActivity());
        // and right after it finishes, the page is still settling
        slow->setLoading(false);
        browser.updateTabTitle(slow->id(), QStringLiteral("Slow Example — Home"));
        QVERIFY(!slow->hasActivity());
    }

    void muteFollowsTheTabAndAudioIsReported()
    {
        std::unique_ptr<Space> space(makeSpace(QStringLiteral("audio"), QStringLiteral("Audio")));
        BrowserController browser(space.get(), nullptr, m_dir.filePath(QStringLiteral("browser-settings.ini")));
        browser.newTab(QStringLiteral("https://music.example"));
        BrowserTab *music = browser.tabModel()->tabAt(1);

        browser.updateTabAudible(music->id(), true);
        QVERIFY(music->audible());
        browser.toggleTabMuted(music->id());
        QVERIFY(music->muted());
        browser.toggleTabMuted(music->id());
        QVERIFY(!music->muted());
        browser.updateTabAudible(music->id(), false);
        QVERIFY(!music->audible());

        browser.toggleTabMuted(QStringLiteral("missing"));
        browser.updateTabAudible(QStringLiteral("missing"), true);
    }

    void confirmCloseRequirementTracksTabCountAndPreference()
    {
        std::unique_ptr<Space> space(makeSpace(QStringLiteral("confirm-close"), QStringLiteral("Close")));
        BrowserController browser(space.get(), nullptr, m_dir.filePath(QStringLiteral("browser-settings.ini")));
        QVERIFY(!browser.confirmCloseRequired());
        browser.newTab(QStringLiteral("https://example.com"));
        QVERIFY(browser.confirmCloseRequired());
    }
};

QTEST_GUILESS_MAIN(TestBrowserController)
#include "tst_BrowserController.moc"
