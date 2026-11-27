#include <QtTest>

#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSignalSpy>
#include <QTemporaryDir>

#include "BookmarkModel.h"
#include "Space.h"

class TestBookmarkModel : public QObject
{
    Q_OBJECT

    QTemporaryDir m_dir;

    Space *makeSpace(const QString &name = QStringLiteral("Bookmarks"))
    {
        QDir(m_dir.filePath(name)).removeRecursively();
        auto *space = new Space(QStringLiteral("bookmarks-test"), name,
                                QColor(QStringLiteral("#345678")), this);
        space->setStorageDir(m_dir.filePath(name));
        return space;
    }

    void writeBookmarkJson(const QString &spaceName, const QString &json)
    {
        const QString directory = m_dir.filePath(spaceName);
        QDir().mkpath(directory);
        QFile file(directory + QStringLiteral("/bookmarks.json"));
        if (file.open(QIODevice::WriteOnly | QIODevice::Truncate))
            file.write(json.toUtf8());
    }

private slots:
    void initTestCase()
    {
        QVERIFY(m_dir.isValid());
    }

    void unattachedModelIsEmptyAndCannotPersist()
    {
        BookmarkModel model(nullptr);
        QCOMPARE(model.rowCount(), 0);
        QVERIFY(!model.isBookmarked(QStringLiteral("https://example.com")));
        model.toggleBookmark(QStringLiteral("Example"), QStringLiteral("https://example.com"));
        QCOMPARE(model.rowCount(), 1); // in-memory changes work without a persistence target
    }

    void parentIndexesHaveNoRows()
    {
        BookmarkModel model(nullptr);
        auto space = makeSpace();
        model.setSpace(space);
        model.toggleBookmark(QStringLiteral("Example"), QStringLiteral("https://example.com"));
        QCOMPARE(model.rowCount(model.index(0, 0)), 0);
    }

    void addingBookmarkPublishesDataAndRoles()
    {
        BookmarkModel model(nullptr);
        auto space = makeSpace();
        model.setSpace(space);
        QSignalSpy rowsInserted(&model, &QAbstractItemModel::rowsInserted);
        QSignalSpy countChanged(&model, &BookmarkModel::countChanged);

        model.toggleBookmark(QStringLiteral("Example"), QStringLiteral("https://example.com"),
                             QStringLiteral("https://example.com/favicon.ico"));

        QCOMPARE(model.rowCount(), 1);
        QCOMPARE(rowsInserted.size(), 1);
        QCOMPARE(countChanged.size(), 1); // insert after the spy is attached
        QCOMPARE(model.data(model.index(0, 0), BookmarkModel::TitleRole).toString(),
                 QStringLiteral("Example"));
        QCOMPARE(model.data(model.index(0, 0), BookmarkModel::UrlRole).toString(),
                 QStringLiteral("https://example.com"));
        QCOMPARE(model.data(model.index(0, 0), BookmarkModel::IconUrlRole).toString(),
                 QStringLiteral("https://example.com/favicon.ico"));
        QCOMPARE(model.roleNames().value(BookmarkModel::TitleRole), QByteArray("title"));
        QVERIFY(model.isBookmarked(QStringLiteral("https://example.com")));
    }

    void emptyTitleFallsBackToUrl()
    {
        BookmarkModel model(nullptr);
        auto space = makeSpace();
        model.setSpace(space);
        model.toggleBookmark({}, QStringLiteral("https://example.com"));
        QCOMPARE(model.data(model.index(0, 0), BookmarkModel::TitleRole).toString(),
                 QStringLiteral("https://example.com"));
    }

    void emptyUrlIsIgnored()
    {
        BookmarkModel model(nullptr);
        auto space = makeSpace();
        QSignalSpy countChanged(&model, &BookmarkModel::countChanged);
        model.toggleBookmark(QStringLiteral("No URL"), QString());
        QCOMPARE(model.rowCount(), 0);
        QCOMPARE(countChanged.size(), 0);
    }

    void togglingAnExistingUrlRemovesIt()
    {
        BookmarkModel model(nullptr);
        auto space = makeSpace();
        model.setSpace(space);
        model.toggleBookmark(QStringLiteral("Example"), QStringLiteral("https://example.com"));
        model.toggleBookmark(QStringLiteral("Ignored replacement title"),
                             QStringLiteral("https://example.com"));
        QCOMPARE(model.rowCount(), 0);
        QVERIFY(!model.isBookmarked(QStringLiteral("https://example.com")));
    }

    void renameTrimsAndNotifiesOnlyForRealChanges()
    {
        BookmarkModel model(nullptr);
        auto space = makeSpace();
        model.setSpace(space);
        model.toggleBookmark(QStringLiteral("Before"), QStringLiteral("https://example.com"));
        QSignalSpy changed(&model, &QAbstractItemModel::dataChanged);

        model.renameBookmark(0, QStringLiteral("  After  "));
        model.renameBookmark(0, QStringLiteral("After"));
        model.renameBookmark(0, QStringLiteral("   "));
        QCOMPARE(changed.size(), 1);
        QCOMPARE(model.data(model.index(0, 0), BookmarkModel::TitleRole).toString(),
                 QStringLiteral("After"));
    }

