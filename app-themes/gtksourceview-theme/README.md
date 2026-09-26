# Jenerated Themes for gedit, GNOME Text Editor and Xed

Color schemes for the text editors built on GtkSourceView, GNOME's text
editing library: **gedit**, **GNOME Text Editor** and **Xed**, and also
Pluma, Meld and others that use it. They color the text area like the
VS Code theme: the same syntax colors, background, selection, current
line, line numbers and search matches. GNOME Text Editor goes further, and
recolors its whole window (header bar, sidebar and popovers) from the
scheme.

[jenerate.py](../../jenerate.py) writes one folder for each palette you
generate, for example `blue-purple/`. Blue Purple is included; to add other
palettes, see [Getting started](../../README.md#getting-started).

## Three versions of one scheme

The editors share one file format, but the versions of GtkSourceView they
use each accept something the others refuse, so each palette gets three
copies of the same scheme:

| File | For | What differs |
|------|-----|--------------|
| `gtksourceview-4/jenerated-<slug>.xml` | GtkSourceView 3 and 4: gedit 46 and earlier, Xed, Pluma, Meld | the plain format |
| `gtksourceview-5/jenerated-<slug>.xml` | GtkSourceView 5: GNOME Text Editor | adds whether the palette is dark or light, and the colors GNOME Text Editor recolors its window with (which GtkSourceView 4 refuses) |
| `libgedit-gtksourceview-300/jenerated-<slug>.xml` | gedit 47 and later, which use their own fork of GtkSourceView | marks the palette dark or light its own way, and refuses the plain format's version number |

The files are generated from `gtksourceview-4.xml.tmpl`,
`gtksourceview-5.xml.tmpl` and `libgedit.xml.tmpl` by
[jenerate.py](../../jenerate.py). To change colors, see
[Changing colors](../../README.md#changing-colors).

## Install

The easiest way is `./setup.sh` from the repository root: choose the text
editors. It links each version of the scheme into the folder that version
of GtkSourceView reads. If GNOME Text Editor or gedit was installed through
Flatpak, which keeps each app's files in a folder of its own, it links the
scheme there too. To install by hand, run these from the same folder where
you ran `git clone`:

```bash
theme="$PWD/jenerated-themes/app-themes/gtksourceview-theme/blue-purple"
data=~/.local/share
mkdir -p "$data/gtksourceview-3.0/styles" "$data/gtksourceview-4/styles" \
  "$data/gtksourceview-5/styles" "$data/libgedit-gtksourceview-300/styles"
ln -s "$theme/gtksourceview-4/jenerated-blue-purple.xml" "$data/gtksourceview-3.0/styles/"
ln -s "$theme/gtksourceview-4/jenerated-blue-purple.xml" "$data/gtksourceview-4/styles/"
ln -s "$theme/gtksourceview-5/jenerated-blue-purple.xml" "$data/gtksourceview-5/styles/"
ln -s "$theme/libgedit-gtksourceview-300/jenerated-blue-purple.xml" "$data/libgedit-gtksourceview-300/styles/"
```

If one of these editors was installed through Flatpak, use the app's own
data folder instead of `~/.local/share`: `~/.var/app/org.gnome.TextEditor/data`
for GNOME Text Editor, and `~/.var/app/org.gnome.gedit/data` for gedit.

Then choose **Jenerated Blue Purple** in each editor, and reopen editors
that were open:

- **gedit:** Preferences → Font & Colors.
- **GNOME Text Editor:** the menu → Preferences → Style. It only lists
  schemes that match its own light or dark style, so switch it to the dark
  style (the moon at the top of the menu) for a dark palette, or the light
  style for a light one.
- **Xed:** Edit → Preferences → Theme.
- **Pluma, Meld and others:** in their preferences, usually under fonts and
  colors.

After changing the palette, run `./jenerate.py` and reopen the editors.
