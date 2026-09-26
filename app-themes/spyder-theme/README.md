# Jenerated Themes for Spyder

Syntax highlighting themes for [Spyder](https://www.spyder-ide.org), the
scientific Python IDE, with the same code colors as the VS Code theme: the
editor's background, the current line and cell, occurrences, links,
matching brackets, and keywords, builtins, definitions, comments, strings,
numbers, `self` and magics.

Spyder keeps its syntax themes in its own settings file, `spyder.ini`,
rather than as separate files. [jenerate.py](../../jenerate.py) writes one
file for each palette you generate, for example
`jenerated-blue-purple.ini`, holding that theme's settings in Spyder's own
format, ready to be added. Blue Purple is included; to add other palettes,
see [Getting started](../../README.md#getting-started).

Spyder's interface follows its own dark or light UI theme, which it picks
to match the syntax theme when **Interface theme** is set to **Automatic**
(Tools → Preferences → Appearance).

The files are generated from `scheme.ini.tmpl` by
[jenerate.py](../../jenerate.py). To change colors, see
[Changing colors](../../README.md#changing-colors).

## Install

Close Spyder first: it saves its settings when it closes, which would undo
the change.

The easiest way is `./setup.sh` from the repository root: choose Spyder
(under Editors). It adds the theme to `spyder.ini` as a custom theme (the
same way Spyder's own **Create new theme** does, named `custom-0`,
`custom-1` and so on, so it sits alongside any themes of your own), and
offers to make it the current theme. It backs the file up first (as
`spyder.ini.before-jenerated`). The file is:

- Linux: `~/.config/spyder-py3/config/spyder.ini`
- Linux, if Spyder was installed through Flatpak:
  `~/.var/app/org.spyder_ide.spyder/config/spyder-py3/config/spyder.ini`
- macOS: `~/.spyder-py3/config/spyder.ini`
- Or `$SPYDER_CONFDIR/config/spyder.ini`, if you've set that.

Open Spyder once before running it, so the file exists.

If you didn't make it the current theme, choose **Jenerated Blue Purple**
under **Tools → Preferences → Appearance → Syntax highlighting theme**.

The theme is copied into Spyder's settings, so after changing the palette,
run `./setup.sh` again (with Spyder closed); it updates the same custom
theme instead of adding another.
