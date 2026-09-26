# Jenerated Themes for Xcode

Themes for [Xcode](https://developer.apple.com/xcode/), on macOS, with the
same code colors as the VS Code theme: the editor's background, current
line, caret and selection, every kind of code Xcode colors separately
(keywords, strings, numbers, types, functions, constants, variables,
macros, attributes, comments, doc comments, regular expressions and more),
the debug console, Quick Help's documentation, and the markers in the
scrollbar.

[jenerate.py](../../jenerate.py) writes one theme for each palette you
generate, for example `jenerated-blue-purple.xccolortheme`. Blue Purple is
included; to add other palettes, see
[Getting started](../../README.md#getting-started).

Each theme uses SF Mono, Xcode's usual font, at 13 points. You can change
the font and size in Xcode's settings after choosing the theme.

The files are generated from `theme.xccolortheme.tmpl` by
[jenerate.py](../../jenerate.py). To change colors, see
[Changing colors](../../README.md#changing-colors).

## Install

The easiest way is `./setup.sh` from the repository root, on your Mac:
choose Xcode (under Editors). It links the theme into Xcode's themes
folder, `~/Library/Developer/Xcode/UserData/FontAndColorThemes/`, named
after the palette (for example `Jenerated Blue Purple.xccolortheme`), since
Xcode lists themes by their file names. To install by hand:

```bash
mkdir -p ~/Library/Developer/Xcode/UserData/FontAndColorThemes
ln -s "$PWD/jenerated-themes/app-themes/xcode-theme/jenerated-blue-purple.xccolortheme" \
  ~/Library/Developer/Xcode/UserData/FontAndColorThemes/"Jenerated Blue Purple.xccolortheme"
```

Then quit and reopen Xcode (it finds new themes when it starts), open
**Xcode → Settings** (**Preferences** in older versions) **→ Themes**, and
choose **Jenerated Blue Purple**.

After changing the palette, run `./jenerate.py` and restart Xcode.
