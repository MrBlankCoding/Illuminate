#include <QtTest>
#include <QStandardPaths>
#include "PermissionHandler.h"

class TestPermissionHandler : public QObject
{
    Q_OBJECT
private slots:
    void initTestCase()
    {
        QStandardPaths::setTestModeEnabled(true);
    }

    void noDecisionReturnsZero()
    {
        PermissionHandler pm(nullptr);
        QCOMPARE(pm.decision(QUrl(QStringLiteral("https://example.com")),
                            static_cast<int>(PermissionHandler::Geolocation)), 0);
    }

    void rememberAllowThenDecide()
    {
        PermissionHandler pm(nullptr);
        const QUrl origin("https://example.com");
        const int type = static_cast<int>(PermissionHandler::MediaVideoCapture);

        pm.storeDecision(origin, type, /*allow*/ true, /*remember*/ true);
        QCOMPARE(pm.decision(origin, type), 1);
    }

    void rememberDenyThenDecide()
    {
        PermissionHandler pm(nullptr);
        const QUrl origin("https://ad-supported.site");
        const int type = static_cast<int>(PermissionHandler::Notifications);

        pm.storeDecision(origin, type, /*allow*/ false, /*remember*/ true);
        QCOMPARE(pm.decision(origin, type), -1);
    }

    void decisionsAreOriginScoped()
    {
        PermissionHandler pm(nullptr);
        const int geo = static_cast<int>(PermissionHandler::Geolocation);
        pm.storeDecision(QUrl(QStringLiteral("https://one.test")), geo, true, true);
        QCOMPARE(pm.decision(QUrl(QStringLiteral("https://two.test")), geo), 0);
        QCOMPARE(pm.decision(QUrl(QStringLiteral("https://one.test")), geo), 1);
    }

    void forgetWhenNotRemembering()
    {
        PermissionHandler pm(nullptr);
        const QUrl origin("https://tmp.test");
        const int mic = static_cast<int>(PermissionHandler::MediaAudioCapture);

        pm.storeDecision(origin, mic, true, /*remember*/ false);
        QCOMPARE(pm.decision(origin, mic), 0); // not persisted
    }

    void labelsAreHumanReadable()
    {
        PermissionHandler pm(nullptr);
        QCOMPARE(pm.labelForType(static_cast<int>(PermissionHandler::Geolocation)),
                 QStringLiteral("Location"));
        QCOMPARE(pm.labelForType(static_cast<int>(PermissionHandler::MediaVideoCapture)),
                 QStringLiteral("Camera"));
    }
    void forgetClearsDecision()
    {
        PermissionHandler pm(nullptr);
        const QUrl origin("https://forget.test");
        const int geo = static_cast<int>(PermissionHandler::Geolocation);
        pm.storeDecision(origin, geo, true, true);
        pm.forget(origin, geo);
        QCOMPARE(pm.decision(origin, geo), 0);
    }

    void rememberedDecisionsListsStoredChoices()
    {
        PermissionHandler pm(nullptr);
        pm.forgetAll();
        const int cam = static_cast<int>(PermissionHandler::MediaVideoCapture);
        pm.storeDecision(QUrl(QStringLiteral("https://list.test")), cam, false, true);

        const QVariantList all = pm.rememberedDecisions();
        QCOMPARE(all.size(), 1);
        const QVariantMap entry = all.first().toMap();
        QCOMPARE(entry.value("host").toString(), QStringLiteral("list.test"));
        QCOMPARE(entry.value("type").toInt(), cam);
        QCOMPARE(entry.value("allow").toBool(), false);

        pm.forgetAll();
        QVERIFY(pm.rememberedDecisions().isEmpty());
    }

    void typesWithoutOsGateAreGranted()
    {
        PermissionHandler pm(nullptr);
        const int clip = static_cast<int>(PermissionHandler::ClipboardReadWrite);
        QCOMPARE(pm.systemAccessForType(clip), static_cast<int>(PermissionHandler::Granted));
        QCOMPARE(pm.blockedResourceForType(clip), -1);
    }
};

QTEST_GUILESS_MAIN(TestPermissionHandler)
#include "tst_PermissionHandler.moc"
