# Jenerated Themes for Mattermost

Themes for [Mattermost](https://mattermost.com), to match the other themes:
the sidebar and team bar, the channel area, mentions, links, buttons,
status indicators, and code blocks.

Mattermost keeps your theme with your account, on the server, so there's
nothing to install on your computer: you paste the theme into Mattermost's
settings once, and it applies wherever you use Mattermost, in a browser,
the desktop app and the mobile apps.

[jenerate.py](../../jenerate.py) writes one file for each palette you
generate, for example `blue-purple.json`, holding the theme in the format
Mattermost's custom theme editor copies and pastes. Blue Purple is
included; to add other palettes, see
[Getting started](../../README.md#getting-started).

## How the colors are used

| Mattermost color | Palette color |
|------------------|---------------|
| Sidebar, its text | `bg_sidebar`, `text_subtle` |
| Sidebar hover, the current channel's border | `bg_hover`, `accent` |
| Sidebar header and team bar | `bg_chrome` |
| Channel area, its text | `bg`, `text` |
| Mention badges, buttons | `accent`, with `text_bright` text |
| Links, the new message line | `accent_soft` |
| Your highlighted mentions | `selection` |
| Online, away, do not disturb | `green`, `yellow`, `red` |

Mattermost colors code blocks with a few fixed code themes rather than
single colors, so the theme picks the one that suits the palette: Monokai
for a dark palette, and GitHub for a light one.

The files are generated from `theme.json.tmpl` by
[jenerate.py](../../jenerate.py). To change colors, see
[Changing colors](../../README.md#changing-colors).

## Install

The easiest way is `./setup.sh` from the repository root: choose Mattermost
(under Communication). It prints the theme and copies it to your clipboard.
Or copy the contents of the palette's `.json` file yourself. Then, in
Mattermost:

1. Open **Settings → Display → Theme**, and choose **Edit**.
2. Choose **Custom Theme**, and paste the theme into the box under **Copy
   and paste to share theme colors**.
3. Choose **Save**.

After changing the palette, run `./jenerate.py` (or `./setup.sh`) and paste
the new theme the same way.
