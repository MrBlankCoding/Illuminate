#include "SidebarModel.h"
#include "BrowserTab.h"
#include "TabModel.h"

#include <QClipboard>
#include <QFile>
#include <QGuiApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QQueue>
#include <QSaveFile>
#include <QSet>
#include <QStringList>
#include <QUuid>

#include <algorithm>
#include <climits>
#include <map>
#include <utility>

namespace {
const QString kHeaderId = QStringLiteral("__header__");
const QUrl kNewTabUrl(QStringLiteral("newtab://newtab"));
QString newId() { return QUuid::createUuid().toString(QUuid::WithoutBraces); }
bool isPage(const QUrl &url)
{
    // a crash page stands in for the page; the tree keeps the page's address
    return url.isValid() && !url.isEmpty() && url != kNewTabUrl
           && !url.toString().startsWith(QLatin1String("illuminate://crashed"), Qt::CaseInsensitive);
}
}

int SidebarModel::rowOf(const QString &id) const
{
    const int row = m_rowIndex.value(id, -1);
    if (row >= 0)
        return row;
    const Node *node = m_nodes.value(id);
    return node && node->parent && node->parent->split ? m_rowIndex.value(node->parent->id, -1) : -1;
}

QVariantList SidebarModel::folders() const
{
    QVariantList list;
    const auto walk = [&list](const auto &self, const Node *parent, int depth) -> void {
        for (const auto &child : parent->children)
        {
            if (!child->folder)
                continue;
            list.append(QVariantMap{
                {QStringLiteral("id"), child->id},
                {QStringLiteral("title"), child->title},
                {QStringLiteral("icon"), child->icon},
                {QStringLiteral("depth"), depth},
            });
            self(self, child.get(), depth + 1);
        }
    };
    walk(walk, &m_root, 0);
    return list;
}

// folders

void SidebarModel::toggleFolder(const QString &id)
{
    if (Node *node = m_nodes.value(id); node && node->folder)
        setExpanded(id, !node->expanded);
}

void SidebarModel::setExpanded(const QString &id, bool expanded, bool recursive)
{
    Node *node = m_nodes.value(id);
    if (!node || !node->folder)
        return;
    const auto apply = [expanded, recursive](const auto &self, Node *folder) -> void {
        folder->expanded = expanded;
        if (!recursive)
            return;
        for (const auto &child : folder->children)
        {
            if (child->folder)
                self(self, child.get());
        }
    };
    apply(apply, node);
    commit();
}

QString SidebarModel::createFolder(const QString &parentId, const QString &title)
{
    Node *parent = folderOrRoot(parentId);
    if (!parent)
        return {};

    auto node = std::make_unique<Node>();
    node->id = newId();
    node->folder = true;
    node->title = title.trimmed().isEmpty() ? QStringLiteral("New Folder") : title.trimmed();
    const QString id = node->id;
    m_nodes.insert(id, node.get());
    insert(std::move(node), parent, INT_MAX);
    parent->expanded = true;
    commit();
    return id;
}

void SidebarModel::renameFolder(const QString &id, const QString &title)
{
    Node *node = m_nodes.value(id);
    const QString trimmed = title.trimmed();
    if (!node || !node->folder || trimmed.isEmpty() || node->title == trimmed)
        return;
    node->title = trimmed;
    const int row = rowOf(id);
    if (row >= 0)
        emit dataChanged(index(row), index(row), {TitleRole});
    scheduleSave();
}

void SidebarModel::setFolderIcon(const QString &id, const QString &icon)
{
    Node *node = m_nodes.value(id);
    if (!node || !node->folder || node->icon == icon)
        return;
    node->icon = icon;
    const int row = rowOf(id);
    if (row >= 0)
        emit dataChanged(index(row), index(row), {IconRole});
    scheduleSave();
}

QString SidebarModel::moveToNewFolder(const QString &id)
{
    Node *node = m_nodes.value(id);
    if (node && node->folder)
        return {};
    if (!node && !findTab(id))
        return {};

    // a subfolder where the tab was, or a folder at the end of the list
    Node *parent = node ? node->parent : &m_root;
    const QString folderId = createFolder(parent->id);
    if (node)
        moveNode(folderId, parent->id, indexInParent(node));
    moveNode(id, folderId, INT_MAX);
    return folderId;
}

