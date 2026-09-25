# Jenerated Themes for Obsidian

[Obsidian](https://obsidian.md) themes that match the VS Code themes.
[jenerate.py](../../jenerate.py) writes one folder for each palette you generate,
for example `blue-purple/`, holding the theme's `theme.css` and
`manifest.json`. Blue Purple is included; to add other palettes, see
[Getting started](../../README.md#getting-started).

Each theme uses the palette's colors whether Obsidian is set to light or
dark, and tells Obsidian whether the palette is dark or light.

The files are generated from `theme.css.tmpl` and `manifest.json.tmpl` by
[jenerate.py](../../jenerate.py). To change colors, see
[Changing colors](../../README.md#changing-colors).

## Install

The easiest way is `./setup.sh` from the repository root: choose Obsidian, and
it lists the vaults Obsidian knows about. To install by hand:

1. Clone this repository.

   ```bash
   git clone https://github.com/savagejen/jenerated-themes jenerated-themes
   ```

2. Obsidian themes are set per vault, in the vault's `.obsidian/themes/`
   folder. Symlink or copy the palette's folder there, naming it
   "Jenerated" plus the palette's name, to match the name in its
   `manifest.json`. A symlink means later changes to the palette show up
   after you reload the theme. Run these from the same folder where you ran
   `git clone`, with your vault's path in place of `~/Notes`:

   ```bash
   mkdir -p ~/Notes/.obsidian/themes

   # Symlink (ln needs an absolute path, hence $PWD)
   ln -s "$PWD/jenerated-themes/app-themes/obsidian-theme/blue-purple" "$HOME/Notes/.obsidian/themes/Jenerated Blue Purple"

   # Or copy
   cp -r ./jenerated-themes/app-themes/obsidian-theme/blue-purple "$HOME/Notes/.obsidian/themes/Jenerated Blue Purple"
   ```

3. In Obsidian, open **Settings** → **Appearance**, and under **Themes**
   choose **Jenerated Blue Purple**. If it isn't listed, click the reload
   button next to **Themes**, or restart Obsidian.

## How the colors are used

The theme sets Obsidian's CSS variables. Obsidian works out some shades from
the accent itself, from its hue, saturation and lightness, and callouts use
colors as RGB numbers, so the template uses jenerate.py's other color forms:
`{{accent_h}}`, `{{accent_s}}` and `{{accent_l}}`, and `{{red_rgb}}` and so on.
Code blocks use the same colors as the VS Code theme's syntax highlighting.
