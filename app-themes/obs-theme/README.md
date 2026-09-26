# Jenerated Themes for OBS Studio

Styles for [OBS Studio](https://obsproject.com) 30 and later: the window,
docks, lists, inputs, buttons, tabs, scroll bars and menus, the audio mixer
and its meters, and the preview's background.

[jenerate.py](../../jenerate.py) writes one style for each palette you
generate, for example `jenerated-blue-purple.ovt`. Blue Purple is included;
to add other palettes, see
[Getting started](../../README.md#getting-started).

Each style builds on OBS's own Yami theme (its Light style for light
palettes), so OBS's layout and icons stay as they are and only the colors
change:

| Part of OBS | Palette color |
|-------------|---------------|
| Docks and lists | `bg` |
| Window around the docks | `bg_minimap` |
| Preview background | `bg_chrome` |
| Inputs and buttons | `bg_hover`, with `bg_secondary_hover` when hovered |
| Selected list items and tabs | `bg_selected` |
| Borders | `border` |
| Text | `text`, with `text_muted` for less important text |
| Focus outlines, sliders, progress bars, selected text | `accent` |
| Links | `accent_soft` |
| Audio meters | `green`, `yellow` and `red` |
| Warnings and errors | `yellow` and `red` |

The files are generated from `style.ovt.tmpl` by
[jenerate.py](../../jenerate.py). To change colors, see
[Changing colors](../../README.md#changing-colors).

## Install

The easiest way is `./setup.sh` from the repository root: choose OBS Studio
(under Entertainment). It links the style into OBS's themes folder:

- Linux: `~/.config/obs-studio/themes/`, and, if OBS was installed through
  Flatpak, `~/.var/app/com.obsproject.Studio/config/obs-studio/themes/`
- macOS: `~/Library/Application Support/obs-studio/themes/`

To install by hand, link or copy the palette's `.ovt` file into that folder.

Then restart OBS Studio, and:

1. Open **Settings → Appearance**.
2. Choose **Yami** as the **Theme** and **Jenerated Blue Purple** as the
   **Style**.

After changing the palette, run `./jenerate.py` and restart OBS.
