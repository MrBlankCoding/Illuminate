#include <QtTest>
#include <QGuiApplication>

#include "CefBrowserWrapper.h"

// Moving a live page between wrappers (how a space's last page shows
// instantly). Without a CEF runtime there are no live pages, so this checks
// that nothing is handed over that shouldn't be.
class TestPageHandover : public QObject
{
    Q_OBJECT

private slots:
    void aWrapperWithoutABrowserHasNoPage()
    {
        CefBrowserWrapper wrapper;
        QVERIFY(!wrapper.hasPage());
        QCOMPARE(wrapper.browserId(), 0);
    }

    void thereIsNothingToTakeFromNoOne()
    {
        CefBrowserWrapper wrapper;
        QVERIFY(!wrapper.adoptPage(nullptr));
        QVERIFY(!wrapper.adoptPage(&wrapper));
    }

    void anEmptyDonorChangesNothing()
    {
        CefBrowserWrapper tab;
        CefBrowserWrapper donor;
        donor.setUrl(QUrl(QStringLiteral("https://example.com/donor")));
        QSignalSpy urlSpy(&tab, &CefBrowserWrapper::urlChanged);
        QSignalSpy idSpy(&tab, &CefBrowserWrapper::browserIdChanged);

        QVERIFY(!tab.adoptPage(&donor));

        QCOMPARE(tab.url(), QUrl());
        QCOMPARE(urlSpy.size(), 0);
        QCOMPARE(idSpy.size(), 0);
        QCOMPARE(donor.url(), QUrl(QStringLiteral("https://example.com/donor")));
    }

    void destroyingAWrapperThatNeverHadAPageIsSafe()
    {
        auto *donor = new CefBrowserWrapper;
        CefBrowserWrapper tab;
        tab.adoptPage(donor);
        delete donor;
        QVERIFY(!tab.hasPage());
    }
};

QTEST_MAIN(TestPageHandover)
#include "tst_PageHandover.moc"
