#include "BrowserController.h"
#include "BrowserSettings.h"
#include "BrowserTab.h"
#include "InternalPageManager.h"
#include "CefManager.h"
#include "../utils/BrowserLogger.h"
#include "../utils/UrlResolver.h"

#include <QGuiApplication>
#include <QClipboard>
#include <QColor>
#include <QSettings>
#include <QDir>
#include <QFile>
#include <QJSEngine>
#include <QMetaObject>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QVector>
#include <QStringList>
#include <QTimer>
#include <QUuid>
#include <algorithm>

#include <utility>

#include <include/cef_command_ids.h>


void BrowserController::newTab(const QString &urlStr, bool background)
{
    if (urlStr.isEmpty() && !background)
    {
        for (int i = 0; i < m_model->rowCount(); ++i)
        {
            BrowserTab *existing = m_model->tabAt(i);
            if (existing && existing->url() == QUrl(NEW_TAB_URL)
                && !m_sidebar->isInFolder(existing) && !m_sidebar->isSplitTab(existing->id()))
            {
                m_model->setActiveIndex(i);
                emit newTabOpened();
                return;
            }
        }
    }

    if (m_model->rowCount() >= TabModel::kMaxTabs)
        return;

    const BrowserSettings *prefs = BrowserSettings::instance();
    const QUrl url = urlStr.isEmpty()
                         ? QUrl(NEW_TAB_URL)
                         : UrlResolver::resolve(urlStr, prefs ? prefs->searchUrlTemplate() : QString());

    // a background tab loads when first shown, like a restored one
    BrowserTab *tab = m_model->addTab(url, /*suspended=*/background);
    if (!tab)
        return;
    if (background)
    {
        tab->setTitle(url.host().isEmpty() ? url.toString() : url.host());
        return;
    }
    m_model->setActiveIndex(m_model->rowCount() - 1);
    if (urlStr.isEmpty())
        emit newTabOpened();
}

void BrowserController::closeTab(int index)
{
    if (m_closeInProgress)
        return;

    BrowserTab *tab = m_model->tabAt(index);
    if (!tab)
        return;

    // a live page gets to run its "Leave site?" check first; it reports back
    // through onTabCloseApproved(), or not at all if the person stays
    if (tab->requestClose())
        return;
    finishCloseTab(index);
}

void BrowserController::onTabCloseApproved(const QString &tabId)
{
    BrowserTab *tab = tabForId(tabId);
    if (!tab)
        return;

    // closing the window or quitting: keep the tab (it's saved with the
    // session) and move on to the next page
    if (m_pageCheck.active)
    {
        if (!m_pageCheck.closed.contains(tabId))
            m_pageCheck.closed.append(tabId);
        if (tabId == m_pageCheck.current)
        {
            m_pageCheck.current.clear();
            m_pageCheckTimer->stop();
            askNextPage();
        }
        return;
    }

    // its page is already gone: never drop this, or the tab is left empty
    if (m_closeInProgress)
    {
        QMetaObject::invokeMethod(this, [this, tabId]() { onTabCloseApproved(tabId); }, Qt::QueuedConnection);
        return;
    }
    finishCloseTab(m_model->indexOf(tab));
}

void BrowserController::onTabCloseCancelled(const QString &tabId)
{
    if (m_pageCheck.active && tabId == m_pageCheck.current)
        endPageCheck(false);
}

void BrowserController::onTabBeforeUnloadShown(const QString &tabId)
{
    if (m_pageCheck.active && tabId == m_pageCheck.current && m_pageCheckTimer)
        m_pageCheckTimer->stop();
}

void BrowserController::closeAllPages()
{
    if (m_pageCheck.active)
        return;
    if (!m_pageCheckTimer)
    {
        m_pageCheckTimer = new QTimer(this);
        m_pageCheckTimer->setSingleShot(true);
        m_pageCheckTimer->setInterval(kPageCheckTimeoutMs);
        connect(m_pageCheckTimer, &QTimer::timeout, this, [this]() {
            // a hung page: it's force-closed at shutdown anyway
            m_pageCheck.current.clear();
            askNextPage();
        });
    }

    m_pageCheck = {};
    m_pageCheck.active = true;
    // the active tab first: it's the one in front of the person
    if (BrowserTab *active = m_model->tabAt(m_model->activeIndex()))
        m_pageCheck.queue.append(active->id());
    for (int i = 0; i < m_model->rowCount(); ++i)
        if (BrowserTab *tab = m_model->tabAt(i); tab && !m_pageCheck.queue.contains(tab->id()))
            m_pageCheck.queue.append(tab->id());
    askNextPage();
}

