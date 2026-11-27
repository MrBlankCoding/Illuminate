pragma ComponentBehavior: Bound
import QtQuick
import illuminate.ui

// A choice of a few options side by side, for a SettingItem. The highlight
// glides to the picked one. model: [{ name, value }]; the binding is up to
// the caller, as with SettingCombo.
FocusScope {
    id: root

    property var model: []
    property var value
    signal activated(var value)

    readonly property int currentIndex: {
        for (let i = 0; i < root.model.length; ++i)
            if (root.model[i].value === root.value)
                return i;
        return -1;
    }

    implicitWidth: segments.implicitWidth + 4
    implicitHeight: 30
    activeFocusOnTab: true

    function pick(index) {
        if (index < 0 || index >= root.model.length || index === root.currentIndex)
            return;
        root.activated(root.model[index].value);
    }

    Keys.onLeftPressed: root.pick(root.currentIndex - 1)
    Keys.onRightPressed: root.pick(root.currentIndex + 1)

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: Theme.surfaceHigh
        border.color: root.activeFocus ? Theme.accent : Theme.border
        border.width: 1
    }

    // the picked option's pill
    Rectangle {
        id: highlight
        objectName: "segmentHighlight"
        // itemAt() has no change signal: the count makes it look again once
        // the segments exist
        readonly property Item target: repeater.count > 0 && root.currentIndex >= 0
            ? repeater.itemAt(root.currentIndex) : null
        visible: target !== null
        x: target ? segments.x + target.x : 0
        y: 2
        width: target ? target.width : 0
        height: parent.height - 4
        radius: 6
        color: Theme.bg
        border.color: Theme.itemActiveBorder
        border.width: 1
        Behavior on x { NumberAnimation { duration: Theme.durationMid; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: Theme.durationMid; easing.type: Easing.OutCubic } }
    }

    Row {
        id: segments
        x: 2
        height: parent.height

        Repeater {
            id: repeater
            model: root.model

            delegate: Item {
                id: segment
                required property var modelData
                required property int index
                readonly property bool picked: segment.index === root.currentIndex

                objectName: "segment_" + segment.modelData.value
                width: label.implicitWidth + 26
                height: segments.height
                Accessible.role: Accessible.RadioButton
                Accessible.name: segment.modelData.name
                Accessible.checked: segment.picked

                Text {
                    id: label
                    anchors.centerIn: parent
                    text: segment.modelData.name
                    color: segment.picked || hover.hovered ? Theme.text : Theme.textMuted
                    font {
                        family: Theme.fontFamily
                        pixelSize: Theme.fontSizeM
                        weight: segment.picked ? Font.Medium : Font.Normal
                    }
                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                }

                HoverHandler {
                    id: hover
                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    onTapped: {
                        root.forceActiveFocus();
                        root.pick(segment.index);
                    }
                }
            }
        }
    }
}
