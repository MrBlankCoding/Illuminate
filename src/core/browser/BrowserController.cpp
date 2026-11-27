#include "BrowserController.h"
#include "BrowserSettings.h"
#include "BrowserTab.h"
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
#include <QUuid>
#include <algorithm>

#include <utility>
BrowserController::BrowserController(Space *space, QObject *parent, const QString &settingsFilePath)
    : QObject(parent)
    , m_space(space)
    , m_webProfile(space ? CefProfile::forSpace(space->id(), space->storageDir()) : CefProfile::instance())
    , m_settings(new QSettings(settingsFilePath.isEmpty()
                                   ? QDir::homePath() + QDir::separator() + ".illuminate"
                                         + QDir::separator() + "settings.ini"
                                   : settingsFilePath,
                               QSettings::IniFormat, this))
    , m_model(new TabModel(this))
    , m_sidebar(new SidebarModel(m_model, this))
    , m_appSettings(new QSettings(this))
{
    m_isFirstRun = !m_appSettings->value("setup/completed", false).toBool();

    connect(m_sidebar, &SidebarModel::newTabOpened, this, &BrowserController::newTabOpened);
    connect(m_sidebar, &SidebarModel::newTabRequested, this, [this]() { newTab(); });
    connect(m_sidebar, &SidebarModel::linkCopied, this, &BrowserController::linkCopied);

    connect(m_model, &TabModel::activeIndexChanged, this, [this]()
            {
        emit activeIndexChanged();
        emitActiveStateChanged();
        rewireActiveTab(); });
    connect(m_model, &TabModel::tabAboutToBeRemoved, this,
            [this](BrowserTab *tab) { rememberClosedTab(tab); });

    if (m_space)
    {
        m_sidebar->load(sidebarFilePath(), true);
        restoreSession();
    }
}

void BrowserController::setActiveSpace(Space *space)
{
    if (!space || m_space == space)
        return;

    emit spaceAboutToChange();
    // the outgoing space keeps its tabs in its own session file; the tree is
    // let go before the tabs, so a folder is still around when its tab is
    saveSession();
    m_sidebar->unload();
    // The outgoing space's tabs stay in memory (not just in its session file)
    // so coming back finds the same tabs, titles and order without reading
    // anything back. Their pages go with their views; the one in front may be
    // kept running by WarmSpaces, the rest load when next opened.
    if (m_space)
    {
        ResidentSpaceTabs resident;
        m_model->takeTabs(resident.tabs, resident.activeIndex);
        for (int i = 0; i < resident.tabs.size(); ++i)
        {
            BrowserTab *tab = resident.tabs.at(i);
            tab->setLoading(false);
            tab->setProgress(0);
            tab->setAudible(false);
            tab->setRenderProcessPid(0);
            if (i != resident.activeIndex)
                tab->setSuspended(true);
        }
        if (!resident.tabs.isEmpty())
            m_residentSpaces.insert(m_space->id(), std::move(resident));
    }
    else
        m_model->clear();

    m_space = space;
    m_webProfile = CefProfile::forSpace(space->id(), space->storageDir());
    const auto resident = m_residentSpaces.find(space->id());
    const bool hasResidentTabs = resident != m_residentSpaces.end();
    if (hasResidentTabs)
    {
        m_model->restoreTabs(std::move(resident->tabs), resident->activeIndex);
        m_residentSpaces.erase(resident);
        m_sessionRestoredForSpace = true;
        // the tab in front gets its view (and takes over a waiting page)
        m_model->setActiveIndex(m_model->activeIndex());
    }
    else
        m_sessionRestoredForSpace = false;
    emit spaceChanged();
    emit themeColorChanged();

    m_sidebar->load(sidebarFilePath(), !hasResidentTabs);
    if (!hasResidentTabs)
        restoreSession();

    // a space with nothing in it still needs a tab, but never the setup page
    if (m_model->rowCount() == 0 && !m_isFirstRun)
        openInitialTab();
}

