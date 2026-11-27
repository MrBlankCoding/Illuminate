import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import illuminate.ui

pragma ComponentBehavior: Bound

Item {
    id: root
    required property var browserWindow
    property alias closeDialog: closeDialog
    property alias aboutDialog: aboutDialog

    Dialog {
        id: closeDialog
        title: "Close window?"
        popupType: Popup.Window
        x: Math.round((root.browserWindow.width - width) / 2)
        y: Math.round((root.browserWindow.height - height) / 2)
        modal: true
        width: Math.min(360, root.browserWindow.width - 80)
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            radius: 10
            color: Theme.surface
            border.color: Theme.border
            border.width: 1
        }

        header: Text {
            text: closeDialog.title
            color: Theme.text
            padding: 16
            bottomPadding: 0
            font {
                family: Theme.fontFamily
                pixelSize: Theme.fontSizeM
                weight: Font.Medium
            }
        }

        contentItem: Text {
            text: Browser.tabModel.count > 1
                ? "This window has " + Browser.tabModel.count + " tabs open."
                : "This window has a tab open."
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeM
            color: Theme.textMuted
            wrapMode: Text.WordWrap
        }

        footer: RowLayout {
            spacing: 8

            Item { Layout.fillWidth: true }

            PillButton {
                text: "Cancel"
                fillColor: "transparent"
                textColor: Theme.text
                Layout.topMargin: 12
                Layout.bottomMargin: 16
                onClicked: closeDialog.close()
            }

            PillButton {
                text: "Close window"
                fillColor: Theme.accent
                hoverFillColor: Qt.darker(Theme.accent, 1.1)
                textColor: Theme.onAccent
                Layout.topMargin: 12
                Layout.bottomMargin: 16
                Layout.rightMargin: 16
                onClicked: {
                    closeDialog.close()
                    root.browserWindow.closeAfterPageCheck()
                }
            }
        }
    }

    Dialog {
        id: aboutDialog
        title: "About " + Qt.application.name
        popupType: Popup.Window
        x: Math.round((root.browserWindow.width - width) / 2)
        y: Math.round((root.browserWindow.height - height) / 2)
        modal: true
        width: Math.min(360, root.browserWindow.width - 80)
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            radius: 10
            color: Theme.surface
            border.color: Theme.border
            border.width: 1
        }

        header: Text {
            text: aboutDialog.title
            color: Theme.text
            padding: 16
            bottomPadding: 0
            font {
                family: Theme.fontFamily
                pixelSize: Theme.fontSizeM
                weight: Font.Medium
            }
        }

        contentItem: ColumnLayout {
            spacing: 6

            Text {
                text: "Version " + (Qt.application.version || "unknown")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeM
                color: Theme.text
                Layout.fillWidth: true
            }

            Text {
                text: "Illuminate is your personal browser for a clearer, more focused web."
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeM
                color: Theme.textMuted
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }

        footer: RowLayout {
            spacing: 8

            Item { Layout.fillWidth: true }

            PillButton {
                text: "Close"
                fillColor: Theme.accent
                hoverFillColor: Qt.darker(Theme.accent, 1.1)
                textColor: Theme.onAccent
                Layout.topMargin: 12
                Layout.bottomMargin: 16
                Layout.rightMargin: 16
                onClicked: aboutDialog.close()
            }
        }
    }

}
