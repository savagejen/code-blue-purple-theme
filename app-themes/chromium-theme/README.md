# Jenerated Themes for Chromium Browsers

Themes for the browsers built on Chromium, which all use the same theme
format:

- Google Chrome
- Brave
- Microsoft Edge
- Opera
- Chromium

(Vivaldi is built on Chromium too, but has its own, fuller theme format; see
[the Vivaldi theme](../vivaldi-theme/).)

Each theme colors the window, tabs, toolbar, address bar, bookmarks bar and
new tab page, to match the VS Code themes. [jenerate.py](../../jenerate.py)
writes one folder for each palette you generate, for example `blue-purple/`,
holding the theme's `manifest.json`. Blue Purple is included; to add other
palettes, see [Getting started](../../README.md#getting-started).

The colors follow the VS Code theme: the darkest background (`bg_chrome`) for
the window and unselected tabs, the editor background (`bg`) for the toolbar,
the selected tab and the new tab page, `bg_hover` for the address bar, and the
palette's text colors for text and icons. On the new tab page, links use
`accent_soft`, and search engines with a logo show their light version. The
themes only have a dark version.

The manifests are generated from `manifest.json.tmpl` by
[jenerate.py](../../jenerate.py). To change colors, see
[Changing colors](../../README.md#changing-colors).

## Install

Browsers install a theme like this as an unpacked extension, straight from
its folder. `./setup.sh` from the repository root (choose Chromium browsers)
generates the theme and explains these steps:

1. Open the browser's extensions page: `chrome://extensions` in Chrome and
   Chromium, `brave://extensions` in Brave, `edge://extensions` in Edge, or
   `opera://extensions` in Opera.
2. Turn on **Developer mode**.
3. Click **Load unpacked** and choose the palette's folder, for example
   `app-themes/chromium-theme/blue-purple`. The theme applies right away.

The browser keeps loading the theme from that folder, so leave the repository
where it is. It also saves a cache of the theme there, `Cached Theme.pak` (git
ignores it). After changing a palette, generate it again, delete that file
(`./setup.sh` does this for you), and load the folder again. To go back to the
browser's own look, open **Settings → Appearance** and click **Reset to
default** by the theme.