void BrowserController::askNextPage()
{
    while (m_pageCheck.active && !m_pageCheck.queue.isEmpty())
    {
        const QString id = m_pageCheck.queue.takeFirst();
        BrowserTab *tab = tabForId(id);
        if (!tab || !tab->requestClose())
            continue; // no live page to ask
        m_pageCheck.current = id;
        m_pageCheckTimer->start();
        return;
    }
    if (m_pageCheck.active)
        endPageCheck(true);
}

void BrowserController::endPageCheck(bool allClosed)
{
    const QStringList closed = m_pageCheck.closed;
    m_pageCheck = {};
    if (m_pageCheckTimer)
        m_pageCheckTimer->stop();

    if (allClosed)
    {
        emit allPagesClosed();
        return;
    }
    // the person kept a page open: the window stays, so do the others
    for (const QString &id : closed)
        if (BrowserTab *tab = tabForId(id))
            tab->recreatePage();
    emit closeAllPagesCancelled();
}

void BrowserController::finishCloseTab(int index)
{
    BrowserTab *tab = m_model->tabAt(index);
    if (!tab)
        return;

    const bool isActive = index == m_model->activeIndex();
    const int next = isActive ? m_model->nearestLiveIndex(index) : index;
    const bool lastPage = isActive && next < 0 && tab->url() == QUrl(NEW_TAB_URL);
    if (m_model->rowCount() <= 1 || lastPage)
    {
        m_closeInProgress = true;
        if (tab->url() != QUrl(NEW_TAB_URL))
        {
            rememberClosedTab(tab);
            tab->setUrl(QUrl(NEW_TAB_URL));
            tab->requestLoad(QUrl(NEW_TAB_URL));
        }

        if (isActive)
            emit newTabOpened();
        QMetaObject::invokeMethod(this, [this]() { m_closeInProgress = false; }, Qt::QueuedConnection);
        return;
    }

    m_closeInProgress = true;
    if (isActive && next >= 0)
        m_model->setActiveIndex(next);
    else if (isActive)
        newTab();
    m_model->removeTab(m_model->indexOf(tab));
    QMetaObject::invokeMethod(this, [this]() { m_closeInProgress = false; }, Qt::QueuedConnection);
}

void BrowserController::rememberClosedTab(const BrowserTab *tab)
{
    if (!tab || !tab->url().isValid() || tab->url().isEmpty()
        || tab->url() == QUrl(NEW_TAB_URL))
        return;

    const QString spaceId = m_space ? m_space->id() : QString();
    QList<ClosedTab> &closedTabs = m_closedTabsBySpace[spaceId];
    closedTabs.append({tab->url()});
    constexpr qsizetype maxRecentlyClosedTabs = 25;
    while (closedTabs.size() > maxRecentlyClosedTabs)
        closedTabs.removeFirst();
}

void BrowserController::reopenLastClosedTab()
{
    if (m_model->rowCount() >= TabModel::kMaxTabs)
        return;

    const QString spaceId = m_space ? m_space->id() : QString();
    auto it = m_closedTabsBySpace.find(spaceId);
    if (it == m_closedTabsBySpace.end() || it->isEmpty())
        return;

    const ClosedTab closedTab = it->takeLast();
    if (it->isEmpty())
        m_closedTabsBySpace.erase(it);

    if (m_model->rowCount() == 1) {
        BrowserTab *currentTab = m_model->tabAt(0);
        if (currentTab && currentTab->url() == QUrl(NEW_TAB_URL)) {
            currentTab->setUrl(closedTab.url);
            currentTab->requestLoad(closedTab.url);
            return;
        }
    }

    newTab(closedTab.url.toString());
}

