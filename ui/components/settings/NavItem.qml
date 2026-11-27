import QtQuick
import illuminate.ui

// one entry in the settings sidebar
Item {
    id: root
    property string label
    property bool selected: false

    signal activated

    implicitHeight: Theme.isMac ? 28 : 32

    Rectangle {
        anchors {
            fill: parent
            leftMargin: Theme.isMac ? 10 : 8
            rightMargin: Theme.isMac ? 10 : 8
        }
        radius: 6
        color: root.selected ? (Theme.isMac ? Theme.itemActive : Theme.accentDim)
                             : (hover.hovered ? Theme.surfaceHigh : "transparent")

        Behavior on color {
            ColorAnimation {
                duration: Theme.durationFast
            }
        }
    }

    Text {
        anchors {
            left: parent.left
            leftMargin: Theme.isMac ? 22 : 20
            verticalCenter: parent.verticalCenter
        }
        text: root.label
        color: root.selected ? (Theme.isMac ? Theme.accent : Theme.text) : Theme.textMuted
        font { family: Theme.fontFamily; pixelSize: Theme.fontSizeM; weight: root.selected ? Font.Medium : Font.Normal }
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
        onTapped: root.activated()
    }
}
