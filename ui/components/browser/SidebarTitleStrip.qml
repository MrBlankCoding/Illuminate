import QtQuick
import QtQuick.Layouts
import illuminate.ui

pragma ComponentBehavior: Bound

Item {
    id: root

    property var sidebar
    readonly property bool fullscreen: sidebar.isFullScreen

    Layout.fillWidth: true
    Layout.preferredHeight: Theme.titleBarHeight

    WindowDragRegion {
        anchors.fill: parent
        z: -1
        // it would move the overlay's own window
        enabled: !root.sidebar.overlay
    }

    RowLayout {
        anchors.fill: parent
        z: 1
        spacing: 2

        Item {
            visible: Theme.isMac && !root.sidebar.overlay
            Layout.preferredWidth: Theme.trafficLightW - Theme.sidebarPadding
        }

        WindowControls {
            visible: root.sidebar.customWindowControls
            targetWindow: root.sidebar.targetWindow
            buttonWidth: Theme.iconButton + 2
            buttonHeight: Theme.iconButton
            Layout.alignment: Qt.AlignVCenter
        }

        Item {
            Layout.fillWidth: true
        }

        SidebarButton {
            icon: "qrc:/illuminate/ui/icons/chevron-left.svg"
            iconSize: 18
            enabled: root.sidebar.canGoBack
            Accessible.name: qsTr("Back")
            onClicked: Browser.goBack()
        }
        SidebarButton {
            icon: "qrc:/illuminate/ui/icons/chevron-right.svg"
            iconSize: 18
            enabled: root.sidebar.canGoForward
            Accessible.name: qsTr("Forward")
            onClicked: Browser.goForward()
        }
        SidebarButton {
            icon: root.sidebar.isLoading ? "qrc:/illuminate/ui/icons/x.svg" : "qrc:/illuminate/ui/icons/rotate-cw.svg"
            iconSize: 15
            enabled: root.sidebar.currentUrl !== ""
            Accessible.name: root.sidebar.isLoading ? qsTr("Stop") : qsTr("Reload")
            onClicked: root.sidebar.isLoading ? Browser.stop() : Browser.reload()
        }
    }
}
