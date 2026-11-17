cmake_minimum_required(VERSION 3.19)

# Builds the Sentaku QML plugin (./plugin) used by the dashboard.
# Normally driven by scripts/build-sentaku-plugin.sh.
#
#   cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
#   cmake --build build && sudo cmake --install build
#
# Options:
#   -DVERSION=x.y.z       numeric version baked into the plugin (default 1.0.0)
#   -DINSTALL_QMLDIR=...  QML install dir, relative to the prefix (default lib/qt6/qml)

if(NOT DEFINED VERSION)
    set(VERSION "1.0.0")
endif()
# project(VERSION) only accepts numeric versions: drop a leading "v" if present.
string(REGEX REPLACE "^v" "" VERSION "${VERSION}")

project(sentaku-shell VERSION ${VERSION} LANGUAGES CXX)

include(GNUInstallDirs)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")

set(INSTALL_QMLDIR "${CMAKE_INSTALL_LIBDIR}/qt6/qml" CACHE STRING "QML install dir")

add_compile_definitions(
    QT_NO_CAST_FROM_ASCII
    QT_NO_CAST_TO_ASCII
    QT_NO_CAST_FROM_BYTEARRAY
)

add_compile_options(
    -Wall -Wextra -Wpedantic -Wshadow -Wconversion
    -Wold-style-cast -Wnull-dereference -Wdouble-promotion
    -Wformat=2 -Wfloat-equal -Woverloaded-virtual
    -Wsign-conversion -Wredundant-decls -Wswitch
    -Wunreachable-code
)

if(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    add_compile_options(-Wunused-lambda-capture -Wno-nonportable-include-path)
endif()

add_subdirectory(plugin)
