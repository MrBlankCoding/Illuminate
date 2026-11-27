#include "AppMenu.h"

#include "BookmarkModel.h"
#include "BrowserController.h"
#include "InternalPageManager.h"
#include "NativeMenuBar.h"
#include "ShortcutRegistry.h"
#include "../spaces/SpaceManager.h"
#include "TabModel.h"

#include <QAbstractItemModel>
#include <QCoreApplication>
#include <QQuickWindow>

namespace
{
    constexpr int kMaxListedBookmarks = 30;

    QString shortcut(const QString &commandId)
    {
        ShortcutRegistry *registry = ShortcutRegistry::instance();
        if (!registry)
            return {};

        const QStringList sequences = registry->sequences(commandId);
        return sequences.isEmpty() ? QString() : sequences.first();
    }

    QString shortcut(const char *commandId)
    {
        return shortcut(QString::fromLatin1(commandId));
    }

    MenuItem overflowEntry(int hidden)
    {
        MenuItem entry = MenuItem::action(QString(), QStringLiteral("…and %1 more").arg(hidden));
        entry.enabled = false;
        return entry;
    }

    MenuItem placeholderEntry(const QString &label)
    {
        MenuItem entry = MenuItem::action(QString(), label);
        entry.enabled = false;
        return entry;
    }

    QString bookmarkLabel(const QVariantMap &bookmark)
    {
        const QString title = bookmark.value(QStringLiteral("title")).toString().trimmed();
        if (!title.isEmpty())
            return title;
        return bookmark.value(QStringLiteral("url")).toString();
    }
}

AppMenu::AppMenu(QObject *parent)
    : QObject(parent), m_rebuildTimer(new QTimer(this))
{
    m_rebuildTimer->setSingleShot(true);
    m_rebuildTimer->setInterval(100);
    connect(m_rebuildTimer, &QTimer::timeout, this, &AppMenu::rebuild);

    BrowserController *controller = BrowserController::instance();
    TabModel *tabs = controller ? controller->tabModel() : nullptr;
    BookmarkModel *bookmarks = BookmarkModel::instance();
    SpaceManager *spaces = SpaceManager::instance();
    ShortcutRegistry *shortcuts = ShortcutRegistry::instance();

    if (controller)
        connect(controller, &BrowserController::activeIndexChanged, this, [this]() { scheduleRebuild(); });
    if (tabs)
    {
        connect(tabs, &TabModel::dataChanged, this,
                [this](const QModelIndex &, const QModelIndex &, const QVector<int> &roles) {
                    if (roles.isEmpty() || roles.contains(TabModel::UrlRole))
                        scheduleRebuild();
                });
    }
    if (bookmarks)
    {
        connect(bookmarks, &BookmarkModel::rowsInserted, this, [this]() { scheduleRebuild(); });
        connect(bookmarks, &BookmarkModel::rowsRemoved, this, [this]() { scheduleRebuild(); });
        connect(bookmarks, &BookmarkModel::modelReset, this, [this]() { scheduleRebuild(); });
        connect(bookmarks, &BookmarkModel::dataChanged, this, [this]() { scheduleRebuild(); });
    }
    if (spaces)
    {
        connect(spaces, &SpaceManager::spacesChanged, this, [this]() {
            watchSpaces();
            scheduleRebuild();
        });
        connect(spaces, &SpaceManager::activeSpaceChanged, this, [this]() { scheduleRebuild(); });
        watchSpaces();
    }
    if (shortcuts)
        connect(shortcuts, &ShortcutRegistry::shortcutsChanged, this, [this]() { scheduleRebuild(); });

    rebuild();
}

bool AppMenu::isNative() const
{
    return NativeMenuBar::isNative();
}

QVariantList AppMenu::tree() const
{
    return MenuItem::toVariantList(m_tree);
}

const QVector<MenuItem> &AppMenu::items() const
{
    return m_tree;
}

AppMenu::~AppMenu()
{
    NativeMenuBar::detach(nullptr);
}

QString AppMenu::shortcutFor(const QString &commandId) const
{
    return shortcut(commandId);
}

void AppMenu::trigger(const QString &id, const QString &payload)
{
    if (id.isEmpty())
        return;
    emit actionTriggered(id, payload);
}

void AppMenu::attach(QQuickWindow *window)
{
    if (!window || window == m_window)
        return;

    m_window = window;
    NativeMenuBar::attach(window, this);
}

void AppMenu::detach(QQuickWindow *window)
{
    if (window && window != m_window)
        return;

    NativeMenuBar::detach(window);
    m_window = nullptr;
}

void AppMenu::refresh()
{
    rebuild();
}

void AppMenu::watchSpaces()
{
    SpaceManager *spaces = SpaceManager::instance();
    if (!spaces)
        return;

    for (const QVariant &entry : spaces->spaces())
    {
        Space *space = entry.value<Space *>();
        if (!space)
            continue;
        connect(space, &Space::nameChanged, this, &AppMenu::onSpaceNameChanged, Qt::UniqueConnection);
    }
}

