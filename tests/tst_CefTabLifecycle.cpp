#include <QtTest>
#include <QDir>
#include <QSettings>
#include <QTemporaryDir>

#include <memory>

#include "BrowserController.h"
#include "BrowserTab.h"
#include "CefNativeViewVisibility.h"
#include "Space.h"
#include "TabModel.h"

class TestCefTabLifecycle : public QObject
{
    Q_OBJECT

    QTemporaryDir m_dir;

    Space *makeSpace(const QString &id)
    {
        auto *space = new Space(id, id, QColor(QStringLiteral("#4A90E2")));
        space->setStorageDir(m_dir.filePath(id));
        QDir().mkpath(space->storageDir());
        return space;
    }

    static BrowserTab *findTab(BrowserController &browser, const QUrl &url)
    {
        for (int i = 0; i < browser.tabModel()->rowCount(); ++i) {
            BrowserTab *tab = browser.tabModel()->tabAt(i);
            if (tab && tab->url() == url)
                return tab;
        }
        return nullptr;
    }

private slots:
    void initTestCase()
    {
        QVERIFY(m_dir.isValid());
        QSettings::setDefaultFormat(QSettings::IniFormat);
        QSettings::setPath(QSettings::IniFormat, QSettings::UserScope, m_dir.path());
        QCoreApplication::setOrganizationName(QStringLiteral("illuminate_tests"));
        QCoreApplication::setApplicationName(QStringLiteral("tst_ceftablifecycle"));
    }

    void visibleForegroundViewStaysVisibleWhileLoading()
    {
        QVERIFY(CefNativeViewVisibility::shouldShow(true, true, true, false));
    }

    void hiddenLoadingViewStaysVisibleBehindForegroundWebTab()
    {
        QVERIFY(CefNativeViewVisibility::shouldShow(true, false, true, true));
    }

    void hiddenLoadingViewIsHiddenWhenForegroundIsInternal()
    {
        QVERIFY(!CefNativeViewVisibility::shouldShow(true, false, true, false));
    }

    void hiddenIdleViewIsAlwaysHidden()
    {
        QVERIFY(!CefNativeViewVisibility::shouldShow(true, false, false, true));
    }

    void invisibleApplicationWindowHidesForegroundAndBackgroundViews()
    {
        QVERIFY(!CefNativeViewVisibility::shouldShow(false, true, true, true));
        QVERIFY(!CefNativeViewVisibility::shouldShow(false, false, true, true));
        QVERIFY(!CefNativeViewVisibility::shouldShow(false, false, false, false));
    }

    void finishingAnInactiveLoadHidesItsNativeView()
    {
        QVERIFY(CefNativeViewVisibility::shouldShow(true, false, true, true));
        QVERIFY(!CefNativeViewVisibility::shouldShow(true, false, false, true));
    }

    void returningToAnInactiveLoadingTabMakesItForeground()
    {
        QVERIFY(CefNativeViewVisibility::shouldShow(true, false, true, true));
        QVERIFY(CefNativeViewVisibility::shouldShow(true, true, true, false));
        QVERIFY(CefNativeViewVisibility::shouldShow(true, true, false, false));
    }

    void foregroundSwitchToInternalPageHidesBackgroundLoad()
    {
        QVERIFY(CefNativeViewVisibility::shouldShow(true, false, true, true));
        QVERIFY(!CefNativeViewVisibility::shouldShow(true, false, true, false));
    }

    void tabSwitchDoesNotCancelAnInFlightNavigation()
    {
        std::unique_ptr<Space> space(makeSpace(QStringLiteral("switch-load")));
        BrowserController browser(space.get(), nullptr, m_dir.filePath(QStringLiteral("browser-settings.ini")));
        browser.newTab(QStringLiteral("https://slow.example.test/"));
        BrowserTab *loadingTab = browser.tabModel()->tabAt(browser.activeIndex());
        QVERIFY(loadingTab);
        const QString loadingId = loadingTab->id();

        browser.updateTabLoading(loadingId, true);
        browser.newTab(QStringLiteral("https://foreground.example.test/"));

        QVERIFY(loadingTab->loading());
        QVERIFY(!browser.activeLoading());
        QCOMPARE(browser.tabModel()->tabAt(browser.activeIndex())->url(),
                 QUrl(QStringLiteral("https://foreground.example.test/")));
    }

