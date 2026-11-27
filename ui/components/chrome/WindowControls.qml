import QtQuick
import illuminate.ui

pragma ComponentBehavior: Bound

// minimise / maximise / close for frameless windows (Windows, Linux)
Row {
    id: root

    // the window to control; differs from root.Window inside the sidebar overlay
    property var targetWindow: root.Window.window
    readonly property bool isMaximized: targetWindow ? targetWindow.visibility === Window.Maximized : false
    property int buttonHeight: Theme.titleBarHeight
    property int buttonWidth: Theme.sysControlW

    component ControlButton: Item {
        property string buttonAccessibleName: ""
        property url iconSource
        property int iconSize: 14
        property color hoverColor: Theme.surfaceHigh
        property color hoverIconColor: Theme.text
        signal clicked
        id: button

        Accessible.role: Accessible.Button
        Accessible.name: buttonAccessibleName
        activeFocusOnTab: true
        Keys.onReturnPressed: button.clicked()
        Keys.onSpacePressed: button.clicked()
        width: root.buttonWidth
        height: root.buttonHeight

        Item {
            anchors.fill: parent
            Rectangle {
                anchors.fill: parent
                color: hover.hovered ? button.hoverColor : "transparent"
                visible: hover.hovered
                Behavior on color {
                    ColorAnimation { duration: Theme.durationFast }
                }
            }
        }

        LucideIcon {
            anchors.centerIn: parent
            source: button.iconSource
            size: button.iconSize
            color: hover.hovered ? button.hoverIconColor : Theme.textMuted
        }

        HoverHandler {
            id: hover
        }
        TapHandler {
            onTapped: button.clicked()
        }
    }

    ControlButton {
        iconSource: "qrc:/illuminate/ui/icons/minus.svg"
        buttonAccessibleName: qsTr("Minimize window")
        onClicked: root.targetWindow.showMinimized()
    }

    ControlButton {
        // overlapping squares = "restore down" while maximised
        iconSource: root.isMaximized ? "qrc:/illuminate/ui/icons/copy.svg" : "qrc:/illuminate/ui/icons/square.svg"
        buttonAccessibleName: root.isMaximized ? qsTr("Restore window") : qsTr("Maximize window")
        iconSize: root.isMaximized ? 13 : 12
        onClicked: root.isMaximized ? root.targetWindow.showNormal() : root.targetWindow.showMaximized()
    }

    ControlButton {
        iconSource: "qrc:/illuminate/ui/icons/x.svg"
        buttonAccessibleName: qsTr("Close window")
        iconSize: 15
        hoverColor: "#e81123"
        hoverIconColor: "white"
        onClicked: root.targetWindow.close()
    }
}
