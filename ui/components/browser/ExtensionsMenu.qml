import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import illuminate.ui

pragma ComponentBehavior: Bound

// The installed extensions, like Chrome's puzzle menu. Picking one with a
// popup asks for its action popup; the rest open their options or details.
Popup {
    id: root

    readonly property ExtensionRegistry registry: Browser.webProfile ? Browser.webProfile.extensions : null
    readonly property var extensions: registry ? registry.items : []
    readonly property int rowHeight: 40
    readonly property int maxRows: 8

    signal popupRequested(var extension)

    function activate(extension) {
        root.close();
        if (extension.popupUrl.length > 0)
            root.popupRequested(extension);
        else
            Browser.newTab(extension.optionsUrl.length > 0 ? extension.optionsUrl : extension.detailsUrl);
    }

    popupType: Popup.Window
    width: 500
    padding: 0
    topPadding: Theme.space1
    bottomPadding: Theme.space1
    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    Component.onCompleted: PopupCloser.watch(root)
    onAboutToShow: if (root.registry) root.registry.refresh()

    background: Rectangle {
        radius: Theme.radiusCard
        color: Theme.bg
        border.color: Theme.border
        border.width: 1
    }

    contentItem: ColumnLayout {
        spacing: 0

        Text {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            Layout.leftMargin: Theme.space3
            Layout.rightMargin: Theme.space3
            text: qsTr("Extensions")
            color: Theme.textMuted
            font {
                family: Theme.fontFamily
                pixelSize: Theme.fontSizeS
                weight: Font.Medium
            }
            verticalAlignment: Text.AlignVCenter
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, root.maxRows * root.rowHeight)
            visible: count > 0
            clip: contentHeight > height
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            model: root.extensions

            delegate: Item {
                required property var modelData
                id: row

                width: ListView.view.width
                height: root.rowHeight

                Rectangle {
                    anchors {
                        fill: parent
                        leftMargin: Theme.space1
                        rightMargin: Theme.space1
                    }
                    radius: Theme.radiusItem
                    color: rowHover.hovered ? Theme.itemHover : "transparent"
                }

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: Theme.space3
                        rightMargin: Theme.space2
                    }
                    spacing: Theme.space2

                    Item {
                        Layout.preferredWidth: Theme.faviconSize
                        Layout.preferredHeight: Theme.faviconSize

                        Image {
                            id: icon
                            anchors.fill: parent
                            source: row.modelData.iconUrl
                            sourceSize.width: 2 * Theme.faviconSize
                            sourceSize.height: 2 * Theme.faviconSize
                            asynchronous: true
                            fillMode: Image.PreserveAspectFit
                            visible: status === Image.Ready
                        }

                        LucideIcon {
                            anchors.centerIn: parent
                            source: "qrc:/illuminate/ui/icons/puzzle.svg"
                            size: 15
                            visible: !icon.visible
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: row.modelData.name
                        textFormat: Text.PlainText // page-controlled: never render it as markup
                        color: Theme.text
                        font {
                            family: Theme.fontFamily
                            pixelSize: Theme.fontSizeM
                        }
                        elide: Text.ElideRight
                    }
                }

                HoverHandler { id: rowHover }
                TapHandler { onTapped: root.activate(row.modelData) }

                ToolTip {
                    visible: rowHover.hovered && row.modelData.popupUrl.length === 0
                    delay: 600
                    text: row.modelData.optionsUrl.length > 0
                        ? qsTr("No popup. Opens this extension's options.")
                        : qsTr("No popup. Opens this extension's details.")
                }

                Accessible.role: Accessible.Button
                Accessible.name: row.modelData.name
                Accessible.description: row.modelData.description
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: Theme.space3
            visible: list.count === 0
            spacing: Theme.space1

            Text {
                Layout.fillWidth: true
                text: qsTr("No extensions yet")
                color: Theme.text
                font {
                    family: Theme.fontFamily
                    pixelSize: Theme.fontSizeM
                }
            }
            Text {
                Layout.fillWidth: true
                text: qsTr("Install them from the Chrome Web Store.")
                color: Theme.textMuted
                font {
                    family: Theme.fontFamily
                    pixelSize: Theme.fontSizeS
                }
                wrapMode: Text.WordWrap
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            Layout.topMargin: Theme.space1
            Layout.bottomMargin: Theme.space1
            color: Theme.border
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 32

            Rectangle {
                anchors {
                    fill: parent
                    leftMargin: Theme.space1
                    rightMargin: Theme.space1
                }
                radius: Theme.radiusItem
                color: manageHover.hovered ? Theme.itemHover : "transparent"
            }

            Text {
                anchors {
                    fill: parent
                    leftMargin: Theme.space3
                }
                text: qsTr("Manage extensions")
                color: Theme.text
                font {
                    family: Theme.fontFamily
                    pixelSize: Theme.fontSizeM
                }
                verticalAlignment: Text.AlignVCenter
            }

            HoverHandler { id: manageHover }
            TapHandler {
                onTapped: {
                    root.close();
                    Browser.newTab("chrome://extensions/");
                }
            }
            Accessible.role: Accessible.Link
            Accessible.name: qsTr("Manage extensions")
        }
    }
}
