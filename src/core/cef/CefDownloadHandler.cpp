#include "CefDownloadHandler.h"
#include "../models/DownloadModel.h"
#include "../utils/BrowserLogger.h"
#include "../utils/cef_helpers.h"

#include <include/cef_request_context.h>
#include <include/cef_values.h>

#include <QCoreApplication>
#include <QHash>
#include <QMutex>
#include <QPair>
#include <QMetaObject>
#include <QStandardPaths>

#include <algorithm>
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

// Every space has its own request context, and each one numbers its downloads
// from 1. The sidebar lists them all together, so give each its own id.
quint32 appDownloadId(CefRefPtr<CefBrowser> browser, uint32_t chromiumId)
{
    static QMutex mutex;
    static QHash<QPair<QString, quint32>, quint32> ids;
    static quint32 next = 0;

    CefRefPtr<CefRequestContext> context = browser && browser->GetHost()
        ? browser->GetHost()->GetRequestContext() : nullptr;
    QMutexLocker lock(&mutex);
    if (!context)
    {
        // its page is gone: the newest download Chromium numbered this way
        quint32 found = 0;
        for (auto it = ids.cbegin(); it != ids.cend(); ++it)
            if (it.key().second == chromiumId)
                found = std::max(found, it.value());
        if (found)
            return found;
    }
    const QPair<QString, quint32> key(context ? cefStringToQString(context->GetCachePath()) : QString(),
                                      chromiumId);
    auto it = ids.constFind(key);
    if (it != ids.cend())
        return it.value();
    const quint32 id = ++next;
    ids.insert(key, id);
    return id;
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
    if (!download_item || !download_item->IsValid())
        return;

    DownloadModel::Update update;
    update.id = appDownloadId(browser, download_item->GetId());
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
