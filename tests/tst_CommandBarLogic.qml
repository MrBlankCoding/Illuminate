import QtQuick
import QtTest
import "../ui/components/overlays/CommandBarLogic.js" as Logic

// the command bar's search and ranking, without the popup around it
TestCase {
    name: "CommandBarLogicTests"

    readonly property var internalSchemes: ["newtab", "illuminate", "chrome"]

    // stand-ins for TabModel and BookmarkModel: count plus itemAt()
    function listOf(items, activeIndex) {
        return {
            count: items.length,
            activeIndex: activeIndex === undefined ? -1 : activeIndex,
            itemAt: i => items[i]
        }
    }

    function tab(title, url) {
        return { title: title, url: url, iconUrl: "" }
    }

    function context(overrides) {
        return Object.assign({
            text: "",
            queryActive: true,
            mode: "new",
            searchEngineName: "DuckDuckGo",
            quickActions: [],
            tabs: listOf([]),
            bookmarks: listOf([]),
            suggestions: [],
            internalSchemes: internalSchemes,
            maxRows: 8
        }, overrides)
    }

    function kinds(rows) {
        return rows.map(r => r.kind)
    }

    // looksLikeUrl

    function test_looksLikeUrl_data() {
        return [
            { tag: "bare domain", text: "example.com", url: true },
            { tag: "domain with path", text: "github.com/anthropics", url: true },
            { tag: "explicit scheme", text: "https://example.com", url: true },
            { tag: "internal scheme", text: "chrome://settings", url: true },
            { tag: "localhost", text: "localhost", url: true },
            { tag: "localhost with port", text: "localhost:3000/app", url: true },
            { tag: "single word", text: "weather", url: false },
            { tag: "words with a dot", text: "node.js tutorial", url: false },
            { tag: "trailing dot only", text: "hello.", url: false },
            { tag: "file name", text: "node.js", url: false },
            { tag: "site with a script path", text: "example.com/app.js", url: true },
            { tag: "a number", text: "3.14", url: false },
            { tag: "ipv4", text: "192.168.1.1", url: true },
            { tag: "out-of-range ipv4", text: "300.1.1.1", url: false },
            { tag: "bracketed ipv6", text: "[::1]:8080", url: true },
            { tag: "about page", text: "about:blank", url: true },
            { tag: "mail link", text: "mailto:a@example.com", url: true }
        ]
    }
    function test_looksLikeUrl(data) {
        compare(Logic.looksLikeUrl(data.text), data.url)
    }

    // isInternalUrl / stripScheme

    function test_internalUrlsAreRecognisedCaseInsensitively() {
        verify(Logic.isInternalUrl("newtab://newtab", internalSchemes))
        verify(Logic.isInternalUrl("CHROME://settings", internalSchemes))
        verify(Logic.isInternalUrl("illuminate://memory", internalSchemes))
        verify(!Logic.isInternalUrl("https://example.com", internalSchemes))
        verify(!Logic.isInternalUrl("chrome settings", internalSchemes))
        verify(!Logic.isInternalUrl("chrome://a b", internalSchemes), "whitespace is never a URL")
    }

    function test_stripSchemeDropsSchemeAndWww() {
        compare(Logic.stripScheme("https://www.github.com/x"), "github.com/x")
        compare(Logic.stripScheme("http://example.com"), "example.com")
        compare(Logic.stripScheme("example.com"), "example.com")
        compare(Logic.stripScheme("https://wwwexample.com"), "wwwexample.com")
    }

    // matchScore

    function test_matchScoreRanksPrefixThenWordThenAnywhere() {
        compare(Logic.matchScore("GitHub", "git"), 3)
        compare(Logic.matchScore("Pull requests · GitHub", "git"), 2)
        compare(Logic.matchScore("docs/github", "git"), 2)
        compare(Logic.matchScore("legit", "git"), 1)
        compare(Logic.matchScore("GitLab", "hub"), 0)
    }

    function test_matchScoreAcceptsNonStrings() {
        compare(Logic.matchScore(42, "4"), 3)
    }

    // makeRow / sameRow

    function test_rowsHaveEveryFieldFilledIn() {
        const row = Logic.makeRow("go", "go", { title: "x" })
        compare(row.kind, "go")
        compare(row.title, "x")
        compare(row.subtitle, "")
        compare(row.tabIndex, -1)
        compare(row.actionIndex, -1)
    }

    function test_sameRowIgnoresTheKeyButNotTheContent() {
        const a = Logic.makeRow("tab", "tab:1", { title: "A", tabIndex: 1 })
        const b = Logic.makeRow("tab", "tab:other", { title: "A", tabIndex: 1 })
        const c = Logic.makeRow("tab", "tab:1", { title: "B", tabIndex: 1 })
        verify(Logic.sameRow(a, b))
        verify(!Logic.sameRow(a, c))
    }

    // buildResults

    function test_nothingTypedMeansNoRows() {
        compare(Logic.buildResults(context({ text: "" })).length, 0)
        compare(Logic.buildResults(context({ text: "   " })).length, 0)
        compare(Logic.buildResults(context({ text: "news", queryActive: false })).length, 0)
    }

    function test_firstRowSearchesForText() {
        const rows = Logic.buildResults(context({ text: "  weather today " }))
        compare(rows[0].kind, "go")
        compare(rows[0].title, "weather today")
        compare(rows[0].dest, "weather today")
        compare(rows[0].subtitle, "Search DuckDuckGo")
    }

    function test_firstRowOpensWhatLooksLikeAnAddress() {
        const rows = Logic.buildResults(context({ text: "example.com" }))
        compare(rows[0].subtitle, "Open")
        compare(rows[0].dest, "example.com")
    }

    function test_atMostTwoActionsBestMatchFirst() {
        const actions = [
            { label: "Toggle Sidebar", icon: "panel-left" },
            { label: "Settings", icon: "" },
            { label: "Open Sidebar Settings", icon: "" }
        ]
        const rows = Logic.buildResults(context({ text: "s", quickActions: actions }))
        const actionRows = rows.filter(r => r.kind === "action")
        compare(actionRows.length, 2)
        // "Settings" starts with the query; the others only match inside
        compare(actionRows[0].title, "Settings")
        compare(actionRows[0].actionIndex, 1)
        compare(actionRows[0].subtitle, "Action")
    }

    function test_openTabsMatchOnTitleOrAddress() {
        const tabs = listOf([
            tab("Inbox", "https://mail.example.com"),
            tab("Pull requests", "https://github.com/pulls"),
            tab("Weather", "https://weather.com")
        ])
        const rows = Logic.buildResults(context({ text: "github", tabs: tabs }))
        const tabRows = rows.filter(r => r.kind === "tab")
        compare(tabRows.length, 1)
        compare(tabRows[0].title, "Pull requests")
        compare(tabRows[0].tabIndex, 1)
        compare(tabRows[0].subtitle, "Switch to Tab")
    }

    function test_internalPagesAreNeverOfferedAsTabs() {
        const tabs = listOf([tab("New Tab", "newtab://newtab"), tab("Settings", "chrome://settings")])
        const rows = Logic.buildResults(context({ text: "n", tabs: tabs }))
        compare(rows.filter(r => r.kind === "tab").length, 0)
    }

    function test_editingSkipsTheTabBeingEdited() {
        const tabs = listOf([tab("Docs", "https://docs.example.com"), tab("Docs 2", "https://docs2.example.com")], 0)
        const rows = Logic.buildResults(context({ text: "docs", tabs: tabs, mode: "edit" }))
        const tabRows = rows.filter(r => r.kind === "tab")
        compare(tabRows.length, 1)
        compare(tabRows[0].tabIndex, 1)
    }

    function test_atMostThreeTabs() {
        const items = []
        for (let i = 0; i < 6; ++i)
            items.push(tab("Docs " + i, "https://docs" + i + ".example.com"))
        const rows = Logic.buildResults(context({ text: "docs", tabs: listOf(items) }))
        compare(rows.filter(r => r.kind === "tab").length, 3)
    }

    function test_bookmarksAlreadyOpenAreLeftToTheTabRow() {
        const tabs = listOf([tab("GitHub", "https://github.com")])
        const bookmarks = listOf([
            { title: "GitHub", url: "https://github.com", iconUrl: "" },
            { title: "GitHub Docs", url: "https://docs.github.com", iconUrl: "" }
        ])
        const rows = Logic.buildResults(context({ text: "git", tabs: tabs, bookmarks: bookmarks }))
        const bookmarkRows = rows.filter(r => r.kind === "bookmark")
        compare(bookmarkRows.length, 1)
        compare(bookmarkRows[0].url, "https://docs.github.com")
        compare(bookmarkRows[0].dest, "https://docs.github.com")
    }

    function test_bookmarksWithoutAnAddressAreSkipped() {
        const bookmarks = listOf([{ title: "Broken", url: "", iconUrl: "" }])
        const rows = Logic.buildResults(context({ text: "broken", bookmarks: bookmarks }))
        compare(rows.filter(r => r.kind === "bookmark").length, 0)
    }

    function test_missingBookmarkModelIsTolerated() {
        const rows = Logic.buildResults(context({ text: "x", bookmarks: null }))
        compare(kinds(rows), ["go"])
    }

    function test_searchSuggestionsAreDeduplicated() {
        const suggestions = [
            { text: "weather", url: "", isBookmark: false },          // same as the query
            { text: "weather today", url: "", isBookmark: false },
            { text: "Weather Today", url: "", isBookmark: false },    // repeat in another case
            { text: "weather tomorrow", url: "", isBookmark: false }
        ]
        const rows = Logic.buildResults(context({ text: "weather", suggestions: suggestions }))
        compare(rows.filter(r => r.kind === "suggest").map(r => r.title), ["weather today", "weather tomorrow"])
    }

    function test_bookmarkSuggestionsBecomeBookmarkRows() {
        const suggestions = [
            { text: "Example", url: "https://example.com", isBookmark: true, iconUrl: "" },
            { text: "Settings", url: "chrome://settings", isBookmark: true, iconUrl: "" }
        ]
        const rows = Logic.buildResults(context({ text: "ex", suggestions: suggestions }))
        const bookmarkRows = rows.filter(r => r.kind === "bookmark")
        compare(bookmarkRows.length, 1)
        compare(bookmarkRows[0].url, "https://example.com")
    }

    function test_rowsNeverExceedTheLimit() {
        const items = [], suggestions = []
        for (let i = 0; i < 10; ++i) {
            items.push(tab("News " + i, "https://news" + i + ".example.com"))
            suggestions.push({ text: "news " + i, url: "", isBookmark: false })
        }
        const actions = [{ label: "News action", icon: "" }, { label: "News other", icon: "" }]
        for (const maxRows of [3, 5, 8]) {
            const rows = Logic.buildResults(context({
                text: "news", tabs: listOf(items), suggestions: suggestions, quickActions: actions, maxRows: maxRows
            }))
            verify(rows.length <= maxRows, "maxRows " + maxRows + " gave " + rows.length)
            compare(rows[0].kind, "go")
        }
    }

    function test_localResultsComeBeforeSuggestions() {
        const rows = Logic.buildResults(context({
            text: "git",
            tabs: listOf([tab("GitHub", "https://github.com")]),
            suggestions: [{ text: "git rebase", url: "", isBookmark: false }]
        }))
        compare(kinds(rows), ["go", "tab", "suggest"])
    }

    function test_evaluateMath_data() {
        return [
            { tag: "multiplication", text: "24 * 1024", result: "24576" },
            { tag: "thousands separator", text: "12,000 / 4", result: "3000" },
            { tag: "fraction", text: "12/25", result: "0.48" },
            { tag: "phone number", text: "555-1234", result: null },
            { tag: "long phone number", text: "555-123-4567", result: null },
            { tag: "date with slashes", text: "1/2/2026", result: null },
            { tag: "date with dashes", text: "2026-11-26", result: null },
            { tag: "decimal comma", text: "1,5*2", result: null }
        ]
    }
    function test_evaluateMath(data) {
        const calc = Logic.evaluateMath(data.text)
        compare(calc ? calc.result : null, data.result)
    }

    function test_inlineCalculation() {
        const rows = Logic.buildResults(context({ text: "24 * 1024" }))
        compare(rows[0].kind, "calc")
        compare(rows[0].title, "24576")
        compare(rows[0].subtitle, "= 24 * 1024 (Calculation)")
    }

    function test_searchBangs() {
        const rows = Logic.buildResults(context({ text: "!w quantum computing" }))
        compare(rows[0].kind, "go")
        compare(rows[0].subtitle, "Search Wikipedia (!w)")
        verify(rows[0].dest.includes("wikipedia.org"))
        verify(rows[0].dest.includes("quantum%20computing"))
    }

    function test_bangOptionsListOnExclamationMark() {
        const rows = Logic.buildResults(context({ text: "!" }))
        verify(rows.length >= 8)
        compare(rows[0].kind, "bang")

        const wRows = Logic.buildResults(context({ text: "!w" }))
        compare(wRows.length, 1)
        compare(wRows[0].kind, "bang")
        compare(wRows[0].dest, "!w ")
    }

    function test_commandPrefixMode() {
        const actions = [
            { label: "Toggle Sidebar", icon: "" },
            { label: "Close Tab", icon: "" }
        ]
        const rows = Logic.buildResults(context({ text: ">", quickActions: actions }))
        compare(rows.length, 2)
        compare(rows[0].kind, "action")
        compare(rows[1].kind, "action")
    }
}
