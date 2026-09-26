# Jenerated Themes for LibreOffice

Themes for [LibreOffice](https://www.libreoffice.org) (Writer, Calc,
Impress, Draw, Base and Math), as a small LibreOffice extension for each
palette. Each theme colors:

- **The window:** toolbars, the sidebar, menus, dialogs, lists, buttons and
  selections.
- **Documents:** the page and the area around it, text, grids, page breaks,
  field and index shadings, spelling and grammar marks, and Calc's value
  highlighting and notes.
- **Code:** the Basic macro editor and SQL in Base.

[jenerate.py](../../jenerate.py) writes one extension folder for each
palette you generate, for example `blue-purple/`; `setup.sh` packages it as
`jenerated-blue-purple.oxt`. Blue Purple's `.oxt` is included, ready to
install; to add other palettes, see
[Getting started](../../README.md#getting-started).

Which palette colors go where:

| Part of LibreOffice | Palette color |
|---------------------|---------------|
| Toolbars, sidebar, dialogs | `bg_sidebar` |
| Lists, input fields | `bg` |
| Menu bar | `bg_chrome` |
| Menus | `bg_widget` |
| Buttons | `bg_hover` |
| Selections and highlighted menu items | `bg_selected`, with `text_strong` |
| Links, checked boxes | `accent_soft` |
| Page | `bg`, with `text` |
| Area around the page | `bg_chrome` |
| Borders and grids | `border` and `guide` |
| Page breaks, cell cursor, header and footer marks | `accent` |
| Spelling mistakes | `red` |
| Calc's values, formulas and text (View → Value Highlighting) | `orange`, `accent_light` and `text` |
| Basic and SQL code | the syntax colors, as in the VS Code theme |

A dark palette makes the pages dark too. To keep them white, tick **Use
white document background** on the Appearance page (see below).

The files are generated from the `.tmpl` files here by
[jenerate.py](../../jenerate.py). To change colors, see
[Changing colors](../../README.md#changing-colors).

## Install

The easiest way is `./setup.sh` from the repository root: choose
LibreOffice (under Editors). It packages the palette's `.oxt` and, if
LibreOffice is closed, installs it with LibreOffice's `unopkg` tool.
Otherwise, or to install by hand: in LibreOffice, open **Tools →
Extensions**, click **Add**, choose the `.oxt`, and restart LibreOffice.
(Double-clicking the `.oxt` works too.)

Then:

1. Open **Tools → Options** (**LibreOffice → Preferences** on a Mac) **→
   LibreOffice → Appearance**.
2. Tick **Enable application theming**, and choose **Jenerated Blue
   Purple** as the theme.
3. Click **OK**, and restart LibreOffice when it asks.

The window colors need a recent LibreOffice with application theming (on
the Appearance page). In older versions, the page is called **Application
Colors**; choosing the theme there colors documents but not the window.

After changing the palette, run `./setup.sh` again (with LibreOffice
closed), or add the new `.oxt` in **Tools → Extensions**, which replaces the
old one. Then restart LibreOffice.
