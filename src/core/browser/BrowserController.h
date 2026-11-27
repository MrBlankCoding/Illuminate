#pragma once

#include <QList>
#include <QHash>
#include <QObject>
#include <QPointer>
#include <QUrl>
#include <QString>
#include <QStringList>
#include <QVariantMap>
#include <QVector>
#include <QtQml/qqmlregistration.h>
#include "TabModel.h"
#include "SidebarModel.h"

#include "CefProfile.h"
#include "../spaces/Space.h"
#include "../utils/ExternalQmlSingleton.h"

class QSettings;
class QTimer;
class BrowserTab;

class BrowserController : public QObject, public ExternalQmlSingleton<BrowserController>
{
    Q_DISABLE_COPY_MOVE(BrowserController)
    Q_OBJECT
    QML_NAMED_ELEMENT(Browser)
    QML_SINGLETON

    // MOC revice tab model
    Q_PROPERTY(TabModel *tabModel READ tabModel CONSTANT)
    Q_PROPERTY(SidebarModel *sidebar READ sidebar CONSTANT)
    Q_PROPERTY(int activeIndex READ activeIndex NOTIFY activeIndexChanged)
    Q_PROPERTY(QString activeUrl READ activeUrl NOTIFY activeUrlChanged)
    Q_PROPERTY(QString activeTitle READ activeTitle NOTIFY activeTitleChanged)
    Q_PROPERTY(QString activeIconUrl READ activeIconUrl NOTIFY activeIconUrlChanged)
    Q_PROPERTY(bool activeLoading READ activeLoading NOTIFY activeLoadingChanged)
    Q_PROPERTY(int activeProgress READ activeProgress NOTIFY activeProgressChanged)
    Q_PROPERTY(QString themeMode READ themeMode WRITE setThemeMode NOTIFY themeModeChanged)
    // the active space's theme seed; invalid when it uses the default theme
    Q_PROPERTY(QColor themeColor READ themeColor NOTIFY themeColorChanged)
    Q_PROPERTY(bool firstRun READ isFirstRun NOTIFY firstRunChanged)
    Q_PROPERTY(CefProfile *webProfile READ webProfile NOTIFY spaceChanged)
    Q_PROPERTY(Space *space READ space NOTIFY spaceChanged)
    Q_PROPERTY(bool chromeStyle READ chromeStyle CONSTANT)

public:
    explicit BrowserController(Space *space, QObject *parent = nullptr,
                               const QString &settingsFilePath = {});

    void setActiveSpace(Space *space);
    Space *space() const { return m_space; }


    TabModel *tabModel() const;
    SidebarModel *sidebar() const;
    int activeIndex() const;
    QString activeUrl() const;
    QString activeTitle() const;
    QString activeIconUrl() const;
    bool activeLoading() const;
    int activeProgress() const;
    QString themeMode() const;
    void setThemeMode(const QString &mode);
    QColor themeColor() const;
    bool isFirstRun() const;
    CefProfile *webProfile() const;
    // the browser profile (cookies, storage) a space's pages use
    Q_INVOKABLE CefProfile *profileForSpace(Space *space) const;
    // Spaces left this session keep their tabs in memory until revisited;
    // this lets go of those for spaces no longer in |spaceIds| (deleted).
    void keepResidentSpaces(const QStringList &spaceIds);
    bool hasResidentTabs(const QString &spaceId) const { return m_residentSpaces.contains(spaceId); }
    bool chromeStyle() const;


