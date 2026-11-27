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

namespace
{
const QString kHeaderId = QStringLiteral("__header__");
const QUrl kNewTabUrl(QStringLiteral("newtab://newtab"));
constexpr int kSaveDelayMs = 300;

QString newId()
{
    return QUuid::createUuid().toString(QUuid::WithoutBraces);
}

// a page worth keeping: not the blank new tab page
bool isPage(const QUrl &url)
{
    return url.isValid() && !url.isEmpty() && url != kNewTabUrl;
}
}

SidebarModel::SidebarModel(TabModel *tabs, QObject *parent)
    : QAbstractListModel(parent), m_tabs(tabs)
{
    m_root.folder = true;

    m_saveTimer.setSingleShot(true);
    m_saveTimer.setInterval(kSaveDelayMs);
    connect(&m_saveTimer, &QTimer::timeout, this, &SidebarModel::saveNow);
    connect(m_tabs, &TabModel::rowsAboutToBeRemoved, this, [this](const QModelIndex &, int first, int last) {
        for (int i = first; i <= last; ++i)
        {
            BrowserTab *tab = m_tabs->tabAt(i);
            Node *node = tab ? m_nodes.value(tab->id()) : nullptr;
            if (node && !node->folder)
            {
                Node *split = node->parent && node->parent->split ? node->parent : nullptr;
                forget(node);
                detach(node);
                if (split && split->children.size() <= 1)
                {
                    if (!split->children.empty())
                    {
                        Node *survivor = split->children.front().get();
                        forget(survivor);
                        detach(survivor);
                    }
                    forget(split);
                    detach(split);
                }
                scheduleSave();
            }
        }
    });
    connect(m_tabs, &TabModel::rowsRemoved, this, &SidebarModel::rebuild);
    connect(m_tabs, &TabModel::rowsInserted, this, &SidebarModel::rebuild);
    connect(m_tabs, &TabModel::rowsMoved, this, &SidebarModel::rebuild);
    connect(m_tabs, &TabModel::modelReset, this, &SidebarModel::rebuild);
    connect(m_tabs, &TabModel::activeIndexChanged, this, [this]() {
        BrowserTab *previous = m_lastActive;
        m_lastActive = activeTab();
        if (previous && previous != m_lastActive)
            leaveTab(previous);
        rebuild();
    });

    connect(m_tabs, &TabModel::dataChanged, this,
            [this](const QModelIndex &topLeft, const QModelIndex &bottomRight, const QList<int> &roles) {
        QList<int> mapped;
        for (const int role : roles)
        {
            switch (role)
            {
            case TabModel::TitleRole:
                mapped << TitleRole;
                break;
            case TabModel::UrlRole:
                mapped << UrlRole;
                break;
            case TabModel::IconUrlRole:
                mapped << IconUrlRole;
                break;
            case TabModel::LoadingRole:
                mapped << LoadingRole;
                break;
            case TabModel::SuspendedRole:
                mapped << SuspendedRole;
                break;
            case TabModel::AudibleRole:
                mapped << AudibleRole;
                break;
            case TabModel::MutedRole:
                mapped << MutedRole;
                break;
            case TabModel::ActivityRole:
                mapped << ActivityRole;
                break;
            }
        }
        bool urlChanged = false;
        for (int i = topLeft.row(); i <= bottomRight.row(); ++i)
        {
            BrowserTab *tab = m_tabs->tabAt(i);
            if (!tab)
                continue;
            syncFromTab(tab);
            urlChanged = urlChanged || roles.contains(TabModel::UrlRole);
            if (mapped.isEmpty())
                continue;
            const int row = m_rowIndex.value(tab->id(), -1);
            if (row >= 0)
                emit dataChanged(index(row), index(row), mapped);
            else if (Node *member = m_nodes.value(tab->id()); member && member->parent && member->parent->split)
            {
                const int groupRow = m_rowIndex.value(member->parent->id, -1);
                if (groupRow >= 0)
                {
                    QList<int> groupRoles = mapped;
                    groupRoles << SplitTitleRole << SplitMembersRole << TitleRole;
                    emit dataChanged(index(groupRow), index(groupRow), groupRoles);
                }
            }
        }
        // Loose tabs stay hidden while they are on the internal blank page.
        // When the command bar navigates one, add its sidebar row immediately.
        if (urlChanged)
            rebuild();
    });

    rebuild();
}

SidebarModel::~SidebarModel()
{
    if (m_saveTimer.isActive())
        saveNow();
}

// QAbstractListModel interface

int SidebarModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid())
        return 0;
    return m_rows.size();
}

