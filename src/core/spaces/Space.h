#ifndef SPACE_H
#define SPACE_H

#include <QColor>
#include <QObject>
#include <QString>
#include <QtQml/qqmlregistration.h>

class Space : public QObject
{
    Q_OBJECT
    // declared so QML tooling knows the type Spaces hands out
    QML_NAMED_ELEMENT(Space)
    QML_UNCREATABLE("Spaces create spaces; use Spaces.createSpace()")
    Q_PROPERTY(QString id READ id CONSTANT)
    Q_PROPERTY(QString name READ name WRITE setName NOTIFY nameChanged)
    Q_PROPERTY(QColor color READ color WRITE setColor NOTIFY colorChanged)
    Q_PROPERTY(QString initial READ initial NOTIFY nameChanged)
    // the seed the UI derives its theme from; invalid means the default theme
    Q_PROPERTY(QColor themeColor READ themeColor NOTIFY themeColorChanged)

public:
    explicit Space(QObject *parent = nullptr);
    Space(const QString &id, const QString &name, const QColor &color, QObject *parent = nullptr);

    QString id() const { return m_id; }
    QString name() const { return m_name; }
    void setName(const QString &name);

    QColor color() const { return m_color; }
    void setColor(const QColor &color);
    QColor themeColor() const { return m_themeColor; }
    // persist: false while previewing, so a drag does not save on every move
    void setThemeColor(const QColor &color, bool persist = true);

    QString initial() const
    {
        return m_name.isEmpty() ? QString() : m_name.left(1).toUpper();
    }

    QString storageDir() const { return m_storageDir; }
    void setStorageDir(const QString &dir) { m_storageDir = dir; }
    QString sidebarFilePath() const;
    QString sessionFilePath() const;
    // the page that was in front when the space was last left, from its
    // session file; empty for none, or for the new tab page and our own pages
    Q_INVOKABLE QString lastActiveUrl() const;
    QString bookmarksFilePath() const;

    // ~/.illuminate, which holds spaces.json as well as the spaces directory
    static QString dataDir();
    static QString spacesRootDir();
    static QString storageDirFor(const QString &spaceId);

    // tests point the root somewhere disposable; empty restores the default
    static void setSpacesRootDir(const QString &dir);

signals:
    void nameChanged();
    void colorChanged();
    void themeColorChanged();
    // the theme is ready to be saved
    void themeChanged();

private:
    QString m_id;
    QString m_name;
    QColor m_color;
    QColor m_themeColor;
    QString m_storageDir;
};

#endif // SPACE_H
