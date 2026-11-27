import QtQuick
import QtTest
import illuminate.ui

Item {
    id: root
    width: 800
    height: 600

    Component {
        id: testedComponent
        KeyboardShortcuts {}
    }

    TestCase {
        name: "KeyboardShortcutsTests"
        when: windowShown

        function test_componentLoads() {
            compare(testedComponent.status, Component.Ready)
        }
    }
}
