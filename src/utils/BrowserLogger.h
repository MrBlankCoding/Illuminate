#pragma once

#include <QObject>
#include <QFile>
#include <QMutex>
#include <QString>
#include <QDateTime>

// Four levels: DEBUG / INFO / WARNING / ERROR
// writes to console and log file
// renames not to .1 when the log file exceeds 2 MB
// BrowserLogger::instance().log(BrowserLogger::Info, "Navigation", "Loaded https://...");
// BrowserLogger::instance().installAsQtHandler();   // call once in main()

class BrowserLogger : public QObject
{
    Q_OBJECT

public:
    enum Level
    {
        Debug = 0,
        Info,
        Warning,
        Error
    };
    Q_ENUM(Level)

    static BrowserLogger &instance();

    // core call
    void log(Level level, const QString &category, const QString &message);

    // log types
    void debug(const QString &category, const QString &message) { log(Debug, category, message); }
    void info(const QString &category, const QString &message) { log(Info, category, message); }
    void warning(const QString &category, const QString &message) { log(Warning, category, message); }
    void error(const QString &category, const QString &message) { log(Error, category, message); }

    // redirect all qDebug / qWarning / qCritical / qFatal output here.
    void installAsQtHandler();

    // log file path
    // idk why
    // could display in UI or smth
    QString logFilePath() const;

private:
    explicit BrowserLogger(QObject *parent = nullptr);
    ~BrowserLogger() override;

    void openLogFile();
    void rotateIfNeeded();

    static void qtMessageHandler(QtMsgType type,
                                 const QMessageLogContext &ctx,
                                 const QString &msg);

    QFile m_file;
    QMutex m_mutex;
    QString m_logPath;

    static constexpr qint64 kMaxFileBytes = 2 * 1024 * 1024; // 2 MB
};
