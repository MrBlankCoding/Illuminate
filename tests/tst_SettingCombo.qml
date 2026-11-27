import QtQuick
import QtTest
import illuminate.ui

Item {
    id: root
    width: 800
    height: 600

    readonly property var engines: [
        { value: "duckduckgo", text: "DuckDuckGo" },
        { value: "google", text: "Google" },
        { value: "bing", text: "Bing" }
    ]

    Component {
        id: comboComponent
        SettingCombo {
            textRole: "text"
            valueRole: "value"
        }
    }

    TestCase {
        name: "SettingComboTests"
        when: windowShown

        function makeCombo(props) {
            const combo = createTemporaryObject(comboComponent, root, props)
            verify(!!combo)
            return combo
        }

        function test_componentLoads() {
            compare(comboComponent.status, Component.Ready)
        }

        function test_selectsTheEntryForItsValue() {
            const combo = makeCombo({ model: root.engines, value: "google" })
            compare(combo.currentIndex, 1)
            compare(combo.displayText, "Google")
        }

        function test_followsValueChanges() {
            const combo = makeCombo({ model: root.engines, value: "google" })
            combo.value = "bing"
            compare(combo.currentIndex, 2)
            combo.value = "duckduckgo"
            compare(combo.currentIndex, 0)
        }

        function test_unknownValueFallsBackToTheFirstEntry() {
            const combo = makeCombo({ model: root.engines, value: "altavista" })
            compare(combo.currentIndex, 0)
        }

        function test_valueSetBeforeTheModelIsAppliedOnceEntriesArrive() {
            const combo = makeCombo({ value: "bing" })
            compare(combo.count, 0)
            combo.model = root.engines
            tryCompare(combo, "currentIndex", 2)
        }

        function test_plainStringModelsWork() {
            const combo = createTemporaryObject(comboComponent, root, {
                textRole: "", valueRole: "", model: ["One", "Two"], value: "Two"
            })
            compare(combo.currentIndex, 1)
            compare(combo.displayText, "Two")
        }
    }
}
