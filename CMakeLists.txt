cmake_minimum_required(VERSION 3.17)
if(APPLE)
    set(ILLUMINATE_MACOS_DEPLOYMENT_TARGET "26.0" CACHE STRING
        "Minimum macOS version supported by the Illuminate app")
    if(NOT CMAKE_OSX_DEPLOYMENT_TARGET)
        set(CMAKE_OSX_DEPLOYMENT_TARGET "${ILLUMINATE_MACOS_DEPLOYMENT_TARGET}")
    endif()
endif()

project(illuminate VERSION 1.0.0 LANGUAGES C CXX)

if(APPLE)
    set(ILLUMINATE_DEPLOYMENT_TARGET "${CMAKE_OSX_DEPLOYMENT_TARGET}")

    enable_language(OBJCXX)
endif()

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

option(ILLUMINATE_UNITY_BUILD "Build illuminatemodule as a unity build" ON)
option(ILLUMINATE_PCH "Use precompiled headers for illuminatemodule" ON)
set(ILLUMINATE_UNITY_BATCH_SIZE 8 CACHE STRING "Unity build batch size for illuminatemodule")

if(MSVC)
    if(CMAKE_GENERATOR MATCHES "Visual Studio")
        add_compile_options($<$<COMPILE_LANGUAGE:C,CXX>:/MP>)
    endif()
    if(POLICY CMP0141)
        cmake_policy(SET CMP0141 NEW)
        set(CMAKE_MSVC_DEBUG_INFORMATION_FORMAT "Embedded")
    endif()
endif()

include(GNUInstallDirs)
include(CTest)
find_package(Qt6 6.8 REQUIRED COMPONENTS
    Core Gui Network Qml Quick QuickControls2
    Widgets PrintSupport Sql
)

if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    find_package(X11 REQUIRED)
endif()


if(DEFINED ENV{CEF_ROOT})
    set(CEF_ROOT $ENV{CEF_ROOT})
elseif(DEFINED CEF_ROOT)
    # Accept -DCEF_ROOT=<path> from the command line
endif()

if(NOT CEF_ROOT)
    message(FATAL_ERROR
        "CEF is required to build Illuminate. Set CEF_ROOT to a CEF binary distribution, "
        "or run ./install-cef.sh and use the printed installation path.")
endif()

if(WIN32 AND NOT DEFINED CEF_RUNTIME_LIBRARY_FLAG)
    set(CEF_RUNTIME_LIBRARY_FLAG "/MD" CACHE STRING "CEF MSVC runtime flag")
endif()
list(APPEND CMAKE_MODULE_PATH "${CEF_ROOT}/cmake")
set(CEF_DIR "${CEF_ROOT}")
find_package(CEF REQUIRED)
set(CEF_FOUND ON)

if(APPLE)
    set(CMAKE_OSX_DEPLOYMENT_TARGET "${ILLUMINATE_DEPLOYMENT_TARGET}")
    list(FILTER CEF_COMPILER_FLAGS EXCLUDE REGEX "^-mmacosx-version-min=")
endif()

option(USE_CEF_DEBUG "Link the Debug CEF framework (for lldb symbolication)" OFF)
option(ILLUMINATE_ENABLE_COVERAGE "Instrument first-party C++ code for coverage reporting" OFF)
if(CEF_FOUND)
    add_subdirectory(${CEF_LIBCEF_DLL_WRAPPER_PATH} libcef_dll_wrapper)

    if(USE_CEF_DEBUG AND NOT CEF_BINARY_DIR_DEBUG)
        message(FATAL_ERROR "USE_CEF_DEBUG=ON but CEF_BINARY_DIR_DEBUG is unset; "
                            "is the Debug framework present under CEF_ROOT?")
    endif()

    if(OS_MAC)
        if(USE_CEF_DEBUG)
            set(_CEF_FW_BIN_DIR "${CEF_BINARY_DIR_DEBUG}")
        else()
            set(_CEF_FW_BIN_DIR "${CEF_BINARY_DIR_RELEASE}")
        endif()
        set(_CEF_FW_PATH "${_CEF_FW_BIN_DIR}/Chromium Embedded Framework.framework")
        add_library(cef::cef UNKNOWN IMPORTED)
        set_target_properties(cef::cef PROPERTIES
            IMPORTED_LOCATION "${_CEF_FW_PATH}/Chromium Embedded Framework"
            INTERFACE_INCLUDE_DIRECTORIES "${CEF_INCLUDE_PATH}"
        )
        set_property(TARGET cef::cef APPEND PROPERTY
            INTERFACE_LINK_OPTIONS "-F${_CEF_FW_BIN_DIR}")
        list(APPEND CEF_FRAMEWORK_LIBS "Chromium Embedded Framework")
    else()
        ADD_LOGICAL_TARGET(libcef "${CEF_LIB_DEBUG}" "${CEF_LIB_RELEASE}")
        add_library(cef::cef ALIAS libcef)
        target_include_directories(libcef INTERFACE "${CEF_INCLUDE_PATH}")
    endif()

