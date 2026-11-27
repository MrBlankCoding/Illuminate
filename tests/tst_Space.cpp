#include <QtTest>
#include <QFile>

#include <QSignalSpy>
#include <QTemporaryDir>

#include "Space.h"

class TestSpace : public QObject
{
    Q_OBJECT

    QTemporaryDir m_dir;

private slots:
    void initTestCase()
    {
        QVERIFY(m_dir.isValid());
    }

    void defaultSpaceHasUsableIdentityAndValues()
    {
        Space space;
        QVERIFY(!space.id().isEmpty());
        QCOMPARE(space.name(), QStringLiteral("New Space"));
        QCOMPARE(space.initial(), QStringLiteral("N"));
        QCOMPARE(space.color(), QColor(QStringLiteral("#4A90E2")));
        QVERIFY(!space.themeColor().isValid());
    }

    void emptyExplicitIdIsReplacedWithGeneratedId()
    {
        Space space(QString(), QStringLiteral("Named"), QColor(QStringLiteral("#123456")));
        QVERIFY(!space.id().isEmpty());
        QCOMPARE(space.name(), QStringLiteral("Named"));
    }

    void explicitIdentityIsPreserved()
    {
        Space space(QStringLiteral("stable-id"), QStringLiteral("Work"),
                    QColor(QStringLiteral("#234567")));
        QCOMPARE(space.id(), QStringLiteral("stable-id"));
        QCOMPARE(space.initial(), QStringLiteral("W"));
    }

    void nameIsTrimmedAndOnlyChangesOnce()
    {
        Space space;
        QSignalSpy spy(&space, &Space::nameChanged);
        space.setName(QStringLiteral("  Work  "));
        space.setName(QStringLiteral("Work"));
        QCOMPARE(space.name(), QStringLiteral("Work"));
        QCOMPARE(space.initial(), QStringLiteral("W"));
        QCOMPARE(spy.size(), 1);
    }

    void emptyNameIsAllowedAndHasNoInitial()
    {
        Space space;
        space.setName(QStringLiteral(" "));
        QVERIFY(space.name().isEmpty());
        QVERIFY(space.initial().isEmpty());
    }

    void colorIgnoresInvalidAndUnchangedValues()
    {
        Space space;
        QSignalSpy spy(&space, &Space::colorChanged);
        const QColor original = space.color();
        space.setColor(QColor());
        space.setColor(original);
        QCOMPARE(space.color(), original);
        QCOMPARE(spy.size(), 0);
        space.setColor(QColor(QStringLiteral("#abcdef")));
        QCOMPARE(space.color(), QColor(QStringLiteral("#abcdef")));
        QCOMPARE(spy.size(), 1);
    }

    void themeColorSeparatesPreviewFromPersistence()
    {
        Space space;
        const QColor seed(QStringLiteral("#ff0000"));
        QSignalSpy colorSpy(&space, &Space::themeColorChanged);
        QSignalSpy themeSpy(&space, &Space::themeChanged);

        space.setThemeColor(seed, false);
        QCOMPARE(space.themeColor(), seed);
        QCOMPARE(colorSpy.size(), 1);
        QCOMPARE(themeSpy.size(), 0);

        // saving what a preview already applied changes nothing visible
        space.setThemeColor(seed, true);
        QCOMPARE(colorSpy.size(), 1);
        QCOMPARE(themeSpy.size(), 1);

        space.setThemeColor(QColor());
        QVERIFY(!space.themeColor().isValid());
        QCOMPARE(colorSpy.size(), 2);
    }

    void storagePathsUseConfiguredRoot()
    {
        Space::setSpacesRootDir(m_dir.path());
        Space space(QStringLiteral("space-id"), QStringLiteral("Work"), QColor());
        space.setStorageDir(Space::storageDirFor(space.id()));
        QCOMPARE(Space::dataDir(), m_dir.path());
        QCOMPARE(Space::spacesRootDir(), m_dir.path() + QStringLiteral("/spaces"));
        QVERIFY(space.storageDir().endsWith(QStringLiteral("/spaces/space-id")));
        QCOMPARE(space.sidebarFilePath(), space.storageDir() + QStringLiteral("/sidebar.json"));
        QCOMPARE(space.sessionFilePath(), space.storageDir() + QStringLiteral("/session.json"));
        QCOMPARE(space.bookmarksFilePath(), space.storageDir() + QStringLiteral("/bookmarks.json"));
        Space::setSpacesRootDir(QString());
    }
    // which page a space had in front, without loading the space
    void lastActiveUrlComesFromTheSessionFile_data()
    {
        QTest::addColumn<QString>("session");
        QTest::addColumn<QString>("expected");
        QTest::newRow("a web page") << "{\"activeUrl\":\"https://example.com/a?b=1\"}" << "https://example.com/a?b=1";
        QTest::newRow("a local file") << "{\"activeUrl\":\"file:///tmp/notes.html\"}" << "file:///tmp/notes.html";
        QTest::newRow("the new tab page") << "{\"activeUrl\":\"newtab://newtab\"}" << "";
        QTest::newRow("one of ours") << "{\"activeUrl\":\"illuminate://memory\"}" << "";
        QTest::newRow("a chrome page") << "{\"activeUrl\":\"chrome://settings\"}" << "";
        QTest::newRow("none recorded") << "{\"tabs\":[]}" << "";
        QTest::newRow("not json") << "garbage" << "";
    }
    void lastActiveUrlComesFromTheSessionFile()
    {
        QFETCH(QString, session);
        QFETCH(QString, expected);
        QTemporaryDir dir;
        Space space(QStringLiteral("last-active"), QStringLiteral("Last"), QColor(Qt::red));
        space.setStorageDir(dir.path());
        QFile file(space.sessionFilePath());
        QVERIFY(file.open(QFile::WriteOnly));
        file.write(session.toUtf8());
        file.close();
        QCOMPARE(space.lastActiveUrl(), expected);
    }

    void aSpaceNeverOpenedHasNoLastPage()
    {
        QTemporaryDir dir;
        Space space(QStringLiteral("fresh"), QStringLiteral("Fresh"), QColor(Qt::blue));
        space.setStorageDir(dir.filePath(QStringLiteral("missing")));
        QCOMPARE(space.lastActiveUrl(), QString());
    }
};

QTEST_GUILESS_MAIN(TestSpace)
#include "tst_Space.moc"
