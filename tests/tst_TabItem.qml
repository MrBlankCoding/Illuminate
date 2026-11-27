import QtQuick
import QtTest
import illuminate.ui

Item {
    id: root
    width: 400
    height: 120

    Component {
        id: tabItemComponent
        TabItem {
            width: 200
            height: 34
            // required; null model means the "New Tab" defaults
            model: null
            index: 0
        }
    }

    SignalSpy {
        id: activatedSpy
        signalName: "activated"
    }

    SignalSpy {
        id: closeClickedSpy
        signalName: "closeClicked"
    }

    SignalSpy {
        id: muteSpy
        signalName: "muteToggled"
    }

    TestCase {
        name: "TabItemTests"
        when: windowShown

        function test_componentExists() {
            let tab = createTemporaryObject(tabItemComponent, root)
            verify(!!tab, "Component exists")
        }

        function test_defaults() {
            let tab = createTemporaryObject(tabItemComponent, root)
            verify(!!tab, "Component exists")
            compare(tab.tabTitle, qsTr("New Tab"))
            compare(tab.tabIconUrl, "")
            compare(tab.tabLoading, false)
            compare(tab.isActive, false)
            compare(tab.tabInFolder, false)
        }

        function test_blankTabIsHidden() {
            let tab = createTemporaryObject(tabItemComponent, root, {
                model: { title: "New Tab", url: "newtab://newtab", iconUrl: "", loading: false, suspended: false }
            })
            verify(!!tab, "Component exists")
            compare(tab.tabUrl, "newtab://newtab")
            compare(tab.visible, false)
        }

        function test_titleReflectsModel() {
            let tab = createTemporaryObject(tabItemComponent, root, {
                model: { title: "GitHub", url: "https://github.com", iconUrl: "https://github.com/favicon.ico", loading: true, suspended: false }
            })
            verify(!!tab, "Component exists")
            compare(tab.tabTitle, qsTr("GitHub"))
            compare(tab.tabIconUrl, qsTr("https://github.com/favicon.ico"))
            compare(tab.tabLoading, true)
        }

        function test_chromeIconUrlDoesNotAttemptImageLoad() {
            let tab = createTemporaryObject(tabItemComponent, root, {
                model: { title: "Settings", url: "chrome://settings", iconUrl: "chrome://theme/IDR_SETTINGS_FAVICON", loading: false, suspended: false }
            })
            verify(!!tab, "Component exists")
            compare(tab.tabTitle, qsTr("Settings"))
            let faviconBox = findChild(tab, "faviconBox")
            verify(!!faviconBox, "faviconBox exists")
            compare(faviconBox.showFavicon, false)
        }

        function test_isActiveToggles() {
            let tab = createTemporaryObject(tabItemComponent, root)
            verify(!!tab, "Component exists")
            tab.isActive = true
            compare(tab.isActive, true)
        }

        function test_activated() {
            let tab = createTemporaryObject(tabItemComponent, root)
            verify(!!tab, "Component exists")
            activatedSpy.target = tab
            activatedSpy.clear()
            mouseClick(tab, tab.width / 2, tab.height / 2)
            tryCompare(activatedSpy, "count", 1)
        }

        function test_closeClicked() {
            let tab = createTemporaryObject(tabItemComponent, root)
            verify(!!tab, "Component exists")
            closeClickedSpy.target = tab
            closeClickedSpy.clear()
            let closeButton = findChild(tab, "closeButton")
            verify(!!closeButton, "Object exists")
            // hidden until the row is hovered
            compare(closeButton.opacity, 0)
            mouseMove(tab, tab.width / 2, tab.height / 2)
            tryCompare(closeButton, "opacity", 1)
            mouseClick(closeButton, closeButton.width / 2, closeButton.height / 2)
            tryCompare(closeClickedSpy, "count", 1)
        }

        function test_closeDoesNotActivate() {
            let tab = createTemporaryObject(tabItemComponent, root)
            verify(!!tab, "Component exists")
            activatedSpy.target = tab
            activatedSpy.clear()
            let closeButton = findChild(tab, "closeButton")
            mouseMove(tab, tab.width / 2, tab.height / 2)
            tryCompare(closeButton, "opacity", 1)
            mouseClick(closeButton, closeButton.width / 2, closeButton.height / 2)
            wait(50)
            compare(activatedSpy.count, 0)
        }

        function tabWith(extra) {
            return createTemporaryObject(tabItemComponent, root, {
                model: Object.assign({ title: "Music", url: "https://music.example", iconUrl: "",
                                       loading: false, suspended: false }, extra)
            })
        }

        function test_quietTabsHaveNoSpeaker() {
            const tab = tabWith({})
            verify(!findChild(tab, "muteButton").visible)
        }

        // a steady icon, not a pulsing one, and it eases in and out
        function test_theSpeakerHoldsStillAndFadesAway() {
            const tab = tabWith({ audible: true })
            const speaker = findChild(tab, "muteButton")
            const icon = speaker.children[0]
            wait(400)
            compare(icon.opacity, 1)
            tab.model = Object.assign({}, tab.model, { audible: false })
            verify(speaker.visible) // still fading out
            tryCompare(speaker, "visible", false)
        }

        function test_aTabPlayingSoundShowsASpeaker() {
            const tab = tabWith({ audible: true })
            const speaker = findChild(tab, "muteButton")
            verify(speaker.visible)
            compare(speaker.Accessible.name, "Mute tab")
        }

        function test_aMutedTabSaysSoEvenWhenQuiet() {
            const tab = tabWith({ muted: true })
            const speaker = findChild(tab, "muteButton")
            verify(speaker.visible)
            compare(speaker.Accessible.name, "Unmute tab")
        }

        function test_clickingTheSpeakerMutesWithoutSwitchingTabs() {
            const tab = tabWith({ audible: true })
            muteSpy.target = tab
            muteSpy.clear()
            activatedSpy.target = tab
            activatedSpy.clear()
            const speaker = findChild(tab, "muteButton")
            mouseClick(speaker, speaker.width / 2, speaker.height / 2)
            tryCompare(muteSpy, "count", 1)
            wait(50)
            compare(activatedSpy.count, 0)
        }

        function test_backgroundActivityShowsADot() {
            const tab = tabWith({ hasActivity: true })
            const dot = findChild(tab, "activityDot")
            tryCompare(dot, "scale", 1)
            verify(dot.visible)
            // the tab in front never shows one
            tab.isActive = true
            tryCompare(dot, "visible", false)
        }

        function test_noActivityNoDot() {
            const tab = tabWith({})
            verify(!findChild(tab, "activityDot").visible)
        }

        function test_middleClickCloses() {
            let tab = createTemporaryObject(tabItemComponent, root)
            verify(!!tab, "Component exists")
            closeClickedSpy.target = tab
            closeClickedSpy.clear()
            mouseClick(tab, 20, tab.height / 2, Qt.MiddleButton)
            tryCompare(closeClickedSpy, "count", 1)
        }
    }

    Component {
        id: avatarComponent
        LetterAvatar {
            width: 16
            height: 16
        }
    }

    TestCase {
        name: "LetterAvatarTests"
        when: windowShown

        function test_letterFromHost() {
            let avatar = createTemporaryObject(avatarComponent, root, { url: "https://www.github.com/x" })
            compare(avatar.host, "github.com")
            compare(avatar.letter, "G")
        }

        function test_letterFallsBackToTitle() {
            let avatar = createTemporaryObject(avatarComponent, root, { url: "", title: "memory" })
            compare(avatar.letter, "M")
        }

        function test_colourIsStablePerHost() {
            let a = createTemporaryObject(avatarComponent, root, { url: "https://example.com/a" })
            let b = createTemporaryObject(avatarComponent, root, { url: "https://example.com/b" })
            let c = createTemporaryObject(avatarComponent, root, { url: "https://other.org" })
            // colours are value types: compare what they are, not the wrappers
            verify(Qt.colorEqual(a.color, b.color), "same host, same colour")
            verify(!Qt.colorEqual(a.color, c.color), "different hosts, different colours")
        }
    }
}
