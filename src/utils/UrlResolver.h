#pragma once

#include <QUrl>
#include <QString>

// Converts raw address-bar text into a loadable QUrl.
// Rules (priority order):
//   1. Contains "://"                       → a full URL, as typed
//   2. about:, mailto:, data:, view-source: → a full URL, as typed
//   3. A local path that exists, or C:\…    → file://
//   4. localhost, an IPv4 or [IPv6] address → http:// (these rarely speak TLS)
//   5. A dotted host, not a number and not
//      a file name like "node.js"           → https://
//   6. Anything else                        → search the query

namespace UrlResolver
{
    // used when the user hasn't picked an engine or their custom template is
    // unusable (empty, or missing the %s placeholder)
    extern const QString kFallbackSearchTemplate;

    // searchTemplate is a URL with a single %s placeholder, e.g.
    // "https://duckduckgo.com/?q=%s". A template without %s is ignored.
    QUrl resolve(const QString &input, const QString &searchTemplate = {});
    QUrl searchUrl(const QString &query, const QString &searchTemplate = {});
    bool looksLikeHost(const QString &trimmed);
}
