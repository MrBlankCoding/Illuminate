#include <QtTest>
#include <QDir>
#include <QFile>
#include <QRegularExpression>
#include <QSet>
#include <QSettings>
#include <QSignalSpy>
#include <QTemporaryDir>

#include <memory>

#include "AppMenu.h"
#include "BookmarkModel.h"
#include "CefChromeCommands.h"
#include "MenuItem.h"
#include "ShortcutRegistry.h"
#include "Space.h"
#include "SpaceManager.h"

namespace
{
const MenuItem *findSubMenu(const QVector<MenuItem> &tree, const QString &label)
{
    for (const MenuItem &item : tree)
        if (item.kind == MenuItem::Kind::SubMenu && item.label == label)
            return &item;
    return nullptr;
}

const MenuItem *findAction(const QVector<MenuItem> &items, const QString &id)
{
    for (const MenuItem &item : items)
    {
        if (item.id == id)
            return &item;
        if (const MenuItem *child = findAction(item.children, id))
            return child;
    }
    return nullptr;
}

void collectActionIds(const QVector<MenuItem> &items, QStringList &ids)
{
    for (const MenuItem &item : items)
    {
        if (item.kind == MenuItem::Kind::Normal && !item.id.isEmpty())
            ids.append(item.id);
        collectActionIds(item.children, ids);
    }
}

// every `case "id":` in KeyboardShortcuts.perform(), where menu and Chrome actions land
QSet<QString> handledActions()
{
    QFile file(QStringLiteral(ILLUMINATE_SOURCE_DIR "/ui/components/browser/KeyboardShortcuts.qml"));
    if (!file.open(QIODevice::ReadOnly))
        return {};
    const QString source = QString::fromUtf8(file.readAll());
    QSet<QString> ids;
    static const QRegularExpression caseLabel(QStringLiteral("case\\s+\"([^\"]+)\"\\s*:"));
    for (auto it = caseLabel.globalMatch(source); it.hasNext();)
        ids.insert(it.next().captured(1));
    return ids;
}
}

class TestAppMenu : public QObject
{
    Q_OBJECT

    QTemporaryDir m_dir;
    std::unique_ptr<ShortcutRegistry> m_shortcuts;
    std::unique_ptr<BookmarkModel> m_bookmarks;
    std::unique_ptr<SpaceManager> m_spaces;

    std::unique_ptr<AppMenu> makeMenu() { return std::make_unique<AppMenu>(nullptr); }

private slots:
    void initTestCase()
    {
        QVERIFY(m_dir.isValid());
        QCoreApplication::setApplicationName(QStringLiteral("tst_appmenu"));
        QSettings::setDefaultFormat(QSettings::IniFormat);
        QSettings::setPath(QSettings::IniFormat, QSettings::UserScope, m_dir.path());
        Space::setSpacesRootDir(m_dir.filePath(QStringLiteral("spaces")));
    }

    void cleanupTestCase()
    {
        Space::setSpacesRootDir(QString());
    }

    void init()
    {
        QSettings().clear();
        // a clean install every time: spaces persist to disk
        QDir(m_dir.filePath(QStringLiteral("spaces"))).removeRecursively();
        m_spaces = std::make_unique<SpaceManager>(nullptr);
        SpaceManager::setQmlInstance(m_spaces.get());
        m_shortcuts = std::make_unique<ShortcutRegistry>(nullptr);
        ShortcutRegistry::setQmlInstance(m_shortcuts.get());
        m_bookmarks = std::make_unique<BookmarkModel>(nullptr);
        BookmarkModel::setQmlInstance(m_bookmarks.get());
    }

    void cleanup()
    {
        BookmarkModel::setQmlInstance(nullptr);
        ShortcutRegistry::setQmlInstance(nullptr);
        SpaceManager::setQmlInstance(nullptr);
        m_bookmarks.reset();
        m_shortcuts.reset();
        m_spaces.reset();
    }

    // MenuItem

    void actionFactoryFillsInTheEntry()
    {
        const MenuItem item = MenuItem::action(QStringLiteral("tab.new"), QStringLiteral("New Tab"),
                                               QStringLiteral("Ctrl+T"));
        QCOMPARE(item.kind, MenuItem::Kind::Normal);
        QCOMPARE(item.id, QStringLiteral("tab.new"));
        QCOMPARE(item.label, QStringLiteral("New Tab"));
        QCOMPARE(item.shortcut, QStringLiteral("Ctrl+T"));
        QVERIFY(item.enabled);
        QVERIFY(!item.checked);
        QVERIFY(!item.isSeparator());
    }

