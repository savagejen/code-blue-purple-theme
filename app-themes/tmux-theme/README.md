# Jenerated Themes for tmux

Colors for [tmux](https://github.com/tmux/tmux), the terminal multiplexer,
to match the terminal and VS Code themes: the status line and its window
list, pane borders, messages and the command prompt, the copy-mode
selection and search matches, popups and menus, the clock and the pane
numbers. What runs inside the panes keeps your terminal's colors.

[jenerate.py](../../jenerate.py) writes one folder for each palette you
generate, for example `blue-purple/`, holding `jenerated-blue-purple.conf`.
Blue Purple is included; to add other palettes, see
[Getting started](../../README.md#getting-started).

## How the colors are used

| tmux | Palette color |
|------|---------------|
| Status line | `text_subtle` on `bg_chrome` |
| Other windows in the status line | `text_muted` |
| Current window | `text_strong` on `bg_selected`, bold |
| Windows with activity, or a bell | `yellow`, `red` |
| Pane borders, the active pane's | `border`, `accent` |
| Messages and the command prompt, popups and menus | `text` on `bg_widget` |
| Copy-mode selection | `text_strong` on `selection` |
| Search matches, the current one | `magenta`, `accent` |
| Selected menu item | `text_bright` on `accent` |

Each setting uses `set -gq`, so a version of tmux without it skips it
quietly: popups need tmux 3.3, and menus 3.4. Only colors are set, so your
status line's layout and contents stay as they are. A tmux theme plugin
that sets the same colors will override these, or be overridden, depending
on which your settings load last.

The file is generated from `colors.conf.tmpl` by
[jenerate.py](../../jenerate.py). To change colors, see
[Changing colors](../../README.md#changing-colors).

## Install

The easiest way is `./setup.sh` from the repository root: choose tmux. It
links the palette's colors to `~/.config/tmux/jenerated-colors.conf`, and
adds a line that loads them to the end of your tmux settings: `~/.tmux.conf`
if you have one, or else `~/.config/tmux/tmux.conf` (the same order tmux
reads them in). If you have neither, it creates `~/.tmux.conf`; if you have
one, it asks first, and your settings in it are kept. If tmux is running, it
offers to load the colors into it right away.

To install by hand:

```bash
mkdir -p ~/.config/tmux
ln -s "$PWD/jenerated-themes/app-themes/tmux-theme/blue-purple/jenerated-blue-purple.conf" ~/.config/tmux/jenerated-colors.conf
echo 'source-file -q ~/.config/tmux/jenerated-colors.conf' >>~/.tmux.conf
tmux source-file ~/.config/tmux/jenerated-colors.conf   # if tmux is running
```

After changing the palette, run `./jenerate.py` and load the file into tmux
again (or restart it). To switch palettes, run `./setup.sh` again. To go
back to tmux's own colors, remove the `source-file` line and restart tmux.
