import QtQuick
import QtQuick.Controls
import illuminate.ui

pragma ComponentBehavior: Bound

Menu {
    id: root

    // an AppMenu.tree node: { label, children: [...] }
    property var node: null

    title: node ? node.label : ""
    popupType: Popup.Native
    Component.onCompleted: PopupCloser.watch(root)

    property var built: []

    Component {
        id: rowSource
        MenuItem {
            property var rowNode
            text: rowNode ? rowNode.label : ""
            enabled: rowNode ? rowNode.enabled : false
            checkable: rowNode ? rowNode.checked : false
            checked: rowNode ? rowNode.checked : false
            onTriggered: AppMenu.trigger(rowNode.id, rowNode.payload)
        }
    }

    Component {
        id: separatorSource
        MenuSeparator {}
    }

    // built when shown: the tree changes with tabs, bookmarks and spaces
    function build() {
        for (let i = root.built.length - 1; i >= 0; --i) {
            root.removeItem(root.built[i]);
            root.built[i].destroy();
        }
        root.built = [];

        const list = root.node ? (root.node.children || []) : [];
        for (let i = 0; i < list.length; ++i) {
            const child = list[i];
            const item = (child.kind === "separator" ? separatorSource : rowSource).createObject(null);
            if (!item)
                continue;
            if (child.kind !== "separator")
                item.rowNode = child;
            root.insertItem(root.built.length, item);
            root.built.push(item);
        }
    }

    onAboutToShow: build()
}
