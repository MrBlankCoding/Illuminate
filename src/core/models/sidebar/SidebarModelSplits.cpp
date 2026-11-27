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
QString newId() { return QUuid::createUuid().toString(QUuid::WithoutBraces); }
}

QString SidebarModel::createSplit(const QString &firstTabId, const QString &secondTabId)
{
    BrowserTab *first = findTab(firstTabId);
    BrowserTab *second = findTab(secondTabId);
    if (!first || !second || first == second)
        return {};
    if (isSplitTab(firstTabId) || isSplitTab(secondTabId))
        return {};

    first->setSuspended(false);
    second->setSuspended(false);
    auto group = std::make_unique<Node>();
    group->id = newId();
    group->split = true;
    Node *raw = group.get();
    m_nodes.insert(raw->id, raw);

    // Members are lifted out of folders and placed in the requested order.
    for (BrowserTab *tab : {first, second})
    {
        Node *old = m_nodes.value(tab->id());
        if (old)
        {
            auto owned = detach(old);
            forget(owned.get());
        }
        auto child = std::make_unique<Node>();
        child->id = tab->id();
        child->tab = tab;
        child->title = tab->title();
        child->url = tab->url();
        child->iconUrl = tab->iconUrl();
        m_nodes.insert(child->id, child.get());
        insert(std::move(child), raw, INT_MAX);
    }
    insert(std::move(group), &m_root, INT_MAX);
    commit();
    m_tabs->setActiveIndex(m_tabs->indexOf(first));
    return raw->id;
}

QVariantList SidebarModel::splitTabs(const QString &id) const
{
    const Node *node = m_nodes.value(id);
    if (node && !node->split && node->parent && node->parent->split)
        node = node->parent;
    QVariantList result;
    if (!node || !node->split)
        return result;
    for (const auto &child : node->children)
        if (child->tab)
            result.append(child->id);
    return result;
}

bool SidebarModel::isSplitTab(const QString &id) const
{
    const Node *node = m_nodes.value(id);
    return node && !node->split && node->parent && node->parent->split;
}

void SidebarModel::prepareSplit(const QString &id)
{
    const Node *group = m_nodes.value(id);
    if (group && !group->split && group->parent && group->parent->split)
        group = group->parent;
    if (!group || !group->split)
        return;
    for (const auto &child : group->children)
        if (child->tab)
            child->tab->setSuspended(false);
}

void SidebarModel::separateSplit(const QString &id)
{
    Node *group = m_nodes.value(id);
    if (!group || !group->split || !group->parent)
        return;
    for (const auto &child : group->children)
        if (child->tab)
            child->tab->setSuspended(false);
    forget(group);
    detach(group);
    commit();
}

bool SidebarModel::separateSplitTab(const QString &tabId)
{
    Node *member = m_nodes.value(tabId);
    Node *group = member && member->parent && member->parent->split ? member->parent : nullptr;
    if (!member || !group || !member->tab || group->children.size() != 2)
        return false;

    for (const auto &child : group->children)
        if (child->tab)
            child->tab->setSuspended(false);
    while (!group->children.empty())
    {
        Node *child = group->children.front().get();
        forget(child);
        detach(child);
    }
    forget(group);
    detach(group);
    commit();
    return true;
}