    void inactiveLoadCompletionUpdatesTheOriginalTab()
    {
        std::unique_ptr<Space> space(makeSpace(QStringLiteral("inactive-complete")));
        BrowserController browser(space.get(), nullptr, m_dir.filePath(QStringLiteral("browser-settings.ini")));
        browser.newTab(QStringLiteral("https://slow.example.test/"));
        BrowserTab *loadingTab = browser.tabModel()->tabAt(browser.activeIndex());
        const QString loadingId = loadingTab->id();
        browser.updateTabLoading(loadingId, true);
        browser.newTab(QStringLiteral("https://foreground.example.test/"));

        browser.updateTabLoading(loadingId, false);

        QVERIFY(!loadingTab->loading());
        QVERIFY(!browser.activeLoading());
        QCOMPARE(browser.tabModel()->data(browser.tabModel()->index(browser.tabModel()->indexOf(loadingTab), 0),
                                         TabModel::LoadingRole).toBool(), false);
    }

    void simultaneousBackgroundLoadsRemainIndependentAcrossSwitches()
    {
        std::unique_ptr<Space> space(makeSpace(QStringLiteral("parallel-loads")));
        BrowserController browser(space.get(), nullptr, m_dir.filePath(QStringLiteral("browser-settings.ini")));
        browser.newTab(QStringLiteral("https://one.example.test/"));
        BrowserTab *one = browser.tabModel()->tabAt(browser.activeIndex());
        browser.updateTabLoading(one->id(), true);

        browser.newTab(QStringLiteral("https://two.example.test/"));
        BrowserTab *two = browser.tabModel()->tabAt(browser.activeIndex());
        browser.updateTabLoading(two->id(), true);

        browser.newTab(QStringLiteral("https://three.example.test/"));
        BrowserTab *three = browser.tabModel()->tabAt(browser.activeIndex());
        browser.updateTabLoading(three->id(), true);

        browser.activateTab(browser.tabModel()->indexOf(one));
        QVERIFY(browser.activeLoading());
        browser.activateTab(browser.tabModel()->indexOf(two));
        QVERIFY(browser.activeLoading());
        browser.activateTab(browser.tabModel()->indexOf(three));
        QVERIFY(browser.activeLoading());

        browser.updateTabLoading(two->id(), false);
        QVERIFY(one->loading());
        QVERIFY(!two->loading());
        QVERIFY(three->loading());
        QVERIFY(browser.activeLoading());
    }

    void loadingStateFollowsStableTabIdWhenRowsMove()
    {
        std::unique_ptr<Space> space(makeSpace(QStringLiteral("reordered-load")));
        BrowserController browser(space.get(), nullptr, m_dir.filePath(QStringLiteral("browser-settings.ini")));
        browser.newTab(QStringLiteral("https://first.example.test/"));
        BrowserTab *first = browser.tabModel()->tabAt(browser.activeIndex());
        browser.newTab(QStringLiteral("https://second.example.test/"));
        BrowserTab *second = browser.tabModel()->tabAt(browser.activeIndex());
        browser.updateTabLoading(first->id(), true);
        browser.updateTabLoading(second->id(), true);

        browser.tabModel()->moveTab(browser.tabModel()->indexOf(first), 0);
        browser.tabModel()->moveTab(browser.tabModel()->indexOf(second), 1);

        QCOMPARE(browser.tabModel()->tabAt(0), first);
        QCOMPARE(browser.tabModel()->tabAt(1), second);
        QVERIFY(first->loading());
        QVERIFY(second->loading());
        browser.updateTabLoading(first->id(), false);
        QVERIFY(!first->loading());
        QVERIFY(second->loading());
    }

    void folderMembershipDoesNotLoseAnInactiveLoad()
    {
        std::unique_ptr<Space> space(makeSpace(QStringLiteral("folder-load")));
        BrowserController browser(space.get(), nullptr, m_dir.filePath(QStringLiteral("browser-settings.ini")));
        browser.newTab(QStringLiteral("https://folder.example.test/"));
        BrowserTab *folderTab = browser.tabModel()->tabAt(browser.activeIndex());
        browser.updateTabLoading(folderTab->id(), true);
        browser.newTab(QStringLiteral("https://foreground.example.test/"));
        BrowserTab *foregroundTab = browser.tabModel()->tabAt(browser.activeIndex());
        const QString folder = browser.sidebar()->createFolder({}, QStringLiteral("Loading"));
        browser.sidebar()->addToFolder(folderTab->id(), folder);

        browser.activateTab(browser.tabModel()->indexOf(folderTab));
        QVERIFY(folderTab->loading());
        QVERIFY(browser.sidebar()->isInFolder(folderTab));
        browser.activateTab(browser.tabModel()->indexOf(foregroundTab));
        QVERIFY(folderTab->loading());
        QVERIFY(!browser.activeLoading());
    }