endif()

qt_standard_project_setup()
qt_policy(SET QTP0004 NEW)

qt_add_executable(illuminate
    src/main.cpp
)

target_precompile_headers(illuminate PRIVATE src/pch.h)

if(WIN32)
    set(ILLUMINATE_ICON "${CMAKE_CURRENT_SOURCE_DIR}/packaging/icons/AppIcon.ico")
    if(NOT EXISTS "${ILLUMINATE_ICON}")
        message(FATAL_ERROR "Missing Windows app icon: ${ILLUMINATE_ICON}")
    endif()
    configure_file(packaging/windows/illuminate.rc.in
                   "${CMAKE_CURRENT_BINARY_DIR}/illuminate.rc" @ONLY)
    target_sources(illuminate PRIVATE "${CMAKE_CURRENT_BINARY_DIR}/illuminate.rc")
endif()

target_include_directories(illuminate PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)
target_compile_definitions(illuminate PRIVATE ILLUMINATE_VERSION="${PROJECT_VERSION}")

target_link_libraries(illuminate PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Network
    Qt6::Qml
    Qt6::Quick
    Qt6::Widgets
    illuminatemodule
    illuminatemoduleplugin
)

if(TARGET cef::cef)
    target_link_libraries(illuminate PRIVATE cef::cef libcef_dll_wrapper)
endif()

