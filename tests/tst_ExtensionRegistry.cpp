#include <QtTest>

#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTemporaryDir>
#include <QUrl>

#include "CefManager.h"
#include "CefProfile.h"
#include "ExtensionRegistry.h"

namespace
{
void writeJson(const QString &path, const QVariantMap &content)
{
    QDir().mkpath(QFileInfo(path).absolutePath());
    QFile file(path);
    QVERIFY(file.open(QIODevice::WriteOnly));
    file.write(QJsonDocument(QJsonObject::fromVariantMap(content)).toJson());
}

void touch(const QString &path)
{
    QDir().mkpath(QFileInfo(path).absolutePath());
    QFile file(path);
    QVERIFY(file.open(QIODevice::WriteOnly));
}

QVariantMap findById(const QVariantList &items, const QString &id)
{
    for (const QVariant &item : items)
        if (item.toMap().value(QStringLiteral("id")).toString() == id)
            return item.toMap();
    return {};
}
}

class TestExtensionRegistry : public QObject
{
    Q_OBJECT

    QTemporaryDir m_dir;

    QString extensionsDir() const { return m_dir.filePath(QStringLiteral("Extensions")); }

private slots:
    void initTestCase()
    {
        QVERIFY(m_dir.isValid());
        QVERIFY(!CefManager::isInitialized());
    }

    void packedExtensionWithPopupIsDescribed()
    {
        const QString root = QDir(extensionsDir()).filePath(QStringLiteral("alpha/1.0_0"));
        writeJson(root + QStringLiteral("/manifest.json"), {
            {QStringLiteral("name"), QStringLiteral("__MSG_extName__")},
            {QStringLiteral("default_locale"), QStringLiteral("en")},
            {QStringLiteral("version"), QStringLiteral("1.0")},
            {QStringLiteral("action"), QVariantMap{
                {QStringLiteral("default_popup"), QStringLiteral("/popup.html")},
                {QStringLiteral("default_icon"), QVariantMap{{QStringLiteral("16"), QStringLiteral("i16.png")},
                                                             {QStringLiteral("48"), QStringLiteral("i48.png")}}}}},
            {QStringLiteral("options_ui"), QVariantMap{{QStringLiteral("page"), QStringLiteral("options.html")}}},
        });
        // message names are case-insensitive
        writeJson(root + QStringLiteral("/_locales/en/messages.json"), {
            {QStringLiteral("EXTNAME"), QVariantMap{{QStringLiteral("message"), QStringLiteral("Alpha")}}},
        });
        touch(root + QStringLiteral("/i48.png"));

        const QVariantList items = ExtensionRegistry::parse({
            {QStringLiteral("alpha"), QVariantMap{{QStringLiteral("path"), QStringLiteral("alpha/1.0_0")},
                                                  {QStringLiteral("location"), 1}}},
        }, extensionsDir());

        QCOMPARE(items.size(), 1);
        const QVariantMap alpha = items.first().toMap();
        QCOMPARE(alpha.value(QStringLiteral("name")).toString(), QStringLiteral("Alpha"));
        QCOMPARE(alpha.value(QStringLiteral("popupUrl")).toString(),
                 QStringLiteral("chrome-extension://alpha/popup.html"));
        QCOMPARE(alpha.value(QStringLiteral("optionsUrl")).toString(),
                 QStringLiteral("chrome-extension://alpha/options.html"));
        QCOMPARE(alpha.value(QStringLiteral("detailsUrl")).toString(),
                 QStringLiteral("chrome://extensions/?id=alpha"));
        QVERIFY(QUrl(alpha.value(QStringLiteral("iconUrl")).toString()).toLocalFile().endsWith(QStringLiteral("i48.png")));
    }

    void disabledComponentAndThemeEntriesAreSkipped()
    {
        const QString theme = QDir(extensionsDir()).filePath(QStringLiteral("theme/1_0"));
        writeJson(theme + QStringLiteral("/manifest.json"), {
            {QStringLiteral("name"), QStringLiteral("Theme")},
            {QStringLiteral("theme"), QVariantMap{}},
        });
        const QString plain = QDir(extensionsDir()).filePath(QStringLiteral("plain/1_0"));
        writeJson(plain + QStringLiteral("/manifest.json"), {{QStringLiteral("name"), QStringLiteral("Plain")}});

        const QVariantList items = ExtensionRegistry::parse({
            {QStringLiteral("theme"), QVariantMap{{QStringLiteral("path"), QStringLiteral("theme/1_0")}}},
            {QStringLiteral("listDisabled"), QVariantMap{{QStringLiteral("path"), QStringLiteral("plain/1_0")},
                                                         {QStringLiteral("disable_reasons"), QVariantList{1}}}},
            {QStringLiteral("maskDisabled"), QVariantMap{{QStringLiteral("path"), QStringLiteral("plain/1_0")},
                                                         {QStringLiteral("disable_reasons"), 2}}},
            {QStringLiteral("stateDisabled"), QVariantMap{{QStringLiteral("path"), QStringLiteral("plain/1_0")},
                                                          {QStringLiteral("state"), 0}}},
            {QStringLiteral("component"), QVariantMap{{QStringLiteral("path"), QStringLiteral("plain/1_0")},
                                                      {QStringLiteral("location"), 5}}},
            {QStringLiteral("enabled"), QVariantMap{{QStringLiteral("path"), QStringLiteral("plain/1_0")},
                                                    {QStringLiteral("disable_reasons"), QVariantList{}}}},
        }, extensionsDir());

        QCOMPARE(items.size(), 1);
        QCOMPARE(items.first().toMap().value(QStringLiteral("id")).toString(), QStringLiteral("enabled"));
        QVERIFY(items.first().toMap().value(QStringLiteral("popupUrl")).toString().isEmpty());
    }

