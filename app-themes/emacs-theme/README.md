# Jenerated Themes for Emacs

Custom themes for [GNU Emacs](https://www.gnu.org/software/emacs/), with the
same code colors as the VS Code theme: the editor, the cursor and region,
the current line and line numbers, the mode line, header line, minibuffer
and tabs, searching and matching parentheses, diffs, and the terminal
colors that shells and compilation output use inside Emacs.

[jenerate.py](../../jenerate.py) writes one theme for each palette you
generate, for example `jenerated-blue-purple-theme.el`, a standard Emacs
custom theme named `jenerated-blue-purple`. Blue Purple is included; to add
other palettes, see [Getting started](../../README.md#getting-started).

The theme also sets faces for built-in packages Emacs loads on demand, such
as diffs and tab bars; Emacs keeps them until those packages load. It works
in graphical Emacs and in a terminal (where Emacs picks the nearest colors
the terminal has, if it doesn't show 24-bit color).

The files are generated from `theme.el.tmpl` by
[jenerate.py](../../jenerate.py). To change colors, see
[Changing colors](../../README.md#changing-colors).

## Install

The easiest way is `./setup.sh` from the repository root: choose Emacs
(under Editors). It links the theme into Emacs's own folder, where Emacs
looks for themes without any other setup. That's `~/.emacs.d/` if you have
it (or a `~/.emacs` file), otherwise `~/.config/emacs/` if you have that,
and otherwise `~/.emacs.d/`, the same way Emacs chooses. To install by
hand, link or copy the palette's `-theme.el` file into that folder.

Then, in Emacs:

1. Run **M-x load-theme RET jenerated-blue-purple RET**. Emacs asks whether
   to trust the theme's code before loading it; answer yes, and yes again
   to treat it as safe so it doesn't ask next time.
2. To keep it, run **M-x customize-themes**, tick `jenerated-blue-purple`
   (and untick any other theme), and choose **Save Theme Settings**.

Or add `(load-theme 'jenerated-blue-purple t)` to your init file.

After changing the palette, run `./jenerate.py` and load the theme again.
