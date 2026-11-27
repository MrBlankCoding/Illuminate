#pragma once

#include <QQuickItem>
#include <QPointer>

class CefBrowserWrapper;

// CEF: QQuickItem embedding native child window for CEF browser.
class CefQuickItem : public QQuickItem
{
    Q_OBJECT
    QML_NAMED_ELEMENT(CefQuickItem)

    Q_PROPERTY(CefBrowserWrapper *browser READ browser WRITE setBrowser NOTIFY browserChanged)

public:
    explicit CefQuickItem(QQuickItem *parent = nullptr);
    ~CefQuickItem() override;

    CefBrowserWrapper *browser() const { return m_browser; }
    void setBrowser(CefBrowserWrapper *browser);

signals:
    void browserChanged();

protected:
    void geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry) override;
    void itemChange(ItemChange change, const ItemChangeData &data) override;
    void componentComplete() override;

private:
    void initializeBrowserHost();
    void updateNativeGeometry();

    QPointer<CefBrowserWrapper> m_browser;
    bool m_initialized = false;
};
