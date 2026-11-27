#include <QtTest>

#include "SidebarModel.h"
#include "TabModel.h"
#include "BrowserTab.h"

class TestSidebarModel : public QObject
{
    Q_OBJECT

    static QUrl url(int n) { return QUrl(QStringLiteral("https://example.com/%1").arg(n)); }

    static QList<BrowserTab *> fill(TabModel &tabs, int count)
    {
        QList<BrowserTab *> added;
        for (int i = 0; i < count; ++i)
            added << tabs.addTab(url(i), /*suspended=*/false);
        tabs.setActiveIndex(0);
        return added;
    }

    // "kind:depth:id" per row, folders by title so failures read well
    static QStringList rows(const SidebarModel &model)
    {
        QStringList out;
        for (int i = 0; i < model.rowCount(); ++i)
        {
            const QModelIndex idx = model.index(i);
            const QString kind = idx.data(SidebarModel::KindRole).toString();
            const QString name = kind == QLatin1String("tab")
                                     ? idx.data(SidebarModel::UrlRole).toUrl().path().mid(1)
                                     : idx.data(SidebarModel::TitleRole).toString();
            out << QStringLiteral("%1:%2:%3").arg(kind.left(1), idx.data(SidebarModel::DepthRole).toString(), name);
        }
        return out;
    }

private slots:
    void looseTabsFollowTheHeader()
    {
        TabModel tabs;
        SidebarModel model(&tabs);
        fill(tabs, 2);

        QCOMPARE(rows(model), (QStringList{"h:0:", "t:0:0", "t:0:1"}));
        QCOMPARE(model.folderCount(), 0);
    }

    void addingToAFolderIndentsTheTab()
    {
        TabModel tabs;
        SidebarModel model(&tabs);
        const auto t = fill(tabs, 3);

        const QString work = model.createFolder({}, QStringLiteral("Work"));
        model.addToFolder(t[1]->id(), work);

        QCOMPARE(rows(model), (QStringList{"f:0:Work", "t:1:1", "h:0:", "t:0:0", "t:0:2"}));
        QVERIFY(model.isInFolder(t[1]));
        QCOMPARE(model.folderCount(), 1);
        QCOMPARE(model.index(0).data(SidebarModel::TabCountRole).toInt(), 1);
    }

    // the top level holds folders only
    void tabsNeverSitOutsideAFolder()
    {
        TabModel tabs;
        SidebarModel model(&tabs);
        const auto t = fill(tabs, 2);
        const QString folder = model.createFolder({}, QStringLiteral("F"));

        QVERIFY(!model.moveNode(t[0]->id(), {}, 0));
        QVERIFY(!model.canDrop(t[0]->id(), folder, SidebarModel::Before));
        QVERIFY(!model.canDrop(t[0]->id(), model.headerId(), SidebarModel::Before));
        QVERIFY(model.canDrop(t[0]->id(), folder, SidebarModel::Into));
        QVERIFY(!model.isInFolder(t[0]));
    }

    void collapsingHidesDescendantsAndRemembersTheirState()
    {
        TabModel tabs;
        SidebarModel model(&tabs);
        const auto t = fill(tabs, 3);
        tabs.setActiveIndex(2);

        const QString outer = model.createFolder({}, QStringLiteral("Outer"));
        const QString inner = model.createFolder(outer, QStringLiteral("Inner"));
        model.addToFolder(t[0]->id(), inner);
        model.setExpanded(inner, false);
        QCOMPARE(rows(model).mid(0, 3), (QStringList{"f:0:Outer", "f:1:Inner", "h:0:"}));

        model.setExpanded(inner, true);
        model.toggleFolder(outer);
        QCOMPARE(rows(model).first(2), (QStringList{"f:0:Outer", "h:0:"}));

        // the inner folder kept its own expanded state
        model.toggleFolder(outer);
        QCOMPARE(rows(model).first(3), (QStringList{"f:0:Outer", "f:1:Inner", "t:2:0"}));
    }

