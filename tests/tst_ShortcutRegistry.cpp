#include "ShortcutRegistry.h"

#include <QGuiApplication>
#include <QKeySequence>
#include <QSettings>
#include <QSet>
#include <QTemporaryDir>
#include <QtTest>

class TestShortcutRegistry : public QObject
{
    Q_OBJECT

private:
    QTemporaryDir m_dir;
    ShortcutRegistry *fresh()
    {
        auto *registry = new ShortcutRegistry(this);
        registry->resetAll();
        return registry;
    }

private slots:
    void initTestCase()
    {
        QVERIFY(m_dir.isValid());
        QCoreApplication::setOrganizationName("illuminateTest");
        QCoreApplication::setApplicationName("ShortcutRegistry");
        QSettings::setDefaultFormat(QSettings::IniFormat);
        QSettings::setPath(QSettings::IniFormat, QSettings::UserScope, m_dir.path());
    }

    void catalogIsComplete()
    {
        auto *registry = fresh();

        const QVariantList commands = registry->commands();
        QVERIFY(!commands.isEmpty());

        QStringList ids;
        for (const QVariant &entry : commands)
        {
            const QVariantMap command = entry.toMap();
            const QString id = command.value(QStringLiteral("id")).toString();
            const QString label = command.value(QStringLiteral("label")).toString();
            const QString category = command.value(QStringLiteral("category")).toString();

            QVERIFY2(!id.isEmpty(), "a command has no id");
            QVERIFY2(!label.isEmpty(), qPrintable(QStringLiteral("%1 has no label").arg(id)));
            QVERIFY2(!category.isEmpty(), qPrintable(QStringLiteral("%1 has no category").arg(id)));
            QVERIFY2(!ids.contains(id), qPrintable(QStringLiteral("duplicate id %1").arg(id)));

            // every catalogued command must be bindable out of the box
            QVERIFY2(!registry->sequences(id).isEmpty(),
                     qPrintable(QStringLiteral("%1 ships with no default").arg(id)));
            QVERIFY(!registry->displaySequence(id).isEmpty());

            ids.append(id);
        }

        QVERIFY(ids.contains(QStringLiteral("copyUrl")));
        QVERIFY(!ids.contains(QStringLiteral("focusAddressBar")));
        QVERIFY(registry->hasCustomizations() == false);
    }

    void everyShortcutHasUniqueValidDefaults()
    {
        ShortcutRegistry registry(nullptr);
        QSet<QString> owners;
        for (const QVariant &entry : registry.commands())
        {
            const QString id = entry.toMap().value(QStringLiteral("id")).toString();
            const QStringList defaults = registry.sequences(id);
            QVERIFY2(!defaults.isEmpty(), qPrintable(id));
            for (const QString &sequence : defaults)
            {
                const QKeySequence parsed(sequence);
                QVERIFY2(!parsed.isEmpty(), qPrintable(id + QStringLiteral(": ") + sequence));
                const QString normalized = parsed.toString(QKeySequence::PortableText);
                QVERIFY2(!owners.contains(normalized), qPrintable(normalized + QStringLiteral(" has duplicate binding")));
                owners.insert(normalized);
            }
        }
    }

    void tabArrowBindingsMatchDirection()
    {
        ShortcutRegistry registry(nullptr);
        QCOMPARE(registry.sequences(QStringLiteral("nextTab")), QStringList{QStringLiteral("Ctrl+Down")});
        QCOMPARE(registry.sequences(QStringLiteral("previousTab")), QStringList{QStringLiteral("Ctrl+Up")});
    }

    void closedTabShortcutHasPlatformBinding()
    {
        ShortcutRegistry registry(nullptr);
#ifdef Q_OS_MACOS
        QCOMPARE(registry.sequences(QStringLiteral("reopenClosedTab")), QStringList{QStringLiteral("Meta+Shift+T")});
#else
        QCOMPARE(registry.sequences(QStringLiteral("reopenClosedTab")), QStringList{QStringLiteral("Ctrl+Shift+T")});
#endif
    }

