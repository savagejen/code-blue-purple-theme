# Jenerated Themes for JetBrains Apps

Themes for the JetBrains apps built on the IntelliJ Platform, version 2023.1
or later:

- IntelliJ IDEA
- Android Studio
- PyCharm
- WebStorm
- PhpStorm
- GoLand
- RubyMine
- CLion
- Rider
- DataGrip
- DataSpell
- RustRover

(Not Fleet, which isn't built on the IntelliJ Platform and has its own theme
format.) Each theme is a small plugin with two parts that match the VS Code
themes:

- a **UI theme** for the window, tool windows, tabs, trees, buttons, popups
  and status bar, and
- an **editor color scheme** for the code, the gutter, search results and the
  console, which the UI theme switches to automatically.

[jenerate.py](../../jenerate.py) writes one folder for each palette you
generate, for example `blue-purple/`, holding the plugin's files:

- `META-INF/plugin.xml`, which describes the plugin,
- `jenerated-<slug>.theme.json`, the UI theme, and
- `jenerated-<slug>.xml`, the editor color scheme.

Blue Purple is included; to add other palettes, see
[Getting started](../../README.md#getting-started).

The files are generated from `plugin.xml.tmpl`, `theme.json.tmpl` and
`editor-scheme.xml.tmpl` by [jenerate.py](../../jenerate.py). To change
colors, see [Changing colors](../../README.md#changing-colors).

## How the colors are used

The UI theme builds on the IDE's own dark theme for the New UI
(`"parentTheme": "ExperimentalDark"`), which defines the whole UI in terms of
a set of named colors: `Gray1` to `Gray14` from darkest to lightest, and
shades of `Blue`, `Green`, `Yellow`, `Red`, `Orange`, `Purple` and `Teal`. The
theme redefines those names with the palette's colors, so every part of the
IDE follows the palette:

- the grays are the palette's backgrounds (`bg`, `bg_sidebar`, `bg_hover`,
  ...) and then its text colors (`text_faint` up to `text_bright`),
- the blues are the accent colors, used for selection, focus, default buttons
  and links, and
- the other colors are the palette's `green`, `yellow`, `red`, `orange`,
  `magenta` and `cyan`; their darkest shades, used as tinted backgrounds, are
  those colors made translucent.

The window's toolbar and the status bar use `bg_chrome`, as in VS Code.

The editor color scheme builds on Darcula, and sets the same syntax colors as
the VS Code theme, and the same 16 console colors as the terminal themes.
The themes only have a dark version.

## Install

Blue Purple's plugin is included, ready to install:
[jenerated-blue-purple.jar](jenerated-blue-purple.jar). For other palettes,
the easiest way is `./setup.sh` from the repository root: choose
JetBrains Apps, and it packages the plugin as
`app-themes/jetbrains-theme/jenerated-<slug>.jar`. To package it by hand, zip
the contents of the palette's folder (not the folder itself):

```bash
cd app-themes/jetbrains-theme/blue-purple
zip -r ../jenerated-blue-purple.jar .
```

Then, in the app:

1. Open **Settings → Plugins**, click the gear icon, and choose
   **Install Plugin from Disk…**.
2. Choose the `.jar`, and restart the app if it asks.
3. Open **Settings → Appearance & Behavior → Appearance**, and choose
   **Jenerated Blue Purple** as the theme. Its editor colors come with it.
Note: You may need to select the theme after installing it.

After changing a palette, package and install the `.jar` again; it replaces
the version you installed.
