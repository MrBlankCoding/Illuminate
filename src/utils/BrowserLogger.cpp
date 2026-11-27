#include "BrowserLogger.h"

#include <QCoreApplication>
#include <QDir>
#include <QStandardPaths>
#include <QDebug>
#include <algorithm>

BrowserLogger &BrowserLogger::instance()
{
    static BrowserLogger inst;
    return inst;
}

BrowserLogger::BrowserLogger(QObject *parent)
    : QObject(parent)
{
    openLogFile();
    log(Info, "Logger", "──── Session started ────");
    log(Info, "Logger", QString("Log file: %1").arg(m_logPath));
}

BrowserLogger::~BrowserLogger()
{
    log(Info, "Logger", "──── Session ended ────");
    QMutexLocker lock(&m_mutex);
    if (m_file.isOpen())
    {
        m_file.close();
    }
}

void BrowserLogger::openLogFile()
{
    const QString logDir = QStandardPaths::writableLocation(
                               QStandardPaths::AppLocalDataLocation) +
                           QStringLiteral("/logs");

    QDir().mkpath(logDir);
    m_logPath = logDir + QStringLiteral("/browser.log");

    m_file.setFileName(m_logPath);
    if (!m_file.open(QIODevice::Append | QIODevice::Text))
    {
        fprintf(stderr, "[BrowserLogger] Failed to open log file: %s\n",
                qPrintable(m_logPath));
    }
}

void BrowserLogger::rotateIfNeeded()
{
    // m_mutex is already held.
    if (m_file.size() < kMaxFileBytes)
        return;

    m_file.close();

    const QString rotated = m_logPath + QStringLiteral(".1");
    QFile::remove(rotated);
    QFile::rename(m_logPath, rotated);

    m_file.setFileName(m_logPath);
    if (!m_file.open(QIODevice::Append | QIODevice::Text))
    {
        fprintf(stderr, "[BrowserLogger] Failed to open rotated log file: %s\n",
                qPrintable(m_logPath));
    }
}

void BrowserLogger::log(Level level, const QString &category, const QString &message)
{
    static const char *levelStr[] = {"DEBUG", "INFO ", "WARN ", "ERROR"};

    const QString timestamp = QDateTime::currentDateTimeUtc()
                                  .toString(QStringLiteral("yyyy-MM-dd hh:mm:ss.zzz"));

    const QString line = QStringLiteral("[%1] [%2] [%3] %4")
                             .arg(timestamp)
                             .arg(QLatin1String(levelStr[std::clamp(static_cast<int>(level), 0, 3)]))
                             .arg(category, -16) // left-align category in 16 chars
                             .arg(message);

    QMutexLocker lock(&m_mutex);

    // write to file
    if (m_file.isOpen())
    {
        rotateIfNeeded();
        m_file.write(line.toUtf8() + '\n');
        // flushing every line stalls the GUI thread on chatty pages; warnings
        // and errors still hit disk immediately so they survive a crash
        if (level >= Warning)
            m_file.flush();
    }

    // mirror to console
    fprintf(stderr, "%s\n", qPrintable(line));
}

QString BrowserLogger::logFilePath() const
{
    return m_logPath;
}

void BrowserLogger::installAsQtHandler()
{
    qInstallMessageHandler(BrowserLogger::qtMessageHandler);
}

void BrowserLogger::qtMessageHandler(QtMsgType type,
                                     const QMessageLogContext &ctx,
                                     const QString &msg)
{
    QString category = QLatin1String(ctx.category ? ctx.category : "Qt");
    if (category == QLatin1String("default"))
        category = ctx.file ? QStringLiteral("Qt/%1").arg(
                                  QString::fromUtf8(ctx.file).section('/', -1))
                            : QStringLiteral("Qt");

    Level level = Info;
    switch (type)
    {
    case QtDebugMsg:
        level = Debug;
        break;
    case QtInfoMsg:
        level = Info;
        break;
    case QtWarningMsg:
        level = Warning;
        break;
    case QtCriticalMsg:
        level = Error;
        break;
    case QtFatalMsg:
        level = Error;
        break;
    }

    BrowserLogger::instance().log(level, category, msg);

    // abort!
    // am i on a submarine?
    if (type == QtFatalMsg)
        std::abort();
}
