#pragma once

#include <QObject>
#include <QPointer>
#include <QStringList>
#include <QtQml/qqmlregistration.h>

class QNetworkAccessManager;
class QNetworkReply;

class SearchSuggestionRequest : public QObject
{
    Q_OBJECT
    QML_ELEMENT

public:
    explicit SearchSuggestionRequest(QObject *parent = nullptr);

    Q_INVOKABLE void fetch(const QString &query);
    Q_INVOKABLE void cancel();

signals:
    void suggestionsReady(const QString &query, const QStringList &suggestions);

private:
    QNetworkAccessManager *m_manager;
    QPointer<QNetworkReply> m_reply;
    QString m_query;
};