void BrowserController::rewireActiveTab()
{
    // preventing signal accumulation across tab switches.
    delete m_activeTabCtx;
    m_activeTabCtx = nullptr;

    BrowserTab *tab = m_model->tabAt(m_model->activeIndex());
    if (!tab)
        return;
    // whatever it was flagging, it's in front of the person now
    tab->setHasActivity(false);

    m_activeTabCtx = new QObject(this);
    connect(tab, &BrowserTab::urlChanged, m_activeTabCtx, [this]
            { emit activeUrlChanged(); });
    connect(tab, &BrowserTab::titleChanged, m_activeTabCtx, [this]
            { emit activeTitleChanged(); });
    connect(tab, &BrowserTab::iconUrlChanged, m_activeTabCtx, [this]
            { emit activeIconUrlChanged(); });
    connect(tab, &BrowserTab::loadingChanged, m_activeTabCtx, [this]
            { emit activeLoadingChanged(); });
    connect(tab, &BrowserTab::progressChanged, m_activeTabCtx, [this]
            { emit activeProgressChanged(); });
}

BrowserTab *BrowserController::tabForId(const QString &tabId) const
{
    if (tabId.isEmpty())
        return nullptr;
    for (int i = 0; i < m_model->rowCount(); ++i)
    {
        BrowserTab *tab = m_model->tabAt(i);
        if (tab && tab->id() == tabId)
            return tab;
    }
    return nullptr;
}

void BrowserController::emitActiveStateChanged()
{
    emit activeUrlChanged();
    emit activeTitleChanged();
    emit activeIconUrlChanged();
    emit activeLoadingChanged();
    emit activeProgressChanged();
}

// Property getter

TabModel *BrowserController::tabModel() const { return m_model; }
SidebarModel *BrowserController::sidebar() const { return m_sidebar; }
CefProfile *BrowserController::webProfile() const
{
    return m_webProfile ? m_webProfile : CefManager::defaultProfile();
}
bool BrowserController::chromeStyle() const { return CefManager::chromeStyle(); }

void BrowserController::keepResidentSpaces(const QStringList &spaceIds)
{
    for (auto it = m_residentSpaces.begin(); it != m_residentSpaces.end();)
    {
        if (spaceIds.contains(it.key()))
        {
            ++it;
            continue;
        }
        qDeleteAll(it->tabs);
        it = m_residentSpaces.erase(it);
    }
}

CefProfile *BrowserController::profileForSpace(Space *space) const
{
    return space ? CefProfile::forSpace(space->id(), space->storageDir()) : webProfile();
}

int BrowserController::activeIndex() const { return m_model->activeIndex(); }

QString BrowserController::activeUrl() const
{
    if (auto *t = m_model->tabAt(m_model->activeIndex()))
        return t->url().toString();
    return {};
}
void BrowserController::copyActiveUrl()
{
    const QString url = activeUrl();
    if (url.isEmpty() || url == NEW_TAB_URL)
        return;
    QGuiApplication::clipboard()->setText(url);
    emit linkCopied(url);
}

void BrowserController::cut()
{
    if (auto *t = m_model->tabAt(m_model->activeIndex()))
        t->cut();
}

void BrowserController::copy()
{
    if (auto *t = m_model->tabAt(m_model->activeIndex()))
        t->copy();
}

void BrowserController::paste()
{
    if (auto *t = m_model->tabAt(m_model->activeIndex()))
        t->paste();
}

void BrowserController::pastePlainText()
{
    if (auto *t = m_model->tabAt(m_model->activeIndex()))
        t->pastePlainText();
}

void BrowserController::selectAll()
{
    if (auto *t = m_model->tabAt(m_model->activeIndex()))
        t->selectAll();
}

void BrowserController::undo()
{
    if (auto *t = m_model->tabAt(m_model->activeIndex()))
        t->undo();
}

void BrowserController::redo()
{
    if (auto *t = m_model->tabAt(m_model->activeIndex()))
        t->redo();
}
QString BrowserController::activeTitle() const
{
    if (auto *t = m_model->tabAt(m_model->activeIndex()))
        return t->title().isEmpty() ? QStringLiteral("New Tab") : t->title();
    return QStringLiteral("New Tab");
}
QString BrowserController::activeIconUrl() const
{
    if (auto *t = m_model->tabAt(m_model->activeIndex()))
        return t->iconUrl();
    return {};
}
bool BrowserController::activeLoading() const
{
    if (auto *t = m_model->tabAt(m_model->activeIndex()))
        return t->loading();
    return false;
}
int BrowserController::activeProgress() const
{
    if (auto *t = m_model->tabAt(m_model->activeIndex()))
        return t->progress();
    return 0;
}
