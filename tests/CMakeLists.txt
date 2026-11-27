find_package(Qt6 REQUIRED COMPONENTS QuickTest Widgets)

qt_add_executable(tst_qmltests main.cpp)

target_compile_definitions(tst_qmltests PRIVATE
    QUICK_TEST_SOURCE_DIR="${CMAKE_CURRENT_SOURCE_DIR}"
)

target_link_libraries(tst_qmltests PRIVATE
    Qt6::Gui
    Qt6::Widgets
    Qt6::QuickTest
    illuminatemodule
    illuminatemoduleplugin
)

add_test(NAME tst_qmltests COMMAND tst_qmltests)

find_package(Qt6 REQUIRED COMPONENTS Test)

qt_add_executable(tst_browsersettings tst_BrowserSettings.cpp)
target_link_libraries(tst_browsersettings PRIVATE Qt6::Test illuminatemodule)
add_test(NAME tst_browsersettings COMMAND tst_browsersettings)

qt_add_executable(tst_browsercontroller tst_BrowserController.cpp)
target_link_libraries(tst_browsercontroller PRIVATE Qt6::Test illuminatemodule)
add_test(NAME tst_browsercontroller COMMAND tst_browsercontroller)

qt_add_executable(tst_permissionhandler tst_PermissionHandler.cpp)
target_link_libraries(tst_permissionhandler PRIVATE Qt6::Test illuminatemodule)
add_test(NAME tst_permissionhandler COMMAND tst_permissionhandler)

qt_add_executable(tst_shortcutbridge tst_ShortcutBridge.cpp)
target_link_libraries(tst_shortcutbridge PRIVATE Qt6::Test Qt6::Quick illuminatemodule)
add_test(NAME tst_shortcutbridge COMMAND tst_shortcutbridge)

qt_add_executable(tst_shortcutregistry tst_ShortcutRegistry.cpp)
target_link_libraries(tst_shortcutregistry PRIVATE Qt6::Test Qt6::Gui illuminatemodule)
add_test(NAME tst_shortcutregistry COMMAND tst_shortcutregistry)

qt_add_executable(tst_tabmodel tst_TabModel.cpp)
target_link_libraries(tst_tabmodel PRIVATE Qt6::Test illuminatemodule)
add_test(NAME tst_tabmodel COMMAND tst_tabmodel)

qt_add_executable(tst_spacemanager tst_SpaceManager.cpp)
target_link_libraries(tst_spacemanager PRIVATE Qt6::Test illuminatemodule)
add_test(NAME tst_spacemanager COMMAND tst_spacemanager)

qt_add_executable(tst_sidebarmodel tst_SidebarModel.cpp)
target_link_libraries(tst_sidebarmodel PRIVATE Qt6::Test illuminatemodule)
add_test(NAME tst_sidebarmodel COMMAND tst_sidebarmodel)

qt_add_executable(tst_chromecommands tst_ChromeCommands.cpp)
target_link_libraries(tst_chromecommands PRIVATE Qt6::Test illuminatemodule)
add_test(NAME tst_chromecommands COMMAND tst_chromecommands)

qt_add_executable(tst_ceftablifecycle tst_CefTabLifecycle.cpp)
target_link_libraries(tst_ceftablifecycle PRIVATE Qt6::Test illuminatemodule)
add_test(NAME tst_ceftablifecycle COMMAND tst_ceftablifecycle)

qt_add_executable(tst_urlresolver tst_UrlResolver.cpp)
target_link_libraries(tst_urlresolver PRIVATE Qt6::Test illuminatemodule)
add_test(NAME tst_urlresolver COMMAND tst_urlresolver)

qt_add_executable(tst_bookmarkmodel tst_BookmarkModel.cpp)
target_link_libraries(tst_bookmarkmodel PRIVATE Qt6::Test illuminatemodule)
add_test(NAME tst_bookmarkmodel COMMAND tst_bookmarkmodel)

qt_add_executable(tst_browsertab tst_BrowserTab.cpp)
target_link_libraries(tst_browsertab PRIVATE Qt6::Test illuminatemodule)
add_test(NAME tst_browsertab COMMAND tst_browsertab)


qt_add_executable(tst_cefprofile tst_CefProfile.cpp)
target_link_libraries(tst_cefprofile PRIVATE Qt6::Test illuminatemodule)
add_test(NAME tst_cefprofile COMMAND tst_cefprofile)

qt_add_executable(tst_extensionregistry tst_ExtensionRegistry.cpp)
target_link_libraries(tst_extensionregistry PRIVATE Qt6::Test illuminatemodule)
add_test(NAME tst_extensionregistry COMMAND tst_extensionregistry)