    Q_INVOKABLE void newTab(const QString &url = {}, bool background = false);
    Q_INVOKABLE void completeFirstRun();
    Q_INVOKABLE void closeTab(int index);
    Q_INVOKABLE void closeOtherTabs(int keepIndex);
    Q_INVOKABLE void onTabCloseApproved(const QString &tabId);
    Q_INVOKABLE void onTabCloseCancelled(const QString &tabId);
    Q_INVOKABLE void onTabBeforeUnloadShown(const QString &tabId);
    Q_INVOKABLE void closeAllPages();
    bool closingAllPages() const { return m_pageCheck.active; }
    // a page that neither closes nor asks within this long is stuck: move on
    static constexpr int kPageCheckTimeoutMs = 3000;
    Q_INVOKABLE void reopenLastClosedTab();
    Q_INVOKABLE void executeChromeCommand(const QString &command);
    Q_INVOKABLE void activateTab(int index);
    // position in sidebar order; -1 is the last tab
    Q_INVOKABLE void activateTabAt(int position);
    Q_INVOKABLE void cycleTab(int delta);
    Q_INVOKABLE void navigate(const QString &input);
    Q_INVOKABLE void reload();
    // stops the active page loading
    Q_INVOKABLE void stop();
    Q_INVOKABLE void goBack();
    Q_INVOKABLE void goForward();
    Q_INVOKABLE void toggleDevTools();
    Q_INVOKABLE void copyActiveUrl();
    Q_INVOKABLE void cut();
    Q_INVOKABLE void copy();
    Q_INVOKABLE void paste();
    Q_INVOKABLE void pastePlainText();
    Q_INVOKABLE void selectAll();
    Q_INVOKABLE void undo();
    Q_INVOKABLE void redo();
    Q_INVOKABLE void saveSession() const;
    Q_INVOKABLE void setThemeColor(const QColor &color);
    // applies without saving; a later setThemeColor (or reset) saves
    Q_INVOKABLE void previewThemeColor(const QColor &color);
    Q_INVOKABLE void resetThemeColor();
    // true when closing the window should ask first (preference + tab count)
    Q_INVOKABLE bool confirmCloseRequired() const;
    Q_INVOKABLE void onTitleChanged(int tabIndex, const QString &title);
    Q_INVOKABLE void onUrlChanged(int tabIndex, const QString &url);
    Q_INVOKABLE void onLoadingChanged(int tabIndex, bool loading);
    Q_INVOKABLE void onLoadProgressChanged(int tabIndex, int progress);
    Q_INVOKABLE void onIconUrlChanged(int tabIndex, const QString &iconUrl);
    Q_INVOKABLE void onRenderProcessPidChanged(int tabIndex, qint64 pid);
    Q_INVOKABLE void onNewWindowRequested(int tabIndex, const QString &url);
    Q_INVOKABLE void updateTabTitle(const QString &tabId, const QString &title);
    Q_INVOKABLE void updateTabUrl(const QString &tabId, const QString &url);
    Q_INVOKABLE void updateTabLoading(const QString &tabId, bool loading);
    Q_INVOKABLE void updateTabProgress(const QString &tabId, int progress);
    Q_INVOKABLE void updateTabIcon(const QString &tabId, const QString &iconUrl);
    Q_INVOKABLE void updateTabRenderProcessPid(const QString &tabId, qint64 pid);
    // a page started or stopped playing sound
    Q_INVOKABLE void updateTabAudible(const QString &tabId, bool audible);
    Q_INVOKABLE void toggleTabMuted(const QString &tabId);
    // background: open it without switching to it
    Q_INVOKABLE void openTabFrom(const QString &sourceTabId, const QString &url, bool background = false);
    // loads |url| in that tab, whether or not it's the active one
    Q_INVOKABLE void loadInTab(const QString &tabId, const QString &url);
    Q_INVOKABLE void adoptWindow(QObject *window);
    Q_INVOKABLE void releaseWindow(QObject *window);
    void destroyAdoptedWindows();

signals:
    // about to swap every tab and folder for another space's
    void spaceAboutToChange();
    void spaceChanged();
    void activeIndexChanged();
    void activeUrlChanged();
    void activeTitleChanged();
    void activeIconUrlChanged();
    void activeLoadingChanged();
    void activeProgressChanged();
    void firstRunChanged();
    void themeModeChanged();
    void themeColorChanged();
    void newTabOpened(); // UI opens the command bar for a requested new tab
    void loadRequested(const QString &tabId, const QUrl &url);
    void navigationRequested(const QString &tabId, const QString &action); // "back"|"forward"|"reload"|"devtools"
    void closeWindowRequested();
    void allPagesClosed();
    // a page address went to the clipboard, for a moment of confirmation
    void linkCopied(const QString &url);
    void closeAllPagesCancelled();

private:
    struct ClosedTab {
        QUrl url;
    };

    void rememberClosedTab(const BrowserTab *tab);
    void finishCloseTab(int index);
    void askNextPage();
    void endPageCheck(bool allClosed);
    void rewireActiveTab();
    BrowserTab *tabForId(const QString &tabId) const;
    void emitActiveStateChanged();
    void restoreSession();
    void openInitialTab();
    QString sessionFilePath() const;
    QString sidebarFilePath() const;

    TabModel *m_model;
    SidebarModel *m_sidebar;
    Space *m_space = nullptr;
    CefProfile *m_webProfile = nullptr;

    QObject *m_activeTabCtx = nullptr;
    QList<QPointer<QObject>> m_adoptedWindows;
    QSettings *m_settings;
    QSettings *m_appSettings = nullptr;
    bool m_isFirstRun = true;
    bool m_sessionRestoredForSpace = false;
    bool m_closeInProgress = false;
    QHash<QString, QList<ClosedTab>> m_closedTabsBySpace;
    struct ResidentSpaceTabs { QVector<BrowserTab *> tabs; int activeIndex = -1; };
    QHash<QString, ResidentSpaceTabs> m_residentSpaces;

    struct PageCheck {
        bool active = false;
        QStringList queue;  // tabs still to ask
        QString current;    // the tab being asked
        QStringList closed; // pages that agreed, to bring back on "Stay"
    };
    PageCheck m_pageCheck;
    QTimer *m_pageCheckTimer = nullptr;

    static const int MIN_TABS_FOR_CYCLE = 2;
    static const int NO_TAB_CYCLE_DELTA = 0;
    static const QString NEW_TAB_URL;
    static const QString SETUP_URL;
};