    void collapsingHidesEveryDescendant()
    {
        TabModel tabs;
        SidebarModel model(&tabs);
        const auto t = fill(tabs, 2);

        const QString folder = model.createFolder({}, QStringLiteral("F"));
        model.addToFolder(t[0]->id(), folder);
        model.addToFolder(t[1]->id(), folder);
        tabs.setActiveIndex(tabs.indexOf(t[1]));
        model.setExpanded(folder, false);

        QCOMPARE(rows(model), (QStringList{"f:0:F", "h:0:"}));

        // Changing the active tab does not reveal a collapsed folder's contents.
        tabs.setActiveIndex(tabs.indexOf(t[0]));
        QCOMPARE(rows(model), (QStringList{"f:0:F", "h:0:"}));
    }

    void aFolderCannotBeDroppedIntoItself()
    {
        TabModel tabs;
        SidebarModel model(&tabs);
        fill(tabs, 1);

        const QString a = model.createFolder({}, QStringLiteral("A"));
        const QString b = model.createFolder(a, QStringLiteral("B"));

        QVERIFY(!model.canDrop(a, a, SidebarModel::Into));
        QVERIFY(!model.canDrop(a, b, SidebarModel::Into));
        QVERIFY(!model.canDrop(a, b, SidebarModel::Before));
        QVERIFY(!model.moveNode(a, b, 0));
        QVERIFY(model.canDrop(b, a, SidebarModel::Before));
        // folders stay out of the loose tabs
        QVERIFY(!model.canDrop(a, model.headerId(), SidebarModel::After));
    }

    void dropReordersSiblings()
    {
        TabModel tabs;
        SidebarModel model(&tabs);
        const auto t = fill(tabs, 4);
        const QString folder = model.createFolder({}, QStringLiteral("F"));
        for (BrowserTab *tab : t.first(3))
            model.addToFolder(tab->id(), folder);

        QVERIFY(model.drop(t[0]->id(), t[2]->id(), SidebarModel::After));
        QCOMPARE(rows(model).mid(1, 3), (QStringList{"t:1:1", "t:1:2", "t:1:0"}));

        QVERIFY(model.drop(t[0]->id(), t[1]->id(), SidebarModel::Before));
        QCOMPARE(rows(model).mid(1, 3), (QStringList{"t:1:0", "t:1:1", "t:1:2"}));

        // a loose tab dropped onto the folder goes in at the end
        QVERIFY(model.drop(t[3]->id(), folder, SidebarModel::Into));
        QCOMPARE(rows(model), (QStringList{"f:0:F", "t:1:0", "t:1:1", "t:1:2", "t:1:3", "h:0:"}));

        // and dropped onto a loose tab, it leaves the folder next to it
        tabs.addTab(url(9));
        QVERIFY(model.drop(t[1]->id(), tabs.tabAt(tabs.rowCount() - 1)->id(), SidebarModel::Before));
        QCOMPARE(rows(model).mid(4), (QStringList{"h:0:", "t:0:1", "t:0:9"}));
    }

    void closingAFolderTabClosesIt()
    {
        TabModel tabs;
        SidebarModel model(&tabs);
        const auto t = fill(tabs, 2);
        const QString folder = model.createFolder({}, QStringLiteral("F"));
        model.addToFolder(t[0]->id(), folder);

        model.closeFolderTabs(folder);
        QCOMPARE(tabs.rowCount(), 1);
        QCOMPARE(rows(model), (QStringList{"f:0:F", "h:0:", "t:0:1"}));
    }

    void deletingAFolderCanKeepItsTabs()
    {
        TabModel tabs;
        SidebarModel model(&tabs);
        const auto t = fill(tabs, 3);
        const QString folder = model.createFolder({}, QStringLiteral("F"));
        model.addToFolder(t[1]->id(), folder);
        model.addToFolder(t[2]->id(), folder);

        // kept tabs are just open tabs again
        model.deleteNode(folder, /*keepTabs=*/true);
        QCOMPARE(rows(model), (QStringList{"h:0:", "t:0:0", "t:0:1", "t:0:2"}));
        QCOMPARE(tabs.rowCount(), 3);

        const QString other = model.createFolder({}, QStringLiteral("G"));
        model.addToFolder(t[1]->id(), other);
        model.deleteNode(other);
        QCOMPARE(tabs.rowCount(), 2);
        QCOMPARE(rows(model), (QStringList{"h:0:", "t:0:0", "t:0:2"}));
    }

