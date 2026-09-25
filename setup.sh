#!/usr/bin/env bash
# Walks you through installing a Jenerated theme: pick an app, pick a palette,
# and this script generates the theme and installs it for you. It can also
# start the Palette Creator, for designing a new palette.
#
# Usage: ./setup.sh
#
# Works on Linux and macOS (including macOS's built-in bash 3.2).

set -eu

# Where setup.sh was run from, for paths the user types.
START_DIR="$(pwd)"
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

OS="$(uname -s)"

# --- Helpers -----------------------------------------------------------------

say() { printf '%s\n' "$*"; }
step() { printf '\n==> %s\n' "$*"; }
die() { printf '\nError: %s\n' "$*" >&2; exit 1; }

# ask_yes "Question?" -> returns 0 for yes (the default), 1 for no.
ask_yes() {
  local reply
  printf '%s [Y/n] ' "$1"
  read -r reply || reply=n
  case "$reply" in
    [nN]*) return 1 ;;
    *) return 0 ;;
  esac
}

# choose "Prompt" option... -> sets CHOICE to the chosen option's index (0-based).
choose() {
  local prompt="$1" i reply
  shift
  say ""
  say "$prompt"
  i=1
  for option in "$@"; do
    printf '  %d) %s\n' "$i" "$option"
    i=$((i + 1))
  done
  while :; do
    printf 'Enter a number (1-%d): ' "$#"
    read -r reply || die "no choice made"
    case "$reply" in
      '' | *[!0-9]*) ;;
      *)
        if [ "$reply" -ge 1 ] && [ "$reply" -le "$#" ]; then
          CHOICE=$((reply - 1))
          return
        fi
        ;;
    esac
    say "Please enter a number between 1 and $#."
  done
}

# toml_value file key -> prints the top-level string value of `key = "..."`
# or `key = '...'`. Only used without Python; jenerate.py reads palettes
# properly otherwise.
toml_value() {
  sed -n -e "s/^$2[[:space:]]*=[[:space:]]*\"\([^\"]*\)\".*/\1/p" \
    -e "s/^$2[[:space:]]*=[[:space:]]*'\([^']*\)'.*/\1/p" "$1" | head -n 1
}

# Finds a Python new enough (3.11+) to run jenerate.py, or prints nothing.
find_python() {
  for py in python3 python3.13 python3.12 python3.11; do
    if command -v "$py" >/dev/null 2>&1 &&
      "$py" -c 'import tomllib' >/dev/null 2>&1; then
      printf '%s' "$py"
      return
    fi
  done
}