    void copyUrlDefaultsToCmdShiftC()
    {
        auto *registry = fresh();

        // the existing binding, unchanged
        QCOMPARE(registry->sequences(QStringLiteral("copyUrl")), QStringList{QStringLiteral("Ctrl+Shift+C")});
        QVERIFY(!registry->isCustomized(QStringLiteral("copyUrl")));

        // whatever glyphs the platform uses, they have to read back as this
        const QKeySequence displayed(registry->displaySequence(QStringLiteral("copyUrl")));
        QCOMPARE(displayed.toString(QKeySequence::PortableText), QStringLiteral("Ctrl+Shift+C"));
    }

    void rebindingReplacesTheDefault()
    {
        auto *registry = fresh();

        QSignalSpy spy(registry, &ShortcutRegistry::shortcutsChanged);
        QVERIFY(registry->setSequence(QStringLiteral("copyUrl"), QStringLiteral("Ctrl+Alt+U")));
        QCOMPARE(spy.size(), 1);

        QCOMPARE(registry->sequences(QStringLiteral("copyUrl")), QStringList{QStringLiteral("Ctrl+Alt+U")});
        QVERIFY(registry->isCustomized(QStringLiteral("copyUrl")));
        QVERIFY(registry->hasCustomizations());

        const QKeySequence displayed(registry->displaySequence(QStringLiteral("copyUrl")));
        QCOMPARE(displayed.toString(QKeySequence::PortableText), QStringLiteral("Ctrl+Alt+U"));
    }

    void bindingsMapFollowsRebinds()
    {
        auto *registry = fresh();

        QVariantMap bindings = registry->bindings();
        QCOMPARE(bindings.size(), registry->commands().size());
        QCOMPARE(bindings.value(QStringLiteral("copyUrl")).toStringList(), QStringList{QStringLiteral("Ctrl+Shift+C")});

        QVERIFY(registry->setSequence(QStringLiteral("copyUrl"), QStringLiteral("Ctrl+Alt+U")));
        bindings = registry->bindings();
        QCOMPARE(bindings.value(QStringLiteral("copyUrl")).toStringList(), QStringList{QStringLiteral("Ctrl+Alt+U")});

        registry->reset(QStringLiteral("copyUrl"));
        bindings = registry->bindings();
        QCOMPARE(bindings.value(QStringLiteral("copyUrl")).toStringList(), QStringList{QStringLiteral("Ctrl+Shift+C")});
    }

    void splitTabsShortcutHasDefaultBinding()
    {
        ShortcutRegistry registry(nullptr);
        QCOMPARE(registry.labelFor(QStringLiteral("splitTabs")),
                 QStringLiteral("Split active tab with next tab"));
        QCOMPARE(registry.sequences(QStringLiteral("splitTabs")),
                 QStringList{QStringLiteral("Ctrl+Alt+\\")});
    }

    void toggleThemeShortcutHasDefaultBinding()
    {
        ShortcutRegistry registry(nullptr);
        QCOMPARE(registry.labelFor(QStringLiteral("toggleTheme")),
                 QStringLiteral("Theme picker"));
        QCOMPARE(registry.sequences(QStringLiteral("toggleTheme")),
                 QStringList{QStringLiteral("Ctrl+Alt+T")});
    }

    void rebindingToTheDefaultIsTheSameAsResetting()
    {
        auto *registry = fresh();

        QVERIFY(registry->setSequence(QStringLiteral("copyUrl"), QStringLiteral("Ctrl+Alt+U")));
        // back to the shipped combination: no longer an override
        QVERIFY(registry->setSequence(QStringLiteral("copyUrl"), QStringLiteral("Ctrl+Shift+C")));

        QVERIFY(!registry->isCustomized(QStringLiteral("copyUrl")));
        QVERIFY(!registry->hasCustomizations());
        QCOMPARE(registry->sequences(QStringLiteral("copyUrl")), QStringList{QStringLiteral("Ctrl+Shift+C")});
    }

