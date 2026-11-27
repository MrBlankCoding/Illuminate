#include "browser/CefBrowserWrapperPrivate.h"

using namespace CefBrowserWrapperPrivate;

void CefBrowserWrapper::showDevTools(const QPoint &inspectAt)
{
    auto host = hostOf(m_browser);
    if (!host)
        return;

    // an empty window info gives DevTools its own top level window;
    // (0,0) opens it without selecting an element
    host->ShowDevTools(CefWindowInfo(), m_client, CefBrowserSettings(), CefPoint(inspectAt.x(), inspectAt.y()));
}

void CefBrowserWrapper::toggleDevTools()
{
    auto host = hostOf(m_browser);
    if (!host)
        return;

    if (host->HasDevTools())
        host->CloseDevTools();
    else
        showDevTools();
}
