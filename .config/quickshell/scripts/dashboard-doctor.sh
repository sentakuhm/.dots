#!/usr/bin/env bash
# Checks everything the dashboard needs and says exactly what is missing.
# Exit status: 0 = all required pieces found, 1 = something required is missing.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0
ok()   { printf '  [ ok ] %s\n' "$*"; }
bad()  { printf '  [FAIL] %s\n' "$*"; fail=1; }
warn() { printf '  [warn] %s\n' "$*"; }

# ---- QML import path candidates ---------------------------------------------
dirs=()
IFS=':' read -r -a extra <<< "${QML_IMPORT_PATH:-}:${QML2_IMPORT_PATH:-}"
for d in "${extra[@]}"; do [ -n "$d" ] && dirs+=("$d"); done
for q in qmake6 qmake-qt6 qtpaths6; do
    if command -v "$q" >/dev/null 2>&1; then
        d="$($q -query QT_INSTALL_QML 2>/dev/null || true)"
        [ -n "$d" ] && dirs+=("$d")
    fi
done
dirs+=(/usr/lib/qt6/qml /usr/lib64/qt6/qml /usr/lib/x86_64-linux-gnu/qt6/qml /usr/local/lib/qt6/qml "$HOME/.local/lib/qt6/qml")

has_module() { # has_module Dir/Sub
    local d
    for d in "${dirs[@]}"; do [ -f "$d/$1/qmldir" ] && return 0; done
    return 1
}

echo "Quickshell"
if command -v quickshell >/dev/null 2>&1; then
    ok "$(quickshell --version 2>/dev/null | head -n1)"
    warn "the dashboard code targets a recent Quickshell (the git version, not an older tagged release); if QML errors mention unknown types/properties, update Quickshell"
else
    bad "quickshell not found in PATH"
fi

echo "Sentaku QML plugin (build with scripts/build-sentaku-plugin.sh)"
for m in Sentaku Sentaku/Config Sentaku/Services Sentaku/Components Sentaku/Blobs \
         Sentaku/Multimedia Sentaku/Images Sentaku/Models Sentaku/I18n Sentaku/Settings Sentaku/State Sentaku/Shaders; do
    if has_module "$m"; then ok "${m//\//.}"; else bad "${m//\//.} not installed"; fi
done

echo "M3Shapes (AUR: qt6-m3shapes-git)"
if has_module M3Shapes; then ok "M3Shapes"; else bad "M3Shapes not installed"; fi

echo "Quickshell Qt add-ons"
has_module QtMultimedia && ok "QtMultimedia" || warn "QtMultimedia QML module not found (qt6-multimedia)"
has_module QtQuick/Controls && ok "QtQuick.Controls" || warn "QtQuick.Controls not found (qt6-declarative)"

echo "Fonts"
if command -v fc-list >/dev/null 2>&1; then
    fonts="$(fc-list : family)"
    grep -qi 'Material Symbols Rounded' <<< "$fonts" && ok "Material Symbols Rounded" \
        || bad "Material Symbols Rounded missing - every dashboard icon is a ligature name and shows as plain text without it (Symbols Nerd Font cannot replace it)"
    grep -qi 'JetBrainsMono Nerd Font' <<< "$fonts" && ok "JetBrainsMono Nerd Font" || warn "JetBrainsMono Nerd Font not found (used for mono + clock via sentaku/shell.json)"
    grep -qi 'Symbols Nerd Font' <<< "$fonts" && ok "Symbols Nerd Font (used by the rest of Senta)" || warn "Symbols Nerd Font not found"
else
    warn "fc-list not available, cannot check fonts"
fi

echo "Data files (scripts/install-sentaku-data.sh)"
state="${XDG_STATE_HOME:-$HOME/.local/state}/sentaku"
conf="${XDG_CONFIG_HOME:-$HOME/.config}/sentaku"
[ -s "$state/scheme.json" ] && ok "$state/scheme.json" || warn "no scheme.json: the dashboard will use its built-in default (pink) palette instead of Tokyo Night"
if [ -s "$state/wallpaper/path.txt" ]; then ok "$state/wallpaper/path.txt"
else warn "no wallpaper/path.txt: the wallpaper service will try to run a 'sentaku' command that does not exist (harmless, but noisy in the log)"; fi
[ -s "$conf/shell.json" ] && ok "$conf/shell.json" || warn "no shell.json: default fonts (Rubik / CaskaydiaCove) and opaque panel"
if [ -s "$conf/shell.json" ] && ! grep -q '"utilities"' "$conf/shell.json"; then
    warn "shell.json has no \"utilities\" section: the quick menu will show the screen-recorder card (needs an external tool) and inert toggles; run scripts/install-sentaku-data.sh to merge it"
fi

echo "Quick menu + Mando settings (runtime tools)"
if command -v nmcli >/dev/null 2>&1; then ok "nmcli (Wi-Fi toggle, Network page)"; else warn "nmcli not found: the Wi-Fi toggle and Mando's Network page need NetworkManager"; fi
if command -v bluetoothctl >/dev/null 2>&1; then ok "bluetoothctl (BlueZ: Bluetooth toggle, Connected devices page)"; else warn "bluetoothctl not found: the Bluetooth toggle and Connected devices page need BlueZ"; fi

echo "Shell files"
for f in plugin/CMakeLists.txt modules/dashboard/Content.qml modules/sentadash/DashboardHost.qml components/DashboardSlot.qml \
         modules/sentadash/UtilitiesHost.qml components/UtilitiesSlot.qml modules/utilities/Content.qml modules/mando/Mando.qml \
         daemons/GameMode.qml daemons/IdleInhibit.qml services/Colours.qml services/Nmcli.qml assets/google-sans-flex; do
    [ -e "$here/$f" ] && ok "$f" || bad "$f missing"
done

echo "Hyprland rules"
hypr="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
for ns in senta-dashboard senta-utilities; do
    if grep -rqs "$ns" "$hypr" 2>/dev/null; then ok "layer rule for $ns found"
    else warn "no layer rule for $ns in ~/.config/hypr (panel works, but without glass blur); see hyprland-blur-snippet.lua"; fi
done
if grep -rqs 'Mando' "$hypr" 2>/dev/null; then ok "window rule for Mando found"
else warn "no window rule for Mando in ~/.config/hypr (the settings window will tile); see hyprland-windowrules-snippet.lua"; fi

echo
if [ "$fail" -eq 0 ]; then echo "All required pieces found. Restart quickshell and hover the bottom centre of the screen."; else echo "Fix the [FAIL] items above, then restart quickshell."; fi
exit "$fail"
