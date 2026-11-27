#include <QtTest>
#include <QSettings>
#include <QTemporaryDir>
#include <QFile>
#include <QSignalSpy>
#include <QStandardPaths>

#include "BrowserSettings.h"

class TestBrowserSettings : public QObject
{
    Q_OBJECT

    QTemporaryDir m_dir;

    QString settingsFile() const
    {
        return m_dir.filePath(QStringLiteral("browser.ini"));
    }

private slots:
    void initTestCase()
    {
        // keep the real user's preferences out of reach
        QVERIFY(m_dir.isValid());
        QSettings::setDefaultFormat(QSettings::IniFormat);
        QSettings::setPath(QSettings::IniFormat, QSettings::UserScope, m_dir.path());
        QCoreApplication::setOrganizationName(QStringLiteral("illuminate_tests"));
        QCoreApplication::setApplicationName(QStringLiteral("tst_browsersettings"));
        QStandardPaths::setTestModeEnabled(true);
    }

    void init()
    {
        QFile::remove(settingsFile());
        QSettings().clear();
    }

    void sidebarWidthDefaults()
    {
        BrowserSettings prefs(nullptr, settingsFile());
        QCOMPARE(prefs.sidebarWidth(), BrowserSettings::kSidebarDefaultWidth);
    }

    void sidebarWidthIsClamped()
    {
        BrowserSettings prefs(nullptr, settingsFile());
        prefs.setSidebarWidth(10);
        QCOMPARE(prefs.sidebarWidth(), BrowserSettings::kSidebarMinWidth);
        prefs.setSidebarWidth(10000);
        QCOMPARE(prefs.sidebarWidth(), BrowserSettings::kSidebarMaxWidth);
    }

    void sidebarWidthPersists()
    {
        {
            BrowserSettings prefs(nullptr, settingsFile());
            QSignalSpy spy(&prefs, &BrowserSettings::sidebarWidthChanged);
            prefs.setSidebarWidth(300);
            QCOMPARE(spy.size(), 1);
            // unchanged: no write, no signal
            prefs.setSidebarWidth(300);
            QCOMPARE(spy.size(), 1);
        }
        BrowserSettings reopened(nullptr, settingsFile());
        QCOMPARE(reopened.sidebarWidth(), 300);
    }

    void storedOutOfRangeWidthIsClampedOnLoad()
    {
        QSettings().setValue(QStringLiteral("sidebar/width"), 5);
        BrowserSettings prefs(nullptr, settingsFile());
        QCOMPARE(prefs.sidebarWidth(), BrowserSettings::kSidebarMinWidth);
    }

    void aResizedSidebarKeepsItsWidth()
    {
        QSettings().setValue(QStringLiteral("sidebar/width"), 260);
        BrowserSettings prefs(nullptr, settingsFile());
        QCOMPARE(prefs.sidebarWidth(), 260);
    }

    void compactLimitsLeaveRoomForTheWindowControls()
    {
        QVERIFY(BrowserSettings::kSidebarMinWidth <= BrowserSettings::kSidebarDefaultWidth);
#if !defined(Q_OS_MACOS)
        QVERIFY(BrowserSettings::kSidebarMinWidth >= 190);
#endif
    }

    void densityDefaultsToCompact()
    {
        BrowserSettings prefs(nullptr, settingsFile());
        QCOMPARE(prefs.uiDensity(), QStringLiteral("compact"));
    }

    void densityPersistsAndNotifiesOnlyOnChange()
    {
        {
            BrowserSettings prefs(nullptr, settingsFile());
            QSignalSpy spy(&prefs, &BrowserSettings::uiDensityChanged);
            prefs.setUiDensity(QStringLiteral("cosy"));
            prefs.setUiDensity(QStringLiteral("cosy"));
            QCOMPARE(spy.size(), 1);
            QCOMPARE(prefs.uiDensity(), QStringLiteral("cosy"));
        }
        BrowserSettings reopened(nullptr, settingsFile());
        QCOMPARE(reopened.uiDensity(), QStringLiteral("cosy"));
        reopened.setUiDensity(QStringLiteral("normal"));
        QCOMPARE(reopened.uiDensity(), QStringLiteral("normal"));
    }

