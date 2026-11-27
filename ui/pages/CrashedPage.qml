import QtQuick
import QtQuick.Layouts
import illuminate.ui

pragma ComponentBehavior: Bound

// rendered for "illuminate://crashed?url=…": a tab whose page kept crashing as
// it loaded. Reloading automatically would only crash again, so ask first.
Item {
    id: root

    // set by the TabSlot hosting this page
    property string tabId: ""
    property string pageUrl: ""

    // the address the crash page stands in for
    readonly property string crashedUrl: {
        const marker = "?url=";
        const at = root.pageUrl.indexOf(marker);
        if (at < 0)
            return "";
        try {
            return decodeURIComponent(root.pageUrl.substring(at + marker.length));
        } catch (e) {
            return "";
        }
    }
    readonly property string crashedHost: {
        const m = /^[a-z][a-z0-9+.-]*:\/\/([^\/?#]+)/i.exec(root.crashedUrl);
        return m ? m[1].replace(/^www\./, "") : root.crashedUrl;
    }

    function reload() {
        if (root.tabId !== "" && root.crashedUrl !== "")
            Browser.loadInTab(root.tabId, root.crashedUrl);
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - 2 * Theme.space4, 420)
        spacing: Theme.space3

        LucideIcon {
            Layout.alignment: Qt.AlignHCenter
            source: "qrc:/illuminate/ui/icons/alert-triangle.svg"
            size: 40
            color: Theme.textMuted
        }

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("This page crashed")
            color: Theme.text
            wrapMode: Text.WordWrap
            font {
                family: Theme.fontFamily
                pixelSize: Theme.fontSizeL
                weight: Font.DemiBold
            }
        }

        Text {
            objectName: "crashDetail"
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: root.crashedHost !== ""
                ? qsTr("%1 stopped working twice in a row, so it wasn't reloaded automatically.").arg(root.crashedHost)
                : qsTr("The page stopped working twice in a row, so it wasn't reloaded automatically.")
            textFormat: Text.PlainText
            color: Theme.textMuted
            wrapMode: Text.WordWrap
            font {
                family: Theme.fontFamily
                pixelSize: Theme.fontSizeM
            }
        }

        PillButton {
            objectName: "reloadButton"
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Theme.space2
            visible: root.crashedUrl !== ""
            text: qsTr("Reload")
            textColor: Theme.onAccent
            fillColor: Theme.accent
            hoverFillColor: Qt.darker(Theme.accent, 1.1)
            onClicked: root.reload()
        }
    }
}
