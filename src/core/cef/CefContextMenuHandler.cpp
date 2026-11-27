#include "CefContextMenuHandler.h"
#include "CefBrowserWrapper.h"

#include <QMetaObject>
#include <QPoint>

#include <include/cef_command_ids.h>

CefContextMenuHandlerImpl::CefContextMenuHandlerImpl(CefBrowserWrapper *wrapper, CefMainBrowserId *mainBrowser)
    : m_wrapper(wrapper), m_mainBrowser(mainBrowser)
{
}

void CefContextMenuHandlerImpl::OnBeforeContextMenu(CefRefPtr<CefBrowser> browser,
                                                    CefRefPtr<CefFrame> frame,
                                                    CefRefPtr<CefContextMenuParams> params,
                                                    CefRefPtr<CefMenuModel> model)
{
    Q_UNUSED(frame);
    Q_UNUSED(params);
    // a native menu takes focus, which closes the popup under it
    if (m_wrapper && m_mainBrowser && m_mainBrowser->matches(browser) && m_wrapper->actionTabId() > 0)
        model->Clear();
}

bool CefContextMenuHandlerImpl::OnContextMenuCommand(CefRefPtr<CefBrowser> browser,
                                                     CefRefPtr<CefFrame> frame,
                                                     CefRefPtr<CefContextMenuParams> params,
                                                     int command_id,
                                                     EventFlags event_flags)
{
    Q_UNUSED(frame);
    Q_UNUSED(event_flags);
    // the DevTools browser inspects itself the Chrome way
    if (command_id != IDC_CONTENT_CONTEXT_INSPECTELEMENT || !m_wrapper || !m_mainBrowser
        || !m_mainBrowser->matches(browser))
        return false;

    const QPoint at(params->GetXCoord(), params->GetYCoord());
    QMetaObject::invokeMethod(m_wrapper, [wrapper = m_wrapper, at]() {
        if (wrapper)
            wrapper->showDevTools(at);
    }, Qt::QueuedConnection);
    return true;
}

void CefContextMenuHandlerImpl::setWrapper(CefBrowserWrapper *wrapper)
{
    m_wrapper = wrapper;
}
