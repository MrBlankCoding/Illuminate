# Module sources, QML resources, platform configuration and compiler settings.
qt_add_library(illuminatemodule STATIC
    src/core/browser/BrowserTab.h
    src/core/browser/BrowserTab.cpp
    src/core/browser/BrowserSettings.h
    src/core/browser/BrowserSettings.cpp
    src/core/browser/BrowserController.h
    src/core/browser/BrowserController.cpp
    src/core/browser/theme/BrowserControllerTheme.cpp
    src/core/browser/session/BrowserControllerSession.cpp
    src/core/browser/tabs/BrowserControllerTabs.cpp
    src/core/browser/SearchSuggestionRequest.h
    src/core/browser/SearchSuggestionRequest.cpp
    src/core/browser/InternalPageManager.h
    src/core/browser/InternalPageManager.cpp

    src/core/models/TabModel.h
    src/core/models/TabModel.cpp
    src/core/models/SidebarModel.h
    src/core/models/SidebarModel.cpp
    src/core/models/sidebar/SidebarModelPersistence.cpp
    src/core/models/sidebar/SidebarModelSplits.cpp
    src/core/models/sidebar/SidebarModelFolders.cpp
    src/core/models/sidebar/SidebarModelTree.cpp
    src/core/models/BookmarkModel.h
    src/core/models/BookmarkModel.cpp
    src/core/models/DownloadModel.h
    src/core/models/DownloadModel.cpp



    src/core/menus/MenuItem.h
    src/core/menus/MenuItem.cpp
    src/core/menus/AppMenu.h
    src/core/menus/AppMenu.cpp
    src/core/menus/NativeMenuBar.h
    src/core/menus/NativeMenuBar.cpp
    src/core/menus/ShortcutRegistry.h
    src/core/menus/ShortcutRegistry.cpp

    src/core/system/SystemInfo.h
    src/core/system/SystemInfo.cpp
    src/core/system/MemoryMonitor.h
    src/core/system/MemoryMonitor.cpp
    src/core/system/PermissionHandler.h
    src/core/system/PermissionHandler.cpp
    src/core/system/platform/PermissionHandlerPlatform.cpp

    src/core/spaces/Space.h
    src/core/spaces/Space.cpp
    src/core/spaces/SpaceManager.h
    src/core/spaces/SpaceManager.cpp

    src/core/cef/CefManager.h
    src/core/cef/CefManager.cpp
    src/core/cef/CefBrowserWrapper.h
    src/core/cef/CefBrowserWrapper.cpp
    src/core/cef/browser/CefBrowserWrapperPrivate.h
    src/core/cef/browser/CefBrowserWrapperView.cpp
    src/core/cef/browser/CefBrowserWrapperActions.cpp
    src/core/cef/browser/CefBrowserWrapperDevTools.cpp
    src/core/cef/browser/CefBrowserWrapperLifecycle.cpp
    src/core/cef/browser/CefBrowserWrapperState.cpp
    src/core/cef/browser/CefBrowserWrapperEvents.cpp
    src/core/cef/CefTabClient.h
    src/core/cef/CefTabClient.cpp
    src/core/cef/CefChromeCommands.h
    src/core/cef/CefChromeCommands.cpp
    src/core/cef/CefStrayBrowserClient.h
    src/core/cef/CefStrayBrowserClient.cpp
    src/core/cef/CefHostWindow.h
    src/core/cef/CefHostWindow.cpp
    src/core/cef/CefPopupWindow.h
    src/core/cef/CefPopupWindow.cpp
    src/core/cef/BeforeUnloadRequest.h
    src/core/cef/BeforeUnloadRequest.cpp
    src/core/cef/AudibleTracker.h
    src/core/cef/AudibleTracker.cpp
    src/core/cef/PageMediaProtocol.h
    src/core/cef/CefNativeViewVisibility.h
    src/core/cef/CefQuickItem.h
    src/core/cef/CefQuickItem.cpp
    src/core/cef/CefProfile.h
    src/core/cef/CefProfile.cpp
    src/core/cef/CefMainBrowserId.h
    src/core/cef/CefLoadHandler.h
    src/core/cef/CefLoadHandler.cpp
    src/core/cef/CefDisplayHandler.h
    src/core/cef/CefDisplayHandler.cpp
    src/core/cef/CefContextMenuHandler.h
    src/core/cef/CefContextMenuHandler.cpp
    src/core/cef/CefDownloadHandler.h
    src/core/cef/CefDownloadHandler.cpp
    src/core/cef/CefPermissionHandler.h
    src/core/cef/CefPermissionHandler.cpp
    src/core/cef/CefRequestHandler.h
    src/core/cef/CefRequestHandler.cpp
    src/core/cef/CefRenderProcessHandler.h
    src/core/cef/CefRenderProcessHandler.cpp
    src/core/cef/ExtensionPopupProtocol.h

    src/core/extensions/ExtensionRegistry.h
    src/core/extensions/ExtensionRegistry.cpp

    src/utils/cef_helpers.h
    src/utils/UrlResolver.h
    src/utils/UrlResolver.cpp
    src/utils/BrowserLogger.h
    src/utils/BrowserLogger.cpp
    src/utils/ExternalQmlSingleton.h
    src/utils/LogBridge.h
    src/utils/ShortcutBridge.h
    src/utils/ShortcutBridge.cpp
    src/utils/WebVersion.h
    src/utils/WindowRounding.h
    src/utils/WindowHelper.h
    src/utils/WindowHelper.cpp
    src/utils/PopupCloser.h
    src/utils/PopupCloser.cpp
)

