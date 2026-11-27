#pragma once

#include <QObject>
#include <QString>
#include <QUrl>
#include <QtQml/qqmlregistration.h>

#include "../../utils/ExternalQmlSingleton.h"

class SystemIntegration : public QObject, public ExternalQmlSingleton<SystemIntegration>
{
    Q_OBJECT
    QML_NAMED_ELEMENT(System)
    QML_SINGLETON

    // "Reduce motion" in the system's accessibility settings
    Q_PROPERTY(bool reduceMotion READ reduceMotion NOTIFY reduceMotionChanged)

public:
    explicit SystemIntegration(QObject *parent);
    ~SystemIntegration() override;

    bool reduceMotion() const { return m_reduceMotion; }
    void setCurrentPage(const QUrl &url, const QString &title);

    void setActiveDownloads(int count);
    static QUrl handoffUrl(const QUrl &url);
    static QString dockBadge(int activeDownloads);

signals:
    void reduceMotionChanged();

private:
    void refreshReduceMotion();

    bool m_reduceMotion = false;
    QUrl m_currentPage;
    QString m_currentTitle;
    QString m_badge;
    void *m_activity = nullptr;
    void *m_observer = nullptr;
};
