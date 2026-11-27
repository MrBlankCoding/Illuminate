import QtQuick
import QtTest
import illuminate.ui

Item {
    id: root
    width: 800
    height: 600

    Component {
        id: avatarComponent
        LetterAvatar {
            width: 16
            height: 16
        }
    }

    TestCase {
        name: "LetterAvatarComponentTests"
        when: windowShown

        function make(props) {
            const avatar = createTemporaryObject(avatarComponent, root, props)
            verify(!!avatar)
            return avatar
        }

        function test_componentLoads() {
            compare(avatarComponent.status, Component.Ready)
        }

        function test_host_data() {
            return [
                { tag: "plain", url: "https://example.com", host: "example.com", letter: "E" },
                { tag: "www is dropped", url: "https://www.github.com/x", host: "github.com", letter: "G" },
                { tag: "port is dropped", url: "http://localhost:8080/app", host: "localhost", letter: "L" },
                { tag: "subdomain is kept", url: "https://docs.qt.io", host: "docs.qt.io", letter: "D" },
                { tag: "query is dropped", url: "https://news.ycombinator.com?id=1", host: "news.ycombinator.com", letter: "N" },
                { tag: "uppercase scheme", url: "HTTPS://Example.com", host: "Example.com", letter: "E" }
            ]
        }
        function test_host(data) {
            const avatar = make({ url: data.url })
            compare(avatar.host, data.host)
            compare(avatar.letter, data.letter)
        }

        function test_titleIsTheFallback() {
            compare(make({ url: "", title: "memory" }).letter, "M")
            compare(make({ url: "not a url", title: "notes" }).letter, "N")
        }

        function test_questionMarkWhenThereIsNothingToGoOn() {
            compare(make({ url: "", title: "" }).letter, "?")
        }

        function test_internalPagesShowTheGlobe() {
            for (const url of ["chrome://settings", "newtab://newtab", "illuminate://memory", "CHROME://history"])
                verify(make({ url: url }).genericGlobe, url)
            verify(!make({ url: "https://example.com" }).genericGlobe)
        }

        function test_colourDependsOnlyOnTheSite() {
            const a = make({ url: "https://example.com/a" })
            const b = make({ url: "https://www.example.com/b?x=1" })
            const c = make({ url: "https://other.org" })
            verify(Qt.colorEqual(a.color, b.color))
            verify(!Qt.colorEqual(a.color, c.color))
        }

        function test_hueIsStableAndInRange() {
            const avatar = make({})
            for (const s of ["", "a", "example.com", "a much longer host name than usual.example.org"]) {
                const h = avatar.hue(s)
                verify(h >= 0 && h < 1, s + " -> " + h)
                compare(avatar.hue(s), h)
            }
        }
    }
}