# zip_folder folder zip -> writes a .zip of everything in the folder (paths
# inside it relative to the folder), with python3 or zip. Returns 1 if
# neither works. With python3 the .zip is reproducible: the same files always
# make the same bytes (every entry gets a fixed date), so the committed
# example packages only change when their contents do.
zip_folder() {
  rm -f "$2"
  if command -v python3 >/dev/null 2>&1 && python3 -c '
import os, sys, zipfile
folder, target = sys.argv[1:]
with zipfile.ZipFile(target, "w") as z:
    for dirpath, dirs, files in os.walk(folder):
        dirs.sort()
        for name in sorted(files):
            path = os.path.join(dirpath, name)
            entry = zipfile.ZipInfo(os.path.relpath(path, folder), (1980, 1, 1, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            entry.external_attr = 0o644 << 16
            with open(path, "rb") as f:
                z.writestr(entry, f.read())
' "$1" "$2" 2>/dev/null; then
    return 0
  fi
  command -v zip >/dev/null 2>&1 && (cd "$1" && zip -q -r "$2" .) 2>/dev/null
}

# --- Prepare for a commit (for maintainers) --------------------------------
# ./setup.sh --prep-commit puts the generated files git tracks back to the
# committed defaults, so local palettes don't end up in a commit:
# Blue Purple's files are regenerated (restored if removed, updated if a
# template changed), and package.json is rebuilt listing only Blue Purple
# (keeping any change to package.json.tmpl). The example packages made from
# Blue Purple (EXAMPLE_PACKAGES) are rebuilt from its regenerated files.
# Other generated themes stay on disk; they're ignored by git. Deliberately
# left out of the usage and README.

PYTHON="$(find_python)"

# Committed, ready-to-install packages of Blue Purple: "folder package" pairs.
EXAMPLE_PACKAGES=(
  "app-themes/vivaldi-theme/blue-purple app-themes/vivaldi-theme/jenerated-blue-purple.zip"
  "app-themes/jetbrains-theme/blue-purple app-themes/jetbrains-theme/jenerated-blue-purple.jar"
)

prep_commit() {
  [ -n "$PYTHON" ] || die "--prep-commit needs Python 3.11 or later"
  local others
  others="$("$PYTHON" jenerate.py --list |
    sed -n 's/^\* \([a-z0-9-][a-z0-9-]*\) .*/\1/p' | grep -vx 'blue-purple' |
    paste -sd, - || true)"

  step "Preparing the repository for a commit"
  "$PYTHON" -c '
import jenerate
jenerate.add(["blue-purple"])
jenerate.write_vscode_package(["blue-purple"])
'
  local pair folder package
  for pair in "${EXAMPLE_PACKAGES[@]}"; do
    folder="${pair% *}"
    package="${pair#* }"
    zip_folder "$ROOT/$folder" "$ROOT/$package" || die "couldn't rebuild $package"
    say "Rebuilt $package"
  done
  say "The generated files git tracks now match the Blue Purple defaults."
  if [ -n "$others" ]; then
    say ""
    say "Your other themes ($others) are still generated, but VS Code won't"
    say "list them until you run, after committing:"
    say "    ./jenerate.py $others"
  fi
}

case "${1:-}" in
  "") ;;
  --prep-commit)
    prep_commit
    exit 0
    ;;
  *) die "unknown option: $1 (run ./setup.sh with no options)" ;;
esac

# --- Install a theme, or design a palette -----------------------------------

# Explains the Palette Creator, then runs its server until Ctrl+C.
start_palette_creator() {
  [ -n "$PYTHON" ] ||
    die "the Palette Creator needs Python 3.11 or later (python3 --version to check)"

  step "Starting the Palette Creator"
  say "It opens in your browser. If it doesn't, open the address printed below."
  say ""
  say "1. The page starts with your work-in-progress palette"
  say "   (palette-creator/work-in-progress-palette.toml; the first time, a copy"
  say "   of Blue Purple). To begin from another palette, use \"Start from\"."
  say "2. Give it a name and a slug (lowercase words and dashes, like deep-blue-sea)."
  say "3. Change colors with the color pickers, or type #rrggbb or another"
  say "   color's name. The preview updates as you go; hover a color to see"
  say "   where it's used, or click the preview to find a color."
  say "4. \"Save\" keeps your work in progress. \"Save as palette\" opens a save"
  say "   dialog in palettes/; keep the suggested name, <slug>-palette.toml, so"
  say "   jenerate.py and ./setup.sh can find it."
  say "5. When you're done, press Ctrl+C here to stop it, then run ./setup.sh"
  say "   again and choose \"Install a theme\": your palette will be listed."
  say ""
  exec "$PYTHON" palette-creator/serve.py
}

say "Jenerated Themes setup"
say "======================"

choose "What would you like to do?" \
  "Install a theme for an app" \
  "Design a new palette (opens the Palette Creator)"
[ "$CHOICE" -eq 1 ] && start_palette_creator

# --- Pick an app -------------------------------------------------------------

APPS=("VS Code" "Slack" "Obsidian" "Vim / Neovim" "Firefox" "Vivaldi"
  "JetBrains Apps (IntelliJ IDEA, Android Studio, PyCharm, WebStorm and more)"
  "Chromium browsers (Chrome, Brave, Edge, Opera and more)")
