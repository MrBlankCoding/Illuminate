import QtQuick
import QtQuick.Layouts
import illuminate.ui

// muted, wrapping explanation that trails a group of settings. Must sit in a layout.
Text {
    id: root
    Layout.fillWidth: true
    Layout.leftMargin: 4
    Layout.rightMargin: 4
    color: Theme.textMuted
    wrapMode: Text.WordWrap
    font { family: Theme.fontFamily; pixelSize: Theme.fontSizeS }
}
