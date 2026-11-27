#include <QtTest>

#include "UrlResolver.h"

class TestUrlResolver : public QObject
{
    Q_OBJECT

private slots:
    void looksLikeHost_data()
    {
        QTest::addColumn<QString>("input");
        QTest::addColumn<bool>("expected");

        QTest::newRow("domain") << QStringLiteral("example.com") << true;
        QTest::newRow("multi-level domain") << QStringLiteral("docs.example.co.uk") << true;
        QTest::newRow("localhost") << QStringLiteral("localhost") << true;
        QTest::newRow("localhost with port") << QStringLiteral("localhost:8080/path") << true;
        QTest::newRow("ipv4") << QStringLiteral("192.168.1.10") << true;
        QTest::newRow("ipv4 with port and path") << QStringLiteral("127.0.0.1:3000/app") << true;
        QTest::newRow("single label") << QStringLiteral("intranet") << false;
        QTest::newRow("search phrase") << QStringLiteral("two words") << false;
        QTest::newRow("leading dot") << QStringLiteral(".example.com") << false;
        QTest::newRow("trailing dot") << QStringLiteral("example.") << false;
        QTest::newRow("dotted numeric hostname") << QStringLiteral("1.2.3") << true;
        QTest::newRow("uppercase localhost") << QStringLiteral("LOCALHOST") << true;
    }

    void looksLikeHost()
    {
        QFETCH(QString, input);
        QFETCH(bool, expected);
        QCOMPARE(UrlResolver::looksLikeHost(input), expected);
    }

    void resolveHost_data()
    {
        QTest::addColumn<QString>("input");
        QTest::addColumn<QString>("expectedHost");

        QTest::newRow("domain") << QStringLiteral("example.com") << QStringLiteral("example.com");
        QTest::newRow("localhost") << QStringLiteral("localhost:8080") << QStringLiteral("localhost");
        QTest::newRow("ipv4") << QStringLiteral("192.168.1.10") << QStringLiteral("192.168.1.10");
        QTest::newRow("surrounding whitespace") << QStringLiteral("  example.com  ")
                                                    << QStringLiteral("example.com");
    }

    void resolveHost()
    {
        QFETCH(QString, input);
        QFETCH(QString, expectedHost);
        const QUrl result = UrlResolver::resolve(input);
        QCOMPARE(result.scheme(), QStringLiteral("https"));
        QCOMPARE(result.host(), expectedHost);
    }

    void emptyInputProducesInvalidUrl()
    {
        QVERIFY(!UrlResolver::resolve(QString()).isValid());
        QVERIFY(!UrlResolver::resolve(QStringLiteral("   ")).isValid());
    }

    void explicitHttpAndHttpsSchemesArePreserved()
    {
        const QUrl http = UrlResolver::resolve(QStringLiteral("http://example.com/path"));
        QCOMPARE(http.scheme(), QStringLiteral("http"));
        QCOMPARE(http.path(), QStringLiteral("/path"));

        const QUrl https = UrlResolver::resolve(QStringLiteral("https://example.com"));
        QCOMPARE(https.scheme(), QStringLiteral("https"));
        QCOMPARE(https.host(), QStringLiteral("example.com"));
    }

    void unknownExplicitSchemeIsNotTurnedIntoSearch()
    {
        const QUrl result = UrlResolver::resolve(QStringLiteral("custom://service/path"));
        QCOMPARE(result.scheme(), QStringLiteral("custom"));
        QCOMPARE(result.host(), QStringLiteral("service"));
    }

    void chromeNewTabAliasesMapToIlluminateNewTab()
    {
        QCOMPARE(UrlResolver::resolve(QStringLiteral("chrome://newtab")),
                 QUrl(QStringLiteral("newtab://newtab")));
        QCOMPARE(UrlResolver::resolve(QStringLiteral("chrome://new-tab-page")),
                 QUrl(QStringLiteral("newtab://newtab")));
        QCOMPARE(UrlResolver::resolve(QStringLiteral("CHROME://NEWTAB")),
                 QUrl(QStringLiteral("newtab://newtab")));
    }

    void nonUrlTextUsesFallbackSearchTemplate()
    {
        const QUrl result = UrlResolver::resolve(QStringLiteral("two words"));
        QCOMPARE(result.host(), QStringLiteral("duckduckgo.com"));
        QCOMPARE(result.query(QUrl::FullyDecoded), QStringLiteral("q=two words"));
    }

    void searchUsesCustomTemplateAndEscapesQuery()
    {
        const QUrl result = UrlResolver::resolve(QStringLiteral("snow & sun"),
            QStringLiteral("https://search.example/find?q=%s"));
        QCOMPARE(result.host(), QStringLiteral("search.example"));
        QCOMPARE(result.query(QUrl::FullyDecoded), QStringLiteral("q=snow & sun"));
    }

    void templateWithoutPlaceholderUsesFallback()
    {
        const QUrl result = UrlResolver::searchUrl(QStringLiteral("cats"),
            QStringLiteral("https://search.example/"));
        QCOMPARE(result.host(), QStringLiteral("duckduckgo.com"));
        QCOMPARE(result.query(QUrl::FullyDecoded), QStringLiteral("q=cats"));
    }

    void repeatedPlaceholdersAreReplaced()
    {
        const QUrl result = UrlResolver::searchUrl(QStringLiteral("a b"),
            QStringLiteral("https://search.example/?q=%s&copy=%s"));
        QCOMPARE(result.query(QUrl::FullyDecoded), QStringLiteral("q=a b&copy=a b"));
    }

    void unicodeSearchTermIsEncodedAndDecodedCorrectly()
    {
        const QUrl result = UrlResolver::searchUrl(QStringLiteral("café 東京"));
        QCOMPARE(result.host(), QStringLiteral("duckduckgo.com"));
        QCOMPARE(result.query(QUrl::FullyDecoded), QString::fromUtf8("q=café 東京"));
    }
};

QTEST_GUILESS_MAIN(TestUrlResolver)
#include "tst_UrlResolver.moc"
