# ==================================================
# Environment
# Dots: https://github.com/sentakuhm/.dots
# ==================================================

# XDG base directories (define these before variables that use them)
set -gx XDG_CONFIG_HOME "$HOME/.config"
set -gx XDG_DATA_HOME "$HOME/.local/share"
set -gx XDG_STATE_HOME "$HOME/.local/state"
set -gx XDG_CACHE_HOME "$HOME/.cache"

# Default applications
set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx TERMINAL foot
set -gx BROWSER firefox

# Firefox / graphics (enable manually if needed)
# set -gx MOZ_DISABLE_RDD_SANDBOX 1
# set -gx LIBVA_DRIVER_NAME nvidia
# set -gx NVD_BACKEND direct
# set -gx CUDA_DISABLE_PERF_BOOST 1

# Local AI / graphics
set -gx LD_PRELOAD /usr/lib/libgamemode.so

# XDG application locations
set -gx W3M_DIR "$XDG_STATE_HOME/w3m"
set -gx GNUPGHOME "$XDG_DATA_HOME/gnupg"
set -gx GTK2_RC_FILES "$XDG_CONFIG_HOME/gtk-2.0/gtkrc"
set -gx _JAVA_OPTIONS "-Djava.util.prefs.userRoot=$XDG_CONFIG_HOME/java"
set -gx TERMINFO "$XDG_DATA_HOME/terminfo"
set -gx TERMINFO_DIRS "$XDG_DATA_HOME/terminfo:/usr/share/terminfo"
set -gx WINEPREFIX "$XDG_DATA_HOME/wineprefixes/default"
set -gx TEXMFVAR "$XDG_CACHE_HOME/texlive/texmf-var"
set -gx TEXMFHOME "$XDG_DATA_HOME/texmf"
set -gx TEXMFCONFIG "$XDG_CONFIG_HOME/texlive/texmf-config"
set -gx PARALLEL_HOME "$XDG_CONFIG_HOME/parallel"
set -gx LESSHISTFILE -
set -gx WGETRC "$XDG_CONFIG_HOME/wgetrc"
set -gx PASSWORD_STORE_DIR "$XDG_DATA_HOME/pass"

# Language toolchains
set -gx GOPATH "$XDG_DATA_HOME/go"
set -gx GOMODCACHE "$XDG_CACHE_HOME/go/mod"
set -gx CARGO_HOME "$XDG_DATA_HOME/cargo"
set -gx RUSTUP_HOME "$XDG_DATA_HOME/rustup"
set -gx NPM_CONFIG_USERCONFIG "$XDG_CONFIG_HOME/npm/npmrc"
set -gx N_PREFIX "$HOME/.local/bin/n"
set -gx COPILOT_HOME "$XDG_CONFIG_HOME/copilot"
set -gx CLAUDE_CONFIG_DIR "$XDG_CONFIG_HOME/claude"

# REA (reverse-engineering agents)
# Ghidra resolves the JDK from PATH; JAVA_HOME is intentionally not pinned.
# set -gx JAVA_HOME /usr/lib/jvm/default
# set -gx GHIDRA_INSTALL_DIR "$XDG_DATA_HOME/ghidra/ghidra_12.1.4_PUBLIC"
