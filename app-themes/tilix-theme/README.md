# Jenerated Themes for Tilix

Color schemes for [Tilix](https://gnunn1.github.io/tilix-web/), the tiling
terminal for Linux. [jenerate.py](../../jenerate.py) writes one `<slug>.json`
file for each palette you generate, for example `blue-purple.json`. Each uses
the same colors as the matching VS Code theme's built-in terminal and the
Ptyxis palette, and shows up in Tilix as "Jenerated" plus the palette's name.

The schemes only have a dark version, so they look the same whether GNOME is
set to light or dark mode.

The `.json` files are generated from `scheme.json.tmpl` by
[jenerate.py](../../jenerate.py). To change colors, see
[Changing colors](../../README.md#changing-colors).

## Install

The easiest way is `./setup.sh` from the repository root: choose Tilix. To
install by hand:

1. Clone this repository. Blue Purple is included; to add other palettes,
   see [Getting started](../../README.md#getting-started).

   ```bash
   git clone https://github.com/savagejen/jenerated-themes jenerated-themes
   ```

2. Symlink or copy the scheme into Tilix's schemes folder. A symlink means
   later changes to the palette show up after you restart Tilix. The
   `jenerated-` prefix keeps it from replacing a scheme of your own with the
   same name. Run these from the same folder where you ran `git clone`.

   ```bash
   mkdir -p ~/.config/tilix/schemes

   # Symlink (ln needs an absolute path, hence $PWD)
   ln -s "$PWD/jenerated-themes/app-themes/tilix-theme/blue-purple.json" ~/.config/tilix/schemes/jenerated-blue-purple.json

   # Or copy
   cp ./jenerated-themes/app-themes/tilix-theme/blue-purple.json ~/.config/tilix/schemes/jenerated-blue-purple.json
   ```

3. Close every Tilix window and open Tilix again; it only reads schemes when
   it starts.

4. Open **Preferences**, choose your profile under **Profiles**, and on the
   **Color** tab choose **Jenerated Blue Purple** as the color scheme. Tilix
   copies the scheme's colors into the profile, so repeat this for each
   profile, and choose the scheme again after changing the palette.

## Scheme file format

A Tilix scheme is a JSON file. `palette` holds the 16 ANSI colors: the
normal colors (black, red, green, yellow, blue, magenta, cyan, white) and
then their bright versions. The cursor uses the palette's accent, and
selected text uses its selection color.
