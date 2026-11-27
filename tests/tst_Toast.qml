import QtQuick
import QtTest
import illuminate.ui

Item {
    id: root
    width: 800
    height: 600

    Component {
        id: toastComponent
        Toast {
            duration: 800
        }
    }

    TestCase {
        name: "ToastTests"
        when: windowShown

        function test_componentLoads() {
            compare(toastComponent.status, Component.Ready)
        }

        function test_showsTheMessageThenGoesAway() {
            const toast = createTemporaryObject(toastComponent, root)
            toast.show("Link copied")
            tryCompare(toast, "opened", true)
            compare(findChild(toast.contentItem, "toastText").text, "Link copied")
            compare(toast.icon, "qrc:/illuminate/ui/icons/check.svg")
            tryCompare(toast, "visible", false, 3000)
        }

        function test_aSecondMessageReplacesTheFirstAndStaysLonger() {
            const toast = createTemporaryObject(toastComponent, root)
            toast.show("First")
            tryCompare(toast, "opened", true)
            wait(300)
            toast.show("Second", "qrc:/illuminate/ui/icons/download.svg")
            compare(findChild(toast.contentItem, "toastText").text, "Second")
            compare(toast.icon, "qrc:/illuminate/ui/icons/download.svg")
            // the timer restarted: still up past the first one's time
            wait(450)
            verify(toast.visible)
            tryCompare(toast, "visible", false, 3000)
        }

        // a new message while the last one fades out must not fade with it
        function test_aMessageDuringTheFadeOutStays() {
            const toast = createTemporaryObject(toastComponent, root)
            toast.show("First")
            tryCompare(toast, "opened", true)
            toast.close()
            verify(toast.visible) // fading out
            toast.show("Second")
            tryCompare(toast, "opened", true)
            compare(findChild(toast.contentItem, "toastText").text, "Second")
            wait(300)
            verify(toast.visible)
        }

        function test_neverTakesFocusFromThePage() {
            const toast = createTemporaryObject(toastComponent, root)
            verify(!toast.focus)
            verify(!toast.modal)
        }
    }
}
