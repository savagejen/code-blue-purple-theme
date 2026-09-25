#!/usr/bin/env python3
"""Palette Creator: design a palette in your browser, with a live preview.

Usage:
    ./palette-creator/serve.py              # open the page in your browser
    ./palette-creator/serve.py --port 9000  # use another port
    ./palette-creator/serve.py --no-browser # just print the address

Serves palette-creator.html on 127.0.0.1 (this computer only). The page edits
work-in-progress-palette.toml, which is created from Blue Purple the first
time. "Load from" copies a palette over it, and "Save as palette" saves it as
a palette; both open this computer's file dialog in palettes/ (zenity or
kdialog on Linux, AppleScript on macOS, or Tk), and without one the page asks
for a file name. Palettes are checked with jenerate.py's own rules, and
saving and loading keep the file's comments and layout.

Set PALETTE_CREATOR_DIALOG=none to always name the file in the page instead
(the tests do this).
"""

import argparse
import json
import os
import platform
import re
import shutil
import subprocess
import sys
import tempfile
import textwrap
import webbrowser
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from urllib.parse import urlparse

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
import jenerate  # noqa: E402  (needs the path above)

PAGE = HERE / "palette-creator.html"
WIP = HERE / "work-in-progress-palette.toml"
STARTER = jenerate.PALETTES / "blue-purple-palette.toml"

# A color line: key = "value"  # note
COLOR_LINE = re.compile(
    r"""^([A-Za-z0-9_]+)\s*=\s*(?:"[^"]*"|'[^']*')\s*(?:#\s?(.*))?$""")
# Color names must be usable as template placeholders.
COLOR_KEY = re.compile(r"[A-Za-z0-9_]+")
# Notes line up in a column, as in the palettes in palettes/.
NOTE_COLUMN = 30
# The note that ends each palette's header comment. It isn't part of the
# description the page edits, and a rebuilt header always ends with it.
COLOR_NOTE = ["Every color is a #rrggbb hex value, or the name of another color in this",
              "file. Templates add transparency themselves (e.g. {{accent}}33)."]
# Header comment lines are wrapped to fit 78 columns with their "# ".
HEADER_WIDTH = 76
MAX_BODY = 1_000_000


class PaletteError(Exception):
    """A palette jenerate.py would reject, with a message for the page."""


def jenerate_check(function, *args, path=None):
    """Call a jenerate.py function, turning its exit message into an error.

    Messages about a temporary file drop the file's path.
    """
    try:
        return function(*args)
    except SystemExit as error:
        message = str(error.code)
        if path is not None:
            message = message.replace(f"{path}: ", "")
        raise PaletteError(message) from None


def header_paragraphs(header):
    """Split header comment lines into paragraphs (lists of lines)."""
    paragraphs, current = [], []
    for line in header + [""]:
        if line.strip():
            current.append(line.strip())
        elif current:
            paragraphs.append(current)
            current = []
    return paragraphs


def description_from_header(header):
    """The header comment as the page's description: each paragraph on one
    line, paragraphs separated by a blank line, without the color note."""
    return "\n\n".join(" ".join(p) for p in header_paragraphs(header)
                        if not " ".join(p).startswith(COLOR_NOTE[0][:30]))


def header_from_description(description):
    """Header comment lines for a description: its paragraphs wrapped to the
    palettes' usual width, then the color note."""
    if not isinstance(description, str):
        raise PaletteError("the description must be text")
    description = description.replace("\r\n", "\n").replace("\r", "\n")
    if any(not c.isprintable() and c != "\n" for c in description):
        raise PaletteError("the description can't contain tabs or other "
                           "control characters")
    header = []
    for paragraph in re.split(r"\n\s*\n", description.strip()):
        if paragraph.strip():
            header += textwrap.wrap(" ".join(paragraph.split()), HEADER_WIDTH,
                                    break_long_words=False, break_on_hyphens=False)
            header.append("")
    return header + COLOR_NOTE


