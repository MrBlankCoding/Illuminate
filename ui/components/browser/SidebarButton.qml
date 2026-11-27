import QtQuick
import illuminate.ui

Item {
    id: root

    property string icon: ""
    property int iconSize: 16
    property bool active: false          // e.g. its panel is open
    property alias hovered: hover.hovered
    signal clicked

    implicitWidth: Theme.iconButton
    implicitHeight: Theme.iconButton
    opacity: enabled ? 1 : 0.35
    scale: tap.pressed ? Theme.pressScale : 1

    Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
    Behavior on scale { NumberAnimation { duration: Theme.durationFast; easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusItem
        color: tap.pressed ? Theme.itemPressed
             : (hover.hovered || root.active) ? Theme.itemHover
             : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
    }

    LucideIcon {
        anchors.centerIn: parent
        source: root.icon
        size: root.iconSize
        color: hover.hovered || root.active ? Theme.text : Theme.textMuted
    }

    HoverHandler {
        id: hover
    }
    TapHandler {
        id: tap
        onTapped: root.clicked()
    }
}