    void unknownDensitiesFallBackToCompact()
    {
        QSettings().setValue(QStringLiteral("appearance/density"), QStringLiteral("enormous"));
        BrowserSettings prefs(nullptr, settingsFile());
        QCOMPARE(prefs.uiDensity(), QStringLiteral("compact"));
        prefs.setUiDensity(QStringLiteral("normal"));
        prefs.setUiDensity(QStringLiteral("huge"));
        QCOMPARE(prefs.uiDensity(), QStringLiteral("compact"));
    }

    void spacesAreKeptReadyByDefaultAndTheChoicePersists()
    {
        {
            BrowserSettings prefs(nullptr, settingsFile());
            QVERIFY(prefs.preloadSpaces());
            QSignalSpy spy(&prefs, &BrowserSettings::preloadSpacesChanged);
            prefs.setPreloadSpaces(false);
            prefs.setPreloadSpaces(false);
            QCOMPARE(spy.size(), 1);
        }
        BrowserSettings reopened(nullptr, settingsFile());
        QVERIFY(!reopened.preloadSpaces());
    }

    void browserLanguageDefaults()
    {
        BrowserSettings prefs(nullptr, settingsFile());
        QCOMPARE(prefs.browserLanguage(), QString());
    }

    void browserLanguagePersists()
    {
        {
            BrowserSettings prefs(nullptr, settingsFile());
            QSignalSpy spy(&prefs, &BrowserSettings::browserLanguageChanged);
            prefs.setBrowserLanguage(QStringLiteral("de"));
            QCOMPARE(spy.size(), 1);
            prefs.setBrowserLanguage(QStringLiteral("de"));
            QCOMPARE(spy.size(), 1);
        }
        BrowserSettings reopened(nullptr, settingsFile());
        QCOMPARE(reopened.browserLanguage(), QStringLiteral("de"));
    }

    void browserLanguageStoredUnderGeneralKey()
    {
        QSettings().setValue(QStringLiteral("general/language"), QStringLiteral("fr-FR"));
        BrowserSettings prefs(nullptr, settingsFile());
        QCOMPARE(prefs.browserLanguage(), QStringLiteral("fr-FR"));
    }

    void startupBehaviorDefaultsAndRejectsUnknownValues()
    {
        BrowserSettings prefs(nullptr, settingsFile());
        QCOMPARE(prefs.startupBehavior(), QStringLiteral("newtab"));
        prefs.setStartupBehavior(QStringLiteral("not-a-mode"));
        QCOMPARE(prefs.startupBehavior(), QStringLiteral("newtab"));
        prefs.setStartupBehavior(QStringLiteral("homepage"));
        QCOMPARE(prefs.startupBehavior(), QStringLiteral("homepage"));
    }

    void startupAndHomepageSettingsPersist()
    {
        {
            BrowserSettings prefs(nullptr, settingsFile());
            QSignalSpy behaviorSpy(&prefs, &BrowserSettings::startupBehaviorChanged);
            QSignalSpy homepageSpy(&prefs, &BrowserSettings::homepageUrlChanged);
            prefs.setStartupBehavior(QStringLiteral("homepage"));
            prefs.setHomepageUrl(QStringLiteral("  https://example.com/start  "));
            QCOMPARE(behaviorSpy.size(), 1);
            QCOMPARE(homepageSpy.size(), 1);
        }

        BrowserSettings reopened(nullptr, settingsFile());
        QCOMPARE(reopened.startupBehavior(), QStringLiteral("homepage"));
        QCOMPARE(reopened.homepageUrl(), QStringLiteral("https://example.com/start"));
    }

    void homepageNoOpDoesNotEmit()
    {
        BrowserSettings prefs(nullptr, settingsFile());
        QSignalSpy spy(&prefs, &BrowserSettings::homepageUrlChanged);
        prefs.setHomepageUrl(QStringLiteral("https://example.com"));
        prefs.setHomepageUrl(QStringLiteral(" https://example.com "));
        QCOMPARE(spy.size(), 1);
    }