def read_palette(path):
    """Read a palette file into the page's form: its header comments (and
    their description), name, slug, and colors in titled groups, each with
    its value and note."""
    data = jenerate_check(jenerate.read_palette_file, path)
    colors = data["colors"]
    header, groups, seen = [], [], set()
    in_header, in_colors, group = True, False, None

    for line in path.read_text().splitlines():
        text = line.strip()
        if not in_colors:
            if text == "[colors]":
                in_colors = True
            elif text.startswith("#") and in_header:
                header.append(re.sub(r"^#\s?", "", text))
            elif text:
                in_header = False
            continue
        if text.startswith("["):
            break
        if not text:
            group = None
        elif text.startswith("#"):
            group = {"title": text.lstrip("#").strip(), "colors": []}
            groups.append(group)
        elif (match := COLOR_LINE.match(text)) and match[1] in colors:
            if group is None:
                group = {"title": "", "colors": []}
                groups.append(group)
            group["colors"].append({"key": match[1], "value": colors[match[1]],
                                    "note": (match[2] or "").strip()})
            seen.add(match[1])

    # Colors written in a way the line pattern doesn't follow still count.
    rest = [{"key": key, "value": value, "note": ""}
            for key, value in colors.items() if key not in seen]
    if rest:
        groups.append({"title": "", "colors": rest})
    groups = [g for g in groups if g["colors"]]
    return {"header": header, "description": description_from_header(header),
            "name": data["name"], "slug": data["slug"], "scheme": data.get("scheme"),
            "groups": groups}


def one_line(text, what):
    if not isinstance(text, str):
        raise PaletteError(f"{what} must be text")
    if any(not c.isprintable() for c in text):
        raise PaletteError(f"{what} can't contain line breaks")
    return text.strip()


def write_palette(palette):
    """Turn the page's form back into palette file text, laid out like the
    palettes in palettes/."""
    try:
        header = [one_line(h, "A header comment") for h in palette["header"]]
        # Keep the header exactly as written unless the description changed.
        description = palette.get("description")
        if description is not None and description != description_from_header(header):
            header = header_from_description(description)
        name, slug = palette["name"], palette["slug"]
        groups = palette["groups"]
        if not isinstance(name, str) or not isinstance(slug, str):
            raise PaletteError("name and slug must be text")
        lines = [f"# {h}".rstrip() for h in header]
        if lines:
            lines.append("")
        # json.dumps writes a valid TOML string, so a stray quote is caught
        # by jenerate.py's checks, with its usual message.
        lines += [f"name = {json.dumps(name)}", f"slug = {json.dumps(slug)}"]
        # A palette can say it's dark or light; otherwise that's worked out.
        if palette.get("scheme") is not None:
            lines.append(f"scheme = {json.dumps(palette['scheme'])}")
        lines += ["", "[colors]"]
        keys = set()
        for i, group in enumerate(groups):
            if i:
                lines.append("")
            title = one_line(group["title"], "A group title")
            if title:
                lines.append(f"# {title}")
            for color in group["colors"]:
                key, value = color["key"], color["value"]
                note = one_line(color.get("note", ""), f"The note for `{key}`")
                if not isinstance(key, str) or not COLOR_KEY.fullmatch(key):
                    raise PaletteError(f"{key!r} can't be a color name (use "
                                       f"letters, numbers and underscores)")
                if key in keys:
                    raise PaletteError(f"color `{key}` is defined twice")
                keys.add(key)
                line = f"{key} = {json.dumps(value)}"
                lines.append(f"{line:<{NOTE_COLUMN}} # {note}" if note else line)
    except (KeyError, TypeError, AttributeError):
        raise PaletteError("the palette sent by the page is incomplete") from None
    return "\n".join(lines) + "\n"


def check_palette(palette):
    """Return the palette's file text, or raise PaletteError if jenerate.py
    would reject it or a template needs a color it doesn't have."""
    text = write_palette(palette)
    with tempfile.TemporaryDirectory() as folder:
        path = Path(folder) / "palette.toml"
        path.write_text(text)
        values = jenerate_check(jenerate.load_palette, path, path=path)
    for template, _ in jenerate.TARGETS:
        jenerate_check(jenerate.render, jenerate.template_path(template, values), values)
    return text


# What ask_path returns when there's no dialog, or it was cancelled.
NO_DIALOG, CANCELLED = "no dialog", "cancelled"


def run_dialog(command):
    """Run a file dialog command: its chosen path, CANCELLED, or NO_DIALOG
    if it couldn't show (no display, say)."""
    try:
        result = subprocess.run(command, capture_output=True, text=True)
    except OSError:
        return NO_DIALOG
    if result.returncode == 0 and result.stdout.strip():
        return Path(result.stdout.strip())
    # zenity and kdialog exit 1 on Cancel; osascript exits 1 on Cancel too.
    return CANCELLED if result.returncode == 1 else NO_DIALOG


