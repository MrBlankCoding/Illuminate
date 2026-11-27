import QtQuick
import illuminate.ui

SettingsPage {
    id: root
    heading: "Tabs"

    SectionHeader {
        text: "Spaces"
    }

    SettingsCard {
        SettingItem {
            topDivider: false
            title: "Keep spaces ready"
            description: "Switching to a space shows its last page instantly, as you left it. Keeps one page per space loaded in the background (up to three)."

            SettingSwitch {
                id: preloadSpacesSwitch
                objectName: "preloadSpacesSwitch"
                checked: Prefs.preloadSpaces
                onToggled: Prefs.preloadSpaces = !preloadSpacesSwitch.checked
            }
        }
    }

    SectionHeader {
        text: "Background tabs"
    }

    SettingsCard {
        SettingItem {
            topDivider: false
            title: "Memory Saver"
            description: "Discards inactive tabs to free memory. They reload when you return to them."

            SettingSwitch {
                id: memorySaverSwitch
                checked: Prefs.memorySaverEnabled
                onToggled: Prefs.memorySaverEnabled = !memorySaverSwitch.checked
            }
        }

        SettingItem {
            visible: Prefs.memorySaverEnabled
            title: "Memory savings"
            description: "Choose how aggressively Chromium deactivates background tabs."

            SettingCombo {
                id: memorySaverModeCombo
                implicitWidth: 160
                model: [
                    { name: "Moderate", value: 0 },
                    { name: "Balanced", value: 1 },
                    { name: "Maximum", value: 2 }
                ]
                textRole: "name"
                valueRole: "value"
                value: Prefs.memorySaverMode
                onActivated: Prefs.memorySaverMode = memorySaverModeCombo.currentValue
            }
        }
    }
    
    SectionHeader {
        text: "Closing"
    }

    SettingsCard {
        SettingItem {
            topDivider: false
            title: "Confirm before closing"
            description: "Asks before closing a window that has more than one tab open."

            SettingSwitch {
                id: confirmCloseSwitch
                checked: Prefs.confirmCloseMultipleTabs
                onToggled: Prefs.confirmCloseMultipleTabs = !confirmCloseSwitch.checked
            }
        }
    }
}
