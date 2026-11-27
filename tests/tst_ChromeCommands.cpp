#include <QtTest>

#include "CefChromeCommands.h"

#include <include/cef_command_ids.h>

class TestChromeCommands : public QObject
{
    Q_OBJECT

    static void expectAction(int commandId, const QString &action, const QString &payload = {})
    {
        const ChromeCommandRoute route = routeChromeCommand(commandId);
        QCOMPARE(route.kind, ChromeCommandRoute::Action);
        QCOMPARE(route.action, action);
        QCOMPARE(route.payload, payload);
    }

private slots:
    // Chrome has no tab strip here; the sidebar owns tabs
    void tabCommandsGoToTheSidebar()
    {
        expectAction(IDC_NEW_TAB, QStringLiteral("tab.new"));
        expectAction(IDC_NEW_WINDOW, QStringLiteral("tab.new"));
        expectAction(IDC_CLOSE_TAB, QStringLiteral("tab.close"));
        expectAction(IDC_RESTORE_TAB, QStringLiteral("tab.reopenClosedTab"));
        expectAction(IDC_SELECT_NEXT_TAB, QStringLiteral("tab.next"));
        expectAction(IDC_SELECT_PREVIOUS_TAB, QStringLiteral("tab.previous"));
        expectAction(IDC_SELECT_TAB_0, QStringLiteral("tab.jump"), QStringLiteral("0"));
        expectAction(IDC_SELECT_TAB_7, QStringLiteral("tab.jump"), QStringLiteral("7"));
        expectAction(IDC_SELECT_LAST_TAB, QStringLiteral("tab.last"));
    }

    void chromeUiIsReplacedByOurs()
    {
        expectAction(IDC_FOCUS_LOCATION, QStringLiteral("view.focusAddressBar"));
        expectAction(IDC_DEV_TOOLS_INSPECT, QStringLiteral("dev.devTools"));
        expectAction(IDC_ZOOM_PLUS, QStringLiteral("view.zoomIn"));
        expectAction(IDC_SHOW_DOWNLOADS, QStringLiteral("page.downloads"));
        expectAction(IDC_MANAGE_EXTENSIONS, QStringLiteral("tab.open"), QStringLiteral("chrome://extensions"));
    }

    void pageCommandsStayWithChrome()
    {
        for (const int id : {IDC_FIND, IDC_PRINT, IDC_BASIC_PRINT, IDC_SAVE_PAGE, IDC_BACK, IDC_RELOAD, IDC_STOP})
            QCOMPARE(routeChromeCommand(id).kind, ChromeCommandRoute::Chrome);
        // extension commands from menus run as Chrome intends
        QCOMPARE(routeChromeCommand(IDC_EXTENSIONS_CONTEXT_CUSTOM_FIRST).kind, ChromeCommandRoute::Chrome);
    }

    // these would want Chrome's own window or toolbar
    void windowOnlyFeaturesAreBlocked()
    {
        for (const int id : {IDC_NEW_INCOGNITO_WINDOW, IDC_SHOW_APP_MENU,
                             IDC_SHOW_BOOKMARK_BAR, IDC_QRCODE_GENERATOR, IDC_HOME})
            QCOMPARE(routeChromeCommand(id).kind, ChromeCommandRoute::Blocked);
    }
};

QTEST_GUILESS_MAIN(TestChromeCommands)
#include "tst_ChromeCommands.moc"
