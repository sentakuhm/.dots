# Zeta right prompt: timestamp and current Git commit SHA.
function fish_right_prompt
    set_color blue
    printf '(%s)' (date '+%H:%M:%S')
    set_color normal

    set -l sha (command git rev-parse --short HEAD 2>/dev/null)
    if test -n "$sha"
        printf ' '
        set_color yellow
        printf '[%s]' "$sha"
        set_color normal
    end
    printf ' '
end
