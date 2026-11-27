#pragma once

#include <QAbstractListModel>
#include <QHash>
#include <QPair>
#include <QPointer>
#include <QTimer>
#include <QUrl>
#include <QVariantList>
#include <QVector>
#include <QtQml/qqmlregistration.h>

#include <memory>
#include <vector>

class BrowserTab;
class TabModel;

class SidebarModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Use Browser.sidebar")
    Q_PROPERTY(int folderCount READ folderCount NOTIFY folderCountChanged)
    Q_PROPERTY(QString headerId READ headerId CONSTANT)
    Q_PROPERTY(int structureRevision READ structureRevision NOTIFY structureChanged)

public:
    enum Roles
    {
        NodeIdRole = Qt::UserRole + 1,
        KindRole,  // "folder" | "split" | "tab" | "header"
        DepthRole,
        ParentIdRole,
        TitleRole,
        UrlRole,
        IconUrlRole,
        IconRole,  // folder emoji; empty means the folder glyph
        ExpandedRole,
        LoadingRole,
        SuspendedRole,
        ActiveRole,
        TabIndexRole,
        InFolderRole,
        PeekRole,
        TabCountRole,
        SplitTabsRole,
        SplitTitleRole,
        SplitMembersRole,
        AudibleRole,
        MutedRole,
        ActivityRole,
    };

    enum DropPosition
    {
        Before,
        After,
        Into,
    };
    Q_ENUM(DropPosition)

    explicit SidebarModel(TabModel *tabs, QObject *parent = nullptr);
    ~SidebarModel() override;

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    // Reads the folders, splits and the tabs filed in them. restoreTabs: add
    // those tabs to the TabModel, suspended. Otherwise the tabs are already
    // there (a space coming back with its tabs still in memory) and each is
    // found by the id it was saved under; ones no longer around are dropped.
    void load(const QString &filePath, bool restoreTabs = true);
    // writes the folders and forgets them; the tabs stay in the TabModel
    void unload();
    void saveNow();

    bool isInFolder(const BrowserTab *tab) const;
    // TabModel indices in the order the sidebar shows them
    QList<int> visualTabOrder() const;
    int folderCount() const;
    QString headerId() const;
    int structureRevision() const { return m_structureRevision; }

    Q_INVOKABLE void toggleFolder(const QString &id);
    Q_INVOKABLE void setExpanded(const QString &id, bool expanded, bool recursive = false);
    // returns the new folder's id
    Q_INVOKABLE QString createFolder(const QString &parentId = {}, const QString &title = {});
    Q_INVOKABLE void renameFolder(const QString &id, const QString &title);
    Q_INVOKABLE void setFolderIcon(const QString &id, const QString &icon);
    // newIndex counts siblings after the node has left its old place.
    // only folders sit at the top level; tabs always go inside one
    Q_INVOKABLE bool moveNode(const QString &id, const QString &newParentId, int newIndex);
    Q_INVOKABLE bool canDrop(const QString &id, const QString &targetId, int position) const;
    Q_INVOKABLE bool drop(const QString &id, const QString &targetId, int position);
    // a folder with keepTabs moves its contents up to where it was
    Q_INVOKABLE void deleteNode(const QString &id, bool keepTabs = false);
    Q_INVOKABLE void addToFolder(const QString &id, const QString &folderId);
    Q_INVOKABLE void removeFromFolder(const QString &id);
    // returns the new folder's id
    Q_INVOKABLE QString moveToNewFolder(const QString &id);
    Q_INVOKABLE void newTabInFolder(const QString &folderId);
    Q_INVOKABLE void closeFolderTabs(const QString &folderId);
    Q_INVOKABLE QString createSplit(const QString &firstTabId, const QString &secondTabId);
    Q_INVOKABLE QVariantList splitTabs(const QString &id) const;
    Q_INVOKABLE bool isSplitTab(const QString &id) const;
    Q_INVOKABLE void prepareSplit(const QString &id);
    Q_INVOKABLE void separateSplit(const QString &id);
    Q_INVOKABLE bool separateSplitTab(const QString &tabId);
    Q_INVOKABLE void copyLink(const QString &id);
    Q_INVOKABLE int rowOf(const QString &id) const;
    // the folder a tab is filed in and its place there; empty when it's loose
    // or half of a split
    QPair<QString, int> placementOf(const QString &tabId) const;
    // [{id, title, icon, depth}] depth-first, for "Add to Folder" menus
    Q_INVOKABLE QVariantList folders() const;

signals:
    void folderCountChanged();
    void structureChanged();
    // a tab is going away and nothing live is left to show
    void newTabRequested();
    // a tab was opened for the user to type into
    void newTabOpened();
    // "Copy Link" put a tab's address on the clipboard
    void linkCopied(const QString &url);

private:
    struct Node
    {
        QString id;
        bool folder = false;
        bool split = false;
        Node *parent = nullptr;
        std::vector<std::unique_ptr<Node>> children;
        QString title;
        QString icon;
        bool expanded = true;
        QPointer<BrowserTab> tab;
        // the tab's last page, written out so the folder survives a restart
        QUrl url;
        QString iconUrl;
    };

    enum class Kind
    {
        Folder,
        Split,
        Tab,
        Header,
    };

    struct Row
    {
        QString key;
        Kind kind = Kind::Tab;
        int depth = 0;
        QPointer<BrowserTab> tab;
        bool peek = false;
    };

    Node *folderOrRoot(const QString &id) const;
    BrowserTab *findTab(const QString &id) const;
    BrowserTab *activeTab() const;
    static bool isAncestor(const Node *ancestor, const Node *node);
    static int indexInParent(const Node *node);
    static int countTabs(const Node *node);
    static void collectTabs(const Node *node, QList<BrowserTab *> &out);
    std::unique_ptr<Node> detach(Node *node);
    void insert(std::unique_ptr<Node> node, Node *parent, int index);
    void forget(Node *node);
    Node *file(BrowserTab *tab, Node *parent, int index);
    bool moveOut(const QString &id, BrowserTab *anchor, bool after);
    BrowserTab *firstLooseTab(const BrowserTab *excluding) const;
    void closeTab(BrowserTab *tab);
    void leaveTab(BrowserTab *tab);
    void syncFromTab(BrowserTab *tab);

    void collectRows(QVector<Row> &out, const Node *node, int depth) const;
    void rebuild();
    void commit();
    void scheduleSave();

    TabModel *m_tabs;
    Node m_root;
    QHash<QString, Node *> m_nodes;
    QVector<Row> m_rows;
    QHash<QString, int> m_rowIndex;
    QPointer<BrowserTab> m_lastActive;
    QString m_path;
    QTimer m_saveTimer;
    int m_folderCount = 0;
    int m_structureRevision = 0;
};
