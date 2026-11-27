#pragma once

#include <QAbstractListModel>
#include <QUrl>
#include <QVariantMap>
#include <QVector>
#include <QtQml/qqmlregistration.h>

class BrowserTab;
class CefProfile;

class TabModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Use Browser.tabModel")
    Q_PROPERTY(int activeIndex READ activeIndex WRITE setActiveIndex
                   NOTIFY activeIndexChanged)
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)

public:
    enum Roles
    {
        IdRole = Qt::UserRole + 1,
        TitleRole,
        UrlRole,
        IconUrlRole,
        ProgressRole,
        LoadingRole,
        RenderPidRole,
        SuspendedRole,
        AudibleRole,
        MutedRole,
        ActivityRole,
    };

    static constexpr int kMaxTabs = 500;

    explicit TabModel(QObject *parent = nullptr);

    // QAbstractListModel interface
    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    // tab CRUD
    // suspended: no web view until the tab is first activated (session restore)
    BrowserTab *addTab(const QUrl &url, bool suspended = false);
    bool removeTab(int index);
    void clear();
    // Hands every tab over (and the active row) leaving the model empty: a
    // space being put away keeps its tabs. They stay this model's children.
    void takeTabs(QVector<BrowserTab *> &tabs, int &activeIndex);
    // Takes tabs back from takeTabs() in place of whatever is here.
    void restoreTabs(QVector<BrowserTab *> tabs, int activeIndex);
    BrowserTab *tabAt(int index) const;
    Q_INVOKABLE BrowserTab *tabAt(int index);
    int indexOf(const BrowserTab *tab) const;
    int nearestLiveIndex(int index) const;

    // QML-invoked reordering
    Q_INVOKABLE void moveTab(int from, int to);

    int activeIndex() const;
    void setActiveIndex(int index);

    // single row update
    void refreshTab(BrowserTab *tab, int role);

    // QML convenience: tabModel.itemAt(i).title etc.
    Q_INVOKABLE QVariantMap itemAt(int index) const;

signals:
    void activeIndexChanged();
    void countChanged();
    void tabAboutToBeRemoved(BrowserTab *tab);

private:
    QVector<BrowserTab *> m_tabs;
    int m_activeIndex = -1;
};
