import QtQuick
import illuminate.ui

pragma ComponentBehavior: Bound

// Opens the installed extensions, and the action popup of whichever one is
// picked, over the active page of |targetWindow|.
SidebarButton {
    id: root

    property Window targetWindow: null
    property string pageUrl: ""
    readonly property bool available: canRunOn(pageUrl)

    // Chrome keeps extensions off its own pages, other extensions' and the
    // Web Store; our internal pages have no browser for them at all
    function canRunOn(url) {
        const match = /^https?:\/\/([^\/?#:]+)/i.exec(url);
        if (!match)
            return false;
        const host = match[1].toLowerCase();
        return host !== "chromewebstore.google.com"
            && !/^https?:\/\/chrome\.google\.com\/webstore/i.test(url);
    }

    visible: available
    onAvailableChanged: {
        if (!available) {
            menu.close();
            actionPopup.dismiss();
        }
    }

    icon: "qrc:/illuminate/ui/icons/puzzle.svg"
    iconSize: 15
    active: menu.visible || actionPopup.visible

    // top left of where popups go, in |host|: just inside the page, level
    // with the button, and clear of the sidebar even when it overlays the page
    function popupOrigin(host) {
        const page = root.targetWindow ? root.targetWindow["activeWebView"] : null; // qmllint disable missing-property
        const pageLeft = page && page.visible ? page.mapToItem(host, 0, 0).x + Theme.space2 : 0;
        const sidebarRight = root.mapToItem(host, root.width, 0).x + Theme.cardMargin + Theme.space2;
        return Qt.point(Math.max(pageLeft, sidebarRight), root.mapToItem(host, 0, 0).y);
    }

    onClicked: {
        const host = root.targetWindow ? root.targetWindow.contentItem : null;
        if (!host)
            return;
        const origin = root.popupOrigin(host);
        menu.x = origin.x;
        menu.y = origin.y;
        menu.open();
    }

    Accessible.role: Accessible.Button
    Accessible.name: qsTr("Extensions")

    ExtensionsMenu {
        id: menu
        parent: root.targetWindow ? root.targetWindow.contentItem : root
        onPopupRequested: extension => {
            const host = root.targetWindow ? root.targetWindow.contentItem : null;
            if (!host)
                return;
            const page = root.targetWindow["activeWebView"]; // qmllint disable missing-property
            const origin = root.popupOrigin(host);
            actionPopup.show(extension,
                             page && page.browserId > 0 ? page.browserId : -1,
                             host.mapToGlobal(origin.x, origin.y));
        }
    }

    ExtensionActionPopup {
        id: actionPopup
        transientParent: root.targetWindow
    }
}
