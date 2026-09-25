# Jenerated Themes for Ptyxis

Terminal palettes for [Ptyxis](https://gitlab.gnome.org/chergert/ptyxis), the
default terminal on Ubuntu 25.10 and later. [jenerate.py](../../jenerate.py)
writes one `<slug>.palette` file for each palette you generate, for example
`blue-purple.palette`. Each uses the same colors as the matching VS Code
theme's built-in terminal.

The palettes only have a dark version, so they look the same whether GNOME is
set to light or dark mode.

The `.palette` files are generated from `palette.tmpl` by
[jenerate.py](../../jenerate.py). To change colors, see
[Changing colors](../../README.md#changing-colors).

## Install

1. Clone this repository. Blue Purple is included; to add other palettes,
   see [Getting started](../../README.md#getting-started).

   ```bash
   git clone https://github.com/savagejen/jenerated-themes jenerated-themes
   ```

2. Symlink or copy the palettes into Ptyxis's palette folder. A symlink means
   later changes to a palette show up after you reopen Ptyxis. After
   generating more palettes, run the command again to add the new ones; after
   `jenerate.py --remove`, delete that palette's file from
   `~/.local/share/org.gnome.Ptyxis/palettes/` too. Run these from the same
   folder where you ran `git clone`.

   ```bash
   mkdir -p ~/.local/share/org.gnome.Ptyxis/palettes

   # Symlink (ln needs an absolute path, hence $PWD)
   ln -sf "$PWD"/jenerated-themes/app-themes/ptyxis-theme/*.palette ~/.local/share/org.gnome.Ptyxis/palettes/

   # Or copy
   cp ./jenerated-themes/app-themes/ptyxis-theme/*.palette ~/.local/share/org.gnome.Ptyxis/palettes/
   ```

3. Close and reopen Ptyxis.

4. Open **Preferences** (`Ctrl+,`), and under **Appearance** choose a
   palette by its name, for example **Blue Purple**. The palette applies to
   the current profile; select it in each profile you want to use it in.

## Palette file format

A `.palette` file is a plain INI file. `Color0` to `Color7` are the normal
ANSI colors (black, red, green, yellow, blue, magenta, cyan, white) and
`Color8` to `Color15` are their bright versions. To add a light variant, move
the color keys in `palette.tmpl` into a `[Dark]` section and add a `[Light]`
section with the same keys.
