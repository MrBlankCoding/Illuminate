import QtQuick
import QtTest
import illuminate.ui

Item {
    id: root
    width: 800
    height: 600

    Component {
        id: menuComponent
        ExtensionsMenu {}
    }

    Component {
        id: buttonComponent
        ExtensionsButton {}
    }

    Component {
        id: popupComponent
        ExtensionActionPopup {}
    }

    TestCase {
        name: "ExtensionsMenuTests"
        when: windowShown

        function test_componentsLoad() {
            compare(menuComponent.status, Component.Ready)
            compare(buttonComponent.status, Component.Ready)
            compare(popupComponent.status, Component.Ready)
        }

        function test_menuIsEmptyWithoutEngine() {
            const menu = createTemporaryObject(menuComponent, root)
            verify(menu)
            compare(menu.extensions.length, 0)
        }

        function test_buttonWithoutWindowDoesNothing() {
            const button = createTemporaryObject(buttonComponent, root)
            verify(button)
            button.clicked()
            verify(!button.active)
        }

        function test_buttonOnlyShowsWhereExtensionsRun() {
            const button = createTemporaryObject(buttonComponent, root)
            verify(button)
            const pages = {
                "https://example.com/a": true,
                "http://localhost:8080/": true,
                "": false,
                "newtab://newtab": false,
                "illuminate://memory": false,
                "chrome://extensions/": false,
                "chrome-extension://abc/popup.html": false,
                "file:///Users/me/a.html": false,
                "https://chromewebstore.google.com/detail/x": false,
                "https://chrome.google.com/webstore/detail/x": false,
                "https://chrome.google.com/search": true
            }
            for (const url in pages) {
                button.pageUrl = url
                compare(button.available, pages[url], url)
                compare(button.visible, pages[url], url)
            }
        }

        function test_popupStartsHiddenAndDismissResets() {
            const popup = createTemporaryObject(popupComponent, root)
            verify(popup)
            verify(!popup.visible)
            popup.contentSize = Qt.size(200, 100)
            popup.dismiss()
            verify(!popup.sized)
            compare(popup.extension, null)
        }
    }
}