    void movingToANewFolderTakesTheTabsPlace()
    {
        TabModel tabs;
        SidebarModel model(&tabs);
        const auto t = fill(tabs, 3);
        const QString outer = model.createFolder({}, QStringLiteral("Outer"));
        for (BrowserTab *tab : t)
            model.addToFolder(tab->id(), outer);

        const QString folder = model.moveToNewFolder(t[1]->id());
        QVERIFY(!folder.isEmpty());
        QCOMPARE(rows(model).first(5), (QStringList{"f:0:Outer", "t:1:0", "f:1:New Folder", "t:2:1", "t:1:2"}));

        // a loose tab gets a new folder of its own
        tabs.addTab(url(9));
        model.moveToNewFolder(tabs.tabAt(tabs.rowCount() - 1)->id());
        QCOMPARE(rows(model).mid(5), (QStringList{"f:0:New Folder", "t:1:9", "h:0:"}));
    }

    void aFolderTabClosedElsewhereLeavesTheTree()
    {
        TabModel tabs;
        SidebarModel model(&tabs);
        const auto t = fill(tabs, 2);
        const QString folder = model.createFolder({}, QStringLiteral("F"));
        model.addToFolder(t[1]->id(), folder);

        QVERIFY(tabs.removeTab(tabs.indexOf(t[1])));
        QCOMPARE(rows(model), (QStringList{"f:0:F", "h:0:", "t:0:0"}));
    }

    void splittingGroupsTabsAndTracksTheirOrder()
    {
        TabModel tabs;
        SidebarModel model(&tabs);
        const auto t = fill(tabs, 3);

        const QString group = model.createSplit(t[1]->id(), t[0]->id());

        QVERIFY(!group.isEmpty());
        QCOMPARE(model.rowCount(), 3); // one split row, header, and one loose tab
        QCOMPARE(model.index(1).data(SidebarModel::KindRole).toString(), QStringLiteral("split"));
        QCOMPARE(model.splitTabs(group), (QVariantList{t[1]->id(), t[0]->id()}));
        QVERIFY(model.isInFolder(t[0]));
        QVERIFY(model.isInFolder(t[1]));
        QCOMPARE(model.visualTabOrder().size(), 3);
    }

    void droppingATabOnAnotherCreatesAFixedTwoPaneSplit()
    {
        TabModel tabs;
        SidebarModel model(&tabs);
        const auto t = fill(tabs, 3);

        QVERIFY(model.canDrop(t[1]->id(), t[0]->id(), SidebarModel::Into));
        QVERIFY(model.drop(t[1]->id(), t[0]->id(), SidebarModel::Into));

        const QString group = model.index(1).data(SidebarModel::NodeIdRole).toString();
        QCOMPARE(model.index(1).data(SidebarModel::KindRole).toString(), QStringLiteral("split"));
        QCOMPARE(model.splitTabs(group), (QVariantList{t[0]->id(), t[1]->id()}));
        QVERIFY(!model.canDrop(t[2]->id(), t[0]->id(), SidebarModel::Into));
        QCOMPARE(model.splitTabs(group).size(), 2);
    }

    void aSplitPersistsItsTwoMembers()
    {
        QTemporaryDir dir;
        const QString path = dir.filePath(QStringLiteral("sidebar.json"));
        QString group;
        {
            TabModel tabs;
            SidebarModel model(&tabs);
            model.load(path);
            const auto t = fill(tabs, 2);
            group = model.createSplit(t[1]->id(), t[0]->id());
            model.saveNow();
        }

        TabModel tabs;
        SidebarModel model(&tabs);
        model.load(path);
        QCOMPARE(tabs.rowCount(), 2);
        const QString restoredGroup = model.index(1).data(SidebarModel::NodeIdRole).toString();
        QCOMPARE(model.index(1).data(SidebarModel::KindRole).toString(), QStringLiteral("split"));
        QCOMPARE(model.splitTabs(restoredGroup).size(), 2);
        QCOMPARE(restoredGroup, group);
    }

