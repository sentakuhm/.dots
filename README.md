# .dots

Dotfiles repo. Git dir lives at `~/.dots` (bare), worktree is `$HOME`.

## What's in here

| Area | Configs |
| --- | --- |
| Shell | fish (`conf.d`, functions, prompt), tmux |
| WM | hyprland (config, modules, scripts, shaders) + quickshell, hyprlock, hyprpaper, hyprlauncher |
| Terminals/Viewers | kitty, yazi, bat, fastfetch |
| Editor | nvim |
| Media | mpv (+ uosc), pulse, MangoHud, gamemode |
| System | git, pacman, npm, wgetrc, fontconfig, xdg-desktop-portal, opencode |

## Setting up a new machine

```
git clone --separate-git-dir=$HOME/.dots https://github.com/sentakuhm/.dots.git tmpdots
rsync --recursive --verbose --exclude '.git' tmpdots/ $HOME/
rm -r tmpdots
```

`git` is required. `rsync` is required.

## Updating

Pull latest:

```
git -C $HOME/.dots pull
```

Save local changes:

```
git add .
git commit -m "message"
git push
```
