# Jenerated Themes for Firefox

[Firefox](https://www.mozilla.org/firefox/) themes that match the VS Code
themes: the window, tabs, toolbar, address bar, menus, sidebar and new tab
page. [jenerate.py](../../jenerate.py) writes one folder for each palette you
generate, for example `blue-purple/`, holding the theme's `manifest.json`.
Blue Purple is included; to add other palettes, see
[Getting started](../../README.md#getting-started).

Each theme marks Firefox's own pages as dark or light, to match the palette.
Websites still follow your system's light or dark setting.

The manifests are generated from `manifest.json.tmpl` by
[jenerate.py](../../jenerate.py). To change colors, see
[Changing colors](../../README.md#changing-colors).

## Install

The easiest way is `./setup.sh` from the repository root: choose Firefox. It
packages the theme, can open Firefox's add-on page for you, and explains the
steps below.

### Try it (until Firefox restarts)

1. In Firefox, go to `about:debugging#/runtime/this-firefox`.
2. Click **Load Temporary Add-on…** and choose the palette's
   `manifest.json`, for example `app-themes/firefox-theme/blue-purple/manifest.json`.

### Keep it

Firefox only keeps add-ons that Mozilla has signed. Signing your own theme is
free, and it stays private (it isn't listed on the add-ons site):

1. Package the theme: `./setup.sh` makes
   `app-themes/firefox-theme/jenerated-<slug>.xpi`, which is just the
   `manifest.json` zipped, with a version number from the date and time.
   Mozilla needs a new version for every upload, so run `./setup.sh` again
   after changing the palette.
2. Go to
   [addons.mozilla.org/developers/addon/submit/distribution](https://addons.mozilla.org/developers/addon/submit/distribution),
   sign in with a Mozilla account, choose **On your own**, and upload the
   `.xpi`.
3. Download the signed file it gives you, and open it in Firefox
   (**File → Open File**, or drag it onto a Firefox window).

Firefox Developer Edition, Nightly and ESR can also install unsigned themes
permanently, after setting `xpinstall.signatures.required` to `false` in
`about:config`.
