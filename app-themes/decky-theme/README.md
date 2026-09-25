# Jenerated Themes for Decky Loader

Themes for Steam's Gaming Mode, the full-screen interface on the Steam Deck
and on SteamOS-like systems such as Bazzite and CachyOS. They recolor the
library, the store, settings, and the Steam and Quick Access menus.

Steam doesn't support themes itself. [Decky Loader](https://decky.xyz) adds
plugins to Gaming Mode, and its **CSS Loader** plugin applies themes.
[jenerate.py](../../jenerate.py) writes one CSS Loader theme folder for each
palette you generate, for example `blue-purple/`, holding `theme.json` and
`shared.css`. Blue Purple is included; to add other palettes, see
[Getting started](../../README.md#getting-started).

## How it works

Steam's interface draws with a set of named colors: seven grays from darkest
to lightest (with a matching set for the store), a blue for focus, toggles
and sliders, and green, yellow, orange and red. The theme replaces them with
the palette's:

| Steam's colors | Palette colors |
|----------------|----------------|
| Darkest to lightest grays | `bg_chrome`, `bg`, `bg_selected`, `text_faint`, `text_muted`, `text_subtle`, `text` |
| Blue, and its lighter and darker versions | `accent`, `accent_light`, `accent_hover`, `accent_soft`, `accent_pale` |
| Green, yellow, orange, red | `green`, `yellow`, `orange`, `red` (and the bright terminal green and red for their brighter versions) |
| See-through layers behind dialogs and on buttons | `bg_chrome`, `accent_pale`, `accent_soft`, `selection` and `text`, with Steam's own transparency |

It only changes these named colors, not Steam's own class names. Those are
generated, and change with Steam updates, so themes that rely on them break
from time to time; the named colors stay. The trade-off is that any parts
Steam colors directly, rather than through the named colors, keep Steam's
colors.

Steam's interface is designed to be dark, so dark palettes suit it best. A
light palette works, but where Steam draws white text directly, it may be
hard to read on the palette's light backgrounds.

The files are generated from `theme.json.tmpl` and `shared.css.tmpl` by
[jenerate.py](../../jenerate.py). To change colors, see
[Changing colors](../../README.md#changing-colors).

## Install

First install [Decky Loader](https://decky.xyz), following its instructions
for your system, then install **CSS Loader** from Decky's plugin store.

The easiest way is `./setup.sh` from the repository root (in Desktop Mode, or
over SSH): choose Decky Loader. It links the theme into `~/homebrew/themes`,
where CSS Loader looks for themes. To install it by hand, run this from the
same folder where you ran `git clone`:

```bash
mkdir -p ~/homebrew/themes
ln -s "$PWD/jenerated-themes/app-themes/decky-theme/blue-purple" ~/homebrew/themes/Jenerated-blue-purple
```

Then, in Gaming Mode:

1. Open the Quick Access menu (the **•••** button on a Steam Deck), then
   Decky's plug icon, and choose **CSS Loader**.
2. If CSS Loader was already running, scroll to the bottom and press
   **Refresh** so it finds the new theme.
3. Turn on **Jenerated Blue Purple**.

CSS Loader reads the theme from the repository, so after changing the
palette and running `./jenerate.py`, press **Refresh** again. To go back to
Steam's own colors, turn the theme off.
