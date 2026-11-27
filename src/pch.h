#pragma once

// Precompiled header for Illuminate.
// Includes the most expensive / most commonly included headers so MSVC
// parses them once instead of once per translation unit.
// Keep this limited to stable third-party / platform headers; do not add
// project headers here (changing them would force a full rebuild).

#if defined(_WIN32)
#  if !defined(WIN32_LEAN_AND_MEAN)
#    define WIN32_LEAN_AND_MEAN
#  endif
#  if !defined(NOMINMAX)
#    define NOMINMAX
#  endif
#  include <windows.h>
#endif

// CEF headers (large, included by many translation units)
#include <include/base/cef_compiler_specific.h>
#include <include/internal/cef_string.h>
#include <include/internal/cef_string_types.h>
#include <include/internal/cef_types.h>
#include <include/cef_base.h>
#include <include/cef_app.h>
#include <include/cef_browser.h>
#include <include/cef_client.h>
#include <include/cef_command_ids.h>
#include <include/cef_frame.h>
#include <include/cef_load_handler.h>
#include <include/cef_permission_handler.h>
#include <include/cef_render_process_handler.h>
#include <include/cef_request_context.h>
#include <include/cef_request_handler.h>
#include <include/cef_task.h>
#include <include/cef_values.h>
#include <include/cef_version.h>

// Views (CEF native windowing, heavy)
#include <include/views/cef_box_layout.h>
#include <include/views/cef_browser_view.h>
#include <include/views/cef_browser_view_delegate.h>
#include <include/views/cef_window.h>
#include <include/views/cef_window_delegate.h>

// Qt headers (large, included by many translation units)
#include <QApplication>
#include <QColor>
#include <QCoreApplication>
#include <QDebug>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QHash>
#include <QMetaObject>
#include <QMutexLocker>
#include <QObject>
#include <QPointer>
#include <QQuickItem>
#include <QQuickWindow>
#include <QRect>
#include <QRectF>
#include <QSettings>
#include <QThread>
#include <QTimer>
#include <QUrl>
#include <QVariant>
#include <QtMath>
#include <QtQml/qqmlregistration.h>

// C++ standard library
#include <algorithm>
#include <atomic>
#include <cmath>
#include <functional>
#include <memory>
#include <utility>
#include <vector>
