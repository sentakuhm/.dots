#!/usr/bin/env bash
# Enumerate desktop entries (.desktop files) and emit a JSON array:
#   [{id, name, icon, exec, categories, keywords, generic, comment, terminal}]
#
# - Local entries (~/.local/share/applications) override system ones with the
#   same id (first directory in the list wins).
# - Entries with NoDisplay / Hidden set, or without a Name, are skipped.
# - Icon names are kept as desktop-entry theme names. Quickshell resolves them
#   at runtime through the active Qt platform icon theme; absolute paths are
#   preserved when they point to an existing file.
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

    # Keep the desktop entry icon name intact. Quickshell resolves it through
    # the active Qt platform icon theme (KDE/Papirus-Dark in this setup).

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
