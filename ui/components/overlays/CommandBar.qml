import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Effects
import QtQuick.Layouts
import illuminate.ui
import "CommandBarLogic.js" as CommandBarLogic

pragma ComponentBehavior: Bound

Popup {
    id: root

    property string mode: "new"
    property var quickActions: []
    property var internalSchemes: ["newtab", "about", "qrc", "chrome", "view-source"]

    readonly property int shadowPad: 28
    readonly property int inputRowHeight: 56
    readonly property int rowHeight: 40
    readonly property int maxRows: 8
    readonly property int preferredWidth: 736
    readonly property int compactHeight: inputRowHeight + shadowPad * 2
    readonly property real listChrome: Theme.space2 * 2 + 1
    readonly property real maxCardHeight: inputRowHeight + listChrome + maxRows * rowHeight
    readonly property real preferredHeight: maxCardHeight + shadowPad * 2
    readonly property real cardTargetHeight: Math.min(
        inputRowHeight + (visibleRows > 0 ? listChrome + visibleRows * rowHeight : 0),
        availableHeight)

    property int highlighted: -1
    property bool navigated: false
    property int visibleRows: 0
    property bool queryActive: false
    property string suggestionsQuery: ""
    property bool settling: false
    property var heldSuggestions: []
    property point lastPointer: Qt.point(-1, -1)
    readonly property var activeTab: Browser.tabModel.tabAt(Browser.tabModel.activeIndex)
    // structureRevision: re-checked when a split forms or breaks around this tab
    readonly property bool activeTabIsSplit: activeTab && Browser.sidebar.structureRevision >= 0
        ? Browser.sidebar.isSplitTab(String(activeTab.id)) : false
    popupType: mode === "new" && String(Browser.activeUrl) === "newtab://newtab" && !root.activeTabIsSplit
        ? Popup.Item : Popup.Window
    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside | Popup.CloseOnPressOutsideParent
    padding: shadowPad
    width: Math.min(root.preferredWidth, parent.width - 32)
    height: Math.min(root.preferredHeight, parent.height - 32)
    x: Math.round((parent.width - width) / 2)
    y: Math.max(16, Math.round((parent.height - height) / 2))
    Component.onCompleted: PopupCloser.watch(root)

    function resetState() {
        rebuildTimer.stop();
        suggestTimer.stop();
        settleTimer.stop();
        shrinkTimer.stop();
        root.settling = false;
        root.queryActive = false;
        root.navigated = false;
        root.highlighted = -1;
        root.visibleRows = 0;
        root.suggestionsQuery = "";
        root.heldSuggestions = [];
        resultsModel.clear();
        suggestions.clear();
    }

    function openNew() {
        root.resetState();
        root.mode = "new";
        input.text = "";
        root.open();
    }

    function openEdit(url) {
        root.resetState();
        root.mode = "edit";
        const u = String(url);
        input.text = root.isInternalUrl(u) ? "" : u;
        root.open();
    }

    onOpened: {
        root.rebuild();
        Qt.callLater(() => {
            if (!root.visible)
                return;
            const popupWindow = input.Window.window;
            if (popupWindow) {
                popupWindow.raise();
                popupWindow.requestActivate();
                Qt.callLater(() => {
                    if (root.visible && popupWindow.active)
                        root.focusInput(true);
                });
            }
        });
    }
    onClosed: root.resetState()

    onHighlightedChanged: {
        if (highlighted >= 0)
            resultsView.ensureIndexVisible(highlighted);
    }

    function focusInput(selectAll) {
        if (!root.visible)
            return;
        input.forceActiveFocus();
        if (selectAll)
            input.selectAll();
    }

    Connections {
        target: input.Window.window
        enabled: input.Window.window !== null
        function onActiveChanged() {
            if (input.Window.window && input.Window.window.active) {
                input.Window.window.raise();
                root.focusInput(false);
            }
        }
    }

    Shortcut {
        sequence: "Esc"
        context: Qt.WindowShortcut
        enabled: root.visible
        onActivated: root.close()
    }

    function looksLikeUrl(text) { return CommandBarLogic.looksLikeUrl(text) }
    function isInternalUrl(url) { return CommandBarLogic.isInternalUrl(url, root.internalSchemes) }
    function stripScheme(url) { return CommandBarLogic.stripScheme(url) }

    function requestSuggestions() {
        const text = input.text;
        if (text.trim() === "")
            return;
        root.suggestionsQuery = text.trim().toLowerCase();
        root.settling = true;
        settleTimer.restart();
        suggestions.update(text);
    }

    function readSuggestions(q) {
        const sm = suggestions.model;
        const fresh = [];
        for (let i = 0; i < sm.count; ++i) {
            const s = sm.get(i);
            if (!s)
                continue;
            fresh.push({
                text: String(s.text),
                url: s.isBookmark ? String(s.url) : "",
                isBookmark: !!s.isBookmark
            });
        }
        const stale = root.suggestionsQuery !== q;
        if (fresh.length > 0) {
            root.heldSuggestions = fresh;
            return stale ? CommandBarLogic.compatible(fresh, q) : fresh;
        }
        if (stale || root.settling)
            return CommandBarLogic.compatible(root.heldSuggestions, q);
        return [];
    }

    function buildResults() {
        return CommandBarLogic.buildResults({
            text: input.text,
            queryActive: root.queryActive,
            searchEngineName: Prefs.searchEngineName,
            calculatorEnabled: Prefs.commandBarCalculatorEnabled,
            bangsEnabled: Prefs.commandBarBangsEnabled,
            quickActions: root.quickActions,
            mode: root.mode,
            tabs: Browser.tabModel,
            internalSchemes: root.internalSchemes,
            suggestions: root.readSuggestions(input.text.trim().toLowerCase()),
            maxRows: root.maxRows
        });
    }

    function syncModel(next) {
        for (let i = 0; i < next.length; ++i) {
            const row = next[i];
            let at = -1;
            for (let j = i; j < resultsModel.count; ++j) {
                if (resultsModel.get(j).key === row.key) {
                    at = j;
                    break;
                }
            }
            if (at < 0) {
                resultsModel.insert(i, row);
            } else {
                if (at !== i)
                    resultsModel.move(at, i, 1);
                if (!CommandBarLogic.sameRow(resultsModel.get(i), row))
                    resultsModel.set(i, row);
            }
        }
        if (resultsModel.count > next.length)
            resultsModel.remove(next.length, resultsModel.count - next.length);
    }

    function rebuild() {
        if (!root.visible)
            return;
        rebuildTimer.stop();

        const keepKey = (root.navigated && root.highlighted >= 0 && root.highlighted < resultsModel.count)
                ? resultsModel.get(root.highlighted).key : "";

        root.syncModel(root.buildResults());

        let idx = -1;
        for (let i = 0; keepKey !== "" && i < resultsModel.count; ++i) {
            if (resultsModel.get(i).key === keepKey) {
                idx = i;
                break;
            }
        }
        if (idx < 0)
            root.navigated = false;
        root.highlighted = idx >= 0 ? idx : (resultsModel.count > 0 ? 0 : -1);
        root.updateVisibleRows();
    }

    function updateVisibleRows() {
        const target = Math.min(root.maxRows, resultsModel.count);
        if (target === 0 || target > root.visibleRows) {
            shrinkTimer.stop();
            root.visibleRows = target;
        } else if (target < root.visibleRows) {
            shrinkTimer.restart();
        } else {
            shrinkTimer.stop();
        }
    }

    function handleEdit() {
        root.queryActive = true;
        root.navigated = false;
        if (input.text.trim() === "") {
            suggestTimer.stop();
            settleTimer.stop();
            root.settling = false;
            root.suggestionsQuery = "";
            root.heldSuggestions = [];
            suggestions.clear();
        } else {
            suggestTimer.restart();
        }
        root.rebuild();
    }

    function moveHighlight(delta) {
        const n = resultsModel.count;
        if (n === 0)
            return;
        root.navigated = true;
        if (root.highlighted < 0)
            root.highlighted = delta > 0 ? 0 : n - 1;
        else
            root.highlighted = (root.highlighted + delta + n) % n;
    }

    function hoverHighlight(i) {
        if (root.highlighted === i)
            return;
        root.navigated = true;
        root.highlighted = i;
    }

    function completeHighlighted() {
        if (root.highlighted < 0 || root.highlighted >= resultsModel.count)
            return;
        const r = resultsModel.get(root.highlighted);
        if (r.kind !== "suggest" && r.kind !== "bookmark" && r.kind !== "calc" && r.kind !== "bang")
            return;
        input.text = r.dest;
        input.cursorPosition = input.text.length;
        root.handleEdit();
    }

    function commit(index, background) {
        const row = index >= 0 && index < resultsModel.count ? resultsModel.get(index) : null;
        const typed = input.text.trim();

        const kind = row ? row.kind : "";
        const dest = row ? row.dest : typed;
        const tabIndex = row ? row.tabIndex : -1;
        const action = kind === "action" ? root.quickActions[row.actionIndex] : null;
        const reuseTab = root.mode === "edit"
                || (!background && String(Browser.activeUrl) === "newtab://newtab");

        if (kind === "calc" || kind === "bang") {
            input.text = dest;
            input.cursorPosition = input.text.length;
            root.handleEdit();
            root.focusInput(false);
            return;
        }

        root.close();
        if (kind === "tab") {
            Browser.activateTab(tabIndex);
            return;
        }
        if (kind === "action") {
            if (action)
                action.run();
            return;
        }
        if (dest === "")
            return;
        if (reuseTab)
            Browser.navigate(dest);
        else
            Browser.newTab(dest, background);
    }

    ListModel {
        id: resultsModel
    }

    SuggestionProvider {
        id: suggestions
    }

    Connections {
        target: suggestions.model
        function onCountChanged() { rebuildTimer.restart() }
        function onDataChanged() { rebuildTimer.restart() }
        function onModelReset() { rebuildTimer.restart() }
        function onRowsInserted() { rebuildTimer.restart() }
        function onRowsRemoved() { rebuildTimer.restart() }
    }

    Timer {
        id: rebuildTimer
        interval: 30
        onTriggered: root.rebuild()
    }

    Timer {
        id: suggestTimer
        interval: 90
        onTriggered: root.requestSuggestions()
    }

    Timer {
        id: settleTimer
        interval: 350
        onTriggered: {
            root.settling = false;
            root.rebuild();
        }
    }

    Timer {
        id: shrinkTimer
        interval: 320
        onTriggered: root.visibleRows = Math.min(root.maxRows, resultsModel.count)
    }

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.motion(180); easing.type: Easing.OutCubic }
        NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: Theme.motion(180); easing.type: Easing.OutBack; easing.overshoot: 1.2 }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; to: 0; duration: Theme.durationFast; easing.type: Easing.InQuad }
        NumberAnimation { property: "scale"; to: 0.98; duration: Theme.durationFast; easing.type: Easing.InQuad }
    }

    Overlay.modal: Item {}

    background: Item {
        RectangularShadow {
            anchors { top: parent.top; topMargin: root.shadowPad; horizontalCenter: parent.horizontalCenter }
            width: card.width
            height: card.height
            radius: card.radius
            blur: 28
            offset.y: 8
            color: Theme.shadow
        }

        Rectangle {
            id: card
            anchors {
                top: parent.top
                topMargin: root.shadowPad
                left: parent.left
                leftMargin: root.shadowPad
                right: parent.right
                rightMargin: root.shadowPad
            }
            height: root.cardTargetHeight
            Behavior on height {
                NumberAnimation { duration: Theme.motion(180); easing.type: Easing.OutCubic }
            }
            radius: Theme.radiusCommand
            color: Theme.cardBg
            border.width: 1
            border.color: Theme.cardBorder
            clip: true
        }
    }

    contentItem: Item {
        Item {
            id: viewport
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            height: card.height
            clip: true

            ColumnLayout {
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }
                height: root.cardTargetHeight
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.inputRowHeight
                    Layout.leftMargin: Theme.space4 + 2
                    Layout.rightMargin: Theme.space4
                    spacing: Theme.space3

                    LucideIcon {
                        size: 18
                        source: "qrc:/illuminate/ui/icons/search.svg"
                        color: Theme.textMuted
                    }

                    TextInput {
                        id: input
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 0
                        focus: root.visible
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true
                        selectByMouse: true
                        color: Theme.text
                        selectionColor: Theme.accentDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeXL

                        readonly property string mathAnswer: {
                            if (!Prefs.commandBarCalculatorEnabled || resultsModel.count === 0)
                                return "";
                            const top = resultsModel.get(0);
                            return top && top.kind === "calc" ? top.title : "";
                        }

                        onTextEdited: root.handleEdit()

                        Keys.onDownPressed: root.moveHighlight(1)
                        Keys.onUpPressed: root.moveHighlight(-1)
                        Keys.onTabPressed: event => {
                            root.completeHighlighted();
                            event.accepted = true;
                        }
                        Keys.onRightPressed: event => {
                            if (input.mathAnswer !== "" && input.cursorPosition === input.text.length) {
                                input.text = input.mathAnswer;
                                input.cursorPosition = input.text.length;
                                root.handleEdit();
                                event.accepted = true;
                                return;
                            }
                            event.accepted = false;
                        }
                        Keys.onReturnPressed: event => root.commit(root.highlighted, (event.modifiers & Qt.ControlModifier) !== 0)
                        Keys.onEnterPressed: event => root.commit(root.highlighted, (event.modifiers & Qt.ControlModifier) !== 0)

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            visible: input.text === ""
                            text: "Search with " + Prefs.searchEngineName + " or enter address"
                            color: Theme.textMuted
                            font: input.font
                        }

                        // Inline autofill ghost preview when user types math
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            x: input.cursorRectangle.x + (input.cursorPosition === input.text.length ? 0 : 99999)
                            visible: input.mathAnswer !== "" && input.cursorPosition === input.text.length
                            text: " = " + input.mathAnswer
                            color: Theme.textMuted
                            font: input.font
                            opacity: 0.6
                        }
                    }
                }

                CommandBarResults {
                    id: resultsView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: resultsModel
                    visibleRows: root.visibleRows
                    maxRows: root.maxRows
                    rowHeight: root.rowHeight
                    highlightedIndex: root.highlighted
                    urlCheck: root.looksLikeUrl
                    onHoverDetected: (index, position) => {
                        if (position.x === root.lastPointer.x && position.y === root.lastPointer.y)
                            return;
                        root.lastPointer = position;
                        root.hoverHighlight(index);
                    }
                    onCommitRequested: index => root.commit(index, false)
                }
            }
        }
    }
}