    void closingAMemberDissolvesTheRemainingPair()
    {
        TabModel tabs;
        SidebarModel model(&tabs);
        const auto t = fill(tabs, 3);
        const QString group = model.createSplit(t[0]->id(), t[1]->id());

        QVERIFY(tabs.removeTab(tabs.indexOf(t[1])));

        QVERIFY(model.splitTabs(group).isEmpty());
        QCOMPARE(rows(model), (QStringList{"h:0:", "t:0:0", "t:0:2"}));
        QVERIFY(!model.isInFolder(t[0]));
    }

    void separatingKeepsAllMembersAsLooseTabs()
    {
        TabModel tabs;
        SidebarModel model(&tabs);
        const auto t = fill(tabs, 3);
        const QString group = model.createSplit(t[0]->id(), t[1]->id());

        model.separateSplit(group);

        QCOMPARE(tabs.rowCount(), 3);
        QCOMPARE(rows(model), (QStringList{"h:0:", "t:0:0", "t:0:1", "t:0:2"}));
        QVERIFY(!model.isInFolder(t[0]));
        QVERIFY(!model.isInFolder(t[1]));
    }

    // a folder tab remembers where it got to, not where it started
    void theTreeSurvivesARestart()
    {
        QTemporaryDir dir;
        const QString path = dir.filePath(QStringLiteral("sidebar.json"));
        {
            TabModel tabs;
            SidebarModel model(&tabs);
            model.load(path);
            const auto t = fill(tabs, 3);
            const QString work = model.createFolder({}, QStringLiteral("Work"));
            const QString inner = model.createFolder(work, QStringLiteral("Inner"));
            model.setFolderIcon(work, QStringLiteral("💼"));
            model.addToFolder(t[0]->id(), inner);
            model.addToFolder(t[1]->id(), work);
            t[0]->setTitle(QStringLiteral("Zero"));
            t[1]->setUrl(url(7));
            model.setExpanded(inner, false);
            model.unload();
        }

        TabModel tabs;
        SidebarModel model(&tabs);
        model.load(path);

        QCOMPARE(tabs.rowCount(), 2);
        QVERIFY(tabs.tabAt(0)->suspended());
        QCOMPARE(rows(model), (QStringList{"f:0:Work", "f:1:Inner", "t:1:7", "h:0:"}));
        QCOMPARE(model.index(0).data(SidebarModel::IconRole).toString(), QStringLiteral("💼"));
        QVERIFY(!model.index(1).data(SidebarModel::ExpandedRole).toBool());

        model.setExpanded(model.index(1).data(SidebarModel::NodeIdRole).toString(), true);
        QCOMPARE(model.index(2).data(SidebarModel::TitleRole).toString(), QStringLiteral("Zero"));
    }