qt_add_executable(tst_systeminfo tst_SystemInfo.cpp)
target_link_libraries(tst_systeminfo PRIVATE Qt6::Test illuminatemodule)
add_test(NAME tst_systeminfo COMMAND tst_systeminfo)

qt_add_executable(tst_space tst_Space.cpp)
target_link_libraries(tst_space PRIVATE Qt6::Test illuminatemodule)
add_test(NAME tst_space COMMAND tst_space)

qt_add_executable(tst_internalpagemanager tst_InternalPageManager.cpp)
target_link_libraries(tst_internalpagemanager PRIVATE Qt6::Test illuminatemodule)
add_test(NAME tst_internalpagemanager COMMAND tst_internalpagemanager)

qt_add_executable(tst_appmenu tst_AppMenu.cpp)
target_link_libraries(tst_appmenu PRIVATE Qt6::Test Qt6::Widgets illuminatemodule)
# reads KeyboardShortcuts.qml to check every menu action has a handler
target_compile_definitions(tst_appmenu PRIVATE ILLUMINATE_SOURCE_DIR="${PROJECT_SOURCE_DIR}")
add_test(NAME tst_appmenu COMMAND tst_appmenu)

qt_add_executable(tst_cefpopupwindow tst_CefPopupWindow.cpp)
target_link_libraries(tst_cefpopupwindow PRIVATE Qt6::Test illuminatemodule)
add_test(NAME tst_cefpopupwindow COMMAND tst_cefpopupwindow)

qt_add_executable(tst_downloadmodel tst_DownloadModel.cpp)
target_link_libraries(tst_downloadmodel PRIVATE Qt6::Test illuminatemodule)
add_test(NAME tst_downloadmodel COMMAND tst_downloadmodel)

qt_add_executable(tst_beforeunloadrequest tst_BeforeUnloadRequest.cpp)
target_link_libraries(tst_beforeunloadrequest PRIVATE Qt6::Test illuminatemodule)
add_test(NAME tst_beforeunloadrequest COMMAND tst_beforeunloadrequest)

qt_add_executable(tst_audibletracker tst_AudibleTracker.cpp)
target_link_libraries(tst_audibletracker PRIVATE Qt6::Test illuminatemodule)
add_test(NAME tst_audibletracker COMMAND tst_audibletracker)

qt_add_executable(tst_pagehandover tst_PageHandover.cpp)
target_link_libraries(tst_pagehandover PRIVATE Qt6::Test Qt6::Gui Qt6::Quick illuminatemodule)
add_test(NAME tst_pagehandover COMMAND tst_pagehandover)

set(_headless_test_targets
    tst_qmltests tst_shortcutbridge tst_shortcutregistry tst_appmenu tst_pagehandover
)
set_tests_properties(${_headless_test_targets} PROPERTIES
    ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QUICK_BACKEND=software"
)

if(WIN32)
    add_custom_command(TARGET tst_shortcutregistry POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E make_directory
                "$<TARGET_FILE_DIR:tst_shortcutregistry>/platforms"
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "$<TARGET_FILE_DIR:Qt6::Core>/../plugins/platforms/qoffscreen.dll"
                "$<TARGET_FILE_DIR:tst_shortcutregistry>/platforms/"
        COMMENT "Staging the offscreen platform plugin for tst_shortcutregistry"
    )
endif()

if(APPLE AND CEF_FOUND)
    foreach(_test_target tst_qmltests tst_browsersettings tst_browsercontroller tst_permissionhandler tst_shortcutbridge tst_shortcutregistry tst_tabmodel tst_sidebarmodel tst_spacemanager tst_chromecommands tst_ceftablifecycle tst_urlresolver tst_bookmarkmodel tst_browsertab tst_internalpagemanager tst_cefprofile tst_extensionregistry tst_systeminfo tst_space tst_appmenu tst_cefpopupwindow tst_downloadmodel tst_beforeunloadrequest tst_audibletracker tst_pagehandover)
        add_custom_command(TARGET ${_test_target} POST_BUILD
            COMMAND install_name_tool -change
                "@executable_path/../Frameworks/Chromium Embedded Framework.framework/Chromium Embedded Framework"
                "${CEF_BINARY_DIR_RELEASE}/Chromium Embedded Framework.framework/Chromium Embedded Framework"
                "$<TARGET_FILE:${_test_target}>"
            COMMENT "Updating CEF library path for ${_test_target}"
        )
    endforeach()
endif()
