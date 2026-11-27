pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import illuminate.ui

SettingsPage {
    id: root
    heading: "General"

    SettingsCard {
        SettingItem {
            topDivider: false
            title: "Appearance"

            SettingCombo {
                id: appearanceCombo
                model: [
                    { name: "Match system", value: "system" },
                    { name: "Light", value: "light" },
                    { name: "Dark", value: "dark" }
                ]
                textRole: "name"
                valueRole: "value"
                value: Browser.themeMode
                onActivated: Browser.themeMode = appearanceCombo.currentValue
            }
        }

        SettingItem {
            title: "Density"

            SettingSegmented {
                id: densityControl
                objectName: "densityControl"
                model: [
                    { name: "Compact", value: "compact" },
                    { name: "Normal", value: "normal" },
                    { name: "Cosy", value: "cosy" }
                ]
                value: Prefs.uiDensity
                onActivated: value => Prefs.uiDensity = value
            }
        }

        SettingItem {
            title: "Browser language"

            SettingCombo {
                id: languageCombo
                model: [
                    { name: "System default", value: "" },
                    { name: "English (United States)", value: "en-US" },
                    { name: "English (United Kingdom)", value: "en-GB" },
                    { name: "Afrikaans", value: "af" },
                    { name: "Albanian", value: "sq" },
                    { name: "Amharic", value: "am" },
                    { name: "Arabic", value: "ar" },
                    { name: "Azerbaijani", value: "az" },
                    { name: "Basque", value: "eu" },
                    { name: "Belarusian", value: "be" },
                    { name: "Bengali", value: "bn" },
                    { name: "Bosnian", value: "bs" },
                    { name: "Bulgarian", value: "bg" },
                    { name: "Catalan", value: "ca" },
                    { name: "Chinese (Simplified)", value: "zh-CN" },
                    { name: "Chinese (Traditional)", value: "zh-TW" },
                    { name: "Croatian", value: "hr" },
                    { name: "Czech", value: "cs" },
                    { name: "Danish", value: "da" },
                    { name: "Dutch", value: "nl" },
                    { name: "Estonian", value: "et" },
                    { name: "Finnish", value: "fi" },
                    { name: "French", value: "fr" },
                    { name: "Galician", value: "gl" },
                    { name: "Georgian", value: "ka" },
                    { name: "German", value: "de" },
                    { name: "Greek", value: "el" },
                    { name: "Gujarati", value: "gu" },
                    { name: "Hebrew", value: "he" },
                    { name: "Hindi", value: "hi" },
                    { name: "Hungarian", value: "hu" },
                    { name: "Indonesian", value: "id" },
                    { name: "Irish", value: "ga" },
                    { name: "Italian", value: "it" },
                    { name: "Japanese", value: "ja" },
                    { name: "Kazakh", value: "kk" },
                    { name: "Korean", value: "ko" },
                    { name: "Latvian", value: "lv" },
                    { name: "Lithuanian", value: "lt" },
                    { name: "Macedonian", value: "mk" },
                    { name: "Malay", value: "ms" },
                    { name: "Malayalam", value: "ml" },
                    { name: "Marathi", value: "mr" },
                    { name: "Norwegian Bokmål", value: "nb" },
                    { name: "Persian", value: "fa" },
                    { name: "Polish", value: "pl" },
                    { name: "Portuguese (Brazil)", value: "pt-BR" },
                    { name: "Portuguese (Portugal)", value: "pt-PT" },
                    { name: "Romanian", value: "ro" },
                    { name: "Russian", value: "ru" },
                    { name: "Serbian", value: "sr" },
                    { name: "Slovak", value: "sk" },
                    { name: "Slovenian", value: "sl" },
                    { name: "Spanish (Latin America)", value: "es-419" },
                    { name: "Spanish (Spain)", value: "es" },
                    { name: "Swahili", value: "sw" },
                    { name: "Swedish", value: "sv" },
                    { name: "Tamil", value: "ta" },
                    { name: "Telugu", value: "te" },
                    { name: "Thai", value: "th" },
                    { name: "Turkish", value: "tr" },
                    { name: "Ukrainian", value: "uk" },
                    { name: "Urdu", value: "ur" },
                    { name: "Vietnamese", value: "vi" }
                ]
                textRole: "name"
                valueRole: "value"
                value: Prefs.browserLanguage
                onActivated: Prefs.browserLanguage = languageCombo.currentValue
            }
        }
    }
}
