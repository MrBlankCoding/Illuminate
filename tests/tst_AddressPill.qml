import QtQuick
import QtTest
import illuminate.ui

Item {
    id: root
    width: 800
    height: 600

    Component {
        id: pillComponent
        AddressPill {
            width: 320
        }
    }

    SignalSpy {
        id: clickedSpy
        signalName: "clicked"
    }

    TestCase {
        name: "AddressPillTests"
        when: windowShown

        function cleanup() {
            while (Bookmarks.count > 0)
                Bookmarks.removeBookmark(0)
            clickedSpy.clear()
        }

        function makePill(props) {
            const pill = createTemporaryObject(pillComponent, root, props || {})
            verify(!!pill)
            return pill
        }

        function test_componentLoads() {
            compare(pillComponent.status, Component.Ready)
        }

        function test_displayHost_data() {
            return [
                { tag: "strips www", url: "https://www.example.com/a/b", host: "example.com" },
                { tag: "keeps subdomains", url: "https://docs.github.com/en", host: "docs.github.com" },
                { tag: "keeps the port", url: "http://localhost:8080/app", host: "localhost:8080" },
                { tag: "drops query", url: "https://example.com?q=1", host: "example.com" },
                { tag: "drops fragment", url: "https://example.com#top", host: "example.com" },
                { tag: "internal page", url: "chrome://settings", host: "settings" },
                { tag: "not a url", url: "just text", host: "just text" }
            ]
        }
        function test_displayHost(data) {
            const pill = makePill()
            compare(pill.displayHost(data.url), data.host)
        }

        function test_bookmarkStateFollowsBookmarks() {
            const pill = makePill({ currentUrl: "https://example.com" })
            verify(!pill.isBookmarked)
            Bookmarks.toggleBookmark("Example", "https://example.com")
            verify(pill.isBookmarked)
            Bookmarks.toggleBookmark("Example", "https://example.com")
            verify(!pill.isBookmarked)
        }

        function test_emptyAddressIsNeverBookmarked() {
            const pill = makePill({ currentUrl: "" })
            verify(!pill.isBookmarked)
        }

        function test_bookmarkStateFollowsTheAddress() {
            Bookmarks.toggleBookmark("Example", "https://example.com")
            const pill = makePill({ currentUrl: "https://other.org" })
            verify(!pill.isBookmarked)
            pill.currentUrl = "https://example.com"
            verify(pill.isBookmarked)
        }

        function test_clickingThePillOpensTheAddressBar() {
            const pill = makePill({ currentUrl: "https://example.com" })
            clickedSpy.target = pill
            mouseClick(pill, 40, pill.height / 2)
            tryCompare(clickedSpy, "count", 1)
        }
    }
}
