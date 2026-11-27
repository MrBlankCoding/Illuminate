#include "DownloadModel.h"

#include <QDesktopServices>
#include <algorithm>
#include <QDir>
#include <QFileInfo>
#include <QJSEngine>
#include <QMutexLocker>
#include <QProcess>
#include <QUrl>

DownloadModel &DownloadModel::instance()
{
    static DownloadModel model(nullptr);
    return model;
}

DownloadModel *DownloadModel::create(QQmlEngine *, QJSEngine *)
{
    DownloadModel *model = &instance();
    QJSEngine::setObjectOwnership(model, QJSEngine::CppOwnership);
    return model;
}

DownloadModel::DownloadModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

int DownloadModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : static_cast<int>(m_entries.size());
}

QVariant DownloadModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_entries.size())
        return {};
    const Entry &entry = m_entries.at(index.row());
    switch (role)
    {
    case IdRole:
        return entry.id;
    case Qt::DisplayRole:
    case FileNameRole:
        return entry.fileName;
    case FilePathRole:
        return entry.filePath;
    case ReceivedBytesRole:
        return entry.receivedBytes;
    case TotalBytesRole:
        return entry.totalBytes;
    case ProgressRole:
        if (entry.state == Complete)
            return 1.0;
        return entry.totalBytes > 0 ? double(entry.receivedBytes) / double(entry.totalBytes) : -1.0;
    case SpeedRole:
        return entry.bytesPerSecond;
    case StateRole:
        return entry.state;
    case StatusTextRole:
        return statusText(entry);
    }
    return {};
}

QHash<int, QByteArray> DownloadModel::roleNames() const
{
    return {
        {IdRole, "downloadId"},
        {FileNameRole, "fileName"},
        {FilePathRole, "filePath"},
        {ReceivedBytesRole, "receivedBytes"},
        {TotalBytesRole, "totalBytes"},
        {ProgressRole, "progress"},
        {SpeedRole, "bytesPerSecond"},
        {StateRole, "downloadState"},
        {StatusTextRole, "statusText"},
    };
}

int DownloadModel::activeCount() const
{
    return static_cast<int>(std::count_if(m_entries.cbegin(), m_entries.cend(),
                                          [](const Entry &e) { return e.state == Active; }));
}

double DownloadModel::overallProgress() const
{
    qint64 received = 0;
    qint64 total = 0;
    for (const Entry &entry : m_entries)
    {
        if (entry.state != Active || entry.totalBytes <= 0)
            continue;
        received += entry.receivedBytes;
        total += entry.totalBytes;
    }
    return total > 0 ? double(received) / double(total) : -1.0;
}

void DownloadModel::applyUpdate(const Update &update, std::function<void()> cancel)
{
    const State state = update.complete      ? Complete
                        : update.cancelled   ? Cancelled
                        : update.interrupted ? Failed
                                             : Active;
    const QString fileName = !update.fullPath.isEmpty() ? QFileInfo(update.fullPath).fileName()
                                                        : safeFileName(update.suggestedName);

    int row = rowOf(update.id);
    const bool added = row < 0;
    if (added)
    {
        // a finished download we never saw start (an update arriving late): nothing to show
        if (state != Active && update.receivedBytes == 0 && update.fullPath.isEmpty())
            return;
        beginInsertRows({}, 0, 0);
        Entry entry;
        entry.id = update.id;
        m_entries.prepend(entry);
        endInsertRows();
        row = 0;
    }

    Entry &entry = m_entries[row];
    const State before = entry.state;
    if (before != Active && !added)
        return; // finished downloads don't change again

    entry.fileName = fileName;
    if (!update.fullPath.isEmpty())
        entry.filePath = update.fullPath;
    entry.receivedBytes = update.receivedBytes;
    entry.totalBytes = state == Complete && update.totalBytes <= 0 ? update.receivedBytes : update.totalBytes;
    entry.bytesPerSecond = state == Active ? update.bytesPerSecond : 0;
    entry.state = state;

    if (state == Active)
    {
        if (cancel)
            m_cancel.insert(update.id, std::move(cancel));
    }
    else
    {
        m_cancel.remove(update.id);
        release(entry.filePath);
    }

    const QModelIndex changed = index(row);
    emit dataChanged(changed, changed);
    if (added)
    {
        trim();
        emit countChanged();
    }
    emit progressChanged();
    if (added && state == Active)
        emit downloadStarted(entry.fileName);

    if (state == Complete && before == Active)
    {
        setHasUnseen(true);
        emit downloadFinished(entry.fileName);
    }
}

QString DownloadModel::safeFileName(const QString &suggestedName)
{
    QString name = suggestedName;
    name.replace(QLatin1Char('\\'), QLatin1Char('/'));
    name = name.section(QLatin1Char('/'), -1).trimmed();
    // never a hidden file or a path that walks out of the folder
    while (name.startsWith(QLatin1Char('.')))
        name.remove(0, 1);
    name.remove(QLatin1Char(':'));
    return name.isEmpty() ? QStringLiteral("download") : name;
}