    // rows move rather than being removed and re-added, so the view animates
    void reorderingEmitsMovesNotResets()
    {
        TabModel tabs;
        SidebarModel model(&tabs);
        const auto t = fill(tabs, 3);
        const QString folder = model.createFolder({}, QStringLiteral("F"));
        for (BrowserTab *tab : t)
            model.addToFolder(tab->id(), folder);

        QSignalSpy removed(&model, &SidebarModel::rowsRemoved);
        QSignalSpy moved(&model, &SidebarModel::rowsMoved);
        QSignalSpy reset(&model, &SidebarModel::modelReset);
        model.drop(t[2]->id(), t[0]->id(), SidebarModel::Before);
        QCOMPARE(removed.size(), 0);
        QCOMPARE(reset.size(), 0);
        QVERIFY(moved.size() >= 1);
    }
    // the crash page stands in for a page; what's saved is the real address
    void aCrashPageDoesNotReplaceTheSavedAddress()
    {
        QTemporaryDir dir;
        const QString path = dir.filePath(QStringLiteral("sidebar.json"));
        {
            TabModel tabs;
            SidebarModel model(&tabs);
            model.load(path);
            const auto t = fill(tabs, 2);
            const QString folder = model.createFolder({}, QStringLiteral("F"));
            model.addToFolder(t[0]->id(), folder);
            t[0]->setUrl(QUrl(QStringLiteral("illuminate://crashed?url=https%3A%2F%2Fexample.com%2F0")));
            model.unload();
        }

        TabModel tabs;
        SidebarModel model(&tabs);
        model.load(path);
        QCOMPARE(rows(model), (QStringList{"f:0:F", "t:1:0", "h:0:"}));
    }
    // the speaker and the activity dot reach the sidebar rows
    void audioAndActivityReachTheRows()
    {
        TabModel tabs;
        SidebarModel model(&tabs);
        const auto t = fill(tabs, 2);
        QSignalSpy spy(&model, &SidebarModel::dataChanged);
        const int row = model.rowOf(t[1]->id());
        QVERIFY(row >= 0);

        t[1]->setAudible(true);
        t[1]->setMuted(true);
        t[1]->setHasActivity(true);
        QVERIFY(model.index(row).data(SidebarModel::AudibleRole).toBool());
        QVERIFY(model.index(row).data(SidebarModel::MutedRole).toBool());
        QVERIFY(model.index(row).data(SidebarModel::ActivityRole).toBool());

        QList<int> roles;
        for (const auto &args : spy)
            roles += args.at(2).value<QList<int>>();
        QVERIFY(roles.contains(SidebarModel::AudibleRole));
        QVERIFY(roles.contains(SidebarModel::MutedRole));
        QVERIFY(roles.contains(SidebarModel::ActivityRole));
        const auto names = model.roleNames();
        QCOMPARE(names.value(SidebarModel::AudibleRole), QByteArray("audible"));
        QCOMPARE(names.value(SidebarModel::ActivityRole), QByteArray("hasActivity"));
    }
    // a space coming back with its tabs in memory: folders find them by id
    void foldersFindTheirTabsWhenTheTabsCameBackInMemory()
    {
        QTemporaryDir dir;
        const QString path = dir.filePath(QStringLiteral("sidebar.json"));
        TabModel tabs;
        SidebarModel model(&tabs);
        model.load(path);
        const auto t = fill(tabs, 4);
        const QString folder = model.createFolder({}, QStringLiteral("Reading"));
        model.addToFolder(t[1]->id(), folder);
        model.addToFolder(t[2]->id(), folder);
        model.unload(); // saved; the tabs stay in the TabModel

        model.load(path, /*restoreTabs=*/false);
        QCOMPARE(tabs.rowCount(), 4); // nothing added
        QCOMPARE(rows(model), (QStringList{"f:0:Reading", "t:1:1", "t:1:2", "h:0:", "t:0:0", "t:0:3"}));
        QVERIFY(model.isInFolder(t[1]));
        QVERIFY(model.isInFolder(t[2]));
        QVERIFY(!model.isInFolder(t[0]));
    }

    void aFiledTabThatIsGoneIsDropped()
    {
        QTemporaryDir dir;
        const QString path = dir.filePath(QStringLiteral("sidebar.json"));
        TabModel tabs;
        SidebarModel model(&tabs);
        model.load(path);
        const auto t = fill(tabs, 3);
        const QString folder = model.createFolder({}, QStringLiteral("F"));
        model.addToFolder(t[1]->id(), folder);
        model.unload();
        tabs.removeTab(1);

        model.load(path, false);
        QCOMPARE(model.folderCount(), 1);
        QCOMPARE(rows(model), (QStringList{"f:0:F", "h:0:", "t:0:0", "t:0:2"}));
    }

    void splitsComeBackWithTabsInMemory()
    {
        QTemporaryDir dir;
        const QString path = dir.filePath(QStringLiteral("sidebar.json"));
        TabModel tabs;
        SidebarModel model(&tabs);
        model.load(path);
        const auto t = fill(tabs, 3);
        model.drop(t[2]->id(), t[0]->id(), SidebarModel::Into);
        QVERIFY(model.isSplitTab(t[0]->id()));
        model.unload();
        QVERIFY(!model.isSplitTab(t[0]->id()));

        model.load(path, false);
        QVERIFY(model.isSplitTab(t[0]->id()));
        QVERIFY(model.isSplitTab(t[2]->id()));
        QCOMPARE(tabs.rowCount(), 3);
    }
};

QTEST_GUILESS_MAIN(TestSidebarModel)
#include "tst_SidebarModel.moc"