    void separatorsAndSubMenusHaveTheirKinds()
    {
        QVERIFY(MenuItem::separator().isSeparator());
        QVERIFY(MenuItem::separator().id.isEmpty());

        const MenuItem sub = MenuItem::subMenu(QStringLiteral("File"), {MenuItem::separator()});
        QCOMPARE(sub.kind, MenuItem::Kind::SubMenu);
        QCOMPARE(sub.children.size(), 1);
    }

    void equalityLooksAtEveryField()
    {
        const MenuItem base = MenuItem::action(QStringLiteral("a"), QStringLiteral("A"));
        MenuItem other = base;
        QVERIFY(base == other);

        other.payload = QStringLiteral("x");
        QVERIFY(base != other);
        other = base;
        other.checked = true;
        QVERIFY(base != other);
        other = base;
        other.enabled = false;
        QVERIFY(base != other);
        other = base;
        other.menuRole = QAction::QuitRole;
        QVERIFY(base != other);

        const MenuItem subA = MenuItem::subMenu(QStringLiteral("S"), {base});
        const MenuItem subB = MenuItem::subMenu(QStringLiteral("S"), {other});
        QVERIFY(subA != subB);
    }

    void variantMapsDescribeTheEntryForQml()
    {
        MenuItem action = MenuItem::action(QStringLiteral("bookmark.open"), QStringLiteral("Example"));
        action.payload = QStringLiteral("https://example.com");
        const QVariantMap map = action.toVariantMap();
        QCOMPARE(map.value(QStringLiteral("kind")).toString(), QStringLiteral("normal"));
        QCOMPARE(map.value(QStringLiteral("id")).toString(), QStringLiteral("bookmark.open"));
        QCOMPARE(map.value(QStringLiteral("payload")).toString(), QStringLiteral("https://example.com"));
        QVERIFY(!map.contains(QStringLiteral("children")));

        QCOMPARE(MenuItem::separator().toVariantMap().value(QStringLiteral("kind")).toString(),
                 QStringLiteral("separator"));

        const QVariantMap sub = MenuItem::subMenu(QStringLiteral("File"), {action, MenuItem::separator()}).toVariantMap();
        QCOMPARE(sub.value(QStringLiteral("kind")).toString(), QStringLiteral("submenu"));
        const QVariantList children = sub.value(QStringLiteral("children")).toList();
        QCOMPARE(children.size(), 2);
        QCOMPARE(children.at(1).toMap().value(QStringLiteral("kind")).toString(), QStringLiteral("separator"));
    }

    // AppMenu structure

    void topLevelMenusAreInOrder()
    {
        auto menu = makeMenu();
        QStringList labels;
        for (const MenuItem &item : menu->items())
            labels.append(item.label);

        QStringList expected{QStringLiteral("File"), QStringLiteral("Edit"), QStringLiteral("View"),
                             QStringLiteral("History"), QStringLiteral("Bookmarks"), QStringLiteral("Spaces")};
#if defined(Q_OS_MACOS)
        expected.append(QStringLiteral("Window"));
#else
        expected.prepend(QCoreApplication::applicationName());
#endif
        QCOMPARE(labels, expected);
        QCOMPARE(menu->tree().size(), menu->items().size());
    }

    void quitAboutAndSettingsCarryTheirMenuRoles()
    {
        auto menu = makeMenu();
        const MenuItem *quit = findAction(menu->items(), QStringLiteral("app.quit"));
        QVERIFY(quit);
        QCOMPARE(quit->menuRole, QAction::QuitRole);
#if defined(Q_OS_MACOS)
        QCOMPARE(findAction(menu->items(), QStringLiteral("app.about"))->menuRole, QAction::AboutRole);
        QCOMPARE(findAction(menu->items(), QStringLiteral("app.settings"))->menuRole, QAction::PreferencesRole);
#endif
    }

    void actionIdsAreUniqueOutsideTheGeneratedLists()
    {
        auto menu = makeMenu();
        QStringList ids;
        collectActionIds(menu->items(), ids);
        QSet<QString> seen;
        for (const QString &id : std::as_const(ids))
        {
            if (id == QLatin1String("bookmark.open") || id == QLatin1String("space.switch"))
                continue;
            QVERIFY2(!seen.contains(id), qPrintable(QStringLiteral("duplicate menu action: ") + id));
            seen.insert(id);
        }
    }

