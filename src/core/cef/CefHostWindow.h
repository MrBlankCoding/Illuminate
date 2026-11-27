#pragma once

#include <include/views/cef_browser_view.h>
#include <include/views/cef_browser_view_delegate.h>
#include <include/views/cef_box_layout.h>
#include <include/views/cef_window.h>
#include <include/views/cef_window_delegate.h>
#include <QRect>

#include <atomic>
#include <functional>

class CefHostWindow : public CefWindowDelegate, public CefBrowserViewDelegate
{
public:
    CefHostWindow(const CefRect &bounds, std::function<void()> ready);

    void create(CefRefPtr<CefClient> client,
                const CefString &url,
                const CefBrowserSettings &settings,
                CefRefPtr<CefDictionaryValue> extraInfo,
                CefRefPtr<CefRequestContext> requestContext);
    void setBounds(const CefRect &bounds, void *parentView = nullptr, const QRect &geometry = QRect(), bool visible = true);
    void setVisible(bool visible);
    void restore(std::function<void()> afterRestore = {});
    void close();
    void *nativeHandle() const;

    // CefBrowserViewDelegate
    cef_runtime_style_t GetBrowserRuntimeStyle() override { return CEF_RUNTIME_STYLE_CHROME; }
    ChromeToolbarType GetChromeToolbarType(CefRefPtr<CefBrowserView>) override { return CEF_CTT_NORMAL; }
    void OnWindowChanged(CefRefPtr<CefView> view, bool added) override;
    CefRefPtr<CefBrowserViewDelegate> GetDelegateForPopupBrowserView(CefRefPtr<CefBrowserView> browserView,
                                                                     const CefBrowserSettings &settings,
                                                                     CefRefPtr<CefClient> client,
                                                                     bool isDevtools) override;
    bool OnPopupBrowserViewCreated(CefRefPtr<CefBrowserView> browserView,
                                   CefRefPtr<CefBrowserView> popupBrowserView,
                                   bool isDevtools) override;

    // CefWindowDelegate
    cef_runtime_style_t GetWindowRuntimeStyle() override { return CEF_RUNTIME_STYLE_CHROME; }
    void OnWindowCreated(CefRefPtr<CefWindow> window) override;
    void OnWindowDestroyed(CefRefPtr<CefWindow> window) override;
    CefRect GetInitialBounds(CefRefPtr<CefWindow>) override { return m_bounds; }
    cef_show_state_t GetInitialShowState(CefRefPtr<CefWindow>) override { return CEF_SHOW_STATE_HIDDEN; }
    bool IsFrameless(CefRefPtr<CefWindow>) override { return true; }
    bool WithStandardWindowButtons(CefRefPtr<CefWindow>) override { return false; }
    bool CanResize(CefRefPtr<CefWindow>) override { return false; }
    bool CanMaximize(CefRefPtr<CefWindow>) override { return false; }
    bool CanMinimize(CefRefPtr<CefWindow>) override { return false; }
    cef_state_t AcceptsFirstMouse(CefRefPtr<CefWindow>) override { return STATE_ENABLED; }

private:
    CefRect m_bounds;
    std::function<void()> m_ready;
    CefRefPtr<CefBrowserView> m_browserView;
    CefRefPtr<CefWindow> m_window;
    CefRefPtr<CefBoxLayout> m_windowLayout;
    CefRefPtr<CefView> m_chromeToolbar;
    std::atomic<cef_window_handle_t> m_nativeHandle{nullptr};
    bool m_visible = false;
    bool m_closing = false;

    IMPLEMENT_REFCOUNTING(CefHostWindow);
};
