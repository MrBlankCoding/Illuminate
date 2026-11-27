#include "BrowserTab.h"
#include "InternalPageManager.h"

#include "CefBrowserWrapper.h"

#include <QDateTime>
#include <QUuid>

BrowserTab::BrowserTab(QObject *parent)
    : QObject(parent), m_id(QUuid::createUuid().toString(QUuid::WithoutBraces))
{
}

QString BrowserTab::id() const { return m_id; }

QUrl BrowserTab::url() const { return m_url; }
QString BrowserTab::title() const { return m_title; }
QString BrowserTab::iconUrl() const { return m_iconUrl; }
int BrowserTab::progress() const { return m_progress; }
bool BrowserTab::loading() const { return m_loading; }
qint64 BrowserTab::renderProcessPid() const { return m_renderProcessPid; }
bool BrowserTab::suspended() const { return m_suspended; }

void BrowserTab::setUrl(const QUrl &url)
{
    if (m_url == url)
        return;
    m_url = url;
    emit urlChanged(url);
}

void BrowserTab::setTitle(const QString &title)
{
    if (m_title == title)
        return;
    m_title = title;
    emit titleChanged(title);
}

void BrowserTab::setIconUrl(const QString &iconUrl)
{
    const QString sanitized = iconUrl.startsWith(QLatin1String("chrome:"), Qt::CaseInsensitive)
        ? InternalPageManager::iconUrl(m_url.toString())
        : iconUrl;
    if (m_iconUrl == sanitized)
        return;
    m_iconUrl = sanitized;
    emit iconUrlChanged(sanitized);
}

void BrowserTab::setProgress(int progress)
{
    if (m_progress == progress)
        return;
    m_progress = progress;
    emit progressChanged(progress);
}

void BrowserTab::setLoading(bool loading)
{
    if (m_loading == loading)
        return;
    m_loading = loading;
    m_loadedAt = loading ? 0 : QDateTime::currentMSecsSinceEpoch();
    emit loadingChanged(loading);
}

void BrowserTab::setRenderProcessPid(qint64 pid)
{
    if (m_renderProcessPid == pid)
        return;
    m_renderProcessPid = pid;
    emit renderProcessPidChanged(pid);
}

void BrowserTab::setSuspended(bool suspended)
{
    if (m_suspended == suspended)
        return;
    m_suspended = suspended;
    emit suspendedChanged(suspended);
}

void BrowserTab::setAudible(bool audible)
{
    if (m_audible == audible)
        return;
    m_audible = audible;
    emit audibleChanged(audible);
}

void BrowserTab::setMuted(bool muted)
{
    if (m_muted == muted)
        return;
    m_muted = muted;
    emit mutedChanged(muted);
}

void BrowserTab::setHasActivity(bool activity)
{
    if (m_hasActivity == activity)
        return;
    m_hasActivity = activity;
    emit hasActivityChanged(activity);
}

bool BrowserTab::settled() const
{
    return !m_loading && !m_suspended && m_loadedAt > 0
           && QDateTime::currentMSecsSinceEpoch() - m_loadedAt >= kActivityGraceMs;
}

void BrowserTab::requestLoad(const QUrl &url)
{
    emit loadRequested(url);
}

void BrowserTab::cut()
{
    if (m_cefBrowserWrapper)
        m_cefBrowserWrapper->triggerWebAction(CefBrowserWrapper::WebAction::Cut);
}

void BrowserTab::copy()
{
    if (m_cefBrowserWrapper)
        m_cefBrowserWrapper->triggerWebAction(CefBrowserWrapper::WebAction::Copy);
}

void BrowserTab::paste()
{
    if (m_cefBrowserWrapper)
        m_cefBrowserWrapper->triggerWebAction(CefBrowserWrapper::WebAction::Paste);
}

void BrowserTab::pastePlainText()
{
    if (m_cefBrowserWrapper)
        m_cefBrowserWrapper->triggerWebAction(CefBrowserWrapper::WebAction::PasteAndMatchStyle);
}

void BrowserTab::selectAll()
{
    if (m_cefBrowserWrapper)
        m_cefBrowserWrapper->triggerWebAction(CefBrowserWrapper::WebAction::SelectAll);
}

void BrowserTab::undo()
{
    if (m_cefBrowserWrapper)
        m_cefBrowserWrapper->triggerWebAction(CefBrowserWrapper::WebAction::Undo);
}

void BrowserTab::redo()
{
    if (m_cefBrowserWrapper)
        m_cefBrowserWrapper->triggerWebAction(CefBrowserWrapper::WebAction::Redo);
}

void BrowserTab::executeChromeCommand(int commandId)
{
    if (m_cefBrowserWrapper)
        m_cefBrowserWrapper->executeChromeCommand(commandId);
}

void BrowserTab::setCefBrowserWrapper(CefBrowserWrapper *wrapper)
{
    m_cefBrowserWrapper = wrapper;
}

bool BrowserTab::requestClose()
{
    return !m_suspended && m_cefBrowserWrapper && m_cefBrowserWrapper->requestClose();
}

void BrowserTab::recreatePage()
{
    if (m_cefBrowserWrapper)
        m_cefBrowserWrapper->recreateBrowser();
}
