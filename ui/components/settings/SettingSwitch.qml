import QtQuick
import illuminate.ui

// on/off control for a SettingItem. Click toggles it; the binding is up to the caller.
Item {
    id: root
    property bool checked: false

    signal toggled

    implicitWidth: 40
    implicitHeight: 24
    width: implicitWidth
    height: implicitHeight

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.accent : Theme.surfaceHigh
        border.color: root.checked ? Theme.accent : Theme.border
        border.width: 1

        Behavior on color {
            ColorAnimation {
                duration: Theme.durationFast
            }
        }
    }

    Rectangle {
        x: root.checked ? root.width - width - 2 : 2
        y: 2
        width: 20
        height: 20
        radius: 10
        color: root.checked ? Theme.onAccent : (Theme.isDark ? "#f5f5fa" : "#ffffff")

        Behavior on x {
            NumberAnimation {
                duration: Theme.durationFast
                easing.type: Easing.OutCubic
            }
        }
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
        onTapped: root.toggled()
    }
}
