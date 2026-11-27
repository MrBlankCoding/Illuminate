#include "CefChromeCommands.h"

#include <include/cef_command_ids.h>

namespace
{
ChromeCommandRoute action(const QString &id, const QString &payload = {})
{
    return {ChromeCommandRoute::Action, id, payload};
}

ChromeCommandRoute blocked()
{
    return {ChromeCommandRoute::Blocked, {}, {}};
}
}

ChromeCommandRoute routeChromeCommand(int commandId)
{
    if (commandId >= IDC_SELECT_TAB_0 && commandId <= IDC_SELECT_TAB_7)
        return action(QStringLiteral("tab.jump"), QString::number(commandId - IDC_SELECT_TAB_0));

    switch (commandId)
    {
    // tabs and windows belong to the sidebar, not to Chrome
    case IDC_NEW_TAB:
    case IDC_NEW_WINDOW:
        return action(QStringLiteral("tab.new"));
    case IDC_CLOSE_TAB:
        return action(QStringLiteral("tab.close"));
    case IDC_RESTORE_TAB:
        return action(QStringLiteral("tab.reopenClosedTab"));
    case IDC_SELECT_NEXT_TAB:
        return action(QStringLiteral("tab.next"));
    case IDC_SELECT_PREVIOUS_TAB:
        return action(QStringLiteral("tab.previous"));
    case IDC_SELECT_LAST_TAB:
        return action(QStringLiteral("tab.last"));
    case IDC_CLOSE_WINDOW:
        return action(QStringLiteral("app.closeWindow"));
    case IDC_MINIMIZE_WINDOW:
        return action(QStringLiteral("window.minimize"));
    case IDC_EXIT:
        return action(QStringLiteral("app.quit"));

    // Find commands fall through to CEF's Chrome runtime UI.
    case IDC_FOCUS_LOCATION:
    case IDC_FOCUS_SEARCH:
        return action(QStringLiteral("view.focusAddressBar"));
    case IDC_FULLSCREEN:
        return action(QStringLiteral("view.fullScreen"));
    // zoom goes through the zoom indicator so it stays in step
    case IDC_ZOOM_PLUS:
        return action(QStringLiteral("view.zoomIn"));
    case IDC_ZOOM_MINUS:
        return action(QStringLiteral("view.zoomOut"));
    case IDC_ZOOM_NORMAL:
        return action(QStringLiteral("view.zoomReset"));
    // one DevTools window per page, toggled the same way as our shortcut
    case IDC_DEV_TOOLS:
    case IDC_DEV_TOOLS_CONSOLE:
    case IDC_DEV_TOOLS_INSPECT:
    case IDC_DEV_TOOLS_DEVICES:
    case IDC_DEV_TOOLS_TOGGLE:
        return action(QStringLiteral("dev.devTools"));
    case IDC_TASK_MANAGER:
        return action(QStringLiteral("app.settings"));
    case IDC_SHOW_HISTORY:
        return action(QStringLiteral("history.show"));
    case IDC_SHOW_DOWNLOADS:
        return action(QStringLiteral("page.downloads"));
    case IDC_BOOKMARK_THIS_TAB:
        return action(QStringLiteral("bookmark.toggle"));
    case IDC_COPY_URL:
        return action(QStringLiteral("page.copyUrl"));
    case IDC_OPTIONS:
        return action(QStringLiteral("app.settings"));
    case IDC_ABOUT:
        return action(QStringLiteral("app.about"));

    // Chrome pages that are fine in one of our tabs
    case IDC_MANAGE_EXTENSIONS:
        return action(QStringLiteral("tab.open"), QStringLiteral("chrome://extensions"));
    case IDC_SHOW_PASSWORD_MANAGER:
        return action(QStringLiteral("tab.open"), QStringLiteral("chrome://password-manager"));
    case IDC_CLEAR_BROWSING_DATA:
        return action(QStringLiteral("tab.open"), QStringLiteral("chrome://settings/clearBrowserData"));

    // tab strip, toolbar and window features with nowhere to show
    case IDC_NEW_INCOGNITO_WINDOW:
    case IDC_DUPLICATE_TAB:
    case IDC_MOVE_TAB_NEXT:
    case IDC_MOVE_TAB_PREVIOUS:
    case IDC_PIN_TARGET_TAB:
    case IDC_WINDOW_CLOSE_TABS_TO_RIGHT:
    case IDC_BOOKMARK_ALL_TABS:
    case IDC_SHOW_BOOKMARK_BAR:
    case IDC_SHOW_BOOKMARK_MANAGER:
    case IDC_HOME:
    case IDC_HELP_PAGE_VIA_KEYBOARD:
    case IDC_SHOW_APP_MENU:
    case IDC_SHOW_AVATAR_MENU:
    case IDC_FOCUS_TOOLBAR:
    case IDC_FOCUS_NEXT_PANE:
    case IDC_FOCUS_PREVIOUS_PANE:
    case IDC_TOGGLE_FULLSCREEN_TOOLBAR:
    case IDC_SHOW_FULL_URLS:
    case IDC_SEND_TAB_TO_SELF:
    case IDC_QRCODE_GENERATOR:
    case IDC_SHOW_TRANSLATE:
    case IDC_CREATE_SHORTCUT:
        return blocked();
    }

    // printing, saving, back/forward/reload, extension commands and the rest
    return {};
}
