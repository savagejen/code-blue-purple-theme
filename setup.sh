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
# Other generated themes stay on disk; they're ignored by git. Left out of
# the usage and README, which are for people installing themes; documented in
# CONTRIBUTING.md.

PYTHON="$(find_python)"

# Committed, ready-to-install packages of Blue Purple: "folder package" pairs.
EXAMPLE_PACKAGES=(
  "app-themes/vivaldi-theme/blue-purple app-themes/vivaldi-theme/jenerated-blue-purple.zip"
  "app-themes/jetbrains-theme/blue-purple app-themes/jetbrains-theme/jenerated-blue-purple.jar"
  "app-themes/libreoffice-theme/blue-purple app-themes/libreoffice-theme/jenerated-blue-purple.oxt"
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

# --- Update the palette screenshots (for maintainers) ------------------------
# ./setup.sh --update-screenshots retakes palettes/Screenshots/<slug>.png for
# every palette, or --update-screenshots=candy,sunset for just those (from
# the Palette Creator's preview, with Playwright), and updates
# palettes/README.md: new palettes get a section, and existing ones get their
# key colors refreshed. See palette-creator/screenshots.py. Needs
# Python 3.11 or later, Node.js and npm. Left out of the usage and README,
# which are for people installing themes; documented in CONTRIBUTING.md.

update_screenshots() {
  [ -n "$PYTHON" ] || die "--update-screenshots needs Python 3.11 or later"
  command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1 ||
    die "--update-screenshots needs Node.js and npm (for Playwright)"
  step "Updating the palette screenshots"
  "$PYTHON" palette-creator/screenshots.py "$@"
}

case "${1:-}" in
  "") ;;
  --prep-commit)
    prep_commit
    exit 0
    ;;
  --update-screenshots | --update-screenshot)
    update_screenshots
    exit 0
    ;;
  --update-screenshots=* | --update-screenshot=*)
    [ -n "${1#*=}" ] || die "name the palettes to screenshot, like --update-screenshots=candy"
    update_screenshots "${1#*=}"
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
  say "   of Blue Purple). To begin from another palette, use \"Load from...\"."
  say "2. Give it a name and a slug (lowercase words and dashes, like deep-blue-sea)."
  say "3. Change colors with the color pickers, or type #rrggbb or another"
  say "   color's name. The preview updates as you go; hover a color to see"
  say "   where it's used, or click the preview to find a color."
  say "4. Your draft saves itself as you go. \"Save as palette...\" opens a save"
  say "   dialog in palettes/; keep the suggested name, <slug>-palette.toml, so"
  say "   jenerate.py and ./setup.sh can find it."
  say "5. When you're done, press Ctrl+C here to stop it, then run ./setup.sh"
  say "   again and choose \"Install a theme\": your palette will be listed."
  say ""
  exec "$PYTHON" palette-creator/serve.py
}

# --- Menus with a way back ---------------------------------------------------

# choose_or_back prompt allow_search option... -> like choose, with "0) Back"
# under the options. Sets CHOICE to the chosen option's index, or to "back".
# If allow_search is "search", typing something other than a number sets
# CHOICE to "search" and SEARCH to what was typed.
choose_or_back() {
  local prompt="$1" allow_search="$2" i reply
  shift 2
  say ""
  say "$prompt"
  i=1
  for option in "$@"; do
    printf '  %d) %s\n' "$i" "$option"
    i=$((i + 1))
  done
  say "  0) Back"
  while :; do
    if [ "$allow_search" = search ]; then
      printf 'Enter a number (0-%d), or type part of an app'"'"'s name to search: ' "$#"
    else
      printf 'Enter a number (0-%d): ' "$#"
    fi
    read -r reply || die "no choice made"
    case "$reply" in
      0)
        CHOICE=back
        return
        ;;
      '' | *[!0-9]*)
        if [ "$allow_search" = search ] && [ -n "$reply" ]; then
          CHOICE=search
          SEARCH="$reply"
          return
        fi
        ;;
      *)
        if [ "$reply" -ge 1 ] && [ "$reply" -le "$#" ]; then
          CHOICE=$((reply - 1))
          return
        fi
        ;;
    esac
    say "Please enter a number between 0 and $#."
  done
}

# --- The apps ----------------------------------------------------------------

# add_app id label category [covers] [words] -> adds an app to the menus. The
# category is one of CATEGORY_IDS, or "" for an app that stays on the main app
# menu. Search matches the label, and also:
#   covers  the apps the theme covers, as its README lists them, since the
#           label only has room for a few (search results show this list);
#   words   other words people might search for (not shown).
APP_IDS=()
APP_LABELS=()
APP_CATEGORIES=()
APP_COVERS=()
APP_WORDS=()
add_app() {
  APP_IDS+=("$1")
  APP_LABELS+=("$2")
  APP_CATEGORIES+=("$3")
  APP_COVERS+=("${4:-}")
  APP_WORDS+=("${5:-}")
}

CATEGORY_IDS=("browsers" "communication" "editors" "terminal" "desktop" "entertainment")
CATEGORY_NAMES=("Web browsers" "Communication" "Editors: code, text and notes"
  "Terminals and command-line tools" "Linux desktops" "Entertainment")

# Each category lists its apps in the order they're added: alphabetical.
add_app chromium "Chromium browsers (Chrome, Brave, Edge, Opera and more)" browsers \
    "Google Chrome, Chromium, Brave, Microsoft Edge, Opera"
add_app firefox "Firefox" browsers \
    "" \
    "mozilla"
add_app vivaldi "Vivaldi" browsers
add_app zen "Zen Browser" browsers
add_app element "Element (Matrix chat)" communication "" "matrix riot chat messaging"
add_app mattermost "Mattermost" communication "" "chat messaging"
add_app slack "Slack" communication "" "chat messaging"
add_app emacs "Emacs" editors "" "gnu doom spacemacs"
if [ "$OS" = "Linux" ]; then
  add_app gtksourceview "GNOME text editors: gedit, GNOME Text Editor and Xed (and Pluma, Meld and more)" editors \
    "gedit, GNOME Text Editor, Xed, Pluma, Meld" \
    "gtksourceview"
fi
add_app godot "Godot" editors \
    "" \
    "game engine gdscript"
add_app jetbrains "JetBrains Apps (IntelliJ IDEA, Android Studio, PyCharm, WebStorm and more)" editors \
    "IntelliJ IDEA, Android Studio, PyCharm, WebStorm, PhpStorm, GoLand, RubyMine, CLion, Rider, DataGrip, DataSpell, RustRover"
add_app libreoffice "LibreOffice (Writer, Calc, Impress and more)" editors \
    "Writer, Calc, Impress, Draw, Base, Math" \
    "office documents spreadsheets presentations word processor"
add_app obsidian "Obsidian" editors \
    "" \
    "notes markdown"
add_app qtcreator "Qt Creator" editors "" "qt qml c++"
add_app rstudio "RStudio" editors "" "r posit rmarkdown quarto"
add_app spyder "Spyder" editors "" "python scientific anaconda"
add_app sublime "Sublime Text" editors
add_app unreal "Unreal Engine" editors "" "ue5 unreal editor game engine epic"
add_app vim "Vim / Neovim" editors \
    "" \
    "nvim"
add_app vscode "VS Code" editors \
    "" \
    "visual studio code"
if [ "$OS" = "Darwin" ]; then
  add_app xcode "Xcode" editors "" "apple swift"
fi
add_app fzf "fzf (fuzzy finder)" terminal
if [ "$OS" = "Linux" ]; then
  add_app ptyxis "Ptyxis (Ubuntu terminal)" terminal \
    "" \
    "gnome"
  add_app tilix "Tilix (terminal)" terminal
fi
add_app tmux "tmux" terminal
add_app zsh "zsh (syntax highlighting and suggestions)" terminal \
    "zsh-syntax-highlighting, fast-syntax-highlighting, zsh-autosuggestions"
