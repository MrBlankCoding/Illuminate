import QtQuick
import QtTest
import illuminate.ui

Item {
    id: root
    width: 300
    height: 600

    // what the tree asks of the Sidebar around it
    QtObject {
        id: fakeSidebar
        property string renamingId: ""
        property var targetWindow: null
        signal commandBarRequested(string mode)
        function openTabMenu(model) {}
        function openFolderMenu(model) {}
        function startRename(id) {}
    }

    Component {
        id: testedComponent
        SidebarTree {
            width: 300
            height: 600
            sidebar: fakeSidebar
        }
    }

    TestCase {
        name: "SidebarTreeTests"
        when: windowShown

        function firstTabRow(tree) {
            const list = tree.tabList
            for (let i = 0; i < list.count; ++i) {
                const row = list.itemAtIndex(i)
                if (row && row.kind === "tab")
                    return row
            }
            return null
        }

        function test_componentLoads() {
            compare(testedComponent.status, Component.Ready)
        }

        // a space switch replaces every row at once; row transitions sit it out
        function test_rowAnimationsPauseForASpaceSwitch() {
            const tree = createTemporaryObject(testedComponent, root)
            verify(tree.animateRows)
            Browser.spaceAboutToChange()
            verify(!tree.animateRows)
            Browser.spaceChanged()
            tryCompare(tree, "animateRows", true)
        }

        // transitions animate their own properties, so the drag dimming binding survives them
        function test_rowsDimWhileDraggedAfterAnimatingIn() {
            Browser.newTab("https://dim.example")
            const tree = createTemporaryObject(testedComponent, root)
            let row = null
            tryVerify(() => (row = firstTabRow(tree)) !== null)
            tryCompare(row, "opacity", 1)
            tree.dragId = row.nodeId
            compare(row.opacity, 0.4)
            tree.dragId = ""
            compare(row.opacity, 1)
            Browser.closeTab(Browser.tabModel.activeIndex)
        }

        function test_aRecycledRowStartsWhole() {
            Browser.newTab("https://recycle.example")
            const tree = createTemporaryObject(testedComponent, root)
            let row = null
            tryVerify(() => (row = firstTabRow(tree)) !== null)
            row.appear = 0
            row.appearScale = 0.5
            row.ListView.reused()
            compare(row.appear, 1)
            compare(row.appearScale, 1)
            Browser.closeTab(Browser.tabModel.activeIndex)
        }
    }
}
