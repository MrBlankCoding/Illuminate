#include "ShortcutRegistry.h"

#include <QKeySequence>
#include <QSettings>

#include <algorithm>

namespace
{
    constexpr char kGroup[] = "shortcuts";
    QString standard(QKeySequence::StandardKey key)
    {
        return QKeySequence(key).toString(QKeySequence::PortableText);
    }

    bool editsText(QKeyCombination combo)
    {
        switch (combo.key())
        {
        case Qt::Key_Backspace:
        case Qt::Key_Delete:
        case Qt::Key_Left:
        case Qt::Key_Right:
        case Qt::Key_Up:
        case Qt::Key_Down:
        case Qt::Key_Home:
        case Qt::Key_End:
            // Alt+Left is Back on Windows and Linux; Cmd+Left is line start on macOS
            return !combo.keyboardModifiers().testFlag(Qt::AltModifier);
        default:
            return combo.keyboardModifiers() == Qt::NoModifier
                && !(combo.key() >= Qt::Key_F1 && combo.key() <= Qt::Key_F35);
        }
    }

    QStringList standards(QKeySequence::StandardKey key)
    {
        QStringList out;
        for (const QKeySequence &sequence : QKeySequence::keyBindings(key))
        {
            if (sequence.isEmpty() || editsText(sequence[0]))
                continue;
            const QString text = sequence.toString(QKeySequence::PortableText);
            if (!out.contains(text))
                out << text;
        }
        // a letter reads better in menus and settings than Ctrl+F4
        std::stable_partition(out.begin(), out.end(), [](const QString &text) {
            const QKeySequence sequence(text);
            const int k = sequence.isEmpty() ? 0 : sequence[0].key();
            return (k >= Qt::Key_A && k <= Qt::Key_Z) || (k >= Qt::Key_0 && k <= Qt::Key_9);
        });
        if (out.isEmpty())
            out << standard(key);
        return out;
    }
}

ShortcutRegistry::ShortcutRegistry(QObject *parent)
    : QObject(parent), m_settings(new QSettings(this))
{
}

const QList<ShortcutRegistry::Command> &ShortcutRegistry::table()
{
    static const QList<Command> commands = buildTable();
    return commands;
}

