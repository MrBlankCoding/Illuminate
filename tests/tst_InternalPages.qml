import QtQuick
import QtTest
import illuminate.ui

Item {
    id: root
    width: 400
    height: 100

    TestCase {
        name: "SetupInternalPageTests"
        when: windowShown

        function test_setup_is_internal() {
            verify(InternalPages.isInternal("illuminate://setup"))
            verify(InternalPages.isInternal("illuminate://setup/"))
        }

        function test_setup_qml_source() {
            compare(InternalPages.qmlSource("illuminate://setup"),
                    "qrc:/illuminate/ui/pages/SetupPage.qml")
            compare(InternalPages.qmlSource("illuminate://setup/"),
                    "qrc:/illuminate/ui/pages/SetupPage.qml")
            // unknown illuminate schemes resolve to nothing
            verify(InternalPages.qmlSource("illuminate://nope") === "")
        }

        function test_setup_title() {
            compare(InternalPages.title("illuminate://setup"), "Setup")
            compare(InternalPages.title("illuminate://setup/"), "Setup")
        }

        function test_new_tab_is_blank() {
            verify(InternalPages.isInternal("newtab://newtab"))
            compare(InternalPages.qmlSource("newtab://newtab"), "")
            compare(InternalPages.title("newtab://newtab"), "")
            compare(InternalPages.title("illuminate://memory"), "")
        }
    }
}
