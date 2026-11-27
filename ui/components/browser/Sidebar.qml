import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import illuminate.ui

pragma ComponentBehavior: Bound

Item {
    id: root

    property string currentUrl: ""
    property string currentTitle: ""
    property string currentIconUrl: ""
    property bool isLoading: false
    property int loadProgress: 0
    property bool canGoBack: false
    property bool canGoForward: false

    property var zoomIndicator: null
    property var themePicker: null
    property var targetWindow: root.Window.window
    readonly property bool currentBookmarked: addressPill.isBookmarked

    signal openSettings
    signal commandBarRequested(string mode)   // "new" | "edit"
    signal toggleCollapsed

    function openSpaceEditor(space) {
        if (spaceEditorPopup)
            spaceEditorPopup.openFor(space)
    }

    function confirmDeleteSpace(space) {
        if (deleteSpacePopup && space)
            deleteSpacePopup.openFor(space)
    }

    readonly property bool isFullScreen: root.targetWindow ? root.targetWindow.visibility === Window.FullScreen : false
    readonly property bool customWindowControls: !Theme.isMac && !isFullScreen
    readonly property bool menuOpen: footer.popupsOpen || sideMenus.popupsOpen || renamingId !== ""

    implicitWidth: Prefs.sidebarWidth

    // which way the space contents slide in on the next switch: -1, 0 or 1
    property int spaceSlideDirection: 0

    function switchSpace(delta) {
        if (Spaces.spaces.length < 2)
            return;
        root.spaceSlideDirection = delta;
        Spaces.cycleSpace(delta);
        WindowHelper.haptic("level");
    }

    // two fingers sideways across the sidebar moves between spaces
    WheelHandler {
        id: spaceSwipe
        objectName: "spaceSwipe"
        target: null
        acceptedDevices: PointerDevice.TouchPad
        property real travelled: 0
        property bool spent: false

        onWheel: event => {
            const dx = event.pixelDelta.x !== 0 ? event.pixelDelta.x : event.angleDelta.x / 8;
            const dy = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y / 8;
            swipeQuiet.restart();
            // vertical scrolling is the tab list's
            if (Math.abs(dx) < Math.abs(dy) * 1.5 || spaceSwipe.spent)
                return;
            spaceSwipe.travelled += dx;
            if (Math.abs(spaceSwipe.travelled) < 110)
                return;
            // one switch per gesture, however far it goes (momentum included)
            spaceSwipe.spent = true;
            root.switchSpace(spaceSwipe.travelled < 0 ? 1 : -1);
        }
    }
    Timer {
        id: swipeQuiet
        interval: 320
        onTriggered: {
            spaceSwipe.travelled = 0;
            spaceSwipe.spent = false;
        }
    }

    Connections {
        target: Spaces
        function onActiveSpaceChanged() {
            spaceSlide.restart();
        }
    }

    // the incoming space's bookmarks and tabs slide in from the side it came from
    ParallelAnimation {
        id: spaceSlide
        onStarted: {
            spaceContents.x = root.spaceSlideDirection * 28;
            spaceContentsFade.opacity = 0;
        }
        onFinished: root.spaceSlideDirection = 0
        NumberAnimation { target: spaceContents; property: "x"; to: 0; duration: Theme.durationSlow; easing.type: Easing.OutCubic }
        NumberAnimation { target: spaceContentsFade; property: "opacity"; to: 1; duration: 220; easing.type: Easing.OutCubic }
    }
    // shared by the essentials and the tree; layouts own their positions
    Translate { id: spaceContents }
    QtObject {
        id: spaceContentsFade
        property real opacity: 1
    }

    // The CEF surface may extend beneath the QML dock/peek window. Keep the
    // sidebar opaque so its controls never appear to float over page content.
    Rectangle {
        anchors.fill: parent
        color: Theme.sidebarBg
        z: -1
    }

    function toggleBookmark() {
        if (root.currentUrl === "")
            return;
        Bookmarks.toggleBookmark(root.currentTitle, root.currentUrl, root.currentIconUrl);
        WindowHelper.haptic("snap");
    }



    // the folder whose title is being edited in place
    property string renamingId: ""

    function startRename(id) {
        if (!id)
            return;
        if (root.targetWindow && root.targetWindow.claimUiFocus)
            root.targetWindow.claimUiFocus("sidebarRename");
        root.renamingId = id;
        Qt.callLater(() => {
            const i = Browser.sidebar.rowOf(id);
            if (i >= 0) {
                treeView.tabList.positionViewAtIndex(i, ListView.Contain);
                // The delegate may be created only after scrolling lays out the
                // newly inserted row, so focus it after that layout turn.
                Qt.callLater(() => {
                    const row = treeView.tabList.itemAtIndex(i);
                    if (row && row.focusTitle)
                        row.focusTitle();
                });
            }
        });
    }

    function newFolder(parentId) {
        root.startRename(Browser.sidebar.createFolder(parentId || ""));
    }

    // menus act on a snapshot: the row can scroll away or be reused meanwhile
    function openTabMenu(m) {
        sideMenus.tabMenu.target = {
            nodeId: m.nodeId,
            title: m.title || "",
            url: m.url ? m.url.toString() : "",
            iconUrl: m.iconUrl || "",
            inFolder: m.inFolder === true,
            parentId: m.parentId || "",
            tabIndex: m.tabIndex
        };
        sideMenus.tabMenu.folders = Browser.sidebar.folders();
        sideMenus.tabMenu.popup();
    }

    function openFolderMenu(m) {
        sideMenus.folderMenu.target = {
            nodeId: m.nodeId,
            title: m.title || "",
            tabCount: m.tabCount || 0
        };
        sideMenus.folderMenu.popup();
    }

    ColumnLayout {
        anchors {
            fill: parent
            leftMargin: Theme.sidebarPadding
            // the card's own margin is the gap on the right
            rightMargin: 0
            bottomMargin: Theme.sidebarPadding
        }
        spacing: Theme.space2

        SidebarTitleStrip {
            sidebar: root
        }

        AddressPill {
            id: addressPill
            Layout.fillWidth: true
            currentUrl: root.currentUrl
            isLoading: root.isLoading
            loadProgress: root.loadProgress
            targetWindow: root.targetWindow
            onClicked: root.commandBarRequested(root.currentUrl === "" ? "new" : "edit")
            onToggleBookmark: root.toggleBookmark()
        }

        EssentialsGrid {
            Layout.fillWidth: true
            Layout.topMargin: Theme.space1
            activeUrl: root.currentUrl
            transform: spaceContents
            opacity: spaceContentsFade.opacity
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            Layout.leftMargin: Theme.space2
            Layout.rightMargin: Theme.space2
            Layout.topMargin: Theme.space1
            visible: Bookmarks.count > 0
            color: Theme.itemHover
        }

        SidebarTree {
            id: treeView
            sidebar: root
            transform: spaceContents
            opacity: spaceContentsFade.opacity
            onContextMenuRequested: sideMenus.sidebarMenu.popup()
        }

        Item {
            id: newTabButton
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.tabRowHeight
            Layout.leftMargin: Theme.space1
            Layout.rightMargin: Theme.space1

            readonly property bool hovered: hoverHandler.hovered

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusTab
                color: tapHandler.pressed ? Theme.itemPressed
                     : newTabButton.hovered ? Theme.itemHover : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.durationFast } }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.space3
                spacing: Theme.space2 + 2

                LucideIcon {
                    source: "qrc:/illuminate/ui/icons/plus.svg"
                    size: 16
                    color: newTabButton.hovered ? Theme.text : Theme.textMuted
                }

                Text {
                    Layout.fillWidth: true
                    text: qsTr("New Tab")
                    color: newTabButton.hovered ? Theme.text : Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeM
                    verticalAlignment: Text.AlignVCenter
                }
            }

            HoverHandler { id: hoverHandler }
            TapHandler {
                id: tapHandler
                onTapped: Browser.newTab()
            }
            Accessible.name: qsTr("New Tab")
        }

        SidebarFooter {
            id: footer
            sidebar: root
        }
    }

    // creating or editing a space; "editing" carries the space being changed
    Popup {
        id: spaceEditorPopup
        property var target: null
        readonly property bool creating: target === null

        parent: Overlay.overlay
        popupType: Popup.Window
        modal: true
        focus: true
        Component.onCompleted: PopupCloser.watch(spaceEditorPopup)
        padding: 18
        width: Math.min(320, parent ? parent.width - 32 : 320)
        x: parent ? Math.round((parent.width - width) / 2) : 0
        y: parent ? Math.round((parent.height - height) / 2) : 0
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onOpened: {
            if (root.targetWindow && root.targetWindow.claimUiFocus)
                root.targetWindow.claimUiFocus("spaceEditor");
            Qt.callLater(function() { spaceEditor.focusName() });
        }
        onClosed: {
            if (root.targetWindow && root.targetWindow.releaseUiFocus)
                root.targetWindow.releaseUiFocus("spaceEditor");
            if (root.targetWindow && root.targetWindow.raiseActiveWebView)
                Qt.callLater(() => root.targetWindow.raiseActiveWebView());
        }
        Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.35) }
        background: Rectangle {
            radius: 18
            color: Theme.surfaceHigh
            border.color: Theme.border
            border.width: 1
        }

        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 160 }
            NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: 200; easing.type: Easing.OutCubic }
        }

        contentItem: ColumnLayout {
            spacing: 12

            SpaceEditor {
                id: spaceEditor
                Layout.fillWidth: true
                onAccepted: spaceEditorPopup.commit()
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
                    onClicked: spaceEditorPopup.close()
                }
                PillButton {
                    text: spaceEditorPopup.creating ? qsTr("Create") : qsTr("Save")
                    textColor: Theme.onAccent
                    fillColor: Theme.accent
                    hoverFillColor: Qt.darker(Theme.accent, 1.1)
                    enabled: spaceEditor.trimmedName.length > 0
                    onClicked: spaceEditorPopup.commit()
                }
            }
        }

        function openFor(space) {
            target = space || null;
            spaceEditor.name = space ? space.name : "";
            spaceEditor.selectedColor = space ? space.color : Spaces.nextSpaceColor();
            open();
        }

        // an empty name would leave an unidentifiable space, so it is refused
        function commit() {
            const name = spaceEditor.trimmedName;
            if (name.length === 0) {
                spaceEditor.focusName();
                return;
            }
            if (spaceEditorPopup.creating) {
                const created = Spaces.createSpace(name, spaceEditor.selectedColor);
                if (created)
                    Spaces.activeSpace = created;
            } else if (spaceEditorPopup.target) {
                spaceEditorPopup.target.name = name;
                spaceEditorPopup.target.color = spaceEditor.selectedColor;
            }
            close();
        }
    }

    // a space takes its tabs with it when it goes
    Popup {
        id: deleteSpacePopup
        property var target: null

        function openFor(space) {
            target = space
            open()
        }

        parent: Overlay.overlay
        modal: true
        focus: true
        Component.onCompleted: PopupCloser.watch(deleteSpacePopup)
        padding: 24
        width: Math.min(340, parent ? parent.width - 32 : 340)
        x: parent ? Math.round((parent.width - width) / 2) : 0
        y: parent ? Math.round((parent.height - height) / 2) : 0
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.35) }
        background: Rectangle {
            radius: 18
            color: Theme.surfaceHigh
            border.color: Theme.border
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: 18

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Rectangle {
                    Layout.preferredWidth: 42
                    Layout.preferredHeight: 42
                    radius: 13
                    color: deleteSpacePopup.target ? deleteSpacePopup.target.color : Theme.danger
                    Text {
                        anchors.centerIn: parent
                        text: deleteSpacePopup.target ? deleteSpacePopup.target.initial : "?"
                        color: Theme.luma(parent.color) > 0.55 ? "#1e1e2e" : "white"
                        font { family: Theme.fontFamily; pixelSize: 17; weight: Font.DemiBold }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3
                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Delete space?")
                        color: Theme.text
                        font { family: Theme.fontFamily; pixelSize: Theme.fontSizeXL; weight: Font.DemiBold }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: deleteSpacePopup.target ? deleteSpacePopup.target.name : ""
                        textFormat: Text.PlainText
                        color: Theme.textMuted
                        elide: Text.ElideRight
                        font { family: Theme.fontFamily; pixelSize: Theme.fontSizeS }
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                text: qsTr("Its folders, tabs and bookmarks go with it. Logins, cookies and history stay.")
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
                    onClicked: deleteSpacePopup.close()
                }
                PillButton {
                    text: qsTr("Delete Space")
                    textColor: "white"
                    fillColor: Theme.danger
                    hoverFillColor: Qt.darker(Theme.danger, 1.1)
                    onClicked: {
                        Spaces.deleteSpace(deleteSpacePopup.target);
                        deleteSpacePopup.close();
                    }
                }
            }
        }
    }

    // the sidebar's context menus (right-click on empty space, row, and folder)
    SidebarMenus {
        id: sideMenus
        sidebar: root
    }

    Connections {
        target: sideMenus.tabMenu
        function onOpened() {
            if (root.targetWindow && root.targetWindow.raiseActiveWebView)
                Qt.callLater(() => root.targetWindow.raiseActiveWebView());
        }
        function onClosed() {
            if (root.targetWindow && root.targetWindow.raiseActiveWebView)
                Qt.callLater(() => root.targetWindow.raiseActiveWebView());
        }
    }

    // a two-finger swipe sideways anywhere in the sidebar moves one space over;
    // sits on top but lets every wheel event through to the list below
    Item {
        anchors.fill: parent
        z: 5

        WheelHandler {
            target: null
            blocking: false
            enabled: !root.menuOpen && Spaces.spaces.length > 1

            property real travelX: 0
            property real travelY: 0
            property bool spent: false

            onWheel: event => {
                // mouse wheels have no phase: only trackpad gestures count
                if (event.phase === Qt.NoScrollPhase || event.phase === Qt.ScrollMomentum)
                    return;
                if (event.phase === Qt.ScrollBegin) {
                    travelX = 0;
                    travelY = 0;
                    spent = false;
                    return;
                }
                if (spent)
                    return;

                // deltas follow the content; flip them back to the fingers
                const sign = event.inverted ? 1 : -1;
                travelX += sign * event.pixelDelta.x;
                travelY += Math.abs(event.pixelDelta.y);
                if (Math.abs(travelX) < 60 || Math.abs(travelX) < travelY * 2)
                    return;

                spent = true;
                const spaces = Spaces.spaces;
                const next = spaces.indexOf(Spaces.activeSpace) + (travelX < 0 ? 1 : -1);
                if (next >= 0 && next < spaces.length)
                    Spaces.activeSpace = spaces[next];
            }
        }
    }

}
