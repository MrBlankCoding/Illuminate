#include "PermissionHandler.h"
#include "../utils/BrowserLogger.h"

#include <QCoreApplication>
#include <algorithm>
#include <QDir>
#include <QGuiApplication>
#include <QSettings>
#include <QStandardPaths>
#include <QTimer>
#include <QByteArray>

namespace {
const QString kGroup = QStringLiteral("permissions");
}

PermissionHandler::PermissionHandler(QObject *parent)
    : QObject(parent),
      m_settings(new QSettings(QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)
                               + QDir::separator() + QStringLiteral("permissions.ini"),
                               QSettings::IniFormat, this))
{
    // default browser and OS privacy choices are made in system dialogs or
    // Settings; re-check when the user comes back
    if (qGuiApp)
    {
        connect(qGuiApp, &QGuiApplication::applicationStateChanged, this,
                [this](Qt::ApplicationState state) {
                    if (state != Qt::ApplicationActive)
                        return;
                    if (m_defaultBrowserChecked)
                        refreshDefaultBrowser();
                    emit systemAccessChanged();
                });
    }
}

// ── site permissions ────────────────────────────────────────────────

PermissionHandler::PermissionType PermissionHandler::toType(int v)
{
    return static_cast<PermissionHandler::PermissionType>(v);
}

QString PermissionHandler::key(const QUrl &origin, int type) const
{
    QUrl normalized = origin;
    normalized.setPath(QString());
    normalized.setQuery(QString());
    normalized.setFragment(QString());
    normalized.setUserInfo(QString());
    const QByteArray encoded = normalized.toString(QUrl::FullyEncoded).toUtf8()
                                   .toBase64(QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals);
    return QStringLiteral("%1/sites/%2/%3").arg(kGroup, QString::fromLatin1(encoded), QString::number(type));
}

QString PermissionHandler::labelForType(int type) const
{
    using T = PermissionType;
    switch (toType(type)) {
    case T::MediaAudioCapture:        return QStringLiteral("Microphone");
    case T::MediaVideoCapture:        return QStringLiteral("Camera");
    case T::MediaAudioVideoCapture:   return QStringLiteral("Camera and Microphone");
    case T::DesktopVideoCapture:      return QStringLiteral("Screen capture");
    case T::DesktopAudioVideoCapture: return QStringLiteral("Screen capture");
    case T::MouseLock:                return QStringLiteral("Mouse lock");
    case T::Notifications:            return QStringLiteral("Notifications");
    case T::Geolocation:              return QStringLiteral("Location");
    case T::ClipboardReadWrite:       return QStringLiteral("Clipboard");
    case T::LocalFontsAccess:         return QStringLiteral("Fonts");
    case T::Unsupported:
    default: return QStringLiteral("Permission");
    }
}

bool PermissionHandler::resolve(const QUrl &origin, int type) const
{
    if (toType(type) == Unsupported)
        return false;
    const int dec = decision(origin, type);
    return (dec != Ask);
}

bool PermissionHandler::resolve(QObject *permission) const
{
    if (!permission)
        return false;
    const QUrl origin = permission->property("origin").toUrl();
    const int type = permission->property("permissionType").toInt();
    const int dec = decision(origin, type);
    if (dec == Allow) {
        QMetaObject::invokeMethod(permission, "grant");
        return true;
    }
    if (dec == Deny) {
        QMetaObject::invokeMethod(permission, "deny");
        return true;
    }
    return false;
}

void PermissionHandler::respond(const QUrl &origin, int type, bool allow, bool remember)
{
    storeDecision(origin, type, allow, remember);
}

void PermissionHandler::respond(QObject *permission, bool allow, bool remember)
{
    if (!permission)
        return;
    if (allow)
        QMetaObject::invokeMethod(permission, "grant");
    else
        QMetaObject::invokeMethod(permission, "deny");

    const QUrl origin = permission->property("origin").toUrl();
    const int type = permission->property("permissionType").toInt();
    storeDecision(origin, type, allow, remember);
}

int PermissionHandler::decision(const QUrl &origin, int type) const
{
    if (toType(type) == Unsupported)
        return Ask;
    QString v = m_settings->value(key(origin, type)).toString();
    // Old entries stored only a host, so scope them to HTTPS (the secure
    // origin on which browser permissions are normally available) instead
    // of carrying a remembered allow over to an HTTP origin.
    if (v.isEmpty() && origin.scheme().compare(QLatin1String("https"), Qt::CaseInsensitive) == 0)
        v = m_settings->value(QStringLiteral("%1/%2/%3").arg(kGroup, origin.host(), QString::number(type))).toString();
    if (v == QStringLiteral("allow")) return Allow;
    if (v == QStringLiteral("deny"))  return Deny;
    return Ask;
}

void PermissionHandler::storeDecision(const QUrl &origin, int type, bool allow, bool remember)
{
    if (!remember || toType(type) == Unsupported)
        return;
    m_settings->setValue(key(origin, type), allow ? QStringLiteral("allow") : QStringLiteral("deny"));
    BrowserLogger::instance().info("Permissions",
        (allow ? "Remembered allow " : "Remembered deny ")
        + labelForType(type) + " for " + origin.host());
    emit decisionsChanged();
}

void PermissionHandler::forget(const QUrl &origin, int type)
{
    m_settings->remove(key(origin, type));
    m_settings->remove(QStringLiteral("%1/%2/%3").arg(kGroup, origin.host(), QString::number(type)));
    emit decisionsChanged();
}