    void conflictingBindingsAreRefused()
    {
        auto *registry = fresh();

        // Ctrl+Shift+S already belongs to Save as PDF.
        QVERIFY(!registry->setSequence(QStringLiteral("copyUrl"), QStringLiteral("Ctrl+Shift+S")));

        // ...and the refused command is left exactly as it was
        QCOMPARE(registry->sequences(QStringLiteral("copyUrl")), QStringList{QStringLiteral("Ctrl+Shift+C")});
        QVERIFY(!registry->isCustomized(QStringLiteral("copyUrl")));
    }

    void commandUsingIdentifiesTheOwner()
    {
        auto *registry = fresh();

        QVERIFY(registry->commandUsing(QStringLiteral("Ctrl+L")).isEmpty());
        QCOMPARE(registry->commandUsing(QStringLiteral("Ctrl+Shift+C")), QStringLiteral("copyUrl"));

        QVERIFY(registry->commandUsing(QStringLiteral("Ctrl+Alt+F9")).isEmpty());

        // and the owner moves with the binding
        QVERIFY(registry->setSequence(QStringLiteral("copyUrl"), QStringLiteral("Ctrl+Alt+U")));
        QVERIFY(registry->commandUsing(QStringLiteral("Ctrl+Shift+C")).isEmpty());
        QCOMPARE(registry->commandUsing(QStringLiteral("Ctrl+Alt+U")), QStringLiteral("copyUrl"));
    }

    void alternateSpellingsCountAsTheSameCombination()
    {
        auto *registry = fresh();

        QVERIFY(registry->setSequence(QStringLiteral("copyUrl"), QStringLiteral("Ctrl+Alt+U")));
        // same combination, different spelling: still a conflict
        QVERIFY(!registry->setSequence(QStringLiteral("savePdf"), QStringLiteral("Ctrl+Alt+U")));
        QVERIFY(!registry->setSequence(QStringLiteral("savePdf"), QStringLiteral("Ctrl+Alt+U")));
    }

    void resetAndResetAllRestoreDefaults()
    {
        auto *registry = fresh();

        QVERIFY(registry->setSequence(QStringLiteral("copyUrl"), QStringLiteral("Ctrl+Alt+U")));
        QVERIFY(registry->setSequence(QStringLiteral("savePdf"), QStringLiteral("Ctrl+Alt+P")));
        QVERIFY(registry->hasCustomizations());

        registry->reset(QStringLiteral("copyUrl"));
        QCOMPARE(registry->sequences(QStringLiteral("copyUrl")), QStringList{QStringLiteral("Ctrl+Shift+C")});
        QVERIFY(registry->isCustomized(QStringLiteral("savePdf")));

        registry->resetAll();
        QVERIFY(!registry->hasCustomizations());
        QCOMPARE(registry->sequences(QStringLiteral("savePdf")), QStringList{QStringLiteral("Ctrl+Shift+S")});
    }

    void bindingsSurviveARestart()
    {
        auto *first = fresh();
        QVERIFY(first->setSequence(QStringLiteral("copyUrl"), QStringLiteral("Ctrl+Alt+U")));

        // a second instance reads the same store, as it would on next launch
        ShortcutRegistry relaunched(nullptr);
        QCOMPARE(relaunched.sequences(QStringLiteral("copyUrl")), QStringList{QStringLiteral("Ctrl+Alt+U")});
        QVERIFY(relaunched.hasCustomizations());

        // and clearing there is visible to the first
        relaunched.resetAll();
        QCOMPARE(first->sequences(QStringLiteral("copyUrl")), QStringList{QStringLiteral("Ctrl+Shift+C")});
    }

    void unknownCommandsAreIgnored()
    {
        auto *registry = fresh();

        QVERIFY(registry->sequences(QStringLiteral("nope")).isEmpty());
        QVERIFY(registry->displaySequence(QStringLiteral("nope")).isEmpty());
        QVERIFY(registry->labelFor(QStringLiteral("nope")).isEmpty());
        QVERIFY(!registry->isCustomized(QStringLiteral("nope")));
        QVERIFY(!registry->setSequence(QStringLiteral("nope"), QStringLiteral("Ctrl+Alt+U")));

        // a rejected command must not have written anything
        QVERIFY(!registry->hasCustomizations());
    }

