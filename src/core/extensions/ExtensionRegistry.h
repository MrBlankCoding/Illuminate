#pragma once

#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

#if defined(Q_MOC_RUN)
template <typename T> class CefRefPtr;
class CefPreferenceObserver;
#else
#include <include/cef_preference.h>
#endif

class CefProfile;
class QTimer;

// The extensions installed in one profile, read from Chrome's own record of
// them, so installs, removals and enabling or disabling show up as they happen.
class ExtensionRegistry : public QObject
{
    Q_OBJECT
    QML_NAMED_ELEMENT(ExtensionRegistry)
    QML_UNCREATABLE("Use CefProfile.extensions")

    // enabled user extensions, sorted by name:
    // [{id, name, description, version, iconUrl, popupUrl, optionsUrl, detailsUrl}]
    Q_PROPERTY(QVariantList items READ items NOTIFY itemsChanged)

public:
    explicit ExtensionRegistry(CefProfile *profile);
    ~ExtensionRegistry() override;

    QVariantList items() const { return m_items; }

    // re-reads Chrome's record; cheap to call, coalesced
    Q_INVOKABLE void refresh();
    // stops watching Chrome's record; before CEF shuts down
    void detach();

    // |settings| is Chrome's "extensions.settings" preference, keyed by id.
    // Relative install paths resolve against |extensionsDir|.
    static QVariantList parse(const QVariantMap &settings, const QString &extensionsDir);
    // settings for whatever is unpacked in |extensionsDir|, for when Chrome's
    // record is unavailable
    static QVariantMap scan(const QString &extensionsDir);
    // one extension's entry from its manifest, empty if it isn't one to list
    static QVariantMap describe(const QString &id, const QString &root, const QVariantMap &manifest);

signals:
    void itemsChanged();

private:
    void load();
    void apply(const QVariantMap &settings, const QString &profilePath);

    CefProfile *m_profile;
    QVariantList m_items;
    QTimer *m_refreshTimer;
    CefRefPtr<CefPreferenceObserver> m_observer;
};
