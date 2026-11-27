#pragma once

#include <QColor>
#include <QPoint>
#include "AudibleTracker.h"

#include <QPointer>
#include <QSet>
#include <QRect>
#include <QQuickItem>
#include <QString>
#include <QUrl>
#include <QtQml/qqmlregistration.h>

#include <atomic>
#if defined(Q_MOC_RUN)
template <typename T> class CefRefPtr;
class CefBrowser;
class CefClient;
class CefDictionaryValue;
#else
#include <include/cef_browser.h>
#include <include/cef_client.h>
#endif

class CefProfile;
class BeforeUnloadRequest;
class CefTabClient;
class CefHostWindow;

class CefBrowserWrapper : public QQuickItem
{
    Q_OBJECT
    QML_NAMED_ELEMENT(CefBrowser)

    Q_PROPERTY(QUrl url READ url WRITE setUrl NOTIFY urlChanged)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(int loadProgress READ loadProgress NOTIFY loadProgressChanged)
    Q_PROPERTY(QString title READ title NOTIFY titleChanged)
    Q_PROPERTY(QUrl icon READ icon NOTIFY iconChanged)
    Q_PROPERTY(bool canGoBack READ canGoBack NOTIFY canGoBackChanged)
    Q_PROPERTY(bool canGoForward READ canGoForward NOTIFY canGoForwardChanged)
    Q_PROPERTY(qreal zoomFactor READ zoomFactor WRITE setZoomFactor NOTIFY zoomFactorChanged)
    Q_PROPERTY(qint64 renderProcessPid READ renderProcessPid NOTIFY renderProcessPidChanged)
    Q_PROPERTY(int lifecycleState READ lifecycleState WRITE setLifecycleState NOTIFY lifecycleStateChanged)
    Q_PROPERTY(int recommendedState READ recommendedState NOTIFY recommendedStateChanged)
    Q_PROPERTY(bool keepVisibleWhileLoading READ keepVisibleWhileLoading WRITE setKeepVisibleWhileLoading NOTIFY keepVisibleWhileLoadingChanged)
    Q_PROPERTY(QColor backgroundColor READ backgroundColor WRITE setBackgroundColor NOTIFY backgroundColorChanged)
    Q_PROPERTY(qreal cornerRadius READ cornerRadius WRITE setCornerRadius NOTIFY cornerRadiusChanged)
    // while set, keyboard focus stays with the Qt UI (overlays) instead of the page
    Q_PROPERTY(bool inputSuppressed READ inputSuppressed WRITE setInputSuppressed NOTIFY inputSuppressedChanged)
    // the page keyboard input belongs to. Re-showing a page that isn't (the
    // other half of a split) must not pull key focus away from the one that is.
    Q_PROPERTY(bool focusTarget READ focusTarget WRITE setFocusTarget NOTIFY focusTargetChanged)

    Q_PROPERTY(bool fullScreen READ fullScreen NOTIFY fullScreenChanged)
    // something on the page is playing with sound
    Q_PROPERTY(bool audible READ audible NOTIFY audibleChanged)
    // the page's sound is muted (Chromium mutes the whole tab, Web Audio too)
    Q_PROPERTY(bool audioMuted READ audioMuted WRITE setAudioMuted NOTIFY audioMutedChanged)
    // Chrome style pages print, find and run extensions through Chrome
    Q_PROPERTY(bool chromeStyle READ chromeStyle CONSTANT)
    Q_PROPERTY(CefProfile *profile READ profile WRITE setProfile NOTIFY profileChanged)
    // CefBrowser identifier, which extension APIs use as the tabId; 0 until created
    Q_PROPERTY(int browserId READ browserId NOTIFY browserIdChanged)
    // makes this an extension action popup for the page with that browserId
    // (-1: none). Set before the browser is created; 0 is an ordinary page.
    Q_PROPERTY(int actionTabId READ actionTabId WRITE setActionTabId NOTIFY actionTabIdChanged)

public:
    enum LifecycleState
    {
        Active = 0,
        Frozen = 1,
        Discarded = 2,
    };
    Q_ENUM(LifecycleState)

    enum WebAction
    {
        Copy = 0,
        Paste = 1,
        CopyLinkToClipboard = 2,
        DownloadImageToDisk = 3,
        DownloadMediaToDisk = 4,
        DownloadLinkToDisk = 5,
        Cut = 7,
        SelectAll = 8,
        PasteAndMatchStyle = 9,
        Undo = 10,
        Redo = 11,
    };
    Q_ENUM(WebAction)

