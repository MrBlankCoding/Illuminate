#include "PermissionHandler.h"

#include <QCoreApplication>
#include <QDesktopServices>
#include <QDir>
#include <QProcess>
#include <QSettings>
#include <QTimer>

#if defined(Q_OS_LINUX)
namespace { const QString kDesktopFile = QStringLiteral("illuminate.desktop"); }
#elif defined(Q_OS_WIN)
namespace {
const QString kProgId = QStringLiteral("illuminate.URL");
const QString kAppName = QStringLiteral("illuminate");
}
#endif

#if defined(Q_OS_LINUX)

// no OS-level gate for desktop apps; portals prompt on their own
PermissionHandler::SystemAccess PermissionHandler::platformSystemAccess(SystemResource)
{
    return Granted;
}

void PermissionHandler::platformRequestSystemAccess(SystemResource)
{
    emit systemAccessChanged();
}

void PermissionHandler::platformOpenSystemSettings(SystemResource)
{
}

bool PermissionHandler::platformIsDefaultBrowser()
{
    QProcess p;
    p.start(QStringLiteral("xdg-settings"),
            {QStringLiteral("check"), QStringLiteral("default-web-browser"), kDesktopFile});
    if (!p.waitForFinished(2000))
        return false;
    return p.readAllStandardOutput().trimmed() == "yes";
}

void PermissionHandler::platformMakeDefaultBrowser()
{
    auto *p = new QProcess(this);
    connect(p, &QProcess::finished, this, [this, p](int code, QProcess::ExitStatus status) {
        const bool ok = status == QProcess::NormalExit && code == 0;
        finishDefaultBrowserRequest(ok, ok ? QString()
                                           : QStringLiteral("xdg-settings failed: ")
                                                 + QString::fromLocal8Bit(p->readAllStandardError()).trimmed());
        p->deleteLater();
    });
    connect(p, &QProcess::errorOccurred, this, [this, p](QProcess::ProcessError err) {
        if (err != QProcess::FailedToStart)
            return;
        finishDefaultBrowserRequest(false, QStringLiteral("xdg-settings is not installed"));
        p->deleteLater();
    });
    p->start(QStringLiteral("xdg-settings"),
             {QStringLiteral("set"), QStringLiteral("default-web-browser"), kDesktopFile});
}


#elif defined(Q_OS_WIN)

namespace {
QString consentStoreKey(PermissionHandler::SystemResource resource)
{
    switch (resource) {
    case PermissionHandler::Camera:     return QStringLiteral("webcam");
    case PermissionHandler::Microphone: return QStringLiteral("microphone");
    case PermissionHandler::Location:   return QStringLiteral("location");
    default:                            return QString();
    }
}
}

PermissionHandler::SystemAccess PermissionHandler::platformSystemAccess(SystemResource resource)
{
    const QString store = consentStoreKey(resource);
    if (store.isEmpty())
        return Granted;
    // the global switch, then the one covering non-Store desktop apps
    const QString base = QStringLiteral("HKEY_CURRENT_USER\\Software\\Microsoft\\Windows\\CurrentVersion\\CapabilityAccessManager\\ConsentStore\\") + store;
    for (const QString &path : {base, base + QStringLiteral("\\NonPackaged")})
    {
        QSettings s(path, QSettings::NativeFormat);
        if (s.value(QStringLiteral("Value")).toString() == QStringLiteral("Deny"))
            return Denied;
    }
    return Granted;
}

// Windows never prompts desktop apps; access is a Settings toggle
void PermissionHandler::platformRequestSystemAccess(SystemResource resource)
{
    if (platformSystemAccess(resource) == Denied)
        platformOpenSystemSettings(resource);
    emit systemAccessChanged();
}

void PermissionHandler::platformOpenSystemSettings(SystemResource resource)
{
    QString page;
    switch (resource) {
    case Camera:        page = QStringLiteral("privacy-webcam"); break;
    case Microphone:    page = QStringLiteral("privacy-microphone"); break;
    case Location:      page = QStringLiteral("privacy-location"); break;
    case ScreenCapture: page = QStringLiteral("privacy"); break;
    }
    QDesktopServices::openUrl(QUrl(QStringLiteral("ms-settings:") + page));
}

bool PermissionHandler::platformIsDefaultBrowser()
{
    QSettings choice(QStringLiteral("HKEY_CURRENT_USER\\Software\\Microsoft\\Windows\\Shell\\Associations\\UrlAssociations\\https\\UserChoice"),
                     QSettings::NativeFormat);
    return choice.value(QStringLiteral("ProgId")).toString() == kProgId;
}

void PermissionHandler::platformMakeDefaultBrowser()
{
    const QString exe = QDir::toNativeSeparators(QCoreApplication::applicationFilePath());

    QSettings progId(QStringLiteral("HKEY_CURRENT_USER\\Software\\Classes\\") + kProgId,
                     QSettings::NativeFormat);
    progId.setValue(QStringLiteral("Default"), QStringLiteral("illuminate URL"));
    progId.setValue(QStringLiteral("URL Protocol"), QString());
    progId.setValue(QStringLiteral("shell/open/command/Default"),
                    QStringLiteral("\"%1\" \"%2\"").arg(exe, QStringLiteral("%1")));

    QSettings caps(QStringLiteral("HKEY_CURRENT_USER\\Software\\") + kAppName + QStringLiteral("\\Capabilities"),
                   QSettings::NativeFormat);
    caps.setValue(QStringLiteral("ApplicationName"), kAppName);
    caps.setValue(QStringLiteral("ApplicationDescription"), QStringLiteral("A Chromium Embedded browser"));
    caps.setValue(QStringLiteral("URLAssociations/http"), kProgId);
    caps.setValue(QStringLiteral("URLAssociations/https"), kProgId);

    QSettings registered(QStringLiteral("HKEY_CURRENT_USER\\Software\\RegisteredApplications"),
                         QSettings::NativeFormat);
    registered.setValue(kAppName, QStringLiteral("Software\\") + kAppName + QStringLiteral("\\Capabilities"));

    progId.sync();
    caps.sync();
    registered.sync();

    const bool opened = QDesktopServices::openUrl(
        QUrl(QStringLiteral("ms-settings:defaultapps?registeredAppUser=") + kAppName));
    // the choice happens in Settings; re-check when the user comes back
    QTimer::singleShot(0, this, [this, opened]() {
        finishDefaultBrowserRequest(opened, QStringLiteral("Could not open Windows Default Apps settings"));
    });
}


#elif !defined(Q_OS_MACOS)

PermissionHandler::SystemAccess PermissionHandler::platformSystemAccess(SystemResource)
{
    return Granted;
}

void PermissionHandler::platformRequestSystemAccess(SystemResource)
{
    emit systemAccessChanged();
}

void PermissionHandler::platformOpenSystemSettings(SystemResource)
{
}

bool PermissionHandler::platformIsDefaultBrowser()
{
    return false;
}

void PermissionHandler::platformMakeDefaultBrowser()
{
    QTimer::singleShot(0, this, [this]() {
        finishDefaultBrowserRequest(false, QStringLiteral("Setting the default browser isn't supported on this platform"));
    });
}

#endif
