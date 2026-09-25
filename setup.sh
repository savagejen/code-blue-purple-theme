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

# --- Prepare for a commit (for maintainers) --------------------------------
# ./setup.sh --prep-commit puts the generated files git tracks back to the
# committed defaults, so local palettes don't end up in a commit:
# Blue Purple's files are regenerated (restored if removed, updated if a
# template changed), and package.json is rebuilt listing only Blue Purple
# (keeping any change to package.json.tmpl). Other generated themes stay on
# disk; they're ignored by git. Deliberately left out of the usage and README.

PYTHON="$(find_python)"

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

APPS=("VS Code" "Slack" "Obsidian" "Vim / Neovim")
APP_IDS=("vscode" "slack" "obsidian" "vim")
if [ "$OS" = "Linux" ]; then
  APPS+=("Ptyxis (Ubuntu terminal)" "Tilix (terminal)")
  APP_IDS+=("ptyxis" "tilix")
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
  local source="$ROOT/vs-code-theme"

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
  ln -sf "$ROOT/ptyxis-theme/$SLUG.palette" "$palettes/$SLUG.palette"
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
  install_link "$themes/Jenerated $NAME" "$ROOT/obsidian-theme/$SLUG"

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

  # vim-theme is a Vim package: linked once, every generated palette's
  # colorscheme (in its colors/ folder) is available.
  if [ -n "$has_vim" ]; then
    step "Installing the colorschemes for Vim"
    mkdir -p "$(dirname "$vim_pack")"
    install_link "$vim_pack" "$ROOT/vim-theme"
  fi
  if [ -n "$has_nvim" ]; then
    step "Installing the colorschemes for Neovim"
    mkdir -p "$(dirname "$nvim_pack")"
    install_link "$nvim_pack" "$ROOT/vim-theme"
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

install_tilix() {
  local schemes="$HOME/.config/tilix/schemes"

  step "Installing the Tilix color scheme"
  mkdir -p "$schemes"
  # The jenerated- prefix keeps it from replacing a scheme of your own.
  install_link "$schemes/jenerated-$SLUG.json" "$ROOT/tilix-theme/$SLUG.json"

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
  theme="$(tr -d '\n' <"slack-theme/$SLUG.txt")"

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
  tilix) install_tilix ;;
esac

say ""
say "Run ./setup.sh again any time to theme another app or switch palettes."