    void separatorsNeverLeadTrailOrDouble()
    {
        auto menu = makeMenu();
        for (const MenuItem &sub : menu->items())
        {
            const QVector<MenuItem> &entries = sub.children;
            QVERIFY2(!entries.isEmpty(), qPrintable(sub.label));
            QVERIFY2(!entries.first().isSeparator(), qPrintable(sub.label + QStringLiteral(" starts with a separator")));
            QVERIFY2(!entries.last().isSeparator(), qPrintable(sub.label + QStringLiteral(" ends with a separator")));
            for (int i = 1; i < entries.size(); ++i)
                QVERIFY2(!(entries[i].isSeparator() && entries[i - 1].isSeparator()),
                         qPrintable(sub.label + QStringLiteral(" has two separators in a row")));
        }
    }

    // a menu item nobody handles does nothing when clicked
    void everyMenuActionHasAHandler()
    {
        const QSet<QString> handled = handledActions();
        QVERIFY2(!handled.isEmpty(), "could not read KeyboardShortcuts.qml");

        auto menu = makeMenu();
        QStringList ids;
        collectActionIds(menu->items(), ids);
        QVERIFY(!ids.isEmpty());
        for (const QString &id : std::as_const(ids))
            QVERIFY2(handled.contains(id), qPrintable(QStringLiteral("no handler for menu action ") + id));
    }

    void everyChromeCommandWeRerouteHasAHandler()
    {
        const QSet<QString> handled = handledActions();
        QVERIFY(!handled.isEmpty());

        QSet<QString> routed;
        for (int command = 0; command <= 60000; ++command)
        {
            const ChromeCommandRoute route = routeChromeCommand(command);
            if (route.kind == ChromeCommandRoute::Action)
                routed.insert(route.action);
        }
        // CefStrayBrowserClient moves windows Chrome opens itself into tabs this way
        routed.insert(QStringLiteral("tab.open"));

        QVERIFY(routed.size() > 10);
        for (const QString &id : std::as_const(routed))
            QVERIFY2(handled.contains(id), qPrintable(QStringLiteral("no handler for Chrome command action ") + id));
    }

    // triggering and shortcuts

    void triggerPassesTheIdAndPayloadOn()
    {
        auto menu = makeMenu();
        QSignalSpy spy(menu.get(), &AppMenu::actionTriggered);
        menu->trigger(QStringLiteral("bookmark.open"), QStringLiteral("https://example.com"));
        QCOMPARE(spy.size(), 1);
        QCOMPARE(spy.at(0).at(0).toString(), QStringLiteral("bookmark.open"));
        QCOMPARE(spy.at(0).at(1).toString(), QStringLiteral("https://example.com"));
    }

    void placeholderEntriesCannotBeTriggered()
    {
        auto menu = makeMenu();
        QSignalSpy spy(menu.get(), &AppMenu::actionTriggered);
        menu->trigger(QString());
        QCOMPARE(spy.size(), 0);
    }

    void shortcutsComeFromTheRegistry()
    {
        auto menu = makeMenu();
        const QString expected = m_shortcuts->sequences(QStringLiteral("newTab")).value(0);
        QVERIFY(!expected.isEmpty());
        QCOMPARE(menu->shortcutFor(QStringLiteral("newTab")), expected);
        QCOMPARE(findAction(menu->items(), QStringLiteral("tab.new"))->shortcut, expected);
        QCOMPARE(menu->shortcutFor(QStringLiteral("no.such.command")), QString());
    }

    void withoutARegistryEntriesHaveNoShortcuts()
    {
        ShortcutRegistry::setQmlInstance(nullptr);
        auto menu = makeMenu();
        QCOMPARE(findAction(menu->items(), QStringLiteral("tab.new"))->shortcut, QString());
        QCOMPARE(menu->shortcutFor(QStringLiteral("newTab")), QString());
    }

    void rebindingAShortcutUpdatesTheMenu()
    {
        auto menu = makeMenu();
        QSignalSpy spy(menu.get(), &AppMenu::treeChanged);
        const QString sequence = ShortcutRegistry::sequenceFromKey(Qt::Key_J, Qt::ControlModifier | Qt::AltModifier | Qt::ShiftModifier);
        QVERIFY(m_shortcuts->setSequence(QStringLiteral("newTab"), sequence));
        QTRY_COMPARE(spy.size(), 1);
        QCOMPARE(findAction(menu->items(), QStringLiteral("tab.new"))->shortcut, sequence);
    }

    // bookmarks

    void noBookmarksShowsADisabledPlaceholder()
    {
        auto menu = makeMenu();
        const MenuItem *bookmarks = findSubMenu(menu->items(), QStringLiteral("Bookmarks"));
        QVERIFY(bookmarks);
        QCOMPARE(bookmarks->children.size(), 2);
        QCOMPARE(bookmarks->children.at(1).label, QStringLiteral("No Bookmarks"));
        QVERIFY(!bookmarks->children.at(1).enabled);
    }

