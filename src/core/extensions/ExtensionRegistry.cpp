#include "ExtensionRegistry.h"
#include "CefProfile.h"
#include "../utils/cef_helpers.h"

#include <include/cef_registration.h>
#include <include/cef_request_context.h>
#include <include/cef_task.h>
#include <include/base/cef_callback.h>
#include <include/wrapper/cef_closure_task.h>

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLocale>
#include <QMetaObject>
#include <QPointer>
#include <QTimer>
#include <QUrl>
#include <QVersionNumber>

#include <algorithm>
#include <functional>

namespace
{

constexpr char kSettingsPreference[] = "extensions.settings";
constexpr int kRefreshDelayMs = 150;

// mojom::ManifestLocation values Chrome stores in "location"
constexpr int kLocationComponent = 5;
constexpr int kLocationExternalComponent = 10;

QVariant toVariant(const CefRefPtr<CefValue> &value)
{
    if (!value)
        return {};
    switch (value->GetType())
    {
    case VTYPE_BOOL:
        return value->GetBool();
    case VTYPE_INT:
        return value->GetInt();
    case VTYPE_DOUBLE:
        return value->GetDouble();
    case VTYPE_STRING:
        return cefStringToQString(value->GetString());
    case VTYPE_DICTIONARY: {
        QVariantMap map;
        CefRefPtr<CefDictionaryValue> dictionary = value->GetDictionary();
        CefDictionaryValue::KeyList keys;
        dictionary->GetKeys(keys);
        for (const CefString &key : keys)
            map.insert(cefStringToQString(key), toVariant(dictionary->GetValue(key)));
        return map;
    }
    case VTYPE_LIST: {
        QVariantList list;
        CefRefPtr<CefListValue> values = value->GetList();
        for (size_t i = 0; i < values->GetSize(); ++i)
            list.append(toVariant(values->GetValue(i)));
        return list;
    }
    default:
        return {};
    }
}

bool isDisabled(const QVariantMap &settings)
{
    // a list of reasons since M135, a bit mask before
    const QVariant reasons = settings.value(QStringLiteral("disable_reasons"));
    if (reasons.typeId() == QMetaType::QVariantList ? !reasons.toList().isEmpty() : reasons.toInt() != 0)
        return true;
    // older profiles: 0 is disabled
    return settings.contains(QStringLiteral("state")) && settings.value(QStringLiteral("state")).toInt() == 0;
}

QVariantMap readJson(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return {};
    return QJsonDocument::fromJson(file.readAll()).object().toVariantMap();
}

// "__MSG_name__" -> the message from the first locale that has it
QString localized(const QString &text, const QString &root, const QString &defaultLocale)
{
    if (!text.startsWith(QStringLiteral("__MSG_")) || !text.endsWith(QStringLiteral("__")))
        return text;
    const QString key = text.mid(6, text.size() - 8);

    const QString uiLocale = QLocale().name();
    const QStringList locales{uiLocale, uiLocale.section(QLatin1Char('_'), 0, 0),
                              defaultLocale, defaultLocale.section(QLatin1Char('_'), 0, 0)};
    for (const QString &locale : locales)
    {
        if (locale.isEmpty())
            continue;
        const QVariantMap messages = readJson(
            QDir(root).filePath(QStringLiteral("_locales/%1/messages.json").arg(locale)));
        // message names are case-insensitive
        for (auto it = messages.cbegin(); it != messages.cend(); ++it)
        {
            if (it.key().compare(key, Qt::CaseInsensitive) != 0)
                continue;
            const QString message = it.value().toMap().value(QStringLiteral("message")).toString();
            if (!message.isEmpty())
                return message;
        }
    }
    return {};
}

// a file inside the extension as a URL QML can load, if it stays inside
QString fileUrl(const QString &root, const QString &relativePath)
{
    if (relativePath.isEmpty())
        return {};
    const QString canonicalRoot = QDir(root).canonicalPath() + QLatin1Char('/');
    const QString canonical = QFileInfo(QDir(root).filePath(relativePath)).canonicalFilePath();
    if (canonical.isEmpty() || !canonical.startsWith(canonicalRoot))
        return {};
    return QUrl::fromLocalFile(canonical).toString();
}

// "default_icon" is a path or {size: path}; take the largest
QString largestIcon(const QVariant &icons)
{
    if (icons.typeId() == QMetaType::QString)
        return icons.toString();
    const QVariantMap sizes = icons.toMap();
    QString path;
    int largest = -1;
    for (auto it = sizes.cbegin(); it != sizes.cend(); ++it)
    {
        bool ok = false;
        const int size = it.key().toInt(&ok);
        if (ok && size > largest && !it.value().toString().isEmpty())
        {
            largest = size;
            path = it.value().toString();
        }
    }
    return path;
}

QString pageUrl(const QString &id, QString page)
{
    while (page.startsWith(QLatin1Char('/')))
        page.remove(0, 1);
    return page.isEmpty() ? QString() : QStringLiteral("chrome-extension://%1/%2").arg(id, page);
}

class SettingsObserver final : public CefPreferenceObserver
{
public:
    explicit SettingsObserver(QPointer<ExtensionRegistry> registry) : m_registry(registry) {}

