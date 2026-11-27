import QtQuick
import illuminate.ui as App

Item {
    id: root

    required property var browser
    required property var logger
    required property var appMenu
    required property var shortcuts
    property var activeWebView: null

    signal settingsRequested
    signal commandBarRequested(string mode)   // "new" | "edit"
    signal sidebarToggleRequested
    signal themeRequested
    signal bookmarkToggleRequested
    signal printRequested
    signal savePdfRequested
    signal fullScreenRequested
    signal aboutRequested
    signal quitRequested
    signal closeWindowRequested
    signal spaceSwitchRequested(string spaceId)
    signal newSpaceRequested
    signal windowRequested(string action)

    function performEdit(id) {
        const focusedItem = root.Window.window ? root.Window.window.activeFocusItem : null
        const methods = { "edit.pastePlainText": "paste", "edit.selectAll": "selectAll" }
        const method = methods[id] || id.slice("edit.".length)
        // Window shortcuts take precedence over text controls' built-in editing
        // keys. Forward those commands to the focused QML editor when possible.
        if (focusedItem && typeof focusedItem[method] === "function") {
            focusedItem[method]()
            return
        }

        root.perform(id)
    }

    function perform(id, payload) {
        switch (id) {
        case "tab.new":
            root.commandBarRequested("new")
            return
        case "tab.close":
            root.browser.closeTab(root.browser.tabModel.activeIndex)
            return
        case "tab.reopenClosed":
        case "tab.reopenClosedTab":
            root.browser.reopenLastClosedTab()
            return
        case "tab.next":
            root.browser.cycleTab(1)
            return
        case "tab.previous":
            root.browser.cycleTab(-1)
            return
        // the open tab list and the Ctrl+1..9 jumps both name a position
        case "tab.activate":
        case "tab.jump":
            root.browser.activateTab(parseInt(payload, 10))
            return
        case "tab.last":
            root.browser.activateTab(root.browser.tabModel.count - 1)
            return
        case "tab.split": {
            const model = root.browser.tabModel
            const first = model.tabAt(model.activeIndex)
            const nextIndex = model.activeIndex + 1
            const second = nextIndex < model.count ? model.tabAt(nextIndex) : null
            if (first && second && !root.browser.sidebar.isSplitTab(first.id)
                    && !root.browser.sidebar.isSplitTab(second.id))
                root.browser.sidebar.createSplit(first.id, second.id)
            return
        }
        // a page in a tab of its own, e.g. chrome://extensions
        case "tab.open":
            root.browser.newTab(payload)
            return

        case "history.back":
            root.browser.goBack()
            return
        case "history.forward":
            root.browser.goForward()
            return
        case "history.reload":
            root.browser.reload()
            return
        case "history.show":
            root.browser.newTab("chrome://history/")
            return
        case "extensions.show":
            root.browser.newTab("chrome://extensions/")
            return

        case "view.toggleSidebar":
            root.sidebarToggleRequested()
            return
        case "view.theme":
            root.themeRequested()
            return
        case "view.zoomIn":
            if (root.activeWebView)
                root.activeWebView.zoomFactor = Math.min(5.0,
                    root.activeWebView.zoomFactor + 0.1)
            return
        case "view.zoomOut":
            if (root.activeWebView)
                root.activeWebView.zoomFactor = Math.max(0.25,
                    root.activeWebView.zoomFactor - 0.1)
            return
        case "view.zoomReset":
            if (root.activeWebView)
                root.activeWebView.zoomFactor = 1.0
            return
        case "view.fullScreen":
            // the window itself, not the page's own element fullscreen
            root.fullScreenRequested()
            return
        case "view.focusAddressBar":
            root.commandBarRequested("edit")
            return

        case "dev.devTools":
            root.browser.toggleDevTools()
            return

        case "page.find":
            root.browser.executeChromeCommand("find")
            return
        case "page.findNext":
            root.browser.executeChromeCommand("findNext")
            return
        case "page.findPrevious":
            root.browser.executeChromeCommand("findPrevious")
            return
        case "page.copyUrl":
            root.browser.copyActiveUrl()
            return
        case "page.print":
            root.printRequested()
            return
        case "page.savePdf":
            root.savePdfRequested()
            return
        case "page.downloads":
            root.browser.newTab("chrome://downloads/")
            return

        case "bookmark.toggle":
            root.bookmarkToggleRequested()
            return
        case "bookmark.open":
            root.browser.newTab(payload)
            return

        case "space.switch":
            root.spaceSwitchRequested(payload)
            return
        case "space.next":
            App.Spaces.cycleSpace(1)
            return
        case "space.previous":
            App.Spaces.cycleSpace(-1)
            return
        case "space.new":
            root.newSpaceRequested()
            return

        case "app.settings":
            root.settingsRequested()
            return
        case "app.closeWindow":
            root.closeWindowRequested()
            return
        case "app.about":
            root.aboutRequested()
            return
        case "app.quit":
            root.quitRequested()
            return

        case "window.minimize":
            root.windowRequested("minimize")
            return
        case "window.zoom":
            root.windowRequested("zoom")
            return
        case "edit.cut":
            root.browser.executeChromeCommand("cut")
            return
        case "edit.copy":
            root.browser.executeChromeCommand("copy")
            return
        case "edit.paste":
            root.browser.executeChromeCommand("paste")
            return
        case "edit.pastePlainText":
            root.browser.executeChromeCommand("pastePlainText")
            return
        case "edit.selectAll":
            root.browser.executeChromeCommand("selectAll")
            return
        case "edit.undo":
            root.browser.executeChromeCommand("undo")
            return
        case "edit.redo":
            root.browser.executeChromeCommand("redo")
            return
        }

        console.warn("KeyboardShortcuts", "No handler for action: " + id)
    }

    Connections {
        target: root.appMenu
        function onActionTriggered(id, payload) {
            root.perform(id, payload)
        }
    }

    // tabs
    Shortcut {
        context: Qt.WindowShortcut
        sequences: root.shortcuts.bindings.newTab
        onActivated: root.perform("tab.new")
    }
    Shortcut {
        context: Qt.WindowShortcut
        enabled: !root.appMenu.native
        sequences: root.shortcuts.bindings.closeTab
        onActivated: root.perform("tab.close")
    }
    Shortcut {
        context: Qt.WindowShortcut
        enabled: !root.appMenu.native
        sequences: root.shortcuts.bindings.reopenClosedTab
        onActivated: root.perform("tab.reopenClosedTab")
    }
    Shortcut {
        context: Qt.WindowShortcut
        sequences: root.shortcuts.bindings.nextTab
        onActivated: root.perform("tab.next")
    }
    Shortcut {
        context: Qt.WindowShortcut
        sequences: root.shortcuts.bindings.previousTab
        onActivated: root.perform("tab.previous")
    }

    Shortcut {
        context: Qt.WindowShortcut
        sequences: root.shortcuts.bindings.tab1
        onActivated: root.browser.activateTab(0)
    }
    Shortcut {
        context: Qt.WindowShortcut
        sequences: root.shortcuts.bindings.tab2
        onActivated: root.browser.activateTab(1)
    }
    Shortcut {
        context: Qt.WindowShortcut
        sequences: root.shortcuts.bindings.tab3
        onActivated: root.browser.activateTab(2)
    }
    Shortcut {
        context: Qt.WindowShortcut
        sequences: root.shortcuts.bindings.tab4
        onActivated: root.browser.activateTab(3)
    }
    Shortcut {
        context: Qt.WindowShortcut
        sequences: root.shortcuts.bindings.tab5
        onActivated: root.browser.activateTab(4)
    }
    Shortcut {
        context: Qt.WindowShortcut
        sequences: root.shortcuts.bindings.tab6
        onActivated: root.browser.activateTab(5)
    }
    Shortcut {
        context: Qt.WindowShortcut
        sequences: root.shortcuts.bindings.tab7
        onActivated: root.browser.activateTab(6)
    }
    Shortcut {
        context: Qt.WindowShortcut
        sequences: root.shortcuts.bindings.tab8
        onActivated: root.browser.activateTab(7)
    }
    Shortcut {
        context: Qt.WindowShortcut
        sequences: root.shortcuts.bindings.lastTab
        onActivated: root.browser.activateTab(root.browser.tabModel.count - 1)
    }
    Shortcut {
        context: Qt.WindowShortcut
        sequences: root.shortcuts.bindings.splitTabs
        onActivated: root.perform("tab.split")
    }

    // navigation
    Shortcut {
        context: Qt.WindowShortcut
        sequences: root.shortcuts.bindings.reload
        onActivated: root.perform("history.reload")
    }
    Shortcut {
        context: Qt.WindowShortcut
        sequences: root.shortcuts.bindings.back
        onActivated: root.perform("history.back")
    }
    Shortcut {
        context: Qt.WindowShortcut
        sequences: root.shortcuts.bindings.forward
        onActivated: root.perform("history.forward")
    }
    Shortcut {
        context: Qt.WindowShortcut
        sequences: root.shortcuts.bindings.copyUrl
        onActivated: root.perform("page.copyUrl")
    }

    // find
    Shortcut {
        context: Qt.WindowShortcut
        enabled: !root.appMenu.native
        sequences: root.shortcuts.bindings.find
        onActivated: root.perform("page.find")
    }
    Shortcut {
        context: Qt.WindowShortcut
        enabled: !root.appMenu.native
        sequences: root.shortcuts.bindings.findNext
        onActivated: root.perform("page.findNext")
    }
    Shortcut {
        context: Qt.WindowShortcut
        enabled: !root.appMenu.native
        sequences: root.shortcuts.bindings.findPrevious
        onActivated: root.perform("page.findPrevious")
    }

    Shortcut {
        context: Qt.WindowShortcut
        sequences: root.shortcuts.bindings.cut
        onActivated: root.performEdit("edit.cut")
    }
    Shortcut {
        context: Qt.WindowShortcut
        sequences: root.shortcuts.bindings.copy
        onActivated: root.performEdit("edit.copy")
    }
    Shortcut {
        context: Qt.WindowShortcut
        sequences: root.shortcuts.bindings.paste
        onActivated: root.performEdit("edit.paste")
    }
    Shortcut {
        context: Qt.WindowShortcut
        sequences: root.shortcuts.bindings.pastePlainText
        onActivated: root.performEdit("edit.pastePlainText")
    }
    Shortcut {
        context: Qt.WindowShortcut
        sequences: root.shortcuts.bindings.selectAll
        onActivated: root.performEdit("edit.selectAll")
    }
    Shortcut {
        context: Qt.WindowShortcut
        sequences: root.shortcuts.bindings.undo
        onActivated: root.performEdit("edit.undo")
    }
    Shortcut {
        context: Qt.WindowShortcut
        sequences: root.shortcuts.bindings.redo
        onActivated: root.performEdit("edit.redo")
    }

    // developer tools
    Shortcut {
        context: Qt.WindowShortcut
        sequences: root.shortcuts.bindings.toggleDevTools
        onActivated: root.perform("dev.devTools")
    }

    // zoom in/out/reset
    Shortcut {
        context: Qt.WindowShortcut
        sequences: root.shortcuts.bindings.zoomIn
        onActivated: root.perform("view.zoomIn")
    }
    Shortcut {
        context: Qt.WindowShortcut
        sequences: root.shortcuts.bindings.zoomOut
        onActivated: root.perform("view.zoomOut")
    }
    Shortcut {
        context: Qt.WindowShortcut
        sequences: root.shortcuts.bindings.zoomReset
        onActivated: root.perform("view.zoomReset")
    }

    Shortcut {
        context: Qt.WindowShortcut
        sequences: root.shortcuts.bindings.toggleSidebar
        onActivated: root.perform("view.toggleSidebar")
    }

    Shortcut {
        context: Qt.WindowShortcut
        sequences: root.shortcuts.bindings.toggleTheme
        onActivated: root.perform("view.theme")
    }

    // the window itself, not the page's own element fullscreen
    Shortcut {
        context: Qt.WindowShortcut
        sequences: root.shortcuts.bindings.toggleFullScreen
        onActivated: root.perform("view.fullScreen")
    }

    // focus address bar
    Shortcut {
        context: Qt.WindowShortcut
        sequences: ["Ctrl+L", "Meta+L"]
        onActivated: root.perform("view.focusAddressBar")
    }

    // settings
    Shortcut {
        context: Qt.WindowShortcut
        sequences: root.shortcuts.bindings.settings
        onActivated: root.perform("app.settings")
    }

    // print
    Shortcut {
        context: Qt.WindowShortcut
        sequences: root.shortcuts.bindings.print
        onActivated: root.perform("page.print")
    }

    // save a copy as PDF
    Shortcut {
        context: Qt.WindowShortcut
        sequences: root.shortcuts.bindings.savePdf
        onActivated: root.perform("page.savePdf")
    }

    // downloads
    Shortcut {
        context: Qt.WindowShortcut
        sequences: root.shortcuts.bindings.downloads
        onActivated: root.perform("page.downloads")
    }

    // bookmarks
    Shortcut {
        context: Qt.WindowShortcut
        sequences: root.shortcuts.bindings.toggleBookmark
        onActivated: root.perform("bookmark.toggle")
    }

    // spaces
    Shortcut {
        context: Qt.WindowShortcut
        sequences: root.shortcuts.bindings.nextSpace
        onActivated: root.perform("space.next")
    }
    Shortcut {
        context: Qt.WindowShortcut
        sequences: root.shortcuts.bindings.previousSpace
        onActivated: root.perform("space.previous")
    }
    Shortcut {
        context: Qt.WindowShortcut
        sequences: root.shortcuts.bindings.newSpace
        onActivated: root.perform("space.new")
    }

    // window and app
    Shortcut {
        context: Qt.WindowShortcut
        sequences: root.shortcuts.bindings.closeWindow
        onActivated: root.perform("app.closeWindow")
    }
    Shortcut {
        context: Qt.WindowShortcut
        sequences: root.shortcuts.bindings.quit
        onActivated: root.perform("app.quit")
    }
}
