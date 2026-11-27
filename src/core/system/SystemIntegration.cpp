#include "SystemIntegration.h"

QUrl SystemIntegration::handoffUrl(const QUrl &url)
{
    if (!url.isValid() || url.host().isEmpty())
        return {};
    const QString scheme = url.scheme().toLower();
    if (scheme != QLatin1String("http") && scheme != QLatin1String("https"))
        return {};

    QUrl clean = url;
    clean.setUserInfo(QString());
    return clean;
}

QString SystemIntegration::dockBadge(int activeDownloads)
{
    if (activeDownloads <= 0)
        return {};
    return activeDownloads > 99 ? QStringLiteral("99+") : QString::number(activeDownloads);
}

#ifndef Q_OS_MACOS
SystemIntegration::SystemIntegration(QObject *parent)
    : QObject(parent)
{
}

SystemIntegration::~SystemIntegration() = default;

void SystemIntegration::setCurrentPage(const QUrl &url, const QString &title)
{
    m_currentPage = handoffUrl(url);
    m_currentTitle = title;
}

void SystemIntegration::setActiveDownloads(int count)
{
    m_badge = dockBadge(count);
}

void SystemIntegration::refreshReduceMotion() {}
#endif