// moving

bool SidebarModel::moveNode(const QString &id, const QString &newParentId, int newIndex)
{
    Node *parent = folderOrRoot(newParentId);
    if (!parent)
        return false;

    Node *node = m_nodes.value(id);
    if ((!node || !node->folder) && parent == &m_root)
        return false;
    if (!node)
    {
        BrowserTab *tab = findTab(id);
        if (!tab)
            return false;
        file(tab, parent, newIndex);
        commit();
        return true;
    }

    if (node->folder && (node == parent || isAncestor(node, parent)))
        return false;
    insert(detach(node), parent, newIndex);
    commit();
    return true;
}

bool SidebarModel::canDrop(const QString &id, const QString &targetId, int position) const
{
    if (id == targetId || id == kHeaderId)
        return false;
    const Node *node = m_nodes.value(id);
    const bool folder = node && node->folder;
    const Node *target = m_nodes.value(targetId);
    if (position == Into && targetId != kHeaderId)
    {
        if (!target || !target->folder)
        {
            if (folder || (node && node->split) || isSplitTab(id) || isSplitTab(targetId))
                return false;
            BrowserTab *draggedTab = findTab(id);
            BrowserTab *targetTab = findTab(targetId);
            return draggedTab && targetTab && draggedTab != targetTab;
        }
    }
    if (!node && !findTab(id))
        return false;

    // above the header is the end of the folders; below it, the loose tabs
    if (targetId == kHeaderId)
        return folder ? position == Before : position != Before;

    if (!target)
        return !folder && findTab(targetId) != nullptr;
    if (position == Into && !target->folder)
        return false;
    const Node *dest = position == Into ? target : target->parent;
    if (!folder)
        return dest != &m_root;
    return dest != node && !isAncestor(node, dest);
}

bool SidebarModel::drop(const QString &id, const QString &targetId, int position)
{
    if (!canDrop(id, targetId, position))
        return false;

    const Node *targetNode = m_nodes.value(targetId);
    if (position == Into)
    {
        if (targetNode && targetNode->folder)
            return moveNode(id, targetId, INT_MAX);
        return !createSplit(targetId, id).isEmpty();
    }

    if (targetId == kHeaderId)
    {
        if (position == Before)
            return moveNode(id, {}, INT_MAX);
        return moveOut(id, firstLooseTab(findTab(id)), false);
    }

    Node *target = m_nodes.value(targetId);
    if (!target)
        return moveOut(id, findTab(targetId), position == After);
    if (position == Into)
        return moveNode(id, targetId, INT_MAX);

    int at = indexInParent(target);
    const Node *node = m_nodes.value(id);
    if (node && node->parent == target->parent && indexInParent(node) < at)
        --at;
    if (position == After)
        ++at;
    return moveNode(id, target->parent->id, at);
}

// out of its folder, next to anchor among the loose tabs
bool SidebarModel::moveOut(const QString &id, BrowserTab *anchor, bool after)
{
    Node *node = m_nodes.value(id);
    if (node && node->folder)
        return false;
    BrowserTab *tab = node ? node->tab.data() : findTab(id);
    if (!tab)
        return false;

    if (node)
    {
        forget(node);
        detach(node);
        scheduleSave();
    }

    if (anchor && anchor != tab)
    {
        const int from = m_tabs->indexOf(tab);
        int to = m_tabs->indexOf(anchor);
        if (from < to && !after)
            --to;
        else if (from > to && after)
            ++to;
        m_tabs->moveTab(from, to);
    }
    commit();
    return true;
}

void SidebarModel::addToFolder(const QString &id, const QString &folderId)
{
    moveNode(id, folderId, INT_MAX);
}

void SidebarModel::removeFromFolder(const QString &id)
{
    BrowserTab *tab = findTab(id);
    if (tab && isInFolder(tab))
        moveOut(id, firstLooseTab(tab), false);
}

