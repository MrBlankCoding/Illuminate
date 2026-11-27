pragma ComponentBehavior: Bound
import QtQuick
import illuminate.ui

FocusScope {
    id: root

    required property string commandId
    property bool capturing: false
    property string message: ""
    property bool conflicted: false
    
    readonly property string sequence: Shortcuts.bindings[root.commandId] !== undefined
        ? Shortcuts.displaySequence(root.commandId) : ""

    readonly property string display: root.capturing
        ? "Press keys…"
        : (root.message.length > 0 ? root.message : (root.sequence.length > 0 ? root.sequence : "Not set"))

    implicitWidth: 190
    implicitHeight: 28

    // a rebind anywhere invalidates a refusal shown here
    function refresh() {
        root.message = "";
        root.conflicted = false;
    }

    function beginCapture() {
        root.message = "";
        root.conflicted = false;
        root.capturing = true;
        root.forceActiveFocus();
    }

    Connections {
        target: Shortcuts
        function onShortcutsChanged() {
            root.refresh();
        }
    }

    onActiveFocusChanged: {
        // tabbing or clicking away abandons whatever was half-entered
        if (!activeFocus && root.capturing)
            root.capturing = false;
    }

    Keys.onPressed: event => {
        // nothing here should reach the window: Escape must not close settings
        // while it doubles as "cancel"
        event.accepted = true;

        if (event.key === Qt.Key_Escape) {
            root.capturing = false;
            root.message = "";
            root.conflicted = false;
            return;
        }

        // a modified Backspace is a legitimate binding, a bare one resets
        if (event.modifiers === 0 && (event.key === Qt.Key_Backspace || event.key === Qt.Key_Delete)) {
            Shortcuts.reset(root.commandId);
            root.capturing = false;
            return;
        }

        const sequence = Shortcuts.sequenceFromKey(event.key, event.modifiers);
        // a bare key is not bindable; stay armed and keep waiting
        if (sequence.length === 0)
            return;

        if (Shortcuts.setSequence(root.commandId, sequence)) {
            root.capturing = false;
            root.message = "";
            root.conflicted = false;
            return;
        }

        const owner = Shortcuts.commandUsing(sequence, root.commandId);
        root.capturing = false;
        root.conflicted = true;
        root.message = "Used by " + (Shortcuts.labelFor(owner).length > 0 ? Shortcuts.labelFor(owner) : owner);
    }

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: root.capturing ? Theme.accentDim : (hover.hovered || root.activeFocus ? Theme.surfaceHigh : Theme.surface)
        border.width: 1
        border.color: root.conflicted ? Theme.danger : (root.capturing ? Theme.accent : Theme.border)

        Behavior on color {
            ColorAnimation {
                duration: Theme.durationFast
            }
        }
    }

    Text {
        anchors {
            fill: parent
            leftMargin: 10
            rightMargin: 10
        }
        verticalAlignment: Text.AlignVCenter
        text: root.display
        elide: Text.ElideRight
        color: root.conflicted ? Theme.danger : (root.capturing ? Theme.accent : Theme.text)
        font { family: Theme.fontFamily; pixelSize: Theme.fontSizeM }
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: {
            if (root.capturing) {
                root.capturing = false;
                return;
            }
            root.beginCapture();
        }
    }
}
