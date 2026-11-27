#pragma once

#include <include/cef_browser.h>
#include <atomic>

class CefMainBrowserId
{
public:
    // Claims |id| as the page's own browser. False when one is already claimed.
    bool claim(int id)
    {
        int expected = 0;
        return m_id.compare_exchange_strong(expected, id);
    }

    // Gives the id up if it still belongs to |browser|.
    bool release(const CefRefPtr<CefBrowser> &browser)
    {
        int expected = browser->GetIdentifier();
        return m_id.compare_exchange_strong(expected, 0);
    }

    // False if |browser| is not the main claimed browser or before the page's browser exists.
    bool matches(const CefRefPtr<CefBrowser> &browser) const
    {
        const int id = m_id.load();
        return id != 0 && browser && browser->GetIdentifier() == id;
    }

private:
    std::atomic<int> m_id{0};
};