    void unpackedExtensionsResolveAbsolutePathsAndRecordedManifests()
    {
        const QString unpacked = m_dir.filePath(QStringLiteral("unpacked"));
        writeJson(unpacked + QStringLiteral("/manifest.json"), {
            {QStringLiteral("name"), QStringLiteral("Bravo")},
            {QStringLiteral("browser_action"), QVariantMap{{QStringLiteral("default_popup"), QStringLiteral("p.html")}}},
            {QStringLiteral("options_page"), QStringLiteral("o.html")},
            // outside the extension: never handed to QML
            {QStringLiteral("icons"), QVariantMap{{QStringLiteral("32"), QStringLiteral("../outside.png")}}},
        });
        touch(m_dir.filePath(QStringLiteral("outside.png")));

        const QVariantList items = ExtensionRegistry::parse({
            {QStringLiteral("bravo"), QVariantMap{{QStringLiteral("path"), unpacked},
                                                  {QStringLiteral("location"), 4}}},
            {QStringLiteral("charlie"), QVariantMap{
                {QStringLiteral("path"), m_dir.filePath(QStringLiteral("missing"))},
                {QStringLiteral("manifest"), QVariantMap{{QStringLiteral("name"), QStringLiteral("Charlie")}}}}},
        }, extensionsDir());

        QCOMPARE(items.size(), 2);
        // sorted by name
        QCOMPARE(items.at(0).toMap().value(QStringLiteral("name")).toString(), QStringLiteral("Bravo"));
        QCOMPARE(items.at(1).toMap().value(QStringLiteral("name")).toString(), QStringLiteral("Charlie"));
        const QVariantMap bravo = findById(items, QStringLiteral("bravo"));
        QCOMPARE(bravo.value(QStringLiteral("popupUrl")).toString(), QStringLiteral("chrome-extension://bravo/p.html"));
        QCOMPARE(bravo.value(QStringLiteral("optionsUrl")).toString(), QStringLiteral("chrome-extension://bravo/o.html"));
        QVERIFY(bravo.value(QStringLiteral("iconUrl")).toString().isEmpty());
    }

    void scanPicksTheNewestVersionWithAManifest()
    {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        writeJson(dir.filePath(QStringLiteral("delta/1.9_0/manifest.json")), {{QStringLiteral("name"), QStringLiteral("Old")}});
        writeJson(dir.filePath(QStringLiteral("delta/1.10_0/manifest.json")), {{QStringLiteral("name"), QStringLiteral("New")}});
        QDir().mkpath(dir.filePath(QStringLiteral("delta/2.0_0"))); // half-installed
        QDir().mkpath(dir.filePath(QStringLiteral("empty")));

        const QVariantMap settings = ExtensionRegistry::scan(dir.path());
        QCOMPARE(settings.keys(), QStringList{QStringLiteral("delta")});
        QCOMPARE(settings.value(QStringLiteral("delta")).toMap().value(QStringLiteral("path")).toString(),
                 QStringLiteral("delta/1.10_0"));

        const QVariantList items = ExtensionRegistry::parse(settings, dir.path());
        QCOMPARE(items.size(), 1);
        QCOMPARE(items.first().toMap().value(QStringLiteral("name")).toString(), QStringLiteral("New"));
    }

    void registryIsEmptyAndSafeWithoutCef()
    {
        CefProfile profile(m_dir.filePath(QStringLiteral("profile")),
                           m_dir.filePath(QStringLiteral("cache")));
        ExtensionRegistry *registry = profile.extensions();
        QVERIFY(registry);
        QCOMPARE(profile.extensions(), registry);
        registry->refresh();
        QTest::qWait(250);
        QVERIFY(registry->items().isEmpty());
    }
};

QTEST_GUILESS_MAIN(TestExtensionRegistry)
#include "tst_ExtensionRegistry.moc"
