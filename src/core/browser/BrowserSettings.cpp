#include "BrowserSettings.h"
#include "CefManager.h"
#include "CefProfile.h"

#include <QDir>
#include <QSettings>

#include <algorithm>
#include <QUrl>

#include "../utils/UrlResolver.h"

namespace
{
    constexpr char kStartupBehaviorKey[] = "startup/behavior";
    constexpr char kStartupHomepageKey[] = "startup/homepage";
    constexpr char kSearchEngineKey[] = "search/engine";
    constexpr char kSearchCustomUrlKey[] = "search/customUrl";
    constexpr char kSearchSuggestionsKey[] = "search/suggestions";
    constexpr char kCommandBarCalculatorKey[] = "search/calculator";
    constexpr char kCommandBarBangsKey[] = "search/bangs";
    constexpr char kThirdPartyCookiesKey[] = "privacy/thirdPartyCookies";
    constexpr char kMemorySaverEnabledKey[] = "tabs/memorySaverEnabled";
    constexpr char kMemorySaverModeKey[] = "tabs/memorySaverMode";
    constexpr char kConfirmCloseKey[] = "tabs/confirmCloseMultipleTabs";
    constexpr char kDensityKey[] = "appearance/density";
    constexpr char kPreloadSpacesKey[] = "spaces/preload";
    constexpr char kMaxDiskCacheSizeKey[] = "network/maxDiskCacheSize";

    QString normalizedDensity(const QString &density)
    {
        if (density == QLatin1String(BrowserSettings::kDensityNormal)
            || density == QLatin1String(BrowserSettings::kDensityCosy))
            return density;
        return QString::fromLatin1(BrowserSettings::kDensityCompact);
    }
    constexpr char kSidebarWidthKey[] = "sidebar/width";
    constexpr char kSidebarCollapsedKey[] = "sidebar/collapsed";
    constexpr char kSidebarCompactKey[] = "sidebar/compact";

    struct SearchEngine
    {
        const char *id;
        const char *name;
        const char *url; // empty for the "custom" pseudo-engine
    };

    const SearchEngine kEngines[] = {
        {"duckduckgo", "DuckDuckGo", "https://duckduckgo.com/?q=%s"},
        {"google", "Google", "https://www.google.com/search?q=%s"},
        {"bing", "Bing", "https://www.bing.com/search?q=%s"},
        {"brave", "Brave", "https://search.brave.com/search?q=%s"},
        {"ecosia", "Ecosia", "https://www.ecosia.org/search?q=%s"},
        {"startpage", "Startpage", "https://www.startpage.com/sp/search?query=%s"},
        {"youtube", "YouTube", "https://www.youtube.com/results?search_query=%s"},
        {"wikipedia", "Wikipedia", "https://en.wikipedia.org/w/index.php?search=%s"},
        {BrowserSettings::kEngineCustom, "Custom…", ""},
    };

    QString engineName(const QString &id)
    {
        for (const SearchEngine &engine : kEngines)
        {
            if (id == QLatin1String(engine.id))
                return QString::fromLatin1(engine.name);
        }
        return {};
    }

    QString engineTemplate(const QString &id)
    {
        for (const SearchEngine &engine : kEngines)
        {
            if (id == QLatin1String(engine.id))
                return QString::fromLatin1(engine.url);
        }
        return {};
    }

    QVariant readValue(QSettings *settings, const char *key, const QVariant &fallback)
    {
        return settings ? settings->value(QLatin1String(key), fallback) : fallback;
    }

    void writeValue(QSettings *settings, const char *key, const QVariant &value)
    {
        if (settings)
            settings->setValue(QLatin1String(key), value);
    }

    constexpr char kBrowserLanguageKey[] = "general/language";
}