void BrowserController::executeChromeCommand(const QString &command)
{
    int commandId = 0;
    if (command == QStringLiteral("find"))
        commandId = IDC_FIND;
    else if (command == QStringLiteral("findNext"))
        commandId = IDC_FIND_NEXT;
    else if (command == QStringLiteral("findPrevious"))
        commandId = IDC_FIND_PREVIOUS;
    else if (command == QStringLiteral("cut"))
        commandId = IDC_CUT;
    else if (command == QStringLiteral("copy"))
        commandId = IDC_COPY;
    else if (command == QStringLiteral("paste"))
        commandId = IDC_PASTE;
    else if (command == QStringLiteral("pastePlainText"))
        commandId = IDC_CONTENT_CONTEXT_PASTE_AND_MATCH_STYLE;
    else if (command == QStringLiteral("selectAll"))
        commandId = IDC_CONTENT_CONTEXT_SELECTALL;
    else if (command == QStringLiteral("undo"))
        commandId = IDC_CONTENT_CONTEXT_UNDO;
    else if (command == QStringLiteral("redo"))
        commandId = IDC_CONTENT_CONTEXT_REDO;
    else
        return;

    if (BrowserTab *tab = m_model->tabAt(m_model->activeIndex()))
        tab->executeChromeCommand(commandId);
}

void BrowserController::activateTab(int index)
{
    if (index < 0 || index >= m_model->rowCount())
        return;
    // setActiveIndex also wakes an already-selected tab that is still
    // suspended (for example, a restored folder tab at index zero).
    m_model->setActiveIndex(index);
}

void BrowserController::activateTabAt(int position)
{
    const QList<int> order = m_sidebar->visualTabOrder();
    if (order.isEmpty())
        return;
    if (position < 0 || position >= order.size())
        position = order.size() - 1;
    activateTab(order.at(position));
}

void BrowserController::cycleTab(int delta)
{
    const QList<int> order = m_sidebar->visualTabOrder();
    const int count = order.size();
    if (delta == NO_TAB_CYCLE_DELTA || count == 0)
        return;

    const int current = order.indexOf(m_model->activeIndex());
    if (current >= 0 && count < MIN_TABS_FOR_CYCLE)
        return;
    int position = current < 0 ? (delta > 0 ? delta - 1 : count + delta) : current + delta;
    position %= count;
    if (position < 0)
        position += count;
    activateTab(order.at(position));
}

// navigation

void BrowserController::navigate(const QString &input)
{
    const BrowserSettings *prefs = BrowserSettings::instance();
    const QUrl url = UrlResolver::resolve(input, prefs ? prefs->searchUrlTemplate() : QString());
    if (url.isEmpty())
        return;
    const int idx = m_model->activeIndex();
    if (BrowserTab *tab = m_model->tabAt(idx))
    {
        // update URL imediatly before page is loaded
        tab->setUrl(url);
        tab->requestLoad(url);
        emit loadRequested(tab->id(), url);
        if (url == QUrl(NEW_TAB_URL))
            emit newTabOpened();
    }
}

void BrowserController::reload()
{
    if (BrowserTab *tab = m_model->tabAt(m_model->activeIndex()))
        emit navigationRequested(tab->id(), QStringLiteral("reload"));
}
void BrowserController::goBack()
{
    if (BrowserTab *tab = m_model->tabAt(m_model->activeIndex()))
        emit navigationRequested(tab->id(), QStringLiteral("back"));
}
void BrowserController::goForward()
{
    if (BrowserTab *tab = m_model->tabAt(m_model->activeIndex()))
        emit navigationRequested(tab->id(), QStringLiteral("forward"));
}

void BrowserController::toggleDevTools()
{
    if (BrowserTab *tab = m_model->tabAt(m_model->activeIndex()))
        emit navigationRequested(tab->id(), QStringLiteral("devtools"));
}

// qml to cpp
// rust later?

void BrowserController::onTitleChanged(int i, const QString &v)
{
    if (auto *t = m_model->tabAt(i))
    {
        t->setTitle(v);
    }
}

void BrowserController::onUrlChanged(int i, const QString &v)
{
    if (auto *t = m_model->tabAt(i))
    {
        t->setUrl(QUrl(v));
    }
}

void BrowserController::onLoadingChanged(int i, bool v)
{
    if (auto *t = m_model->tabAt(i))
        t->setLoading(v);
}

void BrowserController::onLoadProgressChanged(int i, int v)
{
    if (auto *t = m_model->tabAt(i))
        t->setProgress(v);
}

void BrowserController::onIconUrlChanged(int i, const QString &v)
{
    if (auto *t = m_model->tabAt(i))
        t->setIconUrl(v);
}