if [ "$OS" = "Linux" ]; then
  add_app decky "Decky Loader (Steam's Gaming Mode on SteamOS, Bazzite, CachyOS and more)" desktop \
    "" \
    "steam deck steamos bazzite cachyos css loader gaming mode"
  add_app gtk3 "GTK3 apps (GIMP, Inkscape, Thunar, GParted and more)" desktop \
    "GIMP, Inkscape, Shotwell, Thunar, Nemo, Caja, gedit, Mousepad, Geany, Meld, Pluma, Xed, GParted, Synaptic, dconf Editor, Virtual Machine Manager, Evolution, Remmina, Deluge, Rhythmbox, GNOME Terminal, and the Xfce, MATE and Cinnamon desktops' own apps"
  add_app kde "KDE Plasma (Plasma and KDE apps, Konsole, Kate)" desktop \
    "Dolphin, Kate, KWrite, Okular, Konsole, System Settings"
fi
add_app jellyfin "Jellyfin (media server)" entertainment "" "media server movies tv streaming plex emby"
add_app mpv "mpv (media player)" entertainment "" "video music"
add_app obs "OBS Studio (streaming and recording)" entertainment "" "obs streaming recording screen capture twitch youtube"
# Apps that don't fit a category.
add_app insomnia "Insomnia (API client)" "" "" "rest http graphql api kong"

# lowercase text -> prints text in lowercase (macOS's bash 3.2 has no ${x,,}).
lowercase() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# category_name id -> prints the category's name.
category_name() {
  local i
  for i in "${!CATEGORY_IDS[@]}"; do
    if [ "${CATEGORY_IDS[$i]}" = "$1" ]; then printf '%s' "${CATEGORY_NAMES[$i]}"; fi
  done
}

# pick_app -> shows the app menus, starting from APP_MENU ("" for the main
# one, a category's id, or "search"), until an app is chosen: sets APP and
# returns 0, leaving APP_MENU on the menu it was chosen from. Returns 1 for
# Back from the main menu.
APP_MENU=""
pick_app() {
  local labels=() targets=() i category count query
  while :; do
    labels=()
    targets=()
    if [ -z "$APP_MENU" ]; then
      # Categories that have apps (on this system), then the other apps, then
      # search.
      for i in "${!CATEGORY_IDS[@]}"; do
        count=0
        for category in "${APP_CATEGORIES[@]}"; do
          [ "$category" = "${CATEGORY_IDS[$i]}" ] && count=$((count + 1))
        done
        if [ "$count" -gt 0 ]; then
          labels+=("${CATEGORY_NAMES[$i]} ($count apps)")
          targets+=("menu:${CATEGORY_IDS[$i]}")
        fi
      done
      for i in "${!APP_IDS[@]}"; do
        if [ -z "${APP_CATEGORIES[$i]}" ]; then
          labels+=("${APP_LABELS[$i]}")
          targets+=("app:${APP_IDS[$i]}")
        fi
      done
      labels+=("Search for an app by name")
      targets+=("ask-search")
      choose_or_back "Which app do you want to theme?" search "${labels[@]}"
    elif [ "$APP_MENU" = search ]; then
      query="$(lowercase "$SEARCH")"
      for i in "${!APP_IDS[@]}"; do
        # Match the app's name, id, covered apps, words, or category's name.
        case "$(lowercase "${APP_LABELS[$i]} ${APP_IDS[$i]} ${APP_COVERS[$i]} ${APP_WORDS[$i]} $(category_name "${APP_CATEGORIES[$i]}")")" in
          *"$query"*)
            # Here the list of apps the theme covers helps, so show it under
            # the label, wrapped and indented to line up with it.
            if [ -n "${APP_COVERS[$i]}" ]; then
              labels+=("${APP_LABELS[$i]}
$(printf 'Covers: %s\n' "${APP_COVERS[$i]}" | fold -s -w 70 | sed 's/ *$//; s/^/     /')")
            else
              labels+=("${APP_LABELS[$i]}")
            fi
            targets+=("app:${APP_IDS[$i]}")
            ;;
        esac
      done
      if [ "${#labels[@]}" -eq 0 ]; then
        say ""
        say "No app matches \"$SEARCH\"."
        APP_MENU=""
        continue
      fi
      choose_or_back "Apps matching \"$SEARCH\":" search "${labels[@]}"
    else
      for i in "${!APP_IDS[@]}"; do
        if [ "${APP_CATEGORIES[$i]}" = "$APP_MENU" ]; then
          labels+=("${APP_LABELS[$i]}")
          targets+=("app:${APP_IDS[$i]}")
        fi
      done
      choose_or_back "$(category_name "$APP_MENU"):" search "${labels[@]}"
    fi

    case "$CHOICE" in
      back)
        # Back from a category or search goes to the main app menu; from the
        # main app menu, out of pick_app.
        [ -z "$APP_MENU" ] && return 1
        APP_MENU=""
        ;;
      search)
        APP_MENU=search
        ;;
      *)
        case "${targets[$CHOICE]}" in
          menu:*) APP_MENU="${targets[$CHOICE]#menu:}" ;;
          ask-search)
            say ""
            printf "Type part of an app's name (or press Enter to go back): "
            read -r SEARCH || die "no choice made"
            [ -n "$SEARCH" ] && APP_MENU=search
            ;;
          app:*)
            APP="${targets[$CHOICE]#app:}"
            return 0
            ;;
        esac
        ;;
    esac
  done
}

# --- The palettes ------------------------------------------------------------

NAMES=()
SLUGS=()
load_palettes() {
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
}

# --- Choose what to do -------------------------------------------------------

say "Jenerated Themes setup"
say "======================"

# Each menu's Back goes to the one before it: the theme menu back to the app
# menus, and the main app menu back to this first question.
while :; do
  choose "What would you like to do?" \
    "Install a theme for an app" \
    "Design a new palette (opens the Palette Creator)"
  [ "$CHOICE" -eq 1 ] && start_palette_creator

  APP_MENU=""
  chosen=""
  while pick_app; do
    load_palettes
    choose_or_back "Which theme do you want?" "" "${NAMES[@]}"
    if [ "$CHOICE" != back ]; then
      chosen=1
      break
    fi
  done
  [ -n "$chosen" ] && break
done
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

# LibreOffice's extension installer, or nothing if it can't be found.
libreoffice_unopkg() {
  if command -v unopkg >/dev/null 2>&1; then
    command -v unopkg
  elif [ "$OS" = "Darwin" ] && [ -x /Applications/LibreOffice.app/Contents/MacOS/unopkg ]; then
    printf '%s\n' /Applications/LibreOffice.app/Contents/MacOS/unopkg
  fi
  return 0
}

