import QtQuick
import QtQuick.Layouts
import illuminate.ui

pragma ComponentBehavior: Bound

Item {
    id: root
    required property var tree
    anchors.fill: parent

    Rectangle {
        x: root.tree.dragSplitPosition.x
        y: root.tree.dragSplitPosition.y
        z: 21
        width: 190
        height: Theme.tabRowHeight
        radius: Theme.radiusTab
        visible: root.tree.dragSplitMemberId !== ""
        color: Theme.itemActive
        border.color: Theme.accent
        border.width: 1
        RowLayout {
            anchors {
                fill: parent
                leftMargin: Theme.space2
                rightMargin: Theme.space2
            }
            spacing: Theme.space2
            Item {
                Layout.preferredWidth: 18
                Layout.preferredHeight: 18
                readonly property bool hasValidIcon: root.tree.dragSplitMemberIcon !== ""
                    && !root.tree.dragSplitMemberIcon.startsWith("chrome:")
                    && !root.tree.dragSplitMemberIcon.startsWith("about:")
                Image {
                    id: splitPreviewIcon
                    property bool failed: false
                    anchors.fill: parent
                    visible: parent.hasValidIcon && !failed
                    source: visible ? root.tree.dragSplitMemberIcon : ""
                    sourceSize.width: 36
                    sourceSize.height: 36
                    asynchronous: true
                    onSourceChanged: failed = false
                    onStatusChanged: if (status === Image.Error) failed = true
                }
                LucideIcon {
                    anchors.centerIn: parent
                    visible: !parent.hasValidIcon || splitPreviewIcon.failed
                    source: "qrc:/illuminate/ui/icons/globe.svg"
                    size: 15
                    color: Theme.textMuted
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    Layout.fillWidth: true
                    text: root.tree.dragSplitMemberTitle
                    color: Theme.text
                    elide: Text.ElideRight
                    font { family: Theme.fontFamily; pixelSize: Theme.fontSizeS }
                }
                Text {
                    text: qsTr("Release outside to separate")
                    color: Theme.textMuted
                    font { family: Theme.fontFamily; pixelSize: Theme.fontSizeS }
                }
            }
        }
    }

    // follows the pointer while a row is dragged
    Rectangle {
        visible: root.tree.dragId !== ""
        x: Theme.space2
        y: Math.max(0, Math.min(root.tree.height - height, root.tree.dragY - height / 2))
        z: 20
        width: root.tree.width - Theme.space2 * 2
        height: Theme.tabRowHeight
        radius: Theme.radiusTab
        color: Theme.itemActive
        border.width: 1
        border.color: Theme.itemActiveBorder
        opacity: 0.92

        RowLayout {
            anchors {
                fill: parent
                leftMargin: Theme.space3 - 2
                rightMargin: Theme.space2
            }
            spacing: Theme.space2 + 2

            Item {
                Layout.preferredWidth: Theme.faviconSize
                Layout.preferredHeight: Theme.faviconSize
                readonly property bool hasValidIcon: root.tree.dragIconUrl !== ""
                    && !root.tree.dragIconUrl.startsWith("chrome:")
                    && !root.tree.dragIconUrl.startsWith("about:")

                Image {
                    id: dragPreviewIcon
                    property bool failed: false
                    anchors.fill: parent
                    visible: root.tree.dragKind === "tab" && parent.hasValidIcon && !failed
                    source: visible ? root.tree.dragIconUrl : ""
                    sourceSize.width: Theme.faviconSize * 2
                    sourceSize.height: Theme.faviconSize * 2
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    onSourceChanged: failed = false
                    onStatusChanged: if (status === Image.Error) failed = true
                }
                LucideIcon {
                    anchors.centerIn: parent
                    visible: root.tree.dragKind === "folder"
                             || (root.tree.dragKind === "tab" && (!parent.hasValidIcon || dragPreviewIcon.failed))
                    size: 16
                    source: root.tree.dragKind === "folder"
                            ? "qrc:/illuminate/ui/icons/folder.svg"
                            : "qrc:/illuminate/ui/icons/globe.svg"
                    color: Theme.text
                }
            }
            Text {
                Layout.fillWidth: true
                text: root.tree.dragTitle
                textFormat: Text.PlainText
                color: Theme.text
                elide: Text.ElideRight
                font { family: Theme.fontFamily; pixelSize: Theme.fontSizeM }
            }
        }
    }
}
