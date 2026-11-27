#include <QtTest>
#include <QDir>
#include <QFile>
#include <QSignalSpy>
#include <QTemporaryDir>

#include "DownloadModel.h"

// the sidebar's downloads list, fed by Chromium's progress reports
class TestDownloadModel : public QObject
{
    Q_OBJECT

    QTemporaryDir m_dir;

    static DownloadModel::Update update(quint32 id, qint64 received, qint64 total = -1)
    {
        DownloadModel::Update u;
        u.id = id;
        u.fullPath = QStringLiteral("/tmp/file-%1.zip").arg(id);
        u.receivedBytes = received;
        u.totalBytes = total;
        return u;
    }

    static DownloadModel::Update finished(DownloadModel::Update u)
    {
        u.complete = true;
        u.receivedBytes = u.totalBytes > 0 ? u.totalBytes : u.receivedBytes;
        return u;
    }

    static QVariant role(const DownloadModel &model, int row, int role)
    {
        return model.data(model.index(row), role);
    }

    void touch(const QString &name)
    {
        QFile file(m_dir.filePath(name));
        QVERIFY(file.open(QIODevice::WriteOnly));
    }

private slots:
    void initTestCase()
    {
        QVERIFY(m_dir.isValid());
    }

    void init()
    {
        QDir dir(m_dir.path());
        for (const QString &entry : dir.entryList(QDir::Files))
            dir.remove(entry);
    }

    // saving files

    void aFreeNameIsUsedAsIs()
    {
        DownloadModel model(nullptr);
        QCOMPARE(model.reservePath(m_dir.path(), QStringLiteral("report.pdf")), m_dir.filePath(QStringLiteral("report.pdf")));
    }

    void existingFilesAreNeverOverwritten()
    {
        DownloadModel model(nullptr);
        touch(QStringLiteral("report.pdf"));
        touch(QStringLiteral("report (1).pdf"));
        QCOMPARE(model.reservePath(m_dir.path(), QStringLiteral("report.pdf")),
                 m_dir.filePath(QStringLiteral("report (2).pdf")));
    }

    void downloadsStillRunningKeepTheirNames()
    {
        DownloadModel model(nullptr);
        const QString first = model.reservePath(m_dir.path(), QStringLiteral("photo.jpg"));
        const QString second = model.reservePath(m_dir.path(), QStringLiteral("photo.jpg"));
        QCOMPARE(first, m_dir.filePath(QStringLiteral("photo.jpg")));
        QCOMPARE(second, m_dir.filePath(QStringLiteral("photo (1).jpg")));
    }

    void chromiumsPartialFilesCountAsTaken()
    {
        DownloadModel model(nullptr);
        touch(QStringLiteral("big.iso.crdownload"));
        QCOMPARE(model.reservePath(m_dir.path(), QStringLiteral("big.iso")), m_dir.filePath(QStringLiteral("big (1).iso")));
    }

    void tarballsAreNumberedBeforeTheirDoubleExtension()
    {
        DownloadModel model(nullptr);
        touch(QStringLiteral("source.tar.gz"));
        QCOMPARE(model.reservePath(m_dir.path(), QStringLiteral("source.tar.gz")),
                 m_dir.filePath(QStringLiteral("source (1).tar.gz")));
    }

    void namesWithoutAnExtensionAreNumberedToo()
    {
        DownloadModel model(nullptr);
        touch(QStringLiteral("README"));
        QCOMPARE(model.reservePath(m_dir.path(), QStringLiteral("README")), m_dir.filePath(QStringLiteral("README (1)")));
    }

    void aFinishedDownloadFreesItsNameForTheNextOne()
    {
        DownloadModel model(nullptr);
        const QString path = model.reservePath(m_dir.path(), QStringLiteral("a.txt"));
        DownloadModel::Update u = update(1, 0);
        u.fullPath = path;
        model.applyUpdate(u);
        u.cancelled = true;
        model.applyUpdate(u);
        // nothing was written, and the reservation is gone
        QCOMPARE(model.reservePath(m_dir.path(), QStringLiteral("a.txt")), path);
    }

