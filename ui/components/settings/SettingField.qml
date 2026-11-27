import QtQuick
import QtQuick.Controls.Basic
import illuminate.ui

// single-line text input for a SettingItem
TextField {
    id: root
    implicitWidth: 260
    implicitHeight: 30
    leftPadding: 10
    rightPadding: 10
    verticalAlignment: TextInput.AlignVCenter
    font { pixelSize: Theme.fontSizeM; family: Theme.fontFamily }
    color: Theme.text
    placeholderTextColor: Theme.textMuted
    selectionColor: Theme.accent
    selectedTextColor: Theme.onAccent
    selectByMouse: true

    background: Rectangle {
        radius: 6
        color: Theme.surfaceHigh
        border.color: root.activeFocus ? Theme.accent : (root.hovered ? Theme.textMuted : Theme.border)
        border.width: 1

        Behavior on border.color {
            ColorAnimation {
                duration: Theme.durationFast
            }
        }
    }
}
