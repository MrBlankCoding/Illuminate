#include "Space.h"

#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QUrl>
#include <QUuid>

Space::Space(QObject *parent)
    : QObject(parent)
    , m_id(QUuid::createUuid().toString(QUuid::WithoutBraces))
    , m_name(QStringLiteral("New Space"))
    , m_color(QColor(QStringLiteral("#4A90E2")))
{
}

Space::Space(const QString &id, const QString &name, const QColor &color, QObject *parent)
    : QObject(parent), m_id(id), m_name(name), m_color(color)
{
    if (m_id.isEmpty())
        m_id = QUuid::createUuid().toString(QUuid::WithoutBraces);
}

void Space::setName(const QString &name)
{
    const QString trimmed = name.trimmed();
    if (m_name == trimmed)
        return;
    m_name = trimmed;
    emit nameChanged();
}

void Space::setColor(const QColor &color)
{
    if (!color.isValid() || m_color == color)
        return;
    m_color = color;
    emit colorChanged();
}

void Space::setThemeColor(const QColor &color, bool persist)
{
    const QColor seed = color.isValid() ? color : QColor();
    if (m_themeColor != seed)
    {
        m_themeColor = seed;
        emit themeColorChanged();
    }
    // a preview may already have applied the colour without saving it
    if (persist)
        emit themeChanged();
}

namespace
{
QString s_rootOverride;
}

QString Space::dataDir()
{
    return s_rootOverride.isEmpty()
             ? QDir::homePath() + QDir::separator() + QStringLiteral(".illuminate")
             : s_rootOverride;
}

QString Space::spacesRootDir()
{
    return dataDir() + QDir::separator() + QStringLiteral("spaces");
}

void Space::setSpacesRootDir(const QString &dir)
{
    s_rootOverride = dir;
}

QString Space::storageDirFor(const QString &spaceId)
{
    return spacesRootDir() + QDir::separator() + spaceId;
}

QString Space::sidebarFilePath() const
{
    return m_storageDir + QDir::separator() + QStringLiteral("sidebar.json");
}

QString Space::sessionFilePath() const
{
    return m_storageDir + QDir::separator() + QStringLiteral("session.json");
}

QString Space::lastActiveUrl() const
{
    QFile file(sessionFilePath());
    if (!file.open(QFile::ReadOnly | QFile::Text))
        return {};
    const QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    const QString url = doc.isObject() ? doc.object().value(QStringLiteral("activeUrl")).toString().trimmed() : QString();
    const QUrl parsed(url);
    const QString scheme = parsed.scheme().toLower();
    if (!parsed.isValid() || (scheme != QLatin1String("https") && scheme != QLatin1String("http")
                              && scheme != QLatin1String("file")))
        return {};
    return url;
}

QString Space::bookmarksFilePath() const
{
    return m_storageDir + QDir::separator() + QStringLiteral("bookmarks.json");
}
