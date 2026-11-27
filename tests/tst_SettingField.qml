import QtQuick
import QtTest
import illuminate.ui

Item {
    id: root
    width: 800
    height: 600

    Component {
        id: fieldComponent
        SettingField {}
    }

    SignalSpy {
        id: editedSpy
        signalName: "editingFinished"
    }

    TestCase {
        name: "SettingFieldTests"
        when: windowShown

        function test_componentLoads() {
            compare(fieldComponent.status, Component.Ready)
        }

        function test_naturalSize() {
            const field = createTemporaryObject(fieldComponent, root)
            compare(field.implicitWidth, 260)
            compare(field.implicitHeight, 30)
        }

        function test_typingEntersText() {
            const field = createTemporaryObject(fieldComponent, root)
            field.forceActiveFocus()
            keyClick(Qt.Key_A)
            keyClick(Qt.Key_B)
            compare(field.text, "ab")
        }

        function test_returnFinishesEditing() {
            const field = createTemporaryObject(fieldComponent, root, { text: "https://example.com" })
            editedSpy.target = field
            editedSpy.clear()
            field.forceActiveFocus()
            keyClick(Qt.Key_Return)
            compare(editedSpy.count, 1)
            compare(field.text, "https://example.com")
        }

        function test_placeholderShowsWhenEmpty() {
            const field = createTemporaryObject(fieldComponent, root, { placeholderText: "https://…" })
            compare(field.text, "")
            compare(field.placeholderText, "https://…")
        }
    }
}
