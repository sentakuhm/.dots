# ==================================================
# Aliases
# ==================================================

# Cleaning up home folder / tool configuration
alias yarn 'command yarn --use-yarnrc "$XDG_CONFIG_HOME/yarn/config"'
function wget
    command wget --hsts-file="$XDG_CACHE_HOME/wget-hsts" $argv
end

# TeX Live
alias tlinstall 'sudo /usr/local/texlive/2026/bin/x86_64-linux/tlmgr install'
alias tlup 'sudo /usr/local/texlive/2026/bin/x86_64-linux/tlmgr update --all'
alias tllist 'sudo /usr/local/texlive/2026/bin/x86_64-linux/tlmgr update --list'

# Dotfiles
alias dots '/usr/bin/git --git-dir=$HOME/.dots/ --work-tree=$HOME'

# Everyday tools
alias v nvim
alias yy yazi
alias cat bat
alias ff 'clear && fastfetch'
alias ve sudoedit
alias mkdir 'command mkdir -p'
alias ping 'command ping -c 10'
alias less 'command less -R'
alias cls clear
alias reboot 'systemctl reboot'
alias dmesg 'sudo -v; and sudo dmesg --color=always | less'
alias grep 'command grep --color=auto'
alias ls 'eza --colour=always --git --no-filesize --icons=always --no-time --no-user --no-permissions --group-directories-first'

# Gaming
alias umugame 'mangohud gamemoderun umu-run --config "$XDG_CONFIG_HOME/umu/config.toml"'

# Local AI — shared launcher
# Usage: ll fast | ll projm | ll projb
function ll
    set -l mode $argv[1]
    if test -z "$mode"
        echo "usage: ll fast|projm|projb"
        return 1
    end

    set -l model "/Games/Models/Qwen/Qwen3.8-27B-GSQ-RCO-IQ3_XXS-mtp/Qwen3.8-27B-GSQ-RCO-IQ3_XXS-mtp.gguf"
    set -l mmproj "/Games/Models/Qwen/Qwen3.8-27B-GSQ-RCO-IQ3_XXS-mtp/mmproj-Qwen3.8-27B-BF16.gguf"
    set -l name "Qwen3.8 27B GSQ-RCO IQ3_XXS"

    set -l ctx
    set -l batch
    switch $mode
        case fast
            set ctx 41523
            set batch 512
        case projm
            set ctx 65410
            set batch 512
        case projb
            set ctx 131312
            set batch 1024
        case '*'
            echo "usage: ll fast|projm|projb"
            return 1
    end

    llama-server \
        -m "$model" \
        --mmproj "$mmproj" \
        -a "$name" \
        -ngl 999 \
        -fa on \
        --jinja \
        -c $ctx \
        -b $batch \
        -ub $batch \
        -t 6 \
        -tb 6 \
        -np 1 \
        --no-mmproj-offload \
        --spec-type draft-mtp \
        --spec-draft-n-max 2 \
        --spec-draft-p-min 0.75 \
        -ctk q5_1 \
        -ctv q5_1 \
        -ctkd q5_1 \
        -ctvd q5_1 \
        --temp 1.0 \
        --top-p 0.95 \
        --top-k 20 \
        --min-p 0.0 \
        --presence-penalty 0.0 \
        --repeat-penalty 1.0
end

# Optional Canon printer
# alias cjob 'captstatusui -P LBP6020 -e'
