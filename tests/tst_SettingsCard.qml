import QtQuick
import QtTest
import illuminate.ui

Item {
    id: root
    width: 800
    height: 600

    Component {
        id: testedComponent
        SettingsCard {}
    }

    TestCase {
        name: "SettingsCardTests"
        when: windowShown

        function test_componentLoads() {
            compare(testedComponent.status, Component.Ready)
        }
    }
}