def ask_path(kind, default):
    """Show this computer's file dialog: kind "save" starts at the file
    `default` (and asks before replacing an existing file), kind "open"
    starts in the folder `default`."""
    if os.environ.get("PALETTE_CREATOR_DIALOG") == "none":
        return NO_DIALOG
    saving = kind == "save"
    title = "Save palette as" if saving else "Load a palette"
    folder = default.parent if saving else default
    if platform.system() == "Darwin" and shutil.which("osascript"):
        where = f"default location (POSIX file {json.dumps(str(folder))})"
        if saving:
            script = (f'POSIX path of (choose file name with prompt "{title}" '
                      f'{where} default name {json.dumps(default.name)})')
        else:
            script = f'POSIX path of (choose file with prompt "{title}" {where})'
        return run_dialog(["osascript", "-e", script])
    if shutil.which("zenity"):
        command = ["zenity", "--file-selection", f"--title={title}",
                   "--file-filter=Palettes (*.toml) | *.toml"]
        # A trailing slash makes zenity open in the folder.
        command += (["--save", "--confirm-overwrite", f"--filename={default}"]
                    if saving else [f"--filename={folder}/"])
        chosen = run_dialog(command)
        if chosen != NO_DIALOG:
            return chosen
    if shutil.which("kdialog"):
        option = "--getsavefilename" if saving else "--getopenfilename"
        chosen = run_dialog(["kdialog", "--title", title, option,
                             str(default), "Palettes (*.toml)"])
        if chosen != NO_DIALOG:
            return chosen
    try:
        import tkinter
        from tkinter import filedialog
        root = tkinter.Tk()
        root.withdraw()
        root.attributes("-topmost", True)
        options = dict(parent=root, title=title, initialdir=folder,
                       filetypes=[("Palettes", "*.toml")])
        if saving:
            name = filedialog.asksaveasfilename(
                initialfile=default.name, defaultextension=".toml", **options)
        else:
            name = filedialog.askopenfilename(**options)
        root.destroy()
    except Exception:  # no tkinter, or no display for it
        return NO_DIALOG
    return Path(name) if name else CANCELLED


def typed_path(filename):
    """A file name typed into the page, which can only name a file in
    palettes/."""
    if not isinstance(filename, str) or not filename or Path(filename).name != filename:
        raise PaletteError("type just a file name, of a file in palettes/")
    return jenerate.PALETTES / filename


def check_save_path(path, slug):
    """Refuse a place jenerate.py couldn't use the palette from."""
    if path.suffix != ".toml":
        raise PaletteError(f"{path.name}: palette files need to end in .toml")
    if path.resolve().parent == jenerate.PALETTES and path.name != f"{slug}-palette.toml":
        # jenerate.py (and setup.sh's list) would stop at a misnamed palette.
        raise PaletteError(f"in palettes/, this palette has to be named "
                           f"{slug}-palette.toml, so jenerate.py can find it "
                           f"by its slug. Choose that name, or save it "
                           f"somewhere else.")


def save_palette(palette, target, filename=None, overwrite=False):
    """Save to the work-in-progress file, or as a palette file, and describe
    it. A palette file's place comes from the save dialog; without one, from
    `filename` (a name in palettes/) once the page has asked for it."""
    text = check_palette(palette)
    if target == "wip":
        WIP.write_text(text)
        return {"message": f"Saved {WIP.relative_to(jenerate.ROOT)}"}
    if target != "palette":
        raise PaletteError(f"can't save to {target!r}")

    slug = palette["slug"]
    default = jenerate.PALETTES / f"{slug}-palette.toml"
    if filename is None:
        path = ask_path("save", default)
        if path == CANCELLED:
            return {"cancelled": True, "message": "Not saved."}
        if path == NO_DIALOG:
            return {"choose_name": True, "default": default.name}
    else:
        path = typed_path(filename)
        if path.exists() and not overwrite and path.read_text() != text:
            return {"exists": True,
                    "message": f"{path.relative_to(jenerate.ROOT)} already exists"}

    check_save_path(path, slug)
    path.write_text(text)
    if path.resolve().parent == jenerate.PALETTES:
        shown, generate = path.relative_to(jenerate.ROOT), slug
    else:
        shown = generate = path
    return {"message": f"Saved {shown}. Generate its themes with: "
                       f"./jenerate.py {generate}"}


def load_palette(filename=None):
    """Replace the work-in-progress palette with a palette file, copied as
    written, and describe it. The file comes from the open dialog; without
    one, from `filename` (a name in palettes/) once the page has asked for it.
    A palette jenerate.py would reject leaves the work in progress alone."""
    if filename is None:
        path = ask_path("open", jenerate.PALETTES)
        if path == CANCELLED:
            return {"cancelled": True, "message": "Nothing loaded."}
        if path == NO_DIALOG:
            return {"choose_name": True,
                    "palettes": [p.name for p in sorted(jenerate.PALETTES.glob("*.toml"))]}
    else:
        path = typed_path(filename)
    if path.suffix != ".toml" or not path.is_file():
        raise PaletteError(f"{path.name}: not a palette file (.toml)")
    check_palette(read_palette(path))

    WIP.write_text(path.read_text())
    shown = (path.relative_to(jenerate.ROOT)
             if path.resolve().is_relative_to(jenerate.ROOT) else path)
    return {"palette": read_palette(WIP),
            "message": f"Loaded {shown} into the work-in-progress palette."}


