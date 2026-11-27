#pragma once

#include <include/cef_permission_handler.h>
#include <include/cef_task.h>
#include <QObject>
#include <QPointer>
#include <QUrl>
#include <QHash>

#include <memory>

class CefBrowserWrapper;
class CefPermissionRequest : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QUrl origin READ origin CONSTANT)
    Q_PROPERTY(int permissionType READ permissionType CONSTANT)

public:
    explicit CefPermissionRequest(const QUrl &origin,
                                  int type,
                                  CefRefPtr<CefPermissionPromptCallback> callback,
                                  QObject *parent = nullptr);
    CefPermissionRequest(const QUrl &origin,
                         int type,
                         uint32_t requestedPermissions,
                         CefRefPtr<CefMediaAccessCallback> callback,
                         QObject *parent = nullptr);

    // an unanswered prompt is denied, so CEF never waits on it forever
    ~CefPermissionRequest() override;

    QUrl origin() const { return m_origin; }
    int permissionType() const { return m_type; }

    // both answer once and then deleteLater() the request
    Q_INVOKABLE void grant();
    Q_INVOKABLE void deny();


    void invalidate() { m_callback = nullptr; m_mediaCallback = nullptr; }
    bool answered() const { return m_answered; }

private:
    void answer(cef_permission_request_result_t result);
    void answerMedia(bool allow);

    QUrl m_origin;
    int m_type;
    CefRefPtr<CefPermissionPromptCallback> m_callback;
    CefRefPtr<CefMediaAccessCallback> m_mediaCallback;
    uint32_t m_requestedPermissions = 0;
    bool m_answered = false;
};

class CefPermissionHandlerImpl : public CefPermissionHandler
{
public:
    explicit CefPermissionHandlerImpl(CefBrowserWrapper *wrapper);
    void setWrapper(CefBrowserWrapper *wrapper);

    bool OnRequestMediaAccessPermission(CefRefPtr<CefBrowser> browser,
                                        CefRefPtr<CefFrame> frame,
                                        const CefString &requesting_url,
                                        uint32_t requested_permissions,
                                        CefRefPtr<CefMediaAccessCallback> callback) override;

    bool OnShowPermissionPrompt(CefRefPtr<CefBrowser> browser,
                                uint64_t prompt_id,
                                const CefString &requesting_origin,
                                uint32_t requested_permissions,
                                CefRefPtr<CefPermissionPromptCallback> callback) override;

    void OnDismissPermissionPrompt(CefRefPtr<CefBrowser> browser,
                                   uint64_t prompt_id,
                                   cef_permission_request_result_t result) override;

private:
    struct PendingPromptState
    {
        QHash<uint64_t, QPointer<CefPermissionRequest>> prompts;
    };

    void trackOnQtThread(uint64_t promptId, QPointer<CefPermissionRequest> request);
    void invalidateOnQtThread(uint64_t promptId);

    QPointer<CefBrowserWrapper> m_wrapper;
    std::shared_ptr<PendingPromptState> m_pendingPromptState = std::make_shared<PendingPromptState>();

    IMPLEMENT_REFCOUNTING(CefPermissionHandlerImpl);
};
