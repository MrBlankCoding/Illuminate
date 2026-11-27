import QtQuick
import illuminate.ui

pragma ComponentBehavior: Bound

// Keeps each other space's last page running, hidden, so switching to a
// space shows that page at once instead of starting a browser and loading it.
//
// - Leaving a space parks its page here: the live browser moves out of the
//   tab (CefBrowserWrapper::adoptPage) before the tab is torn down.
// - Spaces not visited yet get their last page from their session file,
//   loaded in the background a moment after the app or a switch settles.
// - Arriving in a space, its active tab claims the page and takes it over.
//
// Parked pages are muted and their media paused; they sit at the content
// area's size so they're already laid out. At most maxPages are kept, the
// spaces next to the current one first, as those are a swipe away.
Item {
    id: root
    property var activeWebView: null
    property bool preloading: Prefs ? Prefs.preloadSpaces : false
    property int maxPages: 3
    property int preloadDelay: 1500
    property Component pageComponent: warmPageComponent

    // spaceId -> { view, url }
    property var pages: ({})
    // space ids, most recently left first
    property var recent: []

    visible: false

    readonly property string pauseMediaScript:
        "for (const m of document.querySelectorAll('video,audio')) { try { m.pause() } catch (e) {} }"

    function spaceIds() {
        return Object.keys(root.pages);
    }

    function hasPage(spaceId) {
        return root.pages[spaceId] !== undefined;
    }

    function remember(spaceId, entry) {
        const next = Object.assign({}, root.pages);
        next[spaceId] = entry;
        root.pages = next;
        root.recent = [spaceId].concat(root.recent.filter(id => id !== spaceId));
        root.trim(spaceId);
    }

    function drop(spaceId) {
        const entry = root.pages[spaceId];
        if (!entry)
            return;
        const next = Object.assign({}, root.pages);
        delete next[spaceId];
        root.pages = next;
        root.recent = root.recent.filter(id => id !== spaceId);
        entry.view.destroy();
    }

    function clear() {
        for (const id of root.spaceIds())
            root.drop(id);
    }

    // past the limit, the page left longest ago goes, never |keep|
    function trim(keep) {
        while (root.spaceIds().length > root.maxPages) {
            const oldest = root.recent.slice().reverse().find(id => id !== keep && root.hasPage(id));
            if (!oldest)
                return;
            root.drop(oldest);
        }
    }

    function park(spaceId, url, webView) {
        if (!root.preloading || !spaceId || !url || !webView || !webView.hasPage())
            return false;
        root.drop(spaceId);
        const view = root.pageComponent.createObject(root, { profile: webView.profile });
        if (!view)
            return false;
        if (!view.adoptPage(webView)) {
            view.destroy();
            return false;
        }
        view.runJavaScript(root.pauseMediaScript);
        root.remember(spaceId, { view: view, url: url });
        return true;
    }

    function preload(space) {
        if (!root.preloading || !space || root.hasPage(space.id))
            return false;
        const url = space.lastActiveUrl();
        if (!url)
            return false;
        const view = root.pageComponent.createObject(root, {
            profile: Browser.profileForSpace(space),
            url: url
        });
        if (!view)
            return false;
        root.remember(space.id, { view: view, url: url });
        return true;
    }

    function claim(spaceId, url) {
        const entry = root.pages[spaceId];
        if (!entry || entry.url !== url || !entry.view.hasPage())
            return null;
        const next = Object.assign({}, root.pages);
        delete next[spaceId];
        root.pages = next;
        root.recent = root.recent.filter(id => id !== spaceId);
        return entry.view;
    }

    // the other spaces, nearest to the current one first (a swipe away)
    function spacesByDistance() {
        const all = Spaces ? Spaces.spaces : [];
        const current = all.findIndex(space => Browser.space && space.id === Browser.space.id);
        if (current < 0)
            return all.slice();
        const others = [];
        for (let step = 1; step < all.length; ++step) {
            for (const index of [current + step, current - step]) {
                const space = all[(index % all.length + all.length) % all.length];
                if (space && space.id !== Browser.space.id && !others.includes(space))
                    others.push(space);
            }
        }
        return others;
    }

    function preloadOthers() {
        if (!root.preloading)
            return;
        for (const space of root.spacesByDistance()) {
            if (root.spaceIds().length >= root.maxPages)
                break;
            root.preload(space);
        }
    }

    // spaces deleted since: their pages go too
    function prune() {
        const alive = (Spaces ? Spaces.spaces : []).map(space => space.id);
        for (const id of root.spaceIds())
            if (!alive.includes(id))
                root.drop(id);
    }

    Timer {
        id: preloadTimer
        interval: root.preloadDelay
        onTriggered: root.preloadOthers()
    }

    Component.onCompleted: preloadTimer.restart()
    Component.onDestruction: root.clear()

    Connections {
        target: Browser
        function onSpaceAboutToChange() {
            if (Browser.space)
                root.park(Browser.space.id, Browser.activeUrl, root.activeWebView);
        }
        function onSpaceChanged() {
            preloadTimer.stop();
            Qt.callLater(() => {
                // whatever the new space's tab didn't take is stale now
                if (Browser.space)
                    root.drop(Browser.space.id);
                preloadTimer.restart();
            });
        }
    }

    Connections {
        target: Spaces
        ignoreUnknownSignals: true
        function onSpacesChanged() {
            root.prune();
        }
    }

    Connections {
        target: Prefs
        ignoreUnknownSignals: true
        function onPreloadSpacesChanged() {
            if (Prefs.preloadSpaces)
                preloadTimer.restart();
            else
                root.clear();
        }
    }

    Component {
        id: warmPageComponent
        CefBrowser {
            anchors.fill: parent
            // never heard from the background; the tab sets its own on adoption
            audioMuted: true
            backgroundColor: Theme.bg
            cornerRadius: 0
            onLoadingChanged: {
                if (!loading)
                    runJavaScript(root.pauseMediaScript);
            }
        }
    }
}
