#!/usr/bin/env bash
# Enumerate desktop entries (.desktop files) and emit a JSON array:
#   [{id, name, icon, exec, categories, keywords, generic, comment, terminal}]
#
# - Local entries (~/.local/share/applications) override system ones with the
#   same id (first directory in the list wins).
# - Entries with NoDisplay / Hidden set, or without a Name, are skipped.
# - Icons are resolved to absolute file paths by following the system icon
#   theme chain (see icon_themes below), because Quickshell's image://icon/
#   provider does not produce icons in this setup. Unresolved icons are
#   emitted as "" and the launcher shows the app's initial letter instead.
set -euo pipefail

dirs=(
  "${XDG_DATA_HOME:-$HOME/.local/share}/applications"
  "/usr/local/share/applications"
  "/usr/share/applications"
)

bool() {
  # .desktop booleans are case-insensitive ("true"/"True").
  [ "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" = "true" ]
}

# Icon resolution, mirroring the chain the KDE platform theme would use
# (kdeglobals: Papirus-Dark, which inherits breeze-dark, hicolor) plus the
# monochrome Papirus set as a last resort.
icon_themes=(
  "${XDG_DATA_HOME:-$HOME/.local/share}/icons/Papirus-Dark"
  "/usr/share/icons/Papirus-Dark"
  "/usr/share/icons/breeze-dark"
  "/usr/share/icons/hicolor"
  "/usr/share/icons/Papirus"
)
icon_sizes=(48 64 32 24 128 256 16)
icon_exts=(png webp svg)

resolve_icon() {
  # $1 = Icon= value (theme name(s), absolute path, or entry-relative path)
  # $2 = directory of the .desktop file
  # Prints the first file found, or nothing.
  local name theme size ext layout found=""
  # Desktop entries may list several names, most specific first.
  for name in $1; do
    case "$name" in
      /*)  found="$name" ;;
      */*) found="$2/$name" ;;
      *)
        for theme in "${icon_themes[@]}"; do
          [ -d "$theme" ] || continue
          for size in "${icon_sizes[@]}"; do
            for ext in "${icon_exts[@]}"; do
              for layout in \
                        "$theme/$size/apps/$name.$ext" \
                        "$theme/apps/$size/$name.$ext" \
                        "$theme/${size}x${size}/apps/$name.$ext" \
                        "$theme/apps/${size}x${size}/$name.$ext"; do
                [ -f "$layout" ] && found="$layout" && break 4
              done
            done
          done
        done
        ;;
    esac
    [ -n "$found" ] && break
  done
  if [ -n "$found" ] && [ -f "$found" ]; then
    printf '%s' "$found"
  fi
}

entries=()
declare -A seen

for dir in "${dirs[@]}"; do
  [ -d "$dir" ] || continue
  for f in "$dir"/*.desktop; do
    [ -f "$f" ] || continue
    id="${f##*/}"
    id="${id%.desktop}"
    [ -n "${seen[$id]:-}" ] && continue
    seen[$id]=1

    name="" exec="" icon="" categories="" keywords="" generic="" comment=""
    terminal=false nodisplay=false hidden=false
    while IFS= read -r line; do
      case "$line" in
        Name=*)        [ -z "$name" ] && name="${line#Name=}" ;;
        Exec=*)        [ -z "$exec" ] && exec="${line#Exec=}" ;;
        Icon=*)        [ -z "$icon" ] && icon="${line#Icon=}" ;;
        Categories=*)  [ -z "$categories" ] && categories="${line#Categories=}" ;;
        Keywords=*)    [ -z "$keywords" ] && keywords="${line#Keywords=}" ;;
        GenericName=*) [ -z "$generic" ] && generic="${line#GenericName=}" ;;
        Comment=*)     [ -z "$comment" ] && comment="${line#Comment=}" ;;
        Terminal=*)    [ "${line#Terminal=}" = "true" ] && terminal=true ;;
        NoDisplay=*)   bool "${line#NoDisplay=}" && nodisplay=true ;;
        Hidden=*)      bool "${line#Hidden=}" && hidden=true ;;
      esac
    done < "$f"

    [ -z "$name" ] && continue
    [ "$nodisplay" = true ] && continue
    [ "$hidden" = true ] && continue

    icon="$(resolve_icon "$icon" "${f%/*}")"

    # Strip XDG field codes (%u %U %F %f ...) from the exec string so it can be
    # handed straight to `sh -c`.
    exec="$(printf '%s' "$exec" | sed -E 's/ %([uUfFoOikcnm1-9])//g')"

    entries+=("$(jq -n \
      --arg id "$id" \
      --arg name "$name" \
      --arg icon "$icon" \
      --arg exec "$exec" \
      --arg categories "$categories" \
      --arg keywords "$keywords" \
      --arg generic "$generic" \
      --arg comment "$comment" \
      --argjson terminal "$terminal" \
      '{id:$id, name:$name, icon:$icon, exec:$exec, categories:$categories, keywords:$keywords, generic:$generic, comment:$comment, terminal:$terminal}')")
  done
done

if [ "${#entries[@]}" -eq 0 ]; then
  printf '[]'
  exit 0
fi

printf '%s\n' "${entries[@]}" | jq -s 'sort_by(.name | ascii_downcase)'
