pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import illuminate.ui

SettingsPage {
    id: root
    heading: "Shortcuts"
    subtitle: "Click a shortcut to record a new combination. Backspace restores its default, Escape backs out, and a combination another command already uses will be refused."

    readonly property var groups: {
        const out = [];
        for (let i = 0; i < Shortcuts.commands.length; ++i) {
            const command = Shortcuts.commands[i];
            const last = out.length > 0 ? out[out.length - 1] : null;
            if (last !== null && last.title === command.category)
                last.commands.push(command);
            else
                out.push({
                    title: command.category,
                    commands: [command]
                });
        }
        return out;
    }

    PillButton {
        Layout.alignment: Qt.AlignRight
        visible: Shortcuts.hasCustomizations
        text: "Reset all"
        leftPadding: 14
        rightPadding: 14
        topPadding: 6
        bottomPadding: 6
        fillColor: "transparent"
        borderColor: Theme.border
        textColor: Theme.text
        hoverFillColor: Theme.surfaceHigh
        onClicked: Shortcuts.resetAll()
    }

    Repeater {
        model: root.groups

        delegate: ColumnLayout {
            id: groupBlock
            required property var modelData
            Layout.fillWidth: true
            spacing: 8

            SectionHeader {
                text: groupBlock.modelData.title
            }

            SettingsCard {
                Repeater {
                    model: groupBlock.modelData.commands

                    delegate: SettingItem {
                        id: cmdRow
                        required property var modelData
                        required property int index

                        topDivider: index > 0
                        title: modelData.label

                        ShortcutField {
                            commandId: cmdRow.modelData.id
                        }
                    }
                }
            }
        }
    }
}
