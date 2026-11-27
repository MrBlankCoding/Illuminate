#pragma once

#include <QObject>
#include <QPointer>
#include <QQuickWindow>
#include <QString>
#include <QTimer>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>
#include "../utils/ExternalQmlSingleton.h"
#include "MenuItem.h"

class AppMenu : public QObject, public ExternalQmlSingleton<AppMenu>
{
    Q_DISABLE_COPY_MOVE(AppMenu)
    Q_OBJECT
    QML_NAMED_ELEMENT(AppMenu)
    QML_SINGLETON
    Q_PROPERTY(bool native READ isNative CONSTANT)
    Q_PROPERTY(QVariantList tree READ tree NOTIFY treeChanged)

public:
    explicit AppMenu(QObject *parent);
    ~AppMenu() override;

    bool isNative() const;
    QVariantList tree() const;
    const QVector<MenuItem> &items() const;

    Q_INVOKABLE void attach(QQuickWindow *window);
    Q_INVOKABLE void detach(QQuickWindow *window);
    Q_INVOKABLE void refresh();
    Q_INVOKABLE QString shortcutFor(const QString &commandId) const;
    Q_INVOKABLE void trigger(const QString &id, const QString &payload = QString());

signals:
    void actionTriggered(const QString &id, const QString &payload);
    void treeChanged();

private:
    MenuItem applicationMenu() const;
    MenuItem fileMenu() const;
    MenuItem editMenu() const;
    MenuItem viewMenu() const;
    MenuItem historyMenu() const;
    MenuItem bookmarksMenu() const;
    MenuItem spacesMenu() const;
    MenuItem windowMenu() const;

    // The entries that follow their models: bookmarks and spaces.
    QVector<MenuItem> bookmarkEntries() const;
    QVector<MenuItem> spaceEntries() const;

    void scheduleRebuild();
    void rebuild();
    void watchSpaces();
    void onSpaceNameChanged();

    QVector<MenuItem> m_tree;
    QPointer<QQuickWindow> m_window;
    QTimer *m_rebuildTimer = nullptr;
};
