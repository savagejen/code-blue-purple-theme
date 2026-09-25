# Palette Creator

A page for designing a palette in your browser. It shows a generic app window
(an editor with syntax colors, a sidebar, tabs, a terminal, buttons, inputs,
notifications and a diff) built only from the palette's colors, and recolors
it as you edit.

## Start it

Needs Python 3.11 or later. Run `./setup.sh` from the repository root and
choose **Design a new palette**; it explains the steps below, then starts
the Palette Creator. Or start it directly:

```bash
./palette-creator/serve.py
```

It opens the page in your browser (use `--no-browser` to just print the
address, or `--port` to pick another port). Press `Ctrl+C` in the terminal to
stop it. The page only works while `serve.py` is running, and only from this
computer.

## Design a palette

- **Work in progress:** the page edits `work-in-progress-palette.toml` in
  this folder. It's created from Blue Purple the first time you start
  `serve.py`, and git ignores it, so your drafts stay yours. To begin from a
  different palette, choose it under **Start from**.
- **Colors:** each color has a color picker, and a text field that takes a
  `#rrggbb` value or another color's name (like `red`), just as in a palette
  file. A color that refers to another shows what it resolves to.
- **Finding colors:** hover over a color to highlight where the preview uses
  it (including colors that refer to it), or click part of the preview to
  jump to its color.
- **Checking:** the page checks the palette with `jenerate.py`'s own rules as
  you type, and shows what's wrong, such as a slug with capitals or a color
  the templates need. Hot pink in the preview means a color is missing or
  invalid.

## Save it

- **Save** writes the work-in-progress file.
- **Save as palette…** opens your computer's save dialog in `palettes/`,
  suggesting `<slug>-palette.toml` (for example `sunset-palette.toml`). Keep
  that name: `jenerate.py` finds palettes in `palettes/` by their slug, so it
  won't accept another name there. You can also save somewhere else and pass
  the file's path to `jenerate.py`. The dialog is `zenity` or `kdialog` on
  Linux, or the standard one on macOS; without one, the page asks for a file
  name in `palettes/` instead. Then generate its themes:

  ```bash
  ./jenerate.py <slug>
  ```

Saving keeps the palette file's layout: its header comments, its groups of
colors with their titles, and each color's note.
