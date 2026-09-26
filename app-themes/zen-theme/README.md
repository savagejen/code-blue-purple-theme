# Jenerated Themes for Zen Browser

Themes for [Zen Browser](https://zen-browser.app), which is built on
Firefox but draws its own interface: the sidebar of tabs, workspaces, the
compact toolbar and the window around the page. A Firefox theme only reaches
part of it, so Zen gets its own theme, as the stylesheets Zen reads from
your profile:

- `userChrome.css` colors the browser itself: the window background, the
  sidebar and tabs, the address bar and its suggestions, menus and popups,
  buttons and focus outlines; and
- `userContent.css` colors Zen's own pages: the new tab page, settings, and
  the other `about:` pages. Websites aren't touched.

[jenerate.py](../../jenerate.py) writes one folder for each palette you
generate, for example `blue-purple/`, holding the two files. Blue Purple is
included; to add other palettes, see
[Getting started](../../README.md#getting-started).

## How it works

Zen works out its colors from a few settings of its own (`--zen-*`), and
Firefox's theme colors fill in the rest, so the theme sets those rather than
styling Zen's elements one by one, whose names change more often. The
window background is `bg_chrome`, the sidebar `bg_sidebar`, the selected tab
`bg_selected` with `text_strong` text, popups and the address bar
`bg_widget`, and Zen's accent is `accent`.

Zen's workspace themes (the colors you can pick for each workspace) are
overridden, so every workspace uses the palette. The theme also tells Zen
whether the palette is dark or light, whatever the workspace would choose.

The files are generated from `userChrome.css.tmpl` and
`userContent.css.tmpl` by [jenerate.py](../../jenerate.py). To change
colors, see [Changing colors](../../README.md#changing-colors).

## Install

The easiest way is `./setup.sh` from the repository root: choose Zen
Browser. Open Zen at least once first, so it has a profile. The script:

1. Asks which profile to use, if you have more than one.
2. Links the theme's two files into the profile's `chrome` folder, as
   `jenerated-userChrome.css` and `jenerated-userContent.css`.
3. Adds a line to the top of the profile's `userChrome.css` and
   `userContent.css` that loads them, creating the files if needed. If you
   already have styles of your own there, they're kept (it asks first).
4. Turns on custom stylesheets, which Zen leaves off by default, by adding
   `toolkit.legacyUserProfileCustomizations.stylesheets` to the profile's
   `user.js`.

Then restart Zen.

To install by hand, find your profile folder in Zen (`about:support`, then
**Open Profile Folder**), and:

1. Create a `chrome` folder in it, and link or copy the palette's
   `userChrome.css` and `userContent.css` into it. (If you already have
   files with those names, add `@import "jenerated-userChrome.css";` to the
   top of yours instead, with the theme's file saved under that name, and
   the same for `userContent.css`.)
2. In `about:config`, set `toolkit.legacyUserProfileCustomizations.stylesheets`
   to `true`.
3. Restart Zen.

Zen reads the theme when it starts, so after changing the palette and
running `./jenerate.py`, restart Zen. To go back to Zen's own look, remove
the two `@import` lines (or the files), and restart.
