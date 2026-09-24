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
is written next to the template.
"""

import argparse
import json
import re
import sys
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PALETTES = ROOT / "palettes"

# Generated VS Code theme files, relative to the repository root.
VSCODE_THEME = "vs-code-theme/themes/jenerated-{slug}-color-theme.json"

# (template, output) pairs, relative to the repository root. {slug} in the
# output path is replaced with the palette's slug.
TARGETS = [
    ("vs-code-theme/themes/color-theme.json.tmpl", VSCODE_THEME),
    ("ptyxis-theme/palette.tmpl", "ptyxis-theme/{slug}.palette"),
    ("slack-theme/slack-theme.txt.tmpl", "slack-theme/{slug}.txt"),
]

# package.json is rebuilt from this base after every run, listing each VS Code
# theme file that exists.
VSCODE_PACKAGE_BASE = ROOT / "vs-code-theme/package.json.tmpl"
VSCODE_PACKAGE = ROOT / "vs-code-theme/package.json"

# A theme file's "type" -> the "uiTheme" VS Code expects in package.json.
VSCODE_UI_THEMES = {
    "dark": "vs-dark",
    "light": "vs",
    "hcDark": "hc-black",
    "hcLight": "hc-light",
}

HEX = re.compile(r"#[0-9a-fA-F]{6}")
PLACEHOLDER = re.compile(r"\{\{\s*([A-Za-z0-9_]+)\s*\}\}")
# Slugs become file names, so they're kept to lowercase words and dashes.
SLUG = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*")


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
    # break out of a JSON string or an INI line.
    if any(c in '"\\' or not c.isprintable() for c in data["name"]):
        sys.exit(f"{path}: `name` can't contain quotes, backslashes or "
                 f"line breaks")
    slug = check_slug(data["slug"], path)
    if path.resolve().parent == PALETTES and path.name != f"{slug}-palette.toml":
        sys.exit(f"{path}: palettes in palettes/ must be named after their "
                 f"slug; rename it to {slug}-palette.toml")

    colors = data.setdefault("colors", {})
    if not isinstance(colors, dict):
        sys.exit(f"{path}: `colors` must be a [colors] table")
    for key, value in colors.items():
        if not isinstance(value, str):
            sys.exit(f"{path}: color `{key}` must be a quoted string, like "
                     f'"#rrggbb" or "red"')
    return data


def load_palette(path):
    """Read a palette and return its template values: every color as
    #rrggbb (with references to other colors followed), plus `name` and
    `slug`."""
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

    values = {key: resolve(key) for key in colors}
    values["name"] = data["name"]
    values["slug"] = data["slug"]
    return values


def render(template_path, values):
    """Fill in a template's placeholders, or exit naming any missing ones."""
    text = template_path.read_text()
    missing = set()

    def substitute(match):
        key = match.group(1)
        if key not in values:
            missing.add(key)
            return match.group(0)
        return values[key]

    result = PLACEHOLDER.sub(substitute, text)
    if missing:
        sys.exit(f"{template_path.relative_to(ROOT)}: the palette has no "
                 f"color named {', '.join(sorted(missing))}")
    return result


def output_path(output, slug):
    return ROOT / output.format(slug=slug)


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


def write_vscode_package():
    """Rebuild package.json with one entry per VS Code theme file on disk.

    Each theme's label in the picker is the `name` inside its theme file.
    """
    package = json.loads(VSCODE_PACKAGE_BASE.read_text())
    themes = []
    for path in sorted(ROOT.glob(VSCODE_THEME.format(slug="*"))):
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
                     render(ROOT / template, values))
                    for template, output in TARGETS]
        for path, content in rendered:
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
