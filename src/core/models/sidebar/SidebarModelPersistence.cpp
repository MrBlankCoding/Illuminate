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
constexpr int kSaveDelayMs = 300;
constexpr int kFileVersion = 1;
QString newId() { return QUuid::createUuid().toString(QUuid::WithoutBraces); }
bool isPage(const QUrl &url) { return url.isValid() && !url.isEmpty() && url != kNewTabUrl; }
}

// persistence
//
// {"version": 1, "nodes": [{id, type, parentId, order, ...}]}, depth-first.
// tabs get fresh ids on load; only folder ids are stable across runs.

void SidebarModel::load(const QString &filePath, bool restoreTabs)
{
    unload();
    m_path = filePath;

    QFile file(filePath);
    if (filePath.isEmpty() || !file.open(QFile::ReadOnly | QFile::Text))
    {
        rebuild();
        return;
    }
    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(file.readAll(), &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isObject())
    {
        rebuild();
        return;
    }
    const QJsonArray entries = document.object().value(QStringLiteral("nodes")).toArray();
    file.close();

    struct Pending
    {
        QString fileId;
        int order = 0;
        std::unique_ptr<Node> node;
    };
    std::map<QString, std::vector<Pending>> byParent;

    for (const QJsonValue &value : entries)
    {
        const QJsonObject obj = value.toObject();
        auto node = std::make_unique<Node>();
        const QString type = obj.value(QStringLiteral("type")).toString();
        const QString parentId = obj.value(QStringLiteral("parentId")).toString();
        node->folder = type == QLatin1String("folder");
        node->split = type == QLatin1String("split");
        node->title = obj.value(QStringLiteral("title")).toString();

        // Loose tabs belong to session.json. Sidebar persistence only restores
        // tabs that belong to a folder or split group.
        if (!node->folder && !node->split && parentId.isEmpty())
            continue;

        if (node->split)
        {
            node->id = obj.value(QStringLiteral("id")).toString();
            if (node->id.isEmpty() || m_nodes.contains(node->id))
                node->id = newId();

            m_nodes.insert(node->id, node.get());
        }

        if (node->folder)
        {
            node->id = obj.value(QStringLiteral("id")).toString();
            if (node->id.isEmpty() || node->id == kHeaderId || m_nodes.contains(node->id))
                node->id = newId();
            node->icon = obj.value(QStringLiteral("icon")).toString();
            node->expanded = obj.value(QStringLiteral("expanded")).toBool(true);
        }
        else if (!node->split && !restoreTabs)
        {
            // the space's tabs came back with it: file each where it was
            const QString savedId = obj.value(QStringLiteral("id")).toString();
            BrowserTab *tab = nullptr;
            for (int i = 0; i < m_tabs->rowCount() && !tab; ++i)
                if (BrowserTab *candidate = m_tabs->tabAt(i); candidate->id() == savedId)
                    tab = candidate;
            if (!tab || m_nodes.contains(tab->id()))
                continue;
            node->tab = tab;
            node->id = tab->id();
            node->url = isPage(tab->url()) ? tab->url() : QUrl(obj.value(QStringLiteral("url")).toString());
            node->iconUrl = tab->iconUrl().isEmpty() ? obj.value(QStringLiteral("iconUrl")).toString() : tab->iconUrl();
            if (!tab->title().isEmpty())
                node->title = tab->title();
        }
        else if (!node->split)
        {
            const QUrl url(obj.value(QStringLiteral("url")).toString());
            if (!isPage(url))
                continue;
            BrowserTab *tab = m_tabs->addTab(url, /*suspended=*/true);
            if (!tab)
                continue;
            node->iconUrl = obj.value(QStringLiteral("iconUrl")).toString();
            node->url = url;
            node->tab = tab;
            node->id = tab->id();
            tab->setTitle(node->title);
            tab->setIconUrl(node->iconUrl);
            node->iconUrl = tab->iconUrl();
        }
        m_nodes.insert(node->id, node.get());

        Pending pending;
        pending.fileId = obj.value(QStringLiteral("id")).toString();
        pending.order = obj.value(QStringLiteral("order")).toInt();
        pending.node = std::move(node);
        byParent[parentId].push_back(std::move(pending));
    }

    // attach breadth-first from the top, so a corrupt parent chain can't loop
    QQueue<std::pair<QString, Node *>> queue;
    queue.enqueue({QString(), &m_root});
    while (!queue.isEmpty())
    {
        const auto [fileId, parent] = queue.dequeue();
        auto it = byParent.find(fileId);
        if (it == byParent.end())
            continue;
        std::vector<Pending> children = std::move(it->second);
        byParent.erase(it);
        std::stable_sort(children.begin(), children.end(),
                         [](const Pending &a, const Pending &b) { return a.order < b.order; });
        int splitMembers = 0;
        for (Pending &child : children)
        {
            Node *node = child.node.get();
            if (parent->split && splitMembers >= 2)
            {
                insert(std::move(child.node), &m_root, INT_MAX);
                continue;
            }
            // a tab outside any folder is just an open tab
            if (!node->folder && !node->split && parent == &m_root)
            {
                forget(node);
                continue;
            }
            insert(std::move(child.node), parent, INT_MAX);
            if (parent->split && !node->folder && !node->split)
                ++splitMembers;
            if ((node->folder || node->split) && !child.fileId.isEmpty())
                queue.enqueue({child.fileId, node});
        }
    }

    for (const auto &entry : byParent)
    {
        for (const Pending &orphan : entry.second)
            forget(orphan.node.get());
    }

    rebuild();
}