    void safeFileName_data()
    {
        QTest::addColumn<QString>("suggested");
        QTest::addColumn<QString>("expected");
        QTest::newRow("plain") << "report.pdf" << "report.pdf";
        QTest::newRow("directories are dropped") << "../../etc/passwd" << "passwd";
        QTest::newRow("windows separators") << "..\\..\\evil.exe" << "evil.exe";
        QTest::newRow("hidden files are made visible") << ".bashrc" << "bashrc";
        QTest::newRow("colons are removed") << "a:b.txt" << "ab.txt";
        QTest::newRow("whitespace is trimmed") << "  notes.txt  " << "notes.txt";
        QTest::newRow("empty") << "" << "download";
        QTest::newRow("only dots") << "..." << "download";
        QTest::newRow("trailing slash") << "folder/" << "download";
    }
    void safeFileName()
    {
        QFETCH(QString, suggested);
        QFETCH(QString, expected);
        QCOMPARE(DownloadModel::safeFileName(suggested), expected);
    }

    // the list

    void startsEmpty()
    {
        DownloadModel model(nullptr);
        QCOMPARE(model.rowCount(), 0);
        QCOMPARE(model.activeCount(), 0);
        QCOMPARE(model.overallProgress(), -1.0);
        QVERIFY(!model.hasUnseen());
    }

    void newDownloadsGoToTheTop()
    {
        DownloadModel model(nullptr);
        QSignalSpy countSpy(&model, &DownloadModel::countChanged);
        model.applyUpdate(update(1, 10, 100));
        model.applyUpdate(update(2, 10, 100));
        QCOMPARE(model.rowCount(), 2);
        QCOMPARE(countSpy.size(), 2);
        QCOMPARE(role(model, 0, DownloadModel::IdRole).toUInt(), 2u);
        QCOMPARE(role(model, 0, DownloadModel::FileNameRole).toString(), QStringLiteral("file-2.zip"));
    }

    void progressUpdatesTheSameRow()
    {
        DownloadModel model(nullptr);
        model.applyUpdate(update(1, 10, 100));
        model.applyUpdate(update(1, 60, 100));
        QCOMPARE(model.rowCount(), 1);
        QCOMPARE(role(model, 0, DownloadModel::ProgressRole).toDouble(), 0.6);
        QCOMPARE(role(model, 0, DownloadModel::StateRole).toInt(), int(DownloadModel::Active));
    }

    void suggestedNameShowsUntilTheFileIsChosen()
    {
        DownloadModel model(nullptr);
        DownloadModel::Update u = update(1, 0);
        u.fullPath.clear();
        u.suggestedName = QStringLiteral("../sneaky.pdf");
        model.applyUpdate(u);
        QCOMPARE(role(model, 0, DownloadModel::FileNameRole).toString(), QStringLiteral("sneaky.pdf"));
    }

    void unknownSizeHasNoProgress()
    {
        DownloadModel model(nullptr);
        model.applyUpdate(update(1, 500));
        QCOMPARE(role(model, 0, DownloadModel::ProgressRole).toDouble(), -1.0);
        QCOMPARE(model.overallProgress(), -1.0);
        QCOMPARE(role(model, 0, DownloadModel::StatusTextRole).toString(), QStringLiteral("500 B"));
    }

    void overallProgressCombinesDownloadsOfKnownSize()
    {
        DownloadModel model(nullptr);
        model.applyUpdate(update(1, 50, 100));
        model.applyUpdate(update(2, 150, 300));
        model.applyUpdate(update(3, 999)); // size unknown: left out
        QCOMPARE(model.activeCount(), 3);
        QCOMPARE(model.overallProgress(), 0.5);
    }

