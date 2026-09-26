# Jenerated Themes for fzf

Colors for [fzf](https://github.com/junegunn/fzf), the command-line fuzzy
finder, to match the terminal and VS Code themes: the list, the current
line, matched letters, the prompt, pointer and markers, borders and the
preview window. They apply wherever fzf runs: in the terminal, in its shell
key bindings (such as Ctrl+R and Ctrl+T), and in editor plugins like
fzf.vim that use your fzf options.

[jenerate.py](../../jenerate.py) writes one folder for each palette you
generate, for example `blue-purple/`, holding `jenerated-blue-purple.sh`
(for bash and zsh) and `jenerated-blue-purple.fish` (for fish). Blue Purple
is included; to add other palettes, see
[Getting started](../../README.md#getting-started).

## How the colors are used

fzf takes its colors from the `--color` option in `FZF_DEFAULT_OPTS`, the
environment variable it reads its default options from. The theme's files
add a `--color` option there, after any options of your own, so your other
settings are kept. Loading them again (for example in a shell started from
another) doesn't add the colors twice.

| fzf color | Palette color |
|-----------|---------------|
| List text, background | `text_subtle`, `bg` |
| Current line text, background | `text_strong`, `bg_selected` |
| Matched letters | `magenta`, like search matches in the other themes |
| Prompt, pointer | `accent` |
| Multi-select marker | `green` |
| Info line, borders | `text_muted`, `border` |
| Preview window | `text`, `bg` |

The theme only uses color names fzf has had since version 0.29 (the one in
Ubuntu 22.04). Older versions of fzf refuse a `--color` option with a name
they don't know, and use none of its colors.

The files are generated from `fzf.sh.tmpl` and `fzf.fish.tmpl` by
[jenerate.py](../../jenerate.py). To change colors, see
[Changing colors](../../README.md#changing-colors).

## Install

The easiest way is `./setup.sh` from the repository root: choose fzf. It
links the palette's colors to `~/.config/fzf/jenerated-colors.sh`, and then:

- for **bash** and **zsh**, offers to add a line to `~/.bashrc` or
  `~/.zshrc` that loads them;
- for **fish**, links the fish version into `~/.config/fish/conf.d`, which
  fish loads by itself.

Then open a new terminal. To install by hand, link the palette's file and
load it from your shell's startup file:

```bash
mkdir -p ~/.config/fzf
ln -s "$PWD/jenerated-themes/app-themes/fzf-theme/blue-purple/jenerated-blue-purple.sh" ~/.config/fzf/jenerated-colors.sh
echo '. ~/.config/fzf/jenerated-colors.sh' >>~/.bashrc   # or ~/.zshrc
```

For fish, link `jenerated-blue-purple.fish` into `~/.config/fish/conf.d/`
instead.

After changing the palette, run `./jenerate.py` and open a new terminal. To
switch palettes, run `./setup.sh` again. To go back to fzf's own colors,
remove the line from your startup file (or the link from fish's `conf.d`).
