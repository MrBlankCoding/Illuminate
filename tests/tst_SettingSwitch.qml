import QtQuick
import QtTest
import illuminate.ui

Item {
    id: root
    width: 800
    height: 600

    Component {
        id: switchComponent
        SettingSwitch {}
    }

    SignalSpy {
        id: toggledSpy
        signalName: "toggled"
    }

    TestCase {
        name: "SettingSwitchTests"
        when: windowShown

        function init() {
            toggledSpy.clear()
        }

        function test_componentLoads() {
            compare(switchComponent.status, Component.Ready)
        }

        function test_startsOffAtItsNaturalSize() {
            const control = createTemporaryObject(switchComponent, root)
            verify(!control.checked)
            compare(control.width, 40)
            compare(control.height, 24)
        }

        function test_clickAsksToToggle() {
            const control = createTemporaryObject(switchComponent, root)
            toggledSpy.target = control
            mouseClick(control)
            tryCompare(toggledSpy, "count", 1)
        }

        // the caller owns the value: a click alone must not flip it
        function test_clickLeavesTheValueToTheCaller() {
            const control = createTemporaryObject(switchComponent, root, { checked: true })
            toggledSpy.target = control
            mouseClick(control)
            tryCompare(toggledSpy, "count", 1)
            verify(control.checked)
        }

        function test_repeatedClicksEachAsk() {
            const control = createTemporaryObject(switchComponent, root)
            toggledSpy.target = control
            for (let i = 0; i < 3; ++i) {
                mouseClick(control)
                // past the double-tap window, so each is its own tap
                wait(Qt.styleHints.mouseDoubleClickInterval + 20)
            }
            tryCompare(toggledSpy, "count", 3)
        }
    }
}