BrowserSettings::BrowserSettings(QObject *parent, const QString &settingsFilePath)
    : QObject(parent)
    , m_settings(new QSettings(settingsFilePath.isEmpty()
                                   ? QDir::homePath() + QDir::separator() + ".illuminate"
                                         + QDir::separator() + "settings.ini"
                                   : settingsFilePath,
                               QSettings::IniFormat, this))
    , m_appSettings(new QSettings(this))
{
    m_confirmCloseMultipleTabs =
        m_appSettings->value(QLatin1String(kConfirmCloseKey), true).toBool();
    m_uiDensity = normalizedDensity(m_appSettings->value(QLatin1String(kDensityKey)).toString());
    m_preloadSpaces = m_appSettings->value(QLatin1String(kPreloadSpacesKey), true).toBool();
    const int storedWidth = m_appSettings->value(QLatin1String(kSidebarWidthKey), kSidebarDefaultWidth).toInt();
    m_sidebarWidth = std::clamp(storedWidth, kSidebarMinWidth, kSidebarMaxWidth);
    m_sidebarCollapsed = m_appSettings->value(QLatin1String(kSidebarCollapsedKey), false).toBool();
    m_browserLanguage = readValue(m_appSettings, kBrowserLanguageKey, QString()).toString();
    m_webProfile = CefManager::defaultProfile();
    reloadSettings();
    applyThirdPartyCookies();
    m_webProfile->setMemorySaverSettings(m_memorySaverEnabled, m_memorySaverMode);
    emit browserLanguageChanged();
}

void BrowserSettings::reloadSettings()
{
    const QString behavior =
        readValue(m_settings, kStartupBehaviorKey, QLatin1String(kStartupNewTab)).toString();
    m_startupBehavior = behavior == QLatin1String(kStartupHomepage)
                            ? behavior
                            : QLatin1String(kStartupNewTab);
    m_homepageUrl = readValue(m_settings, kStartupHomepageKey, QString()).toString();

    const QString engineId =
        readValue(m_settings, kSearchEngineKey, QStringLiteral("duckduckgo")).toString();
    m_searchEngineId = engineName(engineId).isEmpty() ? QStringLiteral("duckduckgo") : engineId;
    m_customSearchUrl = readValue(m_settings, kSearchCustomUrlKey, QString()).toString();
    m_searchSuggestions = readValue(m_settings, kSearchSuggestionsKey, true).toBool();
    m_commandBarCalculator = readValue(m_settings, kCommandBarCalculatorKey, true).toBool();
    m_commandBarBangs = readValue(m_settings, kCommandBarBangsKey, true).toBool();

    m_thirdPartyCookies = readValue(m_settings, kThirdPartyCookiesKey, true).toBool();

    m_memorySaverEnabled = readValue(m_settings, kMemorySaverEnabledKey, true).toBool();
    m_memorySaverMode = std::clamp(readValue(m_settings, kMemorySaverModeKey, 1).toInt(), 0, 2);
    m_maxDiskCacheSize = std::max(0, readValue(m_settings, kMaxDiskCacheSizeKey, 0).toInt());

    emit startupBehaviorChanged();
    emit homepageUrlChanged();
    emit searchEngineChanged();
    emit searchSuggestionsEnabledChanged();
    emit commandBarCalculatorEnabledChanged();
    emit commandBarBangsEnabledChanged();
    emit thirdPartyCookiesEnabledChanged();
    emit memorySaverChanged();
    emit maxDiskCacheSizeChanged();
}

// startup and session

QString BrowserSettings::startupBehavior() const
{
    return m_startupBehavior;
}

void BrowserSettings::setStartupBehavior(const QString &behavior)
{
    const QString normalized = behavior == QLatin1String(kStartupHomepage)
                                   ? QString::fromLatin1(kStartupHomepage)
                                   : QString::fromLatin1(kStartupNewTab);
    if (m_startupBehavior == normalized)
        return;
    m_startupBehavior = normalized;
    writeValue(m_settings, kStartupBehaviorKey, normalized);
    emit startupBehaviorChanged();
}

QString BrowserSettings::homepageUrl() const
{
    return m_homepageUrl;
}

