#!/usr/bin/env python3
"""Update the palette screenshots and palettes/README.md (for maintainers).

Usage:
    ./palette-creator/screenshots.py                # screenshots, then README
    ./palette-creator/screenshots.py candy,sunset   # just these palettes' screenshots
    ./palette-creator/screenshots.py --readme-only  # just the README

Screenshots each palette in palettes/ (or just the ones named, by slug) in
the Palette Creator's preview, into palettes/Screenshots/<slug>.png, using Playwright (screenshots.js). The
Palette Creator runs on a throwaway copy of the repository, so the real
work-in-progress palette is never touched. Playwright is installed into
~/.cache/jenerated-themes/playwright (outside the repository) the first time,
with its browser, which needs Node.js, npm and a network connection.

Then updates palettes/README.md: palettes with a screenshot but no section
get one (from their description and key colors), and existing sections get
their key colors refreshed. Other text is left alone; sections and
screenshots for palettes that no longer exist are reported, not removed.

./setup.sh --update-screenshots runs this, and ./setup.sh
--update-screenshots=candy,sunset runs it for just those palettes.
"""

import argparse
import os
import re
import shutil
import socket
import subprocess
import sys
import tempfile
import textwrap
import time
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import serve  # noqa: E402  (needs the path above)
from serve import jenerate  # noqa: E402

ROOT = jenerate.ROOT
PALETTES = jenerate.PALETTES
SCREENSHOTS = PALETTES / "Screenshots"
README = PALETTES / "README.md"
CACHE = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "jenerated-themes" / "playwright"
# The line under each screenshot in the README, with the palette's key colors.
COLORS_LINE = re.compile(r"^Editor `#[0-9a-fA-F]{6}` · Sidebar .*$", re.M)
IMAGE = re.compile(r"\]\(Screenshots/([a-z0-9-]+)\.png\)")


def palette_files():
    return sorted(PALETTES.glob("*-palette.toml"))


def slug_of(path):
    return path.name.removesuffix("-palette.toml")


# --- Screenshots -------------------------------------------------------------

def playwright():
    """The folder whose node_modules has Playwright and its browser,
    installing them the first time."""
    for tool in ("node", "npm"):
        if not shutil.which(tool):
            sys.exit("Updating screenshots needs Node.js and npm (for Playwright)")
    if not (CACHE / "node_modules" / "playwright").is_dir():
        print(f"Installing Playwright into {CACHE}", flush=True)
        CACHE.mkdir(parents=True, exist_ok=True)
        subprocess.run(["npm", "install", "--prefix", str(CACHE), "--no-save",
                        "--no-audit", "--no-fund", "--silent", "playwright"],
                       env={**os.environ, "PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD": "1"},
                       check=True)
    # Fetches the browser if it's missing; quick when it's already there.
    subprocess.run([str(CACHE / "node_modules" / ".bin" / "playwright"),
                    "install", "--only-shell", "chromium"], check=True)
    return CACHE


def copy_repository(target):
    """Copy the repository as git sees it (tracked files, and new ones that
    aren't ignored) into target; outside a git repository, the whole folder."""
    try:
        listed = subprocess.run(["git", "-C", str(ROOT), "ls-files", "-z", "--cached",
                                 "--others", "--exclude-standard"],
                                capture_output=True, check=True).stdout
    except (OSError, subprocess.CalledProcessError):
        shutil.copytree(ROOT, target, ignore=shutil.ignore_patterns(".git", "__pycache__"))
        return
    for name in filter(None, listed.decode().split("\0")):
        source = ROOT / name
        if source.is_file():
            (target / name).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target / name)


def free_port():
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


