#include <QtTest>
#include <QSignalSpy>

#include <memory>

#include "BeforeUnloadRequest.h"
#include "CefRequestHandler.h"

// a page's "Leave site?" question, answered through the app's own dialog
class TestBeforeUnloadRequest : public QObject
{
    Q_OBJECT

private slots:
    void leaveTellsThePageToGo()
    {
        QList<bool> answers;
        BeforeUnloadRequest request(false, [&answers](bool leave) { answers.append(leave); });
        QSignalSpy answered(&request, &BeforeUnloadRequest::answeredWith);
        QSignalSpy finished(&request, &BeforeUnloadRequest::finished);
        QVERIFY(!request.answered());

        request.leave();
        QCOMPARE(answers, QList<bool>{true});
        QVERIFY(request.answered());
        QCOMPARE(answered.size(), 1);
        QCOMPARE(answered.at(0).at(0).toBool(), true);
        QCOMPARE(finished.size(), 1);
    }

    void stayKeepsThePage()
    {
        QList<bool> answers;
        BeforeUnloadRequest request(true, [&answers](bool leave) { answers.append(leave); });
        QVERIFY(request.isReload());
        request.stay();
        QCOMPARE(answers, QList<bool>{false});
    }

    void onlyTheFirstAnswerCounts()
    {
        QList<bool> answers;
        BeforeUnloadRequest request(false, [&answers](bool leave) { answers.append(leave); });
        QSignalSpy finished(&request, &BeforeUnloadRequest::finished);
        request.stay();
        request.leave();
        request.stay();
        QCOMPARE(answers, QList<bool>{false});
        QCOMPARE(finished.size(), 1);
    }

    // the dialog going away without a choice must never close the page
    void anUnansweredRequestMeansStay()
    {
        QList<bool> answers;
        {
            BeforeUnloadRequest request(false, [&answers](bool leave) { answers.append(leave); });
        }
        QCOMPARE(answers, QList<bool>{false});
    }

    void aDismissedRequestAnswersNothing()
    {
        QList<bool> answers;
        auto request = std::make_unique<BeforeUnloadRequest>(false, [&answers](bool leave) { answers.append(leave); });
        QSignalSpy finished(request.get(), &BeforeUnloadRequest::finished);
        QSignalSpy answered(request.get(), &BeforeUnloadRequest::answeredWith);
        request->dismiss();
        QVERIFY(request->answered());
        QCOMPARE(finished.size(), 1);
        QCOMPARE(answered.size(), 0);
        request->leave();
        request.reset();
        QVERIFY(answers.isEmpty());
    }

    // the crash page carries the address it stands in for

    void crashPageCarriesTheAddress()
    {
        const QString page = QStringLiteral("https://example.com/a?b=1&c=two words#frag");
        const QUrl crash = CefRequestHandlerImpl::crashPageFor(page);
        QCOMPARE(crash.scheme(), QStringLiteral("illuminate"));
        QCOMPARE(crash.host(), QStringLiteral("crashed"));
        const QString encoded = crash.toString(QUrl::FullyEncoded);
        const QString value = encoded.mid(encoded.indexOf(QStringLiteral("?url=")) + 5);
        QCOMPARE(QUrl::fromPercentEncoding(value.toLatin1()), page);
        // nothing in the address leaks out as a separate query item or fragment
        QVERIFY(!crash.hasFragment());
    }

    void crashLoopWindowIsAMinute()
    {
        QCOMPARE(CefRequestHandlerImpl::kCrashLoopWindowMs, qint64(60 * 1000));
    }
};

QTEST_GUILESS_MAIN(TestBeforeUnloadRequest)
#include "tst_BeforeUnloadRequest.moc"