void SidebarModel::unload()
{
    if (m_saveTimer.isActive())
        saveNow();
    m_saveTimer.stop();
    m_path.clear();

    for (const auto &child : m_root.children)
        forget(child.get());
    m_root.children.clear();
    rebuild();
}

void SidebarModel::saveNow()
{
    m_saveTimer.stop();
    if (m_path.isEmpty())
        return;

    QJsonArray entries;
    const auto write = [&entries](const auto &self, const Node *parent) -> void {
        int order = 0;
        for (const auto &child : parent->children)
        {
            const Node *node = child.get();
            // still on the new tab page: nothing to come back to
            if (!node->folder && !node->split && node->url.isEmpty())
                continue;

            QJsonObject obj;
            obj[QStringLiteral("id")] = node->id;
            obj[QStringLiteral("type")] = node->folder ? QStringLiteral("folder") : node->split ? QStringLiteral("split") : QStringLiteral("tab");
            obj[QStringLiteral("parentId")] = parent->id;
            obj[QStringLiteral("order")] = order++;
            obj[QStringLiteral("title")] = node->title;
            if (node->folder)
            {
                obj[QStringLiteral("icon")] = node->icon;
                obj[QStringLiteral("expanded")] = node->expanded;
            }
            else if (!node->split)
            {
                obj[QStringLiteral("url")] = node->url.toString();
                obj[QStringLiteral("iconUrl")] = node->iconUrl;
            }
            entries.append(obj);
            if (node->folder || node->split)
                self(self, node);
        }
    };
    write(write, &m_root);

    QJsonObject root;
    root[QStringLiteral("version")] = kFileVersion;
    root[QStringLiteral("nodes")] = entries;

    QSaveFile file(m_path);
    if (!file.open(QFile::WriteOnly | QFile::Text))
    {
        qWarning() << "Could not open sidebar.json for writing:" << file.errorString();
        return;
    }
    file.write(QJsonDocument(root).toJson());
    if (!file.commit())
        qWarning() << "Could not write sidebar.json:" << file.errorString();
}

void SidebarModel::scheduleSave()
{
    if (!m_path.isEmpty())
        m_saveTimer.start();
}