    void renameAndRemoveRejectInvalidRows()
    {
        BookmarkModel model(nullptr);
        auto space = makeSpace();
        model.setSpace(space);
        model.toggleBookmark(QStringLiteral("Example"), QStringLiteral("https://example.com"));
        model.renameBookmark(-1, QStringLiteral("Bad"));
        model.renameBookmark(1, QStringLiteral("Bad"));
        model.removeBookmark(-1);
        model.removeBookmark(1);
        QCOMPARE(model.rowCount(), 1);
    }

    void removePublishesRowAndCountChanges()
    {
        BookmarkModel model(nullptr);
        auto space = makeSpace();
        model.setSpace(space);
        model.toggleBookmark(QStringLiteral("Example"), QStringLiteral("https://example.com"));
        QSignalSpy rowsRemoved(&model, &QAbstractItemModel::rowsRemoved);
        QSignalSpy countChanged(&model, &BookmarkModel::countChanged);

        model.removeBookmark(0);

        QCOMPARE(model.rowCount(), 0);
        QCOMPARE(rowsRemoved.size(), 1);
        QCOMPARE(countChanged.size(), 1);
    }

    void itemAtReturnsAnEmptyMapForInvalidRows()
    {
        BookmarkModel model(nullptr);
        auto space = makeSpace();
        model.setSpace(space);
        model.toggleBookmark(QStringLiteral("Example"), QStringLiteral("https://example.com"),
                             QStringLiteral("icon"));
        QCOMPARE(model.itemAt(-1), QVariantMap());
        QCOMPARE(model.itemAt(1), QVariantMap());
        const QVariantMap item = model.itemAt(0);
        QCOMPARE(item.value(QStringLiteral("title")).toString(), QStringLiteral("Example"));
        QCOMPARE(item.value(QStringLiteral("iconUrl")).toString(), QStringLiteral("icon"));
    }

    void dataRejectsInvalidIndexesAndUnknownRoles()
    {
        BookmarkModel model(nullptr);
        auto space = makeSpace();
        model.setSpace(space);
        model.toggleBookmark(QStringLiteral("Example"), QStringLiteral("https://example.com"));
        QVERIFY(!model.data(QModelIndex(), BookmarkModel::TitleRole).isValid());
        QVERIFY(!model.data(model.index(1, 0), BookmarkModel::TitleRole).isValid());
        QVERIFY(!model.data(model.index(0, 0), Qt::DisplayRole).isValid());
    }

    void bookmarksSurviveModelRecreation()
    {
        auto space = makeSpace();
        {
            BookmarkModel model(nullptr);
            model.setSpace(space);
            model.toggleBookmark(QStringLiteral("Example"), QStringLiteral("https://example.com"),
                                 QStringLiteral("icon"));
        }

        BookmarkModel reopened(nullptr);
        reopened.setSpace(space);
        QCOMPARE(reopened.rowCount(), 1);
        QCOMPARE(reopened.itemAt(0).value(QStringLiteral("title")).toString(), QStringLiteral("Example"));
        QCOMPARE(reopened.itemAt(0).value(QStringLiteral("iconUrl")).toString(), QStringLiteral("icon"));
    }

    void switchingSpaceSavesAndLoadsSeparateFiles()
    {
        auto first = makeSpace(QStringLiteral("First"));
        auto second = makeSpace(QStringLiteral("Second"));
        BookmarkModel model(nullptr);
        model.setSpace(first);
        model.toggleBookmark(QStringLiteral("First"), QStringLiteral("https://first.example"));
        model.setSpace(second);
        QCOMPARE(model.rowCount(), 0);
        model.toggleBookmark(QStringLiteral("Second"), QStringLiteral("https://second.example"));
        model.setSpace(first);
        QCOMPARE(model.rowCount(), 1);
        QVERIFY(model.isBookmarked(QStringLiteral("https://first.example")));
        model.setSpace(second);
        QVERIFY(model.isBookmarked(QStringLiteral("https://second.example")));
    }

    void loadSkipsEntriesWithoutUrlsAndTrimsValidUrls()
    {
        auto space = makeSpace(QStringLiteral("Fixture"));
        writeBookmarkJson(QStringLiteral("Fixture"),
            QStringLiteral("[{\"title\":\"No URL\"},{\"url\":\"   \"},{\"title\":\" Valid \",\"url\":\" https://valid.example \",\"iconUrl\":\"icon\"}]"));
        BookmarkModel model(nullptr);
        model.setSpace(space);
        QCOMPARE(model.rowCount(), 1);
        QCOMPARE(model.itemAt(0).value(QStringLiteral("url")).toString(), QStringLiteral("https://valid.example"));
        QCOMPARE(model.itemAt(0).value(QStringLiteral("title")).toString(), QStringLiteral(" Valid "));
    }

    void malformedOrNonArrayJsonLeavesModelEmpty()
    {
        auto space = makeSpace(QStringLiteral("Fixture"));
        writeBookmarkJson(QStringLiteral("Fixture"), QStringLiteral("not json"));
        BookmarkModel model(nullptr);
        model.setSpace(space);
        QCOMPARE(model.rowCount(), 0);

        auto objectSpace = makeSpace(QStringLiteral("ObjectFixture"));
        writeBookmarkJson(QStringLiteral("ObjectFixture"), QStringLiteral("{}"));
        BookmarkModel objectModel(nullptr);
        objectModel.setSpace(objectSpace);
        QCOMPARE(objectModel.rowCount(), 0);
    }
};

QTEST_GUILESS_MAIN(TestBookmarkModel)
#include "tst_BookmarkModel.moc"
