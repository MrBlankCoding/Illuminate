#pragma once

#include <QAction>
#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include <QVector>

struct MenuItem
{
    enum class Kind
    {
        Normal,
        Separator,
        SubMenu,
    };

    static MenuItem action(const QString &id, const QString &label, const QString &shortcut = QString());
    static MenuItem separator();
    static MenuItem subMenu(const QString &label, QVector<MenuItem> children = {});

    // empty for a separator
    QString id;
    QString label;
    QString shortcut;
    Kind kind = Kind::Normal;
    bool enabled = true;
    bool checked = false;
    // what the action is about: a bookmark url, a space id, a tab index
    QString payload;
    QAction::MenuRole menuRole = QAction::NoRole;
    QVector<MenuItem> children;

    bool isSeparator() const { return kind == Kind::Separator; }
    bool operator==(const MenuItem &other) const;
    bool operator!=(const MenuItem &other) const { return !(*this == other); }
    QVariantMap toVariantMap() const;
    static QVariantList toVariantList(const QVector<MenuItem> &items);
};