void AppMenu::onSpaceNameChanged()
{
    scheduleRebuild();
}


MenuItem AppMenu::applicationMenu() const
{
#if defined(Q_OS_MACOS)
    return {};
#else
    const QString appName = QCoreApplication::applicationName();

    QVector<MenuItem> entries{
        MenuItem::action(QStringLiteral("app.about"), QStringLiteral("About %1").arg(appName)),
        MenuItem::separator(),
        MenuItem::action(QStringLiteral("app.settings"), QStringLiteral("Settings…"), shortcut("settings")),
        MenuItem::separator(),
        MenuItem::action(QStringLiteral("app.quit"), QStringLiteral("Quit"), shortcut("quit")),
    };

    entries.last().menuRole = QAction::QuitRole;

    return MenuItem::subMenu(appName, entries);
#endif
}

MenuItem AppMenu::fileMenu() const
{
    QVector<MenuItem> entries{
        MenuItem::action(QStringLiteral("tab.new"), QStringLiteral("New Tab"), shortcut("newTab")),
        MenuItem::action(QStringLiteral("tab.close"), QStringLiteral("Close Tab"), shortcut("closeTab")),
        MenuItem::action(QStringLiteral("tab.reopenClosedTab"), QStringLiteral("Reopen Closed Tab"),
                         shortcut("reopenClosedTab")),
        MenuItem::separator(),
        MenuItem::action(QStringLiteral("app.closeWindow"), QStringLiteral("Close Window"), shortcut("closeWindow")),
        MenuItem::separator(),
        MenuItem::action(QStringLiteral("page.print"), QStringLiteral("Print…"), shortcut("print")),
        MenuItem::action(QStringLiteral("page.savePdf"), QStringLiteral("Save as PDF…"), shortcut("savePdf")),
        MenuItem::separator(),
        MenuItem::action(QStringLiteral("page.downloads"), QStringLiteral("Downloads"), shortcut("downloads")),
    };

#if defined(Q_OS_MACOS)
    MenuItem about = MenuItem::action(QStringLiteral("app.about"), QStringLiteral("About %1").arg(
                                                                          QCoreApplication::applicationName()));
    about.menuRole = QAction::AboutRole;
    MenuItem quit = MenuItem::action(QStringLiteral("app.quit"), QStringLiteral("Quit %1").arg(
                                                                        QCoreApplication::applicationName()),
                                      shortcut("quit"));
    quit.menuRole = QAction::QuitRole;
    entries.append(MenuItem::separator());
    entries.append(about);
    entries.append(quit);
#endif

    return MenuItem::subMenu(QStringLiteral("File"), entries);
}

MenuItem AppMenu::editMenu() const
{
    return MenuItem::subMenu(QStringLiteral("Edit"), {
        MenuItem::action(QStringLiteral("page.find"), QStringLiteral("Find…"), shortcut("find")),
        MenuItem::action(QStringLiteral("page.findNext"), QStringLiteral("Find Next"), shortcut("findNext")),
        MenuItem::action(QStringLiteral("page.findPrevious"), QStringLiteral("Find Previous"), shortcut("findPrevious")),
        MenuItem::separator(),
        MenuItem::action(QStringLiteral("page.copyUrl"), QStringLiteral("Copy URL"), shortcut("copyUrl")),
    });
}

MenuItem AppMenu::viewMenu() const
{
    QVector<MenuItem> entries{
        MenuItem::action(QStringLiteral("view.zoomReset"), QStringLiteral("Actual Size"), shortcut("zoomReset")),
        MenuItem::separator(),
        MenuItem::action(QStringLiteral("view.zoomIn"), QStringLiteral("Zoom In"), shortcut("zoomIn")),
        MenuItem::action(QStringLiteral("view.zoomOut"), QStringLiteral("Zoom Out"), shortcut("zoomOut")),
        MenuItem::separator(),
        MenuItem::action(QStringLiteral("view.toggleSidebar"), QStringLiteral("Toggle Sidebar"),
                         shortcut("toggleSidebar")),
        MenuItem::action(QStringLiteral("view.fullScreen"), QStringLiteral("Toggle Full Screen"),
                         shortcut("toggleFullScreen")),
        MenuItem::action(QStringLiteral("view.theme"), QStringLiteral("Theme…"),
                         shortcut("toggleTheme")),
        MenuItem::separator(),
        MenuItem::action(QStringLiteral("view.focusAddressBar"), QStringLiteral("Go to Address Bar"),
                         shortcut("focusAddressBar")),
        MenuItem::separator(),
        MenuItem::action(QStringLiteral("extensions.show"), QStringLiteral("Manage Extensions…")),
        MenuItem::separator(),
        MenuItem::action(QStringLiteral("dev.devTools"), QStringLiteral("Toggle Developer Tools"),
                         shortcut("toggleDevTools")),
    };

#if defined(Q_OS_MACOS)
    MenuItem settings = MenuItem::action(QStringLiteral("app.settings"), QStringLiteral("Settings…"),
                                         shortcut("settings"));
    settings.menuRole = QAction::PreferencesRole;
    entries.append(MenuItem::separator());
    entries.append(settings);
#endif

    return MenuItem::subMenu(QStringLiteral("View"), entries);
}

