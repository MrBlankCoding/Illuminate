import QtQuick
import QtTest
import illuminate.ui

Item {
    id: root
    width: 800
    height: 600

    // a stand-in for CefBrowser: holds a "page" that can move between views
    Component {
        id: fakePage
        Item {
            property var profile: null
            property string url: ""
            property bool live: true
            property var scripts: []
            function hasPage() { return live }
            function adoptPage(donor) {
                if (!donor || donor === this || !donor.hasPage())
                    return false
                live = true
                url = donor.url
                donor.live = false
                return true
            }
            function runJavaScript(script) { scripts = scripts.concat([script]) }
        }
    }

    Component {
        id: poolComponent
        WarmSpaces {
            pageComponent: fakePage
            preloadDelay: 60000 // nothing loads behind the test's back
        }
    }

    TestCase {
        name: "WarmSpacesTests"
        when: windowShown

        function makePool() {
            const pool = createTemporaryObject(poolComponent, root)
            verify(pool)
            return pool
        }

        function tabView(url) {
            return createTemporaryObject(fakePage, root, { url: url })
        }

        function test_componentLoads() {
            compare(poolComponent.status, Component.Ready)
        }

        // leaving a space: the page moves out of its tab before the tab goes
        function test_leavingASpaceParksItsPage() {
            const pool = makePool()
            const tab = tabView("https://docs.example/draft")
            verify(pool.park("work", "https://docs.example/draft", tab))
            verify(!tab.hasPage(), "the tab gave its page up")
            compare(pool.spaceIds(), ["work"])
            const parked = pool.pages["work"].view
            verify(parked.hasPage())
            // whatever was playing is paused
            compare(parked.scripts, [pool.pauseMediaScript])
        }

        // arriving: the space's tab takes over the waiting page
        function test_arrivingClaimsThePage() {
            const pool = makePool()
            pool.park("work", "https://docs.example/draft", tabView("https://docs.example/draft"))
            const page = pool.claim("work", "https://docs.example/draft")
            verify(page)
            verify(page.hasPage())
            compare(pool.spaceIds(), [])
            const tab = tabView("")
            verify(tab.adoptPage(page))
            compare(tab.url, "https://docs.example/draft")
        }

        function test_aDifferentPageIsNotClaimed() {
            const pool = makePool()
            pool.park("work", "https://docs.example/draft", tabView("https://docs.example/draft"))
            compare(pool.claim("work", "https://other.example"), null)
            compare(pool.claim("play", "https://docs.example/draft"), null)
            compare(pool.spaceIds(), ["work"])
        }

        function test_aPageThatDiedIsNotClaimed() {
            const pool = makePool()
            pool.park("work", "https://docs.example/draft", tabView("https://docs.example/draft"))
            pool.pages["work"].view.live = false // its browser closed meanwhile
            compare(pool.claim("work", "https://docs.example/draft"), null)
        }

        function test_nothingToParkWithoutALivePage() {
            const pool = makePool()
            const dead = tabView("https://x.example")
            dead.live = false
            verify(!pool.park("work", "https://x.example", dead))
            verify(!pool.park("work", "https://x.example", null))
            verify(!pool.park("", "https://x.example", tabView("https://x.example")))
            verify(!pool.park("work", "", tabView("https://x.example")))
            compare(pool.spaceIds(), [])
        }

        function test_leavingAgainReplacesTheSpacesPage() {
            const pool = makePool()
            pool.park("work", "https://a.example", tabView("https://a.example"))
            const first = pool.pages["work"].view
            pool.park("work", "https://b.example", tabView("https://b.example"))
            compare(pool.spaceIds(), ["work"])
            compare(pool.pages["work"].url, "https://b.example")
            verify(pool.pages["work"].view !== first)
        }

        // the space left longest ago gives its page up first
        function test_atMostMaxPagesAreKept() {
            const pool = makePool()
            pool.maxPages = 2
            pool.park("a", "https://a.example", tabView("https://a.example"))
            pool.park("b", "https://b.example", tabView("https://b.example"))
            pool.park("c", "https://c.example", tabView("https://c.example"))
            compare(pool.spaceIds().sort(), ["b", "c"])
            // b was used again: now a later park drops c's
            pool.park("b", "https://b2.example", tabView("https://b2.example"))
            pool.park("d", "https://d.example", tabView("https://d.example"))
            compare(pool.spaceIds().sort(), ["b", "d"])
        }

        function test_turningItOffLetsEveryPageGo() {
            const pool = makePool()
            pool.park("a", "https://a.example", tabView("https://a.example"))
            pool.preloading = false
            pool.clear()
            compare(pool.spaceIds(), [])
            verify(!pool.park("b", "https://b.example", tabView("https://b.example")))
        }

        // a space not visited yet loads its last page in the background
        function test_aSpaceIsPreloadedFromItsSession() {
            Browser.newTab("https://preload.example/start")
            Browser.saveSession()
            const pool = makePool()
            verify(pool.preload(Browser.space))
            compare(pool.pages[Browser.space.id].url, "https://preload.example/start")
            compare(pool.pages[Browser.space.id].view.url, "https://preload.example/start")
            compare(pool.pages[Browser.space.id].view.profile, Browser.webProfile)
            // once is enough
            verify(!pool.preload(Browser.space))
            pool.clear()
            Browser.closeTab(Browser.tabModel.activeIndex)
        }

        function test_nothingToPreloadWithoutASpace() {
            const pool = makePool()
            verify(!pool.preload(null))
        }

        // switching away parks the page in front, with the address it was at
        function test_aSpaceSwitchParksTheActivePage() {
            Browser.newTab("https://switch.example/page")
            const pool = makePool()
            const tab = tabView("https://switch.example/page")
            pool.activeWebView = tab
            Browser.spaceAboutToChange()
            verify(pool.hasPage(Browser.space.id))
            compare(pool.pages[Browser.space.id].url, "https://switch.example/page")
            verify(!tab.hasPage())
            pool.clear()
            Browser.closeTab(Browser.tabModel.activeIndex)
        }

        // the space just arrived in never keeps a page it didn't take
        function test_anUnclaimedPageForTheCurrentSpaceIsDropped() {
            const pool = makePool()
            pool.park(Browser.space.id, "https://stale.example", tabView("https://stale.example"))
            Browser.spaceChanged()
            tryVerify(() => !pool.hasPage(Browser.space.id))
        }
    }
}
