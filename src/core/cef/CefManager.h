#pragma once

#include <QMutex>
#include <QStringList>
#include <vector>
#include <include/cef_app.h>
#include <include/cef_browser.h>
#include <atomic>

class QTimer;

class CefManager : public CefApp, public CefBrowserProcessHandler
{
public:
    static CefManager &instance();
    static int executeProcess(int argc, char **argv);

    static bool initialize(int argc, char **argv);
    static bool isInitialized() { return instance().m_initialized; }
    static bool isShuttingDown() { return instance().m_shuttingDown.load(); }
    static void shutdown();
    static void setChromiumFlags(const QStringList &flags);
    static bool chromeStyle();
    static class CefProfile *defaultProfile();

    void browserCreated(CefRefPtr<CefBrowser> browser);
    void browserClosed(CefRefPtr<CefBrowser> browser);
    void closeAllBrowsers();

    CefRefPtr<CefBrowserProcessHandler> GetBrowserProcessHandler() override { return this; }
    // only consulted when this executable runs as a renderer (not on macOS)
    CefRefPtr<CefRenderProcessHandler> GetRenderProcessHandler() override;
    void OnBeforeCommandLineProcessing(const CefString &process_type,
                                       CefRefPtr<CefCommandLine> command_line) override;
    void OnRegisterCustomSchemes(CefRawPtr<CefSchemeRegistrar> registrar) override;

    // CefBrowserProcessHandler overrides
    void OnContextInitialized() override;
    void OnScheduleMessagePumpWork(int64_t delay_ms) override;
    CefRefPtr<CefClient> GetDefaultClient() override;

private:
    CefManager() = default;
    ~CefManager() override = default;
    void scheduleMessagePumpWork(int64_t delayMs);
    void doMessageLoopWork();

    static QStringList s_extraFlags;

    // atompic
    std::atomic<bool> m_initialized{false};
    bool m_externalPump = false;
    bool m_inPumpWork = false;
    std::atomic<bool> m_shuttingDown{false};

    QMutex m_browsersMutex;
    std::vector<CefRefPtr<CefBrowser>> m_browsers;
    QTimer *m_pumpTimer = nullptr;
    CefRefPtr<CefClient> m_strayClient;
    CefRefPtr<CefRenderProcessHandler> m_renderHandler;

    IMPLEMENT_REFCOUNTING(CefManager);
};

#ifdef __APPLE__
void installCefAppProtocol();
#endif
