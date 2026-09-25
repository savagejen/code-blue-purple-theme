# Jenerated Themes for KDE Plasma

Themes for the KDE Plasma desktop and its apps, in three parts that match the
VS Code themes:

- a **Plasma color scheme** (`Jenerated-<slug>.colors`), which colors Plasma
  itself (the panel, menus and widgets, with the Breeze Plasma style), window
  title bars (with Breeze window decorations), and every KDE and Qt app, such
  as Dolphin, Kate, Okular and System Settings. KDE's GTK integration applies
  it to GTK apps too;
- a **Konsole color scheme** (`Jenerated-<slug>.colorscheme`), with the same
  16 terminal colors as the Ptyxis and Tilix themes; and
- a **Kate syntax theme** (`Jenerated-<slug>.theme`), with the same syntax
  colors as the VS Code theme, for Kate, KWrite and other apps that use
  KDE's text editor.

No extension is needed: Plasma supports color schemes on its own.
[jenerate.py](../../jenerate.py) writes one folder for each palette you
generate, for example `blue-purple/`, holding the three files. Blue Purple is
included; to add other palettes, see
[Getting started](../../README.md#getting-started). The themes only have a
dark version.

The files are generated from `colors.tmpl`, `konsole.colorscheme.tmpl` and
`syntax.theme.tmpl` by [jenerate.py](../../jenerate.py). The color scheme and
Kate theme follow the layout of Plasma's own Breeze Dark. To change colors,
see [Changing colors](../../README.md#changing-colors).

## How the colors are used

In the Plasma color scheme:

| Color set | Background | Used for |
|-----------|------------|----------|
| Window | `bg_sidebar` | window backgrounds and panels |
| View | `bg` | lists, text areas and other content |
| Button | `bg_hover` | buttons |
| Selection | `accent` | selected items, with `text_bright` text |
| Tooltip | `bg_widget` | tooltips |
| Header, title bars | `bg_chrome` | toolbars and window title bars |
| Complementary | `bg_chrome` | the dark areas some Plasma screens use |

Text is `text`, dimmer text `text_muted`, links `accent_soft`, focus and
hover highlights `accent`, and errors, warnings and success `red`, `yellow`
and `green`.

## Install

The easiest way is `./setup.sh` from the repository root (on Linux): choose
KDE Plasma. It links the three files where KDE looks for them, and on Plasma
offers to switch the color scheme, showing your current one and the command
to switch back. To install by hand, run these from the same folder where you
ran `git clone`:

```bash
theme="$PWD/jenerated-themes/app-themes/kde-theme/blue-purple"
mkdir -p ~/.local/share/color-schemes ~/.local/share/konsole ~/.local/share/org.kde.syntax-highlighting/themes
ln -s "$theme/Jenerated-blue-purple.colors" ~/.local/share/color-schemes/
ln -s "$theme/Jenerated-blue-purple.colorscheme" ~/.local/share/konsole/
ln -s "$theme/Jenerated-blue-purple.theme" ~/.local/share/org.kde.syntax-highlighting/themes/
```

Then turn each one on:

- **Plasma and KDE apps:** **System Settings → Colors & Themes → Colors**,
  and choose **Jenerated Blue Purple**, or run
  `plasma-apply-colorscheme Jenerated-blue-purple`.
- **Konsole:** **Settings → Edit Current Profile → Appearance**, and choose
  **Jenerated Blue Purple**.
- **Kate and KWrite:** **Settings → Configure Kate → Color Themes**, and
  choose **Jenerated Blue Purple**. Restart Kate first if it was open.
