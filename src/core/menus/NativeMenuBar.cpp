#include "NativeMenuBar.h"

#include "AppMenu.h"
#include "MenuItem.h"

#include <QAction>
#include <QKeySequence>
#include <QList>
#include <QMenu>
#include <QMenuBar>
#include <QQuickWindow>

namespace
{
    QMenuBar *s_bar = nullptr;
    QList<QMenu *> s_menus;
    AppMenu *s_owner = nullptr;
    QVector<MenuItem> s_nodes;

    void populateMenu(QMenu *menu, const MenuItem &node, AppMenu *owner)
    {
        menu->clear();
        menu->setTitle(node.label);

        for (const MenuItem &entry : node.children)
        {
            if (entry.isSeparator())
            {
                menu->addSeparator();
                continue;
            }

            QAction *action = menu->addAction(entry.label);
            action->setEnabled(entry.enabled);
            action->setCheckable(entry.checked);
            action->setChecked(entry.checked);
            if (!entry.shortcut.isEmpty())
                action->setShortcut(QKeySequence(entry.shortcut));
            action->setShortcutContext(Qt::WindowShortcut);
            action->setMenuRole(entry.menuRole);

            const QString id = entry.id;
            const QString payload = entry.payload;
            QObject::connect(action, &QAction::triggered, menu, [owner, id, payload]() {
                owner->trigger(id, payload);
            });
        }
    }

    QMenu *buildMenu(const MenuItem &node, AppMenu *owner)
    {
        auto *menu = new QMenu(node.label);
        populateMenu(menu, node, owner);
        return menu;
    }

    void rebuild()
    {
        if (!s_bar || !s_owner)
            return;

        const QVector<MenuItem> &items = s_owner->items();
        if (items.size() == s_nodes.size() && items.size() == s_menus.size())
        {
            for (qsizetype i = 0; i < items.size(); ++i)
            {
                if (items.at(i) == s_nodes.at(i))
                    continue;

                populateMenu(s_menus.at(i), items.at(i), s_owner);
            }
            s_nodes = items;
            return;
        }

        s_bar->clear();
        qDeleteAll(s_menus);
        s_menus.clear();

        for (const MenuItem &node : s_owner->items())
        {
            QMenu *menu = buildMenu(node, s_owner);
            s_menus.append(menu);
            s_bar->addMenu(menu);
        }
        s_nodes = items;
    }
}

namespace NativeMenuBar
{
    bool isNative()
    {
#if defined(Q_OS_MACOS)
        return true;
#else
        return false;
#endif
    }

    void attach(QQuickWindow *window, AppMenu *menu)
    {
        Q_UNUSED(window)

#if !defined(Q_OS_MACOS)
        Q_UNUSED(menu)
#else
        if (!menu)
            return;

        detach(nullptr);

        // QTTT
        s_owner = menu;
        s_bar = new QMenuBar;
        s_bar->setNativeMenuBar(true);
        rebuild();
#endif
    }

    void detach(QQuickWindow *window)
    {
        Q_UNUSED(window)

#if defined(Q_OS_MACOS)
        if (!s_bar)
            return;

        s_bar->clear();
        qDeleteAll(s_menus);
        s_menus.clear();
        s_nodes.clear();

        // deleting the last menu bar is what takes the bar off the screen
        delete s_bar;

        s_bar = nullptr;
        s_owner = nullptr;
#endif
    }

    void refresh(AppMenu *menu)
    {
        Q_UNUSED(menu)

#if defined(Q_OS_MACOS)
        rebuild();
#endif
    }
}
