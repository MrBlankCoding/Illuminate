import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import illuminate.ui

pragma ComponentBehavior: Bound

Item {
    id: root

    property bool hasPreviousDownloads: false
    readonly property alias popupOpen: popup.visible
    readonly property bool downloading: Downloads.activeCount > 0

    implicitWidth: 26
    implicitHeight: 28
    visible: Downloads.count > 0 || root.hasPreviousDownloads

    function openList() {
        if (Downloads.count === 0) {
            Browser.newTab("chrome://downloads/");
            return;
        }
        Downloads.markSeen();
        popup.peeking = false;
        popupAutoClose.stop();
        popup.open();
    }

    // a download just started: show the list for a moment, like Chrome's
    // bubble, without taking keyboard focus from the page. Only while the
    // button is on screen (not with the sidebar collapsed).
    function peek() {
        if (!root.visible || popup.visible)
            return;
        popup.peeking = true;
        popup.open();
        popupAutoClose.restart();
    }

    Connections {
        target: Downloads
        function onDownloadStarted() {
            root.peek();
        }
    }

    Timer {
        id: popupAutoClose
        interval: 5000
        onTriggered: {
            // still being looked at: leave it to the person
            if (popupHover.hovered) {
                popupAutoClose.restart();
                return;
            }
            if (popup.peeking)
                popup.close();
        }
    }

    SidebarButton {
        id: button
        objectName: "downloadsButton"
        anchors.fill: parent
        icon: "qrc:/illuminate/ui/icons/download.svg"
        iconSize: 18
        active: popup.visible
        Accessible.name: root.downloading
            ? qsTr("Downloads, %1 in progress").arg(Downloads.activeCount)
            : qsTr("Downloads")
        onClicked: root.openList()
    }

    // progress around the button; spins when the size isn't known
    Canvas {
        id: ring
        objectName: "progressRing"
        anchors.centerIn: parent
        width: 24
        height: 24
        visible: root.downloading
        readonly property real progress: Downloads.overallProgress
        property real spin: 0
        onProgressChanged: requestPaint()
        onSpinChanged: requestPaint()
        onVisibleChanged: requestPaint()

        NumberAnimation on spin {
            running: ring.visible && ring.progress < 0
            from: 0
            to: 2 * Math.PI
            duration: 1100
            loops: Animation.Infinite
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const r = width / 2 - 1.5;
            ctx.lineWidth = 2;
            ctx.lineCap = "round";
            ctx.strokeStyle = Theme.accent;
            ctx.beginPath();
            if (ring.progress < 0)
                ctx.arc(width / 2, height / 2, r, ring.spin, ring.spin + Math.PI / 2);
            else
                ctx.arc(width / 2, height / 2, r, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * Math.max(0.02, ring.progress));
            ctx.stroke();
        }
    }

    Rectangle {
        objectName: "unseenDot"
        width: 7
        height: 7
        radius: 3.5
        x: parent.width - width - 2
        y: 3
        color: Theme.accent
        visible: Downloads.hasUnseen && !root.downloading && !popup.visible
    }

    Popup {
        id: popup
        objectName: "downloadsPopup"
        // opened by a new download rather than a click
        property bool peeking: false

        popupType: Popup.Window
        width: 300
        x: 0
        y: -height - Theme.space2
        padding: 0
        topPadding: Theme.space1
        bottomPadding: Theme.space1
        focus: !peeking
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        Component.onCompleted: PopupCloser.watch(popup)
        onClosed: {
            Downloads.markSeen();
            popup.peeking = false;
            popupAutoClose.stop();
        }

        background: Rectangle {
            radius: Theme.radiusCard
            color: Theme.bg
            border.color: Theme.border
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: 0

            HoverHandler {
                id: popupHover
            }

            Text {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                leftPadding: Theme.space3
                verticalAlignment: Text.AlignVCenter
                text: qsTr("Downloads")
                color: Theme.textMuted
                font {
                    family: Theme.fontFamily
                    pixelSize: Theme.fontSizeS
                    weight: Font.Medium
                }
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, 6 * 52)
                clip: true
                interactive: contentHeight > height
                model: Downloads
                boundsBehavior: Flickable.StopAtBounds

                delegate: Item {
                    id: row
                    required property int downloadId
                    required property string fileName
                    required property string statusText
                    required property real progress
                    required property int downloadState

                    readonly property bool active: row.downloadState === 0     // DownloadModel.Active
                    readonly property bool complete: row.downloadState === 1   // DownloadModel.Complete

                    width: ListView.view.width
                    height: 52

                    Rectangle {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.space1
                        anchors.rightMargin: Theme.space1
                        radius: Theme.radiusItem
                        color: rowHover.hovered && row.complete ? Theme.itemHover : "transparent"
                    }

                    ColumnLayout {
                        anchors {
                            left: parent.left
                            right: actions.left
                            verticalCenter: parent.verticalCenter
                            leftMargin: Theme.space3
                            rightMargin: Theme.space2
                        }
                        spacing: 3

                        Text {
                            Layout.fillWidth: true
                            text: row.fileName
                            textFormat: Text.PlainText
                            elide: Text.ElideMiddle
                            color: row.complete || row.active ? Theme.text : Theme.textMuted
                            font {
                                family: Theme.fontFamily
                                pixelSize: Theme.fontSizeM
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 3
                            visible: row.active
                            radius: 1.5
                            color: Theme.surfaceHigh
                            Rectangle {
                                height: parent.height
                                radius: parent.radius
                                width: row.progress < 0 ? parent.width * 0.3 : parent.width * row.progress
                                color: Theme.accent
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: row.statusText
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: row.downloadState >= 2 ? Theme.danger : Theme.textMuted
                            font {
                                family: Theme.fontFamily
                                pixelSize: Theme.fontSizeS
                            }
                        }
                    }

                    HoverHandler {
                        id: rowHover
                        cursorShape: row.complete ? Qt.PointingHandCursor : Qt.ArrowCursor
                    }
                    TapHandler {
                        enabled: row.complete
                        onTapped: {
                            Downloads.open(row.downloadId);
                            popup.close();
                        }
                    }

                    Row {
                        id: actions
                        anchors {
                            right: parent.right
                            rightMargin: Theme.space2
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: 2

                        SidebarButton {
                            width: 26
                            height: 26
                            visible: row.complete
                            icon: "qrc:/illuminate/ui/icons/folder-open.svg"
                            iconSize: 14
                            Accessible.name: Qt.platform.os === "osx" ? qsTr("Show in Finder") : qsTr("Show in folder")
                            onClicked: Downloads.reveal(row.downloadId)
                        }
                        SidebarButton {
                            width: 26
                            height: 26
                            visible: row.active
                            icon: "qrc:/illuminate/ui/icons/x.svg"
                            iconSize: 14
                            Accessible.name: qsTr("Cancel download")
                            onClicked: Downloads.cancel(row.downloadId)
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                Layout.leftMargin: Theme.space1
                Layout.rightMargin: Theme.space1
                spacing: 0

                PillButton {
                    text: qsTr("Show all")
                    textColor: Theme.textMuted
                    leftPadding: Theme.space2
                    rightPadding: Theme.space2
                    onClicked: {
                        popup.close();
                        Browser.newTab("chrome://downloads/");
                    }
                }
                Item { Layout.fillWidth: true }
                PillButton {
                    text: qsTr("Clear")
                    textColor: Theme.textMuted
                    leftPadding: Theme.space2
                    rightPadding: Theme.space2
                    visible: Downloads.count > Downloads.activeCount
                    onClicked: Downloads.clearFinished()
                }
            }
        }
    }
}