void PermissionHandler::forgetAll()
{
    m_settings->remove(kGroup);
    emit decisionsChanged();
}

QVariantList PermissionHandler::rememberedDecisions() const
{
    QVariantList out;
    m_settings->beginGroup(kGroup + QStringLiteral("/sites"));
    for (const QString &host : m_settings->childGroups())
    {
        const QString encodedOrigin = host;
        const QUrl origin = QUrl::fromEncoded(QByteArray::fromBase64(encodedOrigin.toLatin1(),
            QByteArray::Base64UrlEncoding));
        m_settings->beginGroup(encodedOrigin);
        for (const QString &typeKey : m_settings->childKeys())
        {
            const int type = typeKey.toInt();
            out.append(QVariantMap{
                {QStringLiteral("host"), origin.host()},
                {QStringLiteral("origin"), origin.toString()},
                {QStringLiteral("type"), type},
                {QStringLiteral("label"), labelForType(type)},
                {QStringLiteral("allow"), m_settings->value(typeKey).toString() == QStringLiteral("allow")},
            });
        }
        m_settings->endGroup();
    }
    m_settings->endGroup();

    // Surface choices saved by older builds, which keyed permissions by host
    // only, so users can still review and revoke them after upgrading.
    m_settings->beginGroup(kGroup);
    for (const QString &host : m_settings->childGroups())
    {
        if (host == QLatin1String("sites"))
            continue;
        m_settings->beginGroup(host);
        for (const QString &typeKey : m_settings->childKeys())
        {
            const int type = typeKey.toInt();
            out.append(QVariantMap{
                {QStringLiteral("host"), host},
                {QStringLiteral("origin"), QStringLiteral("https://") + host},
                {QStringLiteral("type"), type},
                {QStringLiteral("label"), labelForType(type)},
                {QStringLiteral("allow"), m_settings->value(typeKey).toString() == QStringLiteral("allow")},
            });
        }
        m_settings->endGroup();
    }
    m_settings->endGroup();
    return out;
}

// ── OS access ──────────────────────────────────────────────────────

QList<PermissionHandler::SystemResource> PermissionHandler::resourcesForType(int type)
{
    using T = PermissionType;
    switch (toType(type)) {
    case T::MediaAudioCapture:        return {Microphone};
    case T::MediaVideoCapture:        return {Camera};
    case T::MediaAudioVideoCapture:   return {Camera, Microphone};
    case T::DesktopVideoCapture:      return {ScreenCapture};
    case T::DesktopAudioVideoCapture: return {ScreenCapture, Microphone};
    case T::Geolocation:              return {Location};
    default:                          return {};
    }
}

int PermissionHandler::systemAccess(int resource) const
{
    return platformSystemAccess(static_cast<SystemResource>(resource));
}

int PermissionHandler::systemAccessForType(int type) const
{
    SystemAccess worst = Granted;
    for (SystemResource r : resourcesForType(type))
        worst = (std::max)(worst, platformSystemAccess(r));
    return worst;
}

int PermissionHandler::blockedResourceForType(int type) const
{
    for (SystemResource r : resourcesForType(type))
        if (platformSystemAccess(r) == Denied)
            return r;
    return -1;
}

void PermissionHandler::requestSystemAccess(int resource)
{
    platformRequestSystemAccess(static_cast<SystemResource>(resource));
}

void PermissionHandler::openSystemSettings(int resource)
{
    platformOpenSystemSettings(static_cast<SystemResource>(resource));
}

QString PermissionHandler::labelForResource(int resource) const
{
    switch (static_cast<SystemResource>(resource)) {
    case Camera:        return QStringLiteral("Camera");
    case Microphone:    return QStringLiteral("Microphone");
    case Location:      return QStringLiteral("Location");
    case ScreenCapture: return QStringLiteral("Screen recording");
    }
    return QString();
}


bool PermissionHandler::isDefaultBrowser() const
{
    if (!m_defaultBrowserChecked)
    {
        auto *self = const_cast<PermissionHandler *>(this);
        self->m_defaultBrowserChecked = true;
        self->m_isDefaultBrowser = platformIsDefaultBrowser();
    }
    return m_isDefaultBrowser;
}

bool PermissionHandler::defaultBrowserBusy() const
{
    return m_defaultBrowserBusy;
}

bool PermissionHandler::defaultBrowserOpensSystemSettings() const
{
#if defined(Q_OS_WIN)
    return true;
#else
    return false;
#endif
}

void PermissionHandler::refreshDefaultBrowser()
{
    m_defaultBrowserChecked = true;
    setIsDefaultBrowser(platformIsDefaultBrowser());
}

void PermissionHandler::makeDefaultBrowser()
{
    if (m_defaultBrowserBusy)
        return;
    setDefaultBrowserBusy(true);
    platformMakeDefaultBrowser();
}

void PermissionHandler::setIsDefaultBrowser(bool value)
{
    if (m_isDefaultBrowser == value)
        return;
    m_isDefaultBrowser = value;
    emit isDefaultBrowserChanged();
}

void PermissionHandler::setDefaultBrowserBusy(bool value)
{
    if (m_defaultBrowserBusy == value)
        return;
    m_defaultBrowserBusy = value;
    emit defaultBrowserBusyChanged();
}

void PermissionHandler::finishDefaultBrowserRequest(bool ok, const QString &error)
{
    setDefaultBrowserBusy(false);
    refreshDefaultBrowser();
    if (!ok)
    {
        BrowserLogger::instance().warning("Permissions", error);
        emit defaultBrowserFailed(error);
    }
}
