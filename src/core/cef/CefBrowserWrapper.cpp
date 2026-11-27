#include "CefBrowserWrapper.h"
#include "browser/CefBrowserWrapperPrivate.h"

using namespace CefBrowserWrapperPrivate;

#if defined(_WIN32)
#include <windows.h>
#include <QHash>
#include <QtMath>

namespace {
QHash<quintptr, qreal> &cefWindowCornerRadii()
{
    static QHash<quintptr, qreal> radii;
    return radii;
}

UINT dpiForWindow(HWND hwnd)
{
    using GetDpiForWindowFn = UINT(WINAPI *)(HWND);
    static const auto getDpiForWindow = reinterpret_cast<GetDpiForWindowFn>(
        GetProcAddress(GetModuleHandleW(L"user32.dll"), "GetDpiForWindow"));
    return getDpiForWindow ? getDpiForWindow(hwnd) : 96;
}

void applyWindowCornerRadius(HWND hwnd, qreal radius)
{
    if (!hwnd)
        return;
    if (radius <= 0) {
        SetWindowRgn(hwnd, nullptr, TRUE);
        return;
    }

    RECT bounds{};
    if (!GetWindowRect(hwnd, &bounds))
        return;
    const int width = bounds.right - bounds.left;
    const int height = bounds.bottom - bounds.top;
    if (width <= 0 || height <= 0)
        return;

    const int radiusPx = qRound(radius * dpiForWindow(hwnd) / 96.0);
    const int diameter = qMin(qMin(width, height), qMax(1, radiusPx * 2));
    HRGN region = CreateRoundRectRgn(0, 0, width + 1, height + 1, diameter, diameter);
    if (region && !SetWindowRgn(hwnd, region, TRUE))
        DeleteObject(region);
}
} // namespace

