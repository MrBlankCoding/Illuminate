import QtQuick
import QtTest
import illuminate.ui

Item {
    id: root
    width: 800
    height: 600

    Component {
        id: pageComponent
        CrashedPage {
            anchors.fill: parent
        }
    }

    TestCase {
        name: "CrashedPageTests"
        when: windowShown

        function crashUrl(address) {
            return "illuminate://crashed?url=" + encodeURIComponent(address)
        }

        function test_componentLoads() {
            compare(pageComponent.status, Component.Ready)
        }

        function test_readsTheCrashedAddress() {
            const address = "https://www.example.com/a?b=1&c=two words#top"
            const page = createTemporaryObject(pageComponent, root, { pageUrl: crashUrl(address) })
            compare(page.crashedUrl, address)
            compare(page.crashedHost, "example.com")
            verify(findChild(page, "crashDetail").text.indexOf("example.com") >= 0)
            verify(findChild(page, "reloadButton").visible)
        }

        function test_withoutAnAddressThereIsNothingToReload() {
            const page = createTemporaryObject(pageComponent, root, { pageUrl: "illuminate://crashed" })
            compare(page.crashedUrl, "")
            verify(!findChild(page, "reloadButton").visible)
        }

        function test_malformedEncodingIsTolerated() {
            const page = createTemporaryObject(pageComponent, root, { pageUrl: "illuminate://crashed?url=%E0%A4%A" })
            compare(page.crashedUrl, "")
        }

        function test_reloadLoadsTheAddressInItsOwnTab() {
            Browser.newTab("https://before.example")
            const tab = Browser.tabModel.tabAt(Browser.tabModel.activeIndex)
            const address = "https://crashy.example/page"
            const page = createTemporaryObject(pageComponent, root, {
                pageUrl: crashUrl(address), tabId: tab.id
            })
            mouseClick(findChild(page, "reloadButton"))
            compare(Browser.activeUrl, address)
            Browser.closeTab(Browser.tabModel.activeIndex)
        }
    }
}
