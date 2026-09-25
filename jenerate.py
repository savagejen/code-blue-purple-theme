#!/usr/bin/env python3
"""The Jenerator: generate app themes from the palettes you choose.

Usage:
    ./jenerate.py blue-purple                 # add one palette's themes
    ./jenerate.py blue-purple,sunset          # add several at once
    ./jenerate.py path/to/my-palette.toml     # a palette file anywhere
    ./jenerate.py --remove sunset             # remove a palette's themes
    ./jenerate.py --list                      # show palettes, mark generated

A palette is named by its slug (palettes/<slug>-palette.toml) or given as a
path to a .toml file. Each run adds to, or updates, the themes already
generated; nothing else is touched. Each template's {{name}} placeholders are
replaced with the palette's colors (plus its `name` and `slug`), and the result
is written next to the template. Each color is also available as RGB and HSL
numbers, for apps whose themes need them: {{accent_rgb}} is "88, 101, 243",
{{accent_rgb_csv}} is "88,101,243", {{accent_float}} is "0.3451, 0.3961,
0.9529" (each channel from 0 to 1), {{accent_h}}, {{accent_s}} and
{{accent_l}} are "235", "87" and "65", and {{accent_hex}} is "5865F3"
(without the #).
{{uuid}} is an ID made from the slug, the same every time, for apps that
identify themes by UUID.

Palettes can be dark or light. {{scheme}} is "dark" or "light": the palette's
optional `scheme` setting, or else worked out from its editor background
(`bg`). {{scheme: "a" | "b"}} gives "a" for dark palettes and "b" for light
ones, and {scheme} in a template's path picks a template for each.
"""

import argparse
import colorsys
import json
import re
import sys
import tomllib
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PALETTES = ROOT / "palettes"

# Generated VS Code theme files, relative to the repository root.
VSCODE_THEME = "app-themes/vs-code-theme/themes/jenerated-{slug}-color-theme.json"

# (template, output) pairs, relative to the repository root. {slug} in the
# output path is replaced with the palette's slug; it may name a folder, which
# is created as needed and deleted with the palette's last file. {scheme} in
# the template path is replaced with "dark" or "light", for apps whose dark
# and light themes differ too much for one template.
TARGETS = [
    ("app-themes/vs-code-theme/themes/color-theme.json.tmpl", VSCODE_THEME),
    ("app-themes/ptyxis-theme/palette.tmpl", "app-themes/ptyxis-theme/{slug}.palette"),
    ("app-themes/slack-theme/slack-theme.txt.tmpl", "app-themes/slack-theme/{slug}.txt"),
    ("app-themes/tilix-theme/scheme.json.tmpl", "app-themes/tilix-theme/{slug}.json"),
    ("app-themes/vim-theme/colorscheme.vim.tmpl", "app-themes/vim-theme/colors/jenerated-{slug}.vim"),
    ("app-themes/obsidian-theme/theme.css.tmpl", "app-themes/obsidian-theme/{slug}/theme.css"),
    ("app-themes/obsidian-theme/manifest.json.tmpl", "app-themes/obsidian-theme/{slug}/manifest.json"),
    ("app-themes/firefox-theme/manifest.json.tmpl", "app-themes/firefox-theme/{slug}/manifest.json"),
    ("app-themes/vivaldi-theme/settings.json.tmpl", "app-themes/vivaldi-theme/{slug}/settings.json"),
    ("app-themes/jetbrains-theme/plugin.xml.tmpl", "app-themes/jetbrains-theme/{slug}/META-INF/plugin.xml"),
    ("app-themes/jetbrains-theme/theme-{scheme}.json.tmpl", "app-themes/jetbrains-theme/{slug}/jenerated-{slug}.theme.json"),
    ("app-themes/jetbrains-theme/editor-scheme.xml.tmpl", "app-themes/jetbrains-theme/{slug}/jenerated-{slug}.xml"),
    ("app-themes/chromium-theme/manifest.json.tmpl", "app-themes/chromium-theme/{slug}/manifest.json"),
    ("app-themes/gtk3-theme/gtk.css.tmpl", "app-themes/gtk3-theme/{slug}/gtk-3.0/gtk.css"),
    ("app-themes/kde-theme/colors.tmpl", "app-themes/kde-theme/{slug}/Jenerated-{slug}.colors"),
    ("app-themes/kde-theme/konsole.colorscheme.tmpl", "app-themes/kde-theme/{slug}/Jenerated-{slug}.colorscheme"),
    ("app-themes/kde-theme/syntax.theme.tmpl", "app-themes/kde-theme/{slug}/Jenerated-{slug}.theme"),
    ("app-themes/gtk3-theme/index.theme.tmpl", "app-themes/gtk3-theme/{slug}/index.theme"),
    ("app-themes/decky-theme/theme.json.tmpl", "app-themes/decky-theme/{slug}/theme.json"),
    ("app-themes/decky-theme/shared.css.tmpl", "app-themes/decky-theme/{slug}/shared.css"),
    ("app-themes/godot-theme/text-editor.tet.tmpl", "app-themes/godot-theme/{slug}/Jenerated-{slug}.tet"),
    ("app-themes/godot-theme/editor-settings.cfg.tmpl", "app-themes/godot-theme/{slug}/editor-settings.cfg"),
]