QList<ShortcutRegistry::Command> ShortcutRegistry::buildTable()
{
    QList<Command> table;

    // every parameter is taken by value and copied into the row: a
    // qPrintable() temporary would be dangling the moment this returns
    const auto add = [&table](QString category, QString id, QString label, QStringList sequences) {
        table.append({std::move(id), std::move(label), std::move(category), std::move(sequences)});
    };

    add("Tabs", "newTab", "New tab", standards(QKeySequence::StandardKey::AddTab));
    add("Tabs", "closeTab", "Close tab", standards(QKeySequence::StandardKey::Close));
#ifdef Q_OS_MACOS
    add("Tabs", "reopenClosedTab", "Reopen closed tab", {QStringLiteral("Meta+Shift+T")});
#else
    add("Tabs", "reopenClosedTab", "Reopen closed tab", {QStringLiteral("Ctrl+Shift+T")});
#endif
    add("Tabs", "nextTab", "Next tab", {QStringLiteral("Ctrl+Down")});
    add("Tabs", "previousTab", "Previous tab", {QStringLiteral("Ctrl+Up")});

    for (int i = 1; i <= 8; ++i)
        add("Tabs",
            QStringLiteral("tab%1").arg(i),
            QStringLiteral("Open tab %1").arg(i),
            {QStringLiteral("Ctrl+%1").arg(i)});

    add("Tabs", "lastTab", "Open last tab", {QStringLiteral("Ctrl+9")});
    add("Tabs", "splitTabs", "Split active tab with next tab", {QStringLiteral("Ctrl+Alt+\\")});

    QStringList reload = standards(QKeySequence::StandardKey::Refresh);
    if (!reload.contains(QStringLiteral("Ctrl+R")))
        reload.prepend(QStringLiteral("Ctrl+R")); // Windows' table has only F5
    add("Navigation", "reload", "Reload", reload);
    add("Navigation", "back", "Go back", standards(QKeySequence::StandardKey::Back));
    add("Navigation", "forward", "Go forward", standards(QKeySequence::StandardKey::Forward));
    add("Navigation", "copyUrl", "Copy current URL", {QStringLiteral("Ctrl+Shift+C")});

    add("Page", "print", "Print", standards(QKeySequence::StandardKey::Print));
    add("Page", "savePdf", "Save as PDF", {QStringLiteral("Ctrl+Shift+S")});
    add("Page", "toggleBookmark", "Bookmark this page", {QStringLiteral("Ctrl+B")});
    add("Page", "downloads", "Show downloads", {QStringLiteral("Ctrl+Shift+J")});

    add("Find", "find", "Find in page", standards(QKeySequence::StandardKey::Find));
    add("Find", "findNext", "Find next", standards(QKeySequence::StandardKey::FindNext));
    add("Find", "findPrevious", "Find previous", standards(QKeySequence::StandardKey::FindPrevious));

    add("View", "zoomIn", "Zoom in", standards(QKeySequence::StandardKey::ZoomIn) + QStringList{QStringLiteral("Ctrl+=")});
    add("View", "zoomOut", "Zoom out", standards(QKeySequence::StandardKey::ZoomOut));
    add("View", "zoomReset", "Reset zoom", {QStringLiteral("Ctrl+0")});
    add("View", "toggleSidebar", "Toggle sidebar", {QStringLiteral("Ctrl+S")});
    add("View", "toggleFullScreen", "Toggle full screen", {QStringLiteral("Ctrl+Shift+F")});
    add("View", "toggleTheme", "Theme picker", {QStringLiteral("Ctrl+Alt+T")});

    add("Spaces", "nextSpace", "Next space", {QStringLiteral("Ctrl+Alt+Right")});
    add("Spaces", "previousSpace", "Previous space", {QStringLiteral("Ctrl+Alt+Left")});
    add("Spaces", "newSpace", "New space", {QStringLiteral("Ctrl+Alt+N")});

    add("Developer",
        "toggleDevTools",
        "Toggle developer tools",
        {QStringLiteral("Ctrl+Shift+I"), QStringLiteral("Ctrl+Alt+I"), QStringLiteral("F12")});

    add("Application", "settings", "Open settings", {QStringLiteral("Ctrl+,")});
    add("Application", "closeWindow", "Close window", {QStringLiteral("Ctrl+Shift+W")});
    add("Application", "quit", "Quit", {QStringLiteral("Ctrl+Q")});

    add("Edit", "cut", "Cut", {standard(QKeySequence::StandardKey::Cut)});
    add("Edit", "copy", "Copy", {standard(QKeySequence::StandardKey::Copy)});
    add("Edit", "paste", "Paste", {standard(QKeySequence::StandardKey::Paste)});
    add("Edit", "pastePlainText", "Paste and Match Style", {QStringLiteral("Ctrl+Shift+V")});
    add("Edit", "selectAll", "Select All", {standard(QKeySequence::StandardKey::SelectAll)});
    add("Edit", "undo", "Undo", {standard(QKeySequence::StandardKey::Undo)});
    add("Edit", "redo", "Redo", {standard(QKeySequence::StandardKey::Redo)});

    return table;
}

const ShortcutRegistry::Command *ShortcutRegistry::find(const QString &commandId)
{
    for (const Command &command : table())
    {
        if (commandId == command.id)
            return &command;
    }
    return nullptr;
}

QString ShortcutRegistry::normalize(const QString &sequence)
{
    if (sequence.isEmpty())
        return {};

    const QKeySequence parsed(sequence);
    if (parsed.isEmpty())
        return {};

    return parsed.toString(QKeySequence::PortableText);
}

QVariantList ShortcutRegistry::commands() const
{
    QVariantList result;
    result.reserve(table().size());

    for (const Command &command : table())
    {
        result.append(QVariantMap{{QStringLiteral("id"), command.id},
                                  {QStringLiteral("label"), command.label},
                                  {QStringLiteral("category"), command.category}});
    }

    return result;
}

QString ShortcutRegistry::labelFor(const QString &commandId) const
{
    const Command *command = find(commandId);
    return command ? command->label : QString();
}

