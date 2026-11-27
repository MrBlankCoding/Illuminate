#pragma once

#include <QUrl>
#include <QString>

// Converts raw address-bar text into a loadable QUrl.
// Rules (priority order):
//   1. Contains "://"           → treat as a full URL
//   2. Starts with "localhost"  → prepend https://
//   3. Looks like an IP address → prepend https://
//   4. No spaces, contains "."  → prepend https://
//   5. Anything else            → search the query

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