    explicit CefBrowserWrapper(QQuickItem *parent = nullptr);
    ~CefBrowserWrapper() override;

    QUrl url() const { return m_url; }
    void setUrl(const QUrl &url);

    bool loading() const { return m_loading; }
    int loadProgress() const { return m_loadProgress; }
    QString title() const { return m_title; }
    QUrl icon() const { return m_icon; }
    bool canGoBack() const { return m_canGoBack; }
    bool canGoForward() const { return m_canGoForward; }
    qreal zoomFactor() const { return m_zoomFactor; }
    void setZoomFactor(qreal factor);
    qint64 renderProcessPid() const { return m_renderProcessPid; }
    int lifecycleState() const { return m_lifecycleState; }
    void setLifecycleState(int state);
    int recommendedState() const { return m_recommendedState; }
    bool keepVisibleWhileLoading() const { return m_keepVisibleWhileLoading; }
    void setKeepVisibleWhileLoading(bool keepVisible);
    QColor backgroundColor() const { return m_backgroundColor; }
    void setBackgroundColor(const QColor &color);
    qreal cornerRadius() const { return m_cornerRadius; }
    void setCornerRadius(qreal radius);
    bool inputSuppressed() const { return m_inputSuppressed; }
    void setInputSuppressed(bool suppressed);
    bool focusTarget() const { return m_focusTarget; }
    void setFocusTarget(bool target);

    bool fullScreen() const { return m_fullScreen; }
    bool audible() const { return m_audible.audible(); }
    bool audioMuted() const { return m_audioMuted; }
    void setAudioMuted(bool muted);
    bool chromeStyle() const;
    CefProfile *profile() const { return m_profile; }
    void setProfile(CefProfile *profile);
    int browserId() const { return m_browserId; }
    int actionTabId() const { return m_actionTabId; }
    void setActionTabId(int tabId);

    Q_INVOKABLE void goBack();
    Q_INVOKABLE void goForward();
    Q_INVOKABLE void reload();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void executeChromeCommand(int commandId);
    Q_INVOKABLE void triggerWebAction(int action, const QUrl &url = QUrl());
    Q_INVOKABLE void runJavaScript(const QString &script, int worldId = 0);
    Q_INVOKABLE void printToPdf(const QString &path);
    Q_INVOKABLE void print();
    Q_INVOKABLE void load(const QUrl &url) { setUrl(url); }
    Q_INVOKABLE void exitFullScreen();
    Q_INVOKABLE void refreshNativeView(bool raiseAboveSiblings = true);
    // DevTools open in their own window; inspectAt is in page coordinates
    Q_INVOKABLE void showDevTools(const QPoint &inspectAt = QPoint());
    Q_INVOKABLE void toggleDevTools();
    // hands keyboard focus to the page itself
    Q_INVOKABLE void takeFocus();
    // true while the page's own native window holds keyboard focus
    Q_INVOKABLE bool hasNativeFocus() const;
    bool requestClose();

    // Internal integration with CefTabClient
    void setBrowser(CefRefPtr<CefBrowser> browser);
    CefRefPtr<CefBrowser> browser() const { return m_browser; }
    void createBrowser(void *nativeWindowHandle, const QRect &geometry);
    void updateGeometry(const QRect &geometry);

    QRect sceneRect() const;
    void onUrlChanged(const QString &url);
    void onTitleChanged(const QString &title);
    void onIconChanged(const QString &iconUrl);
    void onLoadingStateChanged(bool isLoading, bool canGoBack, bool canGoForward);
    void onLoadProgressChanged(int progress);
    void onPdfPrintFinished(const QString &path, bool ok);
    void onFullscreenModeChanged(bool fullscreen);
    void onActionPopupMessage(const QString &kind, int width, int height);
    // takes ownership; shows it through beforeUnloadRequested
    void onBeforeUnloadRequested(BeforeUnloadRequest *request);
    void dismissBeforeUnload();
    // the page was closed (an approved close the person then backed out of):
    // bring it back at the same address
    void recreateBrowser();
    // the page's browser is gone (OnBeforeClose)
    void onBrowserClosed();
    Q_INVOKABLE bool adoptPage(CefBrowserWrapper *donor);
    // has a live page another wrapper could adopt
    Q_INVOKABLE bool hasPage() const;
    // one frame's media watcher reporting; the page is audible if any frame is
    void onFrameAudible(const QString &frameId, bool audible);
    // the renderer died or the page went away: nothing is playing any more
    void clearAudible();

protected:
    void geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry) override;
    void itemChange(ItemChange change, const ItemChangeData &data) override;
    void componentComplete() override;

