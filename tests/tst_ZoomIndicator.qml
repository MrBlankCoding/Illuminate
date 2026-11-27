import QtQuick
import QtTest
import illuminate.ui

Item {
    id: root
    width: 300
    height: 120

    Component {
        id: zoomIndicatorComponent
        ZoomIndicator {}
    }

    // stands in for CefBrowser: a plain JS object wouldn't notify the
    // zoomPercent binding when zoomFactor changes
    Component {
        id: webViewStubComponent
        QtObject {
            property real zoomFactor: 1.0
        }
    }

    TestCase {
        name: "ZoomIndicatorTests"
        when: windowShown

        function makeWebView(zoomFactor) {
            return createTemporaryObject(webViewStubComponent, root, { zoomFactor: zoomFactor })
        }

        function test_componentExists() {
            let indicator = createTemporaryObject(zoomIndicatorComponent, root)
            verify(!!indicator, "Component exists")
        }

        function test_noWebViewDefaults() {
            let indicator = createTemporaryObject(zoomIndicatorComponent, root)
            verify(!!indicator, "Component exists")
            compare(indicator.zoomPercent, 100)
            compare(indicator.visible, false)
        }

        function test_zoomBounds() {
            let indicator = createTemporaryObject(zoomIndicatorComponent, root)
            verify(!!indicator, "Component exists")
            compare(indicator.minZoom, 0.25)
            compare(indicator.maxZoom, 5.0)
        }

        function test_zoomPercentReflectsWebView() {
            let indicator = createTemporaryObject(zoomIndicatorComponent, root)
            verify(!!indicator, "Component exists")
            indicator.webView = makeWebView(1.5)
            tryCompare(indicator, "zoomPercent", 150)
            tryCompare(indicator, "visible", true)
        }

        function test_zoomByIncrements() {
            let indicator = createTemporaryObject(zoomIndicatorComponent, root)
            verify(!!indicator, "Component exists")
            indicator.webView = makeWebView(1.0)
            indicator.zoomBy(0.1)
            tryCompare(indicator, "zoomPercent", 110)
        }

        function test_zoomByClampsMax() {
            let indicator = createTemporaryObject(zoomIndicatorComponent, root)
            verify(!!indicator, "Component exists")
            indicator.webView = makeWebView(4.9)
            indicator.zoomBy(0.2)
            tryCompare(indicator, "zoomPercent", 500)
        }

        function test_zoomByClampsMin() {
            let indicator = createTemporaryObject(zoomIndicatorComponent, root)
            verify(!!indicator, "Component exists")
            indicator.webView = makeWebView(0.3)
            indicator.zoomBy(-0.1)
            tryCompare(indicator, "zoomPercent", 25)
        }

        function test_zoomReset() {
            let indicator = createTemporaryObject(zoomIndicatorComponent, root)
            verify(!!indicator, "Component exists")
            indicator.webView = makeWebView(1.8)
            indicator.zoomReset()
            tryCompare(indicator, "zoomPercent", 100)
        }

        function test_zoomInTap() {
            let indicator = createTemporaryObject(zoomIndicatorComponent, root)
            verify(!!indicator, "Component exists")
            indicator.webView = makeWebView(1.5)
            let button = findChild(indicator, "zoomInButton")
            verify(!!button, "Object exists")
            mouseClick(button)
            tryCompare(indicator, "zoomPercent", 160)
        }

        function test_zoomOutTap() {
            let indicator = createTemporaryObject(zoomIndicatorComponent, root)
            verify(!!indicator, "Component exists")
            indicator.webView = makeWebView(1.5)
            let button = findChild(indicator, "zoomOutButton")
            verify(!!button, "Object exists")
            mouseClick(button)
            tryCompare(indicator, "zoomPercent", 140)
        }
    }
}