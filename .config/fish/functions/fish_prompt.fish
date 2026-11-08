# Zeta theme for Fish
# Port of the supplied zeta.zsh-theme (Skyler Lee, 2015).
# Prompt layout: # user@host: directory <branch [git status]>
#                ζ                                      (time) [short-sha]

function __zeta_box_name
    if test -f "$HOME/.box-name"
        command cat "$HOME/.box-name"
    else
        echo $hostname
    end
end

function __zeta_current_dir
    string replace -- "$HOME" '~' "$PWD"
end

function __zeta_git_info
    set -l branch (command git symbolic-ref --quiet --short HEAD 2>/dev/null)
    if test -z "$branch"
        set branch (command git rev-parse --short HEAD 2>/dev/null)
    end
    if test -z "$branch"
        return
    end

    set_color --bold blue
    printf ' <%s' "$branch"

    set -l porcelain (command git status --porcelain --untracked-files=normal 2>/dev/null)
    if test -z "$porcelain"
        set_color --bold green
        printf ' ✔'
    else
        set_color --bold red
        printf ' ✘ '
        # Keep Zeta's status vocabulary: + added, - deleted, * modified,
        # > renamed, = unmerged, ? untracked.
        set -l status_marks
        for line in $porcelain
            set -l x (string sub -l 1 -- "$line")
            set -l y (string sub -s 2 -l 1 -- "$line")
            if test "$x" = A; or test "$y" = A
                set -a status_marks (set_color --bold green)'+'(set_color normal)
            end
            if test "$x" = D; or test "$y" = D
                set -a status_marks (set_color --bold red)'-'(set_color normal)
            end
            if test "$x" = M; or test "$y" = M
                set -a status_marks (set_color --bold magenta)'*'(set_color normal)
            end
            if test "$x" = R; or test "$y" = R; or test "$x" = C; or test "$y" = C
                set -a status_marks (set_color --bold blue)'>'(set_color normal)
            end
            if test "$x" = U; or test "$y" = U
                set -a status_marks (set_color --bold cyan)'='(set_color normal)
            end
            if test "$x" = '?' ; or test "$y" = '?'
                set -a status_marks (set_color --bold yellow)'?'(set_color normal)
            end
        end
        for mark in $status_marks
            printf '%s' "$mark"
        end
    end
    set_color normal
    printf '>'
end

function fish_prompt
    set -l last_status $status
    set_color blue
    printf '# '
    if test "$USER" = root
        set_color --background red --bold white
    else
        set_color --bold green
    end
    printf '%s' "$USER"
    set_color normal
    set_color blue
    printf '@'
    set_color --bold cyan
    printf '%s' (__zeta_box_name)
    set_color blue
    printf ': '
    set_color --bold yellow
    printf '%s' (__zeta_current_dir)
    set_color normal
    __zeta_git_info
    printf '\n'

    if test $last_status -eq 0
        set_color --bold magenta
    else
        set_color --bold red
    end
    printf 'ζ '
    set_color normal
end