    void bookmarkToggleIsDisabledWithoutAPage()
    {
        auto menu = makeMenu();
        const MenuItem *toggle = findAction(menu->items(), QStringLiteral("bookmark.toggle"));
        QVERIFY(toggle);
        QVERIFY(!toggle->enabled);
        QCOMPARE(toggle->label, QStringLiteral("Bookmark This Page"));
    }

    void bookmarksAreListedWithTheirAddressAsPayload()
    {
        m_bookmarks->toggleBookmark(QStringLiteral("Example"), QStringLiteral("https://example.com"));
        m_bookmarks->toggleBookmark(QStringLiteral("Qt"), QStringLiteral("https://qt.io"));
        auto menu = makeMenu();
        const MenuItem *bookmarks = findSubMenu(menu->items(), QStringLiteral("Bookmarks"));
        QVERIFY(bookmarks);
        // toggle, separator, then one entry per bookmark
        QCOMPARE(bookmarks->children.size(), 4);
        QVERIFY(bookmarks->children.at(1).isSeparator());
        QSet<QString> payloads;
        for (int i = 2; i < bookmarks->children.size(); ++i)
        {
            QCOMPARE(bookmarks->children.at(i).id, QStringLiteral("bookmark.open"));
            payloads.insert(bookmarks->children.at(i).payload);
        }
        QCOMPARE(payloads, QSet<QString>({QStringLiteral("https://example.com"), QStringLiteral("https://qt.io")}));
    }

    void longBookmarkListsEndInAnOverflowEntry()
    {
        for (int i = 0; i < 35; ++i)
            m_bookmarks->toggleBookmark(QStringLiteral("Page %1").arg(i), QStringLiteral("https://page%1.example.com").arg(i));
        auto menu = makeMenu();
        const MenuItem *bookmarks = findSubMenu(menu->items(), QStringLiteral("Bookmarks"));
        QVERIFY(bookmarks);
        // toggle + separator + 30 listed + overflow
        QCOMPARE(bookmarks->children.size(), 33);
        const MenuItem &overflow = bookmarks->children.last();
        QCOMPARE(overflow.label, QStringLiteral("…and 5 more"));
        QVERIFY(!overflow.enabled);
        QVERIFY(overflow.id.isEmpty());
    }

    void addingABookmarkRebuildsTheMenuOnce()
    {
        auto menu = makeMenu();
        QSignalSpy spy(menu.get(), &AppMenu::treeChanged);
        // a burst of changes is folded into one rebuild
        m_bookmarks->toggleBookmark(QStringLiteral("A"), QStringLiteral("https://a.example.com"));
        m_bookmarks->toggleBookmark(QStringLiteral("B"), QStringLiteral("https://b.example.com"));
        QTRY_COMPARE(spy.size(), 1);
        QTest::qWait(150);
        QCOMPARE(spy.size(), 1);
        QVERIFY(findAction(menu->items(), QStringLiteral("bookmark.open")));
    }

    void refreshWithNothingChangedIsSilent()
    {
        auto menu = makeMenu();
        QSignalSpy spy(menu.get(), &AppMenu::treeChanged);
        menu->refresh();
        QCOMPARE(spy.size(), 0);
    }

    // spaces

    void spacesMenuChecksTheActiveSpace()
    {
        SpaceManager &spaces = *m_spaces;
        Space *second = spaces.createSpace(QStringLiteral("Second"));
        QVERIFY(second);
        spaces.setActiveSpace(second);

        auto menu = makeMenu();
        const MenuItem *spacesMenu = findSubMenu(menu->items(), QStringLiteral("Spaces"));
        QVERIFY(spacesMenu);

        int switches = 0;
        for (const MenuItem &entry : spacesMenu->children)
        {
            if (entry.id != QLatin1String("space.switch"))
                continue;
            ++switches;
            const bool active = entry.payload == second->id();
            QCOMPARE(entry.checked, active);
            QCOMPARE(entry.enabled, !active);
        }
        QCOMPARE(switches, spaces.spaces().size());
        QCOMPARE(spacesMenu->children.last().id, QStringLiteral("space.new"));
    }

    void renamingASpaceRenamesItsEntry()
    {
        auto menu = makeMenu();
        QCOMPARE(m_spaces->spaces().size(), 1);
        Space *active = m_spaces->activeSpace();
        QVERIFY(active);

        active->setName(QStringLiteral("Renamed Space"));
        QTRY_VERIFY(findAction(menu->items(), QStringLiteral("space.switch"))
                    && findAction(menu->items(), QStringLiteral("space.switch"))->label == QStringLiteral("Renamed Space"));
    }
};

QTEST_MAIN(TestAppMenu)
#include "tst_AppMenu.moc"
