# Jenerated Themes for Unreal Engine

Editor themes for the [Unreal Engine](https://www.unrealengine.com) editor
(Unreal Engine 5): the window and panel backgrounds, text, buttons,
selections, inputs and menus, the warning, error and success colors, and the
accent colors the editor uses for asset types and folders.

[jenerate.py](../../jenerate.py) writes one theme for each palette you
generate, for example `jenerated-blue-purple.json`. Blue Purple is included;
to add other palettes, see
[Getting started](../../README.md#getting-started).

This themes the editor itself, not your games. The code editor you use with
Unreal has its own theme: see [VS Code](../vs-code-theme/),
[JetBrains apps](../jetbrains-theme/) (for Rider) or
[Xcode](../xcode-theme/).

Which palette colors go where:

| Unreal color | Palette color |
|--------------|---------------|
| Panel (details, outliner and most of the window) | `bg` |
| Background | `bg_minimap` |
| Recessed (content browser) | `bg_sidebar` |
| Title bar, window border, inputs | `bg_chrome` |
| Headers, dropdowns, notifications | `bg_widget` |
| Secondary buttons, hovered rows | `bg_hover` |
| Hovered buttons | `bg_secondary_hover` |
| Borders | `border` |
| Text | `text`, with `text_subtle` for headers and `text_strong` for hovered text and icons |
| Primary buttons, highlights, selections | `accent`, with `accent_hover` when hovered or pressed |
| Unfocused selections | `bg_selected` |
| Folders | `accent_soft` |
| Warning, error, success | `yellow`, `red`, `green` |
| Accent colors (blue, purple, pink, red, yellow, green, black, gray, white) | the terminal colors |

The files are generated from `theme.json.tmpl` by
[jenerate.py](../../jenerate.py). To change colors, see
[Changing colors](../../README.md#changing-colors).

## Install

The easiest way is `./setup.sh` from the repository root: choose Unreal
Engine (under Editors). It links the theme into Unreal's folder for your own
themes, which every engine version shares:

- Linux: `~/.config/Epic/UnrealEngine/Slate/Themes/`
- macOS: `~/Library/Application Support/Epic/UnrealEngine/Slate/Themes/`

To install by hand, link or copy the palette's `.json` file into that
folder, or use **Import** next to the theme list in the editor (which copies
it, so it won't pick up later changes).

Then, in the Unreal Editor:

1. Open **Edit → Editor Preferences → General → Appearance**.
2. Under **Theme**, choose **Jenerated Blue Purple** as the **Active Theme**.
   Restart the editor first if it doesn't appear.

To tweak the colors inside Unreal, choose **Duplicate** and edit the copy.
Editing the linked theme itself changes the generated file, and running
`./jenerate.py` again would overwrite your changes.

After changing the palette, run `./jenerate.py` and restart the editor.
