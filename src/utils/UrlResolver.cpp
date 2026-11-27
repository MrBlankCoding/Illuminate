#include "UrlResolver.h"
#include <QRegularExpression>

namespace UrlResolver
{

    const QString kFallbackSearchTemplate = QStringLiteral("https://duckduckgo.com/?q=%s");

    static bool isIPv4(const QString &s)
    {
        static const QRegularExpression re(R"(^\d{1,3}(\.\d{1,3}){3}(:\d+)?(/.*)?$)");
        return re.match(s).hasMatch();
    }

    static bool isLocalhost(const QString &s)
    {
        static const QRegularExpression re(
            R"(^localhost(:\d+)?(/.*)?$)", QRegularExpression::CaseInsensitiveOption);
        return re.match(s).hasMatch();
    }

    bool looksLikeHost(const QString &trimmed)
    {
        if (isLocalhost(trimmed) || isIPv4(trimmed))
            return true;
        if (trimmed.contains(' ') || !trimmed.contains('.'))
            return false;
        const int dot = trimmed.indexOf('.');
        return dot > 0 && dot < trimmed.size() - 1;
    }

    QUrl resolve(const QString &input, const QString &searchTemplate)
    {
        const QString t = input.trimmed();
        if (t.isEmpty())
            return {};

        if (t.contains("://"))
        {
            const QUrl url = QUrl::fromUserInput(t);
            const QString scheme = url.scheme().toLower();
            const QString host = url.host().toLower();
            if (scheme == QLatin1String("chrome")
                && (host == QLatin1String("newtab") || host == QLatin1String("new-tab-page")))
            {
                return QUrl(QStringLiteral("newtab://newtab"));
            }
            return url;
        }
        if (looksLikeHost(t))
            return QUrl::fromUserInput("https://" + t);
        return searchUrl(t, searchTemplate);
    }

    QUrl searchUrl(const QString &query, const QString &searchTemplate)
    {
        // a template without the placeholder would drop the query entirely
        const QString tmpl = searchTemplate.contains(QLatin1String("%s"))
                                 ? searchTemplate
                                 : kFallbackSearchTemplate;
        QString escaped = tmpl;
        escaped.replace(QLatin1String("%s"),
                        QString::fromUtf8(QUrl::toPercentEncoding(query)));
        return QUrl(escaped);
    }

} // namespace UrlResolver
