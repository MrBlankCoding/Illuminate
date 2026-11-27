#pragma once

#include <QAbstractListModel>
#include <QHash>
#include <QMutex>
#include <QSet>
#include <QString>
#include <QVector>
#include <QtQml/qqmlregistration.h>

#include <functional>

class QQmlEngine;
class QJSEngine;

// This session's downloads, newest first, for the sidebar's downloads button.
// CefDownloadHandlerImpl feeds it from Chromium's progress updates; it never
// touches CEF itself, so it can be driven directly in tests.
class DownloadModel : public QAbstractListModel
{
    Q_OBJECT
    QML_NAMED_ELEMENT(Downloads)
    QML_SINGLETON
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    Q_PROPERTY(int activeCount READ activeCount NOTIFY progressChanged)
    // 0..1 across the active downloads that know their size, -1 when none do
    Q_PROPERTY(double overallProgress READ overallProgress NOTIFY progressChanged)
    // a download finished since the list was last looked at
    Q_PROPERTY(bool hasUnseen READ hasUnseen NOTIFY hasUnseenChanged)

public:
    enum State { Active, Complete, Cancelled, Failed };
    Q_ENUM(State)

    enum Roles {
        IdRole = Qt::UserRole + 1,
        FileNameRole,
        FilePathRole,
        ReceivedBytesRole,
        TotalBytesRole,
        ProgressRole,
        SpeedRole,
        StateRole,
        StatusTextRole,
    };

    // one progress report from Chromium
    struct Update
    {
        quint32 id = 0;
        QString fullPath;      // empty until the target is chosen
        QString suggestedName; // what to show until then
        qint64 receivedBytes = 0;
        qint64 totalBytes = -1; // -1 when the server didn't say
        qint64 bytesPerSecond = 0;
        bool complete = false;
        bool cancelled = false;
        bool interrupted = false;
    };

    static constexpr int kMaxEntries = 30;

    static DownloadModel &instance();
    static DownloadModel *create(QQmlEngine *, QJSEngine *);

    // No default argument on purpose: given a default constructor, QML builds
    // its own (empty) instance instead of calling create(), and the list the
    // sidebar shows would never see a download.
    explicit DownloadModel(QObject *parent);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int activeCount() const;
    double overallProgress() const;
    bool hasUnseen() const { return m_hasUnseen; }

    // Thread: the Qt thread. |cancel| stops the download in Chromium.
    void applyUpdate(const Update &update, std::function<void()> cancel = {});

    // A free path in |directory| for |suggestedName|: "report.pdf", then
    // "report (1).pdf" and so on, skipping files on disk and paths already
    // handed to downloads still running. Thread-safe; reserves the result.
    QString reservePath(const QString &directory, const QString &suggestedName);
    // the name a download is saved under: no directories, nothing empty
    static QString safeFileName(const QString &suggestedName);
    static QString formatBytes(qint64 bytes);

    Q_INVOKABLE void cancel(quint32 id);
    Q_INVOKABLE bool open(quint32 id) const;
    Q_INVOKABLE bool reveal(quint32 id) const;
    Q_INVOKABLE void clearFinished();
    Q_INVOKABLE void markSeen();

signals:
    void countChanged();
    void progressChanged();
    void hasUnseenChanged();
    // a new download appeared; the sidebar shows the list for a moment
    void downloadStarted(const QString &fileName);
    // a download just finished, for a moment of attention in the UI
    void downloadFinished(const QString &fileName);

private:
    struct Entry
    {
        quint32 id = 0;
        QString fileName;
        QString filePath;
        qint64 receivedBytes = 0;
        qint64 totalBytes = -1;
        qint64 bytesPerSecond = 0;
        State state = Active;
    };

    int rowOf(quint32 id) const;
    QString statusText(const Entry &entry) const;
    void release(const QString &path);
    void setHasUnseen(bool unseen);
    void trim();

    QVector<Entry> m_entries;
    QHash<quint32, std::function<void()>> m_cancel;
    bool m_hasUnseen = false;

    QMutex m_reservedMutex;
    QSet<QString> m_reserved;
};