install_libreoffice() {
  local folder="$ROOT/app-themes/libreoffice-theme/$SLUG"
  local oxt="$ROOT/app-themes/libreoffice-theme/jenerated-$SLUG.oxt"
  local unopkg installed=""

  step "Packaging the LibreOffice theme"
  # The theme is a small extension: its folder, zipped as an .oxt.
  zip_folder "$folder" "$oxt" ||
    die "couldn't make the .oxt (that needs python3 or zip); zip the contents of $folder by hand"
  say "Made $oxt"

  unopkg="$(libreoffice_unopkg)"
  if [ -n "$unopkg" ] && ! pgrep -x soffice.bin >/dev/null 2>&1 && ! pgrep -x soffice >/dev/null 2>&1; then
    step "Installing it as a LibreOffice extension"
    # --force replaces an earlier version of the same palette's theme.
    if "$unopkg" add --force "$oxt"; then
      installed=1
      say "Installed."
    else
      say "unopkg couldn't install it; add it by hand as below."
    fi
  fi

  step "Done! To turn the theme on:"
  if [ -z "$installed" ]; then
    say "1. In LibreOffice, open Tools -> Extensions, click Add, and choose"
    say "   $oxt"
    say "   then restart LibreOffice."
  else
    say "1. Open LibreOffice (or restart it)."
  fi
  say "2. Open Tools -> Options (LibreOffice -> Preferences on a Mac) ->"
  say "   LibreOffice -> Appearance."
  say "3. Tick \"Enable application theming\", choose \"Jenerated $NAME\" as the"
  say "   theme, click OK, and restart LibreOffice when it asks."
  say "To keep documents on white pages, also tick \"Use white document"
  say "background\"."
  say "After changing the palette, run ./setup.sh again (with LibreOffice"
  say "closed) and restart LibreOffice."
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

install_kde() {
  local data="${XDG_DATA_HOME:-$HOME/.local/share}"
  local folder="$ROOT/app-themes/kde-theme/$SLUG"
  local scheme="Jenerated-$SLUG"
  local current="" applied=""

  step "Installing the Plasma color scheme, Konsole colors and Kate theme"
  mkdir -p "$data/color-schemes" "$data/konsole" "$data/org.kde.syntax-highlighting/themes"
  install_link "$data/color-schemes/$scheme.colors" "$folder/$scheme.colors"
  install_link "$data/konsole/$scheme.colorscheme" "$folder/$scheme.colorscheme"
  install_link "$data/org.kde.syntax-highlighting/themes/$scheme.theme" "$folder/$scheme.theme"

  # On Plasma, offer to switch the color scheme now.
  if plasma-apply-colorscheme --list-schemes >/dev/null 2>&1; then
    current="$(plasma-apply-colorscheme --list-schemes 2>/dev/null |
      sed -n 's/^ *\* *\(.*\) (current color scheme)$/\1/p')"
    say ""
    [ -n "$current" ] && say "Your Plasma color scheme is $current."
    if ask_yes "Switch Plasma to Jenerated $NAME now?"; then
      plasma-apply-colorscheme "$scheme" && applied=1
    fi
  fi

  step "Done! To turn the themes on:"
  if [ -n "$applied" ]; then
    say "- Plasma, its window title bars and KDE apps use Jenerated $NAME now."
    [ -n "$current" ] && say "  To switch back: plasma-apply-colorscheme $current"
  else
    say "- Plasma and KDE apps: System Settings -> Colors & Themes -> Colors,"
    say "  choose \"Jenerated $NAME\" (or run plasma-apply-colorscheme $scheme)."
  fi
  say "- Konsole: Settings -> Edit Current Profile -> Appearance, choose"
  say "  \"Jenerated $NAME\"."
  say "- Kate and KWrite: Settings -> Configure Kate -> Color Themes, choose"
  say "  \"Jenerated $NAME\" (restart Kate first if it's open)."
  say "GTK apps follow Plasma's colors too, through KDE's GTK integration."
}

# Where Godot keeps its editor settings: the usual place, and, if Godot was
# installed through Flatpak, the folder Flatpak gives it.
godot_config_dirs() {
  if [ "$OS" = "Darwin" ]; then
    printf '%s\n' "$HOME/Library/Application Support/Godot"
    return 0
  fi
  printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/godot"
  local app
  for app in org.godotengine.Godot org.godotengine.GodotSharp; do
    if [ -d "$HOME/.var/app/$app" ]; then
      printf '%s\n' "$HOME/.var/app/$app/config/godot"
    fi
  done
  return 0
}

# The newest editor settings file in a Godot config folder, or nothing.
# Godot 4.3 and later name it editor_settings-4.<minor>.tres; earlier 4.x
# versions, editor_settings-4.tres.
godot_settings_file() {
  local newest
  newest="$(ls "$1"/editor_settings-4.[0-9]*.tres 2>/dev/null | sort -V | tail -n 1)"
  if [ -n "$newest" ]; then
    printf '%s' "$newest"
  elif [ -f "$1/editor_settings-4.tres" ]; then
    printf '%s' "$1/editor_settings-4.tres"
  fi
}

# Prints the settings to change by hand, from the comment in
# editor-settings.cfg.
godot_manual_steps() {
  say "In Godot, open Editor -> Editor Settings and set:"
  sed -n 's/^;   /  /p' "$1" | while IFS= read -r line; do say "$line"; done
}

# apply_godot_settings settings-file cfg-file: sets each "key = value" line
# of the cfg file in Godot's editor settings, replacing the key's line if
# it's there and adding it if not.
apply_godot_settings() {
  "$PYTHON" -c '
import re, sys
settings_path, cfg_path = sys.argv[1], sys.argv[2]
text = open(settings_path).read()
if not re.search(r"^\[resource\]$", text, re.M):
    sys.exit(f"{settings_path} does not look like Godot editor settings")
for line in open(cfg_path).read().splitlines():
    if not line.strip() or line.startswith(";"):
        continue
    key = line.split(" = ", 1)[0]
    pattern = re.compile(rf"^{re.escape(key)} = .*$", re.M)
    if pattern.search(text):
        text = pattern.sub(lambda m: line, text, count=1)
    else:
        text = text.rstrip("\n") + "\n" + line + "\n"
open(settings_path, "w").write(text)
' "$1" "$2"
}

install_godot() {
  local folder="$ROOT/app-themes/godot-theme/$SLUG"
  local theme="Jenerated-$SLUG"
  local cfg="$folder/editor-settings.cfg"
  local dir file applied=""
  local dirs=() files=()

  # Collect the folders first: install_link may ask a question, which reads
  # your answer from standard input, which a "while read" loop would take over.
  while IFS= read -r dir; do dirs+=("$dir"); done < <(godot_config_dirs)

  step "Installing the Godot script editor theme"
  for dir in "${dirs[@]}"; do
    mkdir -p "$dir/text_editor_themes"
    install_link "$dir/text_editor_themes/$theme.tet" "$folder/$theme.tet"
    file="$(godot_settings_file "$dir")"
    if [ -n "$file" ]; then files+=("$file"); fi
  done

  # The rest of the editor takes its colors from a few editor settings.
  say ""
  if [ "${#files[@]}" -eq 0 ]; then
    say "Godot hasn't been opened yet, so it has no editor settings to change."
    say "Open it once and run ./setup.sh again, or set the colors by hand."
  elif pgrep -i godot >/dev/null 2>&1; then
    say "Godot is open, and it saves its settings when it closes, which would"
    say "undo any change made now. Close it and run ./setup.sh again, or set"
    say "the colors by hand."
  elif [ -z "$PYTHON" ]; then
    say "Changing Godot's editor settings for you needs Python 3.11 or later;"
    say "set the colors by hand."
  elif ask_yes "Set Godot's editor colors to Jenerated $NAME? (Your settings are backed up first.)"; then
    for file in "${files[@]}"; do
      # Keep the first backup: it's the settings from before any palette.
      [ -e "$file.before-jenerated" ] || cp "$file" "$file.before-jenerated"
      apply_godot_settings "$file" "$cfg" || die "couldn't update $file"
      say "Updated $file"
    done
    applied=1
  fi

  if [ -n "$applied" ]; then
    step "Done! Open Godot: the editor and the script editor use Jenerated $NAME."
    say "To go back, choose Default for Color Preset and Color Theme in"
    say "Editor -> Editor Settings, or restore the backup with Godot closed:"
    for file in "${files[@]}"; do
      say "    cp \"$file.before-jenerated\" \"$file\""
    done
  else
    step "Done! To turn the theme on:"
    godot_manual_steps "$cfg"
  fi
  say "After changing the palette, run ./setup.sh again (the script editor"
  say "theme updates by itself, but the interface colors are copied)."
}

