#pragma once

#include <QObject>
#include <QUrl>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>
#include "utils/ExternalQmlSingleton.h"

// preserving exact integer values for QSettings compatibility.
class QSettings;
class PermissionHandler : public QObject, public ExternalQmlSingleton<PermissionHandler>
{
    Q_OBJECT
    QML_NAMED_ELEMENT(Permissions)
    QML_SINGLETON

    Q_PROPERTY(bool isDefaultBrowser READ isDefaultBrowser NOTIFY isDefaultBrowserChanged)
    Q_PROPERTY(bool defaultBrowserBusy READ defaultBrowserBusy NOTIFY defaultBrowserBusyChanged)
    Q_PROPERTY(bool defaultBrowserOpensSystemSettings READ defaultBrowserOpensSystemSettings CONSTANT)

public:
    enum Decision : int { Deny = -1, Ask = 0, Allow = 1 };
    Q_ENUM(Decision)

    enum PermissionType : int {
        Unsupported = 0,
        MediaAudioCapture = 1,
        MediaVideoCapture = 2,
        MediaAudioVideoCapture = 3,
        DesktopVideoCapture = 4,
        DesktopAudioVideoCapture = 5,
        MouseLock = 6,
        Notifications = 7,
        Geolocation = 8,
        ClipboardReadWrite = 9,
        LocalFontsAccess = 10,
    };
    Q_ENUM(PermissionType)

    enum SystemResource : int { Camera, Microphone, Location, ScreenCapture }; // could be more
    Q_ENUM(SystemResource)

    enum SystemAccess : int { Granted, NotDetermined, Denied };
    Q_ENUM(SystemAccess)

    explicit PermissionHandler(QObject *parent);

    // ── site permissions ────────────────────────────────────────────
    Q_INVOKABLE bool resolve(QObject *permission) const;
    Q_INVOKABLE bool resolve(const QUrl &origin, int type) const;
    Q_INVOKABLE void respond(QObject *permission, bool allow, bool remember);
    Q_INVOKABLE void respond(const QUrl &origin, int type, bool allow, bool remember);

    Q_INVOKABLE int decision(const QUrl &origin, int type) const;
    Q_INVOKABLE void storeDecision(const QUrl &origin, int type, bool allow, bool remember);
    Q_INVOKABLE void forget(const QUrl &origin, int type);
    Q_INVOKABLE void forgetAll();
    // [{ host, type, label, allow }]
    Q_INVOKABLE QVariantList rememberedDecisions() const;

    Q_INVOKABLE QString labelForType(int type) const;

    // os
    Q_INVOKABLE int systemAccess(int resource) const;
    Q_INVOKABLE int systemAccessForType(int type) const;
    Q_INVOKABLE int blockedResourceForType(int type) const;
    Q_INVOKABLE void requestSystemAccess(int resource);
    Q_INVOKABLE void openSystemSettings(int resource);
    Q_INVOKABLE QString labelForResource(int resource) const;

    // default browser
    bool isDefaultBrowser() const;
    bool defaultBrowserBusy() const;
    bool defaultBrowserOpensSystemSettings() const;
    Q_INVOKABLE void refreshDefaultBrowser();
    Q_INVOKABLE void makeDefaultBrowser();

signals:
    void decisionsChanged();
    void systemAccessChanged();
    void isDefaultBrowserChanged();
    void defaultBrowserBusyChanged();
    void defaultBrowserFailed(const QString &message);

private:
    static PermissionType toType(int v);
    static QList<SystemResource> resourcesForType(int type);
    QString key(const QUrl &origin, int type) const;

    void setIsDefaultBrowser(bool value);
    void setDefaultBrowserBusy(bool value);
    void finishDefaultBrowserRequest(bool ok, const QString &error);

    // per-platform, in PermissionHandler.cpp / PermissionHandler_mac.mm
    static SystemAccess platformSystemAccess(SystemResource resource);
    void platformRequestSystemAccess(SystemResource resource);
    static void platformOpenSystemSettings(SystemResource resource);
    static bool platformIsDefaultBrowser();
    void platformMakeDefaultBrowser();

    QSettings *m_settings;
    bool m_isDefaultBrowser = false;
    bool m_defaultBrowserBusy = false;
    bool m_defaultBrowserChecked = false;
};
