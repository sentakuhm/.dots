#!/usr/bin/env bash
# Seed the small data files the dashboard reads. Never overwrites existing files.
#
#   ~/.local/state/sentaku/scheme.json          Tokyo Night colours
#   ~/.local/state/sentaku/wallpaper/path.txt   points at the bundled wallpaper
#   ~/.config/sentaku/shell.json                fonts + glass transparency
#
# Why path.txt: when it is missing, the wallpaper service tries to run a
# `sentaku` command (which does not exist) to pick a wallpaper, and logs an error.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
state="${XDG_STATE_HOME:-$HOME/.local/state}/sentaku"
conf="${XDG_CONFIG_HOME:-$HOME/.config}/sentaku"

mkdir -p "$state/wallpaper" "$conf"

put() { # put <content-source-file> <dest>
    if [ -e "$2" ]; then
        echo "keep    $2  (already exists)"
    else
        cp "$1" "$2"
        echo "created $2"
    fi
}

put "$here/sentaku/scheme.json" "$state/scheme.json"
put "$here/sentaku/shell.json" "$conf/shell.json"

# An existing shell.json is never overwritten, but top-level sections it does not have yet
# (for example "utilities", added with the quick menu) are merged in from the shipped file.
# Keys you already have are left exactly as they are; a .bak copy is made first.
if command -v python3 >/dev/null 2>&1; then
    python3 - "$here/sentaku/shell.json" "$conf/shell.json" <<'PY'
import json, shutil, sys
shipped = json.load(open(sys.argv[1]))
path = sys.argv[2]
try:
    mine = json.load(open(path))
except Exception as e:
    print(f"skip    {path}: not valid JSON ({e}); fix it by hand")
    sys.exit(0)
added = [k for k in shipped if k not in mine]
if added:
    shutil.copy(path, path + ".bak")
    for k in added:
        mine[k] = shipped[k]
    with open(path, "w") as f:
        json.dump(mine, f, indent=2)
        f.write("\n")
    print(f"merged  {path}: added {', '.join(added)} (backup: {path}.bak)")
PY
else
    echo "note    python3 not found: add any new sections from $here/sentaku/shell.json to $conf/shell.json by hand"
fi

if [ -s "$state/wallpaper/path.txt" ]; then
    echo "keep    $state/wallpaper/path.txt  (already exists)"
else
    printf '%s\n' "$here/assets/wallpaper.webp" > "$state/wallpaper/path.txt"
    echo "created $state/wallpaper/path.txt -> $here/assets/wallpaper.webp"
fi

echo
echo "Done. To get the built-in pink palette instead of Tokyo Night, delete $state/scheme.json."
