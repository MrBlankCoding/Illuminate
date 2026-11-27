#include "ShortcutBridge.h"
#include "BrowserLogger.h"

#include <include/internal/cef_types.h>

#include <QKeySequence>
#include <QWindow>

#include <QCoreApplication>
#include <QList>
#include <QMetaObject>
#include <QObject>
#include <QString>
#include <QThread>

namespace {

Qt::Key keyFromWindowsKeyCodeImpl(int code)
{
    if (code >= 0x30 && code <= 0x39)
        return static_cast<Qt::Key>(Qt::Key_0 + (code - 0x30));
    if (code >= 0x41 && code <= 0x5A)
        return static_cast<Qt::Key>(code);
    if (code >= 0x70 && code <= 0x7B)
        return static_cast<Qt::Key>(Qt::Key_F1 + (code - 0x70));
    if (code >= 0x60 && code <= 0x69)
        return static_cast<Qt::Key>(Qt::Key_0 + (code - 0x60));

    switch (code)
    {
    case 0x08: return Qt::Key_Backspace;
    case 0x09: return Qt::Key_Tab;
    case 0x0D: return Qt::Key_Return;
    case 0x1B: return Qt::Key_Escape;
    case 0x20: return Qt::Key_Space;
    case 0x21: return Qt::Key_PageUp;
    case 0x22: return Qt::Key_PageDown;
    case 0x23: return Qt::Key_End;
    case 0x24: return Qt::Key_Home;
    case 0x25: return Qt::Key_Left;
    case 0x26: return Qt::Key_Up;
    case 0x27: return Qt::Key_Right;
    case 0x28: return Qt::Key_Down;
    case 0x2D: return Qt::Key_Insert;
    case 0x2E: return Qt::Key_Delete;
    case 0x6A: return Qt::Key_Asterisk;
    case 0x6B: return Qt::Key_Plus;
    case 0x6D: return Qt::Key_Minus;
    case 0x6E: return Qt::Key_Period;
    case 0x6F: return Qt::Key_Slash;
    case 0xBA: return Qt::Key_Semicolon;
    case 0xBB: return Qt::Key_Equal;
    case 0xBC: return Qt::Key_Comma;
    case 0xBD: return Qt::Key_Minus;
    case 0xBE: return Qt::Key_Period;
    case 0xBF: return Qt::Key_Slash;
    case 0xC0: return Qt::Key_QuoteLeft;
    case 0xDB: return Qt::Key_BracketLeft;
    case 0xDC: return Qt::Key_Backslash;
    case 0xDD: return Qt::Key_BracketRight;
    case 0xDE: return Qt::Key_Apostrophe;
    default: return Qt::Key_unknown;
    }
}

Qt::KeyboardModifiers modifiersFromCefImpl(uint32_t cefEventFlags)
{
    Qt::KeyboardModifiers modifiers;
    if (cefEventFlags & EVENTFLAG_SHIFT_DOWN)
        modifiers |= Qt::ShiftModifier;
    if (cefEventFlags & EVENTFLAG_ALT_DOWN)
        modifiers |= Qt::AltModifier;
#ifdef Q_OS_MACOS
    if (cefEventFlags & EVENTFLAG_COMMAND_DOWN)
        modifiers |= Qt::ControlModifier;
    if (cefEventFlags & EVENTFLAG_CONTROL_DOWN)
        modifiers |= Qt::MetaModifier;
#else
    if (cefEventFlags & EVENTFLAG_CONTROL_DOWN)
        modifiers |= Qt::ControlModifier;
    if (cefEventFlags & EVENTFLAG_COMMAND_DOWN)
        modifiers |= Qt::MetaModifier;
#endif
    return modifiers;
}

constexpr const char *kQmlShortcutClassName = "QQuickShortcut";

bool isQmlShortcut(const QObject *object)
{
    return object && qstrcmp(object->metaObject()->className(), kQmlShortcutClassName) == 0;
}

bool replayIntoWindowShortcuts(QWindow *window, Qt::Key key, Qt::KeyboardModifiers modifiers)
{
    if (!window)
        return false;

    if (QThread::currentThread() != QCoreApplication::instance()->thread())
    {
        bool result = false;
        QMetaObject::invokeMethod(
            QCoreApplication::instance(),
            [&]() { result = replayIntoWindowShortcuts(window, key, modifiers); },
            Qt::BlockingQueuedConnection);
        return result;
    }

    const QString sequence = QKeySequence(QKeyCombination(modifiers, key)).toString(QKeySequence::PortableText);
    const QList<QObject *> descendants = window->findChildren<QObject *>();
    QList<QObject *> candidates;
    for (QObject *object : descendants)
    {
        if (!isQmlShortcut(object))
            continue;
        if (!object->property("enabled").toBool())
            continue;

        const QVariant seqProp = object->property("sequence");
        if (seqProp.isValid())
        {
            const QString s = QKeySequence(seqProp.toString()).toString(QKeySequence::PortableText);
            if (s == sequence)
                candidates.append(object);
        }

        const QVariant seqsProp = object->property("sequences");
        if (seqsProp.isValid())
        {
            const QStringList list = seqsProp.toStringList();
            for (const QString &entry : list)
            {
                if (QKeySequence(entry).toString(QKeySequence::PortableText) == sequence)
                {
                    if (!candidates.contains(object))
                        candidates.append(object);
                    break;
                }
            }
        }
    }

    if (candidates.isEmpty())
        return false;

    // CEF's native child view can own the macOS key window while Qt's parent
    // QQuickWindow is still the shortcut owner. Replaying a key event through
    // QWindow then fails Qt's active-window context check. We've already
    // matched an enabled shortcut belonging to this window, so activate it
    // directly and let its QML onActivated handler perform the action.
    for (QObject *object : candidates)
    {
        if (QMetaObject::invokeMethod(object, "activated", Qt::DirectConnection))
        {
            return true;
        }
    }

    return false;
}

} // namespace

Qt::Key ShortcutBridge::keyFromWindowsKeyCode(int code)
{
    return keyFromWindowsKeyCodeImpl(code);
}

Qt::KeyboardModifiers ShortcutBridge::modifiersFromCef(uint32_t cefEventFlags)
{
    return modifiersFromCefImpl(cefEventFlags);
}

bool ShortcutBridge::dispatchKeyPress(QWindow *window, int windowsKeyCode, uint32_t cefEventFlags)
{
    const Qt::Key key = keyFromWindowsKeyCodeImpl(windowsKeyCode);
    if (key == Qt::Key_unknown)
        return false;

    const Qt::KeyboardModifiers modifiers = modifiersFromCefImpl(cefEventFlags);

    return replayIntoWindowShortcuts(window, key, modifiers);
}
