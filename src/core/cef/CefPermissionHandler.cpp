#include "CefPermissionHandler.h"
#include "CefBrowserWrapper.h"
#include "PermissionHandler.h"
#include "../utils/cef_helpers.h"
#include "../utils/BrowserLogger.h"

#include <QCoreApplication>
#include <QMetaObject>

CefPermissionRequest::CefPermissionRequest(const QUrl &origin,
                                           int type,
                                           uint32_t requestedPermissions,
                                           CefRefPtr<CefMediaAccessCallback> callback,
                                           QObject *parent)
    : QObject(parent), m_origin(origin), m_type(type),
      m_mediaCallback(std::move(callback)), m_requestedPermissions(requestedPermissions)
{
}

CefPermissionRequest::CefPermissionRequest(const QUrl &origin,
                                           int type,
                                           CefRefPtr<CefPermissionPromptCallback> callback,
                                           QObject *parent)
    : QObject(parent), m_origin(origin), m_type(type), m_callback(callback)
{
}

CefPermissionRequest::~CefPermissionRequest()
{
    if (m_mediaCallback)
        answerMedia(false);
    else
        answer(CEF_PERMISSION_RESULT_DENY);
}

namespace {
class ContinuePermissionTask : public CefTask
{
public:
    ContinuePermissionTask(CefRefPtr<CefPermissionPromptCallback> callback,
                           cef_permission_request_result_t result)
        : m_callback(std::move(callback)), m_result(result)
    {
    }

    void Execute() override
    {
        if (m_callback)
            m_callback->Continue(m_result);
    }

private:
    CefRefPtr<CefPermissionPromptCallback> m_callback;
    cef_permission_request_result_t m_result;

    IMPLEMENT_REFCOUNTING(ContinuePermissionTask);
};

} // namespace

namespace {
class ContinueMediaPermissionTask final : public CefTask
{
public:
    ContinueMediaPermissionTask(CefRefPtr<CefMediaAccessCallback> callback,
                                uint32_t permissions, bool allow)
        : m_callback(std::move(callback)), m_permissions(permissions), m_allow(allow) {}
    void Execute() override
    {
        if (!m_callback)
            return;
        if (m_allow)
            m_callback->Continue(m_permissions);
        else
            m_callback->Cancel();
    }
private:
    CefRefPtr<CefMediaAccessCallback> m_callback;
    uint32_t m_permissions;
    bool m_allow;
    IMPLEMENT_REFCOUNTING(ContinueMediaPermissionTask);
};
} // namespace

void CefPermissionRequest::answer(cef_permission_request_result_t result)
{
    if (m_answered)
        return;
    m_answered = true;
    CefRefPtr<CefPermissionPromptCallback> callback = m_callback;
    m_callback = nullptr;

    if (CefCurrentlyOn(TID_UI)) {
        if (callback)
            callback->Continue(result);
        return;
    }

    if (!callback)
        return;
    CefPostTask(TID_UI, new ContinuePermissionTask(callback, result));
}

void CefPermissionRequest::grant()
{
    if (m_answered)
        return;
    if (m_mediaCallback) {
        answerMedia(true);
        deleteLater();
        return;
    }
    answer(CEF_PERMISSION_RESULT_ACCEPT);
    deleteLater();
}

void CefPermissionRequest::deny()
{
    if (m_answered)
        return;
    if (m_mediaCallback) {
        answerMedia(false);
        deleteLater();
        return;
    }
    answer(CEF_PERMISSION_RESULT_DENY);
    deleteLater();
}

void CefPermissionRequest::answerMedia(bool allow)
{
    if (m_answered)
        return;
    m_answered = true;
    CefRefPtr<CefMediaAccessCallback> callback = m_mediaCallback;
    m_mediaCallback = nullptr;
    if (!callback)
        return;
    if (CefCurrentlyOn(TID_UI)) {
        if (allow)
            callback->Continue(m_requestedPermissions);
        else
            callback->Cancel();
        return;
    }
    CefPostTask(TID_UI, new ContinueMediaPermissionTask(callback, m_requestedPermissions, allow));
}

CefPermissionHandlerImpl::CefPermissionHandlerImpl(CefBrowserWrapper *wrapper)
    : m_wrapper(wrapper)
{
}

bool CefPermissionHandlerImpl::OnRequestMediaAccessPermission(CefRefPtr<CefBrowser> browser,
                                                              CefRefPtr<CefFrame> frame,
                                                              const CefString &requesting_url,
                                                              uint32_t requested_permissions,
                                                              CefRefPtr<CefMediaAccessCallback> callback)
{
    Q_UNUSED(browser);
    Q_UNUSED(frame);
    const bool audio = requested_permissions & CEF_MEDIA_PERMISSION_DEVICE_AUDIO_CAPTURE;
    const bool video = requested_permissions & CEF_MEDIA_PERMISSION_DEVICE_VIDEO_CAPTURE;
    const bool desktopAudio = requested_permissions & CEF_MEDIA_PERMISSION_DESKTOP_AUDIO_CAPTURE;
    const bool desktopVideo = requested_permissions & CEF_MEDIA_PERMISSION_DESKTOP_VIDEO_CAPTURE;
    int type = PermissionHandler::Unsupported;
    if (desktopAudio || desktopVideo)
        type = desktopAudio && desktopVideo ? PermissionHandler::DesktopAudioVideoCapture
                                           : PermissionHandler::DesktopVideoCapture;
    else if (audio && video)
        type = PermissionHandler::MediaAudioVideoCapture;
    else if (audio)
        type = PermissionHandler::MediaAudioCapture;
    else if (video)
        type = PermissionHandler::MediaVideoCapture;

    if (type == PermissionHandler::Unsupported || !m_wrapper) {
        callback->Cancel();
        return true;
    }
    auto *req = new CefPermissionRequest(cefStringToQUrl(requesting_url), type,
                                         requested_permissions, callback);
    req->moveToThread(QCoreApplication::instance()->thread());
    QMetaObject::invokeMethod(QCoreApplication::instance(), [wrapper = m_wrapper, req]() {
        if (wrapper) {
            req->setParent(wrapper);
            emit wrapper->permissionRequested(req);
        } else {
            delete req;
        }
    }, Qt::QueuedConnection);
    return true;
}

