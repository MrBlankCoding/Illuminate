import QtQuick
import QtTest
import illuminate.ui

Item {
    id: root
    width: 800
    height: 600

    readonly property var options: [
        { name: "Compact", value: "compact" },
        { name: "Normal", value: "normal" },
        { name: "Cosy", value: "cosy" }
    ]

    Component {
        id: segmentedComponent
        SettingSegmented {
            x: 20
            y: 20
            model: root.options
        }
    }

    SignalSpy {
        id: activatedSpy
        signalName: "activated"
    }

    TestCase {
        name: "SettingSegmentedTests"
        when: windowShown

        function make(value) {
            const control = createTemporaryObject(segmentedComponent, root, { value: value })
            activatedSpy.target = control
            activatedSpy.clear()
            return control
        }

        function test_componentLoads() {
            compare(segmentedComponent.status, Component.Ready)
        }

        function test_thePickedOptionIsHighlighted() {
            const control = make("normal")
            compare(control.currentIndex, 1)
            const highlight = findChild(control, "segmentHighlight")
            const normal = findChild(control, "segment_normal")
            tryCompare(highlight, "width", normal.width)
            verify(highlight.visible)
        }

        function test_clickingAnOptionAsksForIt() {
            const control = make("compact")
            mouseClick(findChild(control, "segment_cosy"))
            compare(activatedSpy.count, 1)
            compare(activatedSpy.signalArguments[0][0], "cosy")
            // the caller owns the value
            compare(control.value, "compact")
        }

        function test_clickingThePickedOptionDoesNothing() {
            const control = make("normal")
            mouseClick(findChild(control, "segment_normal"))
            compare(activatedSpy.count, 0)
        }

        function test_arrowKeysStepThroughTheOptions() {
            const control = make("normal")
            control.forceActiveFocus()
            keyClick(Qt.Key_Right)
            compare(activatedSpy.signalArguments[0][0], "cosy")
            keyClick(Qt.Key_Left)
            compare(activatedSpy.signalArguments[1][0], "compact")
        }

        function test_arrowKeysStopAtTheEnds() {
            const control = make("cosy")
            control.forceActiveFocus()
            keyClick(Qt.Key_Right)
            compare(activatedSpy.count, 0)
        }

        function test_anUnknownValueHighlightsNothing() {
            const control = make("enormous")
            compare(control.currentIndex, -1)
            verify(!findChild(control, "segmentHighlight").visible)
        }
    }
}
