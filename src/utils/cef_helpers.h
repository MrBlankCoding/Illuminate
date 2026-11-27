#pragma once

#include <QString>
#include <QUrl>
#include <include/internal/cef_types.h>
#include <include/internal/cef_string.h>
#include <include/internal/cef_string_types.h>
#include <include/cef_base.h>

inline QString cefStringToQString(const CefString &cefStr)
{
    return QString::fromStdU16String(cefStr.ToString16());
}

inline CefString qStringToCef(const QString &qStr)
{
    return CefString(qStr.toStdU16String());
}

inline QUrl cefStringToQUrl(const CefString &cefStr)
{
    return QUrl(cefStringToQString(cefStr));
}

inline CefString qUrlToCefString(const QUrl &url)
{
    return qStringToCef(url.toString(QUrl::FullyEncoded));
}
