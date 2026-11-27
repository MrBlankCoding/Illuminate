import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import illuminate.ui

SettingsPage {
    id: root
    heading: "Privacy"

    Text {
        Layout.fillWidth: true
        text: "Each space has its own browsing history, cookies, sign-ins and site storage."
        color: Theme.textMuted
        wrapMode: Text.WordWrap
        font { family: Theme.fontFamily; pixelSize: Theme.fontSizeM }
    }

    property var savedPermissions: Permissions.rememberedDecisions()

    SettingsCard {
        SectionHeader {
            text: "Cookies"
        }

        SettingItem {
            topDivider: false
            title: "Allow third-party cookies"

            SettingSwitch {
                id: thirdPartyCookiesSwitch
                checked: Prefs.thirdPartyCookiesEnabled
                onToggled: Prefs.thirdPartyCookiesEnabled = !thirdPartyCookiesSwitch.checked
            }
        }
    }

    SectionHeader {
        Layout.topMargin: 12
        text: "Site permissions"
    }

    SettingsCard {
        Repeater {
            model: root.savedPermissions

            delegate: SettingItem {
                id: permissionRow
                required property var modelData
                required property int index
                topDivider: index > 0
                title: String(modelData.origin || modelData.host)
                description: String(modelData.label) + (modelData.allow ? " — Allowed" : " — Blocked")

                PillButton {
                    text: "Remove"
                    textColor: Theme.textMuted
                    fillColor: Theme.surfaceHigh
                    hoverFillColor: Theme.surface
                    onClicked: Permissions.forget(permissionRow.modelData.origin || ("https://" + permissionRow.modelData.host), permissionRow.modelData.type)
                }
            }
        }

        SettingItem {
            visible: root.savedPermissions.length === 0
            topDivider: false
            title: "No saved site choices"
            description: "When a site asks for a permission, choose whether Illuminate should remember your answer."
        }

        SettingItem {
            visible: root.savedPermissions.length > 0
            title: "Reset remembered choices"
            description: "Remove every saved allow and block choice. Sites will ask again next time they request access."

            PillButton {
                text: "Reset all"
                textColor: Theme.textMuted
                fillColor: Theme.surfaceHigh
                hoverFillColor: Theme.surface
                onClicked: resetPermissionsDialog.open()
            }
        }
    }

    SectionHeader {
        Layout.topMargin: 12
        text: "Browsing data"
    }

    SettingsCard {
        SettingItem {
            topDivider: false
            title: "Cookies and sign-in data"
            description: "Remove cookies for websites in this space. You may be signed out here; other spaces are unaffected."

            PillButton {
                text: Browser.webProfile && Browser.webProfile.privacyOperationBusy ? "Working…" : "Clear cookies"
                enabled: Browser.webProfile ? !Browser.webProfile.privacyOperationBusy : false
                textColor: Theme.textMuted
                fillColor: Theme.surfaceHigh
                hoverFillColor: Theme.surface
                onClicked: clearCookiesDialog.open()
            }
        }

        SettingItem {
            title: "Cached files"
            description: "Remove cached files for this space. Cookies, site data, permissions, and browsing history stay."

            PillButton {
                text: Browser.webProfile && Browser.webProfile.privacyOperationBusy ? "Working…" : "Clear cache"
                enabled: Browser.webProfile ? !Browser.webProfile.privacyOperationBusy : false
                textColor: Theme.textMuted
                fillColor: Theme.surfaceHigh
                hoverFillColor: Theme.surface
                onClicked: clearCacheDialog.open()
            }
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.topMargin: 4
        text: Browser.webProfile ? Browser.webProfile.privacyOperationStatus : ""
        visible: text.length > 0
        color: Theme.textMuted
        wrapMode: Text.WordWrap
        font { family: Theme.fontFamily; pixelSize: Theme.fontSizeS }
    }

    Connections {
        target: Permissions
        function onDecisionsChanged() {
            root.savedPermissions = Permissions.rememberedDecisions()
        }
    }

    Dialog {
        id: clearCookiesDialog
        title: "Clear cookies?"
        modal: true
        standardButtons: Dialog.Cancel | Dialog.Yes
        onAccepted: if (Browser.webProfile) Browser.webProfile.clearCookies()

        Label {
            text: "This removes sign-in cookies for websites in this space. You may need to sign in again here. Other spaces are unchanged."
            wrapMode: Text.WordWrap
            width: 340
        }
    }

    Dialog {
        id: clearCacheDialog
        title: "Clear cached files?"
        modal: true
        standardButtons: Dialog.Cancel | Dialog.Yes
        onAccepted: if (Browser.webProfile) Browser.webProfile.clearCache()

        Label {
            text: "This removes temporary cached page resources. Websites may load more slowly the next time you visit them."
            wrapMode: Text.WordWrap
            width: 340
        }
    }

    Dialog {
        id: resetPermissionsDialog
        title: "Reset site permissions?"
        modal: true
        standardButtons: Dialog.Cancel | Dialog.Yes
        onAccepted: Permissions.forgetAll()

        Label {
            text: "All saved allow and block choices will be removed. Sites will ask again when they request access."
            wrapMode: Text.WordWrap
            width: 340
        }
    }
}
