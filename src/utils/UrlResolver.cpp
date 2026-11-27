#include "UrlResolver.h"
#include <QDir>
#include <QFileInfo>
#include <QRegularExpression>
#include <QStringList>

namespace UrlResolver
{

    const QString kFallbackSearchTemplate = QStringLiteral("https://duckduckgo.com/?q=%s");

    static bool isIPv4(const QString &s)
    {
        static const QRegularExpression re(R"(^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})(:\d+)?(/.*)?$)");
        const QRegularExpressionMatch m = re.match(s);
        if (!m.hasMatch())
            return false;
        for (int i = 1; i <= 4; ++i)
            if (m.captured(i).toInt() > 255)
                return false;
        return true;
    }

    static bool isBracketedIPv6(const QString &s)
    {
        static const QRegularExpression re(R"(^\[[0-9a-fA-F:.]+\](:\d+)?(/.*)?$)");
        return re.match(s).hasMatch();
    }

    static bool isLocalhost(const QString &s)
    {
        static const QRegularExpression re(
            R"(^localhost(:\d+)?(/.*)?$)", QRegularExpression::CaseInsensitiveOption);
        return re.match(s).hasMatch();
    }

    // "3.14", "1.2.3": numbers, not hosts
    static bool isPlainNumber(const QString &s)
    {
        static const QRegularExpression re(R"(^[\d.]+$)");
        return re.match(s).hasMatch();
    }

    static bool endsInFileExtension(const QString &host)
    {
        static const QStringList extensions = {
            QStringLiteral("js"), QStringLiteral("jsx"), QStringLiteral("ts"), QStringLiteral("tsx"),
            QStringLiteral("mjs"), QStringLiteral("cjs"), QStringLiteral("json"), QStringLiteral("txt"),
            QStringLiteral("cpp"), QStringLiteral("hpp"), QStringLiteral("cc"), QStringLiteral("h"),
            QStringLiteral("java"), QStringLiteral("kt"), QStringLiteral("swift"), QStringLiteral("html"),
            QStringLiteral("htm"), QStringLiteral("css"), QStringLiteral("scss"), QStringLiteral("exe"),
            QStringLiteral("dmg"), QStringLiteral("pdf"), QStringLiteral("png"), QStringLiteral("jpg"),
            QStringLiteral("jpeg"), QStringLiteral("gif"), QStringLiteral("svg"), QStringLiteral("yml"),
            QStringLiteral("yaml"), QStringLiteral("toml"), QStringLiteral("lock"), QStringLiteral("log"),
            QStringLiteral("csv"), QStringLiteral("qml"), QStringLiteral("dll"), QStringLiteral("dylib"),
        };
        const QString suffix = host.section(QLatin1Char('.'), -1).toLower();
        return extensions.contains(suffix);
    }

    // schemes that are complete without "//"
    static bool hasOpaqueScheme(const QString &s)
    {
        static const QRegularExpression re(
            R"(^(about|mailto|tel|data|view-source|blob):\S)", QRegularExpression::CaseInsensitiveOption);
        return re.match(s).hasMatch();
    }

    static QString expandHome(const QString &s)
    {
        return s.startsWith(QLatin1String("~/")) ? QDir::homePath() + s.mid(1) : s;
    }

    static bool isLocalPath(const QString &s)
    {
        static const QRegularExpression drive(R"(^[A-Za-z]:[\\/])");
        if (drive.match(s).hasMatch() || s.startsWith(QLatin1String("\\\\")))
            return true;
        // "/r/rust" is a search; a path to something that exists is a file
        if (s.startsWith(QLatin1Char('/')) || s.startsWith(QLatin1String("~/")))
            return QFileInfo::exists(expandHome(s));
        return false;
    }

    static bool isLocalNetworkHost(const QString &s)
    {
        return isLocalhost(s) || isIPv4(s) || isBracketedIPv6(s);
    }

    bool looksLikeHost(const QString &trimmed)
    {
        if (isLocalNetworkHost(trimmed))
            return true;
        if (trimmed.contains(' ') || !trimmed.contains('.') || isPlainNumber(trimmed))
            return false;
        const int dot = trimmed.indexOf('.');
        if (dot <= 0 || dot >= trimmed.size() - 1)
            return false;

        static const QRegularExpression hostEnd(R"([:/?#])");
        const QString host = trimmed.section(hostEnd, 0, 0);
        if (host.isEmpty() || host.endsWith(QLatin1Char('.')) || !host.contains(QLatin1Char('.')))
            return false;
        return !endsInFileExtension(host);
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
        if (hasOpaqueScheme(t))
            return QUrl(t);
        if (isLocalPath(t))
            return QUrl::fromLocalFile(QDir::fromNativeSeparators(expandHome(t)));
        if (isLocalNetworkHost(t))
            return QUrl::fromUserInput("http://" + t);
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
