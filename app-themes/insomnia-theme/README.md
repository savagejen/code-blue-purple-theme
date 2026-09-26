# Jenerated Themes for Insomnia

Themes for [Insomnia](https://insomnia.rest), the API client, to match the
other themes: the window, the sidebar, request and response panes, the
editors, dialogs and menus, the accent (the Send button and highlights),
and the colors Insomnia uses for success, warnings and errors.

Insomnia themes come as plugins. [jenerate.py](../../jenerate.py) writes one
plugin folder for each palette you generate, for example
`blue-purple/insomnia-plugin-jenerated-blue-purple/`, holding the plugin's
`package.json` and `index.js`. Blue Purple is included; to add other
palettes, see [Getting started](../../README.md#getting-started).

The plugin only provides a theme. It declares that it needs no
permissions, which Insomnia's plugin settings show.

## How the colors are used

| Insomnia color | Palette color |
|----------------|---------------|
| Background, text | `bg`, `text` |
| Sidebar, its text | `bg_sidebar`, `text_subtle` |
| Title bar | `bg_chrome` |
| Dialogs, menus and tooltips | `bg_widget` |
| Accent ("surprise"), text on it | `accent`, `text_bright` |
| Success, notice, warning, danger, info | `green`, `yellow`, `orange`, `red`, `cyan` |
| Links | `accent_soft` |
| Hover and selection shades | `text_muted`, at several strengths |

The files are generated from `package.json.tmpl` and `index.js.tmpl` by
[jenerate.py](../../jenerate.py). To change colors, see
[Changing colors](../../README.md#changing-colors).

## Install

The easiest way is `./setup.sh` from the repository root: choose Insomnia.
It copies the plugin into Insomnia's plugins folder (a copy, since Insomnia
ignores plugins that are links to folders elsewhere). The folder is:

- Linux: `~/.config/Insomnia/plugins/`
- Linux, if Insomnia was installed through Flatpak:
  `~/.var/app/rest.insomnia.Insomnia/config/Insomnia/plugins/`
- Linux, if Insomnia was installed through Snap:
  `~/snap/insomnia/current/.config/Insomnia/plugins/`
- macOS: `~/Library/Application Support/Insomnia/plugins/`

To install by hand, copy the palette's `insomnia-plugin-jenerated-<slug>`
folder into that folder.

Then, in Insomnia:

1. Restart it, or open **Settings** (**Preferences** in older versions) →
   **Plugins** and choose **Reload**.
2. Open **Settings → Themes**, and choose **Jenerated Blue Purple**.

The plugin is a copy, so after changing the palette, run `./setup.sh` again
(it replaces the old copy) and reload the plugins.
