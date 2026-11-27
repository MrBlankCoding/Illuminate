import QtQuick
import QtQuick.Layouts
import illuminate.ui

pragma ComponentBehavior: Bound

Item {
    id: root

    required property var model
    required property int index

    readonly property string tabTitle: model && model.title !== undefined ? String(model.title) : qsTr("New Tab")
    readonly property string tabIconUrl: model && model.iconUrl !== undefined ? String(model.iconUrl) : ""
    readonly property string tabUrl: model && model.url ? model.url.toString() : ""
    readonly property bool tabLoading: model !== undefined && model !== null && model.loading === true
    readonly property bool tabSuspended: model !== undefined && model !== null && model.suspended === true
    readonly property bool tabInFolder: model ? model.inFolder === true : false
    readonly property bool tabAudible: model ? model.audible === true : false
    readonly property bool tabMuted: model ? model.muted === true : false
    // the page changed while in the background
    readonly property bool tabHasActivity: model ? model.hasActivity === true : false
    property bool isActive: false
    property bool dragging: false  // the sidebar moves rows; this only dims
    property bool faviconFailed: false

    // a folder's new tab still shows while the user picks a page for it
    visible: tabInFolder || tabUrl !== "newtab://newtab"

    signal activated
    signal closeClicked
    signal contextMenuRequested
    signal muteToggled

    readonly property bool hovered: hoverHandler.hovered
    onTabIconUrlChanged: faviconFailed = false

    Rectangle {
        id: body
        anchors.fill: parent
        radius: Theme.radiusTab
        scale: tapHandler.pressed && !root.dragging ? Theme.pressScale : 1
        color: root.isActive ? Theme.itemActive
             : tapHandler.pressed ? Theme.itemPressed
             : root.hovered || root.dragging ? Theme.itemHover
             : "transparent"
        border.width: root.isActive ? 1 : 0
        border.color: Theme.itemActiveBorder

        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
        Behavior on scale { NumberAnimation { duration: Theme.durationFast; easing.type: Easing.OutCubic } }

        RowLayout {
            anchors {
                fill: parent
                leftMargin: Theme.space3 - 2
                rightMargin: Theme.space1 + 2
            }
            spacing: Theme.space2 + 2
            Item {
                id: faviconBox
                objectName: "faviconBox"
                Layout.preferredWidth: Theme.faviconSize
                Layout.preferredHeight: Theme.faviconSize
                Layout.alignment: Qt.AlignVCenter
                // sleeping tabs read as dimmed
                opacity: root.tabSuspended ? 0.45 : 1

                readonly property bool showFavicon: root.tabIconUrl !== ""
                    && !root.tabIconUrl.startsWith("chrome:")
                    && !root.tabIconUrl.startsWith("about:")
                    && !root.tabIconUrl.startsWith("javascript:")
                    && !root.faviconFailed

                Image {
                    anchors.fill: parent
                    sourceSize.width: Theme.faviconSize * 2
                    sourceSize.height: Theme.faviconSize * 2
                    source: faviconBox.showFavicon ? root.tabIconUrl : ""
                    visible: !root.tabLoading && faviconBox.showFavicon
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    asynchronous: true
                    onStatusChanged: if (status === Image.Error) root.faviconFailed = true
                }

                LetterAvatar {
                    anchors.fill: parent
                    visible: !root.tabLoading && !faviconBox.showFavicon
                    url: root.tabUrl
                    title: root.tabTitle
                }

                Canvas {
                    anchors.fill: parent
                    // follows opacity so the fade-out gets to play
                    visible: opacity > 0
                    opacity: root.tabLoading ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }

                    onVisibleChanged: if (visible) requestPaint()
                    Component.onCompleted: requestPaint()

                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        const cx = width / 2, cy = height / 2, r = width / 2 - 1.5;
                        ctx.strokeStyle = Theme.accent;
                        ctx.lineWidth = 2;
                        ctx.lineCap = "round";
                        ctx.beginPath();
                        ctx.arc(cx, cy, r, 0, Math.PI * 1.3);
                        ctx.stroke();
                    }

                    RotationAnimation on rotation {
                        running: root.tabLoading
                        from: 0
                        to: 360
                        duration: 800
                        loops: Animation.Infinite
                    }
                }

                // something new on a page in the background
                Rectangle {
                    objectName: "activityDot"
                    readonly property bool shown: root.tabHasActivity && !root.isActive
                    width: 8
                    height: 8
                    radius: 4
                    x: parent.width - width / 2 - 1
                    y: -height / 2 + 1
                    color: Theme.accent
                    border.width: 1.5
                    border.color: Theme.sidebarBg
                    visible: scale > 0
                    scale: shown ? 1 : 0
                    Behavior on scale {
                        NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.tabTitle
                // page-controlled: never interpret markup (it could load remote images)
                textFormat: Text.PlainText
                color: root.isActive ? Theme.text : Theme.textMuted
                opacity: root.tabSuspended ? 0.7 : 1
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
                font {
                    preferShaping: false
                    pixelSize: Theme.fontSizeM
                    family: Theme.fontFamily
                    weight: root.isActive ? Font.Medium : Font.Normal
                }
                Behavior on color { ColorAnimation { duration: Theme.durationFast } }
            }

            // playing sound: a speaker that mutes the tab when clicked. It
            // eases in and out rather than popping, and holds steady while
            // the page plays (the page side waits out short silences).
            Rectangle {
                objectName: "muteButton"
                readonly property bool shown: (root.tabAudible || root.tabMuted) && !root.dragging
                Layout.preferredWidth: shown ? 22 : 0
                Layout.preferredHeight: 22
                Layout.alignment: Qt.AlignVCenter
                Behavior on Layout.preferredWidth { NumberAnimation { duration: Theme.durationMid; easing.type: Easing.OutCubic } }
                radius: Theme.radiusS
                clip: true
                opacity: shown ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.durationMid } }
                visible: opacity > 0
                color: muteTap.pressed ? Theme.itemPressed : muteHover.hovered ? Theme.itemHover : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                Accessible.role: Accessible.Button
                Accessible.name: root.tabMuted ? qsTr("Unmute tab") : qsTr("Mute tab")

                LucideIcon {
                    id: speaker
                    anchors.centerIn: parent
                    source: root.tabMuted ? "qrc:/illuminate/ui/icons/volume-x.svg"
                                          : "qrc:/illuminate/ui/icons/volume-2.svg"
                    size: 13
                    color: root.tabMuted ? Theme.textMuted
                         : muteHover.hovered || root.isActive ? Theme.text : Theme.textMuted
                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                }

                HoverHandler {
                    id: muteHover
                }
                TapHandler {
                    id: muteTap
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: root.muteToggled()
                }
            }

            Rectangle {
                objectName: "closeButton"
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                Layout.alignment: Qt.AlignVCenter
                radius: Theme.radiusS
                color: closeTap.pressed ? Theme.itemPressed : closeHover.hovered ? Theme.itemHover : "transparent"
                visible: root.hovered && !root.dragging
                opacity: root.hovered && !root.dragging ? 1 : 0

                Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }

                LucideIcon {
                    anchors.centerIn: parent
                    source: "qrc:/illuminate/ui/icons/x.svg"
                    size: 12
                    color: closeHover.hovered ? Theme.text : Theme.textMuted
                }

                HoverHandler {
                    id: closeHover
                }
                TapHandler {
                    id: closeTap
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: root.closeClicked()
                }
            }
        }
    }

    HoverHandler {
        id: hoverHandler
    }

    TapHandler {
        id: tapHandler
        onTapped: if (!closeHover.hovered && !muteHover.hovered) root.activated()
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: root.contextMenuRequested()
    }

    TapHandler {
        acceptedButtons: Qt.MiddleButton
        onTapped: root.closeClicked()
    }
}
