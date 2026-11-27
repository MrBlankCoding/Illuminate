#include "InternalPageManager.h"

#include <QJSEngine>

InternalPageManager &InternalPageManager::instance()
{
    static InternalPageManager mgr;
    return mgr;
}

InternalPageManager *InternalPageManager::create(QQmlEngine *, QJSEngine *)
{
    InternalPageManager *mgr = &instance();
    QJSEngine::setObjectOwnership(mgr, QJSEngine::CppOwnership);
    return mgr;
}

bool InternalPageManager::isInternal(const QString &url)
{
    const QString trimmed = url.trimmed();
    return trimmed == QLatin1String("newtab://newtab") ||
           trimmed.startsWith(QLatin1String("illuminate://"), Qt::CaseInsensitive);
}

namespace
{
// "illuminate://crashed?url=…": the page that replaces a tab whose renderer keeps crashing
bool isCrashPage(const QString &lowerUrl)
{
    return lowerUrl == QLatin1String("illuminate://crashed")
           || lowerUrl.startsWith(QLatin1String("illuminate://crashed?"));
}
}

QString InternalPageManager::qmlSource(const QString &url)
{
    const QString t = url.trimmed().toLower();
    if (isCrashPage(t))
        return QStringLiteral("qrc:/illuminate/ui/pages/CrashedPage.qml");
    if (t == QLatin1String("illuminate://setup") || t == QLatin1String("illuminate://setup/"))
        return QStringLiteral("qrc:/illuminate/ui/pages/SetupPage.qml");

    return {};
}

QString InternalPageManager::title(const QString &url)
{
    const QString lc = url.trimmed().toLower();
    if (isCrashPage(lc))
        return QStringLiteral("Page crashed");
    if (lc == QLatin1String("illuminate://setup") || lc == QLatin1String("illuminate://setup/"))
        return QStringLiteral("Setup");
    return {};
}

QString InternalPageManager::iconUrl(const QString &url)
{
    const QString lc = url.trimmed().toLower();
    if (!lc.startsWith(QLatin1String("chrome://")) &&
        !lc.startsWith(QLatin1String("illuminate://")))
        return {};
    return QStringLiteral("qrc:/illuminate/ui/icons/globe.svg");
}