void cefSetNativeViewGeometry(cef_window_handle_t hwnd, const QRect &rect, bool visible)
{
    if (!hwnd)
        return;
    if (visible) {
        // Avoid a white flash before CEF paints by filling with a dark background.
        RECT rc{0, 0, rect.width(), rect.height()};
        HDC hdc = GetDC(hwnd);
        if (hdc) {
            HBRUSH brush = CreateSolidBrush(RGB(30, 30, 30));
            FillRect(hdc, &rc, brush);
            DeleteObject(brush);
            ReleaseDC(hwnd, hdc);
        }
    }
    ShowWindow(hwnd, visible ? SW_SHOWNA : SW_HIDE);
    if (!visible)
        return;
    SetWindowPos(hwnd, nullptr, rect.x(), rect.y(), rect.width(), rect.height(),
                 SWP_NOZORDER | SWP_NOACTIVATE);
    applyWindowCornerRadius(hwnd, cefWindowCornerRadii().value(reinterpret_cast<quintptr>(hwnd)));
}
void cefSetNativeViewCornerRadius(cef_window_handle_t hwnd, qreal radius)
{
    if (!hwnd)
        return;
    const quintptr key = reinterpret_cast<quintptr>(hwnd);
    if (radius <= 0)
        cefWindowCornerRadii().remove(key);
    else
        cefWindowCornerRadii().insert(key, radius);
    applyWindowCornerRadius(hwnd, radius);
}
void cefSetChildWindowCornerRadius(void *childHandle, qreal radius)
{
    cefSetNativeViewCornerRadius(reinterpret_cast<cef_window_handle_t>(childHandle), radius);
}
void cefRaiseChildWindow(void *, void *childHandle)
{
    HWND hwnd = reinterpret_cast<HWND>(childHandle);
    if (hwnd)
        SetWindowPos(hwnd, HWND_TOP, 0, 0, 0, 0,
                     SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
}
void cefAttachChildWindow(void *parentHandle, void *childHandle)
{
    HWND parent = reinterpret_cast<HWND>(parentHandle);
    HWND child = reinterpret_cast<HWND>(childHandle);
    if (!parent || !child)
        return;
    LONG_PTR style = GetWindowLongPtr(child, GWL_STYLE);
    style &= ~(WS_POPUP | WS_CAPTION | WS_THICKFRAME | WS_SYSMENU | WS_MINIMIZEBOX | WS_MAXIMIZEBOX);
    style |= WS_CHILD;
    SetWindowLongPtr(child, GWL_STYLE, style);
    SetParent(child, parent);
    SetWindowPos(child, HWND_TOP, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_FRAMECHANGED);
}
void cefDetachChildWindow(void *childHandle)
{
    HWND child = reinterpret_cast<HWND>(childHandle);
    if (child) {
        cefSetNativeViewCornerRadius(child, 0);
        ShowWindow(child, SW_HIDE);
        SetParent(child, nullptr);
    }
}
bool cefResignNativeFocus(cef_window_handle_t childHandle)
{
    HWND child = reinterpret_cast<HWND>(childHandle);
    HWND parent = child ? GetParent(child) : nullptr;
    if (!parent || (GetFocus() != child && GetActiveWindow() != child))
        return false;
    SetActiveWindow(parent);
    SetFocus(parent);
    return true;
}
void cefFocusParentWindow(void *parentHandle)
{
    HWND parent = reinterpret_cast<HWND>(parentHandle);
    if (parent) {
        SetActiveWindow(parent);
        SetFocus(parent);
    }
}
#elif defined(ILLUMINATE_HAS_X11)
#include <X11/Xlib.h>

namespace {
// Xlib's default handler exits the process. A BadWindow from a page window
// CEF already destroyed, or a BadMatch from focusing an unmapped parent, is
// harmless here: log it and carry on, as CEF's own sample does.
int logX11Error(Display *, XErrorEvent *event)
{
    qWarning("[X11] ignored error %d (request %d.%d) on window 0x%lx",
             event->error_code, event->request_code, event->minor_code, event->resourceid);
    return 0;
}

int logX11IOError(Display *)
{
    qWarning("[X11] connection to the display was lost");
    return 0;
}

Display *cefX11Display()
{
    static Display *display = []() {
        XSetErrorHandler(logX11Error);
        XSetIOErrorHandler(logX11IOError);
        return XOpenDisplay(nullptr);
    }();
    return display;
}
}

void cefSetNativeViewGeometry(cef_window_handle_t window, const QRect &rect, bool visible)
{
    Display *display = cefX11Display();
    if (!display || !window)
        return;
    const Window child = static_cast<Window>(window);
    if (visible) {
        XMoveResizeWindow(display, child, rect.x(), rect.y(),
                          static_cast<unsigned int>(qMax(1, rect.width())),
                          static_cast<unsigned int>(qMax(1, rect.height())));
        XMapWindow(display, child);
    } else {
        XUnmapWindow(display, child);
    }
    XFlush(display);
}
void cefRaiseChildWindow(void *, void *childHandle)
{
    Display *display = cefX11Display();
    if (display && childHandle) {
        XRaiseWindow(display, static_cast<Window>(reinterpret_cast<quintptr>(childHandle)));
        XFlush(display);
    }
}
void cefAttachChildWindow(void *parentHandle, void *childHandle)
{
    Display *display = cefX11Display();
    if (display && parentHandle && childHandle) {
        XReparentWindow(display,
                        static_cast<Window>(reinterpret_cast<quintptr>(childHandle)),
                        static_cast<Window>(reinterpret_cast<quintptr>(parentHandle)), 0, 0);
        XFlush(display);
    }
}
void cefDetachChildWindow(void *childHandle)
{
    Display *display = cefX11Display();
    if (display && childHandle) {
        const Window child = static_cast<Window>(reinterpret_cast<quintptr>(childHandle));
        XUnmapWindow(display, child);
        XReparentWindow(display, child,
                        DefaultRootWindow(display), 0, 0);
        XFlush(display);
    }
}
bool cefResignNativeFocus(cef_window_handle_t childHandle)
{
    Display *display = cefX11Display();
    if (!display || !childHandle)
        return false;
    Window root = None;
    Window parent = None;
    Window *children = nullptr;
    unsigned int childCount = 0;
    if (!XQueryTree(display, static_cast<Window>(childHandle), &root, &parent, &children, &childCount))
        return false;
    if (children)
        XFree(children);
    if (parent == None)
        return false;
    XSetInputFocus(display, parent, RevertToParent, CurrentTime);
    XFlush(display);
    return true;
}
void cefFocusParentWindow(void *parentHandle)
{
    Display *display = cefX11Display();
    if (display && parentHandle) {
        XSetInputFocus(display,
                       static_cast<Window>(reinterpret_cast<quintptr>(parentHandle)),
                       RevertToParent, CurrentTime);
        XFlush(display);
    }
}
#elif !defined(__APPLE__)
// Native embedding is unavailable on platforms without a supported window system.
void cefSetNativeViewGeometry(cef_window_handle_t, const QRect &, bool) {}
#endif

#ifndef __APPLE__
#if !defined(_WIN32)
void cefSetNativeViewCornerRadius(cef_window_handle_t, qreal) {}
#endif
#if !defined(_WIN32) && !defined(ILLUMINATE_HAS_X11)
bool cefResignNativeFocus(cef_window_handle_t) { return false; }
#endif
void cefSetChildWindowBackgroundColor(void *, const QColor &) {}
#if !defined(_WIN32)
void cefSetChildWindowCornerRadius(void *, qreal) {}
#endif
#if !defined(_WIN32)
#if !defined(ILLUMINATE_HAS_X11)
void cefRaiseChildWindow(void *, void *) {}
void cefAttachChildWindow(void *, void *) {}
void cefDetachChildWindow(void *) {}
#endif
#endif
#if !defined(_WIN32) && !defined(ILLUMINATE_HAS_X11)
void cefFocusParentWindow(void *) {}
#endif
bool cefChildWindowIsKey(void *) { return false; }
void cefSetChildWindowCanTakeKey(void *, bool) {}
void cefMakeChildWindowKey(void *) {}
bool cefChildWindowHasKey(void *) { return false; }
void *cefObserveKeyLoss(void *, std::function<void()>) { return nullptr; }
void cefStopObservingKeyLoss(void *) {}
#endif

namespace {
class ClosureTask final : public CefTask
{
public:
    explicit ClosureTask(std::function<void()> callback) : m_callback(std::move(callback)) {}

    void Execute() override { m_callback(); }

private:
    std::function<void()> m_callback;

    IMPLEMENT_REFCOUNTING(ClosureTask);
};
}

class CefPdfCallbackImpl : public CefPdfPrintCallback
{
public:
    CefPdfCallbackImpl(CefBrowserWrapper *wrapper, const QString &path)
        : m_wrapper(wrapper), m_path(path) {}

    void OnPdfPrintFinished(const CefString &path, bool ok) override
    {
        Q_UNUSED(path);
        QPointer<CefBrowserWrapper> wrapper = m_wrapper;
        const QString outPath = m_path;
        QMetaObject::invokeMethod(
            QCoreApplication::instance(),
            [wrapper, outPath, ok]()
            {
                if (wrapper)
                    wrapper->onPdfPrintFinished(outPath, ok);
            },
            Qt::QueuedConnection);
    }

private:
    QPointer<CefBrowserWrapper> m_wrapper;
    QString m_path;

    IMPLEMENT_REFCOUNTING(CefPdfCallbackImpl);
};


CefBrowserWrapper::CefBrowserWrapper(QQuickItem *parent)
    : QQuickItem(parent),
      m_client(new CefTabClient(this))
{
    setFlag(ItemHasContents, true);
    connect(&m_audible, &AudibleTracker::audibleChanged, this, &CefBrowserWrapper::audibleChanged);
}

void CefBrowserWrapper::setProfile(CefProfile *profile)
{
    if (m_profile == profile)
        return;
    m_profile = profile;
    emit profileChanged();
}

void CefBrowserWrapper::setActionTabId(int tabId)
{
    if (m_actionTabId == tabId)
        return;
    if (m_browser || m_creatingBrowser || m_hostWindow)
        qWarning() << "[CEF] actionTabId only applies before the browser is created";
    m_actionTabId = tabId;
    emit actionTabIdChanged();
}

void CefBrowserWrapper::takeFocus()
{
    auto host = hostOf(m_browser);
    if (!host)
        return;
    if (m_hostWindow)
    {
        // not on screen yet: updateHostWindow() finishes this once it is
        if (!m_hostWindowReady || !m_nativeVisible)
        {
            m_focusWhenShown = true;
            return;
        }
        cefMakeChildWindowKey(m_hostWindow->nativeHandle());
    }
    host->SetFocus(true);
}

bool CefBrowserWrapper::hasNativeFocus() const
{
    return m_hostWindowReady && cefChildWindowHasKey(m_hostWindow->nativeHandle());
}

void CefBrowserWrapper::onActionPopupMessage(const QString &kind, int width, int height)
{
    if (m_actionTabId == 0)
        return;
    if (kind == QLatin1String(ExtensionPopupProtocol::kResize))
        emit contentSizeReported(width, height);
    else if (kind == QLatin1String(ExtensionPopupProtocol::kClose))
        emit closeRequested();
}

CefBrowserWrapper::~CefBrowserWrapper()
{
    cefStopObservingKeyLoss(std::exchange(m_focusObserver, nullptr));
    auto host = hostOf(m_browser);
    m_browser = nullptr;
    if (m_hostWindow)
    {
        cefSetChildWindowCornerRadius(m_hostWindow->nativeHandle(), 0);
        cefDetachChildWindow(m_hostWindow->nativeHandle());
        if (host && !CefManager::isShuttingDown())
            host->CloseBrowser(true);
        m_hostWindow->close();
        m_hostWindow = nullptr;
        return;
    }
    if (!host)
        return;
    cefSetNativeViewCornerRadius(host->GetWindowHandle(), 0);
    cefSetNativeViewGeometry(host->GetWindowHandle(), m_nativeRect, false);

    if (!CefManager::isShuttingDown())
        host->CloseBrowser(true);
}

void CefBrowserWrapper::setUrl(const QUrl &url)
{
    if (m_url == url)
        return;

    m_url = url;
    emit urlChanged();

    if (auto frame = mainFrameOf(m_browser))
        frame->LoadURL(qUrlToCefString(url));
}



void CefBrowserWrapper::printToPdf(const QString &path)
{
    auto host = hostOf(m_browser);
    if (!host)
    {
        // Callers wait for pdfPrintingFinished; don't leave them hanging.
        QTimer::singleShot(0, this, [this, path]()
                           { onPdfPrintFinished(path, false); });
        return;
    }

    CefPdfPrintSettings settings;
    CefRefPtr<CefPdfPrintCallback> callback(new CefPdfCallbackImpl(this, path));
    host->PrintToPDF(qStringToCef(path), settings, callback);
}
void CefBrowserWrapper::print()
{
    if (auto host = hostOf(m_browser))
        host->Print();
}

// full screen
void CefBrowserWrapper::exitFullScreen()
{
    if (!m_fullScreen)
        return;
    if (auto host = hostOf(m_browser))
        host->ExitFullscreen(true);
}

void CefBrowserWrapper::onFullscreenModeChanged(bool fullscreen)
{
    if (m_fullScreen == fullscreen)
        return;
    m_fullScreen = fullscreen;
    emit fullScreenChanged();
}
// dev tools
