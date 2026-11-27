#pragma once

#include <QObject>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>
#include "../utils/ExternalQmlSingleton.h"

class QSettings;
class ShortcutRegistry : public QObject, public ExternalQmlSingleton<ShortcutRegistry>
{
    Q_DISABLE_COPY_MOVE(ShortcutRegistry)
    Q_OBJECT
    QML_NAMED_ELEMENT(Shortcuts)
    QML_SINGLETON

    Q_PROPERTY(QVariantList commands READ commands CONSTANT)
    Q_PROPERTY(bool hasCustomizations READ hasCustomizations NOTIFY shortcutsChanged)
    Q_PROPERTY(QVariantMap bindings READ bindings NOTIFY shortcutsChanged)

public:
    explicit ShortcutRegistry(QObject *parent);

    // [{id, label, category}]
    QVariantList commands() const;
    Q_INVOKABLE QString labelFor(const QString &commandId) const;
    Q_INVOKABLE QStringList sequences(const QString &commandId) const;
    Q_INVOKABLE QString displaySequence(const QString &commandId) const;

    Q_INVOKABLE bool isCustomized(const QString &commandId) const;
    bool hasCustomizations() const;
    QVariantMap bindings() const;

    Q_INVOKABLE bool setSequence(const QString &commandId, const QString &sequence);
    Q_INVOKABLE void reset(const QString &commandId);
    Q_INVOKABLE void resetAll();
    Q_INVOKABLE QString commandUsing(const QString &sequence, const QString &exceptCommandId = QString()) const;
    Q_INVOKABLE static QString sequenceFromKey(int key, int modifierMask);

signals:
    void shortcutsChanged();

private:
    struct Command
    {
        QString id;
        QString label;
        QString category;
        QStringList defaults;
    };

    static const QList<Command> &table();
    static QList<Command> buildTable();
    static const Command *find(const QString &commandId);
    static QString normalize(const QString &sequence);

    QSettings *m_settings = nullptr;
};
