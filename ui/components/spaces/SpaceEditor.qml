import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import illuminate.ui

pragma ComponentBehavior: Bound

ColumnLayout {
    id: root

    property alias name: nameField.text
    readonly property string trimmedName: nameField.text.trim()
    property string selectedColor: Theme.avatarColors[0]
    property string placeholderText: qsTr("Name your space")

    signal accepted

    function focusName() {
        nameField.forceActiveFocus();
        nameField.selectAll();
    }

    spacing: 0

    TextField {
        id: nameField
        Layout.fillWidth: true
        Layout.preferredHeight: 44
        leftPadding: 12
        rightPadding: 12
        placeholderText: root.placeholderText
        placeholderTextColor: Theme.textMuted
        font.pixelSize: Theme.fontSizeM
        font.family: Theme.fontFamily
        color: Theme.text
        selectByMouse: true
        background: Rectangle {
            radius: 9
            color: nameField.activeFocus ? Theme.surface : Theme.bg
            border.width: nameField.activeFocus ? 1.5 : 1
            border.color: nameField.activeFocus ? root.selectedColor : Theme.border
            Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }
        }
        onAccepted: root.accepted()
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 12
        spacing: 7

        Repeater {
            model: Theme.avatarColors
            delegate: Item {
                id: swatchTarget
                required property string modelData
                readonly property bool selected: root.selectedColor === modelData
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                Accessible.role: Accessible.RadioButton
                Accessible.name: qsTr("Space colour ") + modelData
                Accessible.checked: selected

                Rectangle {
                    anchors.centerIn: parent
                    width: 27
                    height: 27
                    radius: 9
                    color: swatchTarget.modelData
                    border.color: swatchTarget.selected ? Theme.text : "transparent"
                    border.width: swatchTarget.selected ? 2 : 0
                    scale: swatchHover.hovered ? 1.08 : 1
                    Behavior on scale { NumberAnimation { duration: Theme.durationFast } }
                    Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }
                    Text {
                        anchors.centerIn: parent
                        visible: swatchTarget.selected
                        text: "✓"
                        color: Theme.luma(parent.color) > 0.55 ? "#1e1e2e" : "white"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                }

                HoverHandler { id: swatchHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.selectedColor = swatchTarget.modelData }
                Keys.onSpacePressed: root.selectedColor = swatchTarget.modelData
            }
        }
    }
}
