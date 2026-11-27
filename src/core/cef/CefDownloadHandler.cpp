#include "CefDownloadHandler.h"
#include "../models/DownloadModel.h"
#include "../utils/BrowserLogger.h"
#include "../utils/cef_helpers.h"

#include <include/cef_request_context.h>
#include <include/cef_values.h>

#include <QCoreApplication>
#include <QMetaObject>
#include <QStandardPaths>

#include <utility>

CefDownloadHandlerImpl::CefDownloadHandlerImpl() = default;

bool CefDownloadHandlerImpl::CanDownload(CefRefPtr<CefBrowser> browser,
                                         const CefString &url,
                                         const CefString &request_method)
{
    Q_UNUSED(browser);
    Q_UNUSED(url);
    Q_UNUSED(request_method);
    return true;
}

namespace
{
// Chrome style pops its download bubble open for every new download. The
// sidebar shows downloads instead, so turn that off before this download's
// target is settled (Chrome checks it once the target is known).
void hideChromeDownloadBubble(CefRefPtr<CefBrowser> browser)
{
    static bool warned = false;
    CefRefPtr<CefRequestContext> context = browser && browser->GetHost()
        ? browser->GetHost()->GetRequestContext() : nullptr;
    const CefString name("download_bubble.partial_view_enabled");
    if (!context || !context->HasPreference(name) || !context->CanSetPreference(name))
    {
        if (!std::exchange(warned, true))
            BrowserLogger::instance().warning("Downloads", "Chromium's download bubble preference is unavailable");
        return;
    }
    CefRefPtr<CefValue> current = context->GetPreference(name);
    if (current && current->GetType() == VTYPE_BOOL && !current->GetBool())
        return;
    CefRefPtr<CefValue> off = CefValue::Create();
    off->SetBool(false);
    CefString error;
    if (!context->SetPreference(name, off, error))
        BrowserLogger::instance().warning("Downloads",
            "Could not turn off Chromium's download bubble: " + cefStringToQString(error));
}
}

bool CefDownloadHandlerImpl::OnBeforeDownload(CefRefPtr<CefBrowser> browser,
                                              CefRefPtr<CefDownloadItem> download_item,
                                              const CefString &suggested_name,
                                              CefRefPtr<CefBeforeDownloadCallback> callback)
{
    Q_UNUSED(download_item);
    hideChromeDownloadBubble(browser);

    // never over an existing file: "report.pdf" becomes "report (1).pdf"
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::DownloadLocation);
    const QString path = DownloadModel::instance().reservePath(dir, cefStringToQString(suggested_name));
    callback->Continue(qStringToCef(path), false);
    return true;
}

void CefDownloadHandlerImpl::OnDownloadUpdated(CefRefPtr<CefBrowser> browser,
                                               CefRefPtr<CefDownloadItem> download_item,
                                               CefRefPtr<CefDownloadItemCallback> callback)
{
    Q_UNUSED(browser);
    if (!download_item || !download_item->IsValid())
        return;

    DownloadModel::Update update;
    update.id = download_item->GetId();
    update.fullPath = cefStringToQString(download_item->GetFullPath());
    update.suggestedName = cefStringToQString(download_item->GetSuggestedFileName());
    update.receivedBytes = download_item->GetReceivedBytes();
    const int64_t total = download_item->GetTotalBytes();
    update.totalBytes = total > 0 ? total : -1;
    update.bytesPerSecond = download_item->GetCurrentSpeed();
    update.complete = download_item->IsComplete();
    update.cancelled = download_item->IsCanceled();
    update.interrupted = download_item->IsInterrupted();

    std::function<void()> cancel;
    if (callback)
        cancel = [callback]() { callback->Cancel(); };

    QMetaObject::invokeMethod(QCoreApplication::instance(), [update, cancel]() {
        DownloadModel::instance().applyUpdate(update, cancel);
    }, Qt::QueuedConnection);
}
