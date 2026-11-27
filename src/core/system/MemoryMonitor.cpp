#include "MemoryMonitor.h"

#include <QCoreApplication>
#include <QDirIterator>
#include <QHash>
#include <QSet>
#include <QStandardPaths>
#include <QJSEngine>
#include <QStringList>
#include <QVariantList>

#include <algorithm>

#if defined(Q_OS_MACOS)
#include <libproc.h>
#include <sys/sysctl.h>
#include <vector>
#elif defined(Q_OS_LINUX)
#include <QDir>
#include <QFile>
#elif defined(Q_OS_WIN)
#include <windows.h>
#include <psapi.h>
#include <tlhelp32.h>
#endif

namespace
{

// pid -> direct children, built once per snapshot
using ChildMap = QHash<qint64, QList<qint64>>;

#if defined(Q_OS_MACOS)

ChildMap childMap(qint64 root)
{
    ChildMap map;
    QList<qint64> queue{root};
    for (qsizetype cursor = 0; cursor < queue.size(); ++cursor)
    {
        const qint64 pid = queue.at(cursor);
        const int bytes = proc_listpids(PROC_PPID_ONLY, uint32_t(pid), nullptr, 0);
        if (bytes <= 0)
            continue;
        // slack in case a child spawns between the two calls
        std::vector<pid_t> pids(bytes / sizeof(pid_t) + 16);
        const int got = proc_listpids(PROC_PPID_ONLY, uint32_t(pid), pids.data(),
                                      int(pids.size() * sizeof(pid_t)));
        for (int i = 0; i < got / int(sizeof(pid_t)); ++i)
        {
            if (pids[i] <= 0)
                continue;
            map[pid].append(pids[i]);
            queue.append(pids[i]);
        }
    }
    return map;
}

// matches the "Memory" column in Activity Monitor
qint64 processBytes(qint64 pid)
{
    rusage_info_v2 info = {};
    if (proc_pid_rusage(pid_t(pid), RUSAGE_INFO_V2, reinterpret_cast<rusage_info_t *>(&info)) != 0)
        return 0;
    return qint64(info.ri_phys_footprint);
}

QStringList processArgs(qint64 pid)
{
    int argMax = 0;
    size_t size = sizeof(argMax);
    int mibMax[2] = {CTL_KERN, KERN_ARGMAX};
    if (sysctl(mibMax, 2, &argMax, &size, nullptr, 0) != 0 || argMax <= 0)
        return {};

    QByteArray buf(argMax, '\0');
    size = size_t(argMax);
    int mib[3] = {CTL_KERN, KERN_PROCARGS2, int(pid)};
    if (sysctl(mib, 3, buf.data(), &size, nullptr, 0) != 0 || size < sizeof(int))
        return {};

    // layout: argc, exec path, NUL padding, argv[0..argc)
    int argc = 0;
    memcpy(&argc, buf.constData(), sizeof(argc));
    const char *p = buf.constData() + sizeof(argc);
    const char *end = buf.constData() + size;
    while (p < end && *p)
        ++p;
    while (p < end && !*p)
        ++p;

    QStringList args;
    while (p < end && args.size() < argc)
    {
        const char *start = p;
        while (p < end && *p)
            ++p;
        args.append(QString::fromLocal8Bit(start, int(p - start)));
        ++p;
    }
    return args;
}

QString metric() { return QStringLiteral("Physical footprint"); }

#elif defined(Q_OS_LINUX)

ChildMap childMap(qint64)
{
    ChildMap map;
    const QStringList entries = QDir(QStringLiteral("/proc")).entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QString &entry : entries)
    {
        bool ok = false;
        const qint64 pid = entry.toLongLong(&ok);
        if (!ok)
            continue;
        QFile f(QStringLiteral("/proc/%1/stat").arg(pid));
        if (!f.open(QIODevice::ReadOnly))
            continue;
        // "pid (comm) state ppid ..."; comm may contain spaces or parens
        const QByteArray stat = f.readAll();
        const int close = stat.lastIndexOf(')');
        if (close < 0)
            continue;
        const QList<QByteArray> fields = stat.mid(close + 2).split(' ');
        if (fields.size() > 1)
            map[fields.at(1).toLongLong()].append(pid);
    }
    return map;
}

qint64 readKb(const QString &path, const QByteArray &key)
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly))
        return -1;
    // /proc pseudo-files report a size of 0, so QFile::atEnd() is true right
    // after open and a readLine()/atEnd() loop would read nothing; readAll()
    // still returns the full contents (verified against smaps_rollup/status)
    const QByteArray all = f.readAll();
    for (const QByteArray &line : all.split('\n'))
    {
        if (line.startsWith(key))
            return line.mid(key.size()).trimmed().split(' ').value(0).toLongLong() * 1024;
    }
    return -1;
}

// PSS splits shared pages between processes, so the sum isn't inflated.
// sandboxed renderers aren't dumpable, which hides smaps; fall back to RSS
qint64 processBytes(qint64 pid)
{
    const qint64 pss = readKb(QStringLiteral("/proc/%1/smaps_rollup").arg(pid), "Pss:");
    if (pss >= 0)
        return pss;
    return std::max<qint64>(0, readKb(QStringLiteral("/proc/%1/status").arg(pid), "VmRSS:"));
}

QStringList processArgs(qint64 pid)
{
    QFile f(QStringLiteral("/proc/%1/cmdline").arg(pid));
    if (!f.open(QIODevice::ReadOnly))
        return {};
    QStringList args;
    for (const QByteArray &a : f.readAll().split('\0'))
        if (!a.isEmpty())
            args.append(QString::fromLocal8Bit(a));
    return args;
}

