#include "browser/CefBrowserWrapperPrivate.h"
#include "../BeforeUnloadRequest.h"

using namespace CefBrowserWrapperPrivate;

void CefBrowserWrapper::goBack()
{
    if (m_browser && m_browser->CanGoBack())
        m_browser->GoBack();
}

void CefBrowserWrapper::goForward()
{
    if (m_browser && m_browser->CanGoForward())
        m_browser->GoForward();
}

void CefBrowserWrapper::reload()
{
    if (m_browser)
        m_browser->Reload();
}

void CefBrowserWrapper::stop()
{
    if (m_browser)
        m_browser->StopLoad();
}
void CefBrowserWrapper::executeChromeCommand(int commandId)
{
    if (auto host = hostOf(m_browser))
        host->ExecuteChromeCommand(commandId, CEF_WOD_CURRENT_TAB);
}

void CefBrowserWrapper::triggerWebAction(int action, const QUrl &url)
{
    auto frame = mainFrameOf(m_browser);
    if (!frame)
        return;

    switch (action)
    {
    case Cut:
        frame->Cut();
        break;
    case Copy:
        frame->Copy();
        break;
    case Paste:
        frame->Paste();
        break;
    case PasteAndMatchStyle:
        frame->PasteAndMatchStyle();
        break;
    case SelectAll:
        frame->SelectAll();
        break;
    case Undo:
        frame->Undo();
        break;
    case Redo:
        frame->Redo();
        break;
    case CopyLinkToClipboard:
        if (url.isValid() && !url.isEmpty())
            QGuiApplication::clipboard()->setText(url.toString());
        break;
    case DownloadImageToDisk:
    case DownloadMediaToDisk:
    case DownloadLinkToDisk:
        if (url.isValid() && !url.isEmpty())
        {
            if (auto host = hostOf(m_browser))
                host->StartDownload(qUrlToCefString(url));
        }
        break;
    default:
        break;
    }
}

void CefBrowserWrapper::runJavaScript(const QString &script, int worldId)
{
    auto frame = mainFrameOf(m_browser);
    if (!frame)
        return;

    if (worldId != 0)
    {
        qWarning() << "[CEF] runJavaScript: worldId" << worldId
                   << "is not yet supported; falling back to main world (0).";
    }

    frame->ExecuteJavaScript(qStringToCef(script), frame->GetURL(), 0);
}

bool CefBrowserWrapper::requestClose()
{
    auto host = hostOf(m_browser);
    if (!host || !m_hostWindow)
        return false;
    host->CloseBrowser(false);
    return true;
}

void CefBrowserWrapper::onBeforeUnloadRequested(BeforeUnloadRequest *request)
{
    // a newer question replaces an unanswered one (which then counts as "stay")
    if (m_beforeUnload)
        m_beforeUnload->deleteLater();
    request->setParent(this);
    m_beforeUnload = request;
    connect(request, &BeforeUnloadRequest::answeredWith, this, [this](bool leave) {
        if (!leave)
            emit closeCancelled();
    });
    connect(request, &BeforeUnloadRequest::finished, request, &QObject::deleteLater);
    emit beforeUnloadRequested(request);
}

void CefBrowserWrapper::dismissBeforeUnload()
{
    if (m_beforeUnload)
        m_beforeUnload->dismiss();
}

void CefBrowserWrapper::recreateBrowser()
{
    if (m_browser)
    {
        // still closing: OnBeforeClose comes through setBrowser(nullptr)
        m_recreateWhenClosed = true;
        return;
    }
    if (m_creatingBrowser)
        return;
    if (m_hostWindow)
    {
        cefDetachChildWindow(m_hostWindow->nativeHandle());
        m_hostWindow->close();
        m_hostWindow = nullptr;
        m_hostWindowReady = false;
    }
    m_nativeRect = QRect();
    m_nativeVisible = false;
    initializeBrowserHost();
}

void CefBrowserWrapper::onBrowserClosed()
{
    const bool recreating = m_recreateWhenClosed;
    setBrowser(nullptr);
    if (!recreating && !CefManager::isShuttingDown())
        emit closeApproved();
}

void CefBrowserWrapper::onFrameAudible(const QString &frameId, bool audible)
{
    m_audible.report(frameId, audible);
}

void CefBrowserWrapper::clearAudible()
{
    m_audible.clear();
}

void CefBrowserWrapper::setAudioMuted(bool muted)
{
    if (m_audioMuted == muted)
        return;
    m_audioMuted = muted;
    if (auto host = hostOf(m_browser))
        host->SetAudioMuted(muted);
    emit audioMutedChanged();
}
