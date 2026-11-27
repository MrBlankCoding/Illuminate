import QtQuick
import QtTest
import illuminate.ui

Item {
    id: root
    width: 800
    height: 600

    Component {
        id: providerComponent
        SuggestionProvider {}
    }

    TestCase {
        name: "SuggestionProviderTests"
        when: windowShown

        property bool suggestionsWereEnabled: true

        function initTestCase() {
            // nothing here may reach the network
            suggestionsWereEnabled = Prefs.searchSuggestionsEnabled
            Prefs.searchSuggestionsEnabled = false
        }

        function cleanupTestCase() {
            Prefs.searchSuggestionsEnabled = suggestionsWereEnabled
        }

        function cleanup() {
            while (Bookmarks.count > 0)
                Bookmarks.removeBookmark(0)
        }

        function makeProvider() {
            const provider = createTemporaryObject(providerComponent, root)
            verify(!!provider)
            return provider
        }

        function rows(provider) {
            const out = []
            for (let i = 0; i < provider.count; ++i)
                out.push(provider.model.get(i))
            return out
        }

        function test_componentLoads() {
            compare(providerComponent.status, Component.Ready)
        }

        function test_startsEmpty() {
            const provider = makeProvider()
            compare(provider.count, 0)
            compare(provider.query, "")
        }

        function test_blankInputClears() {
            const provider = makeProvider()
            Bookmarks.toggleBookmark("Example", "https://example.com")
            provider.update("ex")
            verify(provider.count > 0)
            provider.update("   ")
            compare(provider.count, 0)
            compare(provider.query, "")
        }

        function test_queryIsTrimmed() {
            const provider = makeProvider()
            provider.update("  hello  ")
            compare(provider.query, "hello")
        }

        function test_bookmarksMatchByTitleOrAddress() {
            const provider = makeProvider()
            Bookmarks.toggleBookmark("Docs", "https://developer.example.com")
            Bookmarks.toggleBookmark("Weather", "https://weather.com")
            provider.update("develop")
            const found = rows(provider)
            compare(found.length, 1)
            compare(found[0].text, "Docs")
            compare(found[0].isBookmark, true)

            provider.update("WEATHER")
            compare(rows(provider)[0].text, "Weather")
        }

        function test_atMostThreeBookmarks() {
            const provider = makeProvider()
            for (let i = 0; i < 5; ++i)
                Bookmarks.toggleBookmark("Page " + i, "https://page" + i + ".example.com")
            provider.update("page")
            compare(provider.count, 3)
        }

        function test_inputAtGivesTheAddressForABookmarkAndTheTextOtherwise() {
            const provider = makeProvider()
            Bookmarks.toggleBookmark("Example", "https://example.com")
            provider.cache = { "ex": [{ text: "extra", url: "", isBookmark: false }] }
            provider.update("ex")
            compare(provider.count, 2)
            compare(provider.inputAt(0), "https://example.com")
            compare(provider.inputAt(1), "extra")
            compare(provider.inputAt(-1), "")
            compare(provider.inputAt(5), "")
        }

        function test_cachedSuggestionsAreMergedWithoutDuplicates() {
            const provider = makeProvider()
            Bookmarks.toggleBookmark("News", "https://news.example.com")
            provider.cache = {
                "news": [
                    { text: "NEWS", url: "", isBookmark: false },     // same as the bookmark title
                    { text: "news today", url: "", isBookmark: false },
                    { text: "news live", url: "", isBookmark: false }
                ]
            }
            provider.update("news")
            compare(rows(provider).map(r => r.text), ["News", "news today", "news live"])
        }

        function test_cachedSuggestionsAreCappedAtEight() {
            const provider = makeProvider()
            const many = []
            for (let i = 0; i < 12; ++i)
                many.push({ text: "q " + i, url: "", isBookmark: false })
            provider.cache = { "q": many }
            provider.update("q")
            compare(provider.count, 8)
        }

        function test_disabledSuggestionsLeaveOnlyLocalResults() {
            const provider = makeProvider()
            Bookmarks.toggleBookmark("Local", "https://local.example.com")
            provider.update("local")
            // past the debounce, which would fetch if suggestions were enabled
            wait(120)
            compare(provider.count, 1)
            compare(rows(provider)[0].text, "Local")
        }

        function test_clearEmptiesEverything() {
            const provider = makeProvider()
            Bookmarks.toggleBookmark("Example", "https://example.com")
            provider.update("ex")
            provider.clear()
            compare(provider.count, 0)
            compare(provider.query, "")
            compare(provider.localMatches.length, 0)
        }
    }
}
