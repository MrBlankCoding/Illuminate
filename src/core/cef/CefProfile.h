#pragma once

#include <QObject>
#include <QString>
#include <QtQml/qqmlregistration.h>
#include <include/cef_request_context.h>
#include <include/cef_request_context_handler.h>

#include "ExtensionRegistry.h"

class CefProfile : public QObject
{
    Q_OBJECT
    QML_NAMED_ELEMENT(CefProfile)
    QML_UNCREATABLE("Use Browser.webProfile")

    Q_PROPERTY(QString storagePath READ storagePath CONSTANT)
    Q_PROPERTY(QString cachePath READ cachePath CONSTANT)
    Q_PROPERTY(QString httpUserAgent READ httpUserAgent WRITE setHttpUserAgent NOTIFY httpUserAgentChanged)
    Q_PROPERTY(bool thirdPartyCookiesAllowed READ thirdPartyCookiesAllowed
                   WRITE setThirdPartyCookiesAllowed NOTIFY thirdPartyCookiesAllowedChanged)
    Q_PROPERTY(bool privacyOperationBusy READ privacyOperationBusy NOTIFY privacyOperationBusyChanged)
    Q_PROPERTY(QString privacyOperationStatus READ privacyOperationStatus NOTIFY privacyOperationStatusChanged)
    Q_PROPERTY(ExtensionRegistry *extensions READ extensions CONSTANT)

public:
    explicit CefProfile(const QString &storagePath, const QString &cachePath, QObject *parent = nullptr,
                        bool globalContext = false);
    ~CefProfile() override;

    QString storagePath() const { return m_storagePath; }
    QString cachePath() const { return m_cachePath; }

    QString httpUserAgent() const { return m_userAgent; }
    void setHttpUserAgent(const QString &ua);

    CefRefPtr<CefRequestContext> requestContext();
    bool isRequestContextInitialized() const;
    void markRequestContextInitialized();

    bool thirdPartyCookiesAllowed() const;
    void setThirdPartyCookiesAllowed(bool allowed);
    void setMemorySaverSettings(bool enabled, int aggressiveness);
    bool privacyOperationBusy() const { return m_privacyOperationBusy; }
    QString privacyOperationStatus() const { return m_privacyOperationStatus; }
    Q_INVOKABLE void clearCookies();
    Q_INVOKABLE void clearCache();
    ExtensionRegistry *extensions();
    void finishPrivacyOperation(const QString &message);

    static QString rootCachePath();
    static CefProfile *instance();
    static CefProfile *forSpace(const QString &spaceId, const QString &spaceStoragePath);
    static void setThirdPartyCookiesAllowedForAll(bool allowed);
    static QString storageDir();
    static void releaseAllRequestContexts();

signals:
    void httpUserAgentChanged();
    void thirdPartyCookiesAllowedChanged();
    void requestContextInitialized();
    void privacyOperationBusyChanged();
    void privacyOperationStatusChanged();

private:
    void applyThirdPartyCookiePolicy();
    void applyMemorySaverSettings(bool enabled, int aggressiveness);

    QString m_storagePath;
    QString m_cachePath;
    QString m_userAgent;
    CefRefPtr<CefRequestContext> m_requestContext;
    ExtensionRegistry *m_extensions = nullptr;
    bool m_requestContextInitialized = false;
    bool m_thirdPartyCookiesAllowed = true;
    bool m_privacyOperationBusy = false;
    QString m_privacyOperationStatus;
    bool m_globalContext = false;
};