    void restoredFolderTabWakesAndCanLoadInTheBackground()
    {
        std::unique_ptr<Space> space(makeSpace(QStringLiteral("restored-folder")));
        BrowserController browser(space.get(), nullptr, m_dir.filePath(QStringLiteral("browser-settings.ini")));
        browser.newTab(QStringLiteral("https://restored.example.test/"), true);
        BrowserTab *restored = browser.tabModel()->tabAt(browser.tabModel()->rowCount() - 1);
        QVERIFY(restored->suspended());
        const QString folder = browser.sidebar()->createFolder({}, QStringLiteral("Restored"));
        browser.sidebar()->addToFolder(restored->id(), folder);

        browser.activateTab(browser.tabModel()->indexOf(restored));
        QVERIFY(!restored->suspended());
        browser.updateTabLoading(restored->id(), true);
        browser.newTab(QStringLiteral("https://foreground.example.test/"));

        QVERIFY(restored->loading());
        QVERIFY(!restored->suspended());
        QVERIFY(!browser.activeLoading());
    }

    void repeatedLoadTransitionsDoNotStickLoadingState()
    {
        std::unique_ptr<Space> space(makeSpace(QStringLiteral("load-transitions")));
        BrowserController browser(space.get(), nullptr, m_dir.filePath(QStringLiteral("browser-settings.ini")));
        browser.newTab(QStringLiteral("https://redirects.example.test/"));
        BrowserTab *tab = browser.tabModel()->tabAt(browser.activeIndex());

        for (int i = 0; i < 12; ++i) {
            browser.updateTabLoading(tab->id(), true);
            QVERIFY(tab->loading());
            browser.updateTabLoading(tab->id(), false);
            QVERIFY(!tab->loading());
        }
    }

    void staleLoadCallbacksAfterCloseAreIgnored()
    {
        std::unique_ptr<Space> space(makeSpace(QStringLiteral("closed-callback")));
        BrowserController browser(space.get(), nullptr, m_dir.filePath(QStringLiteral("browser-settings.ini")));
        browser.newTab(QStringLiteral("https://close.example.test/"));
        BrowserTab *closingTab = browser.tabModel()->tabAt(browser.activeIndex());
        const QString closingId = closingTab->id();
        browser.updateTabLoading(closingId, true);
        browser.newTab(QStringLiteral("https://survivor.example.test/"));
        browser.closeTab(browser.tabModel()->indexOf(closingTab));

        const int remainingRows = browser.tabModel()->rowCount();
        browser.updateTabLoading(closingId, false);

        QCOMPARE(browser.tabModel()->rowCount(), remainingRows);
        QVERIFY(findTab(browser, QUrl(QStringLiteral("https://survivor.example.test/"))));
    }

    void burstSwitchesKeepEveryLoadingTabAssociated()
    {
        std::unique_ptr<Space> space(makeSpace(QStringLiteral("burst-switches")));
        BrowserController browser(space.get(), nullptr, m_dir.filePath(QStringLiteral("browser-settings.ini")));
        QList<BrowserTab *> tabs;
        for (int i = 0; i < 5; ++i) {
            browser.newTab(QStringLiteral("https://load-%1.example.test/").arg(i));
            BrowserTab *tab = browser.tabModel()->tabAt(browser.activeIndex());
            tabs << tab;
            browser.updateTabLoading(tab->id(), true);
        }

        for (int i = 0; i < 120; ++i) {
            browser.activateTab(browser.tabModel()->indexOf(tabs.at(i % tabs.size())));
            if (i % 9 == 0) {
                const int from = (i / 3) % tabs.size();
                const int to = (i / 7 + 1) % tabs.size();
                browser.tabModel()->moveTab(from, to);
            }
            for (BrowserTab *tab : tabs)
                QVERIFY(tab->loading());
        }

        for (BrowserTab *tab : tabs) {
            browser.updateTabLoading(tab->id(), false);
            QVERIFY(!tab->loading());
        }
    }
};

QTEST_GUILESS_MAIN(TestCefTabLifecycle)
#include "tst_CefTabLifecycle.moc"
