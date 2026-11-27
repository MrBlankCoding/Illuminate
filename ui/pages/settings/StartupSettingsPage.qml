import QtQuick
import QtQuick.Layouts
import illuminate.ui

SettingsPage {
    id: root
    heading: "Startup"
    subtitle: "Choose what you see when the app opens."

    SettingsCard {
        SettingItem {
            topDivider: false
            title: "Open"
            description: "What the first window shows when the app starts."

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

    Footnote {
        Layout.topMargin: 4
        text: "Saved tabs are restored whenever you open a space. This setting chooses the first page only when that space has no saved tabs."
    }
}
