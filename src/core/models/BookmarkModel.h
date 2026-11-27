#pragma once

#include <QAbstractListModel>
#include <QPointer>
#include <QString>
#include <QVariantMap>
#include <QVector>
#include <QtQml/qqmlregistration.h>
#include "../utils/ExternalQmlSingleton.h"

class Space;
class BookmarkModel : public QAbstractListModel, public ExternalQmlSingleton<BookmarkModel>
{
    Q_OBJECT
    QML_NAMED_ELEMENT(Bookmarks)
    QML_SINGLETON
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)

public:
    enum Roles
    {
        TitleRole = Qt::UserRole + 1,
        UrlRole,
        IconUrlRole,
    };

    explicit BookmarkModel(QObject *parent);

    void setSpace(Space *space);
    Space *space() const { return m_space; }

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE bool isBookmarked(const QString &url) const;
    Q_INVOKABLE void toggleBookmark(const QString &title, const QString &url, const QString &iconUrl = QString());
    Q_INVOKABLE void removeBookmark(int index);
    Q_INVOKABLE void renameBookmark(int index, const QString &title);
    Q_INVOKABLE QVariantMap itemAt(int index) const;

signals:
    void countChanged();

private:
    struct Bookmark
    {
        QString title;
        QString url;
        QString iconUrl;
    };

    int indexOfUrl(const QString &url) const;
    void load();
    bool save() const;

    QVector<Bookmark> m_bookmarks;
    QPointer<Space> m_space;
    QString m_storagePath;
};