    void OnPreferenceChanged(const CefString &) override
    {
        QPointer<ExtensionRegistry> registry = m_registry;
        QMetaObject::invokeMethod(QCoreApplication::instance(), [registry]() {
            if (registry)
                registry->refresh();
        }, Qt::QueuedConnection);
    }

    // only touched on CEF's UI thread
    CefRefPtr<CefRegistration> registration;

private:
    QPointer<ExtensionRegistry> m_registry;
    IMPLEMENT_REFCOUNTING(SettingsObserver);
};

using Delivery = std::function<void(const QVariantMap &settings, const QString &profilePath)>;

// on CEF's UI thread: Chrome's record and where the profile lives
void readSettings(CefRefPtr<CefRequestContext> context,
                  CefRefPtr<SettingsObserver> observer,
                  Delivery deliver)
{
    if (!observer->registration)
        observer->registration = context->AddPreferenceObserver(kSettingsPreference, observer);

    const QVariantMap settings = toVariant(context->GetPreference(kSettingsPreference)).toMap();
    const QString profilePath = cefStringToQString(context->GetCachePath());
    QMetaObject::invokeMethod(QCoreApplication::instance(), [deliver, settings, profilePath]() {
        deliver(settings, profilePath);
    }, Qt::QueuedConnection);
}

void dropRegistration(CefRefPtr<SettingsObserver> observer)
{
    observer->registration = nullptr;
}

} // namespace

ExtensionRegistry::ExtensionRegistry(CefProfile *profile)
    : QObject(profile),
      m_profile(profile),
      m_refreshTimer(new QTimer(this))
{
    m_refreshTimer->setSingleShot(true);
    m_refreshTimer->setInterval(kRefreshDelayMs);
    connect(m_refreshTimer, &QTimer::timeout, this, &ExtensionRegistry::load);
    m_observer = new SettingsObserver(this);
    load();
}

ExtensionRegistry::~ExtensionRegistry()
{
    detach();
}

void ExtensionRegistry::detach()
{
    m_profile = nullptr;
    m_refreshTimer->stop();
    CefRefPtr<SettingsObserver> observer(static_cast<SettingsObserver *>(m_observer.get()));
    m_observer = nullptr;
    // only ever set once CEF is up; CefManager::shutdown() lands here first
    if (!observer || !observer->registration)
        return;
    if (CefCurrentlyOn(TID_UI))
        dropRegistration(observer);
    else
        CefPostTask(TID_UI, base::BindOnce(&dropRegistration, observer));
}

void ExtensionRegistry::refresh()
{
    m_refreshTimer->start();
}

void ExtensionRegistry::load()
{
    if (m_profile && !m_profile->isRequestContextInitialized()) {
        QPointer<ExtensionRegistry> guard(this);
        connect(m_profile, &CefProfile::requestContextInitialized, this, [guard]() {
            if (guard)
                guard->load();
        }, Qt::SingleShotConnection);
        return;
    }
    CefRefPtr<CefRequestContext> context = m_profile ? m_profile->requestContext() : nullptr;
    if (!context || !m_observer)
        return;

    QPointer<ExtensionRegistry> guard(this);
    Delivery deliver = [guard](const QVariantMap &settings, const QString &profilePath) {
        if (guard)
            guard->apply(settings, profilePath);
    };
    CefPostTask(TID_UI, base::BindOnce(&readSettings, context,
                                       CefRefPtr<SettingsObserver>(static_cast<SettingsObserver *>(m_observer.get())),
                                       std::move(deliver)));
}

void ExtensionRegistry::apply(const QVariantMap &settings, const QString &profilePath)
{
    // packed extensions live under Extensions/, beside the profile's
    // Preferences; some layouts nest the profile in Default/
    QString extensionsDir = QDir(profilePath).filePath(QStringLiteral("Extensions"));
    if (!QFileInfo::exists(extensionsDir))
    {
        const QString nested = QDir(profilePath).filePath(QStringLiteral("Default/Extensions"));
        if (QFileInfo::exists(nested))
            extensionsDir = nested;
    }

    const QVariantList items = parse(settings.isEmpty() ? scan(extensionsDir) : settings, extensionsDir);
    if (items == m_items)
        return;
    m_items = items;
    emit itemsChanged();
}

