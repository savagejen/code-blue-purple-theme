# Jenerated Themes for GTK3 Apps

A theme for the Linux apps built with GTK3, in the palette's colors: windows,
header bars, menus, lists and selections, buttons, text fields, tabs,
sidebars, tooltips, scrollbars, switches, checkboxes, sliders and progress
bars. [jenerate.py](../../jenerate.py) writes one theme folder for each
palette you generate, for example `blue-purple/`, holding `gtk-3.0/gtk.css`
and `index.theme`. Blue Purple is included; to add other palettes, see
[Getting started](../../README.md#getting-started).

## Which apps

A GTK3 theme applies to every app built with GTK3. Some common ones:

- **Graphics:** GIMP (3.0 and later), Inkscape, Shotwell
- **Files:** Thunar, Nemo, Caja
- **Text and code:** gedit, Mousepad, Geany, Meld, Pluma, Xed
- **System tools:** GParted, Synaptic, dconf Editor, Virtual Machine Manager
- **Internet and mail:** Evolution, Remmina, Deluge
- **Media:** Rhythmbox
- **Terminals:** GNOME Terminal
- **The Xfce, MATE and Cinnamon desktops' own apps**

The text area in gedit, Xed, Pluma and Meld uses its own color scheme; see
[the text editor color schemes](../gtksourceview-theme/).

Apps built with GTK3 but drawing much of their own interface, such as
LibreOffice, Audacity, Firefox and Thunderbird, pick up the theme in places
(menus, dialogs, some controls).

It doesn't apply to:

- **Newer GNOME apps**, such as Files, Settings, Text Editor and Calculator:
  they're built with GTK4 and libadwaita, which don't support themes.
- **GTK2 apps**, such as GIMP 2.10.
- **Qt and KDE apps.**

## Install

The easiest way is `./setup.sh` from the repository root: choose GTK3 apps.
It links the theme into `~/.local/share/themes/Jenerated-<slug>`, and on
GNOME offers to switch to it, showing your current theme and the command to
switch back. To install it by hand:

```bash
mkdir -p ~/.local/share/themes
ln -s "$PWD/jenerated-themes/app-themes/gtk3-theme/blue-purple" ~/.local/share/themes/Jenerated-blue-purple
```

Then choose **Jenerated-blue-purple**:

- **GNOME:** in GNOME Tweaks, under **Appearance**, for **Legacy
  Applications**, or run
  `gsettings set org.gnome.desktop.interface gtk-theme Jenerated-blue-purple`.
  To go back, set it to your previous theme again (Ubuntu's are called
  `Yaru-dark`, `Yaru-blue-dark` and so on).
- **Xfce:** **Settings → Appearance → Style**.
- **One app at a time:** start it with the `GTK_THEME` variable, for example
  `GTK_THEME=Jenerated-blue-purple gimp`.

Reopen GTK3 apps that were already open. Apps installed through Flatpak
can't see your themes folder by default; to let them, run
`flatpak override --user --filesystem=xdg-data/themes:ro`.

## How it's built

`gtk.css` imports the Adwaita theme that comes with GTK3, its dark or light
version to match the palette, so every widget has a complete style, and then
recolors the main widgets with the
palette. Adwaita paints many widgets with gradients, and restyles unfocused
windows separately, so the theme sets each background as an image too, and
repeats each rule for unfocused (`:backdrop`) windows. It also sets GTK's
named colors (`@theme_bg_color`, `@theme_selected_bg_color` and so on), which
some apps use in their own styles.

The files are generated from `gtk.css.tmpl` and `index.theme.tmpl` by
[jenerate.py](../../jenerate.py). To change colors, see
[Changing colors](../../README.md#changing-colors).
