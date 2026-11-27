pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import illuminate.ui

ComboBox {
    id: root
    implicitWidth: 220
    implicitHeight: 30
    font { pixelSize: Theme.fontSizeM; family: Theme.fontFamily }

    property var value
    onValueChanged: root.syncToValue()
    onCountChanged: root.syncToValue()
    // a new model's values aren't readable until its entries are in place
    onModelChanged: Qt.callLater(root.syncToValue)
    Component.onCompleted: root.syncToValue()

    function syncToValue() {
        if (root.count > 0)
            root.currentIndex = Math.max(0, root.indexOfValue(root.value));
    }

    background: Rectangle {
        radius: 6
        color: root.hovered || root.visualFocus ? Theme.surface : Theme.surfaceHigh
        border.color: root.visualFocus || root.popup.visible ? Theme.accent : Theme.border
        border.width: 1

        Behavior on color {
            ColorAnimation {
                duration: Theme.durationFast
            }
        }
    }

    contentItem: Text {
        leftPadding: 10
        rightPadding: 28
        text: root.displayText
        font: root.font
        color: Theme.text
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    indicator: Text {
        x: root.width - width - 10
        y: (root.height - height) / 2
        text: "⌄"
        color: Theme.textMuted
        font { pixelSize: Theme.fontSizeM; family: Theme.fontFamily }
    }

    delegate: ItemDelegate {
        id: entry
        required property var modelData
        required property int index

        width: root.width - 8
        height: 30
        leftPadding: 10
        rightPadding: 10
        highlighted: root.highlightedIndex === index

        contentItem: Text {
            text: typeof entry.modelData === "string" ? entry.modelData : entry.modelData[root.textRole]
            color: Theme.text
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            font { family: root.font.family; pixelSize: root.font.pixelSize; weight: root.currentIndex === entry.index ? Font.DemiBold : Font.Normal }
        }

        background: Rectangle {
            radius: 6
            color: entry.highlighted || entryHover.hovered ? Theme.accentDim : "transparent"
        }

        HoverHandler {
            id: entryHover
            cursorShape: Qt.PointingHandCursor
        }
    }

    popup: Popup {
        id: comboPopup
        y: root.height + 4
        width: root.width
        implicitHeight: Math.min(contentItem.implicitHeight + 8, 260)
        padding: 4
        Component.onCompleted: PopupCloser.watch(comboPopup)

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: root.popup.visible ? root.delegateModel : null
            currentIndex: count > 0 ? Math.min(Math.max(0, root.highlightedIndex), count - 1) : -1
            boundsBehavior: Flickable.StopAtBounds
            ScrollIndicator.vertical: ScrollIndicator {}
        }

        background: Rectangle {
            radius: 8
            color: Theme.surface
            border.color: Theme.border
            border.width: 1
        }
    }
}