    void searchEngineCatalogHasStableEntries()
    {
        BrowserSettings prefs(nullptr, settingsFile());
        const QVariantList engines = prefs.searchEngines();
        QVERIFY(engines.size() >= 8);

        bool foundDuckDuckGo = false;
        bool foundCustom = false;
        for (const QVariant &entry : engines)
        {
            const QVariantMap engine = entry.toMap();
            QVERIFY(!engine.value(QStringLiteral("id")).toString().isEmpty());
            QVERIFY(!engine.value(QStringLiteral("name")).toString().isEmpty());
            foundDuckDuckGo |= engine.value(QStringLiteral("id")).toString() == QStringLiteral("duckduckgo");
            foundCustom |= engine.value(QStringLiteral("id")).toString() == QStringLiteral("custom");
        }
        QVERIFY(foundDuckDuckGo);
        QVERIFY(foundCustom);
    }

    void invalidStoredSearchEngineFallsBackToDuckDuckGo()
    {
        QSettings stored(settingsFile(), QSettings::IniFormat);
        stored.setValue(QStringLiteral("search/engine"), QStringLiteral("unknown"));
        stored.sync();

        BrowserSettings prefs(nullptr, settingsFile());
        QCOMPARE(prefs.searchEngineId(), QStringLiteral("duckduckgo"));
        QCOMPARE(prefs.searchEngineName(), QStringLiteral("DuckDuckGo"));
        QCOMPARE(prefs.searchUrlTemplate(), QStringLiteral("https://duckduckgo.com/?q=%s"));
    }

    void searchEngineChangesPersistAndNotify()
    {
        {
            BrowserSettings prefs(nullptr, settingsFile());
            QSignalSpy spy(&prefs, &BrowserSettings::searchEngineChanged);
            prefs.setSearchEngineId(QStringLiteral("google"));
            QCOMPARE(spy.size(), 1);
            prefs.setSearchEngineId(QStringLiteral("google"));
            QCOMPARE(spy.size(), 1);
        }
        BrowserSettings reopened(nullptr, settingsFile());
        QCOMPARE(reopened.searchEngineId(), QStringLiteral("google"));
        QCOMPARE(reopened.searchEngineName(), QStringLiteral("Google"));
        QCOMPARE(reopened.searchUrlTemplate(), QStringLiteral("https://www.google.com/search?q=%s"));
    }

    void customSearchTemplateRequiresPlaceholder()
    {
        BrowserSettings prefs(nullptr, settingsFile());
        prefs.setSearchEngineId(QStringLiteral("custom"));
        prefs.setCustomSearchUrl(QStringLiteral("https://search.example/?q="));
        QCOMPARE(prefs.searchUrlTemplate(), QStringLiteral("https://duckduckgo.com/?q=%s"));
        prefs.setCustomSearchUrl(QStringLiteral("https://search.example/?q=%s"));
        QCOMPARE(prefs.searchUrlTemplate(), QStringLiteral("https://search.example/?q=%s"));
    }

    void searchSuggestionsPersistAndNotifyOnlyOnChange()
    {
        {
            BrowserSettings prefs(nullptr, settingsFile());
            QVERIFY(prefs.searchSuggestionsEnabled());
            QSignalSpy spy(&prefs, &BrowserSettings::searchSuggestionsEnabledChanged);
            prefs.setSearchSuggestionsEnabled(false);
            prefs.setSearchSuggestionsEnabled(false);
            QCOMPARE(spy.size(), 1);
        }
        BrowserSettings reopened(nullptr, settingsFile());
        QVERIFY(!reopened.searchSuggestionsEnabled());
    }

