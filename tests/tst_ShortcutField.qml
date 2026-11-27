import QtQuick
import QtTest
import illuminate.ui

Item {
    id: root
    width: 800
    height: 600

    Component {
        id: fieldComponent
        ShortcutField {
            width: 190
            height: 28
            commandId: "reload"
        }
    }

    TestCase {
        id: testCase
        name: "ShortcutFieldTests"
        when: windowShown

        // a combination nothing in the catalogue uses
        readonly property int freeKey: Qt.Key_J
        readonly property int freeModifiers: Qt.ControlModifier | Qt.AltModifier | Qt.ShiftModifier

        function cleanup() {
            Shortcuts.resetAll()
        }

        function makeField(commandId) {
            const field = createTemporaryObject(fieldComponent, root, commandId ? { commandId: commandId } : {})
            verify(!!field)
            return field
        }

        function test_componentLoads() {
            compare(fieldComponent.status, Component.Ready)
        }

        function test_showsTheCurrentBinding() {
            const field = makeField()
            compare(field.sequence, Shortcuts.displaySequence("reload"))
            verify(field.sequence.length > 0)
            compare(field.display, field.sequence)
        }

        function test_unknownCommandShowsNotSet() {
            const field = makeField("no.such.command")
            compare(field.sequence, "")
            compare(field.display, "Not set")
        }

        function test_clickStartsAndStopsCapturing() {
            const field = makeField()
            mouseClick(field)
            verify(field.capturing)
            compare(field.display, "Press keys…")
            mouseClick(field)
            verify(!field.capturing)
        }

        function test_escapeCancelsWithoutChangingTheBinding() {
            const field = makeField()
            const before = Shortcuts.sequences("reload")
            field.beginCapture()
            keyClick(Qt.Key_Escape)
            verify(!field.capturing)
            compare(Shortcuts.sequences("reload"), before)
        }

        function test_aBareKeyKeepsWaiting() {
            const field = makeField()
            field.beginCapture()
            keyClick(Qt.Key_K)
            verify(field.capturing, "a key without a modifier is not a shortcut")
            verify(!Shortcuts.isCustomized("reload"))
        }

        function test_aModifiedKeyBecomesTheBinding() {
            const sequence = Shortcuts.sequenceFromKey(freeKey, freeModifiers)
            compare(Shortcuts.commandUsing(sequence, ""), "", "test combination should be unused")

            const field = makeField()
            field.beginCapture()
            keyClick(freeKey, freeModifiers)
            verify(!field.capturing)
            verify(!field.conflicted)
            verify(Shortcuts.isCustomized("reload"))
            compare(Shortcuts.sequences("reload")[0], sequence)
        }

        function test_aTakenCombinationIsRefusedAndNamesItsOwner() {
            const taken = Shortcuts.sequences("newTab")[0]
            verify(taken.length > 0)
            const field = makeField()
            field.beginCapture()
            // replay the newTab binding through the same path a key press takes
            const mods = (taken.indexOf("Ctrl") >= 0 ? Qt.ControlModifier : 0)
                       | (taken.indexOf("Meta") >= 0 ? Qt.MetaModifier : 0)
                       | (taken.indexOf("Shift") >= 0 ? Qt.ShiftModifier : 0)
                       | (taken.indexOf("Alt") >= 0 ? Qt.AltModifier : 0)
            const key = taken.charCodeAt(taken.length - 1)
            if (Shortcuts.sequenceFromKey(key, mods) !== taken)
                skip("newTab's default can't be typed as a single key here: " + taken)
            keyClick(key, mods)

            verify(!field.capturing)
            verify(field.conflicted)
            compare(field.display, "Used by " + Shortcuts.labelFor("newTab"))
            verify(!Shortcuts.isCustomized("reload"))
        }

        function test_backspaceResetsToTheDefault() {
            Shortcuts.setSequence("reload", Shortcuts.sequenceFromKey(freeKey, freeModifiers))
            verify(Shortcuts.isCustomized("reload"))
            const field = makeField()
            field.beginCapture()
            keyClick(Qt.Key_Backspace)
            verify(!field.capturing)
            verify(!Shortcuts.isCustomized("reload"))
        }

        function test_aRebindElsewhereClearsARefusal() {
            const field = makeField()
            field.message = "Used by Something"
            field.conflicted = true
            Shortcuts.setSequence("reload", Shortcuts.sequenceFromKey(freeKey, freeModifiers))
            compare(field.message, "")
            verify(!field.conflicted)
        }

        function test_losingFocusAbandonsCapture() {
            const field = makeField()
            field.beginCapture()
            verify(field.capturing)
            root.forceActiveFocus()
            verify(!field.capturing)
        }
    }
}