# package.json is rebuilt from this base after every run, listing each VS Code
# theme file that exists.
VSCODE_PACKAGE_BASE = ROOT / "app-themes/vs-code-theme/package.json.tmpl"
VSCODE_PACKAGE = ROOT / "app-themes/vs-code-theme/package.json"

# A theme file's "type" -> the "uiTheme" VS Code expects in package.json.
VSCODE_UI_THEMES = {
    "dark": "vs-dark",
    "light": "vs",
    "hcDark": "hc-black",
    "hcLight": "hc-light",
}

HEX = re.compile(r"#[0-9a-fA-F]{6}")
# {{name}}, or {{scheme: "text for dark" | "text for light"}}.
PLACEHOLDER = re.compile(
    r'\{\{\s*(?:([A-Za-z0-9_]+)|scheme\s*:\s*"([^"]*)"\s*\|\s*"([^"]*)")\s*\}\}')
SCHEMES = ("dark", "light")
# Slugs become file names, so they're kept to lowercase words and dashes.
SLUG = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*")
# Each palette's {{uuid}} is made from its slug in this namespace.
UUID_NAMESPACE = uuid.uuid5(uuid.NAMESPACE_URL, "https://github.com/savagejen/jenerated-themes")


def is_path(arg):
    """Whether a command-line palette is a file path rather than a slug."""
    return arg.endswith(".toml") or "/" in arg


def check_slug(slug, source):
    """Exit unless `slug` is safe to use in a file name."""
    if not SLUG.fullmatch(slug):
        sys.exit(f"{source}: {slug!r} is not a valid slug (use lowercase "
                 f"letters, numbers and single dashes, e.g. blue-purple)")
    return slug


def palette_path(arg):
    """Turn a slug or a path into the palette file's path."""
    if is_path(arg):
        path = Path(arg)
    else:
        path = PALETTES / f"{check_slug(arg, 'palette')}-palette.toml"
    if not path.is_file():
        sys.exit(f"No palette named {arg!r} (looked for {path}). "
                 f"Run ./jenerate.py --list to see the available palettes.")
    return path


def read_palette_file(path):
    """Parse a palette file and check its `name`, `slug` and `colors`."""
    try:
        with open(path, "rb") as f:
            data = tomllib.load(f)
    except tomllib.TOMLDecodeError as error:
        sys.exit(f"{path}: not a valid palette file: {error}")

    for key in ("name", "slug"):
        if not isinstance(data.get(key), str):
            sys.exit(f"{path}: missing top-level `{key}` string")
    # The name is written into the themes as is, so it mustn't be able to
    # break out of a JSON string, an XML file or an INI line. It also names
    # the Obsidian theme's folder, so no slashes.
    name = data["name"]
    if any(c in '"\\/<>&' or not c.isprintable() for c in name):
        sys.exit(f"{path}: `name` can't contain quotes, slashes, "
                 f"backslashes, <, >, & or line breaks")
    if not name.strip() or name != name.strip():
        sys.exit(f"{path}: `name` can't be empty or start or end with spaces")
    slug = check_slug(data["slug"], path)
    if path.resolve().parent == PALETTES and path.name != f"{slug}-palette.toml":
        sys.exit(f"{path}: palettes in palettes/ must be named after their "
                 f"slug; rename it to {slug}-palette.toml")

    if data.get("scheme") not in (None, *SCHEMES):
        sys.exit(f'{path}: `scheme` must be "dark" or "light" (or left out, '
                 f"to work it out from `bg`)")

    colors = data.setdefault("colors", {})
    if not isinstance(colors, dict):
        sys.exit(f"{path}: `colors` must be a [colors] table")
    for key, value in colors.items():
        if not isinstance(value, str):
            sys.exit(f"{path}: color `{key}` must be a quoted string, like "
                     f'"#rrggbb" or "red"')
    return data


