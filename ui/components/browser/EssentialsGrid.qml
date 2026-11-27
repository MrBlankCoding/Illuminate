import QtQuick
import QtQuick.Controls
import illuminate.ui

pragma ComponentBehavior: Bound

Item {
    id: root

    readonly property int maxTiles: 9
    property int bookmarkRevision: 0
    property string activeUrl: ""

    readonly property int columns: 3
    readonly property int spacing: 5
    readonly property int tileHeight: Theme.essentialsTileHeight
    visible: Bookmarks.count > 0
    implicitHeight: {
        const rows = Math.ceil(Math.min(Bookmarks.count, root.maxTiles) / root.columns);
        return rows > 0 ? rows * root.tileHeight + (rows - 1) * root.spacing : 0;
    }

    readonly property real tileWidth: (width - (columns - 1) * spacing) / columns

    // switch to the tab already showing it, otherwise open it
    function open(url) {
        const tabs = Browser.tabModel;
        for (let i = 0; i < tabs.count; ++i) {
            if (tabs.itemAt(i).url.toString() === url) {
                Browser.activateTab(i);
                return;
            }
        }
        Browser.newTab(url);
    }

    Connections {
        target: Bookmarks
        function onDataChanged() { root.bookmarkRevision++ }
    }

    Repeater {
        model: Math.min(Bookmarks.count, root.maxTiles)

        delegate: Rectangle {
            id: tile
            required property int index
            property bool iconFailed: false
            readonly property string bookmarkTitle: {
                const revision = root.bookmarkRevision;
                return Bookmarks.itemAt(index).title;
            }
            readonly property string bookmarkUrl: {
                const revision = root.bookmarkRevision;
                return Bookmarks.itemAt(index).url;
            }
            readonly property string bookmarkIconUrl: {
                const revision = root.bookmarkRevision;
                return Bookmarks.itemAt(index).iconUrl;
            }

            readonly property bool isActive: root.activeUrl !== "" && root.activeUrl === tile.bookmarkUrl

            x: (index % root.columns) * (root.tileWidth + root.spacing)
            y: Math.floor(index / root.columns) * (root.tileHeight + root.spacing)
            width: root.tileWidth
            height: root.tileHeight
            radius: Theme.radiusTab
            color: isActive ? Theme.itemActive
                 : tap.pressed ? Theme.itemPressed
                 : hover.hovered ? Theme.itemHover
                 : Theme.fieldBg
            border.width: isActive ? 1 : 0
            border.color: Theme.itemActiveBorder
            scale: tap.pressed ? Theme.pressScale : 1

            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
            Behavior on scale { NumberAnimation { duration: Theme.durationFast; easing.type: Easing.OutCubic } }

            readonly property bool showBookmarkIcon: tile.bookmarkIconUrl !== ""
                && !tile.bookmarkIconUrl.startsWith("chrome:")
                && !tile.bookmarkIconUrl.startsWith("about:")
                && !tile.iconFailed

            Image {
                anchors.centerIn: parent
                width: 18
                height: 18
                sourceSize.width: 36
                sourceSize.height: 36
                source: tile.showBookmarkIcon ? tile.bookmarkIconUrl : ""
                visible: tile.showBookmarkIcon
                asynchronous: true
                fillMode: Image.PreserveAspectFit
                onStatusChanged: if (status === Image.Error) tile.iconFailed = true
            }

            LetterAvatar {
                anchors.centerIn: parent
                width: 18
                height: 18
                visible: !tile.showBookmarkIcon
                url: tile.bookmarkUrl
                title: tile.bookmarkTitle
            }

            HoverHandler {
                id: hover
                cursorShape: Qt.PointingHandCursor
            }
            TapHandler {
                id: tap
                onTapped: root.open(tile.bookmarkUrl)
            }
            TapHandler {
                acceptedButtons: Qt.MiddleButton
                onTapped: Browser.newTab(tile.bookmarkUrl, true)
            }
            TapHandler {
                acceptedButtons: Qt.RightButton
                onTapped: tileMenu.popup()
            }

            Menu {
                id: tileMenu
                popupType: Popup.Native

                MenuItem {
                    text: tile.bookmarkTitle
                    enabled: false
                }
                MenuSeparator {}
                MenuItem {
                    text: "Open in New Tab"
                    onTriggered: Browser.newTab(tile.bookmarkUrl)
                }
                MenuItem {
                    text: "Open in Background"
                    onTriggered: Browser.newTab(tile.bookmarkUrl, true)
                }
                MenuSeparator {}
                MenuItem {
                    text: "Remove"
                    onTriggered: Bookmarks.removeBookmark(tile.index)
                }
            }
        }
    }
}
