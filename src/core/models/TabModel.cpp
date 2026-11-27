#include "TabModel.h"
#include "BrowserTab.h"

#include <QtAlgorithms>

#include <algorithm>
#include <utility>

TabModel::TabModel(QObject *parent)
    : QAbstractListModel(parent)
{
    connect(this, &TabModel::activeIndexChanged, this, [this]() {
        if (BrowserTab *tab = tabAt(m_activeIndex))
            tab->setSuspended(false);
    });
}

int TabModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid())
        return 0;
    return m_tabs.size();
}

QVariant TabModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_tabs.size())
        return {};

    const BrowserTab *tab = m_tabs.at(index.row());
    switch (role)
    {
    case IdRole:
        return tab->id();
    case TitleRole:
        return tab->title().isEmpty() ? QStringLiteral("New Tab") : tab->title();
    case UrlRole:
        return tab->url();
    case IconUrlRole:
        return tab->iconUrl();
    case ProgressRole:
        return tab->progress();
    case LoadingRole:
        return tab->loading();
    case RenderPidRole:
        return tab->renderProcessPid();
    case SuspendedRole:
        return tab->suspended();
    case AudibleRole:
        return tab->audible();
    case MutedRole:
        return tab->muted();
    case ActivityRole:
        return tab->hasActivity();
    }
    return {};
}

QHash<int, QByteArray> TabModel::roleNames() const
{
    static const QHash<int, QByteArray> roles = {
        {IdRole, "id"},
        {TitleRole, "title"},
        {UrlRole, "url"},
        {IconUrlRole, "iconUrl"},
        {ProgressRole, "progress"},
        {LoadingRole, "loading"},
        {RenderPidRole, "renderPid"},
        {SuspendedRole, "suspended"},
        {AudibleRole, "audible"},
        {MutedRole, "muted"},
        {ActivityRole, "hasActivity"},
    };
    return roles;
}

BrowserTab *TabModel::addTab(const QUrl &url, bool suspended)
{
    if (m_tabs.size() >= kMaxTabs)
        return nullptr;

    const int row = m_tabs.size();
    beginInsertRows({}, row, row);

    auto *tab = new BrowserTab(this);

    connect(tab, &BrowserTab::titleChanged, this, [this, tab]() { refreshTab(tab, TitleRole); });
    connect(tab, &BrowserTab::urlChanged, this, [this, tab]() { refreshTab(tab, UrlRole); });
    connect(tab, &BrowserTab::iconUrlChanged, this, [this, tab]() { refreshTab(tab, IconUrlRole); });
    connect(tab, &BrowserTab::progressChanged, this, [this, tab]() { refreshTab(tab, ProgressRole); });
    connect(tab, &BrowserTab::loadingChanged, this, [this, tab]() { refreshTab(tab, LoadingRole); });
    connect(tab, &BrowserTab::renderProcessPidChanged, this, [this, tab]() { refreshTab(tab, RenderPidRole); });
    connect(tab, &BrowserTab::suspendedChanged, this, [this, tab]() { refreshTab(tab, SuspendedRole); });
    connect(tab, &BrowserTab::audibleChanged, this, [this, tab]() { refreshTab(tab, AudibleRole); });
    connect(tab, &BrowserTab::mutedChanged, this, [this, tab]() { refreshTab(tab, MutedRole); });
    connect(tab, &BrowserTab::hasActivityChanged, this, [this, tab]() { refreshTab(tab, ActivityRole); });

    if (url.isValid() && !url.isEmpty())
        tab->setUrl(url);

    tab->setSuspended(suspended);

    m_tabs.append(tab);
    endInsertRows();
    emit countChanged();

    if (url.isValid() && !url.isEmpty() && !suspended)
        tab->requestLoad(url);

    return tab;
}

bool TabModel::removeTab(int index)
{
    if (index < 0 || index >= m_tabs.size())
        return false;

    if (m_tabs.size() <= 1)
        return false;

    beginRemoveRows({}, index, index);
    BrowserTab *tab = m_tabs.takeAt(index);
    emit tabAboutToBeRemoved(tab);
    tab->deleteLater();

    const int oldActive = m_activeIndex;
    if (index < m_activeIndex)
    {
        --m_activeIndex;
    }
    else if (index == m_activeIndex && m_activeIndex >= m_tabs.size())
    {
        m_activeIndex = (std::max)(0, static_cast<int>(m_tabs.size() - 1));
    }

    endRemoveRows();
    emit countChanged();
    if (index <= oldActive)
        emit activeIndexChanged();

    return true;
}

