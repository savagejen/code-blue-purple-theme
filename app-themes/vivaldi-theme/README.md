# Jenerated Themes for Vivaldi

[Vivaldi](https://vivaldi.com) themes that match the VS Code themes.
[jenerate.py](../../jenerate.py) writes one folder for each palette you
generate, for example `blue-purple/`, holding the theme's `settings.json`, in
the same format as Vivaldi's own themes. Blue Purple is included; to add other
palettes, see [Getting started](../../README.md#getting-started).

The palette's colors fill Vivaldi's five theme colors:

| Vivaldi color | Palette color | Used for |
|---------------|---------------|----------|
| Accent        | `bg_chrome`   | the tab bar |
| Window        | `bg_minimap`  | the window behind panels |
| Background    | `bg`          | toolbars, panels and the active tab |
| Foreground    | `text`        | text and icons |
| Highlight     | `accent`      | focus, selections and progress |

The theme doesn't take its accent color from web pages, so the tab bar keeps
the palette's colors. The themes only have a dark version.

The files are generated from `settings.json.tmpl` by
[jenerate.py](../../jenerate.py). To change colors, see
[Changing colors](../../README.md#changing-colors).

## Install

Vivaldi imports themes as a `.zip` holding the theme's `settings.json`.
Blue Purple's is included, ready to import:
[jenerated-blue-purple.zip](jenerated-blue-purple.zip). For other palettes,
the easiest way is `./setup.sh` from the repository root: choose Vivaldi, and
it makes `app-themes/vivaldi-theme/jenerated-<slug>.zip`. To make it by hand:

```bash
cd app-themes/vivaldi-theme/blue-purple
zip ../jenerated-blue-purple.zip settings.json
```

Then, in Vivaldi:

1. Open **Settings → Themes**, and click **Import Theme…** at the bottom.
2. Choose the `.zip`.
3. Vivaldi shows a preview of the theme and asks whether to install and apply
   it. Accept within 30 seconds; after that the preview expires and nothing is
   installed.

After changing a palette, make and import the `.zip` again. Each palette's
theme keeps the same id (a UUID made from its slug), so Vivaldi offers the new
one as an update to the theme you installed.

If Vivaldi says the theme "cannot be previewed due to format errors", the
theme's fields don't match what Vivaldi expects; `settings.json.tmpl` matches
a theme exported from Vivaldi 8.2.
