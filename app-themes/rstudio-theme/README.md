# Jenerated Themes for RStudio

Themes for [RStudio](https://posit.co/products/open-source/rstudio/), with
the same code colors as the VS Code theme: the editor, the gutter,
selections, matching brackets, R Markdown chunks and headings, debugging
and find highlights, and the console and terminal, whose 16 colors are the
palette's own terminal colors. RStudio styles the rest of its window as
dark or light to match the theme.

[jenerate.py](../../jenerate.py) writes one theme for each palette you
generate, for example `jenerated-blue-purple.rstheme`. Blue Purple is
included; to add other palettes, see
[Getting started](../../README.md#getting-started).

An `.rstheme` is CSS with a short header naming the theme and saying
whether it's dark. Each theme has the same parts as RStudio's built-in
themes: the editor's colors, and the rules RStudio adds to every theme it
converts (for chunk, debug and find lines, the terminal, and the console's
256 colors).

The files are generated from `theme.rstheme.tmpl` by
[jenerate.py](../../jenerate.py). To change colors, see
[Changing colors](../../README.md#changing-colors).

## Install

The easiest way is `./setup.sh` from the repository root: choose RStudio
(under Editors). It links the theme into RStudio's themes folder,
`~/.config/rstudio/themes/` on both Linux and macOS (or
`$RSTUDIO_CONFIG_HOME/themes/` if you've set that). To install by hand:

```bash
mkdir -p ~/.config/rstudio/themes
ln -s "$PWD/jenerated-themes/app-themes/rstudio-theme/jenerated-blue-purple.rstheme" ~/.config/rstudio/themes/
```

Or, in RStudio, open **Tools → Global Options → Appearance**, choose
**Add…**, and pick the palette's `.rstheme` file (this copies it instead).

Then, in **Tools → Global Options → Appearance**, choose **Jenerated Blue
Purple** as the **Editor theme**, and **Apply**. Restart RStudio first if
it doesn't appear in the list.

After changing the palette, run `./jenerate.py` and choose the theme again,
or restart RStudio.