# Folders that can hold Zen's profiles.ini: Zen's usual one (newer versions
# use the XDG config folder on Linux), and, if Zen was installed through
# Flatpak, the folder Flatpak gives it.
zen_profile_roots() {
  if [ "$OS" = "Darwin" ]; then
    printf '%s\n' "$HOME/Library/Application Support/zen"
    return 0
  fi
  printf '%s\n' "$HOME/.zen" "${XDG_CONFIG_HOME:-$HOME/.config}/zen"
  local flatpak="$HOME/.var/app/app.zen_browser.zen"
  if [ -d "$flatpak" ]; then
    printf '%s\n' "$flatpak/.zen" "$flatpak/config/zen"
  fi
  return 0
}

# Prints "folder<TAB>name" for each Zen profile whose folder exists.
zen_profiles() {
  local root
  while IFS= read -r root; do
    [ -f "$root/profiles.ini" ] || continue
    tr -d '\r' <"$root/profiles.ini" | awk -F= -v root="$root" '
      function flush() {
        if (inprofile && path != "") print (relative == "1" ? root "/" path : path) "\t" name
      }
      /^\[/ { flush(); inprofile = ($0 ~ /^\[Profile/); path = ""; name = ""; relative = "1"; next }
      $1 == "Name" { name = substr($0, 6) }
      $1 == "Path" { path = substr($0, 6) }
      $1 == "IsRelative" { relative = $2 }
      END { flush() }
    '
  done < <(zen_profile_roots) | while IFS="$(printf '\t')" read -r folder name; do
    if [ -d "$folder" ]; then printf '%s\t%s\n' "$folder" "$name"; fi
  done
}

# zen_import file stylesheet: makes sure file (userChrome.css or
# userContent.css) starts by importing stylesheet, creating it if needed.
# Asks before changing a file that's already there.
zen_import() {
  local file="$1" line="@import \"$2\";"
  if [ ! -e "$file" ]; then
    printf '%s\n' "/* Zen's stylesheet for $(basename "$file" .css). The line below loads the" \
      "   Jenerated theme; your own styles can go after it. */" "$line" >"$file"
    say "Created $file"
  elif grep -qxF -- "$line" "$file"; then
    return 0
  elif ask_yes "Add the theme to the top of your $(basename "$file")? (Your styles in it are kept.)"; then
    { printf '%s\n' "$line"; cat "$file"; } >"$file.jenerated-new" && mv "$file.jenerated-new" "$file"
    say "Added the theme to $file"
  else
    say "Left $file alone; add this line to the top of it to use the theme:"
    say "    $line"
  fi
}

install_zen() {
  local folder="$ROOT/app-themes/zen-theme/$SLUG"
  local profiles=() names=() dir name profile chrome
  local pref='user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);'

  while IFS="$(printf '\t')" read -r dir name; do
    profiles+=("$dir")
    names+=("${name:-$(basename "$dir")} ($dir)")
  done < <(zen_profiles)

  if [ "${#profiles[@]}" -eq 0 ]; then
    step "Zen hasn't been opened yet, so it has no profile to add the theme to."
    say "Open Zen once, close it, and run ./setup.sh again."
    return 0
  elif [ "${#profiles[@]}" -eq 1 ]; then
    profile="${profiles[0]}"
  else
    choose "Which Zen profile?" "${names[@]}"
    profile="${profiles[$CHOICE]}"
  fi

  step "Installing the Zen theme into $profile"
  chrome="$profile/chrome"
  mkdir -p "$chrome"
  install_link "$chrome/jenerated-userChrome.css" "$folder/userChrome.css"
  install_link "$chrome/jenerated-userContent.css" "$folder/userContent.css"
  zen_import "$chrome/userChrome.css" "jenerated-userChrome.css"
  zen_import "$chrome/userContent.css" "jenerated-userContent.css"

  # Zen only reads userChrome.css and userContent.css with this setting on;
  # user.js sets it each time Zen starts.
  if ! grep -qxF -- "$pref" "$profile/user.js" 2>/dev/null; then
    # Start on a new line, even if the file's last line doesn't end with one.
    if [ -s "$profile/user.js" ] && [ -n "$(tail -c 1 "$profile/user.js")" ]; then
      printf '\n' >>"$profile/user.js"
    fi
    printf '%s\n' "$pref" >>"$profile/user.js"
    say "Turned on custom stylesheets in $profile/user.js"
  fi

  step "Done! Restart Zen to see Jenerated $NAME."
  say "Zen reads the theme from this folder when it starts, so after changing"
  say "the palette, restart Zen again. To go back to Zen's own look, remove the"
  say "@import lines from userChrome.css and userContent.css in"
  say "    $chrome"
}

# Editors built on GtkSourceView read style schemes from a folder named after
# their GtkSourceView version, and the three versions in use each need their
# own file (see app-themes/gtksourceview-theme/README.md).
install_gtksourceview() {
  local data="${XDG_DATA_HOME:-$HOME/.local/share}"
  local folder="$ROOT/app-themes/gtksourceview-theme/$SLUG"
  local file="jenerated-$SLUG.xml"
  local version dir
  # "folder-in-this-repo  styles-folder" pairs: GtkSourceView 3 and 4 (gedit 46
  # and earlier, Xed, Pluma, Meld), 5 (GNOME Text Editor), and gedit 47 and
  # later's own libgedit-gtksourceview.
  local pairs=(
    "gtksourceview-4 $data/gtksourceview-3.0/styles"
    "gtksourceview-4 $data/gtksourceview-4/styles"
    "gtksourceview-5 $data/gtksourceview-5/styles"
    "libgedit-gtksourceview-300 $data/libgedit-gtksourceview-300/styles"
  )
  # Apps installed through Flatpak keep their data in folders of their own.
  if [ -d "$HOME/.var/app/org.gnome.TextEditor" ]; then
    pairs+=("gtksourceview-5 $HOME/.var/app/org.gnome.TextEditor/data/gtksourceview-5/styles")
  fi
  if [ -d "$HOME/.var/app/org.gnome.gedit" ]; then
    pairs+=("libgedit-gtksourceview-300 $HOME/.var/app/org.gnome.gedit/data/libgedit-gtksourceview-300/styles")
  fi

  step "Installing the style schemes"
  for pair in "${pairs[@]}"; do
    version="${pair%% *}"
    dir="${pair#* }"
    mkdir -p "$dir"
    install_link "$dir/$file" "$folder/$version/$file"
  done

  step "Done! Choose \"Jenerated $NAME\" as the color scheme in each editor:"
  say "- gedit: Preferences -> Font & Colors."
  say "- GNOME Text Editor: the menu -> Preferences -> Style. It only lists"
  say "  schemes that match its own light or dark style, so for this palette"
  if grep -q '<property name="variant">light</property>' "$folder/gtksourceview-5/$file"; then
    say "  choose the light style first (the sun at the top of the menu)."
  else
    say "  choose the dark style first (the moon at the top of the menu)."
  fi
  say "- Xed: Edit -> Preferences -> Theme."
  say "- Pluma, Meld and other GtkSourceView editors: in their preferences,"
  say "  usually under fonts and colors."
  say "Reopen editors that were already open. After changing the palette, run"
  say "./jenerate.py $SLUG and reopen them."
}

# fzf reads its colors from FZF_DEFAULT_OPTS, so the theme is a small file
# the shell loads at startup: linked to one place, so switching palettes just
# repoints the link.
install_fzf() {
  local folder="$ROOT/app-themes/fzf-theme/$SLUG"
  local config="${XDG_CONFIG_HOME:-$HOME/.config}"
  local colors="$config/fzf/jenerated-colors.sh"
  local line='[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/fzf/jenerated-colors.sh" ] && . "${XDG_CONFIG_HOME:-$HOME/.config}/fzf/jenerated-colors.sh"'
  local shell rc rcs=() loaded=""

  step "Installing the fzf colors"
  mkdir -p "$config/fzf"
  install_link "$colors" "$folder/jenerated-$SLUG.sh"

  # bash and zsh load it from their startup file: each one that exists, and
  # your own shell's even if it doesn't exist yet.
  shell="$(basename "${SHELL:-}")"
  for rc in bash zsh; do
    if [ -f "$HOME/.${rc}rc" ] || [ "$shell" = "$rc" ]; then rcs+=("$HOME/.${rc}rc"); fi
  done
  for rc in "${rcs[@]}"; do
    if grep -qxF -- "$line" "$rc" 2>/dev/null; then
      loaded=1
    elif ask_yes "Load the colors in $(basename "$rc")? (Adds one line at the end.)"; then
      if [ -s "$rc" ] && [ -n "$(tail -c 1 "$rc")" ]; then printf '\n' >>"$rc"; fi
      printf '%s\n' "# fzf colors from Jenerated Themes" "$line" >>"$rc"
      say "Added the colors to $rc"
      loaded=1
    fi
  done

  # fish loads everything in conf.d by itself.
  if command -v fish >/dev/null 2>&1 || [ -d "$config/fish" ]; then
    mkdir -p "$config/fish/conf.d"
    install_link "$config/fish/conf.d/jenerated-fzf.fish" "$folder/jenerated-$SLUG.fish"
    loaded=1
  fi

  if [ -n "$loaded" ]; then
    step "Done! Open a new terminal to use fzf in Jenerated $NAME."
  else
    step "Done! To use the colors, add this line to your shell's startup file:"
    say "    $line"
  fi
  say "Your own FZF_DEFAULT_OPTS are kept; the colors are added after them."
  say "After changing the palette, run ./jenerate.py $SLUG and open a new"
  say "terminal."
}

# mpv's settings folders: the usual one (on macOS too), and, if mpv was
# installed through Flatpak, the folder Flatpak gives it.
mpv_config_dirs() {
  printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/mpv"
  if [ -d "$HOME/.var/app/io.mpv.Mpv" ]; then
    printf '%s\n' "$HOME/.var/app/io.mpv.Mpv/config/mpv"
  fi
  return 0
}

# OBS Studio's themes folders: the usual one, and, if OBS was installed
# through Flatpak, the folder Flatpak gives it.
obs_themes_dirs() {
  if [ "$OS" = "Darwin" ]; then
    printf '%s\n' "$HOME/Library/Application Support/obs-studio/themes"
  else
    printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/obs-studio/themes"
  fi
  if [ -d "$HOME/.var/app/com.obsproject.Studio" ]; then
    printf '%s\n' "$HOME/.var/app/com.obsproject.Studio/config/obs-studio/themes"
  fi
  return 0
}

install_obs() {
  local file="jenerated-$SLUG.ovt"
  local dir dirs=()

  # Collect the folders first: install_link may ask a question, which reads
  # your answer from standard input, which a "while read" loop would take over.
  while IFS= read -r dir; do dirs+=("$dir"); done < <(obs_themes_dirs)

  step "Installing the OBS Studio style"
  for dir in "${dirs[@]}"; do
    mkdir -p "$dir"
    install_link "$dir/$file" "$ROOT/app-themes/obs-theme/$file"
  done

  step "Done! To turn the style on, restart OBS Studio, then:"
  say "1. Open Settings -> Appearance."
  say "2. Choose Yami as the Theme, and \"Jenerated $NAME\" as the Style."
  say "After changing the palette, run ./jenerate.py $SLUG and restart OBS."
}

install_mpv() {
  local folder="$ROOT/app-themes/mpv-theme/$SLUG"
  local line='include="~~/jenerated-colors.conf"'
  local dir conf dirs=()

  # Collect the folders first: the questions below read your answers from
  # standard input, which a "while read" loop would take over.
  while IFS= read -r dir; do dirs+=("$dir"); done < <(mpv_config_dirs)

  step "Installing the mpv colors"
  for dir in "${dirs[@]}"; do
    mkdir -p "$dir"
    install_link "$dir/jenerated-colors.conf" "$folder/jenerated-$SLUG.conf"
    conf="$dir/mpv.conf"
    if [ ! -e "$conf" ]; then
      printf '%s\n' "# mpv's settings. The line below loads the Jenerated colors." "$line" >"$conf"
      say "Created $conf"
    elif grep -qxF -- "$line" "$conf"; then
      :
    elif ask_yes "Load the colors at the end of $conf? (Your settings in it are kept.)"; then
      if [ -s "$conf" ] && [ -n "$(tail -c 1 "$conf")" ]; then printf '\n' >>"$conf"; fi
      printf '%s\n' "# Colors from Jenerated Themes" "$line" >>"$conf"
      say "Added the colors to $conf"
    else
      say "Left $conf alone; add this line to the end of it to use the colors:"
      say "    $line"
    fi
  done

  step "Done! Restart mpv to see Jenerated $NAME."
  say "The on-screen controller's colors need mpv 0.39 or later; older versions"
  say "keep its own colors (and mention the settings they don't know)."
  say "After changing the palette, run ./jenerate.py $SLUG and restart mpv."
}

install_tmux() {
  local folder="$ROOT/app-themes/tmux-theme/$SLUG"
  local colors="${XDG_CONFIG_HOME:-$HOME/.config}/tmux/jenerated-colors.conf"
  local conf path line

  step "Installing the tmux colors"
  mkdir -p "$(dirname "$colors")"
  install_link "$colors" "$folder/jenerated-$SLUG.conf"

  # tmux reads ~/.tmux.conf if there is one, and otherwise its file in the
  # config folder (tmux 3.1 and later). Use whichever it reads, or start a
  # ~/.tmux.conf, which every version reads.
  if [ -f "$HOME/.tmux.conf" ]; then
    conf="$HOME/.tmux.conf"
  elif [ -f "${XDG_CONFIG_HOME:-$HOME/.config}/tmux/tmux.conf" ]; then
    conf="${XDG_CONFIG_HOME:-$HOME/.config}/tmux/tmux.conf"
  else
    conf="$HOME/.tmux.conf"
  fi
  # tmux expands ~ in an unquoted path; -q skips the file if it's gone.
  case "$colors" in
    "$HOME"/*[[:space:]]*) path="\"$colors\"" ;;
    "$HOME"/*) path="~${colors#"$HOME"}" ;;
    *) path="\"$colors\"" ;;
  esac
  line="source-file -q $path"

  if [ ! -e "$conf" ]; then
    printf '%s\n' "# tmux settings. The line below loads the Jenerated colors." "$line" >"$conf"
    say "Created $conf"
  elif grep -qxF -- "$line" "$conf"; then
    :
  elif ask_yes "Load the colors at the end of $conf? (Your settings in it are kept.)"; then
    if [ -s "$conf" ] && [ -n "$(tail -c 1 "$conf")" ]; then printf '\n' >>"$conf"; fi
    printf '%s\n' "# Colors from Jenerated Themes" "$line" >>"$conf"
    say "Added the colors to $conf"
  else
    say "Left $conf alone; add this line to the end of it to use the colors:"
    say "    $line"
  fi

  # A running tmux only reads its settings when it starts, unless told to.
  if command -v tmux >/dev/null 2>&1 && tmux list-sessions >/dev/null 2>&1 &&
    ask_yes "tmux is running. Load the colors into it now?"; then
    tmux source-file "$colors" && step "Done! tmux uses Jenerated $NAME now."
  else
    step "Done! tmux will use Jenerated $NAME the next time it starts."
    say "To load it into a running tmux: tmux source-file $path"
  fi
  say "After changing the palette, run ./jenerate.py $SLUG and load it again."
}

install_zsh() {
  local folder="$ROOT/app-themes/zsh-theme/$SLUG"
  local config="${XDG_CONFIG_HOME:-$HOME/.config}"
  local zshrc="${ZDOTDIR:-$HOME}/.zshrc"
  local line='[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/jenerated-colors.zsh" ] && source "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/jenerated-colors.zsh"'
  local fast=""

  step "Installing the zsh colors"
  mkdir -p "$config/zsh" "$config/fsh"
  install_link "$config/zsh/jenerated-colors.zsh" "$folder/jenerated-$SLUG.zsh"
  install_link "$config/fsh/jenerated-colors.ini" "$folder/jenerated-$SLUG.ini"

  # zsh-syntax-highlighting and zsh-autosuggestions read the colors from the
  # file ~/.zshrc loads (before or after the plugins; either works).
  if [ ! -e "$zshrc" ]; then
    printf '%s\n' "# zsh settings. The line below loads the Jenerated colors." "$line" >"$zshrc"
    say "Created $zshrc"
  elif grep -qxF -- "$line" "$zshrc"; then
    :
  elif ask_yes "Load the colors at the end of $zshrc? (Your settings in it are kept.)"; then
    if [ -s "$zshrc" ] && [ -n "$(tail -c 1 "$zshrc")" ]; then printf '\n' >>"$zshrc"; fi
    printf '%s\n' "# Colors from Jenerated Themes" "$line" >>"$zshrc"
    say "Added the colors to $zshrc"
  else
    say "Left $zshrc alone; add this line to the end of it to use the colors:"
    say "    $line"
  fi

  # fast-syntax-highlighting keeps its own copy of a theme, made by its
  # fast-theme command, which only exists once ~/.zshrc has loaded the plugin.
  if command -v zsh >/dev/null 2>&1 &&
    zsh -ic 'if (( $+functions[fast-theme] )); then fast-theme -q XDG:jenerated-colors && print JENERATED-FAST-THEME-DONE; fi' \
      </dev/null 2>/dev/null | grep -q JENERATED-FAST-THEME-DONE; then
    say "Switched fast-syntax-highlighting to Jenerated $NAME."
    fast=1
  fi

  step "Done! Open a new terminal to see Jenerated $NAME in zsh."
  if [ -z "$fast" ]; then
    say "If you use fast-syntax-highlighting, switch it to the theme with:"
    say "    fast-theme XDG:jenerated-colors"
  fi
  say "After changing the palette, run ./setup.sh again: fast-syntax-highlighting"
  say "keeps its own copy of the theme."
}

# Element Desktop's settings folders: the usual one, and, if Element was
# installed through Flatpak, the folder Flatpak gives it.
element_config_dirs() {
  if [ "$OS" = "Darwin" ]; then
    printf '%s\n' "$HOME/Library/Application Support/Element"
    return 0
  fi
  printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/Element"
  if [ -d "$HOME/.var/app/im.riot.Riot" ]; then
    printf '%s\n' "$HOME/.var/app/im.riot.Riot/config/Element"
  fi
  return 0
}

# add_element_theme config theme -> adds the theme to Element's config.json,
# in setting_defaults.custom_themes, replacing any earlier Jenerated theme and
# keeping everything else in the file.
add_element_theme() {
  "$PYTHON" -c '
import json, os, sys
config_path, theme_path = sys.argv[1], sys.argv[2]
config = {}
if os.path.exists(config_path):
    with open(config_path) as f:
        config = json.load(f)
theme = json.load(open(theme_path))
defaults = config.setdefault("setting_defaults", {})
themes = [t for t in defaults.get("custom_themes", [])
          if not str(t.get("name", "")).startswith("Jenerated ")]
defaults["custom_themes"] = themes + [theme]
with open(config_path + ".jenerated-new", "w") as f:
    json.dump(config, f, indent=4)
    f.write("\n")
os.replace(config_path + ".jenerated-new", config_path)
' "$1" "$2"
}

install_element() {
  local theme="$ROOT/app-themes/element-theme/$SLUG/jenerated-$SLUG.json"
  local dir config dirs=()

  [ -n "$PYTHON" ] || die "installing the Element theme needs Python 3.11 or later, to add it to
Element's config.json without disturbing the rest of the file.
To add it by hand, see app-themes/element-theme/README.md."

  while IFS= read -r dir; do dirs+=("$dir"); done < <(element_config_dirs)

  step "Adding the theme to Element's settings"
  for dir in "${dirs[@]}"; do
    config="$dir/config.json"
    mkdir -p "$dir"
    # Keep the first backup: it's the settings from before any palette.
    if [ -f "$config" ] && [ ! -e "$config.before-jenerated" ]; then
      cp "$config" "$config.before-jenerated"
    fi
    add_element_theme "$config" "$theme" ||
      die "couldn't update $config (is it valid JSON?)"
    say "Updated $config"
  done

  step "Done! To turn the theme on:"
  say "1. Restart Element (it reads its settings when it starts)."
  say "2. Open Settings -> Appearance, and choose \"Jenerated $NAME\"."
  say "The theme is copied into Element's settings, so after changing the"
  say "palette, run ./setup.sh again and restart Element."
  say "This works in Element Desktop; the web version at app.element.io can't"
  say "read your settings folder."
}

# Insomnia's plugin folders: the usual one, and, if Insomnia was installed
# through Flatpak or Snap, the folder each of those gives it.
insomnia_plugin_dirs() {
  if [ "$OS" = "Darwin" ]; then
    printf '%s\n' "$HOME/Library/Application Support/Insomnia/plugins"
    return 0
  fi
  printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/Insomnia/plugins"
  if [ -d "$HOME/.var/app/rest.insomnia.Insomnia" ]; then
    printf '%s\n' "$HOME/.var/app/rest.insomnia.Insomnia/config/Insomnia/plugins"
  fi
  if [ -d "$HOME/snap/insomnia" ]; then
    printf '%s\n' "$HOME/snap/insomnia/current/.config/Insomnia/plugins"
  fi
  return 0
}

install_insomnia() {
  local plugin="insomnia-plugin-jenerated-$SLUG"
  local source="$ROOT/app-themes/insomnia-theme/$SLUG/$plugin"
  local dir dirs=()

  while IFS= read -r dir; do dirs+=("$dir"); done < <(insomnia_plugin_dirs)

  # Insomnia ignores plugins that are links to folders elsewhere, so the plugin
  # is copied. A folder with this name is one setup.sh made before, so it's
  # replaced.
  step "Installing the Insomnia theme plugin"
  for dir in "${dirs[@]}"; do
    mkdir -p "$dir"
    rm -rf "${dir:?}/$plugin"
    cp -R "$source" "$dir/$plugin"
    say "Copied the plugin to $dir/$plugin"
  done

  step "Done! To turn the theme on:"
  say "1. Restart Insomnia, or open Settings (Preferences in older versions)"
  say "   -> Plugins and choose Reload."
  say "2. Open Settings -> Themes, and choose \"Jenerated $NAME\"."
  say "The plugin is a copy, so after changing the palette, run ./setup.sh again"
  say "and reload the plugins."
}

# Sublime Text's data folders: Sublime Text 4's, and Sublime Text 3's, the
# Flatpak's and the Snap's when they exist.
sublime_data_dirs() {
  if [ "$OS" = "Darwin" ]; then
    printf '%s\n' "$HOME/Library/Application Support/Sublime Text"
    if [ -d "$HOME/Library/Application Support/Sublime Text 3" ]; then
      printf '%s\n' "$HOME/Library/Application Support/Sublime Text 3"
    fi
    return 0
  fi
  local config="${XDG_CONFIG_HOME:-$HOME/.config}"
  printf '%s\n' "$config/sublime-text"
  if [ -d "$config/sublime-text-3" ]; then printf '%s\n' "$config/sublime-text-3"; fi
  if [ -d "$HOME/.var/app/com.sublimetext.three" ]; then
    printf '%s\n' "$HOME/.var/app/com.sublimetext.three/config/sublime-text"
  fi
  if [ -d "$HOME/snap/sublime-text" ]; then
    printf '%s\n' "$HOME/snap/sublime-text/current/.config/sublime-text"
  fi
  return 0
}

install_sublime() {
  local file="jenerated-$SLUG.sublime-color-scheme"
  local dir dirs=()

  # Collect the folders first: install_link may ask a question, which reads
  # your answer from standard input, which a "while read" loop would take over.
  while IFS= read -r dir; do dirs+=("$dir"); done < <(sublime_data_dirs)

  step "Installing the Sublime Text color scheme"
  for dir in "${dirs[@]}"; do
    mkdir -p "$dir/Packages/User"
    install_link "$dir/Packages/User/$file" "$ROOT/app-themes/sublime-theme/$file"
  done

  step "Done! To turn the color scheme on, in Sublime Text:"
  say "1. Open the command palette (Ctrl+Shift+P, or Cmd+Shift+P on a Mac),"
  say "   choose \"UI: Select Color Scheme\", then \"Jenerated $NAME\"."
  say "2. For the sidebar and tabs to match, choose \"UI: Select Theme\" there"
  say "   too, then \"Adaptive\", which takes its colors from the color scheme."
  say "Sublime Text reloads the color scheme when the palette changes and"
  say "./jenerate.py $SLUG runs again."
}

install_xcode() {
  local themes="$HOME/Library/Developer/Xcode/UserData/FontAndColorThemes"

  # Xcode lists a theme by its file name, so the link is named after the
  # palette rather than its slug.
  step "Installing the Xcode theme"
  mkdir -p "$themes"
  install_link "$themes/Jenerated $NAME.xccolortheme" "$ROOT/app-themes/xcode-theme/jenerated-$SLUG.xccolortheme"

  step "Done! To turn the theme on:"
  say "1. Quit Xcode if it's open, and open it again (it finds new themes when"
  say "   it starts)."
  say "2. Open Xcode -> Settings (Preferences in older versions) -> Themes, and"
  say "   choose \"Jenerated $NAME\"."
  say "After changing the palette, run ./jenerate.py $SLUG and restart Xcode."
}

install_rstudio() {
  # RStudio's settings folder, on Linux and macOS alike.
  local themes
  if [ -n "${RSTUDIO_CONFIG_HOME:-}" ]; then
    themes="$RSTUDIO_CONFIG_HOME/themes"
  else
    themes="${XDG_CONFIG_HOME:-$HOME/.config}/rstudio/themes"
  fi

  step "Installing the RStudio theme"
  mkdir -p "$themes"
  install_link "$themes/jenerated-$SLUG.rstheme" "$ROOT/app-themes/rstudio-theme/jenerated-$SLUG.rstheme"

  step "Done! To turn the theme on, in RStudio:"
  say "1. Open Tools -> Global Options -> Appearance."
  say "2. Choose \"Jenerated $NAME\" as the Editor theme, and Apply. (Restart"
  say "   RStudio first if it doesn't appear.)"
  say "After changing the palette, run ./jenerate.py $SLUG and choose the theme"
  say "again, or restart RStudio."
}

# Emacs's own folder, chosen the way Emacs chooses it: ~/.emacs.d if it (or
# a ~/.emacs file) exists, otherwise ~/.config/emacs if that exists, and
# otherwise ~/.emacs.d.
emacs_dir() {
  local xdg="${XDG_CONFIG_HOME:-$HOME/.config}/emacs"
  if [ -e "$HOME/.emacs.d" ] || [ -e "$HOME/.emacs" ]; then
    printf '%s' "$HOME/.emacs.d"
  elif [ -e "$xdg" ]; then
    printf '%s' "$xdg"
  else
    printf '%s' "$HOME/.emacs.d"
  fi
}

install_emacs() {
  local dir file="jenerated-$SLUG-theme.el"
  dir="$(emacs_dir)"

  # Emacs looks for themes in its own folder, so nothing else needs setting.
  step "Installing the Emacs theme"
  mkdir -p "$dir"
  install_link "$dir/$file" "$ROOT/app-themes/emacs-theme/$file"

  step "Done! To turn the theme on, in Emacs:"
  say "1. Run M-x load-theme RET jenerated-$SLUG RET. Emacs asks whether to"
  say "   trust the theme's code first; say yes (and yes to treating it as"
  say "   safe, so it doesn't ask again)."
  say "2. To keep it, run M-x customize-themes, tick jenerated-$SLUG (and"
  say "   untick any other theme), and choose Save Theme Settings."
  say "After changing the palette, run ./jenerate.py $SLUG and load the theme"
  say "again."
}

# Qt Creator's user styles folders: the usual one (~/.config on macOS too),
# and, if Qt Creator was installed through Flatpak, the folder Flatpak gives
# it.
qtcreator_styles_dirs() {
  if [ "$OS" = "Darwin" ]; then
    printf '%s\n' "$HOME/.config/QtProject/qtcreator/styles"
  else
    printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/QtProject/qtcreator/styles"
  fi
  if [ -d "$HOME/.var/app/io.qt.QtCreator" ]; then
    printf '%s\n' "$HOME/.var/app/io.qt.QtCreator/config/QtProject/qtcreator/styles"
  fi
  return 0
}

install_qtcreator() {
  local file="jenerated-$SLUG.xml"
  local dir dirs=()

  # Collect the folders first: install_link may ask a question, which reads
  # your answer from standard input, which a "while read" loop would take over.
  while IFS= read -r dir; do dirs+=("$dir"); done < <(qtcreator_styles_dirs)

  step "Installing the Qt Creator color scheme"
  for dir in "${dirs[@]}"; do
    mkdir -p "$dir"
    install_link "$dir/$file" "$ROOT/app-themes/qtcreator-theme/$file"
  done

  step "Done! To turn the color scheme on, in Qt Creator:"
  say "1. Open Edit -> Preferences (Qt Creator -> Settings on a Mac, Tools ->"
  say "   Options in older versions) -> Text Editor -> Font & Colors."
  say "2. Choose \"Jenerated $NAME\" as the Color Scheme. (Restart Qt Creator"
  say "   first if it doesn't appear.)"
  say "For the rest of the window, choose Qt Creator's own Dark or Light theme"
  say "to match, under Environment -> Interface -> Theme."
  say "After changing the palette, run ./jenerate.py $SLUG and choose the scheme"
  say "again, or restart Qt Creator."
}

# Spyder's settings files (spyder.ini): the usual one, and, if Spyder was
# installed through Flatpak, the one in the folder Flatpak gives it.
spyder_ini_files() {
  if [ -n "${SPYDER_CONFDIR:-}" ]; then
    printf '%s\n' "$SPYDER_CONFDIR/config/spyder.ini"
  elif [ "$OS" = "Darwin" ]; then
    printf '%s\n' "$HOME/.spyder-py3/config/spyder.ini"
  else
    printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/spyder-py3/config/spyder.ini"
  fi
  if [ -d "$HOME/.var/app/org.spyder_ide.spyder" ]; then
    printf '%s\n' "$HOME/.var/app/org.spyder_ide.spyder/config/spyder-py3/config/spyder.ini"
  fi
  return 0
}

# add_spyder_theme ini theme select -> adds the theme to spyder.ini as a
# custom theme: the custom-N that already has this name, or else the lowest
# free N (Spyder expects custom themes to be named custom-<number>). With
# select, also makes it the current theme.
add_spyder_theme() {
  "$PYTHON" -c '
import ast, configparser, os, sys
ini_path, theme_path, select = sys.argv[1], sys.argv[2], sys.argv[3] == "select"
def parser():
    p = configparser.ConfigParser(interpolation=None, comment_prefixes=(";", "#"))
    p.optionxform = str
    return p
theme = parser()
theme.read(theme_path)
theme = dict(theme["appearance"])
ini = parser()
ini.read(ini_path)
if not ini.has_section("appearance"):
    ini.add_section("appearance")
section = ini["appearance"]
names = ast.literal_eval(section.get("custom_names", "[]"))
scheme = next((n for n in names if section.get(f"{n}/name") == theme["name"]), None)
if scheme is None:
    used = {int(n.split("-")[-1]) for n in names}
    scheme = "custom-%d" % min(set(range(len(used) + 1)) - used)
    names = sorted(names + [scheme], key=lambda n: int(n.split("-")[-1]))
section["custom_names"] = repr(names)
for key, value in theme.items():
    section[f"{scheme}/{key}"] = value
if select:
    section["selected"] = scheme
with open(ini_path + ".jenerated-new", "w") as f:
    ini.write(f)
os.replace(ini_path + ".jenerated-new", ini_path)
print(scheme)
' "$1" "$2" "$3"
}

install_spyder() {
  local theme="$ROOT/app-themes/spyder-theme/jenerated-$SLUG.ini"
  local ini files=() found=() select=""

  while IFS= read -r ini; do files+=("$ini"); done < <(spyder_ini_files)
  for ini in "${files[@]}"; do
    if [ -f "$ini" ]; then found+=("$ini"); fi
  done

  step "Adding the theme to Spyder's settings"
  if [ "${#found[@]}" -eq 0 ]; then
    say "Spyder hasn't been opened yet, so it has no settings to add the theme to."
    say "Open it once, close it, and run ./setup.sh again."
    return 0
  fi
  # Spyder runs as a process named spyder, or as python -m spyder.
  if pgrep -ix spyder >/dev/null 2>&1 || pgrep -f -- '-m spyder( |$)' >/dev/null 2>&1; then
    say "Spyder is open, and it saves its settings when it closes, which would"
    say "undo any change made now. Close it and run ./setup.sh again."
    return 0
  fi
  [ -n "$PYTHON" ] || die "adding the theme to Spyder's settings needs Python 3.11 or later."

  if ask_yes "Also make Jenerated $NAME Spyder's current syntax theme?"; then
    select=select
  fi
  for ini in "${found[@]}"; do
    # Keep the first backup: it's the settings from before any palette.
    [ -e "$ini.before-jenerated" ] || cp "$ini" "$ini.before-jenerated"
    add_spyder_theme "$ini" "$theme" "${select:-add}" >/dev/null ||
      die "couldn't update $ini"
    say "Updated $ini"
  done

  step "Done! Open Spyder to use Jenerated $NAME."
  if [ -z "$select" ]; then
    say "Choose it under Tools -> Preferences -> Appearance -> Syntax"
    say "highlighting theme."
  fi
  say "The theme is copied into Spyder's settings, so after changing the"
  say "palette, run ./setup.sh again (with Spyder closed)."
}

# Unreal Engine's folder for your own editor themes. It's the same for every
# engine version, and Unreal doesn't follow XDG_CONFIG_HOME.
unreal_themes_dir() {
  if [ "$OS" = "Darwin" ]; then
    printf '%s\n' "$HOME/Library/Application Support/Epic/UnrealEngine/Slate/Themes"
  else
    printf '%s\n' "$HOME/.config/Epic/UnrealEngine/Slate/Themes"
  fi
}

install_unreal() {
  local file="jenerated-$SLUG.json"
  local dir
  dir="$(unreal_themes_dir)"

  step "Installing the Unreal Engine editor theme"
  mkdir -p "$dir"
  install_link "$dir/$file" "$ROOT/app-themes/unreal-theme/$file"

  step "Done! To turn the theme on, in the Unreal Editor:"
  say "1. Open Edit -> Editor Preferences -> General -> Appearance."
  say "2. Under Theme, choose \"Jenerated $NAME\" as the Active Theme. (Restart"
  say "   the editor first if it doesn't appear.)"
  say "To tweak the colors in Unreal, choose Duplicate and edit the copy, so"
  say "your changes aren't overwritten the next time you run ./jenerate.py."
  say "After changing the palette, run ./jenerate.py $SLUG and restart the"
  say "editor."
}

install_decky() {
  local themes="$HOME/homebrew/themes"

  step "Installing the CSS Loader theme"
  if [ ! -d "$HOME/homebrew" ]; then
    say "Decky Loader isn't installed yet (there's no ~/homebrew folder), so the"
    say "theme will wait for it. Install Decky Loader from https://decky.xyz,"
    say "then CSS Loader from Decky's plugin store."
  fi
  mkdir -p "$themes"
  install_link "$themes/Jenerated-$SLUG" "$ROOT/app-themes/decky-theme/$SLUG"

  step "Done! To turn the theme on, in Gaming Mode:"
  say "1. Open the Quick Access menu (the ... button on a Steam Deck), then"
  say "   Decky's plug icon, and choose CSS Loader."
  say "2. If CSS Loader was already running, scroll to the bottom and press"
  say "   Refresh so it finds the new theme."
  say "3. Turn on \"Jenerated $NAME\"."
  say "CSS Loader reads the theme from this folder, so after changing the"
  say "palette, press Refresh again. To go back to Steam's own colors, turn the"
  say "theme off."
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

install_jellyfin() {
  local file="app-themes/jellyfin-theme/jenerated-$SLUG.css"

  step "Your Jellyfin CSS"
  say "It's in $ROOT/$file"
  if copy_to_clipboard <"$file" 2>/dev/null; then
    say "(Copied to your clipboard.)"
  else
    say "Open that file and copy everything in it."
  fi

  step "Done! To turn the theme on (Jellyfin is themed from inside the app):"
  say "For everyone on your server (as an administrator):"
  say "1. Open Dashboard -> Branding (Dashboard -> General in older versions)."
  say "2. Paste the CSS into Custom CSS code, replacing anything there, and"
  say "   save."
  say "Or just for one device:"
  say "1. Open Settings -> Display."
  say "2. Paste the CSS into the Custom CSS code box, and save."
  say "Choose Jellyfin's Dark theme for a dark palette, or Light for a light one."
  say "After changing the palette, run ./setup.sh again and paste the new CSS."
}

install_mattermost() {
  local theme
  # One line, so it's easy to copy from the terminal too.
  theme="$(tr -d '\n' <"app-themes/mattermost-theme/$SLUG.json" | sed 's/  */ /g')"

  step "Your Mattermost theme"
  say ""
  say "$theme"
  say ""
  if printf '%s' "$theme" | copy_to_clipboard 2>/dev/null; then
    say "(Copied to your clipboard.)"
  fi

  step "Done! To turn the theme on (Mattermost keeps themes with your account):"
  say "1. In Mattermost, open Settings -> Display -> Theme, and choose Edit."
  say "2. Choose Custom Theme, and paste the theme above into the box under"
  say "   \"Copy and paste to share theme colors\"."
  say "3. Choose Save."
  say "It applies wherever you use Mattermost: the web, the desktop app and the"
  say "mobile apps. After changing the palette, run ./setup.sh again and paste"
  say "the new theme."
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
  kde) install_kde ;;
  decky) install_decky ;;
  godot) install_godot ;;
  zen) install_zen ;;
  gtksourceview) install_gtksourceview ;;
  fzf) install_fzf ;;
  mpv) install_mpv ;;
  obs) install_obs ;;
  jellyfin) install_jellyfin ;;
  tmux) install_tmux ;;
  zsh) install_zsh ;;
  element) install_element ;;
  mattermost) install_mattermost ;;
  insomnia) install_insomnia ;;
  sublime) install_sublime ;;
  xcode) install_xcode ;;
  rstudio) install_rstudio ;;
  emacs) install_emacs ;;
  qtcreator) install_qtcreator ;;
  spyder) install_spyder ;;
  unreal) install_unreal ;;
  libreoffice) install_libreoffice ;;
esac

say ""
say "Run ./setup.sh again any time to theme another app or switch palettes."
