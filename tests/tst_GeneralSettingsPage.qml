import QtQuick
import QtTest
import illuminate.ui

Item {
    id: root
    width: 800
    height: 600

    Component {
        id: testedComponent
        GeneralSettingsPage {}
    }

    TestCase {
        name: "GeneralSettingsPageTests"
        when: windowShown

        function cleanup() {
            Prefs.uiDensity = "compact"
        }

        function test_componentLoads() {
            compare(testedComponent.status, Component.Ready)
        }

        function test_densityControlChangesTheSetting() {
            const page = createTemporaryObject(testedComponent, root)
            const control = findChild(page, "densityControl")
            verify(control)
            compare(control.value, "compact")
            mouseClick(findChild(control, "segment_cosy"))
            compare(Prefs.uiDensity, "cosy")
            compare(control.value, "cosy")
        }
    }
}
