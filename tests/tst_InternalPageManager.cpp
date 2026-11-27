#include <QtTest>

#include <QQmlEngine>

#include "InternalPageManager.h"

class TestInternalPageManager : public QObject
{
    Q_OBJECT

private slots:
    void newTabSchemesAreInternal()
    {
        QVERIFY(InternalPageManager::isInternal(QStringLiteral("newtab://newtab")));
        QVERIFY(InternalPageManager::isInternal(QStringLiteral(" newtab://newtab ")));
    }

    void illuminateSchemeIsCaseInsensitive()
    {
        QVERIFY(InternalPageManager::isInternal(QStringLiteral("illuminate://memory")));
        QVERIFY(InternalPageManager::isInternal(QStringLiteral("ILLUMINATE://memory")));
    }

    void ordinaryAndMalformedUrlsAreNotInternal()
    {
        QVERIFY(!InternalPageManager::isInternal(QStringLiteral("https://example.com")));
        QVERIFY(!InternalPageManager::isInternal(QStringLiteral("illuminate:memory")));
        QVERIFY(!InternalPageManager::isInternal(QStringLiteral("chrome://settings")));
        QVERIFY(!InternalPageManager::isInternal(QString()));
    }

    void setupPageResolvesWithOptionalTrailingSlash()
    {
        const QString source = QStringLiteral("qrc:/illuminate/ui/pages/SetupPage.qml");
        QCOMPARE(InternalPageManager::qmlSource(QStringLiteral("illuminate://setup")), source);
        QCOMPARE(InternalPageManager::qmlSource(QStringLiteral("illuminate://setup/")), source);
        QCOMPARE(InternalPageManager::qmlSource(QStringLiteral("ILLUMINATE://SETUP/")), source);
    }

    void setupTitleResolvesWithOptionalTrailingSlash()
    {
        QCOMPARE(InternalPageManager::title(QStringLiteral("illuminate://setup")), QStringLiteral("Setup"));
        QCOMPARE(InternalPageManager::title(QStringLiteral("illuminate://setup/")), QStringLiteral("Setup"));
    }

    void unknownInternalPagesHaveNoSourceOrTitle()
    {
        QVERIFY(InternalPageManager::qmlSource(QStringLiteral("illuminate://unknown")).isEmpty());
        QVERIFY(InternalPageManager::title(QStringLiteral("illuminate://unknown")).isEmpty());
        QVERIFY(InternalPageManager::title(QStringLiteral("newtab://newtab")).isEmpty());
    }

    void internalIconsUseTheBundledGlobe()
    {
        const QString icon = QStringLiteral("qrc:/illuminate/ui/icons/globe.svg");
        QCOMPARE(InternalPageManager::iconUrl(QStringLiteral("chrome://settings")), icon);
        QCOMPARE(InternalPageManager::iconUrl(QStringLiteral("illuminate://memory")), icon);
    }

    void externalUrlsHaveNoInternalIcon()
    {
        QVERIFY(InternalPageManager::iconUrl(QStringLiteral("https://example.com")).isEmpty());
        QVERIFY(InternalPageManager::iconUrl(QStringLiteral("about:blank")).isEmpty());
    }

    void singletonFactoryAlwaysReturnsTheSharedInstance()
    {
        QQmlEngine engine;
        QCOMPARE(InternalPageManager::create(&engine, nullptr), &InternalPageManager::instance());
        QCOMPARE(&InternalPageManager::instance(), &InternalPageManager::instance());
    }
    // a tab whose renderer keeps crashing shows this instead of reloading forever
    void crashPageIsInternalWithItsAddressAttached()
    {
        const QString crash = QStringLiteral("illuminate://crashed?url=https%3A%2F%2Fexample.com%2F");
        QVERIFY(InternalPageManager::isInternal(crash));
        QCOMPARE(InternalPageManager::qmlSource(crash), QStringLiteral("qrc:/illuminate/ui/pages/CrashedPage.qml"));
        QCOMPARE(InternalPageManager::title(crash), QStringLiteral("Page crashed"));
        QCOMPARE(InternalPageManager::qmlSource(QStringLiteral("ILLUMINATE://CRASHED")),
                 QStringLiteral("qrc:/illuminate/ui/pages/CrashedPage.qml"));
    }

    void lookalikesOfTheCrashPageAreNotIt()
    {
        QCOMPARE(InternalPageManager::qmlSource(QStringLiteral("illuminate://crashedpage")), QString());
        QCOMPARE(InternalPageManager::title(QStringLiteral("illuminate://crashed-x?url=a")), QString());
    }
};

QTEST_GUILESS_MAIN(TestInternalPageManager)
#include "tst_InternalPageManager.moc"