    void finishingMarksItUnseenAndSaysSo()
    {
        DownloadModel model(nullptr);
        QSignalSpy finishedSpy(&model, &DownloadModel::downloadFinished);
        QSignalSpy unseenSpy(&model, &DownloadModel::hasUnseenChanged);
        model.applyUpdate(update(1, 50, 100));
        model.applyUpdate(finished(update(1, 100, 100)));

        QCOMPARE(model.activeCount(), 0);
        QCOMPARE(role(model, 0, DownloadModel::StateRole).toInt(), int(DownloadModel::Complete));
        QCOMPARE(role(model, 0, DownloadModel::ProgressRole).toDouble(), 1.0);
        QCOMPARE(role(model, 0, DownloadModel::StatusTextRole).toString(), QStringLiteral("100 B"));
        QCOMPARE(finishedSpy.size(), 1);
        QCOMPARE(finishedSpy.at(0).at(0).toString(), QStringLiteral("file-1.zip"));
        QVERIFY(model.hasUnseen());
        QCOMPARE(unseenSpy.size(), 1);

        model.markSeen();
        QVERIFY(!model.hasUnseen());
    }

    void finishedDownloadsDontChangeAgain()
    {
        DownloadModel model(nullptr);
        QSignalSpy finishedSpy(&model, &DownloadModel::downloadFinished);
        model.applyUpdate(finished(update(1, 100, 100)));
        model.applyUpdate(finished(update(1, 100, 100)));
        DownloadModel::Update late = update(1, 5, 100);
        model.applyUpdate(late);
        QCOMPARE(role(model, 0, DownloadModel::StateRole).toInt(), int(DownloadModel::Complete));
        // a download so quick its first report is the last still counts, once
        QCOMPARE(finishedSpy.size(), 1);
    }

    void lateReportsOfDownloadsNeverSeenAreIgnored()
    {
        DownloadModel model(nullptr);
        DownloadModel::Update u;
        u.id = 9;
        u.cancelled = true;
        model.applyUpdate(u);
        QCOMPARE(model.rowCount(), 0);
    }

    void cancelledAndFailedDownloadsSaySo()
    {
        DownloadModel model(nullptr);
        DownloadModel::Update cancelled = update(1, 10, 100);
        cancelled.cancelled = true;
        DownloadModel::Update failed = update(2, 10, 100);
        failed.interrupted = true;
        model.applyUpdate(update(1, 5, 100));
        model.applyUpdate(update(2, 5, 100));
        model.applyUpdate(cancelled);
        model.applyUpdate(failed);
        QCOMPARE(role(model, 1, DownloadModel::StateRole).toInt(), int(DownloadModel::Cancelled));
        QCOMPARE(role(model, 1, DownloadModel::StatusTextRole).toString(), QStringLiteral("Cancelled"));
        QCOMPARE(role(model, 0, DownloadModel::StateRole).toInt(), int(DownloadModel::Failed));
        QCOMPARE(role(model, 0, DownloadModel::StatusTextRole).toString(), QStringLiteral("Failed"));
        QVERIFY(!model.hasUnseen());
    }

    void cancellingStopsTheDownloadInChromium()
    {
        DownloadModel model(nullptr);
        int cancels = 0;
        model.applyUpdate(update(1, 10, 100), [&cancels]() { ++cancels; });
        model.cancel(1);
        QCOMPARE(cancels, 1);
        QCOMPARE(role(model, 0, DownloadModel::StateRole).toInt(), int(DownloadModel::Cancelled));
        QCOMPARE(model.activeCount(), 0);

        // Chromium's confirmation, and a second click, change nothing
        DownloadModel::Update confirm = update(1, 10, 100);
        confirm.cancelled = true;
        model.applyUpdate(confirm);
        model.cancel(1);
        QCOMPARE(cancels, 1);
    }

