import QtQuick
import illuminate.ui

Item {
    id: root
    property string text: ""
    property color fillColor: "transparent"
    property color hoverFillColor: fillColor
    property color textColor: Theme.text
    property color borderColor: "transparent"
    property int leftPadding: 20
    property int rightPadding: 20
    property int topPadding: 8
    property int bottomPadding: 8
    readonly property bool hovered: hoverHandler.hovered
    readonly property bool pressed: tapHandler.pressed

    signal clicked

    Accessible.role: Accessible.Button
    Accessible.name: root.text
    activeFocusOnTab: true
    Keys.onReturnPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()

    implicitWidth: pillText.implicitWidth + leftPadding + rightPadding
    implicitHeight: pillText.implicitHeight + topPadding + bottomPadding

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: (root.hovered && root.enabled) ? root.hoverFillColor : root.fillColor
        border.width: root.borderColor.a > 0 ? 1 : 0
        border.color: root.borderColor
        Behavior on color {
            ColorAnimation {
                duration: Theme.durationFast
            }
        }
    }

    Text {
        id: pillText
        anchors.centerIn: parent
        text: root.text
        font {
            pixelSize: Theme.fontSizeM
            weight: Font.Medium
            family: Theme.fontFamily
        }
        color: root.textColor
    }

    HoverHandler {
        id: hoverHandler
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        id: tapHandler
        onTapped: root.clicked()
    }
}
