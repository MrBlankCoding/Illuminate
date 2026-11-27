#pragma once

#include <QObject>
#include <QPointer>
#include <QUrl>
#include <QString>

class CefBrowserWrapper;
class CefProfile;

// represents a tab.
class BrowserTab : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString id READ id CONSTANT)

public:
    explicit BrowserTab(QObject *parent = nullptr);

    // stable for the tab's lifetime; the sidebar tree refers to tabs by it
    QString id() const;
    QUrl url() const;
    QString title() const;
    QString iconUrl() const;
    int progress() const; // 0–100
    bool loading() const;
    qint64 renderProcessPid() const; // 0 until Chromium starts the renderer
    bool suspended() const;
    bool audible() const { return m_audible; }
    bool muted() const { return m_muted; }
    bool hasActivity() const { return m_hasActivity; }
    static constexpr qint64 kActivityGraceMs = 3000;

    // called by browser controller
    void setUrl(const QUrl &url);
    void setTitle(const QString &title);
    void setIconUrl(const QString &iconUrl);
    void setProgress(int progress);
    void setLoading(bool loading);
    void setRenderProcessPid(qint64 pid);
    void setSuspended(bool suspended);
    void setAudible(bool audible);
    void setMuted(bool muted);
    void setHasActivity(bool activity);
    // whether a title change now counts as activity (finished loading a while ago)
    bool settled() const;

    void cut();
    void copy();
    void paste();
    void pastePlainText();
    void selectAll();
    void undo();
    void redo();
    void executeChromeCommand(int commandId);

    Q_INVOKABLE void setCefBrowserWrapper(CefBrowserWrapper *wrapper);
    // see CefBrowserWrapper::requestClose(); false: close the tab right away
    bool requestClose();
    // brings its page back after an approved close the person backed out of
    void recreatePage();

    // navigate time!
    // emits loadRequested.
    void requestLoad(const QUrl &url);

signals:
    void loadRequested(const QUrl &url); // -> QML view
    void urlChanged(const QUrl &url);
    void titleChanged(const QString &title);
    void iconUrlChanged(const QString &iconUrl);
    void progressChanged(int progress);
    void loadingChanged(bool loading);
    void renderProcessPidChanged(qint64 pid);
    void suspendedChanged(bool suspended);
    void audibleChanged(bool audible);
    void mutedChanged(bool muted);
    void hasActivityChanged(bool activity);

private:
    QString m_id;
    QUrl m_url;
    QString m_title;
    QString m_iconUrl;
    int m_progress = 0;
    bool m_loading = false;
    qint64 m_renderProcessPid = 0;
    bool m_suspended = false;
    bool m_audible = false;
    bool m_muted = false;
    bool m_hasActivity = false;
    qint64 m_loadedAt = 0; // msecs since epoch the last load finished; 0 while loading
    QPointer<CefBrowserWrapper> m_cefBrowserWrapper;
};
