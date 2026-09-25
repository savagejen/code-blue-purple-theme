# Contributing to Jenerated Themes

Thanks for helping out! This covers how the project fits together, how to add
a palette or an app, and what to run before committing. For installing and
using the themes, see the [README](README.md).

## Setting up

1. Clone the repository:

   ```bash
   git clone https://github.com/savagejen/jenerated-themes jenerated-themes
   cd jenerated-themes
   ```

2. Turn on the git hook, once per clone (git doesn't copy this setting when
   you clone):

   ```bash
   git config core.hooksPath .githooks
   ```

   It's a pre-commit hook that refuses a commit while a palette in
   `palettes/` uses a color from
   [palettes/avoid-these.txt](palettes/avoid-these.txt); see
   [Colors to avoid](#colors-to-avoid). The tests check the same thing, so
   nothing slips through on a clone without it.

What you need:

- **Python 3.11 or later**, for `jenerate.py`, the Palette Creator and most
  of the tests. Nothing to install beyond Python itself.
- **`curl`**, for the Palette Creator tests.
- **Node.js and npm**, only for [updating screenshots](#screenshots).

## How it works

- **Palettes** in [palettes/](palettes/) are TOML files with a `name`, a
  `slug`, an optional `scheme` (`"dark"` or `"light"`), and a list of colors
  named by role (`bg`, `text`, `accent`, `red`, `term_bright_cyan`, ...). A
  color is a `#rrggbb` value or the name of another color in the same file.
- **Templates** (the `.tmpl` files in each app's folder, under
  [app-themes/](app-themes/)) are the app's theme file with `{{color_name}}`
  placeholders where the colors go.
- **[jenerate.py](jenerate.py)** fills in every template for each palette
  you name and writes the results next to the templates, named after the
  palette's slug. `TARGETS` at the top of the file lists each
  `(template, output)` pair. For VS Code it also rebuilds
  `app-themes/vs-code-theme/package.json` from `package.json.tmpl`, listing
  every generated theme.

### Template placeholders

- `{{accent}}` gives the color as `#rrggbb`. A template can add transparency
  after it, for example `{{accent}}33`.
- For apps that need them, each color is also available as numbers:
  `{{accent_rgb}}` gives `88, 101, 243`, `{{accent_rgb_csv}}` gives
  `88,101,243`, `{{accent_h}}`, `{{accent_s}}` and `{{accent_l}}` give `235`,
  `87` and `65`, and `{{accent_hex}}` gives `5865F3` (without the `#`).
- `{{name}}` and `{{slug}}` are the palette's name and slug.
- `{{uuid}}` is an ID made from the palette's slug, the same every time, for
  apps that identify themes by UUID.
- `{{scheme}}` is `dark` or `light`, and
  `{{scheme: "text for dark" | "text for light"}}` picks one of two texts. A
  template whose dark and light versions differ too much for that can have
  `{scheme}` in its path in `TARGETS`, like JetBrains'
  `theme-{scheme}.json.tmpl`.

`jenerate.py` works out whether a palette is dark or light from its editor
background (`bg`), unless the palette sets `scheme`.

### The text colors

Most roles explain themselves. Two are easy to mix up, and matter most for
light palettes:

- `text_bright` is text **on the accent color**: buttons, badges, selected
  menu items.
- `text_strong` is emphasized text **on ordinary backgrounds**: the active
  tab, the selected file, bold terminal text.

On a dark palette both are usually white. On a light palette `text_bright`
stays light, for the accent, and `text_strong` is dark. When a template
needs one of them, pick by what the text sits on.

### Generated files and Blue Purple

Generated files are ignored by git (see [.gitignore](.gitignore)), so each
person's copy holds only the palettes they chose. The exception is Blue
Purple, the default: its generated files are committed, along with a
`package.json` that lists only it, so the themes work without running
anything. The Vivaldi `.zip` and JetBrains `.jar` of Blue Purple are
committed too, ready to install.

Generating other palettes changes `package.json` in your copy. Don't commit
that; [prepare for the commit](#before-you-commit) instead, which puts it
back.

Don't edit generated files by hand; change the palette or template and run
`jenerate.py` again.

## Adding a palette

Design it in the [Palette Creator](palette-creator/)
(`./palette-creator/serve.py`), or copy an existing palette to
`palettes/<slug>-palette.toml` and edit it. Every color the templates use
must be defined; `jenerate.py` names any that are missing, and checks the
palette's other rules (see
[Adding a palette](README.md#adding-a-palette) in the README).

Then:

1. Generate it and try it in a few apps: `./jenerate.py <slug>`.
2. Write a description as the comment at the top of the file: what the
   palette is and where its colors come from. It becomes the palette's
   section in [palettes/README.md](palettes/README.md).
3. Check that text is readable: body text, comments and the syntax colors
   against `bg`, `text_bright` against `accent`, and `text_strong` against
   `bg` and `bg_selected`. The tests require `text_strong` to reach 4.5:1
   against `bg` and `bg_selected`.
4. [Update the screenshots](#screenshots), which adds the palette's
   screenshot and README section.

### Colors to avoid

The palettes published here leave out the exact colors listed in
[palettes/avoid-these.txt](palettes/avoid-these.txt): colors too iconic to
publish. It's a style choice. A nearby shade is fine (one digit off is
enough), and anyone is welcome to use these colors in their own palettes.

The list is one `#rrggbb` per line, with `# ` comments. The pre-commit hook
and the tests in `tests/hooks/` read it, so adding a color there is all it
takes.

## Adding an app

1. Create a folder in `app-themes/`, such as `app-themes/example-theme/`,
   with a template (`<something>.tmpl`) that uses the palette's color names.
   Start the template with a comment saying it's generated and not to edit
   it, where the format allows comments.
2. Add a `(template, output)` pair to `TARGETS` in `jenerate.py`. Use
   `{slug}` in the output path so each palette gets its own file. An app
   that needs several files per theme can use `{slug}` as a folder, like
   Obsidian's `app-themes/obsidian-theme/{slug}/theme.css`.
3. Add the output pattern to `.gitignore`, with a `!` line keeping Blue
   Purple's files, like the other apps.
4. Write a README for the app: what it themes, which palette colors go
   where, and how to install it (with `./setup.sh`, and by hand).
5. Add the app to the list in the main [README](README.md), and to
   `setup.sh`: an entry in the app menu (`APPS` and `APP_IDS`; the
   Linux-only ones are added separately), an `install_<app>` function, and
   a line in the `case` at the end.
6. Add tests: in `tests/jenerate/` for the generated files (that they exist,
   use the palette's colors, are valid for the app's format, and are removed
   with the palette), and in `tests/setup/` for the install. Add the new
   files to the lists in `test_generates_every_app_theme`,
   `test_fills_in_every_placeholder` and
   `test_blue_purple_matches_the_committed_files`.
7. [Prepare for the commit](#before-you-commit), which generates Blue
   Purple's files for the new app.

If the app installs a packaged file (like Vivaldi's `.zip`), add Blue
Purple's package to `EXAMPLE_PACKAGES` in `setup.sh`, so it's rebuilt with
the other defaults.

## Changing a template or Blue Purple

After changing any template, or the Blue Purple palette,
[prepare for the commit](#before-you-commit), and commit the regenerated
Blue Purple files along with your change, so the default stays in sync. The
tests check that they match.

## Before you commit

1. Put the committed defaults back:

   ```bash
   ./setup.sh --prep-commit
   ```

   It regenerates Blue Purple's files (restoring any you removed, and
   updating them for any template change), rebuilds `package.json` listing
   only Blue Purple, and rebuilds the Blue Purple packages. Your other
   generated themes stay on disk, since git ignores them; it prints the
   command to list them in VS Code again afterward.

2. Run the tests:

   ```bash
   tests/run.sh
   ```

3. Commit. The pre-commit hook checks the palettes against the colors to
   avoid.

## Screenshots

Each palette has a screenshot in `palettes/Screenshots/` and a section in
[palettes/README.md](palettes/README.md). To retake them all:

```bash
./setup.sh --update-screenshots
```

To retake just some, name them by slug, with commas between several:

```bash
./setup.sh --update-screenshots=candy
./setup.sh --update-screenshots=candy,sunset
```

It shows each palette in the Palette Creator's preview (running on a
throwaway copy of the repository, so your draft is never touched), saves a
screenshot of it with [Playwright](https://playwright.dev), and updates
`palettes/README.md`: a new palette gets a section, made from its
description and key colors, and existing sections get their key colors
refreshed. Text you've written in the README is left alone.

The first run installs Playwright and its browser into
`~/.cache/jenerated-themes/playwright`, outside the repository, which needs a
network connection. See
[palette-creator/screenshots.py](palette-creator/screenshots.py) for the
details.

## Running the tests

```bash
tests/run.sh
```

Tests live in [tests/](tests/), with one folder per script:

| Folder | Tests |
|--------|-------|
| `tests/jenerate/` | `jenerate.py` and the generated files |
| `tests/setup/` | `setup.sh`, with a temporary home folder |
| `tests/palette-creator/` | the Palette Creator's `serve.py` |
| `tests/screenshots/` | the screenshot script, and its updates to `palettes/README.md` |
| `tests/hooks/` | the git hooks in `.githooks/` |

Each test runs against a temporary copy of the repository, so the tests
don't touch your generated or installed themes. Tests that need Python 3.11
or `curl` are skipped without them. Shared helpers are in `tests/lib.sh`.

Tests are shell functions named `test_...`, each with a comment above it in
the form:

```bash
# GIVEN the Sunset palette
# WHEN generating it
# THEN no generated file has a {{ placeholder left in it
test_fills_in_every_placeholder() {
```

## License

The project is under the [MIT License](LICENSE). By contributing, you agree
that your contribution is licensed under it too.
