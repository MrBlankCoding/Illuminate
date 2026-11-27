#include <QtTest>

#include "BrowserTab.h"

class TestBrowserTab : public QObject
{
    Q_OBJECT

private slots:
    void newTabHasStableIdAndEmptyState()
    {
        BrowserTab tab;
        QVERIFY(!tab.id().isEmpty());
        QCOMPARE(tab.url(), QUrl());
        QVERIFY(tab.title().isEmpty());
        QVERIFY(tab.iconUrl().isEmpty());
        QCOMPARE(tab.progress(), 0);
        QVERIFY(!tab.loading());
        QCOMPARE(tab.renderProcessPid(), 0);
        QVERIFY(!tab.suspended());
    }

    void idsAreUniqueAcrossTabs()
    {
        BrowserTab first;
        BrowserTab second;
        QVERIFY(first.id() != second.id());
    }

    void urlUpdatesNotifyOnlyWhenChanged()
    {
        BrowserTab tab;
        QSignalSpy spy(&tab, &BrowserTab::urlChanged);
        const QUrl url(QStringLiteral("https://example.com/path"));
        tab.setUrl(url);
        tab.setUrl(url);
        QCOMPARE(tab.url(), url);
        QCOMPARE(spy.size(), 1);
        QCOMPARE(spy.takeFirst().at(0).toUrl(), url);
    }

    void titleUpdatesNotifyOnlyWhenChanged()
    {
        BrowserTab tab;
        QSignalSpy spy(&tab, &BrowserTab::titleChanged);
        tab.setTitle(QStringLiteral("Example"));
        tab.setTitle(QStringLiteral("Example"));
        QCOMPARE(tab.title(), QStringLiteral("Example"));
        QCOMPARE(spy.size(), 1);
        QCOMPARE(spy.takeFirst().at(0).toString(), QStringLiteral("Example"));
    }

    void iconUpdatesNotifyOnlyWhenChanged()
    {
        BrowserTab tab;
        QSignalSpy spy(&tab, &BrowserTab::iconUrlChanged);
        tab.setIconUrl(QStringLiteral("https://example.com/favicon.ico"));
        tab.setIconUrl(QStringLiteral("https://example.com/favicon.ico"));
        QCOMPARE(tab.iconUrl(), QStringLiteral("https://example.com/favicon.ico"));
        QCOMPARE(spy.size(), 1);
    }

    void progressUpdatesNotifyOnlyWhenChanged()
    {
        BrowserTab tab;
        QSignalSpy spy(&tab, &BrowserTab::progressChanged);
        tab.setProgress(45);
        tab.setProgress(45);
        QCOMPARE(tab.progress(), 45);
        QCOMPARE(spy.size(), 1);
        QCOMPARE(spy.takeFirst().at(0).toInt(), 45);
    }

    void loadingUpdatesNotifyOnlyWhenChanged()
    {
        BrowserTab tab;
        QSignalSpy spy(&tab, &BrowserTab::loadingChanged);
        tab.setLoading(true);
        tab.setLoading(true);
        tab.setLoading(false);
        QCOMPARE(tab.loading(), false);
        QCOMPARE(spy.size(), 2);
    }

    void rendererPidUpdatesNotifyOnlyWhenChanged()
    {
        BrowserTab tab;
        QSignalSpy spy(&tab, &BrowserTab::renderProcessPidChanged);
        tab.setRenderProcessPid(1234);
        tab.setRenderProcessPid(1234);
        QCOMPARE(tab.renderProcessPid(), qint64(1234));
        QCOMPARE(spy.size(), 1);
    }

    void suspensionUpdatesNotifyOnlyWhenChanged()
    {
        BrowserTab tab;
        QSignalSpy spy(&tab, &BrowserTab::suspendedChanged);
        tab.setSuspended(true);
        tab.setSuspended(true);
        QCOMPARE(tab.suspended(), true);
        QCOMPARE(spy.size(), 1);
    }

    void loadRequestCarriesUrl()
    {
        BrowserTab tab;
        QSignalSpy spy(&tab, &BrowserTab::loadRequested);
        const QUrl url(QStringLiteral("https://example.com/next"));
        tab.requestLoad(url);
        QCOMPARE(spy.size(), 1);
        QCOMPARE(spy.takeFirst().at(0).toUrl(), url);
    }

    void editingActionsAreSafeWithoutAWebView()
    {
        BrowserTab tab;
        tab.cut();
        tab.copy();
        tab.paste();
        tab.selectAll();
        tab.setCefBrowserWrapper(nullptr);
        tab.copy();
        QCOMPARE(tab.progress(), 0);
    }

    void chromeIconUrlIsSanitized()
    {
        BrowserTab tab;
        tab.setUrl(QUrl(QStringLiteral("chrome://settings")));
        tab.setIconUrl(QStringLiteral("chrome://theme/IDR_SETTINGS_FAVICON"));
        QCOMPARE(tab.iconUrl(), QStringLiteral("qrc:/illuminate/ui/icons/globe.svg"));

        BrowserTab extTab;
        extTab.setUrl(QUrl(QStringLiteral("https://example.com")));
        extTab.setIconUrl(QStringLiteral("chrome://favicon/https://example.com"));
        QCOMPARE(extTab.iconUrl(), QString());
    }
    void closingWithoutAWebViewNeedsNoConfirmation()
    {
        BrowserTab tab;
        tab.setUrl(QUrl(QStringLiteral("https://example.com")));
        QVERIFY(!tab.requestClose());
        tab.setCefBrowserWrapper(nullptr);
        QVERIFY(!tab.requestClose());
    }

    void suspendedTabsCloseWithoutAsking()
    {
        BrowserTab tab;
        tab.setUrl(QUrl(QStringLiteral("https://example.com")));
        tab.setSuspended(true);
        QVERIFY(!tab.requestClose());
    }
    void audioStateNotifiesOnlyWhenChanged()
    {
        BrowserTab tab;
        QSignalSpy audibleSpy(&tab, &BrowserTab::audibleChanged);
        QSignalSpy mutedSpy(&tab, &BrowserTab::mutedChanged);
        tab.setAudible(true);
        tab.setAudible(true);
        tab.setMuted(true);
        tab.setMuted(true);
        QVERIFY(tab.audible());
        QVERIFY(tab.muted());
        QCOMPARE(audibleSpy.size(), 1);
        QCOMPARE(mutedSpy.size(), 1);
    }

    void activityNotifiesOnlyWhenChanged()
    {
        BrowserTab tab;
        QSignalSpy spy(&tab, &BrowserTab::hasActivityChanged);
        tab.setHasActivity(true);
        tab.setHasActivity(true);
        tab.setHasActivity(false);
        QCOMPARE(spy.size(), 2);
    }

    // a title change only counts as news once the page has settled
    void aTabSettlesAWhileAfterItsLoadFinishes()
    {
        BrowserTab tab;
        QVERIFY(!tab.settled()); // never loaded
        tab.setLoading(true);
        QVERIFY(!tab.settled());
        tab.setLoading(false);
        QVERIFY(!tab.settled()); // just finished: still settling
        QTest::qWait(BrowserTab::kActivityGraceMs + 100);
        QVERIFY(tab.settled());
        tab.setSuspended(true);
        QVERIFY(!tab.settled());
    }
};

QTEST_GUILESS_MAIN(TestBrowserTab)
#include "tst_BrowserTab.moc"
