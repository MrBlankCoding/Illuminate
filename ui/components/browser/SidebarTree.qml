import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import illuminate.ui

pragma ComponentBehavior: Bound

Item {
    id: root
    property var sidebar
    property alias tabList: rowsView
    signal contextMenuRequested

    Layout.fillWidth: true
    Layout.fillHeight: true

    property string dragId: ""
    property string dragTitle: ""
    property string dragIconUrl: ""
    property string dragKind: ""
    property string dragSplitMemberId: ""
    property string dragSplitMemberTitle: ""
    property string dragSplitMemberIcon: ""
    property point dragSplitPosition: Qt.point(0, 0)
    property real dragY: 0
    property string dropTargetId: ""
    // off while a space switch replaces every row
    property bool animateRows: true

    Connections {
        target: Browser
        function onSpaceAboutToChange() {
            root.animateRows = false;
        }
        function onSpaceChanged() {
            // once the new space's rows are all in
            Qt.callLater(() => root.animateRows = true);
        }
    }
    property int dropPosition: -1
    property real indicatorX: 0
    property real indicatorY: 0

    function beginDrag(row) {
        root.dragId = row.nodeId;
        root.dragKind = row.kind;
        root.dragTitle = row.model.title || "";
        root.dragIconUrl = row.kind === "tab" ? (row.model.iconUrl || "") : "";
    }

    function endDrag() {
        if (root.dragId !== "" && root.dropTargetId !== "" && root.dropPosition >= 0) {
            Browser.sidebar.drop(root.dragId, root.dropTargetId, root.dropPosition);
            WindowHelper.haptic("snap");
        }
        root.dragId = "";
        root.clearTarget();
        scrollTimer.direction = 0;
    }

    function clearTarget() {
        root.dropTargetId = "";
        root.dropPosition = -1;
    }

    function isBlankPlaceholder(url) {
        return !url || url.toString() === "" || url.toString() === "newtab://newtab";
    }

    function dragMove(scenePos) {
        const p = root.mapFromItem(null, scenePos.x, scenePos.y);
        root.dragY = p.y;
        const edge = Theme.tabRowHeight;
        scrollTimer.direction = p.y < edge ? -1 : p.y > root.height - edge ? 1 : 0;
        root.updateTarget();
    }

    // itemAt() returns QQuickItem, while row delegates provide these fields.
    // qmllint disable missing-property
    function updateTarget() {
        const cy = root.dragY + rowsView.contentY;
        let item = rowsView.itemAt(rowsView.width / 2, cy);
        if (!item)
            item = rowsView.itemAt(rowsView.width / 2, cy - rowsView.spacing);
        if (!item && rowsView.count > 0) {
            const last = rowsView.itemAtIndex(rowsView.count - 1);
            if (last && cy > last.y + last.height)
                item = last;
        }
        if (!item || !item["nodeId"]) {
            root.clearTarget();
            return;
        }

        const nodeId = item["nodeId"];
        const kind = item["kind"];
        const expanded = item["expanded"];
        const indent = item["indent"];
        const frac = Math.max(0, Math.min(1, (cy - item.y) / item.height));
        let pos;
        if (kind === "folder")
            pos = frac < 0.25 ? SidebarModel.Before
                : frac > 0.75 && !expanded ? SidebarModel.After
                : SidebarModel.Into;
        else if (root.dragKind === "tab" && kind === "tab" && frac >= 0.25 && frac <= 0.75)
            pos = SidebarModel.Into;
        else
            pos = frac < 0.5 ? SidebarModel.Before : SidebarModel.After;

        if (!Browser.sidebar.canDrop(root.dragId, nodeId, pos)) {
            root.clearTarget();
            return;
        }
        if (nodeId !== root.dropTargetId || pos !== root.dropPosition) {
            // a tick for each place it could land; a firmer one over a folder or split
            if (root.dragId !== "")
                WindowHelper.haptic(pos === SidebarModel.Into ? "snap" : "tick");
            root.dropTargetId = nodeId;
            root.dropPosition = pos;
            if (pos === SidebarModel.Into && kind === "folder" && !expanded)
                expandTimer.restart();
            else
                expandTimer.stop();
        }
        const gap = rowsView.spacing / 2;
        root.indicatorX = indent;
        root.indicatorY = pos === SidebarModel.Before ? item.y - gap : item.y + item.height + gap;
    }
    // qmllint enable missing-property

    Timer {
        id: expandTimer
        interval: Theme.folderHoverExpandMs
        onTriggered: {
            if (root.dropPosition === SidebarModel.Into) {
                Browser.sidebar.setExpanded(root.dropTargetId, true);
                WindowHelper.haptic("level");
            }
        }
    }

    // keep scrolling while a drag hangs at the top or bottom edge
    Timer {
        id: scrollTimer
        property int direction: 0
        repeat: true
        interval: 16
        running: direction !== 0 && root.dragId !== ""
        onTriggered: {
            const max = Math.max(0, rowsView.contentHeight - rowsView.height);
            rowsView.contentY = Math.max(0, Math.min(max, rowsView.contentY + direction * 6));
            root.updateTarget();
        }
    }

    ListView {
        id: rowsView
        anchors.fill: parent
        clip: true
        spacing: Theme.sidebarRowSpacing
        reuseItems: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: root.dragId === "" && root.dragSplitMemberId === ""
        model: Browser.sidebar

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        function revealActive() {
            const i = Browser.sidebar.rowOf(Browser.tabModel.tabAt(Browser.tabModel.activeIndex)?.id ?? "");
            if (i >= 0 && i < rowsView.count)
                rowsView.positionViewAtIndex(i, ListView.Contain);
        }
        Connections {
            target: Browser.tabModel
            function onActiveIndexChanged() { Qt.callLater(rowsView.revealActive) }
        }

        // Rows animate in, out and around, except while a space switch
        // swaps every row at once: the sidebar slides the new space in, and
        // dozens of overlapping row transitions on recycled delegates could
        // leave the old space's rows (a folder) showing. Transitions animate
        // the rows' own "appear"/"appearScale", never opacity or scale,
        // which carry bindings of their own.
        add: root.animateRows ? addTransition : null
        remove: root.animateRows ? removeTransition : null
        displaced: root.animateRows ? displacedTransition : null
        move: root.animateRows ? moveTransition : null

        Transition {
            id: addTransition
            NumberAnimation { property: "appear"; from: 0; to: 1; duration: Theme.durationFolder; easing.type: Easing.OutCubic }
            NumberAnimation { property: "appearScale"; from: 0.96; to: 1; duration: Theme.durationFolder; easing.type: Easing.OutCubic }
        }
        // a closed tab fades and shrinks away while the rest close the gap
        Transition {
            id: removeTransition
            NumberAnimation { property: "appear"; to: 0; duration: Theme.durationFolder; easing.type: Easing.OutCubic }
            NumberAnimation { property: "appearScale"; to: 0.94; duration: Theme.durationFolder; easing.type: Easing.OutCubic }
        }
        Transition {
            id: displacedTransition
            NumberAnimation { properties: "y"; duration: Theme.durationFolder; easing.type: Easing.OutCubic }
            // a row caught mid-transition never stays half-faded
            NumberAnimation { property: "appear"; to: 1; duration: Theme.durationFolder }
            NumberAnimation { property: "appearScale"; to: 1; duration: Theme.durationFolder }
        }
        Transition {
            id: moveTransition
            NumberAnimation { properties: "y"; duration: Theme.durationMid; easing.type: Easing.InOutQuad }
        }

        delegate: Item {
            id: row
            required property var model
            required property int index

            readonly property string nodeId: model.nodeId ?? ""
            readonly property string kind: model.kind ?? ""
            readonly property int depth: model.depth ?? 0
            readonly property bool expanded: model.expanded === true
            readonly property real indent: Math.min(depth, Theme.sidebarMaxIndent) * Theme.sidebarIndent

            // what the add/remove transitions animate
            property real appear: 1
            property real appearScale: 1
            // a recycled row starts whole, whatever its last one was doing
            ListView.onReused: {
                row.appear = 1;
                row.appearScale = 1;
            }
            ListView.onPooled: {
                row.appear = 1;
                row.appearScale = 1;
            }

            width: rowsView.width
            height: kind === "header"
                ? (Browser.sidebar.folderCount > 0 ? Theme.space2 + 1 : 0)
                : Theme.tabRowHeight
            opacity: row.appear * (root.dragId !== "" && root.dragId === nodeId ? 0.4 : 1)
            scale: row.appearScale
            z: dragHandler.active ? 2 : 1

            // a guide line down from each enclosing folder
            Repeater {
                model: Math.min(row.depth, Theme.sidebarMaxIndent)
                Rectangle {
                    required property int index
                    x: index * Theme.sidebarIndent + Theme.space3 - 2 + Theme.faviconSize / 2
                    y: -rowsView.spacing / 2
                    width: 1
                    height: row.height + rowsView.spacing
                    color: Theme.itemPressed
                }
            }

            Loader {
                x: row.indent
                width: row.width - row.indent
                height: row.height
                sourceComponent: row.kind === "folder" ? folderComponent
                               : row.kind === "split" ? splitComponent
                               : row.kind === "tab" ? tabComponent
                               : row.kind === "header" ? headerComponent
                               : null
            }

            Rectangle {
                anchors.fill: parent
                z: 4
                visible: row.kind === "tab" && root.dragKind === "tab"
                    && root.dropTargetId === row.nodeId && root.dropPosition === SidebarModel.Into
                radius: Theme.radiusTab
                color: Qt.alpha(Theme.accent, 0.17)
                border.color: Theme.accent
                border.width: 1
                RowLayout {
                    anchors.centerIn: parent
                    spacing: 7
                    Rectangle {
                        Layout.preferredWidth: 27
                        Layout.preferredHeight: 18
                        radius: 4
                        color: "transparent"
                        border.color: Theme.accent
                        border.width: 1
                        Row {
                            anchors.fill: parent
                            anchors.margins: 2
                            spacing: 2
                            Rectangle { width: (parent.width - parent.spacing) / 2; height: parent.height; radius: 2; color: Theme.accent }
                            Rectangle { width: (parent.width - parent.spacing) / 2; height: parent.height; radius: 2; color: Theme.accent }
                        }
                    }
                    Text {
                        text: qsTr("Release to split")
                        color: Theme.text
                        font {
                            family: Theme.fontFamily
                            pixelSize: Theme.fontSizeS
                            weight: Font.Medium
                        }
                    }
                }
            }

            Component {
                id: tabComponent
                TabItem {
                    model: row.model
                    index: row.index
                    isActive: row.model.active === true
                    dragging: root.dragId === row.nodeId
                    onActivated: {
                        if (!root.isBlankPlaceholder(row.model.url))
                            Browser.activateTab(row.model.tabIndex);
                    }
                    onCloseClicked: {
                        WindowHelper.haptic("snap");
                        Browser.closeTab(row.model.tabIndex);
                    }
                    onMuteToggled: {
                        Browser.toggleTabMuted(row.nodeId);
                        WindowHelper.haptic("tick");
                    }
                    onContextMenuRequested: root.sidebar.openTabMenu(row.model)
                }
            }

            Component {
                id: folderComponent
                FolderRow {
                    title: row.model.title ?? ""
                    icon: row.model.icon ?? ""
                    expanded: row.expanded
                    editing: root.sidebar.renamingId !== "" && root.sidebar.renamingId === row.nodeId
                    dragging: root.dragId === row.nodeId
                    dropTarget: root.dropTargetId === row.nodeId && root.dropPosition === SidebarModel.Into
                    onToggled: {
                        Browser.sidebar.toggleFolder(row.nodeId);
                        WindowHelper.haptic("tick");
                    }
                    onRenameRequested: root.sidebar.startRename(row.nodeId)
                    onRenamed: title => {
                        Browser.sidebar.renameFolder(row.nodeId, title);
                        root.sidebar.renamingId = "";
                        if (root.sidebar.targetWindow && root.sidebar.targetWindow.releaseUiFocus)
                            root.sidebar.targetWindow.releaseUiFocus("sidebarRename");
                    }
                    onEditingCanceled: {
                        root.sidebar.renamingId = "";
                        if (root.sidebar.targetWindow && root.sidebar.targetWindow.releaseUiFocus)
                            root.sidebar.targetWindow.releaseUiFocus("sidebarRename");
                    }
                    onMenuRequested: root.sidebar.openFolderMenu(row.model)
                }
            }

            Component {
                id: splitComponent
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusTab
                    color: row.model.active ? Theme.itemActive : Theme.itemHover
                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: Theme.space3
                            rightMargin: Theme.space2
                        }
                        spacing: Theme.space1
                        Repeater {
                            model: row.model.splitMembers || []
                            delegate: Item {
                                id: splitMember
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.minimumWidth: 0
                                property bool faviconFailed: false
                                readonly property string memberIconUrl: modelData.iconUrl || ""
                                onMemberIconUrlChanged: faviconFailed = false

                                readonly property bool memberActive: modelData.active === true
                                readonly property bool memberHovered: memberHover.hovered
                                readonly property bool memberDragging: root.dragSplitMemberId === modelData.id

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Theme.radiusS
                                    color: parent.memberDragging ? Qt.alpha(Theme.accent, 0.28)
                                         : parent.memberActive ? Qt.alpha(Theme.accent, 0.16)
                                         : parent.memberHovered ? Theme.itemHover : "transparent"
                                    border.width: parent.memberActive || parent.memberDragging ? 1 : 0
                                    border.color: Qt.alpha(Theme.accent, 0.48)
                                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                                }

                                HoverHandler { id: memberHover }

                                TapHandler {
                                    onTapped: {
                                        for (let i = 0; i < Browser.tabModel.count; ++i) {
                                            const tab = Browser.tabModel.tabAt(i);
                                            if (tab && tab.id === splitMember.modelData.id && !root.isBlankPlaceholder(tab.url)) {
                                                Browser.activateTab(i);
                                                break;
                                            }
                                        }
                                    }
                                }

                                DragHandler {
                                    target: null
                                    onActiveChanged: {
                                        if (active) {
                                            root.dragSplitMemberId = splitMember.modelData.id;
                                            root.dragSplitMemberTitle = splitMember.modelData.title;
                                            root.dragSplitMemberIcon = splitMember.modelData.iconUrl;
                                            const p = root.mapFromItem(null, centroid.scenePosition.x, centroid.scenePosition.y);
                                            root.dragSplitPosition = Qt.point(p.x + 14, p.y + 14);
                                        } else if (root.dragSplitMemberId === splitMember.modelData.id) {
                                            const p = row.mapFromItem(null, centroid.scenePosition.x, centroid.scenePosition.y);
                                            const droppedOutside = p.x < 0 || p.y < 0 || p.x > row.width || p.y > row.height;
                                            root.dragSplitMemberId = "";
                                            if (droppedOutside)
                                                Browser.sidebar.separateSplitTab(splitMember.modelData.id);
                                        }
                                    }
                                    onCentroidChanged: if (active) {
                                        const p = root.mapFromItem(null, centroid.scenePosition.x, centroid.scenePosition.y);
                                        root.dragSplitPosition = Qt.point(p.x + 14, p.y + 14);
                                    }
                                }

                                RowLayout {
                                    anchors {
                                        fill: parent
                                        leftMargin: Theme.space1
                                        rightMargin: Theme.space1
                                    }
                                    spacing: Theme.space1
                                    Rectangle {
                                        visible: row.index > 0
                                        Layout.preferredWidth: 1
                                        Layout.preferredHeight: 14
                                        color: Theme.itemActiveBorder
                                    }
                                    Item {
                                        Layout.preferredWidth: 16
                                        Layout.preferredHeight: 16
                                        readonly property bool showMemberIcon: splitMember.memberIconUrl !== ""
                                            && !splitMember.memberIconUrl.startsWith("chrome:")
                                            && !splitMember.memberIconUrl.startsWith("about:")
                                            && !splitMember.faviconFailed
                                        Image {
                                            anchors.fill: parent
                                            visible: parent.showMemberIcon
                                            source: visible ? splitMember.memberIconUrl : ""
                                            sourceSize.width: 32
                                            sourceSize.height: 32
                                            fillMode: Image.PreserveAspectFit
                                            asynchronous: true
                                            onStatusChanged: if (status === Image.Error) splitMember.faviconFailed = true
                                        }
                                        LucideIcon {
                                            anchors.centerIn: parent
                                            visible: !parent.showMemberIcon
                                            source: "qrc:/illuminate/ui/icons/globe.svg"
                                            size: 14
                                            color: Theme.textMuted
                                        }
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        text: splitMember.modelData.title
                                        color: Theme.text
                                        elide: Text.ElideRight
                                        font { family: Theme.fontFamily; pixelSize: Theme.fontSizeS }
                                    }
                                }
                            }
                        }
                        Text {
                            Layout.leftMargin: Theme.space1
                            text: "×"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontSizeM
                            TapHandler {
                                onTapped: Browser.sidebar.separateSplit(row.nodeId)
                            }
                        }
                    }
                }
            }

            // the divider under the folders, and "+ New Tab"
            Component {
                id: headerComponent
                Item {
                    Rectangle {
                        visible: Browser.sidebar.folderCount > 0
                        x: Theme.space2
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - Theme.space2 * 2
                        height: 1
                        color: Theme.itemHover
                    }
                }
            }

            DragHandler {
                id: dragHandler
                target: null
                enabled: (row.kind === "tab" || row.kind === "folder") && root.sidebar.renamingId !== row.nodeId
                onActiveChanged: active ? root.beginDrag(row) : root.endDrag()
                onCentroidChanged: if (active) root.dragMove(centroid.scenePosition)
            }
        }

        // where the dragged row would land
        Rectangle {
            visible: root.dragId !== "" && root.dropPosition >= 0 && root.dropPosition !== SidebarModel.Into
            x: root.indicatorX + Theme.space1
            y: root.indicatorY - height / 2
            z: 10
            width: rowsView.width - x - Theme.space1
            height: 2
            radius: 1
            color: Theme.accent
        }

        TapHandler {
            onTapped: eventPoint => {
                if (!root.sidebar.renamingId)
                    return;
                const p = eventPoint.position;
                const row = rowsView.itemAt(p.x + rowsView.contentX, p.y + rowsView.contentY);
                // qmllint disable missing-property
                if (row && row["nodeId"] === root.sidebar.renamingId)
                    return;
                // qmllint enable missing-property
                root.forceActiveFocus();
            }
        }

        TapHandler {
            onDoubleTapped: eventPoint => {
                const p = eventPoint.position;
                if (!rowsView.itemAt(p.x + rowsView.contentX, p.y + rowsView.contentY))
                    root.sidebar.commandBarRequested("new");
            }
        }

        // empty space: the sidebar's own menu
        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: eventPoint => {
                const p = eventPoint.position;
                if (!rowsView.itemAt(p.x + rowsView.contentX, p.y + rowsView.contentY))
                    root.contextMenuRequested();
            }
        }
    }

    SidebarDragPreviews {
        anchors.fill: parent
        tree: root
    }

}