// tab lifecycle

void SidebarModel::deleteNode(const QString &id, bool keepTabs)
{
    Node *node = m_nodes.value(id);
    if (!node)
    {
        // a loose tab
        closeTab(findTab(id));
        return;
    }

    QList<BrowserTab *> doomed;
    if (node->folder && keepTabs)
    {
        Node *parent = node->parent;
        int at = indexInParent(node);
        while (!node->children.empty())
        {
            Node *child = node->children.front().get();
            // tabs only sit in folders; at the top they're just open tabs
            if (!child->folder && parent == &m_root)
            {
                forget(child);
                detach(child);
                continue;
            }
            insert(detach(child), parent, ++at);
        }
    }
    else
    {
        collectTabs(node, doomed);
    }

    forget(node);
    detach(node);
    commit();
    for (BrowserTab *tab : doomed)
        closeTab(tab);
}

void SidebarModel::newTabInFolder(const QString &folderId)
{
    Node *folder = m_nodes.value(folderId);
    if (!folder || !folder->folder)
        return;
    BrowserTab *tab = m_tabs->addTab(kNewTabUrl);
    if (!tab)
        return;
    file(tab, folder, INT_MAX);
    for (Node *n = folder; n && n != &m_root; n = n->parent)
        n->expanded = true;
    commit();
    m_tabs->setActiveIndex(m_tabs->indexOf(tab));
    emit newTabOpened();
}

void SidebarModel::closeFolderTabs(const QString &folderId)
{
    const Node *folder = m_nodes.value(folderId);
    if (!folder || !folder->folder)
        return;
    QList<BrowserTab *> tabs;
    collectTabs(folder, tabs);
    for (BrowserTab *tab : tabs)
        closeTab(tab);
}

void SidebarModel::copyLink(const QString &id)
{
    const BrowserTab *tab = findTab(id);
    if (!tab || !isPage(tab->url()))
        return;
    if (QClipboard *clipboard = QGuiApplication::clipboard())
    {
        clipboard->setText(tab->url().toString());
        emit linkCopied(tab->url().toString());
    }
}

// keeps what gets written out current with the live tab
void SidebarModel::syncFromTab(BrowserTab *tab)
{
    Node *node = m_nodes.value(tab->id());
    if (!node || node->folder || tab->suspended())
        return;

    bool changed = false;
    if (isPage(tab->url()) && tab->url() != node->url)
    {
        node->url = tab->url();
        changed = true;
    }
    if (!tab->title().isEmpty() && tab->title() != node->title)
    {
        node->title = tab->title();
        changed = true;
    }
    if (!tab->iconUrl().isEmpty() && tab->iconUrl() != node->iconUrl)
    {
        node->iconUrl = tab->iconUrl();
        changed = true;
    }
    if (changed)
        scheduleSave();
}

// "New Tab in Folder" left on the new tab page closes once it's left
void SidebarModel::leaveTab(BrowserTab *tab)
{
    const Node *node = m_nodes.value(tab->id());
    if (!node || node->folder || (node->parent && node->parent->split) || tab->url() != kNewTabUrl)
        return;
    // not from inside the TabModel's own signal
    QMetaObject::invokeMethod(this, [this, tab = QPointer<BrowserTab>(tab)]() {
        if (tab && tab != activeTab() && tab->url() == kNewTabUrl && isInFolder(tab))
            closeTab(tab);
    }, Qt::QueuedConnection);
}

void SidebarModel::closeTab(BrowserTab *tab)
{
    if (!tab || m_tabs->indexOf(tab) < 0)
        return;
    // a live page gets its "Leave site?" first; once it agrees, the
    // controller closes the tab (BrowserController::onTabCloseApproved)
    if (tab->requestClose())
        return;
    if (tab == activeTab())
    {
        const int next = m_tabs->nearestLiveIndex(m_tabs->indexOf(tab));
        if (next >= 0)
            m_tabs->setActiveIndex(next);
        else
            emit newTabRequested();
    }
    m_tabs->removeTab(m_tabs->indexOf(tab));
}