def color_formats(key, value):
    """The other forms of a #rrggbb color that templates can use."""
    r, g, b = (int(value[i:i + 2], 16) for i in (1, 3, 5))
    h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
    return {
        f"{key}_hex": value[1:],
        f"{key}_rgb": f"{r}, {g}, {b}",
        f"{key}_rgb_csv": f"{r},{g},{b}",
        f"{key}_float": f"{r / 255:.4f}, {g / 255:.4f}, {b / 255:.4f}",
        f"{key}_h": str(round(h * 360) % 360),
        f"{key}_s": str(round(s * 100)),
        f"{key}_l": str(round(l * 100)),
    }


def scheme_of(color):
    """ "light" for a background black text reads better on, else "dark"."""
    channels = [int(color[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    linear = [c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
              for c in channels]
    luminance = 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
    # The contrast with black beats the contrast with white.
    return "light" if (luminance + 0.05) / 0.05 > 1.05 / (luminance + 0.05) else "dark"


def load_palette(path):
    """Read a palette and return its template values: every color as
    #rrggbb (with references to other colors followed) and in its other
    forms (see color_formats), plus `name`, `slug`, `uuid` and `scheme`."""
    data = read_palette_file(path)
    colors = data["colors"]

    def resolve(key, chain=()):
        value = colors[key]
        chain += (key,)
        if HEX.fullmatch(value):
            return value
        if value in chain:
            sys.exit(f"{path}: color `{key}` refers to itself in a loop")
        if value not in colors:
            sys.exit(f"{path}: color `{key}` = {value!r} is not a #rrggbb "
                     f"value or the name of another color")
        return resolve(value, chain)

    values = {}
    for key in colors:
        values.update(color_formats(key, resolve(key)))
    # A color the palette defines outright wins over another's derived form.
    values.update((key, resolve(key)) for key in colors)
    values["name"] = data["name"]
    values["slug"] = data["slug"]
    values["uuid"] = str(uuid.uuid5(UUID_NAMESPACE, data["slug"]))
    values["scheme"] = data.get("scheme") or (scheme_of(values["bg"]) if "bg" in values else "dark")
    return values


def read_template(path):
    """Read a template, or exit naming it if it's missing."""
    try:
        return path.read_text()
    except FileNotFoundError:
        sys.exit(f"{path.relative_to(ROOT)}: template not found. Restore it "
                 f"(git checkout -- {path.relative_to(ROOT)}), or remove it "
                 f"from TARGETS in jenerate.py.")


def render(template_path, values):
    """Fill in a template's placeholders, or exit naming any missing ones."""
    text = read_template(template_path)
    missing = set()

    def substitute(match):
        key, for_dark, for_light = match.groups()
        if key is None:
            return for_dark if values["scheme"] == "dark" else for_light
        if key not in values:
            missing.add(key)
            return match.group(0)
        return values[key]

    result = PLACEHOLDER.sub(substitute, text)
    if missing:
        sys.exit(f"{template_path.relative_to(ROOT)}: the palette has no "
                 f"color named {', '.join(sorted(missing))}")
    return result


def template_path(template, values):
    """A template's file, with {scheme} in its path filled in."""
    return ROOT / template.format(scheme=values["scheme"])


def output_path(output, slug):
    return ROOT / output.format(slug=slug)


def slug_folders(slug):
    """The folders made just for this palette's files, like
    app-themes/obsidian-theme/sunset, deepest first (so each is empty by the
    time its parent is removed)."""
    folders = set()
    for _, output in TARGETS:
        folder = Path(output).parent
        while "{slug}" in str(folder):
            folders.add(ROOT / str(folder).format(slug=slug))
            folder = folder.parent
    return sorted(folders, key=lambda f: len(f.parts), reverse=True)


def read_vscode_theme(path):
    """Return a generated VS Code theme's name and type, or exit if the file
    is broken."""
    try:
        theme = json.loads(path.read_text())
        name, kind = theme["name"], theme.get("type", "dark")
    except (json.JSONDecodeError, KeyError, TypeError) as error:
        sys.exit(f"{path.relative_to(ROOT)}: not a valid theme file ({error}). "
                 f"Regenerate it with ./jenerate.py, or delete it.")
    return name, kind


def write_vscode_package(slugs=None):
    """Rebuild package.json with one entry per VS Code theme file on disk, or
    only for the palettes in `slugs` (for the committed default).

    Each theme's label in the picker is the `name` inside its theme file.
    """
    package = json.loads(read_template(VSCODE_PACKAGE_BASE))
    if slugs is None:
        paths = sorted(ROOT.glob(VSCODE_THEME.format(slug="*")))
    else:
        paths = [ROOT / VSCODE_THEME.format(slug=slug) for slug in slugs]
    themes = []
    for path in paths:
        name, kind = read_vscode_theme(path)
        themes.append({
            "label": name,
            "uiTheme": VSCODE_UI_THEMES.get(kind, "vs-dark"),
            "path": f"./{path.relative_to(VSCODE_PACKAGE.parent).as_posix()}",
        })
    package["contributes"]["themes"] = themes

    content = json.dumps(package, indent=2) + "\n"
    if not VSCODE_PACKAGE.exists() or VSCODE_PACKAGE.read_text() != content:
        VSCODE_PACKAGE.write_text(content)
        print(f"Updated {VSCODE_PACKAGE.relative_to(ROOT)}")


def add(names):
    """Generate every app's theme for each palette."""
    for name in names:
        values = load_palette(palette_path(name))
        # Render everything before writing anything, so a bad template
        # leaves no half-generated palette behind.
        rendered = [(output_path(output, values["slug"]),
                     render(template_path(template, values), values))
                    for template, output in TARGETS]
        for path, content in rendered:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content)
        print(f"Generated {values['name']} ({values['slug']})")


def remove(names):
    """Delete each palette's generated themes (the palette itself is kept)."""
    for name in names:
        if is_path(name):
            slug = read_palette_file(palette_path(name))["slug"]
        else:
            slug = check_slug(name, "palette")
        existing = [path for path in
                    (output_path(output, slug) for _, output in TARGETS)
                    if path.exists()]
        if not existing:
            print(f"{slug}: nothing to remove")
        for path in existing:
            path.unlink()
            print(f"Removed {path.relative_to(ROOT)}")
        for folder in slug_folders(slug):
            if folder.is_dir() and not any(folder.iterdir()):
                folder.rmdir()


def list_palettes():
    """Print each palette in palettes/, starring those already generated."""
    for path in sorted(PALETTES.glob("*-palette.toml")):
        data = read_palette_file(path)
        generated = any(output_path(output, data["slug"]).exists()
                        for _, output in TARGETS)
        mark = "*" if generated else " "
        print(f"{mark} {data['slug']:<24} {data['name']}")
    print("\n* = generated")


def main():
    parser = argparse.ArgumentParser(
        description=__doc__.split("\n")[0],
        epilog="Separate several palettes with commas or spaces.")
    parser.add_argument("palettes", nargs="*",
                        help="palette slugs (e.g. blue-purple) or .toml paths")
    action = parser.add_mutually_exclusive_group()
    action.add_argument("--remove", action="store_true",
                        help="delete these palettes' generated themes")
    action.add_argument("--list", action="store_true",
                        help="list the palettes in palettes/")
    args = parser.parse_args()

    if args.list:
        if args.palettes:
            parser.error("--list doesn't take palettes")
        list_palettes()
        return

    names = [name.strip() for arg in args.palettes
             for name in arg.split(",") if name.strip()]
    if not names:
        parser.error("name at least one palette, e.g. ./jenerate.py "
                     "blue-purple (see ./jenerate.py --list)")

    if args.remove:
        remove(names)
    else:
        add(names)
    write_vscode_package()


if __name__ == "__main__":
    main()
