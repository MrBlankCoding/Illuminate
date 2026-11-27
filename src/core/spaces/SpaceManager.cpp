#include "SpaceManager.h"
#include "../utils/BrowserLogger.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QHash>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QSaveFile>
#include <QUuid>

#include <algorithm>

namespace
{
QString managerFilePath()
{
    return Space::dataDir() + QDir::separator() + QStringLiteral("spaces.json");
}

QColor colorOrDefault(const QJsonValue &value)
{
    const QColor color(value.toString());
    return color.isValid() ? color : QColor(QStringLiteral("#4A90E2"));
}

// Files written before themes became a single seed carry a full colour set
// per mode; only the accent's hue and vividness carry over. Their palette
// names ("violet", ...) are no longer read: those spaces start on the
// default theme.
QColor themeColorFrom(const QJsonObject &obj)
{
    if (obj.contains(QStringLiteral("themeColor")))
    {
        const QColor seed(obj.value(QStringLiteral("themeColor")).toString());
        return seed.isValid() ? seed : QColor();
    }

    const QColor accent(obj.value(QStringLiteral("themeColors")).toObject()
                            .value(QStringLiteral("light")).toObject()
                            .value(QStringLiteral("accent")).toString());
    if (accent.isValid())
        return QColor::fromHslF(accent.hslHueF(), accent.hslSaturationF(), 0.5f);

    return {};
}
}

SpaceManager::SpaceManager(QObject *parent)
    : QObject(parent)
{
    load();

    if (m_spaces.isEmpty())
    {
        m_spaces.append(adopt(QString(), QStringLiteral("Default"), QColor(QStringLiteral("#4A90E2"))));
        m_activeSpace = m_spaces.first();
        save();
    }
    if (!m_activeSpace)
    {
        m_activeSpace = m_spaces.first();
        save();
    }
}

SpaceManager::~SpaceManager()
{
    qDeleteAll(m_spaces);
}

QVariantList SpaceManager::spaces() const
{
    QVariantList list;
    list.reserve(m_spaces.size());
    for (Space *space : m_spaces)
        list.append(QVariant::fromValue(space));
    return list;
}

Space *SpaceManager::spaceById(const QString &id) const
{
    for (Space *space : m_spaces)
    {
        if (space->id() == id)
            return space;
    }
    return nullptr;
}

QColor SpaceManager::nextSpaceColor() const
{
    static const QList<QColor> palette = {
        QColor(QStringLiteral("#4A90E2")), QColor(QStringLiteral("#2DA7A1")),
        QColor(QStringLiteral("#F3A43B")), QColor(QStringLiteral("#E86F67")),
        QColor(QStringLiteral("#8A6CFF")), QColor(QStringLiteral("#69B578")),
        QColor(QStringLiteral("#D96ACF"))};

    for (const QColor &color : palette)
    {
        const bool used = std::any_of(m_spaces.cbegin(), m_spaces.cend(), [&color](const Space *space) {
            return space->color() == color;
        });
        if (!used)
            return color;
    }
    return palette.at(m_spaces.size() % palette.size());
}

void SpaceManager::setActiveSpace(Space *space)
{
    if (!space || space == m_activeSpace)
        return;
    if (!m_spaces.contains(space))
        return;

    m_activeSpace = space;
    save();
    emit activeSpaceChanged();
}

Space *SpaceManager::createSpace(const QString &name, const QColor &color)
{
    if (m_spaces.size() >= kMaxSpaces)
    {
        BrowserLogger::instance().warning("SpaceManager", "Space limit reached; not creating another.");
        return nullptr;
    }

    const QColor selectedColor = color.isValid() ? color : nextSpaceColor();
    Space *space = adopt(QString(), name.isEmpty() ? QStringLiteral("New Space") : name, selectedColor);
    m_spaces.append(space);
    save();
    emit spacesChanged();

    if (m_spaces.size() == 1)
        setActiveSpace(space);
    return space;
}

