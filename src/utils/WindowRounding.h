#pragma once

#include <QtGlobal>
#include <qtypes.h>

class QQuickWindow;

namespace WindowRounding
{
#if defined(Q_OS_MACOS)
    // quit the file
    void applyMacTitleBarStyle(QQuickWindow *window, qreal barHeight);
    void setMacWindowButtonsVisible(QQuickWindow *window, bool visible);
    void performMacHaptic(int pattern); // 0 generic, 1 alignment, 2 level change
#endif
}
