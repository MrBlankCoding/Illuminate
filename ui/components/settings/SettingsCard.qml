import QtQuick
import QtQuick.Layouts
import illuminate.ui

Rectangle {
    id: root
    default property alias content: column.data

    Layout.fillWidth: true
    implicitWidth: column.implicitWidth
    implicitHeight: column.implicitHeight
    radius: 10
    color: Theme.surface

    ColumnLayout {
        id: column
        anchors {
            left: parent.left
            right: parent.right
        }
        spacing: 0
    }
}
