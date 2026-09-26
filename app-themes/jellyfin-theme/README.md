# Jenerated Themes for Jellyfin

Custom CSS for [Jellyfin](https://jellyfin.org)'s web interface (version
10.9 and later): the pages and menus, cards, buttons, inputs, tabs,
dialogs, the dashboard, the live TV guide and the scroll bars. The Jellyfin
apps that show the web interface, such as the desktop app, pick it up too;
apps with their own design, like the ones for TVs, don't.

[jenerate.py](../../jenerate.py) writes one CSS file for each palette you
generate, for example `jenerated-blue-purple.css`. Blue Purple is included;
to add other palettes, see
[Getting started](../../README.md#getting-started).

Jellyfin takes its colors from a set of CSS variables, so the CSS sets those
to the palette's colors, whichever of Jellyfin's themes is chosen:

| Part of Jellyfin | Palette color |
|------------------|---------------|
| Page background | `bg` |
| Menus, dialogs, cards' panels | `bg_widget` |
| Header bar | `bg_chrome` |
| Inputs and plain buttons | `bg_hover`, with `bg_secondary_hover` when hovered |
| Selected items | `bg_selected` |
| Text | `text`, with `text_subtle` for secondary text |
| Main buttons, progress bars, highlights | `accent`, with `text_bright` on it |
| Focused items, active tabs | `accent_soft` |
| Dividers and borders | `border` |
| Errors, warnings, success | `red`, `yellow`, `green` |
| Ratings (stars) | `yellow` |

The files are generated from `theme.css.tmpl` by
[jenerate.py](../../jenerate.py). To change colors, see
[Changing colors](../../README.md#changing-colors).

## Install

Jellyfin is themed from inside the app, by pasting CSS into it. The easiest
way is `./setup.sh` from the repository root: choose Jellyfin (under
Entertainment). It copies the palette's CSS to your clipboard (or tells you
where the file is). To do it by hand, open the palette's `.css` file and copy everything in it.

Then paste it into Jellyfin, in one of two places:

- **For everyone on your server** (as an administrator): open
  **Dashboard → Branding** (**Dashboard → General** in older versions),
  paste the CSS into **Custom CSS code**, replacing anything already there,
  and save.
- **Just for one device:** open **Settings → Display**, paste it into the
  **Custom CSS code** box, and save.

Choose Jellyfin's **Dark** theme (under **Settings → Display**) for a dark
palette, or **Light** for a light one. The colors come from the palette
either way, but Jellyfin shades a few things, like raised panels,
differently for dark and light themes.

After changing the palette, run `./setup.sh` again and paste the new CSS in
place of the old.
