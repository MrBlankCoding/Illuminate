import QtQuick
import QtQuick.Layouts
import illuminate.ui

pragma ComponentBehavior: Bound

// a folder in the pinned area: click opens or closes it, double-click renames
Item {
    id: root

    property string title: ""
    property string icon: ""        // emoji; empty shows the folder glyph
    property bool expanded: true
    property bool editing: false
    property bool dropTarget: false // a drag is over the middle of the row
    property bool dragging: false

    signal toggled
    signal renameRequested
    signal renamed(string title)
    signal editingCanceled
    signal menuRequested

    readonly property bool hovered: hoverHandler.hovered

    function focusTitle() {
        if (!root.editing)
            return;
        titleInput.forceActiveFocus();
        titleInput.selectAll();
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusTab
        color: root.dropTarget ? Theme.itemPressed
             : tapHandler.pressed && !root.dragging ? Theme.itemPressed
             : root.hovered || root.dragging ? Theme.itemHover
             : "transparent"
        border.width: root.dropTarget ? 1 : 0
        border.color: Theme.accent
        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
    }

    RowLayout {
        spacing: Theme.space2 + 2
        anchors {
            fill: parent
            leftMargin: Theme.space3 - 2
            rightMargin: Theme.space1 + 2
        }

        Item {
            Layout.preferredWidth: Theme.faviconSize
            Layout.preferredHeight: Theme.faviconSize
            Layout.alignment: Qt.AlignVCenter

            // closed and open glyphs crossfade
            LucideIcon {
                anchors.centerIn: parent
                visible: root.icon === ""
                size: 16
                source: "qrc:/illuminate/ui/icons/folder.svg"
                color: root.hovered ? Theme.text : Theme.textMuted
                opacity: root.expanded ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: Theme.durationFolder; easing.type: Easing.OutCubic } }
            }
            LucideIcon {
                anchors.centerIn: parent
                visible: root.icon === ""
                size: 16
                source: "qrc:/illuminate/ui/icons/folder-open.svg"
                color: root.hovered ? Theme.text : Theme.textMuted
                opacity: root.expanded ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.durationFolder; easing.type: Easing.OutCubic } }
            }
            Text {
                anchors.centerIn: parent
                visible: root.icon !== ""
                text: root.icon
                textFormat: Text.PlainText
                font.pixelSize: 14
                // the emoji can't show open/closed, so it tilts open a little
                rotation: root.expanded ? 0 : -8
                Behavior on rotation { NumberAnimation { duration: Theme.durationFolder; easing.type: Easing.OutCubic } }
            }
        }

        Text {
            visible: !root.editing
            text: root.title
            textFormat: Text.PlainText
            color: Theme.text
            font {
                pixelSize: Theme.fontSizeM
                family: Theme.fontFamily
                weight: Font.Medium
            }
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
            Layout.fillWidth: true
        }

        Rectangle {
            visible: root.editing
            radius: Theme.radiusS
            color: Theme.fieldBg
            border.width: 1
            border.color: Theme.accent
            Layout.fillWidth: true
            Layout.preferredHeight: 24

            TextInput {
                id: titleInput
                objectName: "titleInput"
                property bool canceled: false
                anchors.fill: parent
                anchors {
                    leftMargin: Theme.space2
                    rightMargin: Theme.space2
                }
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.text
                selectionColor: Theme.accentDim
                font {
                    pixelSize: Theme.fontSizeM
                    family: Theme.fontFamily
                }
                clip: true

                // losing focus keeps what was typed; Esc is the way out
                function commit() {
                    if (!root.editing)
                        return;
                    if (canceled || text.trim() === "")
                        root.editingCanceled();
                    else
                        root.renamed(text.trim());
                }

                Keys.onReturnPressed: commit()
                Keys.onEnterPressed: commit()
                Keys.onEscapePressed: {
                    canceled = true;
                    commit();
                }
                onActiveFocusChanged: if (!activeFocus) commit()
            }
        }
    }

    onEditingChanged: {
        if (!editing)
            return;
        titleInput.canceled = false;
        titleInput.text = root.title;
        Qt.callLater(root.focusTitle);
    }
    Component.onCompleted: if (editing) editingChanged()

    HoverHandler {
        id: hoverHandler
    }

    TapHandler {
        id: tapHandler
        enabled: !root.editing
        onTapped: root.toggled()
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        enabled: !root.editing
        onTapped: root.menuRequested()
    }
}