void TabModel::clear()
{
    if (m_tabs.isEmpty())
        return;

    beginRemoveRows({}, 0, m_tabs.size() - 1);
    qDeleteAll(m_tabs);
    m_tabs.clear();
    endRemoveRows();
    emit countChanged();

    if (m_activeIndex != -1)
    {
        m_activeIndex = -1;
        emit activeIndexChanged();
    }
}

void TabModel::takeTabs(QVector<BrowserTab *> &tabs, int &activeIndex)
{
    // views still read the old rows until the reset has begun
    beginResetModel();
    tabs = std::exchange(m_tabs, {});
    activeIndex = std::exchange(m_activeIndex, -1);
    endResetModel();
    emit countChanged();
    if (activeIndex != -1)
        emit activeIndexChanged();
}

void TabModel::restoreTabs(QVector<BrowserTab *> tabs, int activeIndex)
{
    beginResetModel();
    // whatever this model held is replaced, not leaked
    qDeleteAll(m_tabs);
    m_tabs = std::move(tabs);
    m_activeIndex = m_tabs.isEmpty() ? -1 : std::clamp(activeIndex, 0, static_cast<int>(m_tabs.size()) - 1);
    endResetModel();
    emit countChanged();
    emit activeIndexChanged();
}

void TabModel::moveTab(int from, int to)
{
    if (from == to || from < 0 || from >= m_tabs.size() || to < 0 || to >= m_tabs.size())
        return;

    // QAbstractItemModel::beginMoveRows
    // destination must be the row after the definition
    const int destRow = to > from ? to + 1 : to;
    if (!beginMoveRows({}, from, from, {}, destRow))
        return;

    m_tabs.move(from, to);

    const int oldActive = m_activeIndex;
    if (m_activeIndex == from)
        m_activeIndex = to;
    else if (from < m_activeIndex && to >= m_activeIndex)
        --m_activeIndex;
    else if (from > m_activeIndex && to <= m_activeIndex)
        ++m_activeIndex;

    endMoveRows();
    if (m_activeIndex != oldActive)
        emit activeIndexChanged();
}

BrowserTab *TabModel::tabAt(int index) const
{
    if (index < 0 || index >= m_tabs.size())
        return nullptr;
    return m_tabs.at(index);
}

BrowserTab *TabModel::tabAt(int index)
{
    if (index < 0 || index >= m_tabs.size())
        return nullptr;
    return m_tabs.at(index);
}

int TabModel::indexOf(const BrowserTab *tab) const
{
    return m_tabs.indexOf(const_cast<BrowserTab *>(tab));
}

int TabModel::nearestLiveIndex(int index) const
{
    for (int d = 1; d < m_tabs.size(); ++d)
    {
        for (const int i : {index + d, index - d})
        {
            if (i >= 0 && i < m_tabs.size() && !m_tabs.at(i)->suspended())
                return i;
        }
    }
    return -1;
}

int TabModel::activeIndex() const { return m_activeIndex; }

void TabModel::setActiveIndex(int index)
{
    if (m_activeIndex == index)
    {
        // A restored folder/session tab can already occupy the active index
        // while still being suspended. In that case changing the index is a
        // no-op, but activating the row must still create its web view.
        if (BrowserTab *tab = tabAt(index))
            tab->setSuspended(false);
        return;
    }
    m_activeIndex = index;
    emit activeIndexChanged();
}

void TabModel::refreshTab(BrowserTab *tab, int role)
{
    const int row = m_tabs.indexOf(tab);
    if (row < 0)
        return;
    const QModelIndex idx = createIndex(row, 0);
    emit dataChanged(idx, idx, {role});
}

QVariantMap TabModel::itemAt(int index) const
{
    if (index < 0 || index >= m_tabs.size())
        return {};
    const BrowserTab *tab = m_tabs.at(index);
    return {
        {"title", tab->title().isEmpty() ? QStringLiteral("New Tab") : tab->title()},
        {"url", tab->url()},
        {"iconUrl", tab->iconUrl()},
        {"progress", tab->progress()},
        {"loading", tab->loading()},
        {"renderPid", tab->renderProcessPid()},
        {"suspended", tab->suspended()},
    };
}
