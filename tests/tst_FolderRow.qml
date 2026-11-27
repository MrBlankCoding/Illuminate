import QtQuick
import QtTest
import illuminate.ui

Item {
    id: root
    width: 360
    height: 52

    Component {
        id: folderRowComponent
        FolderRow {
            width: 320
            height: 36
        }
    }

    SignalSpy { id: toggledSpy; signalName: "toggled" }
    SignalSpy { id: menuRequestedSpy; signalName: "menuRequested" }
    SignalSpy { id: renamedSpy; signalName: "renamed" }
    SignalSpy { id: editingCanceledSpy; signalName: "editingCanceled" }

    TestCase {
        name: "FolderRowTests"
        when: windowShown

        function test_publicDefaultsAndWritableProperties() {
            let row = createTemporaryObject(folderRowComponent, root)
            verify(!!row, "Component exists")
            compare(row.title, qsTr(""))
            compare(row.icon, qsTr(""))
            compare(row.expanded, true)
            compare(row.editing, false)
            compare(row.dropTarget, false)
            compare(row.dragging, false)

            row.title = qsTr("Work")
            row.icon = qsTr("📁")
            row.expanded = false
            row.dropTarget = true
            row.dragging = true
            compare(row.title, qsTr("Work"))
            compare(row.icon, qsTr("📁"))
            compare(row.expanded, false)
            compare(row.dropTarget, true)
            compare(row.dragging, true)
        }

        function test_primaryClickEmitsToggled() {
            let row = createTemporaryObject(folderRowComponent, root)
            verify(!!row, "Component exists")
            toggledSpy.target = row
            toggledSpy.clear()
            mouseClick(row, row.width / 2, row.height / 2)
            tryCompare(toggledSpy, "count", 1)
        }

        function test_secondaryClickEmitsMenuRequested() {
            let row = createTemporaryObject(folderRowComponent, root)
            verify(!!row, "Component exists")
            menuRequestedSpy.target = row
            menuRequestedSpy.clear()
            mouseClick(row, row.width / 2, row.height / 2, Qt.RightButton)
            tryCompare(menuRequestedSpy, "count", 1)
        }

        function test_tapHandlersAreDisabledDuringEditing() {
            let row = createTemporaryObject(folderRowComponent, root)
            verify(!!row, "Component exists")
            row.editing = true
            toggledSpy.target = row
            toggledSpy.clear()
            mouseClick(row, row.width / 2, row.height / 2)
            tryCompare(toggledSpy, "count", 0)
        }

        function test_editingCopiesTitleToNamedInput() {
            let row = createTemporaryObject(folderRowComponent, root)
            verify(!!row, "Component exists")
            row.title = qsTr("Projects")
            row.editing = true
            let input = findChild(row, "titleInput")
            verify(!!input, "Object exists")
            tryCompare(input, "text", qsTr("Projects"))
        }

        function test_commitEmitsTrimmedName() {
            let row = createTemporaryObject(folderRowComponent, root)
            verify(!!row, "Component exists")
            renamedSpy.target = row
            renamedSpy.clear()
            row.editing = true
            let input = findChild(row, "titleInput")
            verify(!!input, "Object exists")
            input.text = qsTr("  Projects  ")
            input.commit()
            tryCompare(renamedSpy, "count", 1)
            compare(renamedSpy.signalArguments[0][0], qsTr("Projects"))
        }

        function test_emptyCommitCancelsEditing() {
            let row = createTemporaryObject(folderRowComponent, root)
            verify(!!row, "Component exists")
            editingCanceledSpy.target = row
            editingCanceledSpy.clear()
            renamedSpy.clear()
            row.editing = true
            let input = findChild(row, "titleInput")
            verify(!!input, "Object exists")
            input.text = qsTr("   ")
            input.commit()
            tryCompare(editingCanceledSpy, "count", 1)
        }

        function test_escapeStateCancelsEditing() {
            let row = createTemporaryObject(folderRowComponent, root)
            verify(!!row, "Component exists")
            editingCanceledSpy.target = row
            editingCanceledSpy.clear()
            row.editing = true
            let input = findChild(row, "titleInput")
            verify(!!input, "Object exists")
            input.text = qsTr("Keep existing")
            input.canceled = true
            input.commit()
            tryCompare(editingCanceledSpy, "count", 1)
            compare(renamedSpy.count, 0)
        }
    }
}