QVariant SidebarModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_rows.size())
        return {};

    const Row &row = m_rows.at(index.row());
    // a folder or a tab in one; null for loose tabs and the header
    const Node *node = m_nodes.value(row.key);

    switch (role)
    {
    case NodeIdRole:
        return row.key;
    case KindRole:
        return row.kind == Kind::Folder ? QStringLiteral("folder")
             : row.kind == Kind::Split  ? QStringLiteral("split")
             : row.kind == Kind::Tab    ? QStringLiteral("tab")
                                        : QStringLiteral("header");
    case DepthRole:
        return row.depth;
    case PeekRole:
        return row.peek;
    case ParentIdRole:
        return node && node->parent ? node->parent->id : QString();
    case InFolderRole:
        return row.kind == Kind::Tab && node != nullptr;
    case SplitTabsRole:
        if (node && node->split)
        {
            QVariantList ids;
            for (const auto &child : node->children)
                if (child->tab)
                    ids.append(child->id);
            return ids;
        }
        return {};
    case SplitTitleRole:
        if (node && node->split)
        {
            QStringList titles;
            for (const auto &child : node->children)
                if (child->tab)
                    titles << (child->tab->title().isEmpty() ? QStringLiteral("New Tab") : child->tab->title());
            return titles.join(QStringLiteral("  ·  "));
        }
        return QString();
    case SplitMembersRole:
        if (node && node->split)
        {
            QVariantList members;
            for (const auto &child : node->children)
            {
                if (!child->tab)
                    continue;
                members.append(QVariantMap{
                    {QStringLiteral("id"), child->id},
                    {QStringLiteral("title"), child->tab->title().isEmpty()
                        ? QStringLiteral("New Tab") : child->tab->title()},
                    {QStringLiteral("iconUrl"), child->tab->iconUrl().isEmpty()
                        ? child->iconUrl : child->tab->iconUrl()},
                    {QStringLiteral("active"), child->tab == activeTab()},
                });
            }
            return members;
        }
        return {};
    case ActiveRole:
        if (node && node->split)
            return std::any_of(node->children.begin(), node->children.end(), [this](const auto &child) {
                return child->tab && child->tab == activeTab();
            });
        break;
    }

    if (row.kind == Kind::Folder || row.kind == Kind::Split)
    {
        if (!node)
            return {};
        switch (role)
        {
        case TitleRole:
            if (node->split && !node->children.empty())
                return node->children.front()->tab ? node->children.front()->tab->title() : QStringLiteral("Split View");
            return node->title;
        case IconRole:
            return node->icon;
        case ExpandedRole:
            return node->expanded;
        case TabCountRole:
            return countTabs(node);
        }
        return {};
    }

    const BrowserTab *tab = row.tab;
    if (row.kind != Kind::Tab || !tab)
        return {};

    switch (role)
    {
    case TitleRole:
        if (!tab->title().isEmpty())
            return tab->title();
        if (node && !node->title.isEmpty())
            return node->title;
        return QStringLiteral("New Tab");
    case UrlRole:
        return tab->url();
    case IconUrlRole:
        return tab->iconUrl().isEmpty() && node ? node->iconUrl : tab->iconUrl();
    case LoadingRole:
        return tab->loading();
    case SuspendedRole:
        return tab->suspended();
    case AudibleRole:
        return tab->audible();
    case MutedRole:
        return tab->muted();
    case ActivityRole:
        return tab->hasActivity();
    case ActiveRole:
        return tab == activeTab();
    case TabIndexRole:
        return m_tabs->indexOf(tab);
    }
    return {};
}

QHash<int, QByteArray> SidebarModel::roleNames() const
{
    static const QHash<int, QByteArray> roles = {
        {NodeIdRole, "nodeId"},
        {KindRole, "kind"},
        {DepthRole, "depth"},
        {ParentIdRole, "parentId"},
        {TitleRole, "title"},
        {UrlRole, "url"},
        {IconUrlRole, "iconUrl"},
        {IconRole, "icon"},
        {ExpandedRole, "expanded"},
        {LoadingRole, "loading"},
        {SuspendedRole, "suspended"},
        {ActiveRole, "active"},
        {TabIndexRole, "tabIndex"},
        {InFolderRole, "inFolder"},
        {PeekRole, "peek"},
        {TabCountRole, "tabCount"},
        {SplitTabsRole, "splitTabs"},
        {SplitTitleRole, "splitTitle"},
        {AudibleRole, "audible"},
        {MutedRole, "muted"},
        {ActivityRole, "hasActivity"},
        {SplitMembersRole, "splitMembers"},
    };
    return roles;
}

// queries

bool SidebarModel::isInFolder(const BrowserTab *tab) const
{
    const Node *node = tab ? m_nodes.value(tab->id()) : nullptr;
    return node && !node->folder;
}

QList<int> SidebarModel::visualTabOrder() const
{
    QList<int> order;
    for (const Row &row : m_rows)
    {
        if (row.kind == Kind::Tab && row.tab)
            order << m_tabs->indexOf(row.tab);
        else if (row.kind == Kind::Split)
        {
            const Node *group = m_nodes.value(row.key);
            if (group)
                for (const auto &child : group->children)
                    if (child->tab)
                        order << m_tabs->indexOf(child->tab);
        }
    }
    return order;
}

int SidebarModel::folderCount() const { return m_folderCount; }

QString SidebarModel::headerId() const { return kHeaderId; }
