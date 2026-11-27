import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import illuminate.ui

pragma ComponentBehavior: Bound

Item {
    id: root
    required property var tabSlot
    anchors.fill: parent

    property var request: null
    readonly property bool showing: popup.visible

    readonly property string host: {
        const m = /^[a-z][a-z0-9+.-]*:\/\/([^\/?#]+)/i.exec(String(root.tabSlot.tabUrl || ""));
        return m ? m[1].replace(/^www\./, "") : "";
    }

    function show(request) {
        root.request = request;
        popup.open();
    }

    function answer(leave) {
        const request = root.request;
        root.request = null;
        popup.close();
        if (!request)
            return;
        if (leave)
            request.leave();
        else
            request.stay();
    }

    Connections {
        target: root.request
        // the page went away while asking
        function onFinished() {
            root.request = null;
            popup.close();
        }
    }

    Popup {
        id: popup
        objectName: "beforeUnloadPopup"
        popupType: Popup.Window
        modal: true
        focus: true
        padding: 20
        width: 340
        x: Math.round((root.tabSlot.width - width) / 2)
        y: Math.round((root.tabSlot.height - height) / 3)
        closePolicy: Popup.CloseOnEscape
        // keys go to the prompt, not the page behind it
        onOpened: if (root.tabSlot.browserWindow) root.tabSlot.browserWindow.claimUiFocus(popup)
        // Escape, or the popup going away any other way, keeps the page
        onClosed: {
            if (root.tabSlot.browserWindow)
                root.tabSlot.browserWindow.releaseUiFocus(popup)
            if (root.request)
                root.answer(false)
        }
        Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.35) }
        background: Rectangle {
            radius: 16
            color: Theme.bg
            border.color: Theme.border
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: 12

            Text {
                objectName: "beforeUnloadTitle"
                Layout.fillWidth: true
                text: root.request && root.request.isReload ? qsTr("Reload site?") : qsTr("Leave site?")
                color: Theme.text
                wrapMode: Text.WordWrap
                font {
                    family: Theme.fontFamily
                    pixelSize: Theme.fontSizeL
                    weight: Font.DemiBold
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.host !== ""
                    ? qsTr("Changes you made on %1 may not be saved.").arg(root.host)
                    : qsTr("Changes you made may not be saved.")
                textFormat: Text.PlainText
                color: Theme.textMuted
                wrapMode: Text.WordWrap
                font {
                    family: Theme.fontFamily
                    pixelSize: Theme.fontSizeM
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 8

                Item { Layout.fillWidth: true }

                PillButton {
                    objectName: "stayButton"
                    text: qsTr("Stay")
                    textColor: Theme.text
                    fillColor: Theme.surfaceHigh
                    hoverFillColor: Theme.surface
                    onClicked: root.answer(false)
                }
                PillButton {
                    objectName: "leaveButton"
                    text: root.request && root.request.isReload ? qsTr("Reload") : qsTr("Leave")
                    textColor: Theme.onAccent
                    fillColor: Theme.danger
                    hoverFillColor: Qt.darker(Theme.danger, 1.1)
                    onClicked: root.answer(true)
                }
            }
        }
    }
}
