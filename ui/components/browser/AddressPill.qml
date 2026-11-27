import QtQuick
import QtQuick.Layouts
import illuminate.ui

Item {
    id: root

    property string currentUrl: ""
    property bool isLoading: false
    property int loadProgress: 0
    // the window whose active page extensions act on
    property Window targetWindow: null

    readonly property bool isBookmarked: Bookmarks.count >= 0 && root.currentUrl !== "" && Bookmarks.isBookmarked(root.currentUrl)
    signal clicked
    signal toggleBookmark

    implicitHeight: Theme.addressPillHeight
    scale: tap.pressed ? Theme.pressScale : 1
    Behavior on scale { NumberAnimation { duration: Theme.durationFast; easing.type: Easing.OutCubic } }

    // "https://www.example.com/a/b" -> "example.com"
    function displayHost(url) {
        const m = /^[a-z][a-z0-9+.-]*:\/\/([^\/?#]+)/i.exec(url);
        return m ? m[1].replace(/^www\./, "") : url;
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusItem
        color: hover.hovered ? Theme.itemHover : Theme.fieldBg
        // ponytail: retain clipping for pill-corner masking; remove if children stay within rounded bounds.
        clip: true
        Behavior on color { ColorAnimation { duration: Theme.durationFast } }

        RowLayout {
            anchors {
                fill: parent
                leftMargin: Theme.space3 - 2
                rightMargin: Theme.space2
            }
            spacing: Theme.space2 - 2

            LucideIcon {
                size: 13
                source: root.currentUrl === "" ? "qrc:/illuminate/ui/icons/search.svg"
                      : root.currentUrl.startsWith("https://") ? "qrc:/illuminate/ui/icons/lock.svg"
                      : root.currentUrl.startsWith("http://") ? "qrc:/illuminate/ui/icons/alert-triangle.svg"
                      : "qrc:/illuminate/ui/icons/globe.svg"
                color: root.currentUrl.startsWith("http://") ? Theme.danger : Theme.textMuted
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                text: root.currentUrl === "" ? qsTr("Search with %1 or enter address").arg(Prefs.searchEngineName)
                                             : root.displayHost(root.currentUrl)
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: root.currentUrl === "" ? Theme.textMuted : Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeM
                Layout.fillWidth: true
            }

            LucideIcon {
                size: 13
                visible: root.currentUrl !== "" && (hover.hovered || root.isBookmarked)
                source: root.isBookmarked ? "qrc:/illuminate/ui/icons/star-filled.svg" : "qrc:/illuminate/ui/icons/star.svg"
                color: root.isBookmarked ? Theme.accent : (starHover.hovered ? Theme.text : Theme.textMuted)
                Layout.alignment: Qt.AlignVCenter

                HoverHandler {
                    id: starHover
                }
                TapHandler {
                    onTapped: root.toggleBookmark()
                }
            }

            ExtensionsButton {
                id: extensions
                iconSize: 14
                targetWindow: root.targetWindow
                pageUrl: root.currentUrl
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                Layout.rightMargin: -Theme.space1
            }

        }

        Rectangle {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            height: Theme.progressH
            width: parent.width * (root.loadProgress / 100)
            color: Theme.accent
            opacity: root.isLoading && root.loadProgress > 0 && root.loadProgress < 100 ? 1 : 0
            Behavior on width { NumberAnimation { duration: Theme.motion(80); easing.type: Easing.OutQuad } }
            Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
        }
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
        id: tap
        // taps on the star and the extensions button reach this handler too;
        // go by where it landed, as opening a popup can end the hover first
        onTapped: eventPoint => {
            if (!starHover.hovered && !extensions.contains(extensions.mapFromItem(root, eventPoint.position)))
                root.clicked();
        }
    }
}