void BrowserSettings::setHomepageUrl(const QString &url)
{
    const QString trimmed = url.trimmed();
    if (m_homepageUrl == trimmed)
        return;
    m_homepageUrl = trimmed;
    writeValue(m_settings, kStartupHomepageKey, trimmed);
    emit homepageUrlChanged();
}

// search

QString BrowserSettings::searchEngineId() const
{
    return m_searchEngineId;
}

void BrowserSettings::setSearchEngineId(const QString &id)
{
    if (m_searchEngineId == id)
        return;
    m_searchEngineId = id;
    writeValue(m_settings, kSearchEngineKey, id);
    emit searchEngineChanged();
}

QString BrowserSettings::searchEngineName() const
{
    return engineName(m_searchEngineId);
}

QString BrowserSettings::customSearchUrl() const
{
    return m_customSearchUrl;
}

void BrowserSettings::setCustomSearchUrl(const QString &url)
{
    const QString trimmed = url.trimmed();
    if (m_customSearchUrl == trimmed)
        return;
    m_customSearchUrl = trimmed;
    writeValue(m_settings, kSearchCustomUrlKey, trimmed);
    emit searchEngineChanged();
}

QVariantList BrowserSettings::searchEngines() const
{
    QVariantList list;
    for (const SearchEngine &engine : kEngines)
        list.append(QVariantMap{{QStringLiteral("id"), QString::fromLatin1(engine.id)},
                                {QStringLiteral("name"), QString::fromLatin1(engine.name)}});
    return list;
}

QString BrowserSettings::searchUrlTemplate() const
{
    if (m_searchEngineId == QLatin1String(kEngineCustom))
    {
        // a half-typed custom template still has to produce a search
        if (m_customSearchUrl.contains(QLatin1String("%s")))
            return m_customSearchUrl;
        return UrlResolver::kFallbackSearchTemplate;
    }
    const QString tmpl = engineTemplate(m_searchEngineId);
    return tmpl.isEmpty() ? UrlResolver::kFallbackSearchTemplate : tmpl;
}

bool BrowserSettings::searchSuggestionsEnabled() const
{
    return m_searchSuggestions;
}

void BrowserSettings::setSearchSuggestionsEnabled(bool enabled)
{
    if (m_searchSuggestions == enabled)
        return;
    m_searchSuggestions = enabled;
    writeValue(m_settings, kSearchSuggestionsKey, enabled);
    emit searchSuggestionsEnabledChanged();
}

bool BrowserSettings::commandBarCalculatorEnabled() const
{
    return m_commandBarCalculator;
}

void BrowserSettings::setCommandBarCalculatorEnabled(bool enabled)
{
    if (m_commandBarCalculator == enabled)
        return;
    m_commandBarCalculator = enabled;
    writeValue(m_settings, kCommandBarCalculatorKey, enabled);
    emit commandBarCalculatorEnabledChanged();
}

bool BrowserSettings::commandBarBangsEnabled() const
{
    return m_commandBarBangs;
}

void BrowserSettings::setCommandBarBangsEnabled(bool enabled)
{
    if (m_commandBarBangs == enabled)
        return;
    m_commandBarBangs = enabled;
    writeValue(m_settings, kCommandBarBangsKey, enabled);
    emit commandBarBangsEnabledChanged();
}

// privacy

bool BrowserSettings::thirdPartyCookiesEnabled() const
{
    return m_thirdPartyCookies;
}

void BrowserSettings::setThirdPartyCookiesEnabled(bool enabled)
{
    if (m_thirdPartyCookies == enabled)
        return;
    m_thirdPartyCookies = enabled;
    writeValue(m_settings, kThirdPartyCookiesKey, enabled);
    applyThirdPartyCookies();
    emit thirdPartyCookiesEnabledChanged();
}

void BrowserSettings::applyThirdPartyCookies()
{
    CefProfile::setThirdPartyCookiesAllowedForAll(m_thirdPartyCookies);
}

