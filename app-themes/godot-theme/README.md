# Jenerated Themes for Godot

Themes for the [Godot](https://godotengine.org) editor (Godot 4), in two
parts that match the VS Code themes:

- a **script editor theme** (`Jenerated-<slug>.tet`), with the same syntax
  colors as the VS Code theme, plus GDScript's own (node paths, annotations
  and so on), the editor background, selection, current line, code
  completion, breakpoints and bookmarks; and
- the **interface colors** (`editor-settings.cfg`): Godot builds its whole
  interface (docks, panels, tabs, buttons, menus) from a base color, an
  accent color and a contrast setting, so these three come from the palette.

[jenerate.py](../../jenerate.py) writes one folder for each palette you
generate, for example `blue-purple/`, holding the two files. Blue Purple is
included; to add other palettes, see
[Getting started](../../README.md#getting-started).

## How the colors are used

| Godot setting | Palette color |
|---------------|---------------|
| Base Color | `bg_sidebar`; Godot shades the backgrounds behind it from it |
| Accent Color | `accent`: selections, focus, highlighted tabs and buttons |
| Contrast | 0.3 for a dark palette, -0.06 for a light one (Godot's own values) |
| Script editor background | `bg` |

Godot works out its interface text and icon colors itself, light or dark to
suit the base color, so they don't come from the palette.

The files are generated from `text-editor.tet.tmpl` and
`editor-settings.cfg.tmpl` by [jenerate.py](../../jenerate.py). To change
colors, see [Changing colors](../../README.md#changing-colors).

## Install

The easiest way is `./setup.sh` from the repository root: choose Godot. It
links the script editor theme where Godot looks for it, and, if Godot has
been opened before and is closed now, offers to set the interface colors and
the script editor theme in Godot's editor settings. It backs the settings up
first (next to them, as `editor_settings-4.x.tres.before-jenerated`), and
prints the command to restore them.

Godot saves its settings when it closes, so close it before running
`./setup.sh`, or the change is undone.

To install by hand, link the script editor theme into Godot's
`text_editor_themes` folder:

```bash
theme="$PWD/jenerated-themes/app-themes/godot-theme/blue-purple/Jenerated-blue-purple.tet"
mkdir -p ~/.config/godot/text_editor_themes
ln -s "$theme" ~/.config/godot/text_editor_themes/
```

On a Mac the folder is `~/Library/Application Support/Godot/text_editor_themes`,
and if Godot was installed through Flatpak it's
`~/.var/app/org.godotengine.Godot/config/godot/text_editor_themes`.

Then, in Godot, open **Editor → Editor Settings** and set:

- **Interface → Theme → Color Preset:** Custom
- **Interface → Theme → Base Color**, **Accent Color** and **Contrast:** the
  values listed at the top of the palette's `editor-settings.cfg`
- **Text Editor → Theme → Color Theme:** Jenerated-blue-purple

The script editor theme is read each time Godot starts, so after changing
the palette and running `./jenerate.py`, restart Godot to see new syntax
colors. The interface colors are copied into Godot's settings, so run
`./setup.sh` again (or change them by hand) to update those.
