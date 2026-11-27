#pragma once

#include <include/views/cef_browser_view.h>
#include <include/views/cef_browser_view_delegate.h>
#include <include/views/cef_box_layout.h>
#include <include/views/cef_window.h>
#include <include/views/cef_window_delegate.h>

class CefPopupWindow : public CefWindowDelegate, public CefBrowserViewDelegate
{
public:
    static void rememberFeatures(int openerBrowserId, const CefPopupFeatures &features);
    // window.open() of a blank tab the page fills in afterwards: its window
    // stays hidden until CefStrayBrowserClient moves the page into a real tab
    static void rememberHiddenTab(int openerBrowserId);
    static void forgetFeatures(int openerBrowserId);
    static CefRefPtr<CefBrowserViewDelegate> delegateFor(CefRefPtr<CefBrowserView> opener,
                                                         const CefRect &anchor);
    static bool open(CefRefPtr<CefBrowserView> popup);
    // what the page asked for (or 500x640), centred over |anchor| unless it gave a position
    static CefRect boundsFor(const CefPopupFeatures *features, const CefRect &anchor);

    // CefBrowserViewDelegate
    cef_runtime_style_t GetBrowserRuntimeStyle() override { return CEF_RUNTIME_STYLE_CHROME; }
    ChromeToolbarType GetChromeToolbarType(CefRefPtr<CefBrowserView>) override { return CEF_CTT_LOCATION; }
    void OnBrowserCreated(CefRefPtr<CefBrowserView> browserView, CefRefPtr<CefBrowser> browser) override;
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
    cef_show_state_t GetInitialShowState(CefRefPtr<CefWindow>) override
    {
        return m_hidden ? CEF_SHOW_STATE_HIDDEN : CEF_SHOW_STATE_NORMAL;
    }
    bool CanClose(CefRefPtr<CefWindow> window) override;

private:
    CefPopupWindow(const CefRect &bounds, bool hidden) : m_bounds(bounds), m_hidden(hidden) {}

    CefRect m_bounds;
    bool m_hidden = false;
    CefRefPtr<CefBrowserView> m_browserView;
    CefRefPtr<CefWindow> m_window;
    CefRefPtr<CefView> m_toolbar;

    IMPLEMENT_REFCOUNTING(CefPopupWindow);
};