// tabs

bool BrowserSettings::memorySaverEnabled() const
{
    return m_memorySaverEnabled;
}

void BrowserSettings::setMemorySaverEnabled(bool enabled)
{
    if (m_memorySaverEnabled == enabled)
        return;
    m_memorySaverEnabled = enabled;
    writeValue(m_settings, kMemorySaverEnabledKey, enabled);
    if (m_webProfile)
        m_webProfile->setMemorySaverSettings(m_memorySaverEnabled, m_memorySaverMode);
    emit memorySaverChanged();
}

int BrowserSettings::memorySaverMode() const
{
    return m_memorySaverMode;
}

void BrowserSettings::setMemorySaverMode(int mode)
{
    const int clamped = std::clamp(mode, 0, 2);
    if (m_memorySaverMode == clamped)
        return;
    m_memorySaverMode = clamped;
    writeValue(m_settings, kMemorySaverModeKey, clamped);
    if (m_webProfile)
        m_webProfile->setMemorySaverSettings(m_memorySaverEnabled, m_memorySaverMode);
    emit memorySaverChanged();
}

bool BrowserSettings::confirmCloseMultipleTabs() const
{
    return m_confirmCloseMultipleTabs;
}

void BrowserSettings::setConfirmCloseMultipleTabs(bool enabled)
{
    if (m_confirmCloseMultipleTabs == enabled)
        return;
    m_confirmCloseMultipleTabs = enabled;
    writeValue(m_appSettings, kConfirmCloseKey, enabled);
    emit confirmCloseMultipleTabsChanged();
}

void BrowserSettings::setUiDensity(const QString &density)
{
    const QString normalized = normalizedDensity(density);
    if (m_uiDensity == normalized)
        return;
    m_uiDensity = normalized;
    writeValue(m_appSettings, kDensityKey, normalized);
    emit uiDensityChanged();
}

void BrowserSettings::setPreloadSpaces(bool enabled)
{
    if (m_preloadSpaces == enabled)
        return;
    m_preloadSpaces = enabled;
    writeValue(m_appSettings, kPreloadSpacesKey, enabled);
    emit preloadSpacesChanged();
}

int BrowserSettings::maxDiskCacheSize() const
{
    return m_maxDiskCacheSize;
}

void BrowserSettings::setMaxDiskCacheSize(int sizeMB)
{
    sizeMB = std::max(0, sizeMB);
    if (m_maxDiskCacheSize == sizeMB)
        return;
    m_maxDiskCacheSize = sizeMB;
    writeValue(m_settings, kMaxDiskCacheSizeKey, sizeMB);
    emit maxDiskCacheSizeChanged();
}

// sidebar

int BrowserSettings::sidebarWidth() const
{
    return m_sidebarWidth;
}

void BrowserSettings::setSidebarWidth(int width)
{
    width = std::clamp(width, kSidebarMinWidth, kSidebarMaxWidth);
    if (m_sidebarWidth == width)
        return;
    m_sidebarWidth = width;
    writeValue(m_appSettings, kSidebarWidthKey, width);
    emit sidebarWidthChanged();
}

bool BrowserSettings::sidebarCollapsed() const
{
    return m_sidebarCollapsed;
}

void BrowserSettings::setSidebarCollapsed(bool collapsed)
{
    if (m_sidebarCollapsed == collapsed)
        return;
    m_sidebarCollapsed = collapsed;
    writeValue(m_appSettings, kSidebarCollapsedKey, collapsed);
    emit sidebarCollapsedChanged();
}

// general

QString BrowserSettings::browserLanguage() const
{
    return m_browserLanguage;
}

void BrowserSettings::setBrowserLanguage(const QString &language)
{
    if (m_browserLanguage == language)
        return;
    m_browserLanguage = language;
    writeValue(m_appSettings, kBrowserLanguageKey, language);
    emit browserLanguageChanged();
}