if(APPLE)
    target_sources(illuminatemodule PRIVATE src/utils/WindowRounding_mac.mm)
    target_sources(illuminatemodule PRIVATE src/core/system/PermissionHandler_mac.mm)
    target_sources(illuminatemodule PRIVATE src/core/cef/CefManager_mac.mm src/core/cef/CefBrowserWrapper_mac.mm)
    set_source_files_properties(src/core/system/PermissionHandler_mac.mm PROPERTIES
        SKIP_UNITY_BUILD_INCLUSION ON
        SKIP_PRECOMPILE_HEADERS ON
        COMPILE_OPTIONS "-fobjc-arc"
    )
    target_link_libraries(illuminatemodule PRIVATE
        "-framework Cocoa" "-framework AppKit" "-framework QuartzCore" "-framework AVFoundation" "-framework CoreLocation" "-framework IOSurface")
endif()

if(WIN32)
    target_link_libraries(illuminatemodule PRIVATE dwmapi psapi)
endif()

target_include_directories(illuminatemodule PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    ${CMAKE_CURRENT_SOURCE_DIR}/src/core
    ${CMAKE_CURRENT_SOURCE_DIR}/src/core/browser
    ${CMAKE_CURRENT_SOURCE_DIR}/src/core/cef
    ${CMAKE_CURRENT_SOURCE_DIR}/src/core/extensions
    ${CMAKE_CURRENT_SOURCE_DIR}/src/core/menus
    ${CMAKE_CURRENT_SOURCE_DIR}/src/core/models
    ${CMAKE_CURRENT_SOURCE_DIR}/src/core/system
    ${CMAKE_CURRENT_SOURCE_DIR}/src/core/spaces
    ${CMAKE_CURRENT_SOURCE_DIR}/src/utils
    ${CEF_INCLUDE_PATH}
)

target_link_libraries(illuminatemodule PUBLIC
    Qt6::Core
    Qt6::Gui
    Qt6::Network
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Widgets
    Qt6::PrintSupport
    Qt6::Sql
)

if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    target_link_libraries(illuminatemodule PUBLIC X11::X11)
    target_compile_definitions(illuminatemodule PRIVATE ILLUMINATE_HAS_X11)
endif()

if(TARGET cef::cef)
    target_link_libraries(illuminatemodule PUBLIC cef::cef libcef_dll_wrapper)
endif()

target_precompile_headers(illuminatemodule PRIVATE src/pch.h)