private:
    void initializeBrowserHost();
    void createHostWindow(const CefBrowserSettings &settings, CefRefPtr<CefDictionaryValue> extraInfo);
    void onHostWindowReady();
    void updateHostWindow();
    QRect screenRect() const;
    void updateNativeGeometry();
    void applyInputSuppression();
    void notifyWindowRenderingHidden(bool hidden);
    void notifyWindowRenderingResized();

signals:
    void urlChanged();
    void loadingChanged();
    void loadProgressChanged(int progress);
    void titleChanged();
    void iconChanged();
    void canGoBackChanged();
    void canGoForwardChanged();
    void zoomFactorChanged();
    void renderProcessPidChanged(qint64 pid);
    void lifecycleStateChanged();
    void recommendedStateChanged();
    void keepVisibleWhileLoadingChanged();
    void backgroundColorChanged();
    void cornerRadiusChanged();
    void inputSuppressedChanged();
    void focusTargetChanged();
    void nativeFocusRequested();

    void profileChanged();
    void fullScreenChanged();
    void audibleChanged();
    void audioMutedChanged();
    void browserIdChanged();
    void actionTabIdChanged();

    void loadRequested(const QUrl &url);
    // background: ⌘/middle-click and "Open Link in New Tab" — don't switch to it
    void newWindowRequested(const QUrl &url, bool background);
    void printRequested();
    void pdfPrintingFinished(const QString &filePath, bool success);
    void permissionRequested(QObject *permission);
    void javaScriptConsoleMessage(int level, const QString &message, int lineNumber, const QString &sourceId);
    // the page is closing: it passed requestClose(), or called window.close()
    // itself. Its browser is already going away; the tab should go with it.
    void closeApproved();
    // the page asks "Leave site?"; QML shows the dialog and answers |request|
    void beforeUnloadRequested(QObject *request);
    // the person chose to stay on the page
    void closeCancelled();

    // action popups only: what the page reported about itself
    void contentSizeReported(int width, int height);
    void closeRequested();
    // action popups only: the page's native window gave up keyboard focus
    void nativeFocusLost();

private:
    QUrl m_url;
    CefProfile *m_profile = nullptr;
    bool m_loading = false;
    int m_loadProgress = 0;
    QString m_title;
    QUrl m_icon;
    bool m_canGoBack = false;
    bool m_canGoForward = false;
    qreal m_zoomFactor = 1.0;
    qint64 m_renderProcessPid = 0;
    int m_lifecycleState = Active;
    int m_recommendedState = Active;
    bool m_keepVisibleWhileLoading = false;
    bool m_hasLoadedOnce = false;
    QColor m_backgroundColor = Qt::white;
    qreal m_cornerRadius = 0;
    qreal m_nativeCornerRadius = -1;
    std::atomic<bool> m_inputSuppressed = false;
    bool m_restoreFocus = false;
    bool m_focusTarget = true;
    int m_browserId = 0;
    int m_actionTabId = 0;
    bool m_focusWhenShown = false;
    void *m_focusObserver = nullptr;

    CefRefPtr<CefBrowser> m_browser;
    CefRefPtr<CefTabClient> m_client;
    // macOS Chrome style: the page's own borderless window, pinned over us
    CefRefPtr<CefHostWindow> m_hostWindow;
    bool m_hostWindowReady = false;
    bool m_creatingBrowser = false;
    bool m_recreateWhenClosed = false;
    AudibleTracker m_audible;
    bool m_audioMuted = false;
    QPointer<BeforeUnloadRequest> m_beforeUnload;
    bool m_fullScreen = false;
    QRect m_nativeRect;
    bool m_nativeVisible = true;
    QMetaObject::Connection m_frameConnection;
    QMetaObject::Connection m_windowXConnection;
    QMetaObject::Connection m_windowYConnection;
    QMetaObject::Connection m_windowScreenConnection;
    QMetaObject::Connection m_windowVisibilityConnection;
    QMetaObject::Connection m_windowActivationConnection;
    QMetaObject::Connection m_windowActiveConnection;
    QUrl m_createdUrl;
};
