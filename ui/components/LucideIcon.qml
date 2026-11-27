import QtQuick
import QtQuick.Controls.impl
import illuminate.ui

// render icons as any color
// IconImage tints the pixels once when it loads; a MultiEffect per icon
// cost an offscreen layer and a shader pass for every one on screen
Item {
    id: root

    property string source: ""
    property color color: Theme.textMuted
    property int size: 16

    width: size
    height: size

    IconImage {
        anchors.fill: parent
        source: root.source
        sourceSize.width: root.size
        sourceSize.height: root.size
        fillMode: Image.PreserveAspectFit
        color: root.color

        Behavior on color {
            ColorAnimation {
                duration: Theme.durationFast
            }
        }
    }
}
