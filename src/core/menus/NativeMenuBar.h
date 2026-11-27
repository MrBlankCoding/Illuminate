#pragma once

#include <QtGlobal>

class AppMenu;
class QQuickWindow;

namespace NativeMenuBar
{
    bool isNative();
    void attach(QQuickWindow *window, AppMenu *menu);
    void detach(QQuickWindow *window);
    void refresh(AppMenu *menu);
}
