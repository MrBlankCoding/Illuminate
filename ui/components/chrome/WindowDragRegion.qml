import QtQuick
import illuminate.ui

Item {
    id: root

    DragHandler {
        target: null
        onActiveChanged: {
            const win = root.Window.window;
            if (active && win)
                win.startSystemMove();
        }
    }

    TapHandler {
        gesturePolicy: TapHandler.DragThreshold
        onTapCountChanged: {
            if (tapCount !== 2)
                return;
            const win = root.Window.window;
            if (!win)
                return;
            win.visibility === Window.Maximized ? win.showNormal() : win.showMaximized();
        }
    }

    TapHandler {
        enabled: Qt.platform.os === "windows"
        acceptedButtons: Qt.RightButton
        onTapped: {
            const win = root.Window.window;
            if (win)
                WindowHelper.showSystemMenu(win);
        }
    }
}
