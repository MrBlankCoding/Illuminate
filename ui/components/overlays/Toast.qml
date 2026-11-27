import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import illuminate.ui

pragma ComponentBehavior: Bound

// A brief confirmation that floats over the page ("Link copied"), then drifts
// away. Its own window, so it shows above the page's native view.
Popup {
    id: root

    property string text: ""
    property string icon: "qrc:/illuminate/ui/icons/check.svg"
    // how long it stays once shown
    property int duration: 1800

    function show(message, iconSource) {
        root.text = message;
        root.icon = iconSource || "qrc:/illuminate/ui/icons/check.svg";
        if (root.opened) {
            // already up: a little nudge rather than a second toast
            bump.restart();
        } else {
            // closed, or still fading out: (re)open it
            root.open();
        }
        hideTimer.restart();
    }

    popupType: Popup.Window
    modal: false
    focus: false
    closePolicy: Popup.NoAutoClose
    padding: 0
    implicitWidth: row.implicitWidth + 28
    implicitHeight: 34

    Timer {
        id: hideTimer
        interval: root.duration
        onTriggered: root.close()
    }

    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.motion(160); easing.type: Easing.OutCubic }
            NumberAnimation { target: content; property: "y"; from: 10; to: 0; duration: Theme.motion(320); easing.type: Easing.OutBack; easing.overshoot: 1.6 }
            NumberAnimation { target: content; property: "scale"; from: 0.92; to: 1; duration: Theme.motion(320); easing.type: Easing.OutBack }
        }
    }
    exit: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; to: 0; duration: Theme.motion(180); easing.type: Easing.InCubic }
            NumberAnimation { target: content; property: "y"; to: 6; duration: Theme.motion(180); easing.type: Easing.InCubic }
        }
    }

    background: Item {}

    contentItem: Item {
        Rectangle {
            id: content
            objectName: "toastBody"
            width: root.width
            height: root.height
            radius: height / 2
            color: Theme.surfaceHigh
            border.color: Theme.border
            border.width: 1

            SequentialAnimation {
                id: bump
                NumberAnimation { target: content; property: "scale"; to: 1.06; duration: Theme.motion(90); easing.type: Easing.OutCubic }
                NumberAnimation { target: content; property: "scale"; to: 1; duration: Theme.motion(220); easing.type: Easing.OutBack }
            }

            RowLayout {
                id: row
                anchors.centerIn: parent
                spacing: 7

                LucideIcon {
                    source: root.icon
                    size: 14
                    color: Theme.accent
                    Layout.alignment: Qt.AlignVCenter
                }
                Text {
                    objectName: "toastText"
                    text: root.text
                    textFormat: Text.PlainText
                    color: Theme.text
                    elide: Text.ElideMiddle
                    Layout.maximumWidth: 320
                    Layout.alignment: Qt.AlignVCenter
                    font {
                        family: Theme.fontFamily
                        pixelSize: Theme.fontSizeM
                        weight: Font.Medium
                    }
                }
            }
        }
    }
}
