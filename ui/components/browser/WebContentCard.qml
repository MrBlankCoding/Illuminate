import QtQuick
import QtQuick.Effects
import illuminate.ui

pragma ComponentBehavior: Bound

Item {
    id: root

    property real radius: Theme.radiusCard
    property bool roundContent: false
    property bool shadowEnabled: true

    default property alias content: contentArea.data

    // analytic shadow (no offscreen blur pass): soft and wide, low opacity
    RectangularShadow {
        anchors.fill: background
        visible: root.shadowEnabled
        radius: root.radius
        blur: 24
        offset.y: 2
        color: Theme.shadow
    }

    Rectangle {
        id: background
        anchors.fill: parent
        radius: root.radius
        color: Theme.cardBg
    }

    Item {
        id: contentArea
        anchors.fill: parent
        layer.enabled: root.roundContent && root.radius > 0
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: mask
            // a soft threshold antialiases the mask's edge
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }
    }

    Item {
        id: mask
        anchors.fill: parent
        visible: false
        // only rendered while it is in use
        layer.enabled: contentArea.layer.enabled
        layer.smooth: true

        Rectangle {
            anchors.fill: parent
            radius: root.radius
            color: "black"
        }
    }
}