    void commandBarSettingsPersist()
    {
        {
            BrowserSettings prefs(nullptr, settingsFile());
            QVERIFY(prefs.commandBarCalculatorEnabled());
            QVERIFY(prefs.commandBarBangsEnabled());

            QSignalSpy calcSpy(&prefs, &BrowserSettings::commandBarCalculatorEnabledChanged);
            QSignalSpy bangSpy(&prefs, &BrowserSettings::commandBarBangsEnabledChanged);

            prefs.setCommandBarCalculatorEnabled(false);
            prefs.setCommandBarBangsEnabled(false);

            QCOMPARE(calcSpy.size(), 1);
            QCOMPARE(bangSpy.size(), 1);
        }
        BrowserSettings reopened(nullptr, settingsFile());
        QVERIFY(!reopened.commandBarCalculatorEnabled());
        QVERIFY(!reopened.commandBarBangsEnabled());
    }

    void privacyAndMemorySettingsPersistWithoutAnInitializedCefRuntime()
    {
        {
            BrowserSettings prefs(nullptr, settingsFile());
            QSignalSpy cookieSpy(&prefs, &BrowserSettings::thirdPartyCookiesEnabledChanged);
            QSignalSpy saverSpy(&prefs, &BrowserSettings::memorySaverChanged);
            prefs.setThirdPartyCookiesEnabled(false);
            prefs.setMemorySaverEnabled(false);
            prefs.setMemorySaverMode(2);
            QCOMPARE(cookieSpy.size(), 1);
            QCOMPARE(saverSpy.size(), 2);
        }

        BrowserSettings reopened(nullptr, settingsFile());
        QVERIFY(!reopened.thirdPartyCookiesEnabled());
        QVERIFY(!reopened.memorySaverEnabled());
        QCOMPARE(reopened.memorySaverMode(), 2);
    }

    void memorySaverModeIsClamped()
    {
        BrowserSettings prefs(nullptr, settingsFile());
        prefs.setMemorySaverMode(-10);
        QCOMPARE(prefs.memorySaverMode(), 0);
        prefs.setMemorySaverMode(100);
        QCOMPARE(prefs.memorySaverMode(), 2);
    }

    void closeConfirmationPersists()
    {
        {
            BrowserSettings prefs(nullptr, settingsFile());
            QVERIFY(prefs.confirmCloseMultipleTabs());
            QSignalSpy spy(&prefs, &BrowserSettings::confirmCloseMultipleTabsChanged);
            prefs.setConfirmCloseMultipleTabs(false);
            QCOMPARE(spy.size(), 1);
        }
        BrowserSettings reopened(nullptr, settingsFile());
        QVERIFY(!reopened.confirmCloseMultipleTabs());
    }

    void sidebarCollapsedPersists()
    {
        {
            BrowserSettings prefs(nullptr, settingsFile());
            QVERIFY(!prefs.sidebarCollapsed());
            QSignalSpy spy(&prefs, &BrowserSettings::sidebarCollapsedChanged);
            prefs.setSidebarCollapsed(true);
            QCOMPARE(spy.size(), 1);
        }
        BrowserSettings reopened(nullptr, settingsFile());
        QVERIFY(reopened.sidebarCollapsed());
    }

    void maxDiskCacheSizeDefaultsAndPersists()
    {
        {
            BrowserSettings prefs(nullptr, settingsFile());
            QCOMPARE(prefs.maxDiskCacheSize(), 0);
            QSignalSpy spy(&prefs, &BrowserSettings::maxDiskCacheSizeChanged);
            prefs.setMaxDiskCacheSize(1024);
            QCOMPARE(spy.size(), 1);
            // clamped to >= 0
            prefs.setMaxDiskCacheSize(-50);
            QCOMPARE(prefs.maxDiskCacheSize(), 0);
            prefs.setMaxDiskCacheSize(512);
        }
        BrowserSettings reopened(nullptr, settingsFile());
        QCOMPARE(reopened.maxDiskCacheSize(), 512);
    }

    void emptyBrowserLanguageIsAcceptedAndPersists()
    {
        {
            BrowserSettings prefs(nullptr, settingsFile());
            prefs.setBrowserLanguage(QStringLiteral("ja-JP"));
            prefs.setBrowserLanguage(QString());
        }
        BrowserSettings reopened(nullptr, settingsFile());
        QVERIFY(reopened.browserLanguage().isEmpty());
    }
};

QTEST_GUILESS_MAIN(TestBrowserSettings)
#include "tst_BrowserSettings.moc"
