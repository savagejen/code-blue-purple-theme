# Jenerated Themes for Sublime Text

Color schemes for [Sublime Text](https://www.sublimetext.com), with the same
syntax colors as the VS Code theme: the editor's background, text, caret,
current line, selection, gutter, indent guides, find results, matching
brackets and tags, and the diff markers in the gutter.

Sublime Text 4 comes with a UI theme called **Adaptive**, which takes the
window's colors (sidebar, tabs, panels) from the color scheme, so choosing
it alongside the color scheme themes the whole window.

[jenerate.py](../../jenerate.py) writes one color scheme for each palette
you generate, for example `jenerated-blue-purple.sublime-color-scheme`.
Blue Purple is included; to add other palettes, see
[Getting started](../../README.md#getting-started).

The files are generated from `color-scheme.tmpl` by
[jenerate.py](../../jenerate.py). To change colors, see
[Changing colors](../../README.md#changing-colors).

## Install

The easiest way is `./setup.sh` from the repository root: choose Sublime
Text (under Editors). It links the color scheme into Sublime Text's
`Packages/User` folder:

- Linux: `~/.config/sublime-text/Packages/User/` (and
  `~/.config/sublime-text-3/Packages/User/` for Sublime Text 3, if you have
  it)
- Linux, if Sublime Text was installed through Flatpak:
  `~/.var/app/com.sublimetext.three/config/sublime-text/Packages/User/`
- Linux, if Sublime Text was installed through Snap:
  `~/snap/sublime-text/current/.config/sublime-text/Packages/User/`
- macOS: `~/Library/Application Support/Sublime Text/Packages/User/`

To install by hand, link or copy the palette's `.sublime-color-scheme`
file into that folder.

Then, in Sublime Text:

1. Open the command palette (**Ctrl+Shift+P**, or **Cmd+Shift+P** on a
   Mac), choose **UI: Select Color Scheme**, then **Jenerated Blue
   Purple**.
2. For the sidebar and tabs to match, choose **UI: Select Theme**, then
   **Adaptive**.

Sublime Text reloads the color scheme when its file changes, so after
changing the palette, running `./jenerate.py` is enough.