if(ILLUMINATE_ENABLE_COVERAGE)
    if(NOT CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
        message(FATAL_ERROR "ILLUMINATE_ENABLE_COVERAGE currently requires GCC/gcov")
    endif()
    target_compile_options(illuminatemodule PRIVATE --coverage -O0 -g)
    target_link_options(illuminatemodule INTERFACE --coverage)
endif()

if(WIN32 AND CEF_COMPILER_DEFINES)
    set(_cef_defines ${CEF_COMPILER_DEFINES})
    list(REMOVE_ITEM _cef_defines _HAS_EXCEPTIONS=0)
    target_compile_definitions(illuminate PUBLIC ${_cef_defines})
    target_compile_definitions(illuminatemodule PUBLIC ${_cef_defines})
endif()

if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU" OR (CMAKE_CXX_COMPILER_ID MATCHES "Clang" AND NOT CMAKE_CXX_COMPILER_ID STREQUAL "AppleClang"))
    target_compile_options(illuminatemodule PRIVATE -Wno-sfinae-incomplete)
    target_compile_options(illuminate PRIVATE -Wno-sfinae-incomplete)
endif()

set(ILLUMINATE_QML_FILES
    ui/Theme.qml
    ui/ThemePalette.js
    ui/pages/BrowserWindow.qml
    ui/pages/CrashedPage.qml
    ui/pages/SettingsWindow.qml
    ui/pages/SetupPage.qml
    ui/pages/settings/PrivacySettingsPage.qml
    ui/pages/settings/SearchSettingsPage.qml
    ui/pages/settings/ShortcutsSettingsPage.qml
    ui/pages/settings/StartupSettingsPage.qml
    ui/pages/settings/TabsSettingsPage.qml
    ui/pages/settings/GeneralSettingsPage.qml
    ui/pages/settings/StatisticsSettingsPage.qml
    ui/components/LetterAvatar.qml
    ui/components/LucideIcon.qml
    ui/components/PillButton.qml
    ui/components/chrome/ResizeGrips.qml
    ui/components/chrome/WindowControls.qml
    ui/components/chrome/WindowDragRegion.qml
    ui/components/browser/AddressPill.qml
    ui/components/browser/BeforeUnloadPrompt.qml
    ui/components/browser/BrowserWorkspace.qml
    ui/components/browser/EssentialsGrid.qml
    ui/components/browser/ExtensionActionPopup.qml
    ui/components/browser/DownloadsButton.qml
    ui/components/browser/ExtensionsButton.qml
    ui/components/browser/ExtensionsMenu.qml
    ui/components/browser/FolderRow.qml
    ui/components/browser/KeyboardShortcuts.qml
    ui/components/browser/PrintController.qml
    ui/components/browser/PermissionPrompt.qml
    ui/components/browser/Sidebar.qml
    ui/components/browser/SidebarDragPreviews.qml
    ui/components/browser/SidebarButton.qml
    ui/components/browser/SidebarFooter.qml
    ui/components/browser/SidebarMenus.qml
    ui/components/browser/SidebarTitleStrip.qml
    ui/components/browser/SidebarTree.qml
    ui/components/browser/SuggestionProvider.qml
    ui/components/browser/TabItem.qml
    ui/components/browser/TabSlot.qml
    ui/components/browser/WebContentCard.qml
    ui/components/browser/WarmSpaces.qml
    ui/components/browser/WindowDialogs.qml
    ui/components/overlays/AppSubMenu.qml
    ui/components/overlays/CommandBar.qml
    ui/components/overlays/CommandBarLogic.js
    ui/components/overlays/CommandBarResults.qml
    ui/components/overlays/ThemePicker.qml
    ui/components/overlays/ZoomIndicator.qml
    ui/components/overlays/Toast.qml
    ui/components/spaces/SpaceEditor.qml
    ui/components/spaces/SpaceSwitcher.qml
    ui/components/settings/Footnote.qml
    ui/components/settings/NavItem.qml
    ui/components/settings/SectionHeader.qml
    ui/components/settings/SettingCombo.qml
    ui/components/settings/SettingSegmented.qml
    ui/components/settings/SettingField.qml
    ui/components/settings/SettingItem.qml
    ui/components/settings/SettingsCard.qml
    ui/components/settings/SettingsPage.qml
    ui/components/settings/SettingSwitch.qml
    ui/components/settings/ShortcutField.qml
)

set(ILLUMINATE_RESOURCES
    ui/icons/alert-triangle.svg
    ui/icons/arrow-right.svg
    ui/icons/chevron-left.svg
    ui/icons/chevron-right.svg
    ui/icons/copy.svg
    ui/icons/download.svg
    ui/icons/folder.svg
    ui/icons/folder-open.svg
    ui/icons/folder-plus.svg
    ui/icons/more-horizontal.svg
    ui/icons/globe.svg
    ui/icons/lock.svg
    ui/icons/activity.svg
    ui/icons/minus.svg
    ui/icons/monitor.svg
    ui/icons/moon.svg
    ui/icons/more-vertical.svg
    ui/icons/panel-left.svg
    ui/icons/pin.svg
    ui/icons/plus.svg
    ui/icons/puzzle.svg
    ui/icons/rotate-cw.svg
    ui/icons/search.svg
    ui/icons/square.svg
    ui/icons/star-filled.svg
    ui/icons/star.svg
    ui/icons/sun.svg
    ui/icons/x.svg
    ui/icons/volume-2.svg
    ui/icons/volume-x.svg
    ui/icons/check.svg
)

foreach(_f ${ILLUMINATE_QML_FILES} ${ILLUMINATE_RESOURCES})
    string(REGEX REPLACE "^ui/" "" _alias "${_f}")
    set_source_files_properties("${CMAKE_CURRENT_SOURCE_DIR}/${_f}" PROPERTIES
        QT_RESOURCE_ALIAS "${_alias}")
endforeach()

qt_add_qml_module(illuminatemodule
    URI illuminate.ui
    VERSION 1.0
    RESOURCE_PREFIX /
    OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/qml/illuminate/ui"
    QML_FILES
        ${ILLUMINATE_QML_FILES}
    RESOURCES
        ${ILLUMINATE_RESOURCES}
)

if(ILLUMINATE_UNITY_BUILD)
    set_target_properties(illuminatemodule PROPERTIES
        UNITY_BUILD ON
        UNITY_BUILD_BATCH_SIZE ${ILLUMINATE_UNITY_BATCH_SIZE}
    )
    # Split implementation files often share anonymous-namespace helpers/constants.
    # Keep them out of unity batches to avoid symbol collisions.
    set(_unity_skip
        src/core/models/SidebarModel.cpp
        src/core/models/sidebar/SidebarModelPersistence.cpp
        src/core/models/sidebar/SidebarModelSplits.cpp
        src/core/models/sidebar/SidebarModelFolders.cpp
        src/core/models/sidebar/SidebarModelTree.cpp
        src/core/browser/theme/BrowserControllerTheme.cpp
        src/core/browser/session/BrowserControllerSession.cpp
        src/core/browser/tabs/BrowserControllerTabs.cpp
        src/core/cef/browser/CefBrowserWrapperView.cpp
        src/core/cef/browser/CefBrowserWrapperActions.cpp
        src/core/cef/browser/CefBrowserWrapperDevTools.cpp
        src/core/cef/browser/CefBrowserWrapperLifecycle.cpp
        src/core/cef/browser/CefBrowserWrapperState.cpp
        src/core/cef/browser/CefBrowserWrapperEvents.cpp
        src/core/menus/ShortcutRegistry.cpp
        src/core/system/PermissionHandler.cpp
    )
    foreach(_src IN LISTS _unity_skip)
        set_source_files_properties("${CMAKE_CURRENT_SOURCE_DIR}/${_src}" PROPERTIES
            SKIP_UNITY_BUILD_INCLUSION ON)
    endforeach()
endif()

if(ILLUMINATE_PCH)
    target_precompile_headers(illuminatemodule PRIVATE
        <QObject>
        <QString>
        <QUrl>
        <QVariant>
        <QVector>
        <QHash>
        <QList>
        <QPointer>
        <QDebug>
        <memory>
        <string>
        <vector>
        <utility>
        <functional>
    )
endif()
