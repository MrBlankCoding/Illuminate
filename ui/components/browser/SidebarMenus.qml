import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import illuminate.ui

pragma ComponentBehavior: Bound

Item {
    id: root
    property var sidebar

    readonly property bool popupsOpen: sidebarContextMenu.visible || tabContextMenu.visible || folderContextMenu.visible || deleteFolderPopup.visible
    property alias sidebarMenu: sidebarContextMenu
    property alias tabMenu: tabContextMenu
    property alias folderMenu: folderContextMenu

    // right-click on empty sidebar space
    Menu {
        id: sidebarContextMenu
        popupType: Popup.Native
        Component.onCompleted: PopupCloser.watch(sidebarContextMenu)

        MenuItem {
            text: qsTr("New Tab")
            onTriggered: root.sidebar.commandBarRequested("new")
        }
        MenuItem {
            text: qsTr("New Folder")
            onTriggered: root.sidebar.newFolder()
        }

        MenuSeparator {}

        MenuItem {
            text: qsTr("New Space…")
            onTriggered: root.sidebar.openSpaceEditor(null)
        }
        MenuItem {
            text: qsTr("Rename Space…")
            onTriggered: root.sidebar.openSpaceEditor(Spaces.activeSpace)
        }

        MenuSeparator {}

        MenuItem {
            text: qsTr("Theme…")
            onTriggered: root.sidebar.themePicker && root.sidebar.themePicker.open()
        }
    }

    Menu {
        id: tabContextMenu
        popupType: Popup.Native
        Component.onCompleted: PopupCloser.watch(tabContextMenu)

        property var target: ({})
        property var folders: []
        readonly property bool isPage: (target.url || "") !== "" && target.url !== "newtab://newtab"
        readonly property bool bookmarked: Bookmarks.count >= 0 && isPage && Bookmarks.isBookmarked(target.url)

        MenuItem {
            text: qsTr("Copy Link")
            enabled: root.tabMenu.isPage
            onTriggered: Browser.sidebar.copyLink(root.tabMenu.target.nodeId)
        }
        MenuItem {
            text: root.tabMenu.bookmarked ? qsTr("Remove Bookmark") : qsTr("Bookmark")
            enabled: root.tabMenu.isPage
            onTriggered: Bookmarks.toggleBookmark(root.tabMenu.target.title, root.tabMenu.target.url, root.tabMenu.target.iconUrl)
        }
        MenuItem {
            text: qsTr("Duplicate Tab")
            enabled: root.tabMenu.isPage
            onTriggered: Browser.newTab(root.tabMenu.target.url)
        }

        MenuSeparator {}

        Menu {
            id: addToFolderMenu
            title: root.tabMenu.target.inFolder ? qsTr("Move to Folder") : qsTr("Add to Folder")

            MenuItem {
                text: qsTr("New Folder")
                onTriggered: root.sidebar.startRename(Browser.sidebar.moveToNewFolder(root.tabMenu.target.nodeId))
            }
            MenuSeparator {}

            Instantiator {
                model: root.tabMenu.folders
                delegate: MenuItem {
                    required property var modelData
                    text: "    ".repeat(modelData.depth) + (modelData.icon ? modelData.icon + "  " : "") + modelData.title
                    // already there
                    enabled: modelData.id !== root.tabMenu.target.parentId
                    onTriggered: Browser.sidebar.addToFolder(root.tabMenu.target.nodeId, modelData.id)
                }
                // after "New Folder" and the separator
                onObjectAdded: (index, object) => addToFolderMenu.insertItem(index + 2, object)
                onObjectRemoved: (index, object) => addToFolderMenu.removeItem(object)
            }
        }

        MenuItem {
            text: qsTr("Remove from Folder")
            visible: root.tabMenu.target.inFolder === true
            onTriggered: Browser.sidebar.removeFromFolder(root.tabMenu.target.nodeId)
        }

        MenuSeparator {}

        MenuItem {
            text: qsTr("Close Tab")
            onTriggered: Browser.closeTab(root.tabMenu.target.tabIndex)
        }
    }

    Menu {
        id: folderContextMenu
        popupType: Popup.Native
        Component.onCompleted: PopupCloser.watch(folderContextMenu)

        property var target: ({})

        MenuItem {
            text: qsTr("Rename")
            onTriggered: root.sidebar.startRename(root.folderMenu.target.nodeId)
        }

        Menu {
            id: iconMenu
            title: qsTr("Change Icon")

            MenuItem {
                text: qsTr("Folder")
                onTriggered: Browser.sidebar.setFolderIcon(root.folderMenu.target.nodeId, "")
            }
            MenuSeparator {}

            Instantiator {
                model: ["⭐", "💼", "🏠", "📚", "🎵", "🎮", "🛒", "💡", "🔧", "📰", "✈️", "🎨", "💻", "📌", "❤️", "🔥"]
                delegate: MenuItem {
                    required property string modelData
                    text: modelData
                    onTriggered: Browser.sidebar.setFolderIcon(root.folderMenu.target.nodeId, modelData)
                }
                onObjectAdded: (index, object) => iconMenu.insertItem(index + 2, object)
                onObjectRemoved: (index, object) => iconMenu.removeItem(object)
            }
        }

        MenuSeparator {}

        MenuItem {
            text: qsTr("New Tab in Folder")
            onTriggered: Browser.sidebar.newTabInFolder(root.folderMenu.target.nodeId)
        }
        MenuItem {
            text: qsTr("New Subfolder")
            onTriggered: root.sidebar.newFolder(root.folderMenu.target.nodeId)
        }

        MenuSeparator {}

        MenuItem {
            text: qsTr("Expand All")
            onTriggered: Browser.sidebar.setExpanded(root.folderMenu.target.nodeId, true, true)
        }
        MenuItem {
            text: qsTr("Collapse All")
            onTriggered: Browser.sidebar.setExpanded(root.folderMenu.target.nodeId, false, true)
        }
        MenuItem {
            text: qsTr("Close All Tabs")
            enabled: root.folderMenu.target.tabCount > 0
            onTriggered: Browser.sidebar.closeFolderTabs(root.folderMenu.target.nodeId)
        }

        MenuSeparator {}

        MenuItem {
            text: root.folderMenu.target.tabCount > 0 ? qsTr("Delete Folder…") : qsTr("Delete Folder")
            onTriggered: {
                if (root.folderMenu.target.tabCount > 0) {
                    deleteFolderPopup.target = root.folderMenu.target;
                    deleteFolderPopup.open();
                } else {
                    Browser.sidebar.deleteNode(root.folderMenu.target.nodeId);
                }
            }
        }
    }

    // a folder with tabs in it asks what happens to them
    Popup {
        id: deleteFolderPopup
        property var target: ({})

        parent: Overlay.overlay
        modal: true
        focus: true
        Component.onCompleted: PopupCloser.watch(deleteFolderPopup)
        padding: 20
        width: Math.min(300, parent ? parent.width - 32 : 300)
        x: parent ? Math.round((parent.width - width) / 2) : 0
        y: parent ? Math.round((parent.height - height) / 2) : 0
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.35) }
        background: Rectangle {
            radius: 16
            color: Theme.bg
            border.color: Theme.border
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: 16

            Text {
                Layout.fillWidth: true
                text: qsTr("Delete \"%1\"?").arg(deleteFolderPopup.target.title || "")
                textFormat: Text.PlainText
                color: Theme.text
                wrapMode: Text.WordWrap
                font { family: Theme.fontFamily; pixelSize: Theme.fontSizeM; weight: Font.Medium }
            }
            Text {
                Layout.fillWidth: true
                text: deleteFolderPopup.target.tabCount === 1
                    ? qsTr("It holds 1 tab. Keep it open, or close it too?")
                    : qsTr("It holds %1 tabs. Keep them open, or close them too?").arg(deleteFolderPopup.target.tabCount || 0)
                color: Theme.textMuted
                wrapMode: Text.WordWrap
                font { family: Theme.fontFamily; pixelSize: Theme.fontSizeS }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Item { Layout.fillWidth: true }

                PillButton {
                    text: qsTr("Cancel")
                    textColor: Theme.textMuted
                    fillColor: Theme.surfaceHigh
                    hoverFillColor: Theme.surface
                    onClicked: deleteFolderPopup.close()
                }
                PillButton {
                    text: qsTr("Keep Tabs")
                    textColor: Theme.text
                    fillColor: Theme.surfaceHigh
                    hoverFillColor: Theme.surface
                    onClicked: {
                        Browser.sidebar.deleteNode(deleteFolderPopup.target.nodeId, true);
                        deleteFolderPopup.close();
                    }
                }
                PillButton {
                    text: qsTr("Close Tabs")
                    textColor: "white"
                    fillColor: Theme.danger
                    hoverFillColor: Qt.darker(Theme.danger, 1.1)
                    onClicked: {
                        Browser.sidebar.deleteNode(deleteFolderPopup.target.nodeId, false);
                        deleteFolderPopup.close();
                    }
                }
            }
        }
    }
}