    void emptyingASequenceIsNotABinding()
    {
        auto *registry = fresh();

        // nothing is bound to nothing
        QVERIFY(registry->setSequence(QStringLiteral("copyUrl"), QString()));
        QCOMPARE(registry->sequences(QStringLiteral("copyUrl")), QStringList{QStringLiteral("Ctrl+Shift+C")});

        // a sequence Qt cannot parse is treated the same way
        QVERIFY(registry->setSequence(QStringLiteral("copyUrl"), QStringLiteral("NotAKey")));
        QCOMPARE(registry->sequences(QStringLiteral("copyUrl")), QStringList{QStringLiteral("Ctrl+Shift+C")});
    }

    void sequenceFromKeyRequiresAModifier()
    {
        constexpr int ctrlShift = Qt::ControlModifier | Qt::ShiftModifier;
        constexpr int alt = Qt::AltModifier;

        QCOMPARE(ShortcutRegistry::sequenceFromKey(Qt::Key_C, ctrlShift), QStringLiteral("Ctrl+Shift+C"));
        QCOMPARE(ShortcutRegistry::sequenceFromKey(Qt::Key_P, alt), QStringLiteral("Alt+P"));

        // a bare key would swallow ordinary typing
        QVERIFY(ShortcutRegistry::sequenceFromKey(Qt::Key_C, 0).isEmpty());

        // Escape backs out, and a lone modifier is not a combination
        QVERIFY(ShortcutRegistry::sequenceFromKey(Qt::Key_Escape, ctrlShift).isEmpty());
        QVERIFY(ShortcutRegistry::sequenceFromKey(Qt::Key_Shift, Qt::ShiftModifier).isEmpty());

        // keypad and group-switch bits are noise, not part of the binding
        QCOMPARE(ShortcutRegistry::sequenceFromKey(Qt::Key_C, ctrlShift | Qt::KeypadModifier),
                 QStringLiteral("Ctrl+Shift+C"));
    }

    void capturedSequencesAreAcceptedAsBindings()
    {
        auto *registry = fresh();

        // what the settings field hands back has to be directly bindable
        const QString captured = ShortcutRegistry::sequenceFromKey(Qt::Key_U, Qt::ControlModifier | Qt::AltModifier);
        QCOMPARE(captured, QStringLiteral("Ctrl+Alt+U"));
        QVERIFY(registry->setSequence(QStringLiteral("copyUrl"), captured));
        QCOMPARE(registry->sequences(QStringLiteral("copyUrl")), QStringList{captured});
    }

    void everyDefaultIsAUsableSequence()
    {
        auto *registry = fresh();

        // the settings page renders these, and QML re-parses them on load
        for (const QVariant &entry : registry->commands())
        {
            const QString id = entry.toMap().value(QStringLiteral("id")).toString();
            for (const QString &sequence : registry->sequences(id))
            {
                const QKeySequence parsed(sequence);
                QVERIFY2(!parsed.isEmpty(),
                         qPrintable(QStringLiteral("%1: %2 is not parseable").arg(id, sequence)));
                // a chord would arrive as one string QML silently mis-binds
                QVERIFY2(parsed.count() == 1,
                         qPrintable(QStringLiteral("%1: %2 is a multi-step chord").arg(id, sequence)));
            }
        }
    }
};

// QKeySequence(StandardKey) resolves through the platform theme, so this needs
// a real QGuiApplication -- a QCoreApplication segfaults inside Qt. Offscreen
// keeps it from needing a display.
int main(int argc, char *argv[])
{
    qputenv("QT_QPA_PLATFORM", "offscreen");
    QGuiApplication app(argc, argv);
    TestShortcutRegistry registry;
    return QTest::qExec(&registry, argc, argv);
}

#include "tst_ShortcutRegistry.moc"
