// Entry point for the "illuminate Helper*.app" bundles CEF launches for its
// renderer, GPU, plugin and utility sub-processes on macOS.

#include <include/cef_app.h>
#include <include/wrapper/cef_library_loader.h>

#include "CefRenderProcessHandler.h"

namespace {

class HelperApp : public CefApp
{
public:
    // must match CefManager::OnRegisterCustomSchemes in the browser process
    void OnRegisterCustomSchemes(CefRawPtr<CefSchemeRegistrar> registrar) override
    {
        registrar->AddCustomScheme("illuminate", CEF_SCHEME_OPTION_STANDARD | CEF_SCHEME_OPTION_SECURE);
        registrar->AddCustomScheme("newtab", CEF_SCHEME_OPTION_STANDARD | CEF_SCHEME_OPTION_SECURE);
    }

    CefRefPtr<CefRenderProcessHandler> GetRenderProcessHandler() override { return m_renderHandler; }

private:
    CefRefPtr<CefRenderProcessHandler> m_renderHandler = new CefRenderProcessHandlerImpl();
    IMPLEMENT_REFCOUNTING(HelperApp);
};

} // namespace

int main(int argc, char *argv[])
{
    // helpers load the framework at runtime instead of linking it
    CefScopedLibraryLoader libraryLoader;
    if (!libraryLoader.LoadInHelper())
        return 1;

    CefMainArgs mainArgs(argc, argv);
    return CefExecuteProcess(mainArgs, new HelperApp, nullptr);
}