if(OS_MAC AND CEF_FOUND)
    set_target_properties(illuminate PROPERTIES
        BUILD_RPATH "@executable_path/../Frameworks"
        INSTALL_RPATH "@executable_path/../Frameworks"
    )

    add_custom_command(TARGET illuminate POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E rm -rf
            "$<TARGET_FILE_DIR:illuminate>/../Frameworks/Chromium Embedded Framework.framework"
        COMMAND ${CMAKE_COMMAND} -E copy_directory
            "${_CEF_FW_BIN_DIR}/Chromium Embedded Framework.framework"
            "$<TARGET_FILE_DIR:illuminate>/../Frameworks/Chromium Embedded Framework.framework/Versions/A"
        COMMAND ${CMAKE_COMMAND} -E make_directory
            "$<TARGET_FILE_DIR:illuminate>/../Frameworks/Chromium Embedded Framework.framework/Versions"
        COMMAND ln -sf "A" "$<TARGET_FILE_DIR:illuminate>/../Frameworks/Chromium Embedded Framework.framework/Versions/Current"
        COMMAND ln -sf "Versions/A/Chromium Embedded Framework" "$<TARGET_FILE_DIR:illuminate>/../Frameworks/Chromium Embedded Framework.framework/Chromium Embedded Framework"
        COMMAND ln -sf "Versions/A/Libraries" "$<TARGET_FILE_DIR:illuminate>/../Frameworks/Chromium Embedded Framework.framework/Libraries"
        COMMAND ln -sf "Versions/A/Resources" "$<TARGET_FILE_DIR:illuminate>/../Frameworks/Chromium Embedded Framework.framework/Resources"
        COMMENT "Copying Chromium Embedded Framework.framework into the bundle with proper structure"
    )

    if(EXISTS "${_CEF_FW_BIN_DIR}/Chromium Embedded Framework.framework/Info.plist")
        add_custom_command(TARGET illuminate POST_BUILD
            COMMAND ln -sf "Versions/A/Info.plist" "$<TARGET_FILE_DIR:illuminate>/../Frameworks/Chromium Embedded Framework.framework/Info.plist"
            COMMENT "Linking CEF framework Info.plist"
            VERBATIM
        )
    endif()

    foreach(_suffix_list ${CEF_HELPER_APP_SUFFIXES})
        string(REPLACE ":" ";" _suffix_list ${_suffix_list})
        list(GET _suffix_list 0 _name_suffix)
        list(GET _suffix_list 1 _target_suffix)
        list(GET _suffix_list 2 _plist_suffix)

        set(_helper_target "illuminate_Helper${_target_suffix}")
        set(_helper_output_name "illuminate Helper${_name_suffix}")

        set(_helper_info_plist "${CMAKE_CURRENT_BINARY_DIR}/helper-Info${_target_suffix}.plist")
        file(READ "${CMAKE_CURRENT_SOURCE_DIR}/packaging/helper-Info.plist.in" _plist_contents)
        string(REPLACE "\${EXECUTABLE_NAME}" "${_helper_output_name}" _plist_contents "${_plist_contents}")
        string(REPLACE "\${BUNDLE_ID_SUFFIX}" "${_plist_suffix}" _plist_contents "${_plist_contents}")
        string(REPLACE "\${VERSION}" "${PROJECT_VERSION}" _plist_contents "${_plist_contents}")
        string(REPLACE "\${MIN_SYSTEM_VERSION}" "${ILLUMINATE_DEPLOYMENT_TARGET}" _plist_contents "${_plist_contents}")
        file(WRITE "${_helper_info_plist}" "${_plist_contents}")

        add_executable(${_helper_target} MACOSX_BUNDLE
            src/cef_helper/process_helper_mac.cpp
            src/core/cef/CefRenderProcessHandler.cpp)
        target_include_directories(${_helper_target} PRIVATE
            "${CEF_INCLUDE_PATH}" "${CMAKE_CURRENT_SOURCE_DIR}/src/core/cef")
        target_link_libraries(${_helper_target} PRIVATE cef::cef libcef_dll_wrapper "-framework Cocoa")
        set_target_properties(${_helper_target} PROPERTIES
            AUTOMOC OFF
            OUTPUT_NAME "${_helper_output_name}"
            MACOSX_BUNDLE_INFO_PLIST "${_helper_info_plist}"
        )

        add_dependencies(illuminate ${_helper_target})
        set(_helper_staged "$<TARGET_FILE_DIR:illuminate>/../Frameworks/${_helper_output_name}.app")
        add_custom_command(TARGET illuminate POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E rm -rf "${_helper_staged}"
            COMMAND ${CMAKE_COMMAND} -E copy_directory
                "$<TARGET_BUNDLE_DIR:${_helper_target}>"
                "${_helper_staged}"
            COMMENT "Copying ${_helper_output_name}.app into the bundle"
            VERBATIM
        )

        add_custom_command(TARGET illuminate POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E make_directory "${_helper_staged}/Contents/Frameworks"
            COMMAND ${CMAKE_COMMAND} -E rm -rf "${_helper_staged}/Contents/Frameworks/Chromium Embedded Framework.framework"
            COMMAND ${CMAKE_COMMAND} -E create_symlink
                "../../../Chromium Embedded Framework.framework"
                "${_helper_staged}/Contents/Frameworks/Chromium Embedded Framework.framework"
            COMMENT "Symlinking Chromium Embedded Framework.framework into ${_helper_output_name}.app"
            VERBATIM
        )
    endforeach()
endif()

if(WIN32 AND CEF_FOUND)
    set(_cef_stage_dir "$<TARGET_FILE_DIR:illuminate>")
    COPY_FILES(illuminate "${CEF_BINARY_FILES}" "${CEF_BINARY_DIR}" "${_cef_stage_dir}")
    COPY_FILES(illuminate "${CEF_RESOURCE_FILES}" "${CEF_RESOURCE_DIR}" "${_cef_stage_dir}")

    set(_cef_install_files "")
    foreach(_cef_file IN LISTS CEF_BINARY_FILES)
        list(APPEND _cef_install_files "${CEF_BINARY_DIR_RELEASE}/${_cef_file}")
    endforeach()
    foreach(_cef_file IN LISTS CEF_RESOURCE_FILES)
        if(_cef_file STREQUAL "locales")
            install(DIRECTORY "${CEF_RESOURCE_DIR}/locales"
                    DESTINATION "${CMAKE_INSTALL_BINDIR}")
        else()
            list(APPEND _cef_install_files "${CEF_RESOURCE_DIR}/${_cef_file}")
        endif()
    endforeach()
    install(FILES ${_cef_install_files} DESTINATION "${CMAKE_INSTALL_BINDIR}")
endif()

