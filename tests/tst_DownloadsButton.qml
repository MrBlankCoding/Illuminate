import QtQuick
import QtTest
import illuminate.ui

Item {
    id: root
    width: 400
    height: 400

    Component {
        id: buttonComponent
        DownloadsButton {
            y: 300
        }
    }

    TestCase {
        name: "DownloadsButtonTests"
        when: windowShown

        function test_componentLoads() {
            compare(buttonComponent.status, Component.Ready)
        }

        // QML once built its own empty list, so downloads never showed up
        function test_qmlSeesTheListTheBrowserFills() {
            verify(Downloads === cppDownloads, "Downloads must be DownloadModel::instance()")
        }

        function test_hiddenUntilThereIsSomethingToShow() {
            compare(Downloads.count, 0)
            const button = createTemporaryObject(buttonComponent, root)
            verify(!button.visible)
            button.hasPreviousDownloads = true
            verify(button.visible)
        }

        function test_noRingOrDotWhenIdle() {
            const button = createTemporaryObject(buttonComponent, root, { hasPreviousDownloads: true })
            verify(!button.downloading)
            verify(!findChild(button, "progressRing").visible)
            verify(!findChild(button, "unseenDot").visible)
        }

        // nothing from this session yet: the full downloads page
        function test_withNoSessionDownloadsClickingOpensTheDownloadsPage() {
            const before = Browser.tabModel.count
            const button = createTemporaryObject(buttonComponent, root, { hasPreviousDownloads: true })
            mouseClick(findChild(button, "downloadsButton"))
            tryCompare(Browser.tabModel, "count", before + 1)
            compare(Browser.activeUrl, "chrome://downloads/")
            verify(!button.popupOpen)
            Browser.closeTab(Browser.tabModel.activeIndex)
        }
    }
}