APP_IDS=("vscode" "slack" "obsidian" "vim" "firefox" "vivaldi" "jetbrains" "chromium")
if [ "$OS" = "Linux" ]; then
  APPS+=("Ptyxis (Ubuntu terminal)" "Tilix (terminal)"
    "GTK3 apps (GIMP, Inkscape, Thunar, GParted and more)")
  APP_IDS+=("ptyxis" "tilix" "gtk3")
fi

choose "Which app do you want to theme?" "${APPS[@]}"
APP="${APP_IDS[$CHOICE]}"

# --- Pick a palette ----------------------------------------------------------

NAMES=()
SLUGS=()
if [ -n "$PYTHON" ]; then
  # jenerate.py --list prints "* slug   Name" per palette (the * marks
  # generated ones), and stops with a message if a palette is broken.
  LIST="$("$PYTHON" jenerate.py --list)" ||
    die "fix the palette named above, then run ./setup.sh again"
  TAB="$(printf '\t')"
  while IFS="$TAB" read -r slug name; do
    SLUGS+=("$slug")
    NAMES+=("$name")
  done < <(printf '%s\n' "$LIST" |
    sed -n "s/^[* ] \([a-z0-9-][a-z0-9-]*\)  *\(.*\)$/\1$TAB\2/p")
else
  for file in palettes/*-palette.toml; do
    [ -f "$file" ] || continue
    NAMES+=("$(toml_value "$file" name)")
    SLUGS+=("$(toml_value "$file" slug)")
  done
fi
[ "${#SLUGS[@]}" -gt 0 ] || die "no palettes found in palettes/"

choose "Which theme do you want?" "${NAMES[@]}"
NAME="${NAMES[$CHOICE]}"
SLUG="${SLUGS[$CHOICE]}"

# --- Generate the theme ------------------------------------------------------

step "Generating the $NAME theme"
if [ -n "$PYTHON" ]; then
  "$PYTHON" jenerate.py "$SLUG"
elif [ "$SLUG" = "blue-purple" ]; then
  # Blue Purple is committed already generated, so it works without Python.
  say "Python 3.11+ not found; using the Blue Purple files that come with the repository."
else
  die "generating $NAME needs Python 3.11 or later (python3 --version to check).
Install it, or choose Blue Purple, which works without Python."
fi

# --- Install it --------------------------------------------------------------

# install_link target source -> links target to source, offering to replace
# anything already at target.
install_link() {
  local target="$1" source="$2"
  if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
    say "Already installed (linked to this folder)."
    return
  fi
  if [ -e "$target" ] || [ -L "$target" ]; then
    say "An older install exists at $target."
    ask_yes "Replace it with a link to this folder?" || die "left the existing install alone"
    rm -rf "$target"
  fi
  ln -s "$source" "$target"
  say "Linked $target -> $source"
}

install_vscode() {
  local extensions="$HOME/.vscode/extensions"
  local target="$extensions/jenerated-themes"
  local source="$ROOT/app-themes/vs-code-theme"

  step "Installing the VS Code extension"
  mkdir -p "$extensions"
  install_link "$target" "$source"

  # A .vsix install of the same extension would clash with the link.
  for other in "$extensions"/local.jenerated-themes-*; do
    [ -e "$other" ] || continue
    say ""
    say "Note: you also have a packaged copy installed ($(basename "$other"))."
    say "Uninstall \"Jenerated Themes\" from VS Code's Extensions view so the two don't clash."
  done

  # If the extension was ever uninstalled, VS Code lists it in .obsolete and
  # ignores it, even after it's reinstalled. VS Code rewrites that file while
  # it runs, so it has to be closed while we remove the entry.
  local obsolete="$extensions/.obsolete"
  if [ -f "$obsolete" ] && grep -q 'local\.jenerated-themes' "$obsolete"; then
    say ""
    say "VS Code has this extension marked as uninstalled, which hides the theme."
    say "Quit VS Code completely (all windows), then press Enter to fix it."
    read -r _ || die "stopped before changing VS Code's files; run ./setup.sh again"
    sed -e 's/"local\.jenerated-themes[^"]*":[a-z]*//g' \
      -e 's/,,*/,/g' -e 's/{,/{/' -e 's/,}/}/' "$obsolete" >"$obsolete.tmp"
    if grep -q '^{}$' "$obsolete.tmp"; then
      rm -f "$obsolete" "$obsolete.tmp"
    else
      mv "$obsolete.tmp" "$obsolete"
    fi
    say "Fixed."
  fi

  step "Done! To turn the theme on:"
  say "1. Open (or reload) VS Code: Command Palette -> \"Developer: Reload Window\"."
  say "2. Open the theme picker (Ctrl+K Ctrl+T, or Cmd+K Cmd+T on a Mac)."
  say "3. Choose \"Jenerated $NAME\"."
}

