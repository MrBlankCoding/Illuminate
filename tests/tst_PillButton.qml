import QtQuick
import QtTest
import illuminate.ui

Item {
    id: root
    width: 400
    height: 200

    Component {
        id: pillButtonComponent
        PillButton {
            width: 120
            height: 40
        }
    }

    SignalSpy {
        id: clickedSpy
        signalName: "clicked"
    }

    TestCase {
        name: "PillButtonTests"
        when: windowShown

        function test_componentExists() {
            let pill = createTemporaryObject(pillButtonComponent, root)
            verify(!!pill, "Component exists")
        }

        function test_defaultText() {
            let pill = createTemporaryObject(pillButtonComponent, root)
            verify(!!pill, "Component exists")
            compare(pill.text, qsTr(""))
        }

        function test_textWritable() {
            let pill = createTemporaryObject(pillButtonComponent, root)
            verify(!!pill, "Component exists")
            pill.text = qsTr("Search")
            compare(pill.text, qsTr("Search"))
        }

        function test_colorRoundTrip() {
            let pill = createTemporaryObject(pillButtonComponent, root)
            verify(!!pill, "Component exists")
            pill.fillColor = '#ff0000'
            compare(pill.fillColor.toString(), '#ff0000')
            pill.hoverFillColor = '#00ff00'
            compare(pill.hoverFillColor.toString(), '#00ff00')
            pill.textColor = '#0000ff'
            compare(pill.textColor.toString(), '#0000ff')
            pill.borderColor = '#ffff00'
            compare(pill.borderColor.toString(), '#ffff00')
        }

        function test_paddingDefaults() {
            let pill = createTemporaryObject(pillButtonComponent, root)
            verify(!!pill, "Component exists")
            compare(pill.leftPadding, 20)
            compare(pill.rightPadding, 20)
            compare(pill.topPadding, 8)
            compare(pill.bottomPadding, 8)
        }

        function test_clicked() {
            let pill = createTemporaryObject(pillButtonComponent, root)
            verify(!!pill, "Component exists")
            clickedSpy.target = pill
            clickedSpy.clear()
            mouseClick(pill, pill.width / 2, pill.height / 2)
            tryCompare(clickedSpy, "count", 1)
        }

        function test_pressedWhilePressed() {
            let pill = createTemporaryObject(pillButtonComponent, root)
            verify(!!pill, "Component exists")
            mousePress(pill, pill.width / 2, pill.height / 2)
            tryCompare(pill, "pressed", true)
            mouseRelease(pill, pill.width / 2, pill.height / 2)
            tryCompare(pill, "pressed", false)
        }

        function test_hovered() {
            let pill = createTemporaryObject(pillButtonComponent, root)
            verify(!!pill, "Component exists")
            mouseMove(pill, pill.width / 2, pill.height / 2)
            tryCompare(pill, "hovered", true)
        }
    }
}