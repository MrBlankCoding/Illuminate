import QtQuick
import QtQuick.Layouts
import illuminate.ui

// one row in a SettingsCard: title and description on the left, the control
// passed as the default property on the right. Must sit in a layout.
Item {
    id: root
    property string title
    property string description
    property bool topDivider: true
    default property alias control: slot.data

    // the control passed in; it is sized by the row rather than by itself
    readonly property Item controlItem: slot.children.length > 0 ? slot.children[0] : null

    Layout.fillWidth: true
    implicitHeight: Math.max(52, rowLayout.implicitHeight + 24)

    Rectangle {
        visible: root.topDivider
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            leftMargin: 16
            rightMargin: 16
        }
        height: 1
        color: Theme.border
        opacity: 0.6
    }

    RowLayout {
        id: rowLayout
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: 16
            rightMargin: 16
        }
        spacing: 16

        ColumnLayout {
            Layout.fillWidth: true
            // takes whatever the control leaves, but never so little that the
            // title becomes unreadable; the control gives way first
            Layout.preferredWidth: 0
            Layout.minimumWidth: 160
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: root.title
                color: Theme.text
                elide: Text.ElideRight
                font { family: Theme.fontFamily; pixelSize: Theme.fontSizeM; weight: Font.Medium }
            }
            Text {
                Layout.fillWidth: true
                visible: text.length > 0
                text: root.description
                color: Theme.textMuted
                wrapMode: Text.WordWrap
                font { family: Theme.fontFamily; pixelSize: Theme.fontSizeS }
            }
        }

        Item {
            id: slot
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: root.controlItem ? root.controlItem.implicitWidth : 0
            // wide inputs and combos shrink in a narrow window; small controls
            // like a switch keep their size
            Layout.minimumWidth: Math.min(root.controlItem ? root.controlItem.implicitWidth : 0, 120)
            implicitHeight: root.controlItem ? root.controlItem.implicitHeight : 0
        }
    }
}