QStringList ShortcutRegistry::sequences(const QString &commandId) const
{
    const Command *command = find(commandId);
    if (!command)
        return {};

    const QString bound = normalize(m_settings->value(QLatin1String(kGroup) + QLatin1Char('/') + command->id).toString());
    if (!bound.isEmpty())
        return {bound};

    return command->defaults;
}

QString ShortcutRegistry::displaySequence(const QString &commandId) const
{
    QStringList rendered;
    for (const QString &sequence : sequences(commandId))
    {
        const QString native = QKeySequence(sequence).toString(QKeySequence::NativeText);
        if (!rendered.contains(native))
            rendered.append(native);
    }
    return rendered.join(QStringLiteral(" or "));
}

bool ShortcutRegistry::isCustomized(const QString &commandId) const
{
    const Command *command = find(commandId);
    if (!command)
        return false;

    return !normalize(m_settings->value(QLatin1String(kGroup) + QLatin1Char('/') + command->id).toString()).isEmpty();
}

bool ShortcutRegistry::hasCustomizations() const
{
    for (const Command &command : table())
    {
        if (isCustomized(command.id))
            return true;
    }
    return false;
}

QVariantMap ShortcutRegistry::bindings() const
{
    QVariantMap result;
    for (const Command &command : table())
        result.insert(command.id, sequences(command.id));
    return result;
}

QString ShortcutRegistry::commandUsing(const QString &sequence, const QString &exceptCommandId) const
{
    const QString wanted = normalize(sequence);
    if (wanted.isEmpty())
        return {};

    for (const Command &command : table())
    {
        if (command.id == exceptCommandId)
            continue;

        if (sequences(command.id).contains(wanted))
            return command.id;
    }

    return {};
}

bool ShortcutRegistry::setSequence(const QString &commandId, const QString &sequence)
{
    const Command *command = find(commandId);
    if (!command)
        return false;

    const QString normalized = normalize(sequence);

    // rebinding to a default is the same as never having changed it
    if (normalized.isEmpty() || command->defaults.contains(normalized))
    {
        reset(commandId);
        return true;
    }

    // two live commands on one key means one of them silently stops working
    if (!commandUsing(normalized, commandId).isEmpty())
        return false;

    m_settings->setValue(QLatin1String(kGroup) + QLatin1Char('/') + commandId, normalized);
    m_settings->sync();
    emit shortcutsChanged();
    return true;
}

void ShortcutRegistry::reset(const QString &commandId)
{
    if (!find(commandId))
        return;

    m_settings->remove(QLatin1String(kGroup) + QLatin1Char('/') + commandId);
    m_settings->sync();
    emit shortcutsChanged();
}

void ShortcutRegistry::resetAll()
{
    if (!hasCustomizations())
        return;

    m_settings->remove(QLatin1String(kGroup));
    m_settings->sync();
    emit shortcutsChanged();
}

QString ShortcutRegistry::sequenceFromKey(int key, int modifierMask)
{
    const auto qtKey = static_cast<Qt::Key>(key);

    // pressing a modifier on its own never makes a bindable combination
    switch (qtKey)
    {
    case Qt::Key_Shift:
    case Qt::Key_Control:
    case Qt::Key_Meta:
    case Qt::Key_Alt:
    case Qt::Key_AltGr:
    case Qt::Key_CapsLock:
    case Qt::Key_NumLock:
    case Qt::Key_ScrollLock:
        return {};
    default:
        break;
    }

    constexpr int kBindable = Qt::ControlModifier | Qt::AltModifier | Qt::ShiftModifier | Qt::MetaModifier;
    const auto modifiers = static_cast<Qt::KeyboardModifiers>(modifierMask & kBindable);

    // a bare key would swallow ordinary typing, so require a modifier
    if (modifiers == Qt::NoModifier)
        return {};

    if (qtKey == Qt::Key_Escape || qtKey == Qt::Key_unknown)
        return {};

    const QKeySequence sequence(QKeyCombination(modifiers, qtKey));
    if (sequence.isEmpty())
        return {};

    return sequence.toString(QKeySequence::PortableText);
}
