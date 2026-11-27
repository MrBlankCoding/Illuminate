import QtQuick
import QtTest
import illuminate.ui

Item {
    id: root
    width: 800
    height: 600

    // what the prompt reads from its TabSlot
    Item {
        id: fakeTab
        width: 800
        height: 600
        property string tabUrl: "https://www.docs.example/edit"
    }

    // a stand-in for BeforeUnloadRequest
    Component {
        id: requestComponent
        QtObject {
            property bool isReload: false
            property var answers: []
            signal finished()
            function leave() { answers = answers.concat([true]) }
            function stay() { answers = answers.concat([false]) }
        }
    }

    Component {
        id: promptComponent
        BeforeUnloadPrompt {
            tabSlot: fakeTab
        }
    }

    TestCase {
        name: "BeforeUnloadPromptTests"
        when: windowShown

        function showPrompt(isReload) {
            const prompt = createTemporaryObject(promptComponent, root)
            const request = createTemporaryObject(requestComponent, root, { isReload: !!isReload })
            prompt.show(request)
            const popup = findChild(prompt, "beforeUnloadPopup")
            tryCompare(popup, "opened", true)
            return { prompt: prompt, request: request, popup: popup }
        }

        function test_componentLoads() {
            compare(promptComponent.status, Component.Ready)
        }

        function test_namesTheSite() {
            const prompt = createTemporaryObject(promptComponent, root)
            compare(prompt.host, "docs.example")
        }

        function test_leaveLetsThePageGo() {
            const p = showPrompt()
            compare(findChild(p.popup.contentItem, "beforeUnloadTitle").text, "Leave site?")
            mouseClick(findChild(p.popup.contentItem, "leaveButton"))
            compare(p.request.answers, [true])
            tryCompare(p.popup, "visible", false)
            verify(!p.prompt.showing)
        }

        function test_stayKeepsThePage() {
            const p = showPrompt()
            mouseClick(findChild(p.popup.contentItem, "stayButton"))
            compare(p.request.answers, [false])
            tryCompare(p.popup, "visible", false)
        }

        function test_escapeMeansStay() {
            const p = showPrompt()
            keyClick(Qt.Key_Escape)
            tryCompare(p.popup, "visible", false)
            compare(p.request.answers, [false])
        }

        function test_reloadIsWordedAsReload() {
            const p = showPrompt(true)
            compare(findChild(p.popup.contentItem, "beforeUnloadTitle").text, "Reload site?")
            compare(findChild(p.popup.contentItem, "leaveButton").text, "Reload")
        }

        // the page went away while asking: close without answering
        function test_aDismissedRequestClosesQuietly() {
            const p = showPrompt()
            p.request.finished()
            tryCompare(p.popup, "visible", false)
            compare(p.request.answers, [])
        }

        function test_answersOnlyOnce() {
            const p = showPrompt()
            p.prompt.answer(true)
            p.prompt.answer(false)
            compare(p.request.answers, [true])
        }
    }
}
