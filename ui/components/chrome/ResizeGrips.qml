import QtQuick

Item {
    id: root

    property int edgeGrip: 6
    property int cornerGrip: 10

    // Expose a signal or property to handle system resize requests
    signal requestSystemResize(int edges)

    MouseArea { // left
        objectName: "leftGrip"
        height: parent.height - root.cornerGrip * 2
        width: root.edgeGrip
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        cursorShape: Qt.SizeHorCursor
        onPressed: root.requestSystemResize(Qt.LeftEdge)
    }
    MouseArea { // right
        objectName: "rightGrip"
        height: parent.height - root.cornerGrip * 2
        width: root.edgeGrip
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        cursorShape: Qt.SizeHorCursor
        onPressed: root.requestSystemResize(Qt.RightEdge)
    }
    MouseArea { // bottom
        objectName: "bottomGrip"
        width: parent.width - root.cornerGrip * 2
        height: root.edgeGrip
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        cursorShape: Qt.SizeVerCursor
        onPressed: root.requestSystemResize(Qt.BottomEdge)
    }
    MouseArea { // top-left corner
        objectName: "topLeftGrip"
        width: root.cornerGrip
        height: root.cornerGrip
        anchors.top: parent.top
        anchors.left: parent.left
        cursorShape: Qt.SizeFDiagCursor
        onPressed: root.requestSystemResize(Qt.TopEdge | Qt.LeftEdge)
    }
    MouseArea { // top-right corner
        objectName: "topRightGrip"
        width: root.cornerGrip
        height: root.cornerGrip
        anchors.top: parent.top
        anchors.right: parent.right
        cursorShape: Qt.SizeBDiagCursor
        onPressed: root.requestSystemResize(Qt.TopEdge | Qt.RightEdge)
    }
    MouseArea { // bottom-left corner
        objectName: "bottomLeftGrip"
        width: root.cornerGrip
        height: root.cornerGrip
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        cursorShape: Qt.SizeBDiagCursor
        onPressed: root.requestSystemResize(Qt.BottomEdge | Qt.LeftEdge)
    }
    MouseArea { // bottom-right corner
        objectName: "bottomRightGrip"
        width: root.cornerGrip
        height: root.cornerGrip
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        cursorShape: Qt.SizeFDiagCursor
        onPressed: root.requestSystemResize(Qt.BottomEdge | Qt.RightEdge)
    }
}
