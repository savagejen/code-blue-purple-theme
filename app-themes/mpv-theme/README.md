# Jenerated Themes for mpv

Colors for the [mpv](https://mpv.io) media player's own interface, to match
the other themes: the on-screen controller (the play bar that appears over
the video), on-screen messages and the OSD bar, the playlist and other
lists, and the console and its menus. Subtitles and the video itself aren't
touched.

[jenerate.py](../../jenerate.py) writes one folder for each palette you
generate, for example `blue-purple/`, holding `jenerated-blue-purple.conf`.
Blue Purple is included; to add other palettes, see
[Getting started](../../README.md#getting-started).

## How the colors are used

| mpv setting | Palette color |
|-------------|---------------|
| Controller background | `bg_chrome` |
| Progress bar and time, pressed buttons | `accent` |
| Title, buttons | `text` (the smaller buttons `text_subtle`) |
| Messages and the OSD bar | `text`, outlined in `bg_chrome` |
| Selected item in lists | `accent_soft` |
| Console menus: focused item | `text_bright` on `accent` |
| Console menus: matched letters | `magenta`, like search matches in the other themes |

Some of these settings are newer than others. The controller's colors need
mpv 0.39 or later, the selected item and console colors 0.40, and the
console's focused item 0.41. Older versions of mpv use what they know, keep
their own colors for the rest, and mention the settings they don't know in
the terminal.

The file is generated from `colors.conf.tmpl` by
[jenerate.py](../../jenerate.py). To change colors, see
[Changing colors](../../README.md#changing-colors).

## Install

The easiest way is `./setup.sh` from the repository root: choose mpv
(under Entertainment). It links the palette's colors into mpv's settings
folder as `jenerated-colors.conf`, and adds a line to the end of `mpv.conf`
that loads them, creating `mpv.conf` if needed. If you already have an `mpv.conf`, it
asks first, and your settings in it are kept. If mpv was installed through
Flatpak, it does the same in the folder Flatpak gives mpv.

To install by hand, link the palette's file into mpv's settings folder
(`~/.config/mpv`, on macOS too) and load it from `mpv.conf`:

```bash
mkdir -p ~/.config/mpv
ln -s "$PWD/jenerated-themes/app-themes/mpv-theme/blue-purple/jenerated-blue-purple.conf" ~/.config/mpv/jenerated-colors.conf
echo 'include="~~/jenerated-colors.conf"' >>~/.config/mpv/mpv.conf
```

If mpv was installed through Flatpak, use
`~/.var/app/io.mpv.Mpv/config/mpv` instead of `~/.config/mpv`.

Then restart mpv. After changing the palette, run `./jenerate.py` and
restart mpv. To switch palettes, run `./setup.sh` again. To go back to
mpv's own colors, remove the `include` line from `mpv.conf`.
