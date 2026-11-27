import QtQuick
import QtTest
import illuminate.ui

Item {
    id: root
    width: 400
    height: 300

    Component {
        id: gripsComponent
        ResizeGrips {
            width: 300
            height: 200
        }
    }

    SignalSpy {
        id: resizeSpy
        signalName: "requestSystemResize"
    }

    TestCase {
        name: "ResizeGripsTests"
        when: windowShown

        function test_componentExists() {
            let grips = createTemporaryObject(gripsComponent, root)
            verify(!!grips, "Component exists")
        }

        function test_gripDefaults() {
            let grips = createTemporaryObject(gripsComponent, root)
            verify(!!grips, "Component exists")
            compare(grips.edgeGrip, 6)
            compare(grips.cornerGrip, 10)
        }

        function test_gripWritable() {
            let grips = createTemporaryObject(gripsComponent, root)
            verify(!!grips, "Component exists")
            grips.edgeGrip = 8
            compare(grips.edgeGrip, 8)
        }

        function test_leftGripResize() {
            let grips = createTemporaryObject(gripsComponent, root)
            verify(!!grips, "Component exists")
            resizeSpy.target = grips
            resizeSpy.clear()
            let grip = findChild(grips, "leftGrip")
            verify(!!grip, "Object exists")
            mousePress(grip)
            tryCompare(resizeSpy, "count", 1)
            compare(resizeSpy.signalArguments[0][0], Qt.LeftEdge)
        }

        function test_rightGripResize() {
            let grips = createTemporaryObject(gripsComponent, root)
            verify(!!grips, "Component exists")
            resizeSpy.target = grips
            resizeSpy.clear()
            let grip = findChild(grips, "rightGrip")
            verify(!!grip, "Object exists")
            mousePress(grip)
            tryCompare(resizeSpy, "count", 1)
            compare(resizeSpy.signalArguments[0][0], Qt.RightEdge)
        }

        function test_bottomGripResize() {
            let grips = createTemporaryObject(gripsComponent, root)
            verify(!!grips, "Component exists")
            resizeSpy.target = grips
            resizeSpy.clear()
            let grip = findChild(grips, "bottomGrip")
            verify(!!grip, "Object exists")
            mousePress(grip)
            tryCompare(resizeSpy, "count", 1)
            compare(resizeSpy.signalArguments[0][0], Qt.BottomEdge)
        }

        function test_topLeftGripResize() {
            let grips = createTemporaryObject(gripsComponent, root)
            verify(!!grips, "Component exists")
            resizeSpy.target = grips
            resizeSpy.clear()
            let grip = findChild(grips, "topLeftGrip")
            verify(!!grip, "Object exists")
            mousePress(grip)
            tryCompare(resizeSpy, "count", 1)
            compare(resizeSpy.signalArguments[0][0], Qt.TopEdge | Qt.LeftEdge)
        }

        function test_topRightGripResize() {
            let grips = createTemporaryObject(gripsComponent, root)
            verify(!!grips, "Component exists")
            resizeSpy.target = grips
            resizeSpy.clear()
            let grip = findChild(grips, "topRightGrip")
            verify(!!grip, "Object exists")
            mousePress(grip)
            tryCompare(resizeSpy, "count", 1)
            compare(resizeSpy.signalArguments[0][0], Qt.TopEdge | Qt.RightEdge)
        }

        function test_bottomLeftGripResize() {
            let grips = createTemporaryObject(gripsComponent, root)
            verify(!!grips, "Component exists")
            resizeSpy.target = grips
            resizeSpy.clear()
            let grip = findChild(grips, "bottomLeftGrip")
            verify(!!grip, "Object exists")
            mousePress(grip)
            tryCompare(resizeSpy, "count", 1)
            compare(resizeSpy.signalArguments[0][0], Qt.BottomEdge | Qt.LeftEdge)
        }

        function test_bottomRightGripResize() {
            let grips = createTemporaryObject(gripsComponent, root)
            verify(!!grips, "Component exists")
            resizeSpy.target = grips
            resizeSpy.clear()
            let grip = findChild(grips, "bottomRightGrip")
            verify(!!grip, "Object exists")
            mousePress(grip)
            tryCompare(resizeSpy, "count", 1)
            compare(resizeSpy.signalArguments[0][0], Qt.BottomEdge | Qt.RightEdge)
        }
    }
}