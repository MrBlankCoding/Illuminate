import QtQuick
import QtTest
import illuminate.ui

Item {
    id: root
    width: 800
    height: 600

    Component {
        id: testedComponent
        SettingsWindow {}
    }

    TestCase {
        name: "SettingsWindowTests"
        when: windowShown

        function test_componentLoads() {
            compare(testedComponent.status, Component.Ready)
        }

        function test_statisticsSectionPresent() {
            const window = createTemporaryObject(testedComponent, root)
            verify(window !== null)
            const nav = window.contentItem.children.find(c => c.sections !== undefined)
            verify(nav !== undefined)
            verify(nav.sections.includes("Statistics"))
        }
    }
}
