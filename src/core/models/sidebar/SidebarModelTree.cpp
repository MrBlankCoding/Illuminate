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
bool isPage(const QUrl &url) { return url.isValid() && !url.isEmpty() && url != kNewTabUrl; }
}

// tree helpers

SidebarModel::Node *SidebarModel::folderOrRoot(const QString &id) const
{
    if (id.isEmpty())
        return const_cast<Node *>(&m_root);
    Node *node = m_nodes.value(id);
    return node && node->folder ? node : nullptr;
}

BrowserTab *SidebarModel::findTab(const QString &id) const
{
    if (const Node *node = m_nodes.value(id); node && !node->folder)
        return node->tab;
    for (int i = 0; i < m_tabs->rowCount(); ++i)
    {
        if (BrowserTab *tab = m_tabs->tabAt(i); tab->id() == id)
            return tab;
    }
    return nullptr;
}

BrowserTab *SidebarModel::activeTab() const
{
    return m_tabs->tabAt(m_tabs->activeIndex());
}

bool SidebarModel::isAncestor(const Node *ancestor, const Node *node)
{
    for (const Node *n = node ? node->parent : nullptr; n; n = n->parent)
    {
        if (n == ancestor)
            return true;
    }
    return false;
}

int SidebarModel::indexInParent(const Node *node)
{
    const auto &siblings = node->parent->children;
    for (size_t i = 0; i < siblings.size(); ++i)
    {
        if (siblings[i].get() == node)
            return static_cast<int>(i);
    }
    return -1;
}

int SidebarModel::countTabs(const Node *node)
{
    int count = 0;
    for (const auto &child : node->children)
        count += (child->folder || child->split) ? countTabs(child.get()) : (child->tab ? 1 : 0);
    return count;
}

void SidebarModel::collectTabs(const Node *node, QList<BrowserTab *> &out)
{
    if (!node->folder && !node->split)
    {
        if (node->tab)
            out << node->tab;
        return;
    }
    for (const auto &child : node->children)
        collectTabs(child.get(), out);
}

std::unique_ptr<SidebarModel::Node> SidebarModel::detach(Node *node)
{
    auto &siblings = node->parent->children;
    const auto it = std::find_if(siblings.begin(), siblings.end(),
                                 [node](const auto &child) { return child.get() == node; });
    std::unique_ptr<Node> owned = std::move(*it);
    siblings.erase(it);
    owned->parent = nullptr;
    return owned;
}

void SidebarModel::insert(std::unique_ptr<Node> node, Node *parent, int index)
{
    auto &siblings = parent->children;
    const int at = std::clamp(index, 0, static_cast<int>(siblings.size()));
    node->parent = parent;
    siblings.insert(siblings.begin() + at, std::move(node));
}

// drops a subtree from the id index; the caller detaches it
void SidebarModel::forget(Node *node)
{
    m_nodes.remove(node->id);
    for (const auto &child : node->children)
        forget(child.get());
}

SidebarModel::Node *SidebarModel::file(BrowserTab *tab, Node *parent, int index)
{
    auto node = std::make_unique<Node>();
    node->id = tab->id();
    node->tab = tab;
    node->title = tab->title();
    node->iconUrl = tab->iconUrl();
    if (isPage(tab->url()))
        node->url = tab->url();
    Node *raw = node.get();
    m_nodes.insert(raw->id, raw);
    insert(std::move(node), parent, index);
    return raw;
}

BrowserTab *SidebarModel::firstLooseTab(const BrowserTab *excluding) const
{
    for (int i = 0; i < m_tabs->rowCount(); ++i)
    {
        BrowserTab *tab = m_tabs->tabAt(i);
        if (tab != excluding && !isInFolder(tab) && tab->url() != kNewTabUrl)
            return tab;
    }
    return nullptr;
}

// flattening

void SidebarModel::collectRows(QVector<Row> &out, const Node *node, int depth) const
{
    for (const auto &child : node->children)
    {
        if (child->split)
            continue;
        if (!child->folder)
        {
            if (child->tab)
                out.append(Row{child->id, Kind::Tab, depth, child->tab, false});
            continue;
        }

        out.append(Row{child->id, Kind::Folder, depth, nullptr, false});
        if (child->expanded)
        {
            collectRows(out, child.get(), depth + 1);
        }
    }
}

void SidebarModel::rebuild()
{
    QVector<Row> next;
    collectRows(next, &m_root, 0);
    next.append(Row{kHeaderId, Kind::Header, 0, nullptr, false});
    QSet<QString> emittedSplits;
    for (int i = 0; i < m_tabs->rowCount(); ++i)
    {
        BrowserTab *tab = m_tabs->tabAt(i);
        Node *tabNode = m_nodes.value(tab->id());
        if (tabNode && tabNode->parent && tabNode->parent->split)
        {
            const QString splitId = tabNode->parent->id;
            if (!emittedSplits.contains(splitId))
            {
                next.append(Row{splitId, Kind::Split, 0, nullptr, false});
                emittedSplits.insert(splitId);
            }
            continue;
        }
        // Blank command-bar tabs stay hidden until they navigate somewhere.
        if (!isInFolder(tab) && tab->url() != kNewTabUrl)
            next.append(Row{tab->id(), Kind::Tab, 0, tab, false});
    }

    // turn the old rows into the new ones a row at a time, so the view can
    // animate what actually came, went and moved
    QSet<QString> keep;
    for (const Row &row : next)
        keep.insert(row.key);
    for (int i = m_rows.size() - 1; i >= 0; --i)
    {
        if (keep.contains(m_rows.at(i).key))
            continue;
        beginRemoveRows({}, i, i);
        m_rows.removeAt(i);
        endRemoveRows();
    }
    QHash<QString, int> oldRowPositions;
    oldRowPositions.reserve(m_rows.size());
    for (int row = 0; row < m_rows.size(); ++row)
        oldRowPositions.insert(m_rows.at(row).key, row);

    for (int i = 0; i < next.size(); ++i)
    {
        if (i < m_rows.size() && m_rows.at(i).key == next.at(i).key)
        {
            m_rows[i] = next.at(i);
            continue;
        }
        int from = oldRowPositions.value(next.at(i).key, -1);
        if (from < i || from >= m_rows.size() || m_rows.at(from).key != next.at(i).key)
            from = -1;
        if (from >= 0)
        {
            const QString movedKey = m_rows.at(from).key;
            beginMoveRows({}, from, from, {}, i);
            m_rows.move(from, i);
            m_rows[i] = next.at(i);
            oldRowPositions[movedKey] = i;
            for (int row = i + 1; row <= from; ++row)
                oldRowPositions[m_rows.at(row).key] = row;
            endMoveRows();
        }
        else
        {
            beginInsertRows({}, i, i);
            m_rows.insert(i, next.at(i));
            for (int row = i; row < m_rows.size(); ++row)
                oldRowPositions[m_rows.at(row).key] = row;
            endInsertRows();
        }
    }

    m_rowIndex.clear();
    for (int i = 0; i < m_rows.size(); ++i)
        m_rowIndex.insert(m_rows.at(i).key, i);

    // depth, activity and counts can change under rows that stayed put
    if (!m_rows.isEmpty())
        emit dataChanged(index(0), index(m_rows.size() - 1));

    const int folders = static_cast<int>(std::count_if(m_root.children.begin(), m_root.children.end(),
        [](const auto &child) { return child->folder; }));
    if (folders != m_folderCount)
    {
        m_folderCount = folders;
        emit folderCountChanged();
    }
    ++m_structureRevision;
    emit structureChanged();
}

void SidebarModel::commit()
{
    rebuild();
    scheduleSave();
}
