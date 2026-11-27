#ifndef SPACEMANAGER_H
#define SPACEMANAGER_H

#include <QColor>
#include <QList>
#include <QObject>
#include <QPointer>
#include <QString>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

#include "Space.h"
#include "../utils/ExternalQmlSingleton.h"

class SpaceManager : public QObject, public ExternalQmlSingleton<SpaceManager>
{
    Q_OBJECT
    QML_NAMED_ELEMENT(Spaces)
    QML_SINGLETON
    Q_PROPERTY(QVariantList spaces READ spaces NOTIFY spacesChanged)
    Q_PROPERTY(Space *activeSpace READ activeSpace WRITE setActiveSpace NOTIFY activeSpaceChanged)

public:
    static constexpr int kMaxSpaces = 24;
    explicit SpaceManager(QObject *parent);
    ~SpaceManager() override;

    QVariantList spaces() const;
    Space *activeSpace() const { return m_activeSpace; }
    void setActiveSpace(Space *space);

    Q_INVOKABLE Space *spaceById(const QString &id) const;
    Q_INVOKABLE QColor nextSpaceColor() const;
    Q_INVOKABLE Space *createSpace(const QString &name = {},
                                   const QColor &color = QColor());
    Q_INVOKABLE void deleteSpace(Space *space);
    Q_INVOKABLE void cycleSpace(int delta);

signals:
    void activeSpaceChanged();
    void spacesChanged();

private:
    Space *adopt(const QString &id, const QString &name, const QColor &color);
    void connectSpace(Space *space);
    void load();
    void save() const;

    QList<Space *> m_spaces;
    QPointer<Space> m_activeSpace;
    bool m_loading = false;
};

#endif // SPACEMANAGER_H
