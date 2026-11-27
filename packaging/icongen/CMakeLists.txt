cmake_minimum_required(VERSION 3.16)
project(illuminate_icongen LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Svg)

qt_add_executable(icongen icongen.cpp)

target_link_libraries(icongen PRIVATE Qt6::Core Qt6::Gui Qt6::Svg)
