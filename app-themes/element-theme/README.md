# Jenerated Themes for Element

Themes for [Element](https://element.io), the Matrix chat app, to match the
other themes: the timeline, the room list and the spaces bar, message
bubbles, buttons, menus, links, badges, and the colors of usernames and
avatars.

[jenerate.py](../../jenerate.py) writes one folder for each palette you
generate, for example `blue-purple/`, holding `jenerated-blue-purple.json`,
an Element custom theme. Blue Purple is included; to add other palettes, see
[Getting started](../../README.md#getting-started).

## How it works

Element draws its older screens from a set of named colors, and its newer
ones (such as the room list) from the design tokens of its Compound design
system, so each theme sets both:

| Element | Palette color |
|---------|---------------|
| Timeline | `text` on `bg` |
| Room list | `text_subtle` on `bg_sidebar` |
| Spaces bar | `bg_chrome` |
| Accent, buttons, unread badges | `accent`, with `text_bright` text |
| Links | `accent_soft` |
| Your messages, others' messages (bubble layout) | `bg_selected`, `bg_widget` |
| Usernames and avatars | eight of the syntax colors |

The theme is marked dark or light to match the palette, so Element uses the
matching version of its own styles for anything the theme doesn't set.

The files are generated from `theme.json.tmpl` by
[jenerate.py](../../jenerate.py). To change colors, see
[Changing colors](../../README.md#changing-colors).

## Install

This is for **Element Desktop**. Element on the web (such as
app.element.io) reads its settings from the website, so it can't load a
theme from your computer.

The easiest way is `./setup.sh` from the repository root: choose Element
(under Communication). It adds the theme to Element's own settings file,
`config.json`, under `setting_defaults.custom_themes`, keeping everything
else in the file, and backs the file up first (as
`config.json.before-jenerated`). The file is in:

- Linux: `~/.config/Element/`
- Linux, if Element was installed through Flatpak:
  `~/.var/app/im.riot.Riot/config/Element/`
- macOS: `~/Library/Application Support/Element/`

Then restart Element, open **Settings → Appearance**, and choose **Jenerated
Blue Purple**.

To install by hand, add the theme's contents to that `config.json` (creating
it if needed) as an item of `custom_themes`:

```json
{
    "setting_defaults": {
        "custom_themes": [
            { "name": "Jenerated Blue Purple", "is_dark": true, "colors": { "...": "..." } }
        ]
    }
}
```

The theme is copied into `config.json`, so after changing the palette, run
`./setup.sh` again (it replaces the old copy) and restart Element.

If you've added custom themes before in Element's developer tools
(`/devtools`, then **Custom themes**), Element keeps that list in your
account, and it takes the place of the one in `config.json`. Add the theme
there instead: that panel needs the theme at a web address, so put the
`.json` file somewhere you can link to it.
