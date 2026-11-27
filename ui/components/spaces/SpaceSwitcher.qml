import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import illuminate.ui

pragma ComponentBehavior: Bound

Item {
    id: root

    property var sidebar
    readonly property var spaceManager: Spaces
    readonly property var spaces: root.spaceManager.spaces
    readonly property var activeSpace: root.spaceManager.activeSpace
    readonly property int dotTargetSize: spaces.length <= 4 ? 30
        : spaces.length <= 8 ? 26
        : spaces.length <= 14 ? 22 : 18
    readonly property int dotDiameter: spaces.length <= 4 ? 15
        : spaces.length <= 8 ? 12
        : spaces.length <= 14 ? 10 : 8

    implicitHeight: Theme.iconButton
    implicitWidth: 96
    Layout.fillWidth: true
    Layout.minimumWidth: 0
    visible: spaces.length > 0

    signal editRequested(var space)
    signal deleteRequested(var space)

    function select(space) {
        if (space && space !== root.activeSpace)
            root.spaceManager.activeSpace = space;
    }

    function revealActiveSpace() {
        let index = -1;
        for (let i = 0; i < root.spaces.length; ++i) {
            if (root.spaces[i] === root.activeSpace) {
                index = i;
                break;
            }
        }
        const dot = spaceDots.itemAt(index);
        if (!dot)
            return;
        const position = dot.mapToItem(dotFlick.contentItem, 0, 0).x;
        if (position < dotFlick.contentX)
            dotFlick.contentX = position;
        else if (position + dot.width > dotFlick.contentX + dotFlick.width)
            dotFlick.contentX = position + dot.width - dotFlick.width;
    }

    onActiveSpaceChanged: Qt.callLater(revealActiveSpace)

    RowLayout {
        anchors.fill: parent
        spacing: 2

        Flickable {
            id: dotFlick
            Layout.fillWidth: true
            Layout.minimumWidth: 16
            Layout.fillHeight: true
            clip: true
            contentWidth: Math.max(width, dotItems.implicitWidth)
            contentHeight: height
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.HorizontalFlick

            Row {
                id: dotRow
                width: dotFlick.contentWidth
                height: parent.height

                Row {
                    id: dotItems
                    x: Math.max(0, (dotRow.width - implicitWidth) / 2)
                    height: parent.height
                    spacing: 2

                    Repeater {
                        id: spaceDots
                        model: root.spaces
                        delegate: Item {
                            id: dot
                            required property var modelData
                            readonly property bool selected: dot.modelData === root.activeSpace
                            width: root.dotTargetSize
                            height: dotItems.height

                            Rectangle {
                                anchors.centerIn: parent
                                width: dot.selected ? root.dotDiameter : Math.max(6, root.dotDiameter - 3)
                                height: width
                                radius: width / 2
                                color: dot.modelData.color
                                border.width: dot.selected ? 1 : 0
                                border.color: Theme.text
                            }

                            HoverHandler { id: dotHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: root.select(dot.modelData) }
                            TapHandler {
                                acceptedButtons: Qt.RightButton
                                onTapped: {
                                    spaceMenu.target = dot.modelData;
                                    spaceMenu.popup();
                                }
                            }
                            ToolTip {
                                visible: dotHover.hovered
                                delay: 350
                                text: dot.modelData.name
                            }
                            Accessible.role: Accessible.Button
                            Accessible.name: qsTr("Space: %1").arg(dot.modelData.name)
                            Accessible.description: dot.selected ? qsTr("Current space") : qsTr("Switch to this space")
                            Accessible.selected: dot.selected
                        }
                    }
                }
            }
        }
    }

    Menu {
        id: spaceMenu
        popupType: Popup.Native
        Component.onCompleted: PopupCloser.watch(spaceMenu)
        property var target: null

        MenuItem {
            text: qsTr("Rename…")
            onTriggered: root.editRequested(spaceMenu.target)
        }

        Menu {
            id: colorMenu
            title: qsTr("Change Colour")
            Instantiator {
                model: Theme.avatarColors
                delegate: MenuItem {
                    required property string modelData
                    text: modelData
                    onTriggered: if (spaceMenu.target) spaceMenu.target.color = modelData
                }
                onObjectAdded: (index, object) => colorMenu.insertItem(index, object)
                onObjectRemoved: (index, object) => colorMenu.removeItem(object)
            }
        }

        MenuSeparator {}
        MenuItem {
            text: qsTr("Delete Space…")
            enabled: root.spaces.length > 1
            onTriggered: root.deleteRequested(spaceMenu.target)
        }
    }
}
