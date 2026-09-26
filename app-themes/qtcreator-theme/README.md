# Jenerated Themes for Qt Creator

Color schemes for [Qt Creator](https://www.qt.io/product/development-tools)'s
text editor, with the same code colors as the VS Code theme: C++, QML and
JavaScript, the current line and line numbers, selections, search results,
matching parentheses, disabled code, diffs and version control logs, and
the underlines for errors, warnings and info.

[jenerate.py](../../jenerate.py) writes one color scheme for each palette
you generate, for example `jenerated-blue-purple.xml`. Blue Purple is
included; to add other palettes, see
[Getting started](../../README.md#getting-started).

This colors the editor. The rest of Qt Creator's window comes from its own
UI theme, whose format is tied to Qt Creator's internal design files and
changes between versions, so choose Qt Creator's built-in **Dark** or
**Light** theme to match the palette.

The files are generated from `color-scheme.xml.tmpl` by
[jenerate.py](../../jenerate.py). To change colors, see
[Changing colors](../../README.md#changing-colors).

## Install

The easiest way is `./setup.sh` from the repository root: choose Qt Creator
(under Editors). It links the color scheme into Qt Creator's styles folder,
`~/.config/QtProject/qtcreator/styles/` (on macOS too), and, if Qt Creator
was installed through Flatpak, into
`~/.var/app/io.qt.QtCreator/config/QtProject/qtcreator/styles/`. To install
by hand, link or copy the palette's `.xml` file into that folder.

Then, in Qt Creator:

1. Open **Edit → Preferences** (**Qt Creator → Settings** on a Mac, **Tools
   → Options** in older versions) **→ Text Editor → Font & Colors**.
2. Choose **Jenerated Blue Purple** as the **Color Scheme**. Restart Qt
   Creator first if it doesn't appear.
3. For the rest of the window, choose **Dark** or **Light** under
   **Environment → Interface → Theme**.

After changing the palette, run `./jenerate.py` and choose the scheme
again, or restart Qt Creator.
