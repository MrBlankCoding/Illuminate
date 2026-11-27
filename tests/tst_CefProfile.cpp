#include <QtTest>

#include <QSignalSpy>
#include <QTemporaryDir>

#include "CefManager.h"
#include "CefProfile.h"

class TestCefProfile : public QObject
{
    Q_OBJECT

    QTemporaryDir m_dir;

private slots:
    void initTestCase()
    {
        QVERIFY(m_dir.isValid());
        QVERIFY(!CefManager::isInitialized());
    }

    void requestContextIsUnavailableBeforeCefInitialization()
    {
        CefProfile profile(m_dir.filePath(QStringLiteral("profile")),
                           m_dir.filePath(QStringLiteral("cache")));
        QVERIFY(!profile.requestContext());
    }

    void cookiePreferenceCanBeChangedWithoutCef()
    {
        CefProfile profile(m_dir.filePath(QStringLiteral("profile")),
                           m_dir.filePath(QStringLiteral("cache")));
        QSignalSpy spy(&profile, &CefProfile::thirdPartyCookiesAllowedChanged);

        profile.setThirdPartyCookiesAllowed(false);
        profile.setThirdPartyCookiesAllowed(false);

        QVERIFY(!profile.thirdPartyCookiesAllowed());
        QCOMPARE(spy.size(), 1);
    }

    void memorySaverSettingsAreSafeBeforeCefInitialization()
    {
        CefProfile profile(m_dir.filePath(QStringLiteral("profile")),
                           m_dir.filePath(QStringLiteral("cache")));
        profile.setMemorySaverSettings(true, -5);
        profile.setMemorySaverSettings(false, 5);
        QVERIFY(!profile.requestContext());
    }

    void cookieClearReportsUninitializedEngineWithoutStayingBusy()
    {
        CefProfile profile(m_dir.filePath(QStringLiteral("profile")),
                           m_dir.filePath(QStringLiteral("cache")));
        QSignalSpy busySpy(&profile, &CefProfile::privacyOperationBusyChanged);
        QSignalSpy statusSpy(&profile, &CefProfile::privacyOperationStatusChanged);

        profile.clearCookies();

        QVERIFY(!profile.privacyOperationBusy());
        QCOMPARE(profile.privacyOperationStatus(),
                 QStringLiteral("The browser engine is not initialized."));
        QCOMPARE(busySpy.size(), 0);
        QCOMPARE(statusSpy.size(), 1);
    }

    void cacheClearReportsUninitializedEngineWithoutStayingBusy()
    {
        CefProfile profile(m_dir.filePath(QStringLiteral("profile")),
                           m_dir.filePath(QStringLiteral("cache")));
        profile.clearCache();
        QVERIFY(!profile.privacyOperationBusy());
        QCOMPARE(profile.privacyOperationStatus(),
                 QStringLiteral("The browser engine is not initialized."));
    }

    void repeatedClearRequestsRemainSafe()
    {
        CefProfile profile(m_dir.filePath(QStringLiteral("profile")),
                           m_dir.filePath(QStringLiteral("cache")));
        profile.finishPrivacyOperation(QStringLiteral("Existing result"));
        profile.clearCookies();
        profile.clearCache();
        QCOMPARE(profile.privacyOperationStatus(),
                 QStringLiteral("The browser engine is not initialized."));
    }
};

QTEST_GUILESS_MAIN(TestCefProfile)
#include "tst_CefProfile.moc"
