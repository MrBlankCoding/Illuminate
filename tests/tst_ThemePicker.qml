import QtQuick
import QtQuick.Controls.Basic
import QtTest
import illuminate.ui

Item {
    id: root
    width: 800
    height: 600

    Component {
        id: testedComponent
        ThemePicker {}
    }

    // stands in for BrowserWindow: the focus claims and the page taking focus back
    QtObject {
        id: fakeWindow
        property var claims: []
        signal focusReturnedToWeb()
        function claimUiFocus(owner) { claims = claims.concat([owner]) }
        function releaseUiFocus(owner) { claims = claims.filter(c => c !== owner) }
    }

    TestCase {
        name: "ThemePickerTests"
        when: windowShown

        SignalSpy {
            id: themeColorSpy
            target: Browser
            signalName: "themeColorChanged"
        }

        function cleanup() {
            Browser.resetThemeColor()
            themeColorSpy.clear()
        }

        function test_componentLoads() {
            compare(testedComponent.status, Component.Ready)
        }

        function test_usesInWindowPopupOnWindows() {
            if (Qt.platform.os !== "windows")
                return
            const picker = createTemporaryObject(testedComponent, root)
            verify(picker)
            compare(picker.popupType, Popup.Item)
        }

        function test_draggingWheelUpdatesTheTheme() {
            const picker = createTemporaryObject(testedComponent, root)
            verify(picker)
            picker.open()
            tryCompare(picker, "opened", true)
            const wheel = findChild(picker, "themePickerWheel")
            verify(wheel)

            Browser.resetThemeColor()
            mousePress(wheel, wheel.width / 2, wheel.height / 2)
            mouseMove(wheel, wheel.width - 6, wheel.height / 2, 20)
            mouseRelease(wheel, wheel.width - 6, wheel.height / 2)
            tryVerify(() => Browser.themeColor.valid && Browser.themeColor.hslSaturation > 0.75)
        }

        function test_previewIsSavedWhenThePickerCloses() {
            const picker = createTemporaryObject(testedComponent, root)
            verify(picker)
            picker.open()
            tryCompare(picker, "opened", true)
            picker.pickAt(200, 106)
            verify(picker.previewing)
            verify(Theme.hasCustomSeed)
            picker.close()
            tryCompare(picker, "visible", false)
            verify(!picker.previewing)
            verify(Theme.hasCustomSeed)
        }

        // a click in the page never reaches Qt; the window says focus went back to it
        function test_clickingIntoThePageClosesThePicker() {
            const picker = createTemporaryObject(testedComponent, root, { focusRouter: fakeWindow })
            picker.open()
            tryCompare(picker, "opened", true)
            compare(fakeWindow.claims, ["themePicker"])

            fakeWindow.focusReturnedToWeb()
            tryCompare(picker, "visible", false)
            compare(fakeWindow.claims, [])
        }

        function test_aColourBeingPreviewedIsKeptWhenThePageTakesFocus() {
            const picker = createTemporaryObject(testedComponent, root, { focusRouter: fakeWindow })
            picker.open()
            tryCompare(picker, "opened", true)
            picker.pickAt(200, 106)
            fakeWindow.focusReturnedToWeb()
            tryCompare(picker, "visible", false)
            verify(!picker.previewing)
            verify(Theme.hasCustomSeed)
        }

        // detents around the wheel and a settle into the grey centre
        function test_theWheelTracksDetentsAndTheCentre() {
            const picker = createTemporaryObject(testedComponent, root)
            picker.feelAt(0.01, 0.9)
            compare(picker.lastDetent, 0)
            picker.feelAt(0.09, 0.9)
            compare(picker.lastDetent, 1)
            verify(!picker.inCentre)
            picker.feelAt(0.09, 0.02)
            verify(picker.inCentre)
            picker.feelAt(0.99, 0.9)
            compare(picker.lastDetent, 11)
            verify(!picker.inCentre)
        }

        function test_rapidPointerSamplesAreCoalesced() {
            Browser.resetThemeColor()
            themeColorSpy.clear()
            const picker = createTemporaryObject(testedComponent, root)
            picker.queuePickAt(106, 0)
            picker.queuePickAt(212, 106)
            tryCompare(themeColorSpy, "count", 1)
            compare(Browser.themeColor, picker.seedAt(0, 1))
        }

        function test_aClosedPickerIgnoresThePage() {
            const picker = createTemporaryObject(testedComponent, root, { focusRouter: fakeWindow })
            fakeWindow.focusReturnedToWeb()
            verify(!picker.visible)
            compare(fakeWindow.claims, [])
        }
    }
}