set(ILLUMINATE_RUNTIME_DESTINATION "${CMAKE_INSTALL_BINDIR}")
if(UNIX AND NOT APPLE AND CEF_FOUND)
    set(ILLUMINATE_RUNTIME_DESTINATION "${CMAKE_INSTALL_LIBDIR}/illuminate")
    set(_cef_stage_dir "$<TARGET_FILE_DIR:illuminate>")
    # settings.no_sandbox is set, so the setuid sandbox helper isn't needed
    set(_cef_linux_binaries ${CEF_BINARY_FILES})
    list(REMOVE_ITEM _cef_linux_binaries "chrome-sandbox")
    COPY_FILES(illuminate "${_cef_linux_binaries}" "${CEF_BINARY_DIR}" "${_cef_stage_dir}")
    COPY_FILES(illuminate "${CEF_RESOURCE_FILES}" "${CEF_RESOURCE_DIR}" "${_cef_stage_dir}")
    set_target_properties(illuminate PROPERTIES INSTALL_RPATH "\$ORIGIN")

    set(_cef_install_files "")
    foreach(_cef_file IN LISTS _cef_linux_binaries)
        list(APPEND _cef_install_files "${CEF_BINARY_DIR_RELEASE}/${_cef_file}")
    endforeach()
    foreach(_cef_file IN LISTS CEF_RESOURCE_FILES)
        if(_cef_file STREQUAL "locales")
            install(DIRECTORY "${CEF_RESOURCE_DIR}/locales"
                    DESTINATION "${ILLUMINATE_RUNTIME_DESTINATION}")
        else()
            list(APPEND _cef_install_files "${CEF_RESOURCE_DIR}/${_cef_file}")
        endif()
    endforeach()
    install(FILES ${_cef_install_files} DESTINATION "${ILLUMINATE_RUNTIME_DESTINATION}")
    install(CODE "
        set(_bin \"\$ENV{DESTDIR}\${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_BINDIR}\")
        file(MAKE_DIRECTORY \"\${_bin}\")
        file(CREATE_LINK \"../${ILLUMINATE_RUNTIME_DESTINATION}/illuminate\" \"\${_bin}/illuminate\" SYMBOLIC)
    ")
endif()

set_target_properties(illuminate PROPERTIES
    WIN32_EXECUTABLE TRUE
)

if(APPLE)
    set_target_properties(illuminate PROPERTIES
        MACOSX_BUNDLE TRUE
        MACOSX_BUNDLE_BUNDLE_NAME "illuminate"
        MACOSX_BUNDLE_GUI_IDENTIFIER "local.illuminate.illuminate"
        MACOSX_BUNDLE_BUNDLE_VERSION "${PROJECT_VERSION}"
        MACOSX_BUNDLE_SHORT_VERSION_STRING "${PROJECT_VERSION}"
        MACOSX_BUNDLE_ICON_FILE "AppIcon"
        MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/packaging/Info.plist.in"
    )
endif()

if(APPLE)
    set(APP_ICON "${CMAKE_CURRENT_SOURCE_DIR}/packaging/icons/AppIcon.icns")
    if(NOT EXISTS "${APP_ICON}")
        message(FATAL_ERROR "Missing app icon: ${APP_ICON}")
    endif()
    add_custom_command(TARGET illuminate POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${APP_ICON}"
                "$<TARGET_BUNDLE_DIR:illuminate>/Contents/Resources/AppIcon.icns"
        COMMENT "Installing AppIcon.icns into the bundle"
    )
endif()

set_source_files_properties(ui/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

include(cmake/IlluminateModule.cmake)

install(TARGETS illuminate
    BUNDLE  DESTINATION .
    RUNTIME DESTINATION ${ILLUMINATE_RUNTIME_DESTINATION}
)

if(UNIX AND NOT APPLE)
    install(FILES packaging/illuminate.desktop
            DESTINATION "${CMAKE_INSTALL_DATADIR}/applications")
    install(FILES packaging/icons/illuminate.svg
            DESTINATION "${CMAKE_INSTALL_DATADIR}/icons/hicolor/scalable/apps")
else()
    qt_generate_deploy_qml_app_script(
        TARGET illuminate
        OUTPUT_SCRIPT ILLUMINATE_DEPLOY_SCRIPT
        NO_UNSUPPORTED_PLATFORM_ERROR
    )
    install(SCRIPT ${ILLUMINATE_DEPLOY_SCRIPT})
endif()

if(BUILD_TESTING)
    add_subdirectory(tests)
endif()
