import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import illuminate.ui

pragma ComponentBehavior: Bound

Item {
    id: root
    required property var tabSlot

    property var pendingPermission: null
    property string pendingPermissionLabel: ""
    property int pendingBlockedResource: -1
    property var permissionQueue: []
    anchors.fill: parent

    function handlePermission(permission) {
        if (Permissions.resolve(permission))
            return
        if (root.pendingPermission || permissionPopup.visible) {
            root.permissionQueue.push(permission)
            return
        }
        root.showPermission(permission)
    }

    function showPermission(permission) {
        const type = permission.permissionType
        root.pendingPermission = permission
        root.pendingPermissionLabel = Permissions.labelForType(type)
        root.pendingBlockedResource = Permissions.blockedResourceForType(type)
        rememberChk.checked = false
        permissionPopup.open()
    }

    function showNextPermission() {
        if (root.pendingPermission || permissionPopup.visible)
            return
        while (root.permissionQueue.length > 0) {
            const p = root.permissionQueue.shift()
            if (!p || p.permissionType === undefined || Permissions.resolve(p))
                continue
            root.showPermission(p)
            return
        }
    }

    function applyPermission(allow) {
        const p = root.pendingPermission
        if (!p)
            return
        Permissions.respond(p, allow, rememberChk.checked)
        root.pendingPermission = null
        permissionPopup.close()
    }

    onPendingPermissionChanged: {
        if (!root.pendingPermission && permissionPopup.visible)
            permissionPopup.close()
    }

    Connections {
        target: Permissions
        enabled: root.pendingPermission !== null
        function onSystemAccessChanged() {
            if (root.pendingPermission) {
                root.pendingBlockedResource =
                    Permissions.blockedResourceForType(root.pendingPermission.permissionType)
            }
        }
    }

    Popup {
        id: permissionPopup
        popupType: Popup.Window
        modal: true
        focus: true
        padding: 20
        width: 320
        x: Math.round((root.tabSlot.width - width) / 2)
        y: Math.round((root.tabSlot.height - height) / 2)
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        // keys go to the prompt, not the page behind it
        onOpened: if (root.tabSlot.browserWindow) root.tabSlot.browserWindow.claimUiFocus(permissionPopup)
        onClosed: {
            if (root.tabSlot.browserWindow)
                root.tabSlot.browserWindow.releaseUiFocus(permissionPopup)
            const p = root.pendingPermission
            root.pendingPermission = null
            if (p)
                p.deny()
            Qt.callLater(root.showNextPermission)
        }
        Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.35) }
        background: Rectangle {
            radius: 16
            color: Theme.bg
            border.color: Theme.border
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: 16

            Text {
                Layout.fillWidth: true
                text: (root.pendingPermission ? root.pendingPermission.origin.host : "") + " " + root.pendingPermissionLabel + "?"
                textFormat: Text.PlainText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeM
                color: Theme.text
                wrapMode: Text.WordWrap
            }

            Text {
                Layout.fillWidth: true
                visible: root.pendingBlockedResource >= 0
                text: Permissions.labelForResource(root.pendingBlockedResource)
                      + " access is turned off for Illuminate in your system settings."
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeS
                color: Theme.danger
                wrapMode: Text.WordWrap
            }

            PillButton {
                visible: root.pendingBlockedResource >= 0
                text: "Open System Settings"
                textColor: Theme.text
                fillColor: Theme.surfaceHigh
                hoverFillColor: Theme.surface
                onClicked: Permissions.openSystemSettings(root.pendingBlockedResource)
            }

            CheckBox {
                id: rememberChk
                text: "Remember this choice"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeS
                palette.windowText: Theme.textMuted
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Item { Layout.fillWidth: true }

                PillButton {
                    text: "Allow"
                    enabled: root.pendingBlockedResource < 0
                    textColor: "white"
                    fillColor: Theme.accent
                    hoverFillColor: Qt.darker(Theme.accent, 1.1)
                    onClicked: root.applyPermission(true)
                }
                PillButton {
                    text: "Deny"
                    textColor: Theme.textMuted
                    fillColor: Theme.surfaceHigh
                    hoverFillColor: Theme.surface
                    onClicked: root.applyPermission(false)
                }
            }
        }
    }
}
