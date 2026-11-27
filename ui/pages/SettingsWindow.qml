pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import illuminate.ui

ApplicationWindow {
    id: root
    width: Theme.isMac ? 820 : 760
    height: Theme.isMac ? 620 : 600
    minimumWidth: Theme.isMac ? 640 : 560
    minimumHeight: 420
    title: "Settings"
    color: Theme.bg

    readonly property bool frameless: !Theme.isMac
    flags: (frameless ? Qt.Window | Qt.FramelessWindowHint : Qt.Window) | Qt.Dialog

    Rectangle {
        id: header
        anchors { top: parent.top; left: parent.left; right: parent.right }
        // collapsed on macOS so everything below still sits at the top
        height: root.frameless ? Theme.titleBarHeight : 0
        visible: root.frameless
        color: Theme.surface

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Theme.border
        }

        WindowDragRegion {
            anchors.fill: parent
        }

        Text {
            anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
            text: "Settings"
            color: Theme.text
            font { family: Theme.fontFamily; pixelSize: Theme.fontSizeM; weight: Font.Medium }
        }

        WindowControls {
            id: controls
            anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
        }
    }

    // sidebar
    Rectangle {
        id: navRoot
        property int currentIndex: 0
        readonly property var sections: ["General", "Startup", "Search", "Privacy", "Tabs", "Shortcuts", "Statistics"]

        anchors { top: header.visible ? header.bottom : parent.top; left: parent.left; bottom: parent.bottom }
        width: Theme.isMac ? 190 : 168
        color: Theme.sidebarBg

        Rectangle {
            anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
            width: 1
            color: Theme.border
        }

        Column {
            anchors { top: parent.top; topMargin: Theme.isMac ? 18 : 12; left: parent.left; right: parent.right }
            spacing: Theme.isMac ? 4 : 2

            Repeater {
                model: navRoot.sections

                delegate: NavItem {
                    required property var modelData
                    required property int index

                    label: modelData
                    selected: navRoot.currentIndex === index
                    width: navRoot.width
                    onActivated: navRoot.currentIndex = index
                }
            }
        }
    }

    // content
    Flickable {
        id: flick
        anchors { top: header.visible ? header.bottom : parent.top; left: navRoot.right; right: parent.right; bottom: parent.bottom }
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        contentWidth: width
        contentHeight: pages.height + 64
        ScrollBar.vertical: ScrollBar {}

        Connections {
            target: navRoot
            function onCurrentIndexChanged() {
                flick.contentY = 0;
            }
        }

        StackLayout {
            id: pages
            y: Theme.isMac ? 36 : 32
            x: (flick.width - width) / 2
            width: Math.min(flick.width - (Theme.isMac ? 72 : 48), 640)
            height: pageList[navRoot.currentIndex].implicitHeight
            currentIndex: navRoot.currentIndex

            readonly property var pageList: [generalPage, startupPage, searchPage, privacyPage, tabsPage, shortcutsPage, statisticsPage]

            GeneralSettingsPage { id: generalPage }
            StartupSettingsPage { id: startupPage }
            SearchSettingsPage { id: searchPage }
            PrivacySettingsPage { id: privacyPage }
            TabsSettingsPage { id: tabsPage }
            ShortcutsSettingsPage { id: shortcutsPage }
            StatisticsSettingsPage { id: statisticsPage }
        }
    }

    ResizeGrips {
        anchors.fill: parent
        visible: root.frameless && root.visibility === Window.Windowed
        z: 1000
        onRequestSystemResize: edges => root.startSystemResize(edges)
    }

    Shortcut {
        sequences: Shortcuts.bindings.settings !== undefined ? Shortcuts.bindings.settings : ["Ctrl+,"]
        onActivated: root.close()
    }
}
