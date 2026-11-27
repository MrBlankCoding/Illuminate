#include "SearchSuggestionRequest.h"

#include "../../utils/BrowserLogger.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonParseError>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QSslError>
#include <QUrl>
#include <QUrlQuery>

#include <chrono>

SearchSuggestionRequest::SearchSuggestionRequest(QObject *parent)
    : QObject(parent),
      m_manager(new QNetworkAccessManager(this))
{
}

void SearchSuggestionRequest::fetch(const QString &query)
{
    cancel();
    m_query = query.trimmed();
    if (m_query.isEmpty())
        return;

    QUrl url(QStringLiteral("https://suggestqueries.google.com/complete/search"));
    QUrlQuery parameters;
    parameters.addQueryItem(QStringLiteral("client"), QStringLiteral("firefox"));
    parameters.addQueryItem(QStringLiteral("q"), m_query);
    url.setQuery(parameters);

    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("illuminate"));
    request.setTransferTimeout(std::chrono::seconds(10));
    QNetworkReply *reply = m_manager->get(request);
    m_reply = reply;
    const QString requestedQuery = m_query;
    connect(reply, &QNetworkReply::sslErrors, this, [reply](const QList<QSslError> &errors) {
        BrowserLogger::instance().warning(
            QStringLiteral("SearchSuggestions"),
            QStringLiteral("Suggestion request encountered %1 SSL error(s)").arg(errors.size()));
        reply->abort();
    });
    connect(reply, &QNetworkReply::finished, this, [this, reply, requestedQuery]() {
        if (m_reply != reply) {
            reply->deleteLater();
            return;
        }
        m_reply = nullptr;

        if (reply->error() != QNetworkReply::NoError) {
            BrowserLogger::instance().warning(
                QStringLiteral("SearchSuggestions"),
                QStringLiteral("Suggestion request failed: %1").arg(reply->errorString()));
            reply->deleteLater();
            return;
        }

        QJsonParseError parseError;
        const QJsonDocument response = QJsonDocument::fromJson(reply->readAll(), &parseError);
        reply->deleteLater();
        if (parseError.error != QJsonParseError::NoError || !response.isArray()) {
            BrowserLogger::instance().warning(
                QStringLiteral("SearchSuggestions"),
                QStringLiteral("Suggestion response was invalid JSON"));
            return;
        }

        const QJsonArray payload = response.array();
        if (payload.size() < 2 || !payload.at(1).isArray()) {
            BrowserLogger::instance().warning(
                QStringLiteral("SearchSuggestions"),
                QStringLiteral("Suggestion response had an unexpected format"));
            return;
        }

        QStringList suggestions;
        const QJsonArray values = payload.at(1).toArray();
        for (const QJsonValue &value : values) {
            if (!value.isString())
                continue;
            const QString suggestion = value.toString().trimmed();
            if (!suggestion.isEmpty() && !suggestions.contains(suggestion)) {
                suggestions.append(suggestion);
                if (suggestions.size() == 8)
                    break;
            }
        }
        emit suggestionsReady(requestedQuery, suggestions);
    });
}

void SearchSuggestionRequest::cancel()
{
    m_query.clear();
    if (!m_reply)
        return;
    QNetworkReply *reply = m_reply;
    m_reply = nullptr;
    reply->abort();
}
