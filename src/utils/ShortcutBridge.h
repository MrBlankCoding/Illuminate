#pragma once

#include <Qt>
#include <QString>

class QWindow;

class ShortcutBridge
{
public:
    static bool dispatchKeyPress(QWindow *window, int windowsKeyCode, uint32_t cefEventFlags);
    static Qt::Key keyFromWindowsKeyCode(int windowsKeyCode);
    static Qt::KeyboardModifiers modifiersFromCef(uint32_t cefEventFlags);

    // Snapshot of |window|'s enabled shortcuts, for key presses that arrive
    // on CEF's own thread (Windows, Linux). Qt thread only.
    static void refreshShortcuts(QWindow *window);
    static bool isCachedShortcut(const QWindow *window, Qt::Key key, Qt::KeyboardModifiers modifiers);

};