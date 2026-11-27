import QtQuick
import QtQuick.Layouts
import illuminate.ui

pragma ComponentBehavior: Bound

Item {
    id: root

    required property var model
    required property int visibleRows
    required property int maxRows
    required property int rowHeight
    required property int highlightedIndex
    required property var urlCheck
    signal hoverDetected(int index, point position)
    signal commitRequested(int index)

    function ensureIndexVisible(index) {
        if (index >= 0 && index < resultList.count)
            resultList.positionViewAtIndex(index, ListView.Contain);
    }

    Item {
        anchors.fill: parent
        opacity: root.visibleRows > 0 ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.motion(140); easing.type: Easing.OutCubic }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                color: Theme.cardBorder
                Layout.preferredHeight: 1
            }

            ListView {
                id: resultList
                clip: true
                Layout.fillWidth: true
                Layout.fillHeight: true
                topMargin: Theme.space2
                bottomMargin: Theme.space2
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds
                model: root.model

                delegate: Item {
                    id: row

                    required property int index
                    required property string kind
                    required property string title
                    required property string subtitle
                    required property string url
                    required property string iconUrl
                    required property string icon
                    readonly property bool selected: index === root.highlightedIndex

                    width: resultList.width
                    height: root.rowHeight

                    Rectangle {
                        anchors {
                            fill: parent
                            leftMargin: Theme.space2
                            rightMargin: Theme.space2
                        }
                        radius: Theme.radiusItem
                        color: row.selected ? Theme.accentDim : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                    }

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: Theme.space4 + 2
                            rightMargin: Theme.space4 + 2
                        }
                        spacing: Theme.space3

                        Item {
                            Layout.preferredWidth: 16
                            Layout.preferredHeight: 16

                            Image {
                                id: favicon
                                anchors.fill: parent
                                sourceSize.width: 32
                                sourceSize.height: 32
                                source: (row.kind === "tab" || row.kind === "bookmark") && row.iconUrl !== "" && !row.iconUrl.startsWith("chrome:") && !row.iconUrl.startsWith("about:") ? row.iconUrl : ""
                                visible: status === Image.Ready
                                asynchronous: true
                                onStatusChanged: {
                                    if (status === Image.Error)
                                        source = "";
                                }
                            }
                            LetterAvatar {
                                anchors.fill: parent
                                visible: !favicon.visible && (row.kind === "tab" || row.kind === "bookmark")
                                url: row.url
                                title: row.title
                            }
                            LucideIcon {
                                anchors.centerIn: parent
                                size: 15
                                visible: row.kind === "go" || row.kind === "suggest" || row.kind === "action" || row.kind === "calc" || row.kind === "bang"
                                source: row.kind === "action" ? row.icon
                                      : row.kind === "calc" ? "qrc:/illuminate/ui/icons/activity.svg"
                                      : row.kind === "bang" ? "qrc:/illuminate/ui/icons/search.svg"
                                      : row.kind === "go" && root.urlCheck(row.title) ? "qrc:/illuminate/ui/icons/globe.svg"
                                      : "qrc:/illuminate/ui/icons/search.svg"
                                color: (row.kind === "calc" || row.kind === "bang") ? Theme.accent : Theme.textMuted
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: row.title
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: Theme.text
                            font { family: Theme.fontFamily; pixelSize: Theme.fontSizeM }
                        }

                        Text {
                            Layout.maximumWidth: resultList.width * 0.4
                            visible: text !== ""
                            text: row.subtitle
                            textFormat: Text.PlainText
                            elide: Text.ElideMiddle
                            color: Theme.textMuted
                            font { family: Theme.fontFamily; pixelSize: Theme.fontSizeS }
                        }

                        LucideIcon {
                            visible: row.selected
                            size: 13
                            source: "qrc:/illuminate/ui/icons/arrow-right.svg"
                            color: Theme.textMuted
                        }
                    }

                    HoverHandler {
                        onPointChanged: {
                            const p = point.scenePosition;
                            root.hoverDetected(row.index, Qt.point(p.x, p.y));
                        }
                    }
                    TapHandler {
                        onTapped: root.commitRequested(row.index)
                    }
                }
            }
        }
    }
}