QString metric() { return QStringLiteral("Proportional set size"); }

#elif defined(Q_OS_WIN)

ChildMap childMap(qint64)
{
    ChildMap map;
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snap == INVALID_HANDLE_VALUE)
        return map;
    PROCESSENTRY32W entry = {};
    entry.dwSize = sizeof(entry);
    for (BOOL ok = Process32FirstW(snap, &entry); ok; ok = Process32NextW(snap, &entry))
        map[entry.th32ParentProcessID].append(entry.th32ProcessID);
    CloseHandle(snap);
    return map;
}

// matches the "Memory" column in Task Manager
qint64 processBytes(qint64 pid)
{
    HANDLE h = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, DWORD(pid));
    if (!h)
        return 0;
    PROCESS_MEMORY_COUNTERS_EX pmc = {};
    qint64 bytes = 0;
    if (GetProcessMemoryInfo(h, reinterpret_cast<PROCESS_MEMORY_COUNTERS *>(&pmc), sizeof(pmc)))
        bytes = qint64(pmc.PrivateUsage);
    CloseHandle(h);
    return bytes;
}

// reading another process's command line needs PEB poking; the page labels
// renderers from tab pids instead
QStringList processArgs(qint64) { return {}; }

QString metric() { return QStringLiteral("Private bytes"); }

#else

ChildMap childMap(qint64) { return {}; }
qint64 processBytes(qint64) { return 0; }
QStringList processArgs(qint64) { return {}; }
QString metric() { return QStringLiteral("Unavailable"); }

#endif

QString argValue(const QStringList &args, QLatin1StringView key)
{
    for (const QString &a : args)
        if (a.startsWith(key))
            return a.mid(key.size());
    return {};
}

// chromium's --type= switch, made readable
QString processType(qint64 pid, bool self)
{
    if (self)
        return QStringLiteral("Browser");

    const QStringList args = processArgs(pid);
    const QString type = argValue(args, QLatin1StringView("--type="));
    if (type == QLatin1String("renderer"))
        return QStringLiteral("Renderer");
    if (type == QLatin1String("gpu-process"))
        return QStringLiteral("GPU");
    if (type == QLatin1String("zygote"))
        return QStringLiteral("Zygote");
    if (type == QLatin1String("utility"))
    {
        // e.g. network.mojom.NetworkService -> Network
        QString sub = argValue(args, QLatin1StringView("--utility-sub-type=")).section(QLatin1Char('.'), 0, 0);
        sub.replace(QLatin1Char('_'), QLatin1Char(' '));
        if (sub.isEmpty())
            return QStringLiteral("Utility");
        sub[0] = sub.at(0).toUpper();
        return sub;
    }
    if (!type.isEmpty())
        return type;
    return QStringLiteral("Helper");
}

} // namespace

MemoryMonitor &MemoryMonitor::instance()
{
    static MemoryMonitor monitor;
    return monitor;
}

MemoryMonitor *MemoryMonitor::create(QQmlEngine *, QJSEngine *)
{
    MemoryMonitor *monitor = &instance();
    // function-local static; the engine must never delete it
    QJSEngine::setObjectOwnership(monitor, QJSEngine::CppOwnership);
    return monitor;
}

QString MemoryMonitor::metricName() const
{
    return metric();
}

qint64 MemoryMonitor::historySizeBytes() const
{
    qint64 total = 0;
    const QString cefDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + QStringLiteral("/cef");
    QDirIterator it(cefDir, QStringList() << QStringLiteral("History*"), QDir::Files, QDirIterator::Subdirectories);
    while (it.hasNext()) {
        it.next();
        total += it.fileInfo().size();
    }
    return total;
}

qint64 MemoryMonitor::diskCacheSizeBytes() const
{
    qint64 total = 0;
    const QString cefDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + QStringLiteral("/cef");
    QDirIterator it(cefDir, QDir::Files, QDirIterator::Subdirectories);
    while (it.hasNext()) {
        it.next();
        const QString path = it.filePath();
        if (path.contains(QStringLiteral("Cache")) || path.contains(QStringLiteral("blob_storage"))) {
            total += it.fileInfo().size();
        }
    }
    return total;
}

QVariantMap MemoryMonitor::snapshot() const
{
    const qint64 self = QCoreApplication::applicationPid();
    const ChildMap children = childMap(self);

    struct Proc
    {
        qint64 pid;
        qint64 bytes;
        QString type;
    };
    QList<Proc> procs;
    qint64 total = 0;

    // walk the tree: chromium on linux forks renderers from the zygote
    // visited guards against pid reuse making a cycle (windows keeps stale ppids)
    QList<qint64> queue{self};
    QSet<qint64> visited;
    for (qsizetype cursor = 0; cursor < queue.size(); ++cursor)
    {
        const qint64 pid = queue.at(cursor);
        if (visited.contains(pid))
            continue;
        visited.insert(pid);
        const qint64 bytes = processBytes(pid);
        procs.append({pid, bytes, processType(pid, pid == self)});
        total += bytes;
        queue.append(children.value(pid));
    }

    std::sort(procs.begin(), procs.end(), [](const Proc &a, const Proc &b) { return a.bytes > b.bytes; });

    QVariantList list;
    list.reserve(procs.size());
    for (const Proc &p : procs)
    {
        list.append(QVariantMap{
            {QStringLiteral("pid"), p.pid},
            {QStringLiteral("bytes"), double(p.bytes)},
            {QStringLiteral("type"), p.type},
            {QStringLiteral("self"), p.pid == self},
        });
    }

    return {
        {QStringLiteral("total"), double(total)},
        {QStringLiteral("processes"), list},
    };
}
