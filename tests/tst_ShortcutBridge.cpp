#include <QtTest>
#include <QCoreApplication>
#include <QKeySequence>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QQuickWindow>

#include <include/internal/cef_types.h>

#include "ShortcutBridge.h"

class TestShortcutBridge : public QObject
{
    Q_OBJECT

    static constexpr int kVkT = 'T';
    static constexpr int kVkUp = 0x26;
    static constexpr int kVkF12 = 0x7B;
    static constexpr int kVkEqual = 0xBB;
    static constexpr int kVkThree = '3';
    static constexpr uint32_t kCmd = EVENTFLAG_COMMAND_DOWN;
    static constexpr uint32_t kCmdShift = EVENTFLAG_COMMAND_DOWN | EVENTFLAG_SHIFT_DOWN;
#ifdef Q_OS_MACOS
    static constexpr uint32_t kPrimary = EVENTFLAG_COMMAND_DOWN;
#else
    static constexpr uint32_t kPrimary = EVENTFLAG_CONTROL_DOWN;
#endif

    QObject *m_window = nullptr;

private slots:
    void lettersAndDigitsMapDirectly()
    {
        QCOMPARE(ShortcutBridge::keyFromWindowsKeyCode(kVkT), Qt::Key_T);
        QCOMPARE(ShortcutBridge::keyFromWindowsKeyCode(kVkThree), Qt::Key_3);
        QCOMPARE(ShortcutBridge::keyFromWindowsKeyCode(0x30 + 9), Qt::Key_9);
    }

    void namedKeysAreTranslated()
    {
        QCOMPARE(ShortcutBridge::keyFromWindowsKeyCode(kVkUp), Qt::Key_Up);
        QCOMPARE(ShortcutBridge::keyFromWindowsKeyCode(0x7B), Qt::Key_F12);
        QCOMPARE(ShortcutBridge::keyFromWindowsKeyCode(kVkEqual), Qt::Key_Equal);
        QCOMPARE(ShortcutBridge::keyFromWindowsKeyCode(0x2E), Qt::Key_Delete);
        QCOMPARE(ShortcutBridge::keyFromWindowsKeyCode(0x1B), Qt::Key_Escape);
    }

    void unknownKeyCodesAreIgnored()
    {
        QCOMPARE(ShortcutBridge::keyFromWindowsKeyCode(0x99), Qt::Key_unknown);
        QCOMPARE(ShortcutBridge::keyFromWindowsKeyCode(0), Qt::Key_unknown);
    }

    void commandIsControlModifierOnMac()
    {
        // QML spells the Command key "Ctrl" everywhere in this project
        const Qt::KeyboardModifiers cmd = ShortcutBridge::modifiersFromCef(kCmd);
#ifdef Q_OS_MACOS
        QCOMPARE(cmd, Qt::KeyboardModifiers(Qt::ControlModifier));
        QCOMPARE(ShortcutBridge::modifiersFromCef(EVENTFLAG_CONTROL_DOWN),
                 Qt::KeyboardModifiers(Qt::MetaModifier));
#else
        QCOMPARE(ShortcutBridge::modifiersFromCef(EVENTFLAG_CONTROL_DOWN),
                 Qt::KeyboardModifiers(Qt::ControlModifier));
        QCOMPARE(cmd, Qt::KeyboardModifiers(Qt::MetaModifier));
#endif
        QCOMPARE(ShortcutBridge::modifiersFromCef(kCmdShift),
                 Qt::KeyboardModifiers(cmd | Qt::ShiftModifier));
    }

    void producesTheKeySequencesTheUiDeclares()
    {
        // the QML shortcut table, checked against Qt's own parser
        const auto combo = [](int vk, uint32_t flags) {
            return QKeySequence(QKeyCombination(ShortcutBridge::modifiersFromCef(flags),
                                                ShortcutBridge::keyFromWindowsKeyCode(vk)));
        };
        QCOMPARE(combo(kVkT, kPrimary), QKeySequence(QStringLiteral("Ctrl+T")));
        QCOMPARE(combo(kVkUp, kPrimary), QKeySequence(QStringLiteral("Ctrl+Up")));
        QCOMPARE(combo(kVkF12, 0), QKeySequence(QStringLiteral("F12")));
        QCOMPARE(combo(kVkThree, kPrimary), QKeySequence(QStringLiteral("Ctrl+3")));
        QCOMPARE(combo('I', kPrimary | EVENTFLAG_ALT_DOWN), QKeySequence(QStringLiteral("Ctrl+Alt+I")));
        // Cmd+Shift+F is the letter F, not the F6 function key: only the
        // physical F-key row reports 0x70..0x7B
        QCOMPARE(combo('F', kPrimary | EVENTFLAG_SHIFT_DOWN), QKeySequence(QStringLiteral("Ctrl+Shift+F")));
    }