install_ptyxis() {
  local palettes="$HOME/.local/share/org.gnome.Ptyxis/palettes"

  step "Installing the Ptyxis palette"
  mkdir -p "$palettes"
  ln -sf "$ROOT/app-themes/ptyxis-theme/$SLUG.palette" "$palettes/$SLUG.palette"
  say "Linked $palettes/$SLUG.palette"

  step "Done! To turn the palette on:"
  say "1. Close and reopen Ptyxis."
  say "2. Open Preferences (Ctrl+,), and under Appearance choose \"$NAME\"."
  say "   It applies to the current profile; repeat for other profiles."
}

# Prints the vaults Obsidian knows about, one per line, from its vault list
# (obsidian.json), wherever this system's Obsidian keeps it.
known_obsidian_vaults() {
  local config
  for config in \
    "$HOME/.config/obsidian/obsidian.json" \
    "$HOME/.var/app/md.obsidian.Obsidian/config/obsidian/obsidian.json" \
    "$HOME/snap/obsidian/current/.config/obsidian/obsidian.json" \
    "$HOME/Library/Application Support/obsidian/obsidian.json"; do
    [ -f "$config" ] || continue
    grep -o '"path":"[^"]*"' "$config" | sed -e 's/^"path":"//' -e 's/"$//'
  done | sort -u | while IFS= read -r vault; do
    [ -d "$vault" ] && printf '%s\n' "$vault"
  done
}