QVariantList ExtensionRegistry::parse(const QVariantMap &settings, const QString &extensionsDir)
{
    QVariantList items;
    for (auto it = settings.cbegin(); it != settings.cend(); ++it)
    {
        const QVariantMap extension = it.value().toMap();
        const int location = extension.value(QStringLiteral("location")).toInt();
        if (location == kLocationComponent || location == kLocationExternalComponent || isDisabled(extension))
            continue;

        const QString path = extension.value(QStringLiteral("path")).toString();
        if (path.isEmpty())
            continue;
        const QString root = QDir::isAbsolutePath(path) ? path : QDir(extensionsDir).filePath(path);

        // unpacked extensions may only have their manifest in the record
        QVariantMap manifest = readJson(QDir(root).filePath(QStringLiteral("manifest.json")));
        if (manifest.isEmpty())
            manifest = extension.value(QStringLiteral("manifest")).toMap();

        const QVariantMap item = describe(it.key(), root, manifest);
        if (!item.isEmpty())
            items.append(item);
    }

    std::sort(items.begin(), items.end(), [](const QVariant &left, const QVariant &right) {
        return QString::localeAwareCompare(left.toMap().value(QStringLiteral("name")).toString(),
                                           right.toMap().value(QStringLiteral("name")).toString()) < 0;
    });
    return items;
}

QVariantMap ExtensionRegistry::scan(const QString &extensionsDir)
{
    QVariantMap settings;
    const QFileInfoList extensions = QDir(extensionsDir).entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QFileInfo &extension : extensions)
    {
        // versions are named like 1.2.3_0; keep the newest with a manifest
        QString newest;
        QVersionNumber newestVersion;
        const QFileInfoList versions = QDir(extension.absoluteFilePath()).entryInfoList(
            QDir::Dirs | QDir::NoDotAndDotDot);
        for (const QFileInfo &version : versions)
        {
            if (!QFileInfo::exists(QDir(version.absoluteFilePath()).filePath(QStringLiteral("manifest.json"))))
                continue;
            const QVersionNumber number = QVersionNumber::fromString(version.fileName());
            if (newest.isEmpty() || QVersionNumber::compare(number, newestVersion) > 0)
            {
                newest = version.fileName();
                newestVersion = number;
            }
        }
        if (!newest.isEmpty())
            settings.insert(extension.fileName(),
                            QVariantMap{{QStringLiteral("path"), extension.fileName() + QLatin1Char('/') + newest}});
    }
    return settings;
}

QVariantMap ExtensionRegistry::describe(const QString &id, const QString &root, const QVariantMap &manifest)
{
    // themes and apps have nothing to show in an extensions menu
    if (manifest.isEmpty() || manifest.contains(QStringLiteral("theme")) || manifest.contains(QStringLiteral("app")))
        return {};

    const QString defaultLocale = manifest.value(QStringLiteral("default_locale")).toString();
    QString name = localized(manifest.value(QStringLiteral("name")).toString(), root, defaultLocale);
    if (name.isEmpty())
        name = id;

    QVariantMap action = manifest.value(QStringLiteral("action")).toMap();
    if (action.isEmpty())
        action = manifest.value(QStringLiteral("browser_action")).toMap();
    if (action.isEmpty())
        action = manifest.value(QStringLiteral("page_action")).toMap();

    QString icon = largestIcon(action.value(QStringLiteral("default_icon")));
    if (icon.isEmpty())
        icon = largestIcon(manifest.value(QStringLiteral("icons")));

    QString options = manifest.value(QStringLiteral("options_ui")).toMap().value(QStringLiteral("page")).toString();
    if (options.isEmpty())
        options = manifest.value(QStringLiteral("options_page")).toString();

    return {
        {QStringLiteral("id"), id},
        {QStringLiteral("name"), name},
        {QStringLiteral("description"),
         localized(manifest.value(QStringLiteral("description")).toString(), root, defaultLocale)},
        {QStringLiteral("version"), manifest.value(QStringLiteral("version")).toString()},
        {QStringLiteral("iconUrl"), fileUrl(root, icon)},
        {QStringLiteral("popupUrl"), pageUrl(id, action.value(QStringLiteral("default_popup")).toString())},
        {QStringLiteral("optionsUrl"), pageUrl(id, options)},
        {QStringLiteral("detailsUrl"), QStringLiteral("chrome://extensions/?id=%1").arg(id)},
    };
}