    void cancellingSomethingFinishedOrUnknownIsHarmless()
    {
        DownloadModel model(nullptr);
        int cancels = 0;
        model.applyUpdate(update(1, 10, 100), [&cancels]() { ++cancels; });
        model.applyUpdate(finished(update(1, 100, 100)));
        model.cancel(1);
        model.cancel(42);
        QCOMPARE(cancels, 0);
        QCOMPARE(role(model, 0, DownloadModel::StateRole).toInt(), int(DownloadModel::Complete));
    }

    void clearingKeepsRunningDownloads()
    {
        DownloadModel model(nullptr);
        model.applyUpdate(update(1, 10, 100));
        model.applyUpdate(finished(update(2, 100, 100)));
        model.applyUpdate(update(3, 10, 100));
        model.clearFinished();
        QCOMPARE(model.rowCount(), 2);
        QCOMPARE(model.activeCount(), 2);
        QVERIFY(!model.hasUnseen());
    }

    void theListKeepsOnlyRecentFinishedDownloads()
    {
        DownloadModel model(nullptr);
        model.applyUpdate(update(1000, 1, 100)); // still running: never dropped
        for (quint32 id = 1; id <= DownloadModel::kMaxEntries + 5; ++id)
        {
            model.applyUpdate(update(id, 1, 100));
            model.applyUpdate(finished(update(id, 100, 100)));
        }
        QCOMPARE(model.rowCount(), DownloadModel::kMaxEntries);
        QCOMPARE(model.activeCount(), 1);
        QCOMPARE(role(model, 0, DownloadModel::IdRole).toUInt(), quint32(DownloadModel::kMaxEntries + 5));
    }

    void statusShowsProgressAndSpeed()
    {
        DownloadModel model(nullptr);
        DownloadModel::Update u = update(1, 5 * 1024 * 1024, 20 * 1024 * 1024);
        u.bytesPerSecond = 2 * 1024 * 1024;
        model.applyUpdate(u);
        QCOMPARE(role(model, 0, DownloadModel::StatusTextRole).toString(),
                 QStringLiteral("5.0 MB of 20.0 MB · 2.0 MB/s"));
    }

    void formatBytes_data()
    {
        QTest::addColumn<qint64>("bytes");
        QTest::addColumn<QString>("text");
        QTest::newRow("unknown") << qint64(-1) << "?";
        QTest::newRow("bytes") << qint64(512) << "512 B";
        QTest::newRow("kilobytes") << qint64(2048) << "2 KB";
        QTest::newRow("megabytes") << qint64(3 * 1024 * 1024 + 512 * 1024) << "3.5 MB";
        QTest::newRow("gigabytes") << qint64(5) * 1024 * 1024 * 1024 << "5.00 GB";
    }
    void formatBytes()
    {
        QFETCH(qint64, bytes);
        QFETCH(QString, text);
        QCOMPARE(DownloadModel::formatBytes(bytes), text);
    }

    void openingOrRevealingMissingFilesFails()
    {
        DownloadModel model(nullptr);
        model.applyUpdate(update(1, 10, 100));
        QVERIFY(!model.open(1));   // not finished
        QVERIFY(!model.open(77));  // unknown
        QVERIFY(!model.reveal(77));
        model.applyUpdate(finished(update(1, 100, 100)));
        QVERIFY(!model.open(1));   // /tmp/file-1.zip doesn't exist
        QVERIFY(!model.reveal(1));
    }

    void rolesAreNamedForQml()
    {
        DownloadModel model(nullptr);
        const auto names = model.roleNames();
        for (const char *name : {"downloadId", "fileName", "filePath", "progress", "downloadState", "statusText"})
            QVERIFY2(names.values().contains(QByteArray(name)), name);
        // "state" would clash with every QML item's own state property
        QVERIFY(!names.values().contains(QByteArray("state")));
    }
};

QTEST_GUILESS_MAIN(TestDownloadModel)
#include "tst_DownloadModel.moc"