def take_screenshots(files):
    modules = playwright()
    SCREENSHOTS.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as folder:
        copy = Path(folder) / "repo"
        copy_repository(copy)
        port = free_port()
        server = subprocess.Popen(
            [sys.executable, str(copy / "palette-creator" / "serve.py"),
             "--no-browser", "--port", str(port)],
            env={**os.environ, "PALETTE_CREATOR_DIALOG": "none"},
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            base = f"http://127.0.0.1:{port}"
            for _ in range(100):
                try:
                    urllib.request.urlopen(base, timeout=1)
                    break
                except OSError:
                    time.sleep(0.05)
            else:
                sys.exit("The Palette Creator didn't start")
            subprocess.run(["node", str(HERE / "screenshots.js"), base, str(SCREENSHOTS),
                            *[f.name for f in files]],
                           env={**os.environ, "NODE_PATH": str(modules / "node_modules")},
                           check=True)
        finally:
            server.terminate()
            server.wait()


# --- README --------------------------------------------------------------------

def colors_line(palette):
    """The line of key colors under a palette's screenshot."""
    colors = serve.jenerate_check(jenerate.load_palette, palette["path"])
    return " · ".join(f"{label} `{colors[key]}`" for label, key in
                      (("Editor", "bg"), ("Sidebar", "bg_sidebar"),
                       ("Accent", "accent"), ("Text", "text")))


def section(palette):
    """A new README section for a palette."""
    name, slug = palette["name"], palette["slug"]
    description = "\n\n".join(textwrap.fill(p, 78, break_long_words=False,
                                            break_on_hyphens=False)
                              for p in palette["description"].split("\n\n") if p.strip())
    parts = [f"## {name}", f"`{slug}`"]
    if description:
        parts.append(description)
    parts += [f"![The {name} palette in the Palette Creator's preview](Screenshots/{slug}.png)",
              colors_line(palette)]
    return "\n\n".join(parts) + "\n"


def update_readme():
    text = README.read_text() if README.exists() else ""
    if not text.strip():
        text = "# Palettes\n"
    palettes = {}
    for path in palette_files():
        palette = serve.read_palette(path)
        palette["path"] = path
        palettes[palette["slug"]] = palette

    # Refresh the key colors in each section that has a palette.
    starts = [m.start() for m in re.finditer(r"^## ", text, re.M)] + [len(text)]
    chunks = [text[:starts[0]]] + [text[a:b] for a, b in zip(starts, starts[1:])]
    listed = set()
    for i, chunk in enumerate(chunks):
        image = IMAGE.search(chunk)
        if not image:
            continue
        slug = image.group(1)
        listed.add(slug)
        if slug not in palettes:
            print(f"palettes/README.md has a section for {slug}, which isn't a palette any more")
        elif COLORS_LINE.search(chunk):
            chunks[i] = COLORS_LINE.sub(colors_line(palettes[slug]), chunk, count=1)
    text = "".join(chunks)

    # Add sections for palettes that have a screenshot but no section.
    added = []
    for slug, palette in palettes.items():
        if slug in listed:
            continue
        if not (SCREENSHOTS / f"{slug}.png").exists():
            print(f"No screenshot of {slug}, so it isn't added to palettes/README.md")
            continue
        text = text.rstrip("\n") + "\n\n" + section(palette)
        added.append(slug)

    for png in sorted(SCREENSHOTS.glob("*.png")) if SCREENSHOTS.is_dir() else []:
        if png.stem not in palettes:
            print(f"palettes/Screenshots/{png.name} is of {png.stem}, which isn't a palette any more")

    if not README.exists() or README.read_text() != text:
        README.write_text(text)
        print("Updated palettes/README.md" + (f" (added {', '.join(added)})" if added else ""))
    else:
        print("palettes/README.md is up to date")


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--readme-only", action="store_true",
                        help="only update palettes/README.md")
    parser.add_argument("slugs", nargs="*", metavar="slug",
                        help="palettes to screenshot, by slug (commas or spaces "
                             "between several); all of them if none are named")
    args = parser.parse_args()
    slugs = [s for arg in args.slugs for s in arg.split(",") if s]
    if args.readme_only and slugs:
        parser.error("--readme-only updates the README for every palette; "
                     "leave out the palette names")
    files = palette_files()
    if slugs:
        by_slug = {slug_of(f): f for f in files}
        unknown = [s for s in slugs if s not in by_slug]
        if unknown:
            sys.exit(f"No palette in palettes/ called {', '.join(unknown)} "
                     f"(the palettes are: {', '.join(by_slug)})")
        files = [by_slug[s] for s in dict.fromkeys(slugs)]
    if not args.readme_only:
        take_screenshots(files)
    # The README covers every palette, so its key colors stay current.
    update_readme()


if __name__ == "__main__":
    main()
