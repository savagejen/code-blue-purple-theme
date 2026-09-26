# Jenerated Themes for zsh

Colors for the zsh command line, to match the terminal and VS Code themes:

- **zsh-syntax-highlighting** and **fast-syntax-highlighting**, which color
  what you type as you type it: commands, strings, options, paths, comments,
  and commands that don't exist; and
- **zsh-autosuggestions**, which shows the rest of a line you've typed
  before in a dim color.

These are plugins, each installed separately; the theme colors whichever of
them you use. zsh on its own colors little else, and your prompt is left
alone, so it works with Starship, Powerlevel10k or any prompt of your own.

[jenerate.py](../../jenerate.py) writes one folder for each palette you
generate, for example `blue-purple/`, holding `jenerated-blue-purple.zsh`
(for zsh-syntax-highlighting and zsh-autosuggestions) and
`jenerated-blue-purple.ini` (a fast-syntax-highlighting theme). Blue Purple is
included; to add other palettes, see
[Getting started](../../README.md#getting-started).

## How the colors are used

| What you type | Palette color |
|---------------|---------------|
| Commands, functions, aliases and builtins | `accent_light`, like functions in the other themes |
| Keywords (`if`, `for`, `while`) | `accent_soft` |
| Strings | `green` |
| Options (`-a`, `--all`), and variables in strings | `orange` |
| Commands that don't exist | `red`, bold |
| Paths | `text`, underlined |
| Operators (`\|`, `;`, `>`) | `text_subtle` |
| Comments, and autosuggestions | `text_muted` |

The colors are `#rrggbb`, which terminals with 24-bit color show exactly.
On a terminal that doesn't set `COLORTERM` to say it has 24-bit color, the
zsh file loads zsh's `nearcolor` module, which picks the nearest color the
terminal has.

The files are generated from `colors.zsh.tmpl` and `fast-theme.ini.tmpl` by
[jenerate.py](../../jenerate.py). To change colors, see
[Changing colors](../../README.md#changing-colors).

## Install

The easiest way is `./setup.sh` from the repository root: choose zsh (under
Terminals and command-line tools). It:

1. links the zsh file to `~/.config/zsh/jenerated-colors.zsh`, and adds a
   line to the end of `~/.zshrc` that loads it (creating `~/.zshrc` if
   needed, and asking first if you already have one);
2. links the fast-syntax-highlighting theme to
   `~/.config/fsh/jenerated-colors.ini`, and, if you use
   fast-syntax-highlighting, switches it to the theme.

Then open a new terminal. To install by hand:

```bash
mkdir -p ~/.config/zsh ~/.config/fsh
ln -s "$PWD/jenerated-themes/app-themes/zsh-theme/blue-purple/jenerated-blue-purple.zsh" ~/.config/zsh/jenerated-colors.zsh
ln -s "$PWD/jenerated-themes/app-themes/zsh-theme/blue-purple/jenerated-blue-purple.ini" ~/.config/fsh/jenerated-colors.ini
echo 'source ~/.config/zsh/jenerated-colors.zsh' >>~/.zshrc
```

For fast-syntax-highlighting, then run `fast-theme XDG:jenerated-colors` in
zsh.

The zsh file can be loaded before or after the plugins. After changing the
palette, run `./jenerate.py` and open a new terminal; if you use
fast-syntax-highlighting, run `./setup.sh` again (or `fast-theme
XDG:jenerated-colors`), since it keeps its own copy of the theme.
