#include "MenuItem.h"

MenuItem MenuItem::action(const QString &id, const QString &label, const QString &shortcut)
{
    MenuItem item;
    item.id = id;
    item.label = label;
    item.shortcut = shortcut;
    return item;
}

MenuItem MenuItem::separator()
{
    MenuItem item;
    item.kind = Kind::Separator;
    return item;
}

MenuItem MenuItem::subMenu(const QString &label, QVector<MenuItem> children)
{
    MenuItem item;
    item.kind = Kind::SubMenu;
    item.label = label;
    item.children = std::move(children);
    return item;
}

bool MenuItem::operator==(const MenuItem &other) const
{
    return kind == other.kind && id == other.id && label == other.label && shortcut == other.shortcut
           && enabled == other.enabled && checked == other.checked && payload == other.payload
           && menuRole == other.menuRole && children == other.children;
}

QVariantMap MenuItem::toVariantMap() const
{
    QVariantMap map;
    map[QStringLiteral("id")] = id;
    map[QStringLiteral("label")] = label;
    map[QStringLiteral("shortcut")] = shortcut;
    map[QStringLiteral("enabled")] = enabled;
    map[QStringLiteral("checked")] = checked;
    map[QStringLiteral("payload")] = payload;
    map[QStringLiteral("kind")] = QStringLiteral("normal");

    switch (kind)
    {
    case Kind::Separator:
        map[QStringLiteral("kind")] = QStringLiteral("separator");
        break;
    case Kind::SubMenu:
        map[QStringLiteral("kind")] = QStringLiteral("submenu");
        break;
    case Kind::Normal:
        break;
    }

    if (!children.isEmpty())
        map[QStringLiteral("children")] = toVariantList(children);

    return map;
}

QVariantList MenuItem::toVariantList(const QVector<MenuItem> &items)
{
    QVariantList list;
    list.reserve(items.size());
    for (const MenuItem &item : items)
        list.append(item.toVariantMap());
    return list;
}