# Asks which vault to theme and sets VAULT.
choose_obsidian_vault() {
  local vaults=() vault
  while IFS= read -r vault; do
    vaults+=("$vault")
  done < <(known_obsidian_vaults)

  VAULT=""
  if [ "${#vaults[@]}" -gt 0 ]; then
    choose "Which Obsidian vault? (themes are set per vault)" \
      "${vaults[@]}" "Another folder (type its path)"
    [ "$CHOICE" -lt "${#vaults[@]}" ] && VAULT="${vaults[$CHOICE]}"
  fi
  if [ -z "$VAULT" ]; then
    say ""
    printf 'Path to your vault folder: '
    read -r VAULT || die "no vault given"
    [ -n "$VAULT" ] || die "no vault given"
    case "$VAULT" in
      "~" | "~/"*) VAULT="$HOME${VAULT#\~}" ;;
      /*) ;;
      # A relative path is relative to where setup.sh was run, not the repo.
      *) VAULT="$START_DIR/$VAULT" ;;
    esac
    VAULT="${VAULT%/}"
  fi

  [ -d "$VAULT" ] || die "there's no folder at $VAULT"
  if [ ! -d "$VAULT/.obsidian" ]; then
    say "$VAULT has no .obsidian folder, so it may not be an Obsidian vault."
    ask_yes "Use it anyway?" || die "no vault chosen"
  fi
}

install_obsidian() {
  choose_obsidian_vault
  local themes="$VAULT/.obsidian/themes"

  step "Installing the Obsidian theme"
  mkdir -p "$themes"
  # Obsidian names a theme after its folder, which must match the name in
  # its manifest.json.
  install_link "$themes/Jenerated $NAME" "$ROOT/app-themes/obsidian-theme/$SLUG"

  step "Done! To turn the theme on:"
  say "1. In Obsidian, open Settings -> Appearance."
  say "2. Under Themes, choose \"Jenerated $NAME\". If it isn't listed, click"
  say "   the reload button next to Themes, or restart Obsidian."
  say "Themes are per vault; run ./setup.sh again for your other vaults."
}

install_vim() {
  local vim_pack="$HOME/.vim/pack/jenerated/start/jenerated-themes"
  local nvim_pack="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/pack/jenerated/start/jenerated-themes"
  local has_vim="" has_nvim=""
  { command -v vim >/dev/null 2>&1 || [ -d "$HOME/.vim" ]; } && has_vim=1
  { command -v nvim >/dev/null 2>&1 || [ -d "$HOME/.config/nvim" ]; } && has_nvim=1
  # With neither found, set it up for Vim.
  [ -z "$has_nvim" ] && has_vim=1

  # app-themes/vim-theme is a Vim package: linked once, every generated palette's
  # colorscheme (in its colors/ folder) is available.
  if [ -n "$has_vim" ]; then
    step "Installing the colorschemes for Vim"
    mkdir -p "$(dirname "$vim_pack")"
    install_link "$vim_pack" "$ROOT/app-themes/vim-theme"
  fi
  if [ -n "$has_nvim" ]; then
    step "Installing the colorschemes for Neovim"
    mkdir -p "$(dirname "$nvim_pack")"
    install_link "$nvim_pack" "$ROOT/app-themes/vim-theme"
  fi

  step "Done! To turn the colorscheme on:"
  say "Try it now with :colorscheme jenerated-$SLUG"
  say ""
  if [ -n "$has_vim" ]; then
    say "To keep it, add these lines to ~/.vimrc:"
    say "    set termguicolors"
    say "    colorscheme jenerated-$SLUG"
  fi
  if [ -n "$has_nvim" ]; then
    say "To keep it in Neovim, add these lines to ~/.config/nvim/init.lua:"
    say "    vim.opt.termguicolors = true"
    say "    vim.cmd.colorscheme(\"jenerated-$SLUG\")"
  fi
  say ""
  say "termguicolors gives the palette's exact colors. If your terminal doesn't"
  say "support true color, leave it out: the colorscheme then uses the terminal's"
  say "16 colors, which the Ptyxis and Tilix themes set to the same palette."
}

# open_firefox url -> opens the URL in Firefox without waiting for it, or
# returns 1 if Firefox can't be found.
open_firefox() {
  if [ "$OS" = "Darwin" ]; then
    open -a Firefox "$1" >/dev/null 2>&1
  elif command -v firefox >/dev/null 2>&1; then
    (firefox "$1" >/dev/null 2>&1 &)
  else
    return 1
  fi
}

# package_firefox_theme folder xpi -> zips the theme's manifest.json into an
# .xpi for Mozilla to sign, with a version made from the date and time, since
# each upload needs a new version. Returns 1 without a working python3.
package_firefox_theme() {
  command -v python3 >/dev/null 2>&1 || return 1
  python3 -c '
import json, sys, time, zipfile
folder, xpi = sys.argv[1:]
manifest = json.load(open(folder + "/manifest.json"))
now = time.localtime()
manifest["version"] = (f"{now.tm_year}.{now.tm_mon * 100 + now.tm_mday}."
                       f"{now.tm_hour * 100 + now.tm_min}")
with zipfile.ZipFile(xpi, "w", zipfile.ZIP_DEFLATED) as z:
    z.writestr("manifest.json", json.dumps(manifest, indent=2) + "\n")
' "$1" "$2" 2>/dev/null
}

install_firefox() {
  local folder="$ROOT/app-themes/firefox-theme/$SLUG"
  local xpi="$ROOT/app-themes/firefox-theme/jenerated-$SLUG.xpi"

  step "Packaging the Firefox theme"
  if package_firefox_theme "$folder" "$xpi"; then
    say "Made $xpi, for keeping the theme (see below)."
  else
    xpi=""
    say "Couldn't package it (that needs python3), but you can still try it."
  fi

  say ""
  if ask_yes "Open Firefox's add-on debugging page, to try the theme now?"; then
    open_firefox "about:debugging#/runtime/this-firefox" ||
      say "Couldn't find Firefox; open about:debugging#/runtime/this-firefox in it."
  fi

  step "Done! To try the theme (until Firefox restarts):"
  say "1. In Firefox, on about:debugging (\"This Firefox\"), click"
  say "   \"Load Temporary Add-on…\"."
  say "2. Choose $folder/manifest.json"
  if [ -n "$xpi" ]; then
    say ""
    say "To keep it: Firefox only keeps add-ons signed by Mozilla, and signing"
    say "your own theme is free."
    say "1. Go to https://addons.mozilla.org/developers/addon/submit/distribution"
    say "   and sign in with a Mozilla account."
    say "2. Choose \"On your own\", and upload $xpi"
    say "3. Download the signed file it gives you, and open it in Firefox"
    say "   (File -> Open File, or drag it onto a Firefox window)."
    say "Run ./setup.sh again after changing the palette, for a new version."
  fi
}

install_vivaldi() {
  local folder="$ROOT/app-themes/vivaldi-theme/$SLUG"
  local theme_zip="$ROOT/app-themes/vivaldi-theme/jenerated-$SLUG.zip"

  step "Packaging the Vivaldi theme"
  # Vivaldi imports a theme as a .zip holding its settings.json.
  zip_folder "$folder" "$theme_zip" ||
    die "couldn't make the .zip (that needs python3 or zip); zip $folder/settings.json by hand"
  say "Made $theme_zip"

  step "Done! To turn the theme on:"
  say "1. In Vivaldi, open Settings -> Themes, and click \"Import Theme...\" at the"
  say "   bottom."
  say "2. Choose $theme_zip"
  say "3. Vivaldi previews the theme and asks whether to install it. Accept"
  say "   within 30 seconds, or the preview expires and nothing is installed."
  say "After changing the palette, run ./setup.sh again and import the new .zip:"
  say "Vivaldi offers it as an update to the theme you installed."
}

install_jetbrains() {
  local folder="$ROOT/app-themes/jetbrains-theme/$SLUG"
  local jar="$ROOT/app-themes/jetbrains-theme/jenerated-$SLUG.jar"

  step "Packaging the JetBrains theme"
  # The theme is a small plugin: its folder, zipped as a .jar.
  zip_folder "$folder" "$jar" ||
    die "couldn't make the .jar (that needs python3 or zip); zip the contents of $folder by hand"
  say "Made $jar"

  step "Done! To turn the theme on:"
  say "It works in the JetBrains apps built on the IntelliJ Platform (2023.1 or"
  say "later): IntelliJ IDEA, Android Studio, PyCharm, WebStorm, PhpStorm, GoLand,"
  say "RubyMine, CLion, Rider, DataGrip, DataSpell and RustRover. (Not Fleet,"
  say "which has its own theme format.) In the app:"
  say "1. Open Settings -> Plugins, click the gear icon, and choose"
  say "   \"Install Plugin from Disk...\"."
  say "2. Choose $jar"
  say "   and restart the app if it asks."
  say "3. Open Settings -> Appearance & Behavior -> Appearance, and choose"
  say "   \"Jenerated $NAME\" as the theme. Its editor colors come with it."
  say "After changing the palette, run ./setup.sh again and install the new .jar."
}

# The GNOME setting for the GTK3 theme, or nothing without gsettings.
gtk_theme_setting() {
  command -v gsettings >/dev/null 2>&1 &&
    gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null
}

install_gtk3() {
  local themes="${XDG_DATA_HOME:-$HOME/.local/share}/themes"
  local theme="Jenerated-$SLUG"
  local current

  step "Installing the GTK3 theme"
  mkdir -p "$themes"
  install_link "$themes/$theme" "$ROOT/app-themes/gtk3-theme/$SLUG"

  current="$(gtk_theme_setting || true)"
  if [ -n "$current" ]; then
    say ""
    say "Your GTK3 theme is $current."
    if ask_yes "Switch every GTK3 app to $theme now?"; then
      gsettings set org.gnome.desktop.interface gtk-theme "$theme"
      step "Done! GTK3 apps use $theme now (reopen any that were open)."
      say "To switch back:"
      say "    gsettings set org.gnome.desktop.interface gtk-theme $current"
      return
    fi
  fi

  step "Done! To turn the theme on:"
  say "- For every GTK3 app on GNOME: in GNOME Tweaks, under Appearance, choose"
  say "  \"$theme\" for Legacy Applications, or run"
  say "      gsettings set org.gnome.desktop.interface gtk-theme $theme"
  say "- On Xfce: Settings -> Appearance -> Style -> \"$theme\"."
  say "- To try it in one app: GTK_THEME=$theme gimp (or any GTK3 app)."
}

install_chromium() {
  local folder="$ROOT/app-themes/chromium-theme/$SLUG"

  # Browsers cache a theme in its folder when they load it; clear any old
  # cache so the new colors are used.
  rm -f "$folder/Cached Theme.pak"

  step "Done! The theme is ready in $folder"
  say "To turn it on, in Chrome, Brave, Edge, Opera, Chromium or another"
  say "Chromium-based browser:"
  say "1. Open the browser's extensions page:"
  say "     chrome://extensions  (Chrome, Chromium)"
  say "     brave://extensions   (Brave)"
  say "     edge://extensions    (Edge)"
  say "     opera://extensions   (Opera)"
  say "2. Turn on Developer mode."
  say "3. Click \"Load unpacked\" and choose the folder above. The theme applies"
  say "   right away."
  say "The browser keeps loading the theme from that folder, so leave it there."
  say "After changing the palette, run ./setup.sh again and load it again."
  say "To go back to the browser's own look: Settings -> Appearance -> Theme ->"
  say "Reset to default."
}

install_tilix() {
  local schemes="$HOME/.config/tilix/schemes"

  step "Installing the Tilix color scheme"
  mkdir -p "$schemes"
  # The jenerated- prefix keeps it from replacing a scheme of your own.
  install_link "$schemes/jenerated-$SLUG.json" "$ROOT/app-themes/tilix-theme/$SLUG.json"

  step "Done! To turn the color scheme on:"
  say "1. Close every Tilix window, then open Tilix again."
  say "2. Open Preferences, choose your profile under Profiles, and on the"
  say "   Color tab choose \"Jenerated $NAME\" as the color scheme."
  say "   Repeat for other profiles."
}

copy_to_clipboard() {
  if [ "$OS" = "Darwin" ] && command -v pbcopy >/dev/null 2>&1; then
    pbcopy
  elif [ -n "${WAYLAND_DISPLAY:-}" ] && command -v wl-copy >/dev/null 2>&1; then
    wl-copy
  elif command -v xclip >/dev/null 2>&1; then
    xclip -selection clipboard
  elif command -v xsel >/dev/null 2>&1; then
    xsel --clipboard --input
  else
    return 1
  fi
}

install_slack() {
  local theme
  theme="$(tr -d '\n' <"app-themes/slack-theme/$SLUG.txt")"

  step "Your Slack theme string"
  say ""
  say "    $theme"
  say ""
  if printf '%s' "$theme" | copy_to_clipboard 2>/dev/null; then
    say "(Copied to your clipboard.)"
  fi

  step "Done! To turn the theme on (Slack can't be themed from outside the app):"
  say "1. Paste the string above into any message box in Slack, such as a DM"
  say "   to yourself, and send it."
  say "2. Click the \"Switch sidebar theme\" button that appears under it."
  say "Slack themes are per workspace, so repeat this in each workspace."
}

case "$APP" in
  vscode) install_vscode ;;
  ptyxis) install_ptyxis ;;
  slack) install_slack ;;
  obsidian) install_obsidian ;;
  vim) install_vim ;;
  firefox) install_firefox ;;
  vivaldi) install_vivaldi ;;
  jetbrains) install_jetbrains ;;
  chromium) install_chromium ;;
  tilix) install_tilix ;;
  gtk3) install_gtk3 ;;
esac

say ""
say "Run ./setup.sh again any time to theme another app or switch palettes."
