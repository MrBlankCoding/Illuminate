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
#include <QSaveFile>
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


QString BrowserController::sessionFilePath() const
{
    return m_space ? m_space->sessionFilePath() : QString();
}

QString BrowserController::sidebarFilePath() const
{
    return m_space ? m_space->sidebarFilePath() : QString();
}

bool BrowserController::confirmCloseRequired() const
{
    const BrowserSettings *prefs = BrowserSettings::instance();
    if (prefs && !prefs->confirmCloseMultipleTabs())
        return false;
    // one tab is still worth closing without a prompt; a pile of them is not
    return m_model->rowCount() > 1;
}

void BrowserController::saveSession() const
{
    const QString path = sessionFilePath();
    if (path.isEmpty())
        return;

    QJsonArray tabsArray;
    int savedActiveIndex = 0;
    BrowserTab *activeTab = m_model->tabAt(m_model->activeIndex());
    const QUrl activeUrl = activeTab ? activeTab->url() : QUrl();
    const QString activeTitle = activeTab ? activeTab->title() : QString();
    for (int i = 0; i < m_model->rowCount(); ++i)
    {
        BrowserTab *tab = m_model->tabAt(i);
        const QUrl url = tab ? tab->url() : QUrl();
        // tabs in folders come back from sidebar.json
        if (!tab || !url.isValid() || url.isEmpty() || url == QUrl(NEW_TAB_URL) || m_sidebar->isInFolder(tab))
            continue;

        QJsonObject obj;
        obj[QStringLiteral("url")] = url.toString();
        obj[QStringLiteral("title")] = tab->title();
        tabsArray.append(obj);

        if (i == m_model->activeIndex())
            savedActiveIndex = tabsArray.size() - 1;
    }

    m_sidebar->saveNow();

    QJsonObject root;
    root[QStringLiteral("activeIndex")] = savedActiveIndex;
    root[QStringLiteral("tabs")] = tabsArray;
    if (activeUrl.isValid() && !activeUrl.isEmpty())
        root[QStringLiteral("activeUrl")] = activeUrl.toString();
    if (!activeTitle.isEmpty())
        root[QStringLiteral("activeTitle")] = activeTitle;

    QSaveFile file(path);
    if (!file.open(QFile::WriteOnly | QFile::Text))
    {
        qWarning() << "Could not open session.json for writing:" << file.errorString();
        return;
    }
    if (file.write(QJsonDocument(root).toJson()) < 0 || !file.commit())
        qWarning() << "Could not save session.json:" << file.errorString();
}

void BrowserController::restoreSession()
{
    if (m_sessionRestoredForSpace)
        return;
    m_sessionRestoredForSpace = true;

    const BrowserSettings *prefs = BrowserSettings::instance();
    const bool restoreTabs = !prefs || prefs->restoreTabsOnStartup();

    const QString path = sessionFilePath();
    QFile file(path);
    if (!restoreTabs || path.isEmpty() || !file.open(QFile::ReadOnly | QFile::Text))
    {
        openInitialTab();
        return;
    }

    const QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    file.close();

    const QJsonArray tabsArray = doc.isObject() ? doc.object()[QStringLiteral("tabs")].toArray() : QJsonArray();
    const int base = m_model->rowCount();
    QVector<int> restoredSessionIndexes;
    for (const QJsonValue &value : tabsArray)
    {
        if (!value.isObject())
            continue;
        const QJsonObject obj = value.toObject();
        const QString urlText = obj[QStringLiteral("url")].toString();
        const QUrl url(urlText);
        if (urlText.isEmpty() || !url.isValid() || m_model->rowCount() >= TabModel::kMaxTabs)
            continue;

        // Older builds could write split members to both persistence files.
        // The sidebar copy is authoritative because it retains the grouping.
        bool alreadyInSidebar = false;
        for (int i = 0; i < base; ++i)
        {
            BrowserTab *sidebarTab = m_model->tabAt(i);
            if (sidebarTab && m_sidebar->isInFolder(sidebarTab) && sidebarTab->url() == url &&
                sidebarTab->title() == obj[QStringLiteral("title")].toString())
            {
                alreadyInSidebar = true;
                break;
            }
        }
        if (alreadyInSidebar)
            continue;

        if (BrowserTab *tab = m_model->addTab(url, /*suspended=*/true))
        {
            tab->setTitle(obj[QStringLiteral("title")].toString());
            restoredSessionIndexes.append(m_model->rowCount() - 1);
        }
    }

    if (m_model->rowCount() == 0)
    {
        openInitialTab();
        return;
    }

    const QJsonObject session = doc.object();
    const QUrl savedActiveUrl(session.value(QStringLiteral("activeUrl")).toString());
    const QString savedActiveTitle = session.value(QStringLiteral("activeTitle")).toString();
    int activeIndex = -1;
    if (savedActiveUrl.isValid() && !savedActiveUrl.isEmpty())
    {
        if (!savedActiveTitle.isEmpty())
        {
            for (int i = 0; i < m_model->rowCount(); ++i)
            {
                BrowserTab *tab = m_model->tabAt(i);
                if (tab && tab->url() == savedActiveUrl && tab->title() == savedActiveTitle)
                {
                    activeIndex = i;
                    break;
                }
            }
        }
        if (activeIndex < 0)
            for (int i = 0; i < m_model->rowCount(); ++i)
                if (BrowserTab *tab = m_model->tabAt(i); tab && tab->url() == savedActiveUrl)
                {
                    activeIndex = i;
                    break;
                }
    }
    if (activeIndex < 0 && !restoredSessionIndexes.isEmpty())
    {
        const int savedIndex = session.value(QStringLiteral("activeIndex")).toInt(0);
        activeIndex = restoredSessionIndexes.at(
            std::clamp(savedIndex, 0, static_cast<int>(restoredSessionIndexes.size()) - 1));
    }
    if (activeIndex < 0)
        activeIndex = 0;
    m_model->setActiveIndex(activeIndex);
}

void BrowserController::openInitialTab()
{
    if (m_isFirstRun)
    {
        newTab(SETUP_URL);
        return;
    }

    const BrowserSettings *prefs = BrowserSettings::instance();
    if (prefs && prefs->startupBehavior() == QLatin1String(BrowserSettings::kStartupHomepage) && !prefs->homepageUrl().isEmpty())
    {
        newTab(prefs->homepageUrl());
        return;
    }

    newTab();
}

bool BrowserController::isFirstRun() const
{
    return m_isFirstRun;
}

void BrowserController::completeFirstRun()
{
    if (!m_appSettings)
        return;
    m_appSettings->setValue("setup/completed", true);
    if (m_isFirstRun)
    {
        m_isFirstRun = false;
        emit firstRunChanged();
        // hand the user a normal new tab once setup is accepted
        if (BrowserTab *tab = m_model->tabAt(m_model->activeIndex()))
        {
            if (tab->url() == QUrl(SETUP_URL))
            {
                tab->setUrl(QUrl(NEW_TAB_URL));
                tab->requestLoad(QUrl(NEW_TAB_URL));
                emit activeUrlChanged();
                emit newTabOpened();
            }
        }
    }
}

// tab managment