void BrowserController::onRenderProcessPidChanged(int i, qint64 v)
{
    if (auto *t = m_model->tabAt(i))
        t->setRenderProcessPid(v);
}

void BrowserController::onNewWindowRequested(int i, const QString &url)
{
    Q_UNUSED(i);
        newTab(url);
    }

void BrowserController::updateTabTitle(const QString &tabId, const QString &title)
{
    BrowserTab *tab = tabForId(tabId);
    if (!tab)
        return;
    // a background page retitling itself after it settled ("(2) Inbox") has
    // something new; a dot on its tab says so until it's looked at
    const bool background = tab != m_model->tabAt(m_model->activeIndex());
    if (background && tab->settled() && !tab->title().isEmpty() && title != tab->title()
        && !InternalPageManager::isInternal(tab->url().toString()))
        tab->setHasActivity(true);
    tab->setTitle(title);
}

void BrowserController::updateTabAudible(const QString &tabId, bool audible)
{
    if (BrowserTab *tab = tabForId(tabId))
        tab->setAudible(audible);
}

void BrowserController::toggleTabMuted(const QString &tabId)
{
    if (BrowserTab *tab = tabForId(tabId))
        tab->setMuted(!tab->muted());
}

void BrowserController::updateTabUrl(const QString &tabId, const QString &url)
{
    BrowserTab *tab = tabForId(tabId);
    if (!tab)
        return;
    tab->setUrl(QUrl(url));
    if (tab == m_model->tabAt(m_model->activeIndex()) && tab->url() == QUrl(NEW_TAB_URL))
        emit newTabOpened();
}

void BrowserController::updateTabLoading(const QString &tabId, bool loading)
{
    if (BrowserTab *tab = tabForId(tabId))
        tab->setLoading(loading);
}

void BrowserController::updateTabProgress(const QString &tabId, int progress)
{
    if (BrowserTab *tab = tabForId(tabId))
        tab->setProgress(progress);
}

void BrowserController::updateTabIcon(const QString &tabId, const QString &iconUrl)
{
    if (BrowserTab *tab = tabForId(tabId))
        tab->setIconUrl(iconUrl);
}

void BrowserController::updateTabRenderProcessPid(const QString &tabId, qint64 pid)
{
    if (BrowserTab *tab = tabForId(tabId))
        tab->setRenderProcessPid(pid);
}

void BrowserController::openTabFrom(const QString &sourceTabId, const QString &url, bool background)
{
    // nothing to open: never fall back to an empty new tab (that's the command bar)
    if (url.trimmed().isEmpty() || !tabForId(sourceTabId))
        return;
    newTab(url, background);
}

void BrowserController::loadInTab(const QString &tabId, const QString &url)
{
    BrowserTab *tab = tabForId(tabId);
    const BrowserSettings *prefs = BrowserSettings::instance();
    const QUrl resolved = UrlResolver::resolve(url, prefs ? prefs->searchUrlTemplate() : QString());
    if (!tab || resolved.isEmpty())
        return;
    tab->setUrl(resolved);
    tab->requestLoad(resolved);
    emit loadRequested(tab->id(), resolved);
}


// top-level windows

void BrowserController::adoptWindow(QObject *window)
{
    if (!window)
        return;
    m_adoptedWindows.removeIf([](const QPointer<QObject> &w) { return w.isNull(); });
    if (m_adoptedWindows.contains(window))
        return;
    QJSEngine::setObjectOwnership(window, QJSEngine::CppOwnership);
    m_adoptedWindows.append(window);
}

void BrowserController::releaseWindow(QObject *window)
{
    if (!window)
        return;
    const bool adopted = m_adoptedWindows.contains(window);
    if (adopted)
        m_adoptedWindows.removeIf([window](const QPointer<QObject> &candidate) {
            return candidate.isNull() || candidate.data() == window;
        });
    if (adopted || QJSEngine::objectOwnership(window) == QJSEngine::JavaScriptOwnership)
        window->deleteLater();
}

void BrowserController::destroyAdoptedWindows()
{
    const QList<QPointer<QObject>> windows = std::exchange(m_adoptedWindows, {});
    for (const QPointer<QObject> &window : windows)
        delete window.data();
}

const QString BrowserController::NEW_TAB_URL = "newtab://newtab";
const QString BrowserController::SETUP_URL = "illuminate://setup";