QString DownloadModel::reservePath(const QString &directory, const QString &suggestedName)
{
    const QString name = safeFileName(suggestedName);
    const QFileInfo info(name);
    // "archive.tar.gz" numbers as "archive (1).tar.gz", like other browsers
    QString base = info.completeBaseName();
    QString suffix = info.suffix();
    if (base.endsWith(QLatin1String(".tar"), Qt::CaseInsensitive))
    {
        base.chop(4);
        suffix = QStringLiteral("tar.") + suffix;
    }
    if (base.isEmpty())
    {
        base = name;
        suffix.clear();
    }

    const QDir dir(directory);
    QMutexLocker lock(&m_reservedMutex);
    for (int n = 0;; ++n)
    {
        QString candidate = n == 0 ? base : QStringLiteral("%1 (%2)").arg(base).arg(n);
        if (!suffix.isEmpty())
            candidate += QLatin1Char('.') + suffix;
        const QString path = dir.filePath(candidate);
        // Chromium writes "<name>.crdownload" while it works; that counts too
        if (!m_reserved.contains(path) && !QFileInfo::exists(path)
            && !QFileInfo::exists(path + QStringLiteral(".crdownload")))
        {
            m_reserved.insert(path);
            return path;
        }
    }
}

void DownloadModel::release(const QString &path)
{
    if (path.isEmpty())
        return;
    QMutexLocker lock(&m_reservedMutex);
    m_reserved.remove(path);
}

QString DownloadModel::formatBytes(qint64 bytes)
{
    if (bytes < 0)
        return QStringLiteral("?");
    if (bytes < 1024)
        return QStringLiteral("%1 B").arg(bytes);
    const double kb = bytes / 1024.0;
    if (kb < 1024)
        return QStringLiteral("%1 KB").arg(kb, 0, 'f', 0);
    const double mb = kb / 1024.0;
    if (mb < 1024)
        return QStringLiteral("%1 MB").arg(mb, 0, 'f', 1);
    return QStringLiteral("%1 GB").arg(mb / 1024.0, 0, 'f', 2);
}

QString DownloadModel::statusText(const Entry &entry) const
{
    switch (entry.state)
    {
    case Complete:
        return formatBytes(entry.totalBytes > 0 ? entry.totalBytes : entry.receivedBytes);
    case Cancelled:
        return tr("Cancelled");
    case Failed:
        return tr("Failed");
    case Active:
        break;
    }
    QString text = entry.totalBytes > 0
        ? tr("%1 of %2").arg(formatBytes(entry.receivedBytes), formatBytes(entry.totalBytes))
        : formatBytes(entry.receivedBytes);
    if (entry.bytesPerSecond > 0)
        text += QStringLiteral(" · %1/s").arg(formatBytes(entry.bytesPerSecond));
    return text;
}

int DownloadModel::rowOf(quint32 id) const
{
    for (int i = 0; i < m_entries.size(); ++i)
        if (m_entries.at(i).id == id)
            return i;
    return -1;
}

void DownloadModel::cancel(quint32 id)
{
    const int row = rowOf(id);
    if (row < 0 || m_entries.at(row).state != Active)
        return;
    if (const auto cancel = m_cancel.take(id))
        cancel();
    // Chromium confirms with a final update; show it as cancelled right away
    Entry &entry = m_entries[row];
    entry.state = Cancelled;
    entry.bytesPerSecond = 0;
    release(entry.filePath);
    const QModelIndex changed = index(row);
    emit dataChanged(changed, changed);
    emit progressChanged();
}

bool DownloadModel::open(quint32 id) const
{
    const int row = rowOf(id);
    if (row < 0 || m_entries.at(row).state != Complete || !QFileInfo::exists(m_entries.at(row).filePath))
        return false;
    return QDesktopServices::openUrl(QUrl::fromLocalFile(m_entries.at(row).filePath));
}

bool DownloadModel::reveal(quint32 id) const
{
    const int row = rowOf(id);
    if (row < 0)
        return false;
    const QString path = m_entries.at(row).filePath;
    const QFileInfo info(path);
    if (path.isEmpty() || !info.exists())
        return false;
#if defined(Q_OS_MACOS)
    return QProcess::startDetached(QStringLiteral("/usr/bin/open"), {QStringLiteral("-R"), path});
#elif defined(Q_OS_WIN)
    return QProcess::startDetached(QStringLiteral("explorer.exe"),
                                   {QStringLiteral("/select,"), QDir::toNativeSeparators(path)});
#else
    return QDesktopServices::openUrl(QUrl::fromLocalFile(info.absolutePath()));
#endif
}

void DownloadModel::clearFinished()
{
    for (int i = static_cast<int>(m_entries.size()) - 1; i >= 0; --i)
    {
        if (m_entries.at(i).state == Active)
            continue;
        beginRemoveRows({}, i, i);
        m_entries.removeAt(i);
        endRemoveRows();
    }
    emit countChanged();
    emit progressChanged();
    setHasUnseen(false);
}

void DownloadModel::markSeen()
{
    setHasUnseen(false);
}

void DownloadModel::setHasUnseen(bool unseen)
{
    if (m_hasUnseen == unseen)
        return;
    m_hasUnseen = unseen;
    emit hasUnseenChanged();
}

// the oldest finished downloads go first; running ones always stay
void DownloadModel::trim()
{
    for (int i = static_cast<int>(m_entries.size()) - 1; i >= 0 && m_entries.size() > kMaxEntries; --i)
    {
        if (m_entries.at(i).state == Active)
            continue;
        beginRemoveRows({}, i, i);
        m_entries.removeAt(i);
        endRemoveRows();
    }
}
