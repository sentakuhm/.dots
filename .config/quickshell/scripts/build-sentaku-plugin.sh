#!/usr/bin/env bash
# Build + install the Sentaku QML plugin (modules Sentaku, Sentaku.Config,
# Sentaku.Services, ...) that the dashboard needs. The source is ./plugin in
# this folder; nothing is downloaded.
#
# Usage:
#   scripts/build-sentaku-plugin.sh
#
# Optional environment:
#   PREFIX=/usr           install prefix (QML modules land in $PREFIX/lib/qt6/qml/Sentaku)
#   BUILD_DIR=...         build directory (default: ~/.cache/sentaku-plugin-build)
#   SENTAKU_VERSION=x.y.z numeric version baked into the plugin (default 1.0.0)
#
# Installing somewhere other than a directory Qt already searches (for example
# PREFIX=$HOME/.local) needs QML_IMPORT_PATH=$PREFIX/lib/qt6/qml in the
# environment that starts Quickshell.
set -euo pipefail

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "missing build tool: $1"; }

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[ -f "$here/CMakeLists.txt" ] && [ -f "$here/plugin/CMakeLists.txt" ] || die "plugin sources not found in $here"

need cmake; need ninja; need pkg-config
command -v g++ >/dev/null 2>&1 || command -v clang++ >/dev/null 2>&1 || die "missing a C++ compiler (g++ or clang++)"

# ---- dependency probe (clear errors beat CMake walls of text) ---------------
missing=()
for pc in libpipewire-0.3 aubio libqalculate; do
    pkg-config --exists "$pc" || missing+=("pkg-config: $pc")
done
pkg-config --exists libcava || pkg-config --exists cava || missing+=("pkg-config: libcava (or cava)")
for mod in Qt6Core Qt6Quick Qt6QuickControls2 Qt6ShaderTools Qt6Multimedia Qt6Sql Qt6Concurrent Qt6DBus Qt6Network; do
    pkg-config --exists "$mod" || missing+=("Qt dev package: $mod")
done
[ -e /usr/include/sensors/sensors.h ] || [ -e /usr/local/include/sensors/sensors.h ] || missing+=("lm_sensors headers (sensors/sensors.h)")
if [ "${#missing[@]}" -gt 0 ]; then
    printf 'Missing build dependencies:\n' >&2
    printf '  - %s\n' "${missing[@]}" >&2
    die "install them and re-run"
fi

qtver="$(pkg-config --modversion Qt6Core)"
if [ "$(printf '%s\n6.9\n' "$qtver" | sort -V | head -n1)" != "6.9" ]; then
    die "Qt $qtver found, but the plugin needs Qt 6.9 or newer"
fi

prefix="${PREFIX:-/usr}"
build="${BUILD_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/sentaku-plugin-build}"
version="${SENTAKU_VERSION:-1.0.0}"

echo ">> source : $here (plugin/)"
echo ">> build  : $build"
echo ">> prefix : $prefix   (QML modules -> $prefix/lib/qt6/qml/Sentaku)"
echo ">> Qt     : $qtver"

cmake -S "$here" -B "$build" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$prefix" \
    -DVERSION="$version"
cmake --build "$build"

if [ -w "$prefix" ] || [ "$(id -u)" -eq 0 ]; then
    cmake --install "$build"
else
    echo ">> installing with sudo (needs write access to $prefix)"
    sudo cmake --install "$build"
fi

echo
echo "Plugin installed. Next:"
echo "  1. install M3Shapes (AUR: qt6-m3shapes-git) and the Material Symbols font"
echo "  2. scripts/install-sentaku-data.sh"
echo "  3. scripts/dashboard-doctor.sh   (verifies everything), then restart quickshell"
echo
echo "To remove the plugin later: sudo rm -rf $prefix/lib/qt6/qml/Sentaku"
