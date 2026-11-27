#include <QtTest>

#include "CefPopupWindow.h"

// where a window.open() popup (e.g. "Sign in with Google") is placed
class TestCefPopupWindow : public QObject
{
    Q_OBJECT

    // the tab the popup is opened from, in screen DIP
    const CefRect m_tab{100, 50, 1200, 800};

    static CefPopupFeatures features()
    {
        CefPopupFeatures f{};
        return f;
    }

private slots:
    void noFeaturesGivesTheDefaultSizeCentredOverTheTab()
    {
        const CefRect bounds = CefPopupWindow::boundsFor(nullptr, m_tab);
        QCOMPARE(bounds.width, 500);
        QCOMPARE(bounds.height, 640);
        QCOMPARE(bounds.x, 100 + (1200 - 500) / 2);
        QCOMPARE(bounds.y, 50 + (800 - 640) / 2);
    }

    void emptyFeaturesAreTheSameAsNone()
    {
        const CefPopupFeatures f = features();
        const CefRect withEmpty = CefPopupWindow::boundsFor(&f, m_tab);
        const CefRect withNone = CefPopupWindow::boundsFor(nullptr, m_tab);
        QCOMPARE(withEmpty.x, withNone.x);
        QCOMPARE(withEmpty.y, withNone.y);
        QCOMPARE(withEmpty.width, withNone.width);
        QCOMPARE(withEmpty.height, withNone.height);
    }

    void requestedSizeIsHonouredAndStillCentred()
    {
        CefPopupFeatures f = features();
        f.width = 450;
        f.widthSet = 1;
        f.height = 600;
        f.heightSet = 1;
        const CefRect bounds = CefPopupWindow::boundsFor(&f, m_tab);
        QCOMPARE(bounds.width, 450);
        QCOMPARE(bounds.height, 600);
        QCOMPARE(bounds.x, 100 + (1200 - 450) / 2);
        QCOMPARE(bounds.y, 50 + (800 - 600) / 2);
    }

    void onlyOneDimensionCanBeRequested()
    {
        CefPopupFeatures f = features();
        f.width = 700;
        f.widthSet = 1;
        const CefRect bounds = CefPopupWindow::boundsFor(&f, m_tab);
        QCOMPARE(bounds.width, 700);
        QCOMPARE(bounds.height, 640);
    }

    void tinyPopupsAreGrownToSomethingUsable_data()
    {
        QTest::addColumn<int>("width");
        QTest::addColumn<int>("height");
        QTest::addColumn<int>("expectedWidth");
        QTest::addColumn<int>("expectedHeight");
        QTest::newRow("1x1 tracking popup") << 1 << 1 << 320 << 240;
        QTest::newRow("zero") << 0 << 0 << 320 << 240;
        QTest::newRow("negative") << -50 << -50 << 320 << 240;
        QTest::newRow("just above the minimum") << 321 << 241 << 321 << 241;
    }
    void tinyPopupsAreGrownToSomethingUsable()
    {
        QFETCH(int, width);
        QFETCH(int, height);
        QFETCH(int, expectedWidth);
        QFETCH(int, expectedHeight);
        CefPopupFeatures f = features();
        f.width = width;
        f.widthSet = 1;
        f.height = height;
        f.heightSet = 1;
        const CefRect bounds = CefPopupWindow::boundsFor(&f, m_tab);
        QCOMPARE(bounds.width, expectedWidth);
        QCOMPARE(bounds.height, expectedHeight);
    }

    void requestedPositionWins()
    {
        CefPopupFeatures f = features();
        f.x = 10;
        f.xSet = 1;
        f.y = 20;
        f.ySet = 1;
        const CefRect bounds = CefPopupWindow::boundsFor(&f, m_tab);
        QCOMPARE(bounds.x, 10);
        QCOMPARE(bounds.y, 20);
    }

    void aPartialPositionKeepsTheOtherAxisCentred()
    {
        CefPopupFeatures f = features();
        f.y = 5;
        f.ySet = 1;
        const CefRect bounds = CefPopupWindow::boundsFor(&f, m_tab);
        QCOMPARE(bounds.y, 5);
        QCOMPARE(bounds.x, 100 + (1200 - 500) / 2);
    }

    void aSmallTabCentresThePopupPastItsEdges()
    {
        // the popup is bigger than the tab: it overhangs evenly on both sides
        const CefRect smallTab{400, 300, 200, 100};
        const CefRect bounds = CefPopupWindow::boundsFor(nullptr, smallTab);
        QCOMPARE(bounds.x + bounds.width / 2, smallTab.x + smallTab.width / 2);
        QCOMPARE(bounds.y + bounds.height / 2, smallTab.y + smallTab.height / 2);
    }

    void hiddenTabsCanBeRememberedAndForgotten()
    {
        CefPopupWindow::rememberHiddenTab(777);
        CefPopupWindow::forgetFeatures(777);
        CefPopupWindow::rememberHiddenTab(777);
        // a later real popup from the same opener replaces it
        CefPopupWindow::rememberFeatures(777, features());
        CefPopupWindow::forgetFeatures(777);
    }

    void forgettingUnknownOpenersIsHarmless()
    {
        CefPopupWindow::forgetFeatures(12345);
        CefPopupWindow::rememberFeatures(12345, features());
        CefPopupWindow::forgetFeatures(12345);
        CefPopupWindow::forgetFeatures(12345);
    }
};

QTEST_GUILESS_MAIN(TestCefPopupWindow)
#include "tst_CefPopupWindow.moc"