    void qmlShortcutFiresAndUnmatchedKeysFallThrough()
    {
        QObject *root = freshWindow();
        QVERIFY(root);
        auto *window = qobject_cast<QQuickWindow *>(root);
        QVERIFY(window);

        // Cmd+T: the app's own shortcut, must be consumed
        QVERIFY(ShortcutBridge::dispatchKeyPress(window, kVkT, kPrimary));
        QCOMPARE(root->property("activatedCount").toInt(), 1);

        // Cmd+K has no shortcut, so Chromium must still see it
        QVERIFY(!ShortcutBridge::dispatchKeyPress(window, 'K', kPrimary));
        QCOMPARE(root->property("activatedCount").toInt(), 1);

        // the F12 binding has no modifier
        QVERIFY(ShortcutBridge::dispatchKeyPress(window, kVkF12, 0));
        QCOMPARE(root->property("activatedCount").toInt(), 2);
    }

    void closedWindowDoesNotStealShortcuts()
    {
        QObject *outgoing = createWindowWithShortcut();
        auto *outgoingWindow = qobject_cast<QQuickWindow *>(outgoing);
        QVERIFY(outgoingWindow);
        outgoing->setProperty("shortcutContext", static_cast<int>(Qt::WindowShortcut));
        outgoingWindow->show();
        QCoreApplication::processEvents();

        QObject *incoming = freshWindow();
        auto *incomingWindow = qobject_cast<QQuickWindow *>(incoming);
        QVERIFY(incomingWindow);
        incoming->setProperty("shortcutContext", static_cast<int>(Qt::WindowShortcut));
        incomingWindow->show();
        incomingWindow->requestActivate();
        QCoreApplication::processEvents();

        // outlives its usefulness, exactly as a switched-away window did
        outgoingWindow->close();
        QCoreApplication::processEvents();

        QVERIFY(ShortcutBridge::dispatchKeyPress(incomingWindow, kVkT, kPrimary));
        QCOMPARE(incoming->property("activatedCount").toInt(), 1);

        delete outgoingWindow;
    }

    void disabledShortcutsAreNotConsumed()
    {
        QObject *root = freshWindow();
        QVERIFY(root);
        auto *window = qobject_cast<QQuickWindow *>(root);
        QVERIFY(window);

        QVERIFY(root->setProperty("findEnabled", false));
        QVERIFY(!ShortcutBridge::dispatchKeyPress(window, 'G', kPrimary));
        QCOMPARE(root->property("activatedCount").toInt(), 0);
    }

    void windowShortcutMatchesWhenFocused()
    {
        QQuickWindow *window = focusedWindow();
        if (!window)
            return;
        QVERIFY(ShortcutBridge::dispatchKeyPress(window, kVkT, kPrimary));
        QCOMPARE(m_window->property("activatedCount").toInt(), 1);
    }


private:
    // A WindowShortcut whose window is the focus window: the narrower of the two
    // contexts. CEF's native view holding first responder inside that same
    // window is only reproducible in the app itself, not here.
    QQuickWindow *focusedWindow()
    {
        QObject *root = freshWindow();
        if (!root)
            return nullptr;
        if (!root->setProperty("shortcutContext", static_cast<int>(Qt::WindowShortcut)))
        {
            qWarning("could not set the shortcut context");
            return nullptr;
        }
        auto *window = qobject_cast<QQuickWindow *>(root);
        // let the `context: win.shortcutContext` bindings re-evaluate before
        // the key press is dispatched
        QCoreApplication::processEvents();
        if (QGuiApplication::focusWindow() != window)
        {
            qWarning("test window never became the focus window");
            return nullptr;
        }
        return window;
    }

    QObject *freshWindow()
    {
        delete m_window;
        m_window = createWindowWithShortcut();
        auto *window = qobject_cast<QQuickWindow *>(m_window);
        if (!window)
            return m_window;

        window->show();
        window->requestActivate();
        QCoreApplication::processEvents();
        if (QGuiApplication::focusWindow() != window)
            qWarning("test window never became the focus window");
        return m_window;
    }

    // The default Qt.ApplicationShortcut context, so a match does not depend on
    // which of the app's windows has focus.
    static QObject *createWindowWithShortcut()
    {
        static QQmlEngine engine;
        QQmlComponent component(&engine);
        component.setData(R"(
import QtQuick

Window {
    id: win

    property int activatedCount: 0
    property bool findEnabled: true
    property int shortcutContext: Qt.ApplicationShortcut

    Shortcut {
        sequences: ["Ctrl+T"]
        context: win.shortcutContext
        onActivated: win.activatedCount++
    }
    Shortcut {
        sequences: [StandardKey.FindNext]
        context: win.shortcutContext
        enabled: win.findEnabled
        onActivated: win.activatedCount++
    }
    Shortcut {
        sequence: "F12"
        context: win.shortcutContext
        onActivated: win.activatedCount++
    }
}
)", QUrl(QStringLiteral("qrc:/ShortcutBridgeTest.qml")));
        if (component.isError())
            qWarning("%s", qPrintable(component.errorString()));
        return component.create();
    }
};

QTEST_MAIN(TestShortcutBridge)
#include "tst_ShortcutBridge.moc"
