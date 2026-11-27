#include "BrowserController.h"
#include "BrowserSettings.h"
#include "BrowserTab.h"
#include "CefManager.h"
#include "../utils/BrowserLogger.h"
#include "../utils/UrlResolver.h"

#include <QGuiApplication>
#include <QClipboard>
#include <QColor>
#include <QSettings>
#include <QDir>
#include <QFile>
#include <QJSEngine>
#include <QMetaObject>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QVector>
#include <QStringList>
#include <QUuid>
#include <algorithm>

#include <utility>


QString BrowserController::themeMode() const
{
    if (!m_settings)
        return QStringLiteral("system");
    return m_settings->value(QStringLiteral("themeMode"), QStringLiteral("system")).toString();
}

void BrowserController::setThemeMode(const QString &mode)
{
    if (!m_settings || (mode != QLatin1String("system") &&
                        mode != QLatin1String("dark") &&
                        mode != QLatin1String("light")))
        return;
    if (m_settings->value(QStringLiteral("themeMode"), QStringLiteral("system")).toString() != mode)
    {
        m_settings->setValue(QStringLiteral("themeMode"), mode);
        emit themeModeChanged();
    }
}

QColor BrowserController::themeColor() const
{
    return m_space ? m_space->themeColor() : QColor();
}

void BrowserController::setThemeColor(const QColor &color)
{
    if (!m_space || !color.isValid())
        return;
    const bool changed = m_space->themeColor() != color;
    m_space->setThemeColor(color);
    if (changed)
        emit themeColorChanged();
}

void BrowserController::previewThemeColor(const QColor &color)
{
    if (!m_space || !color.isValid() || m_space->themeColor() == color)
        return;
    m_space->setThemeColor(color, false);
    emit themeColorChanged();
}

void BrowserController::resetThemeColor()
{
    if (!m_space)
        return;
    const bool changed = m_space->themeColor().isValid();
    m_space->setThemeColor(QColor());
    if (changed)
        emit themeColorChanged();
}

// session persistence (per-profile)

