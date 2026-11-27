import QtQuick
import QtTest
import illuminate.ui

Item {
    id: root
    width: 800
    height: 600

    Component {
        id: testedComponent
        SearchSettingsPage {}
    }

    TestCase {
        name: "SearchSettingsPageTests"
        when: windowShown

        function test_componentLoads() {
            compare(testedComponent.status, Component.Ready)
        }
    }
}
