import QtQuick
import illuminate.ui

SettingsPage {
    id: root
    heading: "Startup"

    SettingsCard {
        SettingItem {
            topDivider: false
            title: "Restore tabs"
            description: "Reopen the tabs each space had when you last quit. Tabs in sidebar folders always come back."

            SettingSwitch {
                id: restoreTabsSwitch
                objectName: "restoreTabsSwitch"
                checked: Prefs.restoreTabsOnStartup
                onToggled: Prefs.restoreTabsOnStartup = !restoreTabsSwitch.checked
            }
        }

        SettingItem {
            title: "Open"
            description: "What a space shows when it has no tabs to restore."

            SettingCombo {
                id: startupCombo
                model: [
                    {
                        name: "New tab page",
                        value: "newtab"
                    },
                    {
                        name: "Homepage",
                        value: "homepage"
                    }
                ]
                textRole: "name"
                valueRole: "value"
                value: Prefs.startupBehavior
                onActivated: Prefs.startupBehavior = startupCombo.currentValue
            }
        }

        SettingItem {
            visible: Prefs.startupBehavior === "homepage"
            title: "Homepage"
            description: "Loaded when Open is set to Homepage."

            SettingField {
                id: homepageField
                placeholderText: "https://example.com"
                text: Prefs.homepageUrl
                onEditingFinished: Prefs.homepageUrl = text

                Connections {
                    target: Prefs
                    function onHomepageUrlChanged() {
                        if (!homepageField.activeFocus)
                            homepageField.text = Prefs.homepageUrl;
                    }
                }
            }
        }
    }
}