bool CefPermissionHandlerImpl::OnShowPermissionPrompt(CefRefPtr<CefBrowser> browser,
                                                      uint64_t prompt_id,
                                                      const CefString &requesting_origin,
                                                      uint32_t requested_permissions,
                                                      CefRefPtr<CefPermissionPromptCallback> callback)
{
    Q_UNUSED(browser);
    Q_UNUSED(prompt_id);

    const QUrl origin = cefStringToQUrl(requesting_origin);
    int type = PermissionHandler::Unsupported;

    const uint32_t cameraMic = CEF_PERMISSION_TYPE_CAMERA_STREAM | CEF_PERMISSION_TYPE_MIC_STREAM;
    if ((requested_permissions & cameraMic) == cameraMic && (requested_permissions & ~cameraMic) == 0)
        type = PermissionHandler::MediaAudioVideoCapture;
    else if (requested_permissions == CEF_PERMISSION_TYPE_GEOLOCATION)
        type = PermissionHandler::Geolocation;
    else if (requested_permissions == CEF_PERMISSION_TYPE_NOTIFICATIONS)
        type = PermissionHandler::Notifications;
    else if (requested_permissions == CEF_PERMISSION_TYPE_CAMERA_STREAM)
        type = PermissionHandler::MediaVideoCapture;
    else if (requested_permissions == CEF_PERMISSION_TYPE_MIC_STREAM)
        type = PermissionHandler::MediaAudioCapture;
    else if (requested_permissions == CEF_PERMISSION_TYPE_CLIPBOARD)
        type = PermissionHandler::ClipboardReadWrite;
    else if (requested_permissions == CEF_PERMISSION_TYPE_LOCAL_FONTS)
        type = PermissionHandler::LocalFontsAccess;
    else if (requested_permissions == CEF_PERMISSION_TYPE_POINTER_LOCK ||
             requested_permissions == CEF_PERMISSION_TYPE_KEYBOARD_LOCK)
        type = PermissionHandler::MouseLock;

    // Something we can't name to the person (MIDI, window management, a
    // bundle mixing kinds): a generic "Allow?" would grant all of it blind.
    if (type == PermissionHandler::Unsupported)
    {
        BrowserLogger::instance().info("Permissions", QStringLiteral("Denied unsupported permission request 0x%1 from %2")
            .arg(requested_permissions, 0, 16).arg(origin.toDisplayString()));
        callback->Continue(CEF_PERMISSION_RESULT_DENY);
        return true;
    }

    if (m_wrapper)
    {
        auto *req = new CefPermissionRequest(origin, type, callback);
        req->moveToThread(QCoreApplication::instance()->thread());
        trackOnQtThread(prompt_id, req);
        QMetaObject::invokeMethod(QCoreApplication::instance(), [wrapper = m_wrapper, req]() {
            if (wrapper)
            {
                req->setParent(wrapper);
                emit wrapper->permissionRequested(req);
            }
            else
            {
                delete req; // denies it
            }
        }, Qt::QueuedConnection);
        return true;
    }

    return false;
}

void CefPermissionHandlerImpl::OnDismissPermissionPrompt(CefRefPtr<CefBrowser> browser,
                                                         uint64_t prompt_id,
                                                         cef_permission_request_result_t result)
{
    Q_UNUSED(browser);
    Q_UNUSED(result);
    invalidateOnQtThread(prompt_id);
}

void CefPermissionHandlerImpl::trackOnQtThread(uint64_t promptId, QPointer<CefPermissionRequest> request)
{
    const auto state = m_pendingPromptState;
    QMetaObject::invokeMethod(
        QCoreApplication::instance(),
        [state, promptId, request]() { state->prompts.insert(promptId, request); },
        Qt::QueuedConnection);
}

void CefPermissionHandlerImpl::invalidateOnQtThread(uint64_t promptId)
{
    const auto state = m_pendingPromptState;
    QMetaObject::invokeMethod(
        QCoreApplication::instance(),
        [state, promptId]() {
            auto it = state->prompts.find(promptId);
            if (it == state->prompts.end())
                return;
            if (it.value())
                it.value()->invalidate();
            state->prompts.erase(it);
        },
        Qt::QueuedConnection);
}

void CefPermissionHandlerImpl::setWrapper(CefBrowserWrapper *wrapper)
{
    m_wrapper = wrapper;
}
