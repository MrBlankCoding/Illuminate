import QtQuick
import QtTest
import illuminate.ui

Item {
    id: root
    width: 200
    height: 100

    Component {
        id: iconComponent
        LucideIcon {}
    }

    TestCase {
        name: "LucideIconTests"
        when: windowShown

        function test_componentExists() {
            let icon = createTemporaryObject(iconComponent, root)
            verify(!!icon, "Component exists")
        }

        function test_defaultSize() {
            let icon = createTemporaryObject(iconComponent, root)
            verify(!!icon, "Component exists")
            compare(icon.size, 16)
            compare(icon.width, 16)
            compare(icon.height, 16)
        }

        function test_sizeWritable() {
            let icon = createTemporaryObject(iconComponent, root)
            verify(!!icon, "Component exists")
            icon.size = 24
            compare(icon.width, 24)
            compare(icon.height, 24)
        }

        function test_sourceWritable() {
            let icon = createTemporaryObject(iconComponent, root)
            verify(!!icon, "Component exists")
            icon.source = qsTr("qrc:/illuminate/ui/icons/globe.svg")
            compare(icon.source, qsTr("qrc:/illuminate/ui/icons/globe.svg"))
        }

        function test_colorWritable() {
            let icon = createTemporaryObject(iconComponent, root)
            verify(!!icon, "Component exists")
            icon.color = '#ff0000'
            compare(icon.color.toString(), '#ff0000')
        }
    }
}