class Handler(BaseHTTPRequestHandler):
    def send(self, status, body, content_type="application/json"):
        if content_type == "application/json":
            body = json.dumps(body)
        data = body.encode() if isinstance(body, str) else body
        self.send_response(status)
        self.send_header("Content-Type", f"{content_type}; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def from_this_page(self):
        """Refuse requests another website makes through the browser: the
        Host must be this server (against DNS rebinding), and any Origin must
        be this page."""
        port = self.server.server_address[1]
        hosts = {f"127.0.0.1:{port}", f"localhost:{port}"}
        origin = self.headers.get("Origin")
        if (self.headers.get("Host") not in hosts
                or (origin is not None and origin.removeprefix("http://") not in hosts)):
            self.send(HTTPStatus.FORBIDDEN, {"error": "not from this page"})
            return False
        return True

    def do_GET(self):
        if not self.from_this_page():
            return
        url = urlparse(self.path)
        if url.path == "/":
            self.send(HTTPStatus.OK, PAGE.read_bytes(), "text/html")
        elif url.path == "/api/palette":
            self.get_palette()
        else:
            self.send(HTTPStatus.NOT_FOUND, {"error": "not found"})

    def get_palette(self):
        """Send the work-in-progress palette."""
        source = WIP.relative_to(jenerate.ROOT)
        try:
            palette = read_palette(WIP)
        except PaletteError as error:
            self.send(HTTPStatus.UNPROCESSABLE_ENTITY,
                      {"error": str(error), "source": str(source)})
            return
        self.send(HTTPStatus.OK, {"palette": palette, "source": str(source)})

    def do_POST(self):
        if not self.from_this_page():
            return
        # A JSON body can't be sent by another site without the browser
        # asking this server first, which it never agrees to.
        if self.headers.get("Content-Type", "").split(";")[0] != "application/json":
            self.send(HTTPStatus.UNSUPPORTED_MEDIA_TYPE, {"error": "send JSON"})
            return
        length = int(self.headers.get("Content-Length") or 0)
        if length > MAX_BODY:
            self.send(HTTPStatus.REQUEST_ENTITY_TOO_LARGE, {"error": "too large"})
            return
        try:
            body = json.loads(self.rfile.read(length))
            if not isinstance(body, dict):
                raise TypeError
            palette = body.get("palette")
            if self.path in ("/api/check", "/api/save") and palette is None:
                raise KeyError
        except (json.JSONDecodeError, KeyError, TypeError):
            self.send(HTTPStatus.BAD_REQUEST, {"error": "send {\"palette\": ...}"})
            return

        try:
            if self.path == "/api/check":
                check_palette(palette)
                result = {"ok": True}
            elif self.path == "/api/save":
                result = save_palette(palette, body.get("target", "wip"),
                                      body.get("filename"),
                                      body.get("overwrite") is True)
                result["ok"] = not any(result.get(k) for k in
                                       ("exists", "cancelled", "choose_name"))
            elif self.path == "/api/load":
                result = load_palette(body.get("filename"))
                result["ok"] = not any(result.get(k) for k in
                                       ("cancelled", "choose_name"))
            else:
                self.send(HTTPStatus.NOT_FOUND, {"error": "not found"})
                return
        except PaletteError as error:
            result = {"ok": False, "error": str(error)}
        self.send(HTTPStatus.OK, result)

    def log_message(self, format, *args):
        pass


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--no-browser", action="store_true",
                        help="don't open the page, just print its address")
    args = parser.parse_args()

    if not WIP.exists():
        WIP.write_text(STARTER.read_text())
        print(f"Created {WIP.relative_to(jenerate.ROOT)} from Blue Purple")
    try:
        server = HTTPServer(("127.0.0.1", args.port), Handler)
    except OSError as error:
        sys.exit(f"Can't use port {args.port} ({error.strerror}); "
                 f"try another with --port")

    url = f"http://127.0.0.1:{server.server_address[1]}/"
    print(f"Palette Creator is running at {url}")
    print("Press Ctrl+C to stop.", flush=True)
    if not args.no_browser:
        webbrowser.open(url)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print()


if __name__ == "__main__":
    main()
