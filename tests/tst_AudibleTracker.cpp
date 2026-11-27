#include <QtTest>
#include <QSignalSpy>

#include "AudibleTracker.h"

// the speaker on a tab: sound shows at once, silence only once it has lasted
class TestAudibleTracker : public QObject
{
    Q_OBJECT

private slots:
    void soundShowsAtOnce()
    {
        AudibleTracker tracker;
        QSignalSpy spy(&tracker, &AudibleTracker::audibleChanged);
        tracker.report(QStringLiteral("main"), true);
        QVERIFY(tracker.audible());
        QCOMPARE(spy.size(), 1);
    }

    void silenceWaitsBeforeTheSpeakerGoes()
    {
        AudibleTracker tracker;
        tracker.setHoldMs(150);
        tracker.report(QStringLiteral("main"), true);
        QSignalSpy spy(&tracker, &AudibleTracker::audibleChanged);
        tracker.report(QStringLiteral("main"), false);
        QVERIFY(tracker.audible()); // still showing
        QCOMPARE(spy.size(), 0);
        QTRY_VERIFY_WITH_TIMEOUT(!tracker.audible(), 1000);
        QCOMPARE(spy.size(), 1);
    }

    // buffering, the next track, an ad swapping in: no blink
    void aShortSilenceNeverHidesTheSpeaker()
    {
        AudibleTracker tracker;
        tracker.setHoldMs(200);
        QSignalSpy spy(&tracker, &AudibleTracker::audibleChanged);
        tracker.report(QStringLiteral("main"), true);
        for (int i = 0; i < 5; ++i)
        {
            tracker.report(QStringLiteral("main"), false);
            QTest::qWait(50);
            tracker.report(QStringLiteral("main"), true);
        }
        QTest::qWait(300);
        QVERIFY(tracker.audible());
        QCOMPARE(spy.size(), 1); // shown once, never hidden
    }

    void anyFrameMakingSoundCounts()
    {
        AudibleTracker tracker;
        tracker.setHoldMs(100);
        tracker.report(QStringLiteral("main"), true);
        tracker.report(QStringLiteral("youtube-embed"), true);
        tracker.report(QStringLiteral("main"), false);
        QTest::qWait(200);
        QVERIFY(tracker.audible()); // the embed still plays
        tracker.report(QStringLiteral("youtube-embed"), false);
        QTRY_VERIFY_WITH_TIMEOUT(!tracker.audible(), 1000);
    }

    void aClosedOrCrashedPageGoesQuietAtOnce()
    {
        AudibleTracker tracker;
        tracker.report(QStringLiteral("main"), true);
        tracker.clear();
        QVERIFY(!tracker.audible());
        // and a late hold doesn't bring anything back
        QTest::qWait(50);
        QVERIFY(!tracker.audible());
    }

    void quietFramesReportingQuietChangeNothing()
    {
        AudibleTracker tracker;
        QSignalSpy spy(&tracker, &AudibleTracker::audibleChanged);
        tracker.report(QStringLiteral("main"), false);
        tracker.report(QStringLiteral("other"), false);
        QVERIFY(!tracker.audible());
        QCOMPARE(spy.size(), 0);
    }

    void theDefaultHoldOutlastsATrackChange()
    {
        QVERIFY(AudibleTracker::kSilenceHoldMs >= 1500);
    }
    // a page moving to another wrapper brings what it was playing
    void anAdoptedPageKeepsItsSound()
    {
        AudibleTracker parked;
        parked.report(QStringLiteral("main"), true);
        AudibleTracker tab;
        QSignalSpy spy(&tab, &AudibleTracker::audibleChanged);
        tab.adopt(parked);
        QVERIFY(tab.audible());
        QCOMPARE(spy.size(), 1);
        // and its frames keep reporting to the new owner
        tab.setHoldMs(50);
        tab.report(QStringLiteral("main"), false);
        QTRY_VERIFY_WITH_TIMEOUT(!tab.audible(), 1000);
    }

    void adoptingASilentPageIsSilent()
    {
        AudibleTracker parked;
        AudibleTracker tab;
        tab.adopt(parked);
        QVERIFY(!tab.audible());
    }
};

QTEST_GUILESS_MAIN(TestAudibleTracker)
#include "tst_AudibleTracker.moc"