MenuItem AppMenu::historyMenu() const
{
    return MenuItem::subMenu(QStringLiteral("History"), {
        MenuItem::action(QStringLiteral("history.show"),    QStringLiteral("Show History"),  shortcut("showHistory")),
        MenuItem::separator(),
        MenuItem::action(QStringLiteral("history.back"),    QStringLiteral("Back"),    shortcut("back")),
        MenuItem::action(QStringLiteral("history.forward"), QStringLiteral("Forward"), shortcut("forward")),
        MenuItem::separator(),
        MenuItem::action(QStringLiteral("history.reload"),  QStringLiteral("Reload"),  shortcut("reload")),
    });
}

MenuItem AppMenu::bookmarksMenu() const
{
    const BrowserController *controller = BrowserController::instance();
    const BookmarkModel *bookmarks = BookmarkModel::instance();
    const QString url = controller ? controller->activeUrl() : QString();

    // the new tab page and the internal pages are not something to bookmark
    const bool onRealPage = !url.isEmpty() && !InternalPageManager::isInternal(url);
    const bool bookmarked = onRealPage && bookmarks && bookmarks->isBookmarked(url);

    QVector<MenuItem> entries;
    MenuItem toggle = MenuItem::action(QStringLiteral("bookmark.toggle"),
                                       bookmarked ? QStringLiteral("Remove Bookmark")
                                                  : QStringLiteral("Bookmark This Page"),
                                       shortcut("toggleBookmark"));
    toggle.enabled = onRealPage;
    entries.append(toggle);
    entries += bookmarkEntries();

    return MenuItem::subMenu(QStringLiteral("Bookmarks"), entries);
}

MenuItem AppMenu::spacesMenu() const
{
    QVector<MenuItem> entries = spaceEntries();
    entries.append(MenuItem::separator());
    entries.append(MenuItem::action(QStringLiteral("space.new"), QStringLiteral("New Space…"),
                                    shortcut("newSpace")));

    return MenuItem::subMenu(QStringLiteral("Spaces"), entries);
}

MenuItem AppMenu::windowMenu() const
{
    return MenuItem::subMenu(QStringLiteral("Window"), {
        MenuItem::action(QStringLiteral("window.minimize"), QStringLiteral("Minimize"),
                         QStringLiteral("Ctrl+M")),
        MenuItem::action(QStringLiteral("window.zoom"), QStringLiteral("Zoom")),
    });
}

QVector<MenuItem> AppMenu::bookmarkEntries() const
{
    const BookmarkModel *model = BookmarkModel::instance();
    QVector<MenuItem> entries;
    if (!model)
        return entries;

    const int total = model->rowCount();
    if (total == 0)
    {
        entries.append(placeholderEntry(QStringLiteral("No Bookmarks")));
        return entries;
    }

    entries.append(MenuItem::separator());

    const int listed = (std::min)(total, kMaxListedBookmarks);
    for (int i = 0; i < listed; ++i)
    {
        const QVariantMap bookmark = model->itemAt(i);
        MenuItem entry = MenuItem::action(QStringLiteral("bookmark.open"), bookmarkLabel(bookmark));
        entry.payload = bookmark.value(QStringLiteral("url")).toString();
        entries.append(entry);
    }
    if (total > listed)
        entries.append(overflowEntry(total - listed));

    return entries;
}

QVector<MenuItem> AppMenu::spaceEntries() const
{
    SpaceManager *spaces = SpaceManager::instance();
    QVector<MenuItem> entries;
    if (!spaces)
        return entries;

    const QVariantList all = spaces->spaces();
    if (all.isEmpty())
    {
        entries.append(placeholderEntry(QStringLiteral("No Spaces")));
        return entries;
    }

    const Space *active = spaces->activeSpace();
    for (const QVariant &entry : all)
    {
        Space *space = entry.value<Space *>();
        if (!space)
            continue;

        const bool isActive = space == active;
        MenuItem item = MenuItem::action(QStringLiteral("space.switch"), space->name());
        item.payload = space->id();
        item.checked = isActive;
        item.enabled = !isActive;
        entries.append(item);
    }

    return entries;
}

void AppMenu::scheduleRebuild()
{
    if (!m_rebuildTimer->isActive())
        m_rebuildTimer->start();
}

void AppMenu::rebuild()
{
    m_rebuildTimer->stop();

    QVector<MenuItem> tree = {
        fileMenu(),
        editMenu(),
        viewMenu(),
        historyMenu(),
        bookmarksMenu(),
        spacesMenu(),
    };

    const MenuItem app = applicationMenu();
    if (!app.label.isEmpty())
        tree.prepend(app);

#if defined(Q_OS_MACOS)
    tree.append(windowMenu());
#endif
    if (tree == m_tree)
        return;
    m_tree = std::move(tree);

    emit treeChanged();
    NativeMenuBar::refresh(this);
}