void SpaceManager::deleteSpace(Space *space)
{
    if (!space || !m_spaces.contains(space))
        return;

    if (m_spaces.size() == 1)
    {
        BrowserLogger::instance().warning("SpaceManager", "Cannot delete the last space.");
        return;
    }

    const qsizetype index = m_spaces.indexOf(space);
    m_spaces.removeOne(space);
    const bool wasActive = m_activeSpace == space;
    if (wasActive)
        setActiveSpace(m_spaces.at((std::min)(index, m_spaces.size() - 1)));

    // its folders, tabs and bookmarks go with it; nothing shared is in here
    const QString spacesRoot = QFileInfo(Space::spacesRootDir()).canonicalFilePath();
    const QString storagePath = QFileInfo(space->storageDir()).canonicalFilePath();
    if (!spacesRoot.isEmpty() && !storagePath.isEmpty()
        && storagePath.startsWith(spacesRoot + QDir::separator()))
        QDir(storagePath).removeRecursively();
    space->deleteLater();
    emit spacesChanged();
    save();
}

void SpaceManager::cycleSpace(int delta)
{
    if (m_spaces.size() < 2 || delta == 0)
        return;

    const int start = m_spaces.indexOf(m_activeSpace);
    const int count = m_spaces.size();
    const int next = ((start + delta) % count + count) % count;
    setActiveSpace(m_spaces.at(next));
}


Space *SpaceManager::adopt(const QString &id, const QString &name, const QColor &color)
{
    auto *space = new Space(id, name, color, this);
    space->setStorageDir(Space::storageDirFor(space->id()));
    QDir().mkpath(space->storageDir());
    connectSpace(space);
    return space;
}

void SpaceManager::connectSpace(Space *space)
{
    connect(space, &Space::nameChanged, this, [this]() { if (!m_loading) { save(); emit spacesChanged(); } });
    connect(space, &Space::colorChanged, this, [this]() { if (!m_loading) { save(); emit spacesChanged(); } });
    connect(space, &Space::themeChanged, this, [this]() { if (!m_loading) save(); });
}

void SpaceManager::load()
{
    m_loading = true;
    QFile file(managerFilePath());
    if (!file.open(QIODevice::ReadOnly))
    {
        BrowserLogger::instance().info("SpaceManager", "No spaces.json found; starting with one space.");
        m_loading = false;
        return;
    }

    const QByteArray data = file.readAll();
    file.close();

    QJsonParseError parseError;
    const QJsonDocument doc = QJsonDocument::fromJson(data, &parseError);
    if (parseError.error != QJsonParseError::NoError || !doc.isObject())
    {
        m_loading = false;
        BrowserLogger::instance().error("SpaceManager", "Invalid spaces.json; ignoring its contents.");
        return;
    }
    const QJsonObject root = doc.object();
    const QJsonArray array = root.value(QStringLiteral("spaces")).toArray();
    const QString activeId = root.value(QStringLiteral("activeSpaceId")).toString();

    for (const QJsonValue &value : array)
    {
        const QJsonObject obj = value.toObject();
        const QString id = obj.value(QStringLiteral("id")).toString();
        if (QUuid::fromString(id).isNull())
        {
            BrowserLogger::instance().warning("SpaceManager", "Skipping a space with an invalid ID.");
            continue;
        }
        Space *space = adopt(id,
                             obj.value(QStringLiteral("name")).toString(),
                             colorOrDefault(obj.value(QStringLiteral("color"))));
        space->setThemeColor(themeColorFrom(obj));
        m_spaces.append(space);
        if (space->id() == activeId)
            m_activeSpace = space;
    }
    m_loading = false;
    BrowserLogger::instance().info("SpaceManager", QString("Loaded %1 spaces.").arg(m_spaces.size()));
}

void SpaceManager::save() const
{
    QJsonArray array;
    for (const Space *space : m_spaces)
    {
        QJsonObject obj;
        obj[QStringLiteral("id")] = space->id();
        obj[QStringLiteral("name")] = space->name();
        obj[QStringLiteral("color")] = space->color().name();
        if (space->themeColor().isValid())
            obj[QStringLiteral("themeColor")] = space->themeColor().name();
        array.append(obj);
    }

    QJsonObject root;
    root[QStringLiteral("version")] = 1;
    root[QStringLiteral("activeSpaceId")] = m_activeSpace ? m_activeSpace->id() : QString();
    root[QStringLiteral("spaces")] = array;

    const QString path = managerFilePath();
    QDir().mkpath(QFileInfo(path).absolutePath());

    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly))
    {
        BrowserLogger::instance().error("SpaceManager", "Couldn't open spaces.json for writing.");
        return;
    }
    file.write(QJsonDocument(root).toJson());
    if (!file.commit())
        BrowserLogger::instance().error("SpaceManager", "Couldn't write spaces.json.");
}
