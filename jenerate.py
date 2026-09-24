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

# (template, output) pairs, relative to the repository root. {slug} in the
# output path is replaced with the palette's slug.
TARGETS = [
    ("vs-code-theme/themes/color-theme.json.tmpl",
     "vs-code-theme/themes/jenerated-{slug}-color-theme.json"),
    ("ptyxis-theme/palette.tmpl", "ptyxis-theme/{slug}.palette"),
    ("slack-theme/slack-theme.txt.tmpl", "slack-theme/{slug}.txt"),
]

# package.json is rebuilt from this base after every run, listing each VS Code
# theme file that exists.
VSCODE_PACKAGE_BASE = "vs-code-theme/package.json.tmpl"
VSCODE_PACKAGE = "vs-code-theme/package.json"
VSCODE_THEME_GLOB = "themes/jenerated-*-color-theme.json"

HEX = re.compile(r"#[0-9a-fA-F]{6}")
PLACEHOLDER = re.compile(r"\{\{\s*([A-Za-z0-9_]+)\s*\}\}")


def palette_path(arg):
    """Turn a slug or a path into the palette file's path."""
    if arg.endswith(".toml") or "/" in arg:
        path = Path(arg)
    else:
        path = PALETTES / f"{arg}-palette.toml"
    if not path.is_file():
        sys.exit(f"No palette named {arg!r} (looked for {path}). "
                 f"Run ./jenerate.py --list to see the available palettes.")
    return path


def read_toml(path):
    with open(path, "rb") as f:
        data = tomllib.load(f)
    for key in ("name", "slug"):
        if not isinstance(data.get(key), str):
            sys.exit(f"{path}: missing top-level `{key}` string")
    return data


def load_palette(path):
    data = read_toml(path)
    raw = data.get("colors", {})

    def resolve(key, seen=()):
        value = raw[key]
        if HEX.fullmatch(value):
            return value
        if value in seen or value == key:
            sys.exit(f"{path}: color `{key}` refers to itself in a loop")
        if value not in raw:
            sys.exit(f"{path}: color `{key}` = {value!r} is not a #rrggbb "
                     f"value or the name of another color")
        return resolve(value, seen + (key,))

    values = {key: resolve(key) for key in raw}
    values["name"] = data["name"]
    values["slug"] = data["slug"]
    return values


def render(template_path, values):
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


def outputs_for(slug):
    return [ROOT / output.format(slug=slug) for _, output in TARGETS]


def write_vscode_package():
    """Rebuild package.json with one entry per VS Code theme file on disk.

    Each theme's label in the picker is the `name` inside its theme file.
    """
    package = json.loads((ROOT / VSCODE_PACKAGE_BASE).read_text())
    package_path = ROOT / VSCODE_PACKAGE
    package["contributes"]["themes"] = [
        {
            "label": json.loads(path.read_text())["name"],
            "uiTheme": "vs-dark",
            "path": f"./themes/{path.name}",
        }
        for path in sorted(package_path.parent.glob(VSCODE_THEME_GLOB))
    ]
    content = json.dumps(package, indent=2) + "\n"
    if not package_path.exists() or package_path.read_text() != content:
        package_path.write_text(content)
        print(f"Updated {package_path.relative_to(ROOT)}")


def add(args):
    for arg in args:
        values = load_palette(palette_path(arg))
        rendered = [(out, render(ROOT / template, values))
                    for (template, _), out
                    in zip(TARGETS, outputs_for(values["slug"]))]
        for out, content in rendered:
            out.write_text(content)
        print(f"Generated {values['name']} ({values['slug']})")


def remove(args):
    for arg in args:
        is_path = arg.endswith(".toml") or "/" in arg
        slug = read_toml(palette_path(arg))["slug"] if is_path else arg
        existing = [p for p in outputs_for(slug) if p.exists()]
        if not existing:
            print(f"{slug}: nothing to remove")
        for path in existing:
            path.unlink()
            print(f"Removed {path.relative_to(ROOT)}")


def list_palettes():
    for path in sorted(PALETTES.glob("*-palette.toml")):
        data = read_toml(path)
        generated = any(p.exists() for p in outputs_for(data["slug"]))
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

    names = [n for arg in args.palettes for n in arg.split(",") if n.strip()]
    names = [n.strip() for n in names]
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
