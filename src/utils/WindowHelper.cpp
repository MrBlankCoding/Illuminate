#include "WindowHelper.h"

#if defined(Q_OS_MACOS)
#include "WindowRounding.h"
#elif defined(Q_OS_WIN)
#include <windows.h>
#include <dwmapi.h>
#endif

void WindowHelper::showSystemMenu(QQuickWindow *window)
{
#if defined(Q_OS_WIN)
    if (!window)
        return;

    const HWND hwnd = reinterpret_cast<HWND>(window->winId());
    if (!hwnd)
        return;

    POINT cursorPosition;
    if (!GetCursorPos(&cursorPosition))
        return;

    const HMENU systemMenu = GetSystemMenu(hwnd, FALSE);
    if (!systemMenu)
        return;

    SetForegroundWindow(hwnd);
    const UINT command = TrackPopupMenu(systemMenu,
                                        TPM_RETURNCMD | TPM_RIGHTBUTTON,
                                        cursorPosition.x, cursorPosition.y, 0, hwnd, nullptr);
    PostMessage(hwnd, WM_NULL, 0, 0);
    if (command)
        PostMessage(hwnd, WM_SYSCOMMAND, command, 0);
#else
    Q_UNUSED(window);
#endif
}

void WindowHelper::applyTitleBarStyle(QQuickWindow *window, qreal barHeight)
{
#if defined(Q_OS_MACOS)
    WindowRounding::applyMacTitleBarStyle(window, barHeight);
#elif defined(Q_OS_WIN)
    if (!window)
        return;

    const auto applyStyle = [window, barHeight]() {
        HWND hwnd = reinterpret_cast<HWND>(window->winId());
        if (!hwnd)
            return;

        BOOL enable = TRUE;
        DwmSetWindowAttribute(hwnd, 20, &enable, sizeof(enable));
        // DWMWA_WINDOW_CORNER_PREFERENCE = 33, DWMWCP_ROUND = 2.
        const DWORD cornerPreferenceAttribute = 33;
        const int roundedCorners = 2;
        DwmSetWindowAttribute(hwnd, cornerPreferenceAttribute, &roundedCorners,
                              sizeof(roundedCorners));
        MARGINS margins = {0, 0, 0, static_cast<LONG>(barHeight)};
        DwmExtendFrameIntoClientArea(hwnd, &margins);
        SetWindowPos(hwnd, nullptr, 0, 0, 0, 0,
                     SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED);
    };

    applyStyle();
    QObject::connect(window, &QWindow::windowStateChanged, window,
                     [applyStyle](Qt::WindowState) { applyStyle(); });
#else
    Q_UNUSED(window);
    Q_UNUSED(barHeight);
#endif
}

void WindowHelper::setWindowButtonsVisible(QQuickWindow *window, bool visible)
{
#if defined(Q_OS_MACOS)
    WindowRounding::setMacWindowButtonsVisible(window, visible);
#else
    Q_UNUSED(window);
    Q_UNUSED(visible);
#endif
}

void WindowHelper::haptic(const QString &kind)
{
#if defined(Q_OS_MACOS)
    WindowRounding::performMacHaptic(kind == QLatin1String("snap") ? 1
                                     : kind == QLatin1String("level") ? 2 : 0);
#else
    Q_UNUSED(kind);
#endif
}
