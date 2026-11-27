import QtQuick
import QtTest
import illuminate.ui

Item {
    id: root
    width: 800
    height: 600

    Component {
        id: testedComponent
        TabSlot {}
    }

    // what TabSlot reads from BrowserWindow and BrowserWorkspace
    QtObject {
        id: fakeWindow
        property bool inputOverlayOpen: false
        property var warmSpaces: null
        function returnFocusToWeb() {}
        function claimUiFocus(owner) {}
        function releaseUiFocus(owner) {}
        function openSystemPrintFor(view) {}
        function onPdfPrintingFinished(filePath, success) {}
    }
    QtObject {
        id: fakeViewStack
        property real cornerRadius: 0
        function refreshActiveWebView() {}
    }

    Item {
        id: stack
        anchors.fill: parent

        Repeater {
            id: slots
            model: null
            delegate: TabSlot {
                browserWindow: fakeWindow
                viewStack: fakeViewStack
            }
        }
    }

    TestCase {
        name: "TabSlotTests"
        when: windowShown

        property var createdIds: []

        function indexOfId(id) {
            for (let i = 0; i < Browser.tabModel.count; ++i) {
                if (String(Browser.tabModel.tabAt(i).id) === String(id))
                    return i;
            }
            return -1;
        }

        // a background new-tab page: internal, so no Chromium page is created
        function addTab() {
            const before = Browser.tabModel.count;
            Browser.newTab("", true);
            compare(Browser.tabModel.count, before + 1);
            const id = String(Browser.tabModel.tabAt(before).id);
            createdIds.push(id);
            return id;
        }

        function slotFor(id) {
            return slots.itemAt(indexOfId(id));
        }

        function init() {
            createdIds = [];
            slots.model = Browser.tabModel;
        }

        function cleanup() {
            slots.model = null;
            for (const id of createdIds) {
                if (Browser.sidebar.isSplitTab(id))
                    Browser.sidebar.separateSplitTab(id);
            }
            for (let i = createdIds.length - 1; i >= 0; --i) {
                const index = indexOfId(createdIds[i]);
                if (index >= 0)
                    Browser.closeTab(index);
            }
        }

        function test_componentLoads() {
            compare(testedComponent.status, Component.Ready)
        }

        // two splits: only the one holding the active tab is on screen, or
        // the hidden split's pages keep running, stacked under the visible ones
        function test_onlyActiveSplitIsVisible() {
            const a = addTab(), b = addTab(), c = addTab(), d = addTab(), solo = addTab();
            verify(Browser.sidebar.createSplit(a, b) !== "");
            verify(Browser.sidebar.createSplit(c, d) !== "");

            Browser.activateTab(indexOfId(a));
            tryVerify(() => slotFor(a).visible && slotFor(b).visible);
            verify(!slotFor(c).visible, "a split that isn't active stays hidden");
            verify(!slotFor(d).visible, "a split that isn't active stays hidden");
            verify(!slotFor(solo).visible);

            Browser.activateTab(indexOfId(d));
            tryVerify(() => slotFor(c).visible && slotFor(d).visible);
            verify(!slotFor(a).visible);
            verify(!slotFor(b).visible);

            Browser.activateTab(indexOfId(solo));
            tryVerify(() => slotFor(solo).visible);
            for (const id of [a, b, c, d])
                verify(!slotFor(id).visible, "split members hide behind an unsplit tab");
        }

        function test_splitHalvesSitSideBySide() {
            const a = addTab(), b = addTab();
            verify(Browser.sidebar.createSplit(a, b) !== "");
            Browser.activateTab(indexOfId(a));

            const left = slotFor(a), right = slotFor(b);
            tryVerify(() => left.visible && right.visible);
            compare(left.x, 0);
            verify(left.width < stack.width / 2 + 1);
            verify(right.x >= left.x + left.width, "the halves don't overlap");
            verify(right.x + right.width <= stack.width + 0.5);
        }

        function test_isActiveTabFollowsSelection() {
            const a = addTab(), b = addTab();
            verify(Browser.sidebar.createSplit(a, b) !== "");
            Browser.activateTab(indexOfId(a));
            tryVerify(() => slotFor(a).isActiveTab);
            verify(!slotFor(b).isActiveTab);

            Browser.activateTab(indexOfId(b));
            tryVerify(() => slotFor(b).isActiveTab);
            verify(!slotFor(a).isActiveTab);
        }
    }
}
