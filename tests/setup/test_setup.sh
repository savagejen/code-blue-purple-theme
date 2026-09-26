#!/usr/bin/env bash
# Tests for setup.sh.
#
# Usage: tests/setup/test_setup.sh
#
# Each test runs setup.sh from a throwaway copy of the repository, with HOME
# pointed at an empty folder, so nothing outside the sandbox is touched. Fake
# clipboard commands (and, where a test needs one, a fake `uname` or
# `python3`) are put first on PATH.

source "$(dirname "$0")/../lib.sh"

# Every clipboard tool writes to a file, so tests never touch the real one.
after_sandbox() {
  for tool in pbcopy wl-copy xclip xsel; do
    fake_command "$tool" "cat > \"$SANDBOX/clipboard\""
  done
  # A gsettings and plasma-apply-colorscheme that don't work, so no test
  # changes your desktop's theme.
  fake_command gsettings "exit 1"
  fake_command plasma-apply-colorscheme "exit 1"
  # The tests pick palettes by their place in the menu (Blue Purple is 1,
  # Sunset is 2), so keep only those two, whatever else is in palettes/.
  find "$SANDBOX/repo/palettes" -name '*.toml' ! -name 'blue-purple-palette.toml' \
    ! -name 'sunset-palette.toml' -delete
}

# fake_os Linux|Darwin -> makes `uname -s` report that OS.
fake_os() {
  fake_command uname "echo $1"
}

# Makes every python look too old to run jenerate.py.
fake_no_python() {
  for py in python3 python3.13 python3.12 python3.11; do
    fake_command "$py" "exit 1"
  done
}

# run_setup "1\nanswers" [options...] -> runs setup.sh with the options, feeding
# it the answers (use \n between them), and sets OUTPUT and STATUS. It runs
# from $RUN_FROM (default $SANDBOX), and runs $SETUP (default the sandbox
# repository's setup.sh).
# Settings that point apps at other folders (ZDOTDIR, RSTUDIO_CONFIG_HOME,
# SPYDER_CONFDIR) are cleared, so the tests never touch your real ones; a test
# that needs one set uses TEST_ZDOTDIR, TEST_RSTUDIO_CONFIG_HOME or
# TEST_SPYDER_CONFDIR instead.
run_setup() {
  local answers="$1"
  shift
  OUTPUT="$(cd "${RUN_FROM:-$SANDBOX}" && printf '%b' "$answers" |
    HOME="$SANDBOX/home" PATH="$SANDBOX/bin:$PATH" WAYLAND_DISPLAY= XDG_DATA_HOME= XDG_CACHE_HOME= XDG_CONFIG_HOME= \
    ZDOTDIR="${TEST_ZDOTDIR:-}" RSTUDIO_CONFIG_HOME="${TEST_RSTUDIO_CONFIG_HOME:-}" \
    SPYDER_CONFDIR="${TEST_SPYDER_CONFDIR:-}" \
      bash "${SETUP:-$SANDBOX/repo/setup.sh}" "$@" 2>&1)"
  STATUS=$?
}

# sandbox_jenerate args... -> runs the sandbox repository's jenerate.py.
sandbox_jenerate() {
  (cd "$SANDBOX/repo" && "$(find_python)" jenerate.py "$@" >/dev/null 2>&1)
}

# palette_name file -> prints a palette's name, read with Python's TOML parser.
palette_name() {
  "$(find_python)" -c '
import sys, tomllib
print(tomllib.load(open(sys.argv[1], "rb"))["name"])
' "$1"
}

# --- Tests: menus ------------------------------------------------------------

# GIVEN a Linux system
# WHEN setup.sh shows the app menu
# THEN it lists the categories with how many apps each has, then the apps
#      that don't fit one, then search, and a way back
test_app_menu_on_linux_groups_the_apps() {
  fake_os Linux
  run_setup "1\n2\n3\n1\n"
  assert_status 0
  assert_contains "Which app do you want to theme?
  1) Web browsers (4 apps)
  2) Communication (3 apps)
  3) Editors: code, text and notes (13 apps)
  4) Terminals and command-line tools (5 apps)
  5) Linux desktops (3 apps)
  6) Entertainment (3 apps)
  7) Insomnia (API client)
  8) Search for an app by name
  0) Back"
  assert_contains "Your Slack theme string"
}

# GIVEN a Mac
# WHEN setup.sh shows the app menu
# THEN the Linux-only apps are left out of the categories, and the Linux
#      desktops category, which has none left, isn't shown
test_app_menu_on_macos_leaves_out_linux_apps() {
  fake_os Darwin
  run_setup "1\n2\n3\n1\n"
  assert_status 0
  assert_contains "Which app do you want to theme?
  1) Web browsers (4 apps)
  2) Communication (3 apps)
  3) Editors: code, text and notes (13 apps)
  4) Terminals and command-line tools (3 apps)
  5) Entertainment (3 apps)
  6) Insomnia (API client)
  7) Search for an app by name
  0) Back"
  assert_contains "Your Slack theme string"
  assert_not_contains "Linux desktops"
}

# GIVEN a Linux system
# WHEN opening each category from the app menu, then going back
# THEN each lists its apps, alphabetically, with a way back, and Back
#      returns to the app menu each time
test_each_category_lists_its_apps() {
  fake_os Linux
  run_setup "1\n1\n0\n2\n0\n3\n0\n4\n0\n5\n0\n6\n0\n7\n1\n"
  assert_status 0
  assert_contains "Communication:
  1) Element (Matrix chat)
  2) Mattermost
  3) Slack
  0) Back"
  assert_contains "Web browsers:
  1) Chromium browsers (Chrome, Brave, Edge, Opera and more)
  2) Firefox
  3) Vivaldi
  4) Zen Browser
  0) Back"
  assert_contains "Editors: code, text and notes:
  1) Emacs
  2) GNOME text editors: gedit, GNOME Text Editor and Xed (and Pluma, Meld and more)
  3) Godot
  4) JetBrains Apps (IntelliJ IDEA, Android Studio, PyCharm, WebStorm and more)
  5) LibreOffice (Writer, Calc, Impress and more)
  6) Obsidian
  7) Qt Creator
  8) RStudio
  9) Spyder
  10) Sublime Text
  11) Unreal Engine
  12) Vim / Neovim
  13) VS Code
  0) Back"
  assert_contains "Terminals and command-line tools:
  1) fzf (fuzzy finder)
  2) Ptyxis (Ubuntu terminal)
  3) Tilix (terminal)
  4) tmux
  5) zsh (syntax highlighting and suggestions)
  0) Back"
  assert_contains "Linux desktops:
  1) Decky Loader (Steam's Gaming Mode on SteamOS, Bazzite, CachyOS and more)
  2) GTK3 apps (GIMP, Inkscape, Thunar, GParted and more)
  3) KDE Plasma (Plasma and KDE apps, Konsole, Kate)
  0) Back"
  assert_contains "Entertainment:
  1) Jellyfin (media server)
  2) mpv (media player)
  3) OBS Studio (streaming and recording)
  0) Back"
  count="$(printf '%s\n' "$OUTPUT" | grep -c '^Which app do you want to theme?$')"
  [ "$count" -eq 7 ] || fail "expected the app menu 7 times (once, then after each Back), got $count"
}

# GIVEN a category open
# WHEN choosing an app from it
# THEN that app is installed
test_choosing_an_app_from_a_category() {
  fake_os Linux
  run_setup "1\n4\n4\n1\n"
  assert_status 0
  assert_contains "Installing the tmux colors"
}

# GIVEN the app menu
# WHEN typing part of a name instead of a number
# THEN it lists the apps whose name, or category, match (case doesn't
#      matter), and one can be chosen from them
test_typing_a_name_searches() {
  fake_os Linux
  run_setup "1\nCOMMAND-LINE\n4\n1\n"
  assert_status 0
  assert_contains 'Apps matching "COMMAND-LINE":
  1) fzf (fuzzy finder)
  2) Ptyxis (Ubuntu terminal)
  3) Tilix (terminal)
  4) tmux
  5) zsh (syntax highlighting and suggestions)
     Covers: zsh-syntax-highlighting, fast-syntax-highlighting,
     zsh-autosuggestions
  0) Back'
  assert_contains "Installing the tmux colors"
}

# GIVEN the app menu
# WHEN searching for apps a theme covers but its menu name doesn't list:
#      RustRover, Dolphin and Brave
# THEN each finds the theme that covers it (JetBrains, KDE Plasma and
#      Chromium browsers), with the full list of apps it covers under it,
#      wrapped and lined up with its name
test_search_finds_apps_a_theme_covers() {
  fake_os Linux
  run_setup "1\nrustrover\n0\ndolphin\n0\nbrave\n1\n1\n"
  assert_status 0
  assert_contains 'Apps matching "rustrover":
  1) JetBrains Apps (IntelliJ IDEA, Android Studio, PyCharm, WebStorm and more)
     Covers: IntelliJ IDEA, Android Studio, PyCharm, WebStorm, PhpStorm,
     GoLand, RubyMine, CLion, Rider, DataGrip, DataSpell, RustRover
  0) Back'
  assert_contains 'Apps matching "dolphin":
  1) KDE Plasma (Plasma and KDE apps, Konsole, Kate)
     Covers: Dolphin, Kate, KWrite, Okular, Konsole, System Settings
  0) Back'
  assert_contains 'Apps matching "brave":
  1) Chromium browsers (Chrome, Brave, Edge, Opera and more)
     Covers: Google Chrome, Chromium, Brave, Microsoft Edge, Opera
  0) Back'
}

# GIVEN the app menu and a category
# WHEN they're shown
# THEN they don't list the apps each theme covers (only search results do)
test_menus_leave_out_the_covered_apps() {
  fake_os Linux
  run_setup "1\n2\n0\nslack\n1\n1\n"
  assert_status 0
  assert_not_contains "Covers:"
}

# GIVEN the JetBrains theme's README, which lists the IDEs it supports
# WHEN searching for each of them
# THEN every one finds the JetBrains theme
test_search_finds_every_jetbrains_ide() {
  fake_os Linux
  ides="$(sed -n '/^Themes for the JetBrains apps/,/^(Not Fleet/s/^- //p' "$SANDBOX/repo/app-themes/jetbrains-theme/README.md")"
  [ -n "$ides" ] || fail "expected the README to list the IDEs"
  answers="1\n"
  while IFS= read -r ide; do answers="$answers$ide\n0\n"; done <<<"$ides"
  run_setup "${answers}slack\n1\n1\n"
  assert_status 0
  while IFS= read -r ide; do
    assert_contains "Apps matching \"$ide\":
  1) JetBrains Apps"
  done <<<"$ides"
  # The Covers list shown in search results names them all too.
  covers="$(printf '%s\n' "$OUTPUT" | sed -n '/^Apps matching "RustRover":$/,/^  0) Back$/p' | sed -n '/Covers:/,/0) Back/p' | tr '\n' ' ')"
  while IFS= read -r ide; do
    case "$covers" in *"$ide"*) ;; *) fail "expected the Covers list to name $ide" ;; esac
  done <<<"$ides"
}

# GIVEN an app two themes cover: gedit, whose text area the GNOME text
#       editors theme colors and whose window the GTK3 theme colors
# WHEN searching for it
# THEN both are listed
test_search_lists_every_theme_for_an_app() {
  fake_os Linux
  run_setup "1\ngedit\n0\nslack\n1\n1\n"
  assert_status 0
  assert_contains 'Apps matching "gedit":
  1) GNOME text editors: gedit, GNOME Text Editor and Xed (and Pluma, Meld and more)
     Covers: gedit, GNOME Text Editor, Xed, Pluma, Meld
  2) GTK3 apps (GIMP, Inkscape, Thunar, GParted and more)
     Covers: GIMP, Inkscape, Shotwell, Thunar, Nemo, Caja, gedit,'
}

# GIVEN the app menu
# WHEN choosing "Search for an app by name" and typing a name
# THEN it lists the matching apps
test_search_option_asks_for_a_name() {
  fake_os Linux
  run_setup "1\n8\nfire\n1\n1\n"
  assert_status 0
  assert_contains "Type part of an app's name (or press Enter to go back): "
  assert_contains 'Apps matching "fire":
  1) Firefox
  0) Back'
}

# GIVEN the app menu
# WHEN searching for something no app matches, then for Slack
# THEN it says nothing matches and shows the app menu again, where the next
#      search works
test_search_with_no_matches_returns_to_the_app_menu() {
  fake_os Linux
  run_setup "1\nnotepad\nslack\n1\n1\n"
  assert_status 0
  assert_contains 'No app matches "notepad".'
  assert_contains "Your Slack theme string"
}

# GIVEN the app menu
# WHEN choosing Back
# THEN it returns to the first question, where installing starts over
test_back_from_the_app_menu_returns_to_the_first_question() {
  fake_os Linux
  run_setup "1\n0\n1\nslack\n1\n1\n"
  assert_status 0
  count="$(printf '%s\n' "$OUTPUT" | grep -c '^What would you like to do?$')"
  [ "$count" -eq 2 ] || fail "expected the first question twice, got $count"
  assert_contains "Your Slack theme string"
}

# GIVEN an app chosen from a category
# WHEN choosing Back at the theme menu
# THEN it returns to that category, where another app can be chosen
test_back_from_the_theme_menu_returns_to_the_category() {
  fake_os Linux
  run_setup "1\n1\n2\n0\n1\n1\n"
  assert_status 0
  count="$(printf '%s\n' "$OUTPUT" | grep -c '^Web browsers:$')"
  [ "$count" -eq 2 ] || fail "expected the browsers category twice, got $count"
  assert_contains "chrome://extensions"
  assert_not_contains "about:debugging"
}

# GIVEN the palettes in palettes/
# WHEN choosing an app
# THEN the theme menu lists every palette by name
test_theme_menu_lists_every_palette() {
  run_setup "1\nslack\n1\n1\n"
  for file in "$SANDBOX"/repo/palettes/*-palette.toml; do
    assert_contains ") $(palette_name "$file")"
  done
}

# GIVEN a new Forest palette in palettes/
# WHEN choosing an app
# THEN the theme menu lists Forest
test_theme_menu_lists_a_new_palette() {
  sed -e 's/^name = .*/name = "Forest"/' -e 's/^slug = .*/slug = "forest"/' \
    "$SANDBOX/repo/palettes/sunset-palette.toml" \
    >"$SANDBOX/repo/palettes/forest-palette.toml"
  run_setup "1\nslack\n1\n1\n"
  assert_contains ") Forest"
}

# GIVEN a Forest palette whose name and slug use TOML's single quotes
# WHEN choosing Slack and Forest
# THEN Forest is listed by name and generated
test_theme_menu_reads_single_quoted_names() {
  sed -e "s/^name = .*/name = 'Forest'/" -e "s/^slug = .*/slug = 'forest'/" \
    "$SANDBOX/repo/palettes/sunset-palette.toml" >"$SANDBOX/repo/palettes/forest-palette.toml"
  run_setup "1\nslack\n1\n2\n"
  assert_status 0
  assert_contains "2) Forest"
  assert_contains "Generated Forest (forest)"
}

# GIVEN no Python 3.11 or later, and a palette whose name uses single quotes
# WHEN setup.sh shows the theme menu
# THEN the palette is still listed by name
test_theme_menu_without_python_reads_single_quoted_names() {
  fake_no_python
  sed -e "s/^name = .*/name = 'Forest'/" -e "s/^slug = .*/slug = 'forest'/" \
    "$SANDBOX/repo/palettes/sunset-palette.toml" >"$SANDBOX/repo/palettes/forest-palette.toml"
  run_setup "1\nslack\n1\n1\n"
  assert_contains "2) Forest"
}

# GIVEN a palette in palettes/ that isn't valid TOML
# WHEN choosing an app
# THEN it stops before the theme menu, naming the broken palette
test_theme_menu_stops_on_an_unreadable_palette() {
  printf 'name = "Broken\n' >"$SANDBOX/repo/palettes/broken-palette.toml"
  run_setup "1\nslack\n1\n1\n"
  assert_status 1
  assert_contains "broken-palette.toml: not a valid palette file"
  assert_contains "fix the palette named above"
  assert_not_contains "Which theme"
}

# GIVEN answers that are empty or out of range at the app menu, and empty,
#       not numbers or out of range at the theme menu
# WHEN they're typed
# THEN each one asks again, and valid answers then carry on
test_invalid_choices_ask_again() {
  run_setup "1\n\n99\nslack\n1\n\nabc\n99\n-1\n1\n"
  assert_status 0
  count="$(printf '%s\n' "$OUTPUT" | grep -c 'Please enter a number between 0 and')"
  [ "$count" -eq 6 ] || fail "expected 6 re-prompts, got $count"
  assert_contains "Your Slack theme string"
}

# GIVEN no input at all
# WHEN setup.sh asks what to do
# THEN it exits with status 1, saying no choice was made
test_no_answer_exits_with_error() {
  run_setup ""
  assert_status 1
  assert_contains "no choice made"
}

# --- Tests: the first menu --------------------------------------------------

# Replaces the sandbox's serve.py with a stub that records its folder and
# arguments in $SANDBOX/serve-ran, then exits.
stub_palette_creator() {
  cat >"$SANDBOX/repo/palette-creator/serve.py" <<EOF
import os, sys
with open("$SANDBOX/serve-ran", "w") as f:
    f.write(os.getcwd() + "|" + " ".join(sys.argv[1:]))
print("stub server running")
EOF
}

# GIVEN setup.sh starting
# WHEN it shows its first menu
# THEN it offers installing a theme or designing a palette, and choosing to
#      install goes on to the app menu
test_first_menu_offers_installing_or_designing() {
  run_setup "1\nslack\n1\n1\n"
  assert_status 0
  assert_contains "What would you like to do?"
  assert_contains "1) Install a theme for an app"
  assert_contains "2) Design a new palette (opens the Palette Creator)"
  assert_contains "Which app do you want to theme?"
}

# GIVEN an answer that isn't one of the first menu's choices
# WHEN it's typed at the first menu
# THEN it asks again
test_first_menu_asks_again_for_an_invalid_choice() {
  run_setup "3\n1\nslack\n1\n1\n"
  assert_status 0
  assert_contains "Please enter a number between 1 and 2."
}

# GIVEN setup.sh run from a folder other than the repository
# WHEN choosing to design a palette
# THEN it explains how to use the Palette Creator, then runs serve.py from
#      the repository, without going on to the app menu
test_palette_creator_choice_starts_the_server() {
  stub_palette_creator
  run_setup "2\n"
  assert_status 0
  assert_contains "Starting the Palette Creator"
  assert_contains '"Save as palette..." opens a save'
  assert_contains "press Ctrl+C here to stop it"
  assert_contains "stub server running"
  assert_not_contains "Which app"
  assert_file_equals "$SANDBOX/serve-ran" "$SANDBOX/repo|"
}

# GIVEN no Python 3.11 or later
# WHEN choosing to design a palette
# THEN it exits with status 1, saying the Palette Creator needs Python, and
#      doesn't try to start it
test_palette_creator_needs_python() {
  stub_palette_creator
  fake_no_python
  run_setup "2\n"
  assert_status 1
  assert_contains "the Palette Creator needs Python 3.11 or later"
  assert_missing "$SANDBOX/serve-ran"
}

# --- Tests: generating -------------------------------------------------------

# GIVEN Python 3.11 or later
# WHEN choosing Slack and Sunset
# THEN Sunset's themes are generated and added to package.json
test_generates_the_chosen_palette() {
  run_setup "1\nslack\n1\n2\n"
  assert_status 0
  assert_contains "Generated Sunset (sunset)"
  assert_exists "$SANDBOX/repo/app-themes/slack-theme/sunset.txt"
  assert_exists "$SANDBOX/repo/app-themes/ptyxis-theme/sunset.palette"
  assert_exists "$SANDBOX/repo/app-themes/vs-code-theme/themes/jenerated-sunset-color-theme.json"
  grep -q '"Jenerated Sunset"' "$SANDBOX/repo/app-themes/vs-code-theme/package.json" ||
    fail "expected package.json to list Jenerated Sunset"
}

# GIVEN no Python 3.11 or later
# WHEN choosing Slack and Blue Purple
# THEN it succeeds using the committed Blue Purple files
test_blue_purple_works_without_python() {
  fake_no_python
  run_setup "1\nslack\n1\n1\n"
  assert_status 0
  assert_contains "Python 3.11+ not found"
  assert_contains "$(tr -d '\n' <"$SANDBOX/repo/app-themes/slack-theme/blue-purple.txt")"
}

# GIVEN no Python 3.11 or later
# WHEN choosing Slack and Sunset
# THEN it exits with status 1, saying generating Sunset needs Python
test_other_palettes_need_python() {
  fake_no_python
  run_setup "1\nslack\n1\n2\n"
  assert_status 1
  assert_contains "generating Sunset needs Python 3.11 or later"
}

# GIVEN a palette with a color that isn't valid (so it's listed, but can't be
#       generated)
# WHEN choosing Tilix and that palette
# THEN it stops with jenerate.py's error and installs nothing
test_choosing_a_broken_palette_stops_with_its_error() {
  fake_os Linux
  sed -e 's/^name = .*/name = "Bad"/' -e 's/^slug = .*/slug = "bad"/' \
    "$SANDBOX/repo/palettes/sunset-palette.toml" >"$SANDBOX/repo/palettes/bad-palette.toml"
  printf 'mystery = "blue-purple"\n' >>"$SANDBOX/repo/palettes/bad-palette.toml"
  run_setup "1\ntilix\n1\n1\ny\n1\n"
  assert_status 1
  assert_contains "1) Bad"
  assert_contains "color \`mystery\` = 'blue-purple' is not a #rrggbb value"
  assert_not_contains "Done!"
  assert_missing "$SANDBOX/home/.config/tilix/schemes/jenerated-bad.json"
}

# GIVEN the repository is in a folder with a space in its path
# WHEN installing Sunset for Tilix, the VS Code extension, and Blue Purple for
#      Obsidian
# THEN everything is generated there and each link points at the right place
test_repo_in_a_folder_with_spaces() {
  fake_os Linux
  mkdir -p "$SANDBOX/My Projects" "$SANDBOX/Notes/.obsidian"
  mv "$SANDBOX/repo" "$SANDBOX/My Projects/repo"
  local repo="$SANDBOX/My Projects/repo"
  SETUP="$repo/setup.sh"
  run_setup "1\ntilix\n1\n2\ny\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/.config/tilix/schemes/jenerated-sunset.json" "$repo/app-themes/tilix-theme/sunset.json"
  assert_exists "$repo/app-themes/tilix-theme/sunset.json"
  run_setup "1\nvs code\n1\n1\ny\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/.vscode/extensions/jenerated-themes" "$repo/app-themes/vs-code-theme"
  run_setup "1\nobsidian\n1\n1\n$SANDBOX/Notes\ny\n1\n"
  assert_status 0
  assert_link "$SANDBOX/Notes/.obsidian/themes/Jenerated Blue Purple" "$repo/app-themes/obsidian-theme/blue-purple"
}

# --- Tests: VS Code ----------------------------------------------------------

# GIVEN no VS Code extension installed
# WHEN choosing VS Code and Blue Purple
# THEN the extension folder is linked into ~/.vscode/extensions, and it says
#      which theme to choose
test_vscode_links_the_extension() {
  run_setup "1\nvs code\n1\n1\ny\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/.vscode/extensions/jenerated-themes" "$SANDBOX/repo/app-themes/vs-code-theme"
  assert_contains 'Choose "Jenerated Blue Purple"'
}

# GIVEN the extension is already linked to this repository
# WHEN choosing VS Code again
# THEN it says it's already installed and doesn't offer to replace it
test_vscode_already_linked_is_left_alone() {
  mkdir -p "$SANDBOX/home/.vscode/extensions"
  ln -s "$SANDBOX/repo/app-themes/vs-code-theme" "$SANDBOX/home/.vscode/extensions/jenerated-themes"
  run_setup "1\nvs code\n1\n1\ny\n1\n"
  assert_status 0
  assert_contains "Already installed"
  assert_not_contains "Replace it"
}

# GIVEN an old copy of the extension folder
# WHEN choosing VS Code and answering yes to replacing it
# THEN the copy is replaced with a link
test_vscode_replaces_an_old_copy_when_asked() {
  mkdir -p "$SANDBOX/home/.vscode/extensions/jenerated-themes"
  run_setup "1\nvs code\n1\n1\ny\n1\ny\n"
  assert_status 0
  assert_contains "An older install exists"
  assert_link "$SANDBOX/home/.vscode/extensions/jenerated-themes" "$SANDBOX/repo/app-themes/vs-code-theme"
}

# GIVEN the extension linked to some other folder
# WHEN choosing VS Code and accepting the default answer
# THEN the link points at this repository, and the other folder is kept
test_vscode_replaces_a_link_to_another_folder() {
  mkdir -p "$SANDBOX/home/.vscode/extensions" "$SANDBOX/elsewhere"
  ln -s "$SANDBOX/elsewhere" "$SANDBOX/home/.vscode/extensions/jenerated-themes"
  run_setup "1\nvs code\n1\n1\ny\n1\n\n"
  assert_status 0
  assert_link "$SANDBOX/home/.vscode/extensions/jenerated-themes" "$SANDBOX/repo/app-themes/vs-code-theme"
  assert_exists "$SANDBOX/elsewhere"
}

# GIVEN an old copy of the extension folder
# WHEN choosing VS Code and answering no to replacing it
# THEN it exits with status 1 and the copy is untouched
test_vscode_keeps_an_old_copy_when_declined() {
  mkdir -p "$SANDBOX/home/.vscode/extensions/jenerated-themes"
  touch "$SANDBOX/home/.vscode/extensions/jenerated-themes/keep-me"
  run_setup "1\nvs code\n1\n1\ny\n1\nn\n"
  assert_status 1
  assert_contains "left the existing install alone"
  assert_exists "$SANDBOX/home/.vscode/extensions/jenerated-themes/keep-me"
}

# GIVEN a packaged (.vsix) copy of the extension is installed
# WHEN choosing VS Code
# THEN it warns about the packaged copy so the two don't clash
test_vscode_warns_about_a_packaged_copy() {
  mkdir -p "$SANDBOX/home/.vscode/extensions/local.jenerated-themes-1.0.0"
  run_setup "1\nvs code\n1\n1\ny\n1\n"
  assert_status 0
  assert_contains "you also have a packaged copy installed (local.jenerated-themes-1.0.0)"
}

# GIVEN VS Code's .obsolete file lists only this extension
# WHEN choosing VS Code and pressing Enter once VS Code is closed
# THEN the .obsolete file is deleted
test_vscode_removes_obsolete_file_with_only_this_extension() {
  mkdir -p "$SANDBOX/home/.vscode/extensions"
  printf '{"local.jenerated-themes-1.0.0":true}' >"$SANDBOX/home/.vscode/extensions/.obsolete"
  run_setup "1\nvs code\n1\n1\ny\n1\n\n"
  assert_status 0
  assert_contains "marked as uninstalled"
  assert_missing "$SANDBOX/home/.vscode/extensions/.obsolete"
}

# GIVEN VS Code's .obsolete file lists this extension between two others
# WHEN choosing VS Code and pressing Enter once VS Code is closed
# THEN only this extension's entry is removed
test_vscode_keeps_other_obsolete_entries() {
  mkdir -p "$SANDBOX/home/.vscode/extensions"
  printf '{"a.first-1.0.0":true,"local.jenerated-themes-1.0.0":true,"b.second-2.0.0":true}' \
    >"$SANDBOX/home/.vscode/extensions/.obsolete"
  run_setup "1\nvs code\n1\n1\ny\n1\n\n"
  assert_status 0
  assert_file_equals "$SANDBOX/home/.vscode/extensions/.obsolete" \
    '{"a.first-1.0.0":true,"b.second-2.0.0":true}'
}

# GIVEN VS Code's .obsolete file lists this extension
# WHEN choosing VS Code, but the input ends instead of pressing Enter
# THEN it stops without changing .obsolete, since VS Code may still be open
test_vscode_stops_if_input_ends_before_enter() {
  mkdir -p "$SANDBOX/home/.vscode/extensions"
  printf '{"local.jenerated-themes-1.0.0":true}' >"$SANDBOX/home/.vscode/extensions/.obsolete"
  run_setup "1\nvs code\n1\n1\ny\n1\n"
  assert_status 1
  assert_contains "stopped before changing VS Code's files"
  assert_file_equals "$SANDBOX/home/.vscode/extensions/.obsolete" '{"local.jenerated-themes-1.0.0":true}'
}

# GIVEN VS Code's .obsolete file lists only another extension
# WHEN choosing VS Code
# THEN it doesn't mention it and the file is unchanged
test_vscode_ignores_obsolete_file_without_this_extension() {
  mkdir -p "$SANDBOX/home/.vscode/extensions"
  printf '{"a.first-1.0.0":true}' >"$SANDBOX/home/.vscode/extensions/.obsolete"
  run_setup "1\nvs code\n1\n1\ny\n1\n"
  assert_status 0
  assert_not_contains "marked as uninstalled"
  assert_file_equals "$SANDBOX/home/.vscode/extensions/.obsolete" '{"a.first-1.0.0":true}'
}

# --- Tests: Ptyxis -----------------------------------------------------------

# GIVEN a Linux system
# WHEN choosing Ptyxis and Blue Purple
# THEN the palette is linked into Ptyxis's palettes folder, and it says which
#      palette to choose
test_ptyxis_links_the_palette() {
  fake_os Linux
  run_setup "1\nptyxis\n1\n1\ny\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/.local/share/org.gnome.Ptyxis/palettes/blue-purple.palette" \
    "$SANDBOX/repo/app-themes/ptyxis-theme/blue-purple.palette"
  assert_contains 'choose "Blue Purple"'
}

# GIVEN the Ptyxis palette is already linked
# WHEN choosing Ptyxis again
# THEN it succeeds and the link is still right
test_ptyxis_running_twice_is_fine() {
  fake_os Linux
  run_setup "1\nptyxis\n1\n1\ny\n1\n"
  run_setup "1\nptyxis\n1\n1\ny\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/.local/share/org.gnome.Ptyxis/palettes/blue-purple.palette" \
    "$SANDBOX/repo/app-themes/ptyxis-theme/blue-purple.palette"
}

# --- Tests: Tilix -----------------------------------------------------------

TILIX_SCHEMES=".config/tilix/schemes"

# GIVEN a Linux system
# WHEN choosing Tilix and Blue Purple
# THEN the scheme is linked into Tilix's schemes folder as
#      jenerated-blue-purple.json, and it says which scheme to choose
test_tilix_links_the_scheme() {
  fake_os Linux
  run_setup "1\ntilix\n1\n1\ny\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/$TILIX_SCHEMES/jenerated-blue-purple.json" \
    "$SANDBOX/repo/app-themes/tilix-theme/blue-purple.json"
  assert_contains 'choose "Jenerated Blue Purple"'
}

# GIVEN a Linux system
# WHEN choosing Tilix and Sunset
# THEN Sunset's scheme is generated and linked
test_tilix_links_a_generated_palette() {
  fake_os Linux
  run_setup "1\ntilix\n1\n2\ny\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/$TILIX_SCHEMES/jenerated-sunset.json" \
    "$SANDBOX/repo/app-themes/tilix-theme/sunset.json"
  assert_exists "$SANDBOX/repo/app-themes/tilix-theme/sunset.json"
}

# GIVEN a scheme of the user's own called blue-purple.json
# WHEN choosing Tilix and Blue Purple
# THEN their scheme is untouched
test_tilix_leaves_other_schemes_alone() {
  fake_os Linux
  mkdir -p "$SANDBOX/home/$TILIX_SCHEMES"
  echo mine >"$SANDBOX/home/$TILIX_SCHEMES/blue-purple.json"
  run_setup "1\ntilix\n1\n1\ny\n1\n"
  assert_status 0
  assert_file_equals "$SANDBOX/home/$TILIX_SCHEMES/blue-purple.json" "mine"
}

# GIVEN the Tilix scheme is already linked
# WHEN choosing Tilix again
# THEN it says it's already installed
test_tilix_already_linked_is_left_alone() {
  fake_os Linux
  run_setup "1\ntilix\n1\n1\ny\n1\n"
  run_setup "1\ntilix\n1\n1\ny\n1\n"
  assert_status 0
  assert_contains "Already installed"
}

# GIVEN a file already at jenerated-blue-purple.json
# WHEN choosing Tilix and answering no to replacing it
# THEN it exits with status 1 and the file is untouched
test_tilix_asks_before_replacing_a_file() {
  fake_os Linux
  mkdir -p "$SANDBOX/home/$TILIX_SCHEMES"
  echo old >"$SANDBOX/home/$TILIX_SCHEMES/jenerated-blue-purple.json"
  run_setup "1\ntilix\n1\n1\ny\n1\nn\n"
  assert_status 1
  assert_file_equals "$SANDBOX/home/$TILIX_SCHEMES/jenerated-blue-purple.json" "old"
}

# --- Tests: showing the install commands, then running them ------------------

# GIVEN a Linux system
# WHEN choosing Tilix and answering no to running the install commands
# THEN the link and copy commands are shown first, nothing is installed, and
#      the steps to turn the theme on follow the commands
test_install_commands_are_shown_and_can_be_declined() {
  fake_os Linux
  run_setup "1\ntilix\n1\n1\nn\n"
  assert_status 0
  assert_contains "==> To install the Tilix color scheme, run:
    mkdir -p \"\$HOME/$TILIX_SCHEMES\"
    ln -s \"$SANDBOX/repo/app-themes/tilix-theme/blue-purple.json\" \"\$HOME/$TILIX_SCHEMES/jenerated-blue-purple.json\"
Or, to copy the files instead of linking them:
    cp -R \"$SANDBOX/repo/app-themes/tilix-theme/blue-purple.json\" \"\$HOME/$TILIX_SCHEMES/jenerated-blue-purple.json\"

Run these for you? [Y/n]"
  assert_contains "==> Once you've run the commands above, to turn the color scheme on:"
  assert_not_contains "Link or copy the files?"
  assert_missing "$SANDBOX/home/$TILIX_SCHEMES"
}

# GIVEN a Linux system
# WHEN choosing Tilix, running the commands, and choosing to copy
# THEN the scheme is copied rather than linked, with a reminder to run
#      setup.sh again after changing the palette
test_install_can_copy_instead_of_linking() {
  fake_os Linux
  run_setup "1\ntilix\n1\n1\ny\n2\n"
  assert_status 0
  [ -f "$SANDBOX/home/$TILIX_SCHEMES/jenerated-blue-purple.json" ] &&
    [ ! -L "$SANDBOX/home/$TILIX_SCHEMES/jenerated-blue-purple.json" ] ||
    fail "expected a copy, not a link"
  assert_same_file "$SANDBOX/home/$TILIX_SCHEMES/jenerated-blue-purple.json" \
    "$SANDBOX/repo/app-themes/tilix-theme/blue-purple.json"
  assert_contains "The files are copies, so after changing the palette"
}

# --- Tests: Vim --------------------------------------------------------------

VIM_PACK=".vim/pack/jenerated/start/jenerated-themes"
NVIM_PACK=".local/share/nvim/site/pack/jenerated/start/jenerated-themes"

# vim_loads scheme -> fails unless the real Vim, with the sandbox's home,
# finds and loads the colorscheme. Skipped when Vim isn't installed.
vim_loads() {
  command -v vim >/dev/null 2>&1 || return 0
  rm -f "$SANDBOX/vim-result"
  HOME="$SANDBOX/home" vim -Nu NONE -i NONE -es \
    -c "try | colorscheme $1 | call writefile([g:colors_name], '$SANDBOX/vim-result') | catch | call writefile([v:exception], '$SANDBOX/vim-result') | endtry" \
    -c 'qa!' </dev/null >/dev/null 2>&1
  assert_file_equals "$SANDBOX/vim-result" "$1"
}

# GIVEN no Neovim config
# WHEN choosing Vim and Blue Purple
# THEN app-themes/vim-theme is linked as a Vim package, Vim can load the colorscheme,
#      and it says what to add to ~/.vimrc
test_vim_links_the_package() {
  run_setup "1\nneovim\n1\n1\ny\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/$VIM_PACK" "$SANDBOX/repo/app-themes/vim-theme"
  assert_contains "colorscheme jenerated-blue-purple"
  assert_contains "~/.vimrc"
  vim_loads jenerated-blue-purple
}

# GIVEN a Neovim config folder
# WHEN choosing Vim and Blue Purple
# THEN app-themes/vim-theme is also linked as a Neovim package, and it says what to add
#      to init.lua
test_vim_links_the_package_for_neovim() {
  mkdir -p "$SANDBOX/home/.config/nvim"
  run_setup "1\nneovim\n1\n1\ny\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/$NVIM_PACK" "$SANDBOX/repo/app-themes/vim-theme"
  assert_contains 'vim.cmd.colorscheme("jenerated-blue-purple")'
}

# GIVEN Vim was set up with Blue Purple
# WHEN choosing Vim and Sunset
# THEN the link is already there, and Sunset's newly generated colorscheme
#      loads through it too
test_vim_one_link_serves_every_palette() {
  run_setup "1\nneovim\n1\n1\ny\n1\n"
  run_setup "1\nneovim\n1\n2\ny\n1\n"
  assert_status 0
  assert_contains "Already installed"
  assert_exists "$SANDBOX/repo/app-themes/vim-theme/colors/jenerated-sunset.vim"
  vim_loads jenerated-sunset
}

# GIVEN an old copy of the colorschemes where the Vim package goes
# WHEN choosing Vim and answering no to replacing it
# THEN it exits with status 1 and the copy is untouched
test_vim_asks_before_replacing_a_copy() {
  mkdir -p "$SANDBOX/home/$VIM_PACK/colors"
  touch "$SANDBOX/home/$VIM_PACK/colors/keep-me.vim"
  run_setup "1\nneovim\n1\n1\ny\n1\nn\n"
  assert_status 1
  assert_exists "$SANDBOX/home/$VIM_PACK/colors/keep-me.vim"
}

# --- Tests: Firefox ----------------------------------------------------------

FIREFOX_DIR="app-themes/firefox-theme"

# xpi_manifest xpi expression -> prints a Python expression over the .xpi's
# manifest (as `m`), or its file list (as `names`).
xpi_manifest() {
  "$(find_python)" -c "
import json, sys, zipfile
z = zipfile.ZipFile(sys.argv[1])
names = z.namelist()
m = json.loads(z.read('manifest.json'))
print($2)
" "$1"
}

# wait_for file -> waits up to two seconds for a file (from a command setup.sh
# started in the background).
wait_for() {
  for _ in $(seq 40); do
    [ -e "$1" ] && return 0
    "$(find_python)" -c 'import time; time.sleep(0.05)'
  done
}

# GIVEN a Linux system
# WHEN choosing Firefox and Sunset, and not opening Firefox
# THEN Sunset's theme is packaged as an .xpi holding just its manifest, with
#      a date-based version, and it explains trying and keeping the theme
test_firefox_packages_the_theme() {
  fake_os Linux
  fake_command firefox "touch \"$SANDBOX/firefox-ran\""
  run_setup "1\nfirefox\n1\n2\nn\n"
  assert_status 0
  xpi="$SANDBOX/repo/$FIREFOX_DIR/jenerated-sunset.xpi"
  assert_exists "$xpi"
  [ "$(xpi_manifest "$xpi" 'names')" = "['manifest.json']" ] || fail "expected the .xpi to hold only manifest.json"
  [ "$(xpi_manifest "$xpi" 'm["name"], m["browser_specific_settings"]["gecko"]["id"]')" = \
    "Jenerated Sunset jenerated-sunset@jenerated-themes" ] || fail "unexpected .xpi name or id"
  version="$(xpi_manifest "$xpi" 'm["version"]')"
  printf '%s' "$version" | grep -Eq '^20[0-9]{2}\.[1-9][0-9]{2,3}\.(0|[1-9][0-9]{0,3})$' ||
    fail "expected a date-based version without leading zeros, got $version"
  assert_contains "$SANDBOX/repo/$FIREFOX_DIR/sunset/manifest.json"
  assert_contains "https://addons.mozilla.org/developers/addon/submit/distribution"
  assert_contains "upload $xpi"
  assert_missing "$SANDBOX/firefox-ran"
}

# GIVEN a Linux system with Firefox
# WHEN choosing Firefox and answering yes to opening it
# THEN Firefox is started on its add-on debugging page
test_firefox_opens_the_debugging_page() {
  fake_os Linux
  fake_command firefox "printf '%s' \"\$*\" >\"$SANDBOX/firefox-ran\""
  run_setup "1\nfirefox\n1\n1\ny\n"
  assert_status 0
  wait_for "$SANDBOX/firefox-ran"
  assert_file_equals "$SANDBOX/firefox-ran" "about:debugging#/runtime/this-firefox"
}

# GIVEN a Mac
# WHEN choosing Firefox and answering yes to opening it
# THEN it opens the page with `open -a Firefox`
test_firefox_on_macos_uses_open() {
  fake_os Darwin
  fake_command open "printf '%s' \"\$*\" >\"$SANDBOX/open-ran\""
  run_setup "1\nfirefox\n1\n1\ny\n"
  assert_status 0
  assert_file_equals "$SANDBOX/open-ran" "-a Firefox about:debugging#/runtime/this-firefox"
}

# GIVEN a Mac where Firefox can't be opened
# WHEN choosing Firefox and answering yes to opening it
# THEN it says so, and still explains how to load the theme
test_firefox_that_cant_be_found_is_explained() {
  fake_os Darwin
  fake_command open "exit 1"
  run_setup "1\nfirefox\n1\n1\ny\n"
  assert_status 0
  assert_contains "Couldn't find Firefox"
  assert_contains "Load Temporary Add-on"
}

# GIVEN no working python3
# WHEN choosing Firefox and Blue Purple
# THEN it can't package the theme, but still explains how to try it, without
#      the steps for keeping it
test_firefox_without_python_can_still_be_tried() {
  fake_os Linux
  fake_no_python
  run_setup "1\nfirefox\n1\n1\nn\n"
  assert_status 0
  assert_contains "Couldn't package it"
  assert_contains "$SANDBOX/repo/$FIREFOX_DIR/blue-purple/manifest.json"
  assert_not_contains "addons.mozilla.org"
  assert_missing "$SANDBOX/repo/$FIREFOX_DIR/jenerated-blue-purple.xpi"
}

# --- Tests: Vivaldi ----------------------------------------------------------

VIVALDI_DIR="app-themes/vivaldi-theme"

# GIVEN the Sunset palette
# WHEN choosing Vivaldi and Sunset
# THEN it's packaged as a .zip holding just its settings.json, as Vivaldi
#      imports it, and it explains how to import it
test_vivaldi_packages_the_theme() {
  run_setup "1\nvivaldi\n1\n2\n"
  assert_status 0
  theme_zip="$SANDBOX/repo/$VIVALDI_DIR/jenerated-sunset.zip"
  assert_exists "$theme_zip"
  result="$("$(find_python)" -c '
import json, sys, zipfile
z = zipfile.ZipFile(sys.argv[1])
s = json.loads(z.read("settings.json"))
print(z.namelist(), s["name"])
' "$theme_zip")"
  [ "$result" = "['settings.json'] Jenerated Sunset" ] ||
    fail "unexpected .zip contents: $result"
  assert_contains '"Import Theme..."'
  assert_contains "$theme_zip"
  assert_contains "within 30 seconds"
}

# GIVEN no working python3, but the zip command
# WHEN choosing Vivaldi and Blue Purple
# THEN it packages the theme with zip instead
test_vivaldi_packages_with_zip_without_python() {
  fake_no_python
  fake_command zip "printf '%s\n' \"\$@\" >\"$SANDBOX/zip-ran\""
  run_setup "1\nvivaldi\n1\n1\n"
  assert_status 0
  assert_file_contains "$SANDBOX/zip-ran" "$SANDBOX/repo/$VIVALDI_DIR/jenerated-blue-purple.zip"
  assert_file_contains "$SANDBOX/zip-ran" "-r"
}

# GIVEN neither python3 nor zip working
# WHEN choosing Vivaldi and Blue Purple
# THEN it exits with status 1, saying what's needed
test_vivaldi_without_a_way_to_zip() {
  fake_no_python
  fake_command zip "exit 1"
  run_setup "1\nvivaldi\n1\n1\n"
  assert_status 1
  assert_contains "couldn't make the .zip (that needs python3 or zip)"
}

# --- Tests: JetBrains apps ---------------------------------------------------

JETBRAINS_DIR="app-themes/jetbrains-theme"

# GIVEN the Sunset palette
# WHEN choosing JetBrains apps and Sunset
# THEN the theme is packaged as a plugin .jar holding its descriptor, UI theme
#      and editor scheme, each pointing at files in the .jar, and it explains
#      installing it from disk
test_jetbrains_packages_the_plugin() {
  run_setup "1\njetbrains\n1\n2\n"
  assert_status 0
  jar="$SANDBOX/repo/$JETBRAINS_DIR/jenerated-sunset.jar"
  assert_exists "$jar"
  result="$("$(find_python)" -c '
import json, sys, zipfile, xml.etree.ElementTree as ET
z = zipfile.ZipFile(sys.argv[1])
names = sorted(z.namelist())
plugin = ET.fromstring(z.read("META-INF/plugin.xml"))
theme_path = plugin.find("extensions/themeProvider").get("path").lstrip("/")
theme = json.loads(z.read(theme_path))
scheme_path = theme["editorScheme"].lstrip("/")
print(names, theme_path in names, scheme_path in names, theme["name"])
' "$jar")"
  [ "$result" = "['META-INF/plugin.xml', 'jenerated-sunset.theme.json', 'jenerated-sunset.xml'] True True Jenerated Sunset" ] ||
    fail "unexpected .jar contents: $result"
  assert_contains '"Install Plugin from Disk..."'
  assert_contains "IntelliJ IDEA, Android Studio, PyCharm, WebStorm, PhpStorm, GoLand,"
  assert_contains "$jar"
  assert_contains '"Jenerated Sunset" as the theme'
}

# GIVEN neither python3 nor zip working
# WHEN choosing JetBrains apps and Blue Purple
# THEN it exits with status 1, saying what's needed
test_jetbrains_without_a_way_to_zip() {
  fake_no_python
  fake_command zip "exit 1"
  run_setup "1\njetbrains\n1\n1\n"
  assert_status 1
  assert_contains "couldn't make the .jar (that needs python3 or zip)"
}

# --- Tests: GTK3 apps ---------------------------------------------------------

GTK3_THEMES=".local/share/themes"

# fake_gsettings current-theme -> fakes a working gsettings: `get` prints the
# theme, and `set` records its arguments in $SANDBOX/gsettings-set.
fake_gsettings() {
  fake_command gsettings "case \"\$1\" in
  get) echo \"'$1'\" ;;
  set) printf '%s\n' \"\$*\" >\"$SANDBOX/gsettings-set\" ;;
esac"
}

# GIVEN a Linux system without GNOME's settings tool
# WHEN choosing GTK3 apps and Blue Purple
# THEN the theme is linked into ~/.local/share/themes as Jenerated-blue-purple,
#      and it explains how to turn it on
test_gtk3_links_the_theme() {
  fake_os Linux
  run_setup "1\ngtk3\n1\n1\ny\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/$GTK3_THEMES/Jenerated-blue-purple" "$SANDBOX/repo/app-themes/gtk3-theme/blue-purple"
  assert_exists "$SANDBOX/home/$GTK3_THEMES/Jenerated-blue-purple/gtk-3.0/gtk.css"
  assert_contains "gsettings set org.gnome.desktop.interface gtk-theme Jenerated-blue-purple"
  assert_contains "GTK_THEME=Jenerated-blue-purple"
}

# GIVEN GNOME's settings tool, with Yaru-dark as the GTK3 theme
# WHEN choosing GTK3 apps and Sunset, and answering yes to switching
# THEN the GTK3 theme is set to Jenerated-sunset, and it says how to switch
#      back to Yaru-dark
test_gtk3_switches_the_theme_when_asked() {
  fake_os Linux
  fake_gsettings Yaru-dark
  run_setup "1\ngtk3\n1\n2\ny\n1\ny\n"
  assert_status 0
  assert_contains "Your GTK3 theme is 'Yaru-dark'."
  assert_file_equals "$SANDBOX/gsettings-set" "set org.gnome.desktop.interface gtk-theme Jenerated-sunset"
  assert_contains "gsettings set org.gnome.desktop.interface gtk-theme 'Yaru-dark'"
  assert_link "$SANDBOX/home/$GTK3_THEMES/Jenerated-sunset" "$SANDBOX/repo/app-themes/gtk3-theme/sunset"
}

# GIVEN GNOME's settings tool
# WHEN choosing GTK3 apps and answering no to switching
# THEN the theme is installed but the setting is left alone
test_gtk3_leaves_the_theme_setting_when_declined() {
  fake_os Linux
  fake_gsettings Yaru-dark
  run_setup "1\ngtk3\n1\n1\ny\n1\nn\n"
  assert_status 0
  assert_missing "$SANDBOX/gsettings-set"
  assert_link "$SANDBOX/home/$GTK3_THEMES/Jenerated-blue-purple" "$SANDBOX/repo/app-themes/gtk3-theme/blue-purple"
  assert_contains "Legacy Applications"
}

# --- Tests: Chromium browsers ------------------------------------------------

# GIVEN the Sunset palette
# WHEN choosing Chromium browsers and Sunset
# THEN Sunset's theme is generated, and it explains loading its folder as an
#      unpacked extension in each browser
test_chromium_explains_loading_the_theme() {
  run_setup "1\nchromium\n1\n2\n"
  assert_status 0
  folder="$SANDBOX/repo/app-themes/chromium-theme/sunset"
  assert_exists "$folder/manifest.json"
  assert_contains "The theme is ready in $folder"
  assert_contains "chrome://extensions"
  assert_contains "brave://extensions"
  assert_contains "edge://extensions"
  assert_contains '"Load unpacked"'
}

# GIVEN a browser's old cache of Blue Purple's theme in its folder
# WHEN choosing Chromium browsers and Blue Purple
# THEN the cache is deleted, so the browser uses the current colors
test_chromium_clears_an_old_theme_cache() {
  touch "$SANDBOX/repo/app-themes/chromium-theme/blue-purple/Cached Theme.pak"
  run_setup "1\nchromium\n1\n1\n"
  assert_status 0
  assert_missing "$SANDBOX/repo/app-themes/chromium-theme/blue-purple/Cached Theme.pak"
  assert_exists "$SANDBOX/repo/app-themes/chromium-theme/blue-purple/manifest.json"
}

# --- Tests: KDE Plasma -------------------------------------------------------

KDE_DATA=".local/share"

# fake_plasma current-scheme -> fakes a working plasma-apply-colorscheme:
# --list-schemes lists Breeze schemes with the given one current, and
# applying a scheme records it in $SANDBOX/plasma-applied.
fake_plasma() {
  fake_command plasma-apply-colorscheme "if [ \"\$1\" = --list-schemes ]; then
  echo 'You have the following color schemes on your system:'
  for s in BreezeClassic BreezeDark BreezeLight; do
    if [ \"\$s\" = '$1' ]; then echo \" * \$s (current color scheme)\"; else echo \" * \$s\"; fi
  done
else
  printf '%s' \"\$1\" >\"$SANDBOX/plasma-applied\"
fi"
}

# GIVEN a Linux system that isn't running Plasma
# WHEN choosing KDE Plasma and Blue Purple
# THEN the color scheme, Konsole colors and Kate theme are linked where KDE
#      looks for them, and it explains how to turn each on
test_kde_links_the_themes() {
  fake_os Linux
  run_setup "1\nkde plasma\n1\n1\n"
  assert_status 0
  folder="$SANDBOX/repo/app-themes/kde-theme/blue-purple"
  assert_link "$SANDBOX/home/$KDE_DATA/color-schemes/Jenerated-blue-purple.colors" "$folder/Jenerated-blue-purple.colors"
  assert_link "$SANDBOX/home/$KDE_DATA/konsole/Jenerated-blue-purple.colorscheme" "$folder/Jenerated-blue-purple.colorscheme"
  assert_link "$SANDBOX/home/$KDE_DATA/org.kde.syntax-highlighting/themes/Jenerated-blue-purple.theme" "$folder/Jenerated-blue-purple.theme"
  assert_contains "plasma-apply-colorscheme Jenerated-blue-purple"
  assert_contains "Edit Current Profile"
  assert_contains "Configure Kate"
  assert_not_contains "Switch Plasma"
}

# GIVEN Plasma, with Breeze Dark as the color scheme
# WHEN choosing KDE Plasma and Sunset, and answering yes to switching
# THEN Plasma is switched to Jenerated-sunset, and it says how to switch back
#      to Breeze Dark
test_kde_switches_the_color_scheme_when_asked() {
  fake_os Linux
  fake_plasma BreezeDark
  run_setup "1\nkde plasma\n1\n2\ny\n"
  assert_status 0
  assert_contains "Your Plasma color scheme is BreezeDark."
  assert_file_equals "$SANDBOX/plasma-applied" "Jenerated-sunset"
  assert_contains "To switch back: plasma-apply-colorscheme BreezeDark"
  assert_link "$SANDBOX/home/$KDE_DATA/color-schemes/Jenerated-sunset.colors" \
    "$SANDBOX/repo/app-themes/kde-theme/sunset/Jenerated-sunset.colors"
}

# GIVEN Plasma
# WHEN choosing KDE Plasma and answering no to switching
# THEN the themes are installed but the color scheme is left alone
test_kde_leaves_the_color_scheme_when_declined() {
  fake_os Linux
  fake_plasma BreezeDark
  run_setup "1\nkde plasma\n1\n1\nn\n"
  assert_status 0
  assert_missing "$SANDBOX/plasma-applied"
  assert_contains "System Settings -> Colors & Themes -> Colors"
  assert_exists "$SANDBOX/home/$KDE_DATA/color-schemes/Jenerated-blue-purple.colors"
}

# --- Tests: Decky Loader ----------------------------------------------------

# GIVEN a Linux system with Decky Loader installed (a ~/homebrew folder)
# WHEN choosing Decky Loader and Blue Purple
# THEN the theme folder is linked into ~/homebrew/themes, and it explains how
#      to turn it on in CSS Loader, without saying Decky is missing
test_decky_links_the_theme() {
  fake_os Linux
  mkdir -p "$SANDBOX/home/homebrew/plugins"
  run_setup "1\ndecky\n1\n1\ny\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/homebrew/themes/Jenerated-blue-purple" \
    "$SANDBOX/repo/app-themes/decky-theme/blue-purple"
  assert_contains "choose CSS Loader"
  assert_contains "Turn on \"Jenerated Blue Purple\"."
  assert_not_contains "Decky Loader isn't installed yet"
}

# GIVEN a Linux system without Decky Loader (no ~/homebrew folder)
# WHEN choosing Decky Loader and Sunset
# THEN it says Decky Loader isn't installed and where to get it, and links the
#      theme anyway, ready for when it is
test_decky_explains_when_decky_is_missing() {
  fake_os Linux
  run_setup "1\ndecky\n1\n2\ny\n1\n"
  assert_status 0
  assert_contains "Decky Loader isn't installed yet"
  assert_contains "https://decky.xyz"
  assert_link "$SANDBOX/home/homebrew/themes/Jenerated-sunset" \
    "$SANDBOX/repo/app-themes/decky-theme/sunset"
}

# --- Tests: Godot -----------------------------------------------------------

GODOT_CFG=".config/godot"

# godot_settings path -> writes a small Godot editor settings file with the
# default color preset, base color and script editor theme.
godot_settings() {
  mkdir -p "$(dirname "$1")"
  printf '%s\n' '[gd_resource type="EditorSettings" format=3]' '' '[resource]' \
    'interface/theme/color_preset = "Default"' \
    'interface/theme/base_color = Color(0.14, 0.14, 0.14, 1)' \
    'text_editor/theme/color_theme = "Default"' >"$1"
}

# GIVEN a Linux system where Godot has never been opened (no settings)
# WHEN choosing Godot and Blue Purple
# THEN the script editor theme is linked where Godot looks for it, and it
#      explains that Godot has to be opened first, with the settings to
#      change by hand
test_godot_links_the_theme_and_explains_before_first_run() {
  fake_os Linux
  fake_command pgrep "exit 1"
  run_setup "1\ngodot\n1\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/$GODOT_CFG/text_editor_themes/Jenerated-blue-purple.tet" \
    "$SANDBOX/repo/app-themes/godot-theme/blue-purple/Jenerated-blue-purple.tet"
  assert_contains "Godot hasn't been opened yet"
  assert_contains "Interface > Theme > Color Preset: Custom"
  assert_contains "Text Editor > Theme > Color Theme: Jenerated-blue-purple"
}

# GIVEN Godot's settings for 4.5 and 4.6, and Godot closed
# WHEN choosing Godot and Blue Purple, and answering yes to setting colors
# THEN the 4.6 settings are backed up, then get Blue Purple's settings (each
#      key once, replacing the old line or added), 4.5's are left alone, and
#      it says how to go back
test_godot_sets_the_editor_colors_when_asked() {
  fake_os Linux
  fake_command pgrep "exit 1"
  godot_settings "$SANDBOX/home/$GODOT_CFG/editor_settings-4.5.tres"
  godot_settings "$SANDBOX/home/$GODOT_CFG/editor_settings-4.6.tres"
  cp "$SANDBOX/home/$GODOT_CFG/editor_settings-4.6.tres" "$SANDBOX/original.tres"
  run_setup "1\ngodot\n1\n1\ny\n"
  assert_status 0
  settings="$SANDBOX/home/$GODOT_CFG/editor_settings-4.6.tres"
  assert_same_file "$settings.before-jenerated" "$SANDBOX/original.tres"
  while IFS= read -r line; do
    case "$line" in ";"* | "") continue ;; esac
    [ "$(grep -cxF -- "$line" "$settings")" = 1 ] || fail "expected one line '$line' in $settings"
  done <"$SANDBOX/repo/app-themes/godot-theme/blue-purple/editor-settings.cfg"
  assert_file_not_contains "$settings" "Color(0.14, 0.14, 0.14, 1)"
  assert_file_contains "$settings" "[resource]"
  assert_same_file "$SANDBOX/home/$GODOT_CFG/editor_settings-4.5.tres" "$SANDBOX/original.tres"
  assert_contains "Updated $settings"
  assert_contains "cp \"$settings.before-jenerated\" \"$settings\""
}

# GIVEN Godot's script editor theme already linked, but to an old copy
#       elsewhere
# WHEN choosing Godot and Blue Purple, and answering yes to replacing it and
#      then no to changing the settings
# THEN the link is replaced after asking (the question reads the answer
#      typed, not setup.sh's own list of folders)
test_godot_asks_before_replacing_an_old_link() {
  fake_os Linux
  fake_command pgrep "exit 1"
  godot_settings "$SANDBOX/home/$GODOT_CFG/editor_settings-4.6.tres"
  mkdir -p "$SANDBOX/home/$GODOT_CFG/text_editor_themes" "$SANDBOX/old"
  : >"$SANDBOX/old/Jenerated-blue-purple.tet"
  ln -s "$SANDBOX/old/Jenerated-blue-purple.tet" "$SANDBOX/home/$GODOT_CFG/text_editor_themes/Jenerated-blue-purple.tet"
  run_setup "1\ngodot\n1\n1\ny\nn\n"
  assert_status 0
  assert_contains "Replace it with a link to this folder?"
  assert_link "$SANDBOX/home/$GODOT_CFG/text_editor_themes/Jenerated-blue-purple.tet" \
    "$SANDBOX/repo/app-themes/godot-theme/blue-purple/Jenerated-blue-purple.tet"
}

# GIVEN Godot's settings, already set to Blue Purple by setup.sh
# WHEN choosing Godot and Sunset, and answering yes again
# THEN the settings get Sunset's, and the backup is still the settings from
#      before any palette
test_godot_keeps_the_first_backup() {
  fake_os Linux
  fake_command pgrep "exit 1"
  godot_settings "$SANDBOX/home/$GODOT_CFG/editor_settings-4.6.tres"
  cp "$SANDBOX/home/$GODOT_CFG/editor_settings-4.6.tres" "$SANDBOX/original.tres"
  run_setup "1\ngodot\n1\n1\ny\n"
  run_setup "1\ngodot\n1\n2\ny\n"
  assert_status 0
  settings="$SANDBOX/home/$GODOT_CFG/editor_settings-4.6.tres"
  assert_file_contains "$settings" 'text_editor/theme/color_theme = "Jenerated-sunset"'
  assert_file_not_contains "$settings" "Jenerated-blue-purple"
  assert_same_file "$settings.before-jenerated" "$SANDBOX/original.tres"
}

# GIVEN Godot's settings, and Godot closed
# WHEN choosing Godot and answering no to setting colors
# THEN the settings are left alone, with no backup, and the settings to
#      change by hand are shown
test_godot_leaves_the_settings_when_declined() {
  fake_os Linux
  fake_command pgrep "exit 1"
  godot_settings "$SANDBOX/home/$GODOT_CFG/editor_settings-4.6.tres"
  cp "$SANDBOX/home/$GODOT_CFG/editor_settings-4.6.tres" "$SANDBOX/original.tres"
  run_setup "1\ngodot\n1\n1\nn\n"
  assert_status 0
  assert_same_file "$SANDBOX/home/$GODOT_CFG/editor_settings-4.6.tres" "$SANDBOX/original.tres"
  assert_missing "$SANDBOX/home/$GODOT_CFG/editor_settings-4.6.tres.before-jenerated"
  assert_contains "Interface > Theme > Color Preset: Custom"
}

# GIVEN Godot's settings, and Godot running
# WHEN choosing Godot
# THEN it doesn't offer to change the settings (Godot would overwrite them
#      when it closes), says to close it first, and shows the settings to
#      change by hand
test_godot_waits_while_godot_is_open() {
  fake_os Linux
  fake_command pgrep "exit 0"
  godot_settings "$SANDBOX/home/$GODOT_CFG/editor_settings-4.6.tres"
  cp "$SANDBOX/home/$GODOT_CFG/editor_settings-4.6.tres" "$SANDBOX/original.tres"
  run_setup "1\ngodot\n1\n1\n"
  assert_status 0
  assert_contains "Godot is open"
  assert_not_contains "Set Godot's editor colors"
  assert_same_file "$SANDBOX/home/$GODOT_CFG/editor_settings-4.6.tres" "$SANDBOX/original.tres"
  assert_contains "Interface > Theme > Base Color:"
}

# GIVEN Godot installed through Flatpak, with its own settings, as well as
#       the usual settings folder
# WHEN choosing Godot and answering yes
# THEN the theme is linked into both, and both settings files are updated
test_godot_themes_the_flatpak_too() {
  fake_os Linux
  fake_command pgrep "exit 1"
  flatpak="$SANDBOX/home/.var/app/org.godotengine.Godot/config/godot"
  godot_settings "$flatpak/editor_settings-4.6.tres"
  godot_settings "$SANDBOX/home/$GODOT_CFG/editor_settings-4.6.tres"
  run_setup "1\ngodot\n1\n1\ny\n"
  assert_status 0
  for dir in "$SANDBOX/home/$GODOT_CFG" "$flatpak"; do
    assert_link "$dir/text_editor_themes/Jenerated-blue-purple.tet" \
      "$SANDBOX/repo/app-themes/godot-theme/blue-purple/Jenerated-blue-purple.tet"
    assert_file_contains "$dir/editor_settings-4.6.tres" 'text_editor/theme/color_theme = "Jenerated-blue-purple"'
  done
}

# GIVEN Godot settings named editor_settings-4.tres (before 4.3),
#       -4.9.tres and -4.10.tres
# WHEN choosing Godot and answering yes
# THEN the newest, 4.10's, is the one updated
test_godot_updates_the_newest_settings() {
  fake_os Linux
  fake_command pgrep "exit 1"
  for version in 4 4.9 4.10; do
    godot_settings "$SANDBOX/home/$GODOT_CFG/editor_settings-$version.tres"
  done
  run_setup "1\ngodot\n1\n1\ny\n"
  assert_status 0
  assert_file_contains "$SANDBOX/home/$GODOT_CFG/editor_settings-4.10.tres" "Jenerated-blue-purple"
  assert_file_not_contains "$SANDBOX/home/$GODOT_CFG/editor_settings-4.9.tres" "Jenerated"
  assert_file_not_contains "$SANDBOX/home/$GODOT_CFG/editor_settings-4.tres" "Jenerated"
}

# GIVEN a Mac with Godot's settings
# WHEN choosing Godot (also 9 on a Mac) and answering yes
# THEN the theme is linked into Godot's folder in Application Support, and
#      its settings are updated
test_godot_on_macos_uses_application_support() {
  fake_os Darwin
  fake_command pgrep "exit 1"
  dir="$SANDBOX/home/Library/Application Support/Godot"
  godot_settings "$dir/editor_settings-4.6.tres"
  run_setup "1\ngodot\n1\n1\ny\n"
  assert_status 0
  assert_link "$dir/text_editor_themes/Jenerated-blue-purple.tet" \
    "$SANDBOX/repo/app-themes/godot-theme/blue-purple/Jenerated-blue-purple.tet"
  assert_file_contains "$dir/editor_settings-4.6.tres" 'text_editor/theme/color_theme = "Jenerated-blue-purple"'
}

# --- Tests: Zen Browser -----------------------------------------------------

# zen_profile root name path... -> writes root/profiles.ini listing a profile
# for each "name path" pair (paths relative to root), and creates their
# folders.
zen_profile() {
  local root="$1" n=0
  shift
  mkdir -p "$root"
  : >"$root/profiles.ini"
  while [ $# -gt 1 ]; do
    printf '[Profile%d]\nName=%s\nIsRelative=1\nPath=%s\n\n' "$n" "$1" "$2" >>"$root/profiles.ini"
    mkdir -p "$root/$2"
    n=$((n + 1))
    shift 2
  done
  printf '[General]\nStartWithLastProfile=1\n' >>"$root/profiles.ini"
}

ZEN_ROOT=".zen"

# GIVEN a Linux system with one Zen profile and no custom stylesheets
# WHEN choosing Zen Browser and Blue Purple
# THEN the theme's stylesheets are linked into the profile's chrome folder,
#      userChrome.css and userContent.css are created to import them, custom
#      stylesheets are turned on in user.js, and it says to restart Zen
test_zen_installs_the_theme_into_the_profile() {
  fake_os Linux
  zen_profile "$SANDBOX/home/$ZEN_ROOT" "Default (release)" "abc.Default (release)"
  run_setup "1\nzen browser\n1\n1\n"
  assert_status 0
  profile="$SANDBOX/home/$ZEN_ROOT/abc.Default (release)"
  folder="$SANDBOX/repo/app-themes/zen-theme/blue-purple"
  assert_link "$profile/chrome/jenerated-userChrome.css" "$folder/userChrome.css"
  assert_link "$profile/chrome/jenerated-userContent.css" "$folder/userContent.css"
  assert_file_contains "$profile/chrome/userChrome.css" '@import "jenerated-userChrome.css";'
  assert_file_contains "$profile/chrome/userContent.css" '@import "jenerated-userContent.css";'
  assert_file_contains "$profile/user.js" 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);'
  assert_contains "Restart Zen"
}

# GIVEN a Zen profile with a userChrome.css of the user's own, and a user.js
#       whose last line has no line break
# WHEN choosing Zen Browser and answering yes to adding the theme
# THEN the import is added as the first line, the user's styles are kept
#      after it, and the setting goes on its own line in user.js
test_zen_adds_the_theme_to_an_existing_stylesheet() {
  fake_os Linux
  zen_profile "$SANDBOX/home/$ZEN_ROOT" "Default" "abc.default"
  profile="$SANDBOX/home/$ZEN_ROOT/abc.default"
  mkdir -p "$profile/chrome"
  printf '#nav-bar { opacity: 0.9; }\n' >"$profile/chrome/userChrome.css"
  printf 'user_pref("browser.startup.page", 3);' >"$profile/user.js"
  run_setup "1\nzen browser\n1\n1\ny\n"
  assert_status 0
  expected="$(printf '@import "jenerated-userChrome.css";\n#nav-bar { opacity: 0.9; }')"
  assert_file_equals "$profile/chrome/userChrome.css" "$expected"
  expected="$(printf 'user_pref("browser.startup.page", 3);\nuser_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);')"
  assert_file_equals "$profile/user.js" "$expected"
}

# GIVEN a Zen profile with a userChrome.css of the user's own
# WHEN choosing Zen Browser and answering no to adding the theme
# THEN the stylesheet is left alone, and it shows the line to add by hand
test_zen_leaves_an_existing_stylesheet_when_declined() {
  fake_os Linux
  zen_profile "$SANDBOX/home/$ZEN_ROOT" "Default" "abc.default"
  profile="$SANDBOX/home/$ZEN_ROOT/abc.default"
  mkdir -p "$profile/chrome"
  printf '#nav-bar { opacity: 0.9; }\n' >"$profile/chrome/userChrome.css"
  run_setup "1\nzen browser\n1\n1\nn\n"
  assert_status 0
  assert_file_equals "$profile/chrome/userChrome.css" "#nav-bar { opacity: 0.9; }"
  assert_contains '    @import "jenerated-userChrome.css";'
}

# GIVEN Zen with Blue Purple installed by setup.sh
# WHEN choosing Zen Browser and Sunset, and answering yes to replacing the
#      old links
# THEN the links point to Sunset, and neither the imports nor the setting
#      are added twice
test_zen_switching_palettes_adds_nothing_twice() {
  fake_os Linux
  zen_profile "$SANDBOX/home/$ZEN_ROOT" "Default" "abc.default"
  profile="$SANDBOX/home/$ZEN_ROOT/abc.default"
  run_setup "1\nzen browser\n1\n1\n"
  run_setup "1\nzen browser\n1\n2\ny\ny\n"
  assert_status 0
  assert_link "$profile/chrome/jenerated-userChrome.css" "$SANDBOX/repo/app-themes/zen-theme/sunset/userChrome.css"
  [ "$(grep -c jenerated-userChrome.css "$profile/chrome/userChrome.css")" = 1 ] || fail "expected one import in userChrome.css"
  [ "$(grep -c legacyUserProfileCustomizations "$profile/user.js")" = 1 ] || fail "expected the setting once in user.js"
}

# GIVEN two Zen profiles
# WHEN choosing Zen Browser and then the second profile
# THEN it lists both by name, and installs into the second one only
test_zen_asks_which_profile() {
  fake_os Linux
  zen_profile "$SANDBOX/home/$ZEN_ROOT" "Work" "aaa.work" "Personal" "bbb.personal"
  run_setup "1\nzen browser\n1\n1\n2\n"
  assert_status 0
  assert_contains "Which Zen profile?"
  assert_contains "1) Work ($SANDBOX/home/$ZEN_ROOT/aaa.work)"
  assert_contains "2) Personal ($SANDBOX/home/$ZEN_ROOT/bbb.personal)"
  assert_exists "$SANDBOX/home/$ZEN_ROOT/bbb.personal/chrome/jenerated-userChrome.css"
  assert_missing "$SANDBOX/home/$ZEN_ROOT/aaa.work/chrome"
}

# GIVEN Zen profiles in the XDG config folder and in the folder Flatpak
#       gives Zen (and none in ~/.zen)
# WHEN choosing Zen Browser
# THEN both are offered
test_zen_finds_xdg_and_flatpak_profiles() {
  fake_os Linux
  zen_profile "$SANDBOX/home/.config/zen" "Native" "n.default"
  zen_profile "$SANDBOX/home/.var/app/app.zen_browser.zen/.zen" "Flatpak" "f.default"
  run_setup "1\nzen browser\n1\n1\n2\n"
  assert_status 0
  assert_contains "Native ($SANDBOX/home/.config/zen/n.default)"
  assert_contains "Flatpak ($SANDBOX/home/.var/app/app.zen_browser.zen/.zen/f.default)"
  assert_exists "$SANDBOX/home/.var/app/app.zen_browser.zen/.zen/f.default/chrome/jenerated-userChrome.css"
}

# GIVEN a Mac with a Zen profile in Application Support
# WHEN choosing Zen Browser (also 10 on a Mac)
# THEN the theme is installed into that profile
test_zen_on_macos_uses_application_support() {
  fake_os Darwin
  zen_profile "$SANDBOX/home/Library/Application Support/zen" "Default" "Profiles/abc.default"
  run_setup "1\nzen browser\n1\n1\n"
  assert_status 0
  assert_exists "$SANDBOX/home/Library/Application Support/zen/Profiles/abc.default/chrome/jenerated-userChrome.css"
}

# GIVEN Zen has never been opened (no profiles)
# WHEN choosing Zen Browser
# THEN it says to open Zen once first, and installs nothing
test_zen_explains_when_there_is_no_profile() {
  fake_os Linux
  run_setup "1\nzen browser\n1\n1\n"
  assert_status 0
  assert_contains "Zen hasn't been opened yet"
  assert_missing "$SANDBOX/home/$ZEN_ROOT"
}

# --- Tests: GtkSourceView text editors --------------------------------------

# GIVEN a Linux system
# WHEN choosing the text editors and Blue Purple (a dark palette)
# THEN each GtkSourceView version's styles folder gets a link to its own
#      version of the scheme (3 and 4 share one), and it explains where each
#      editor's setting is, telling GNOME Text Editor users to pick its dark
#      style
test_gtksourceview_links_each_version() {
  fake_os Linux
  run_setup "1\ngnome text editors\n1\n1\ny\n1\n"
  assert_status 0
  data="$SANDBOX/home/.local/share"
  folder="$SANDBOX/repo/app-themes/gtksourceview-theme/blue-purple"
  file="jenerated-blue-purple.xml"
  assert_link "$data/gtksourceview-3.0/styles/$file" "$folder/gtksourceview-4/$file"
  assert_link "$data/gtksourceview-4/styles/$file" "$folder/gtksourceview-4/$file"
  assert_link "$data/gtksourceview-5/styles/$file" "$folder/gtksourceview-5/$file"
  assert_link "$data/libgedit-gtksourceview-300/styles/$file" "$folder/libgedit-gtksourceview-300/$file"
  assert_contains "gedit: Preferences -> Font & Colors."
  assert_contains "Xed: Edit -> Preferences -> Theme."
  assert_contains "choose the dark style first"
  assert_missing "$SANDBOX/home/.var"
}

# GIVEN a light palette
# WHEN choosing the text editors and it
# THEN it tells GNOME Text Editor users to pick its light style
test_gtksourceview_light_palette_says_light_style() {
  fake_os Linux
  sed -e 's/^name = .*/name = "Dawn"/' -e 's/^slug = .*/slug = "dawn"/' \
    -e 's/^bg = "#[0-9a-fA-F]*"/bg = "#fbfbfd"/' "$SANDBOX/repo/palettes/sunset-palette.toml" \
    >"$SANDBOX/repo/palettes/dawn-palette.toml"
  run_setup "1\ngnome text editors\n1\n2\ny\n1\n"
  assert_status 0
  assert_contains "Jenerated Dawn"
  assert_contains "choose the light style first"
}

# GIVEN GNOME Text Editor and gedit installed through Flatpak
# WHEN choosing the text editors
# THEN their own data folders get links too
test_gtksourceview_themes_the_flatpaks() {
  fake_os Linux
  mkdir -p "$SANDBOX/home/.var/app/org.gnome.TextEditor" "$SANDBOX/home/.var/app/org.gnome.gedit"
  run_setup "1\ngnome text editors\n1\n1\ny\n1\n"
  assert_status 0
  folder="$SANDBOX/repo/app-themes/gtksourceview-theme/blue-purple"
  assert_link "$SANDBOX/home/.var/app/org.gnome.TextEditor/data/gtksourceview-5/styles/jenerated-blue-purple.xml" \
    "$folder/gtksourceview-5/jenerated-blue-purple.xml"
  assert_link "$SANDBOX/home/.var/app/org.gnome.gedit/data/libgedit-gtksourceview-300/styles/jenerated-blue-purple.xml" \
    "$folder/libgedit-gtksourceview-300/jenerated-blue-purple.xml"
}

# --- Tests: fzf -------------------------------------------------------------

FZF_LINE='[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/fzf/jenerated-colors.sh" ] && . "${XDG_CONFIG_HOME:-$HOME/.config}/fzf/jenerated-colors.sh"'

# GIVEN a bash user whose ~/.bashrc sets FZF_DEFAULT_OPTS, and whose last
#       line has no line break
# WHEN choosing fzf and Blue Purple, and answering yes to loading the colors
# THEN the colors file is linked into ~/.config/fzf, ~/.bashrc loads it on a
#      line of its own, and a shell reading ~/.bashrc has the user's option
#      followed by Blue Purple's colors
test_fzf_loads_the_colors_from_bashrc() {
  fake_os Linux
  printf 'export FZF_DEFAULT_OPTS="--layout=reverse"' >"$SANDBOX/home/.bashrc"
  SHELL=/bin/bash run_setup "1\nfzf\n1\n1\ny\n"
  assert_status 0
  assert_link "$SANDBOX/home/.config/fzf/jenerated-colors.sh" \
    "$SANDBOX/repo/app-themes/fzf-theme/blue-purple/jenerated-blue-purple.sh"
  assert_file_contains "$SANDBOX/home/.bashrc" 'export FZF_DEFAULT_OPTS="--layout=reverse"'
  [ "$(grep -cxF -- "$FZF_LINE" "$SANDBOX/home/.bashrc")" = 1 ] || fail "expected ~/.bashrc to load the colors once"
  opts="$(HOME="$SANDBOX/home" XDG_CONFIG_HOME= bash -c '. ~/.bashrc; printf %s "$FZF_DEFAULT_OPTS"')"
  case "$opts" in
    "--layout=reverse --color=fg:"*) ;;
    *) fail "expected the user's option, then the colors, got: $opts" ;;
  esac
  assert_contains "Open a new terminal"
}

# GIVEN a zsh user with no ~/.zshrc yet
# WHEN choosing fzf and answering yes
# THEN ~/.zshrc is created, loading the colors
test_fzf_creates_zshrc_for_a_zsh_user() {
  fake_os Linux
  SHELL=/usr/bin/zsh run_setup "1\nfzf\n1\n1\ny\n"
  assert_status 0
  assert_file_contains "$SANDBOX/home/.zshrc" "$FZF_LINE"
}

# GIVEN fzf set up with Blue Purple, loaded from ~/.bashrc
# WHEN choosing fzf and Sunset, and answering yes to replacing the link
# THEN the link points to Sunset's colors, and ~/.bashrc isn't changed again
test_fzf_switching_palettes_repoints_the_link() {
  fake_os Linux
  : >"$SANDBOX/home/.bashrc"
  SHELL=/bin/bash run_setup "1\nfzf\n1\n1\ny\n"
  cp "$SANDBOX/home/.bashrc" "$SANDBOX/bashrc-before"
  SHELL=/bin/bash run_setup "1\nfzf\n1\n2\ny\n"
  assert_status 0
  assert_link "$SANDBOX/home/.config/fzf/jenerated-colors.sh" \
    "$SANDBOX/repo/app-themes/fzf-theme/sunset/jenerated-sunset.sh"
  assert_same_file "$SANDBOX/home/.bashrc" "$SANDBOX/bashrc-before"
  assert_not_contains "Load the colors in"
}

# GIVEN a fish user (a ~/.config/fish folder, and no bash or zsh files)
# WHEN choosing fzf
# THEN the fish colors are linked into fish's conf.d, which fish loads by
#      itself, and no startup file is changed
test_fzf_links_the_fish_colors() {
  fake_os Linux
  mkdir -p "$SANDBOX/home/.config/fish"
  SHELL=/usr/bin/fish run_setup "1\nfzf\n1\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/.config/fish/conf.d/jenerated-fzf.fish" \
    "$SANDBOX/repo/app-themes/fzf-theme/blue-purple/jenerated-blue-purple.fish"
  assert_missing "$SANDBOX/home/.bashrc"
  assert_missing "$SANDBOX/home/.zshrc"
  assert_contains "Open a new terminal"
}

# GIVEN a bash user, without fish
# WHEN choosing fzf and answering no to loading the colors
# THEN ~/.bashrc is left alone, and it shows the line to add by hand
test_fzf_shows_the_line_when_declined() {
  command -v fish >/dev/null 2>&1 && return 0  # fish would load the colors itself
  fake_os Linux
  printf '# my bashrc\n' >"$SANDBOX/home/.bashrc"
  SHELL=/bin/bash run_setup "1\nfzf\n1\n1\nn\n"
  assert_status 0
  assert_file_equals "$SANDBOX/home/.bashrc" "# my bashrc"
  assert_contains "add this line to your shell's startup file"
  assert_contains "    $FZF_LINE"
}

# --- Tests: mpv -------------------------------------------------------------

MPV_LINE='include="~~/jenerated-colors.conf"'

# GIVEN a system where mpv has no settings file yet
# WHEN choosing mpv and Blue Purple
# THEN the colors are linked into ~/.config/mpv, and mpv.conf is created to
#      include them
test_mpv_creates_mpv_conf() {
  fake_os Linux
  run_setup "1\nmpv\n1\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/.config/mpv/jenerated-colors.conf" \
    "$SANDBOX/repo/app-themes/mpv-theme/blue-purple/jenerated-blue-purple.conf"
  assert_file_contains "$SANDBOX/home/.config/mpv/mpv.conf" "$MPV_LINE"
  assert_contains "Restart mpv"
}

# GIVEN an mpv.conf of the user's own, whose last line has no line break
# WHEN choosing mpv and answering yes to loading the colors
# THEN the include goes at the end, on a line of its own, after the user's
#      settings
test_mpv_adds_the_colors_to_an_existing_mpv_conf() {
  fake_os Linux
  mkdir -p "$SANDBOX/home/.config/mpv"
  printf 'volume=70' >"$SANDBOX/home/.config/mpv/mpv.conf"
  run_setup "1\nmpv\n1\n1\ny\n"
  assert_status 0
  expected="$(printf 'volume=70\n# Colors from Jenerated Themes\n%s' "$MPV_LINE")"
  assert_file_equals "$SANDBOX/home/.config/mpv/mpv.conf" "$expected"
}

# GIVEN an mpv.conf of the user's own
# WHEN choosing mpv and answering no to loading the colors
# THEN mpv.conf is left alone, and it shows the line to add by hand
test_mpv_leaves_mpv_conf_when_declined() {
  fake_os Linux
  mkdir -p "$SANDBOX/home/.config/mpv"
  printf 'volume=70\n' >"$SANDBOX/home/.config/mpv/mpv.conf"
  run_setup "1\nmpv\n1\n1\nn\n"
  assert_status 0
  assert_file_equals "$SANDBOX/home/.config/mpv/mpv.conf" "volume=70"
  assert_contains "    $MPV_LINE"
}

# GIVEN mpv set up with Blue Purple
# WHEN choosing mpv and Sunset, and answering yes to replacing the link
# THEN the link points to Sunset's colors, and mpv.conf isn't changed again
test_mpv_switching_palettes_repoints_the_link() {
  fake_os Linux
  run_setup "1\nmpv\n1\n1\n"
  cp "$SANDBOX/home/.config/mpv/mpv.conf" "$SANDBOX/mpv-before.conf"
  run_setup "1\nmpv\n1\n2\ny\n"
  assert_status 0
  assert_link "$SANDBOX/home/.config/mpv/jenerated-colors.conf" \
    "$SANDBOX/repo/app-themes/mpv-theme/sunset/jenerated-sunset.conf"
  assert_same_file "$SANDBOX/home/.config/mpv/mpv.conf" "$SANDBOX/mpv-before.conf"
}

# GIVEN mpv installed through Flatpak, and on a Mac too
# WHEN choosing mpv
# THEN the Flatpak's settings folder gets the colors as well; and on a Mac
#      they go in ~/.config/mpv, where mpv looks there too
test_mpv_themes_the_flatpak_and_macos() {
  fake_os Linux
  mkdir -p "$SANDBOX/home/.var/app/io.mpv.Mpv"
  run_setup "1\nmpv\n1\n1\n"
  assert_status 0
  assert_file_contains "$SANDBOX/home/.var/app/io.mpv.Mpv/config/mpv/mpv.conf" "$MPV_LINE"
  assert_exists "$SANDBOX/home/.var/app/io.mpv.Mpv/config/mpv/jenerated-colors.conf"
  rm -rf "$SANDBOX/home/.config" "$SANDBOX/home/.var"
  fake_os Darwin
  run_setup "1\nmpv\n1\n1\n"
  assert_status 0
  assert_file_contains "$SANDBOX/home/.config/mpv/mpv.conf" "$MPV_LINE"
}

# --- Tests: tmux ------------------------------------------------------------

TMUX_LINE='source-file -q ~/.config/tmux/jenerated-colors.conf'

# fake_tmux running|stopped -> fakes tmux: list-sessions succeeds only when
# running, and source-file records the file it's given in $SANDBOX/tmux-sourced.
fake_tmux() {
  local status=1
  [ "$1" = running ] && status=0
  fake_command tmux "case \"\$1\" in
  list-sessions) exit $status ;;
  source-file) printf '%s' \"\$2\" >\"$SANDBOX/tmux-sourced\" ;;
esac"
}

# GIVEN no tmux settings file, and tmux not running
# WHEN choosing tmux and Blue Purple
# THEN the colors are linked into ~/.config/tmux, ~/.tmux.conf is created to
#      load them, and it says how to load them into a running tmux
test_tmux_creates_tmux_conf() {
  fake_os Linux
  fake_tmux stopped
  run_setup "1\ntmux\n1\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/.config/tmux/jenerated-colors.conf" \
    "$SANDBOX/repo/app-themes/tmux-theme/blue-purple/jenerated-blue-purple.conf"
  assert_file_contains "$SANDBOX/home/.tmux.conf" "$TMUX_LINE"
  assert_contains "the next time it starts"
  assert_contains "tmux source-file ~/.config/tmux/jenerated-colors.conf"
  assert_missing "$SANDBOX/tmux-sourced"
}

# GIVEN a tmux.conf in ~/.config/tmux (and no ~/.tmux.conf)
# WHEN choosing tmux and answering yes to loading the colors
# THEN that file loads them, and no ~/.tmux.conf is made (tmux would read it
#      instead)
test_tmux_uses_the_config_folder_file() {
  fake_os Linux
  fake_tmux stopped
  mkdir -p "$SANDBOX/home/.config/tmux"
  printf 'set -g mouse on\n' >"$SANDBOX/home/.config/tmux/tmux.conf"
  run_setup "1\ntmux\n1\n1\ny\n"
  assert_status 0
  expected="$(printf 'set -g mouse on\n# Colors from Jenerated Themes\n%s' "$TMUX_LINE")"
  assert_file_equals "$SANDBOX/home/.config/tmux/tmux.conf" "$expected"
  assert_missing "$SANDBOX/home/.tmux.conf"
}

# GIVEN a ~/.tmux.conf of the user's own
# WHEN choosing tmux and answering no to loading the colors
# THEN ~/.tmux.conf is left alone, and it shows the line to add by hand
test_tmux_leaves_tmux_conf_when_declined() {
  fake_os Linux
  fake_tmux stopped
  printf 'set -g mouse on\n' >"$SANDBOX/home/.tmux.conf"
  run_setup "1\ntmux\n1\n1\nn\n"
  assert_status 0
  assert_file_equals "$SANDBOX/home/.tmux.conf" "set -g mouse on"
  assert_contains "    $TMUX_LINE"
}

# GIVEN tmux running
# WHEN choosing tmux and answering yes to loading the colors into it
# THEN the running tmux is told to load the colors file
test_tmux_loads_the_colors_into_a_running_tmux() {
  fake_os Linux
  fake_tmux running
  run_setup "1\ntmux\n1\n1\ny\n"
  assert_status 0
  assert_file_equals "$SANDBOX/tmux-sourced" "$SANDBOX/home/.config/tmux/jenerated-colors.conf"
  assert_contains "tmux uses Jenerated Blue Purple now"
}

# GIVEN tmux set up with Blue Purple
# WHEN choosing tmux and Sunset, and answering yes to replacing the link
# THEN the link points to Sunset, and ~/.tmux.conf isn't changed again
test_tmux_switching_palettes_repoints_the_link() {
  fake_os Linux
  fake_tmux stopped
  run_setup "1\ntmux\n1\n1\n"
  cp "$SANDBOX/home/.tmux.conf" "$SANDBOX/tmux-before.conf"
  run_setup "1\ntmux\n1\n2\ny\n"
  assert_status 0
  assert_link "$SANDBOX/home/.config/tmux/jenerated-colors.conf" \
    "$SANDBOX/repo/app-themes/tmux-theme/sunset/jenerated-sunset.conf"
  assert_same_file "$SANDBOX/home/.tmux.conf" "$SANDBOX/tmux-before.conf"
}

# --- Tests: zsh -------------------------------------------------------------

ZSH_LINE='[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/jenerated-colors.zsh" ] && source "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/jenerated-colors.zsh"'

# fake_zsh with|without -> fakes zsh, as if ~/.zshrc loaded
# fast-syntax-highlighting or not: with it, running fast-theme prints the
# marker setup.sh looks for. Records the command it's given in
# $SANDBOX/zsh-ran.
fake_zsh() {
  local marker=""
  [ "$1" = with ] && marker="echo JENERATED-FAST-THEME-DONE"
  fake_command zsh "printf '%s' \"\$2\" >\"$SANDBOX/zsh-ran\"
$marker"
}

# GIVEN no ~/.zshrc, and zsh without fast-syntax-highlighting
# WHEN choosing zsh and Blue Purple
# THEN the zsh colors and the fast-syntax-highlighting theme are linked into
#      ~/.config, ~/.zshrc is created to load the colors, and it says how to
#      switch fast-syntax-highlighting to the theme
test_zsh_creates_zshrc() {
  fake_os Linux
  fake_zsh without
  run_setup "1\nzsh\n1\n1\n"
  assert_status 0
  folder="$SANDBOX/repo/app-themes/zsh-theme/blue-purple"
  assert_link "$SANDBOX/home/.config/zsh/jenerated-colors.zsh" "$folder/jenerated-blue-purple.zsh"
  assert_link "$SANDBOX/home/.config/fsh/jenerated-colors.ini" "$folder/jenerated-blue-purple.ini"
  assert_file_contains "$SANDBOX/home/.zshrc" "$ZSH_LINE"
  assert_contains "    fast-theme XDG:jenerated-colors"
  assert_file_contains "$SANDBOX/zsh-ran" "fast-theme -q XDG:jenerated-colors"
}

# GIVEN a ~/.zshrc of the user's own, and zsh with fast-syntax-highlighting
# WHEN choosing zsh and answering yes to loading the colors
# THEN the line goes at the end of ~/.zshrc, and fast-syntax-highlighting is
#      switched to the theme
test_zsh_switches_fast_syntax_highlighting() {
  fake_os Linux
  fake_zsh with
  printf 'source ~/plugins/fast-syntax-highlighting.plugin.zsh\n' >"$SANDBOX/home/.zshrc"
  run_setup "1\nzsh\n1\n1\ny\n"
  assert_status 0
  expected="$(printf 'source ~/plugins/fast-syntax-highlighting.plugin.zsh\n# Colors from Jenerated Themes\n%s' "$ZSH_LINE")"
  assert_file_equals "$SANDBOX/home/.zshrc" "$expected"
  assert_contains "Switched fast-syntax-highlighting to Jenerated Blue Purple."
  assert_not_contains "If you use fast-syntax-highlighting"
}

# GIVEN a ~/.zshrc of the user's own
# WHEN choosing zsh and answering no to loading the colors
# THEN ~/.zshrc is left alone, and it shows the line to add by hand
test_zsh_leaves_zshrc_when_declined() {
  fake_os Linux
  fake_zsh without
  printf 'setopt autocd\n' >"$SANDBOX/home/.zshrc"
  run_setup "1\nzsh\n1\n1\nn\n"
  assert_status 0
  assert_file_equals "$SANDBOX/home/.zshrc" "setopt autocd"
  assert_contains "    $ZSH_LINE"
}

# GIVEN ZDOTDIR set to another folder, where zsh keeps its .zshrc
# WHEN choosing zsh
# THEN the .zshrc in that folder loads the colors, and no ~/.zshrc is made
test_zsh_uses_zdotdir() {
  fake_os Linux
  fake_zsh without
  mkdir -p "$SANDBOX/home/.config/zsh"
  TEST_ZDOTDIR="$SANDBOX/home/.config/zsh" run_setup "1\nzsh\n1\n1\n"
  assert_status 0
  assert_file_contains "$SANDBOX/home/.config/zsh/.zshrc" "$ZSH_LINE"
  assert_missing "$SANDBOX/home/.zshrc"
}

# --- Tests: Element ---------------------------------------------------------

# GIVEN Element Desktop without a config.json of its own
# WHEN choosing Element and Blue Purple
# THEN ~/.config/Element/config.json is created with Blue Purple's theme as
#      a custom theme, and it says to restart Element and choose the theme
test_element_creates_config_json() {
  fake_os Linux
  run_setup "1\nelement\n1\n1\n"
  assert_status 0
  result="$("$(find_python)" -c '
import json, sys
c = json.load(open(sys.argv[1]))
print([t["name"] for t in c["setting_defaults"]["custom_themes"]])
' "$SANDBOX/home/.config/Element/config.json")"
  [ "$result" = "['Jenerated Blue Purple']" ] || fail "expected just Blue Purple's theme, got $result"
  assert_missing "$SANDBOX/home/.config/Element/config.json.before-jenerated"
  assert_contains "Restart Element"
  assert_contains 'choose "Jenerated Blue Purple"'
}

# GIVEN an Element config.json with a homeserver, another setting, someone
#       else's custom theme, and a Jenerated theme from before
# WHEN choosing Element and Sunset
# THEN the file is backed up, and keeps the homeserver, the setting and the
#      other theme, with the old Jenerated theme replaced by Sunset's
test_element_keeps_the_rest_of_config_json() {
  fake_os Linux
  mkdir -p "$SANDBOX/home/.config/Element"
  printf '%s\n' '{"default_server_config": {"m.homeserver": {"base_url": "https://matrix.example.org"}},' \
    ' "setting_defaults": {"showHiddenEventsInTimeline": true, "custom_themes": [' \
    '  {"name": "Other Theme", "is_dark": true, "colors": {}},' \
    '  {"name": "Jenerated Blue Purple", "is_dark": true, "colors": {}}]}}' \
    >"$SANDBOX/home/.config/Element/config.json"
  cp "$SANDBOX/home/.config/Element/config.json" "$SANDBOX/original.json"
  run_setup "1\nelement\n1\n2\n"
  assert_status 0
  result="$("$(find_python)" -c '
import json, sys
c = json.load(open(sys.argv[1]))
d = c["setting_defaults"]
print(c["default_server_config"]["m.homeserver"]["base_url"], d["showHiddenEventsInTimeline"],
      [t["name"] for t in d["custom_themes"]])
' "$SANDBOX/home/.config/Element/config.json")"
  [ "$result" = "https://matrix.example.org True ['Other Theme', 'Jenerated Sunset']" ] || fail "got $result"
  assert_same_file "$SANDBOX/home/.config/Element/config.json.before-jenerated" "$SANDBOX/original.json"
}

# GIVEN an Element config.json that isn't valid JSON
# WHEN choosing Element
# THEN it stops, saying it couldn't update the file, and leaves it as it was
test_element_stops_on_a_broken_config_json() {
  fake_os Linux
  mkdir -p "$SANDBOX/home/.config/Element"
  printf '{"brand": "Element",\n' >"$SANDBOX/home/.config/Element/config.json"
  run_setup "1\nelement\n1\n1\n"
  assert_status 1
  assert_contains "couldn't update $SANDBOX/home/.config/Element/config.json (is it valid JSON?)"
  assert_file_equals "$SANDBOX/home/.config/Element/config.json" '{"brand": "Element",'
}

# GIVEN Element installed through Flatpak, and on a Mac
# WHEN choosing Element
# THEN the Flatpak's settings folder gets the theme too; and on a Mac it
#      goes in Application Support
test_element_themes_the_flatpak_and_macos() {
  fake_os Linux
  mkdir -p "$SANDBOX/home/.var/app/im.riot.Riot"
  run_setup "1\nelement\n1\n1\n"
  assert_status 0
  assert_file_contains "$SANDBOX/home/.var/app/im.riot.Riot/config/Element/config.json" "Jenerated Blue Purple"
  assert_file_contains "$SANDBOX/home/.config/Element/config.json" "Jenerated Blue Purple"
  fake_os Darwin
  run_setup "1\nelement\n1\n1\n"
  assert_status 0
  assert_file_contains "$SANDBOX/home/Library/Application Support/Element/config.json" "Jenerated Blue Purple"
}

# --- Tests: Obsidian --------------------------------------------------------

# make_vault path -> creates an Obsidian vault folder (with .obsidian inside).
make_vault() {
  mkdir -p "$1/.obsidian"
}

# know_vaults config vault... -> writes an Obsidian vault list (obsidian.json)
# at $SANDBOX/home/<config> listing the vaults.
know_vaults() {
  local config="$SANDBOX/home/$1" entries="" i=0
  shift
  for vault in "$@"; do
    i=$((i + 1))
    entries="$entries${entries:+,}\"id$i\":{\"path\":\"$vault\",\"ts\":1,\"open\":true}"
  done
  mkdir -p "$(dirname "$config")"
  printf '{"vaults":{%s}}' "$entries" >"$config"
}

LINUX_CONFIG=".config/obsidian/obsidian.json"

obsidian_theme() {
  printf '%s' "$1/.obsidian/themes/Jenerated $2"
}

# GIVEN one vault in Obsidian's vault list
# WHEN choosing Obsidian, Blue Purple and that vault
# THEN the vault and 'Another folder' are offered, the theme is linked into the
#      vault, and it says which theme to choose
test_obsidian_links_the_theme_into_a_known_vault() {
  make_vault "$SANDBOX/Notes"
  know_vaults "$LINUX_CONFIG" "$SANDBOX/Notes"
  run_setup "1\nobsidian\n1\n1\n1\ny\n1\n"
  assert_status 0
  assert_contains "1) $SANDBOX/Notes"
  assert_contains "2) Another folder (type its path)"
  assert_link "$(obsidian_theme "$SANDBOX/Notes" "Blue Purple")" "$SANDBOX/repo/app-themes/obsidian-theme/blue-purple"
  assert_contains 'choose "Jenerated Blue Purple"'
}

# GIVEN a known vault
# WHEN choosing Obsidian and Sunset
# THEN the theme's folder name matches the name in its manifest.json
test_obsidian_theme_folder_matches_its_manifest() {
  make_vault "$SANDBOX/Notes"
  know_vaults "$LINUX_CONFIG" "$SANDBOX/Notes"
  run_setup "1\nobsidian\n1\n2\n1\ny\n1\n"
  assert_status 0
  assert_file_contains "$(obsidian_theme "$SANDBOX/Notes" "Sunset")/manifest.json" \
    '"name": "Jenerated Sunset"'
  assert_exists "$(obsidian_theme "$SANDBOX/Notes" "Sunset")/theme.css"
}

# GIVEN three vaults in Obsidian's vault list, one of which no longer exists
# WHEN choosing Obsidian
# THEN only the two that exist are offered, followed by 'Another folder'
test_obsidian_lists_every_known_vault_that_exists() {
  make_vault "$SANDBOX/Notes"
  make_vault "$SANDBOX/My Work"
  know_vaults "$LINUX_CONFIG" "$SANDBOX/Notes" "$SANDBOX/Gone" "$SANDBOX/My Work"
  run_setup "1\nobsidian\n1\n1\n1\ny\n1\n"
  assert_contains ") $SANDBOX/Notes"
  assert_contains ") $SANDBOX/My Work"
  assert_not_contains "$SANDBOX/Gone"
  assert_contains "3) Another folder (type its path)"
}

# GIVEN a known vault with a space in its path
# WHEN choosing it
# THEN the theme is linked into it
test_obsidian_vault_with_spaces_in_its_path() {
  make_vault "$SANDBOX/My Work"
  know_vaults "$LINUX_CONFIG" "$SANDBOX/My Work"
  run_setup "1\nobsidian\n1\n1\n1\ny\n1\n"
  assert_status 0
  assert_link "$(obsidian_theme "$SANDBOX/My Work" "Blue Purple")" "$SANDBOX/repo/app-themes/obsidian-theme/blue-purple"
}

# GIVEN a Mac with Obsidian's vault list in ~/Library/Application Support
# WHEN choosing Obsidian
# THEN the vault is offered
test_obsidian_finds_vaults_on_macos() {
  fake_os Darwin
  make_vault "$SANDBOX/Notes"
  know_vaults "Library/Application Support/obsidian/obsidian.json" "$SANDBOX/Notes"
  run_setup "1\nobsidian\n1\n1\n1\ny\n1\n"
  assert_status 0
  assert_contains "1) $SANDBOX/Notes"
}

# GIVEN Obsidian installed through Flatpak, with its vault list in the
#       folder Flatpak gives it
# WHEN choosing Obsidian
# THEN the vault is offered
test_obsidian_finds_vaults_from_flatpak() {
  make_vault "$SANDBOX/Notes"
  know_vaults ".var/app/md.obsidian.Obsidian/config/obsidian/obsidian.json" "$SANDBOX/Notes"
  run_setup "1\nobsidian\n1\n1\n1\ny\n1\n"
  assert_contains "1) $SANDBOX/Notes"
}

# GIVEN the same vault in two of Obsidian's vault lists
# WHEN choosing Obsidian
# THEN it's offered once
test_obsidian_lists_a_vault_known_twice_once() {
  make_vault "$SANDBOX/Notes"
  know_vaults "$LINUX_CONFIG" "$SANDBOX/Notes"
  know_vaults ".var/app/md.obsidian.Obsidian/config/obsidian/obsidian.json" "$SANDBOX/Notes"
  run_setup "1\nobsidian\n1\n1\n1\ny\n1\n"
  assert_contains "2) Another folder"
}

# GIVEN no Obsidian vault list
# WHEN choosing Obsidian and typing a vault's path with a trailing slash
# THEN it asks for the path directly and links the theme into that vault
test_obsidian_asks_for_a_path_when_no_vaults_are_known() {
  make_vault "$SANDBOX/Notes"
  run_setup "1\nobsidian\n1\n1\n$SANDBOX/Notes/\ny\n1\n"
  assert_status 0
  assert_contains "Path to your vault folder:"
  assert_not_contains "Another folder"
  assert_link "$(obsidian_theme "$SANDBOX/Notes" "Blue Purple")" "$SANDBOX/repo/app-themes/obsidian-theme/blue-purple"
}

# GIVEN a known vault, and another vault in the home folder
# WHEN choosing 'Another folder' and typing ~/Vault
# THEN ~ is expanded and the theme is linked into that vault
test_obsidian_another_folder_expands_the_home_folder() {
  make_vault "$SANDBOX/Notes"
  make_vault "$SANDBOX/home/Vault"
  know_vaults "$LINUX_CONFIG" "$SANDBOX/Notes"
  run_setup "1\nobsidian\n1\n1\n2\n~/Vault\ny\n1\n"
  assert_status 0
  assert_link "$(obsidian_theme "$SANDBOX/home/Vault" "Blue Purple")" "$SANDBOX/repo/app-themes/obsidian-theme/blue-purple"
}

# GIVEN a vault called Notes in the folder setup.sh is run from
# WHEN typing the relative path Notes
# THEN the theme is linked into that vault, not looked for in the repository
test_obsidian_relative_path_is_relative_to_where_setup_ran() {
  mkdir -p "$SANDBOX/work/Notes/.obsidian"
  RUN_FROM="$SANDBOX/work"
  run_setup "1\nobsidian\n1\n1\nNotes\ny\n1\n"
  assert_status 0
  assert_link "$(obsidian_theme "$SANDBOX/work/Notes" "Blue Purple")" "$SANDBOX/repo/app-themes/obsidian-theme/blue-purple"
}

# GIVEN no Obsidian vault list
# WHEN pressing Enter without typing a path
# THEN it exits with status 1, saying no vault was given
test_obsidian_empty_path_is_an_error() {
  run_setup "1\nobsidian\n1\n1\n\n"
  assert_status 1
  assert_contains "no vault given"
}

# GIVEN no Obsidian vault list
# WHEN typing the path of a folder that doesn't exist
# THEN it exits with status 1, saying there's no folder there
test_obsidian_missing_folder_is_an_error() {
  run_setup "1\nobsidian\n1\n1\n$SANDBOX/Nowhere\n"
  assert_status 1
  assert_contains "there's no folder at $SANDBOX/Nowhere"
}

# GIVEN a folder with no .obsidian folder in it
# WHEN typing its path and answering no
# THEN it exits with status 1 without creating anything in the folder
test_obsidian_asks_before_using_a_folder_that_isnt_a_vault() {
  mkdir -p "$SANDBOX/Plain"
  run_setup "1\nobsidian\n1\n1\n$SANDBOX/Plain\nn\n"
  assert_status 1
  assert_contains "has no .obsidian folder"
  assert_missing "$SANDBOX/Plain/.obsidian"
}

# GIVEN a folder with no .obsidian folder in it
# WHEN typing its path and answering yes
# THEN the theme is linked into it
test_obsidian_uses_a_folder_that_isnt_a_vault_when_told_to() {
  mkdir -p "$SANDBOX/Plain"
  run_setup "1\nobsidian\n1\n1\n$SANDBOX/Plain\ny\ny\n1\n"
  assert_status 0
  assert_link "$(obsidian_theme "$SANDBOX/Plain" "Blue Purple")" "$SANDBOX/repo/app-themes/obsidian-theme/blue-purple"
}

# GIVEN the theme is already linked into a vault
# WHEN choosing the same vault again
# THEN it says it's already installed
test_obsidian_already_linked_is_left_alone() {
  make_vault "$SANDBOX/Notes"
  know_vaults "$LINUX_CONFIG" "$SANDBOX/Notes"
  run_setup "1\nobsidian\n1\n1\n1\ny\n1\n"
  run_setup "1\nobsidian\n1\n1\n1\ny\n1\n"
  assert_status 0
  assert_contains "Already installed"
}

# GIVEN an old copy of the theme in a vault
# WHEN choosing that vault and answering yes to replacing it
# THEN the copy is replaced with a link
test_obsidian_replaces_an_old_copy_when_asked() {
  make_vault "$SANDBOX/Notes"
  mkdir -p "$(obsidian_theme "$SANDBOX/Notes" "Blue Purple")"
  know_vaults "$LINUX_CONFIG" "$SANDBOX/Notes"
  run_setup "1\nobsidian\n1\n1\n1\ny\n1\ny\n"
  assert_status 0
  assert_contains "An older install exists"
  assert_link "$(obsidian_theme "$SANDBOX/Notes" "Blue Purple")" "$SANDBOX/repo/app-themes/obsidian-theme/blue-purple"
}

# --- Tests: preparing a commit ----------------------------------------------

# The generated files git tracks: Blue Purple's defaults.
BLUE_PURPLE_FILES="app-themes/vs-code-theme/themes/jenerated-blue-purple-color-theme.json
app-themes/ptyxis-theme/blue-purple.palette
app-themes/slack-theme/blue-purple.txt
app-themes/obsidian-theme/blue-purple/theme.css
app-themes/obsidian-theme/blue-purple/manifest.json
app-themes/tilix-theme/blue-purple.json"

# Fails unless package.json matches the one git has (staged, or else
# committed).
assert_package_json_is_committed() {
  git -C "$REPO" show :app-themes/vs-code-theme/package.json >"$SANDBOX/committed-package.json"
  assert_same_file "$SANDBOX/repo/app-themes/vs-code-theme/package.json" "$SANDBOX/committed-package.json"
}

# GIVEN Sunset has been generated, so package.json lists it
# WHEN running setup.sh --prep-commit
# THEN package.json matches the committed one again, Sunset's files are kept,
#      and it says how to list Sunset in VS Code again
test_prep_commit_resets_package_json() {
  sandbox_jenerate sunset
  run_setup "" --prep-commit
  assert_status 0
  assert_package_json_is_committed
  assert_exists "$SANDBOX/repo/app-themes/tilix-theme/sunset.json"
  assert_contains "./jenerate.py sunset"
}

# GIVEN Blue Purple's generated files have been removed
# WHEN running setup.sh --prep-commit
# THEN every Blue Purple file is back, matching what's committed
test_prep_commit_restores_removed_blue_purple_files() {
  sandbox_jenerate --remove blue-purple
  run_setup "" --prep-commit
  assert_status 0
  for rel in $BLUE_PURPLE_FILES; do
    assert_same_file "$SANDBOX/repo/$rel" "$REPO/$rel"
  done
  assert_package_json_is_committed
}

# GIVEN nothing but Blue Purple is generated
# WHEN running setup.sh --prep-commit
# THEN it succeeds, package.json is unchanged, and there's no hint about
#      other themes
test_prep_commit_on_a_clean_repository() {
  run_setup "" --prep-commit
  assert_status 0
  assert_package_json_is_committed
  assert_not_contains "Your other themes"
}

# GIVEN Sunset and a Forest palette have both been generated
# WHEN running setup.sh --prep-commit
# THEN the hint lists both, ready to paste into jenerate.py
test_prep_commit_lists_every_other_generated_theme() {
  sed -e 's/^name = .*/name = "Forest"/' -e 's/^slug = .*/slug = "forest"/' \
    "$SANDBOX/repo/palettes/sunset-palette.toml" >"$SANDBOX/repo/palettes/forest-palette.toml"
  sandbox_jenerate forest,sunset
  run_setup "" --prep-commit
  assert_status 0
  assert_contains "./jenerate.py forest,sunset"
}

# GIVEN package.json.tmpl has been changed (a new version), and Sunset is
#       generated
# WHEN running setup.sh --prep-commit
# THEN package.json keeps the change but lists only Blue Purple
test_prep_commit_keeps_package_json_template_changes() {
  sed 's/"version": "1.0.0"/"version": "1.1.0"/' \
    "$SANDBOX/repo/app-themes/vs-code-theme/package.json.tmpl" >"$SANDBOX/package.json.tmpl"
  cp "$SANDBOX/package.json.tmpl" "$SANDBOX/repo/app-themes/vs-code-theme/package.json.tmpl"
  sandbox_jenerate sunset
  run_setup "" --prep-commit
  assert_status 0
  assert_file_contains "$SANDBOX/repo/app-themes/vs-code-theme/package.json" '"version": "1.1.0"'
  assert_file_contains "$SANDBOX/repo/app-themes/vs-code-theme/package.json" '"label": "Jenerated Blue Purple"'
  assert_file_not_contains "$SANDBOX/repo/app-themes/vs-code-theme/package.json" "Sunset"
}

# GIVEN a template has been changed
# WHEN running setup.sh --prep-commit
# THEN Blue Purple's generated file picks up the change, ready to commit
test_prep_commit_regenerates_blue_purple_from_changed_templates() {
  printf '{{accent}}|{{name}}\n' >"$SANDBOX/repo/app-themes/slack-theme/slack-theme.txt.tmpl"
  run_setup "" --prep-commit
  assert_status 0
  assert_file_equals "$SANDBOX/repo/app-themes/slack-theme/blue-purple.txt" "#5865F3|Blue Purple"
}

EXAMPLE_ZIP="app-themes/vivaldi-theme/jenerated-blue-purple.zip"
EXAMPLE_JAR="app-themes/jetbrains-theme/jenerated-blue-purple.jar"

# package_matches_folder package folder -> fails unless the package holds
# exactly the folder's files, with the same contents.
package_matches_folder() {
  "$(find_python)" -c '
import os, sys, zipfile
package, folder = sys.argv[1:]
z = zipfile.ZipFile(package)
files = {os.path.relpath(os.path.join(d, n), folder): open(os.path.join(d, n), "rb").read()
         for d, _, names in os.walk(folder) for n in names}
sys.exit(0 if {i: z.read(i) for i in z.namelist()} == files else 1)
' "$1" "$2" || fail "expected $1 to hold exactly the files in $2"
}

# GIVEN the Vivaldi and JetBrains templates have changed
# WHEN running setup.sh --prep-commit
# THEN the example packages are rebuilt from Blue Purple's regenerated files
test_prep_commit_rebuilds_the_example_packages() {
  sed 's/"radius": 6/"radius": 9/' "$SANDBOX/repo/app-themes/vivaldi-theme/settings.json.tmpl" >"$SANDBOX/vivaldi.tmpl"
  cp "$SANDBOX/vivaldi.tmpl" "$SANDBOX/repo/app-themes/vivaldi-theme/settings.json.tmpl"
  sed 's/"author": "Jenerated Themes"/"author": "Someone Else"/' "$SANDBOX/repo/app-themes/jetbrains-theme/theme.json.tmpl" >"$SANDBOX/theme.tmpl"
  cp "$SANDBOX/theme.tmpl" "$SANDBOX/repo/app-themes/jetbrains-theme/theme.json.tmpl"
  run_setup "" --prep-commit
  assert_status 0
  assert_contains "Rebuilt $EXAMPLE_ZIP"
  assert_contains "Rebuilt $EXAMPLE_JAR"
  package_matches_folder "$SANDBOX/repo/$EXAMPLE_ZIP" "$SANDBOX/repo/app-themes/vivaldi-theme/blue-purple"
  package_matches_folder "$SANDBOX/repo/$EXAMPLE_JAR" "$SANDBOX/repo/app-themes/jetbrains-theme/blue-purple"
  unzip_text="$("$(find_python)" -c 'import sys, zipfile; print(zipfile.ZipFile(sys.argv[1]).read("settings.json").decode())' "$SANDBOX/repo/$EXAMPLE_ZIP")"
  case "$unzip_text" in
    *'"radius": 9'*) ;;
    *) fail "expected the rebuilt Vivaldi example to have the template's change" ;;
  esac
}

# GIVEN the example packages have been deleted
# WHEN running setup.sh --prep-commit
# THEN they're made again
test_prep_commit_restores_deleted_example_packages() {
  rm -f "$SANDBOX/repo/$EXAMPLE_ZIP" "$SANDBOX/repo/$EXAMPLE_JAR"
  run_setup "" --prep-commit
  assert_status 0
  package_matches_folder "$SANDBOX/repo/$EXAMPLE_ZIP" "$SANDBOX/repo/app-themes/vivaldi-theme/blue-purple"
  package_matches_folder "$SANDBOX/repo/$EXAMPLE_JAR" "$SANDBOX/repo/app-themes/jetbrains-theme/blue-purple"
}

# GIVEN the repository's example packages
# WHEN running setup.sh --prep-commit, twice
# THEN the packages are byte for byte the same as the repository's each time,
#      so git only sees them change when their contents do
test_prep_commit_example_packages_are_reproducible() {
  run_setup "" --prep-commit
  assert_same_file "$SANDBOX/repo/$EXAMPLE_ZIP" "$REPO/$EXAMPLE_ZIP"
  assert_same_file "$SANDBOX/repo/$EXAMPLE_JAR" "$REPO/$EXAMPLE_JAR"
  run_setup "" --prep-commit
  assert_same_file "$SANDBOX/repo/$EXAMPLE_ZIP" "$REPO/$EXAMPLE_ZIP"
  assert_same_file "$SANDBOX/repo/$EXAMPLE_JAR" "$REPO/$EXAMPLE_JAR"
}

# GIVEN no Python 3.11 or later
# WHEN running setup.sh --prep-commit
# THEN it exits with status 1, saying it needs Python, and changes nothing
test_prep_commit_needs_python() {
  sandbox_jenerate sunset
  cp "$SANDBOX/repo/app-themes/vs-code-theme/package.json" "$SANDBOX/before.json"
  fake_no_python
  run_setup "" --prep-commit
  assert_status 1
  assert_contains "--prep-commit needs Python 3.11 or later"
  assert_same_file "$SANDBOX/repo/app-themes/vs-code-theme/package.json" "$SANDBOX/before.json"
}

# --- Tests: updating the palette screenshots --------------------------------

# GIVEN no Python 3.11 or later
# WHEN running setup.sh --update-screenshots
# THEN it exits with status 1, saying it needs Python
test_update_screenshots_needs_python() {
  fake_no_python
  run_setup "" --update-screenshots
  assert_status 1
  assert_contains "--update-screenshots needs Python 3.11 or later"
}

# GIVEN Python but no Node.js
# WHEN running setup.sh --update-screenshots
# THEN it exits with status 1, saying it needs Node.js and npm, without
#      changing any screenshot
test_update_screenshots_needs_node() {
  local python
  python="$(find_python)"
  mkdir -p "$SANDBOX/minbin"
  for tool in bash dirname uname "$python"; do
    ln -s "$(command -v "$tool")" "$SANDBOX/minbin/$tool"
  done
  cp "$SANDBOX/repo/palettes/Screenshots/blue-purple.png" "$SANDBOX/before.png"
  OUTPUT="$(cd "$SANDBOX" && HOME="$SANDBOX/home" PATH="$SANDBOX/minbin" XDG_CACHE_HOME= \
    "$SANDBOX/minbin/bash" "$SANDBOX/repo/setup.sh" --update-screenshots 2>&1)"
  STATUS=$?
  assert_status 1
  assert_contains "--update-screenshots needs Node.js and npm (for Playwright)"
  assert_same_file "$SANDBOX/repo/palettes/Screenshots/blue-purple.png" "$SANDBOX/before.png"
}

# GIVEN fake node and npm (node writes a placeholder screenshot per palette)
# WHEN running setup.sh --update-screenshots
# THEN it runs the screenshot script: every palette gets a new screenshot,
#      and the README is checked
test_update_screenshots_runs_the_screenshot_script() {
  fake_command npm "prefix=''
while [ \$# -gt 0 ]; do [ \"\$1\" = --prefix ] && prefix=\"\$2\"; shift; done
mkdir -p \"\$prefix/node_modules/playwright\" \"\$prefix/node_modules/.bin\"
printf '#!/bin/sh\nexit 0\n' >\"\$prefix/node_modules/.bin/playwright\"
chmod +x \"\$prefix/node_modules/.bin/playwright\""
  fake_command node "out=\"\$3\"; shift 3
for f in \"\$@\"; do printf 'new png' >\"\$out/\${f%-palette.toml}.png\"; done"
  run_setup "" --update-screenshots
  assert_status 0
  assert_contains "Updating the palette screenshots"
  for file in "$SANDBOX"/repo/palettes/*-palette.toml; do
    assert_file_equals "$SANDBOX/repo/palettes/Screenshots/$(basename "$file" -palette.toml).png" "new png"
  done
  assert_contains "palettes/README.md"
  assert_not_contains "Which app"
}

# GIVEN fake node and npm (node records the palettes it's asked for)
# WHEN running setup.sh --update-screenshots=sunset, and again with the
#      singular --update-screenshot=sunset,blue-purple
# THEN each runs the screenshot script for just the palettes named
test_update_screenshots_for_named_palettes() {
  fake_command npm "prefix=''
while [ \$# -gt 0 ]; do [ \"\$1\" = --prefix ] && prefix=\"\$2\"; shift; done
mkdir -p \"\$prefix/node_modules/playwright\" \"\$prefix/node_modules/.bin\"
printf '#!/bin/sh\nexit 0\n' >\"\$prefix/node_modules/.bin/playwright\"
chmod +x \"\$prefix/node_modules/.bin/playwright\""
  fake_command node "out=\"\$3\"; shift 3
printf '%s\n' \"\$@\" >\"$SANDBOX/node-palettes\"
for f in \"\$@\"; do printf 'new png' >\"\$out/\${f%-palette.toml}.png\"; done"
  run_setup "" --update-screenshots=sunset
  assert_status 0
  assert_file_equals "$SANDBOX/node-palettes" "sunset-palette.toml"
  run_setup "" --update-screenshot=sunset,blue-purple
  assert_status 0
  assert_file_equals "$SANDBOX/node-palettes" "$(printf 'sunset-palette.toml\nblue-purple-palette.toml')"
  assert_not_contains "Which app"
}

# GIVEN setup.sh
# WHEN running it with --update-screenshots= and no palette after the =
# THEN it stops, saying how to name one
test_update_screenshots_with_an_empty_list_is_an_error() {
  run_setup "" --update-screenshots=
  assert_status 1
  assert_contains "name the palettes to screenshot, like --update-screenshots=candy"
}

# GIVEN an option setup.sh doesn't know
# WHEN running setup.sh with it
# THEN it exits with status 1, naming the option, without showing the menu
test_unknown_option_is_an_error() {
  run_setup "" --bogus
  assert_status 1
  assert_contains "unknown option: --bogus"
  assert_not_contains "Which app"
}

# --- Tests: Slack ------------------------------------------------------------

# GIVEN a Linux system with a clipboard tool
# WHEN choosing Slack and Blue Purple
# THEN the theme string is printed and copied to the clipboard
test_slack_prints_and_copies_the_theme_string() {
  fake_os Linux
  theme="$(tr -d '\n' <"$SANDBOX/repo/app-themes/slack-theme/blue-purple.txt")"
  run_setup "1\nslack\n1\n1\n"
  assert_status 0
  assert_contains "    $theme"
  assert_contains "(Copied to your clipboard.)"
  assert_file_equals "$SANDBOX/clipboard" "$theme"
}

# GIVEN Insomnia without plugins
# WHEN choosing Insomnia and Blue Purple
# THEN Blue Purple's plugin is copied (not linked: Insomnia ignores links to
#      folders elsewhere) into Insomnia's plugins folder, and it explains how
#      to reload plugins and choose the theme
test_insomnia_copies_the_plugin() {
  fake_os Linux
  run_setup "1\ninsomnia\n1\n1\n"
  assert_status 0
  plugin="$SANDBOX/home/.config/Insomnia/plugins/insomnia-plugin-jenerated-blue-purple"
  [ -d "$plugin" ] && [ ! -L "$plugin" ] || fail "expected a copied plugin folder at $plugin"
  assert_same_file "$plugin/index.js" \
    "$SANDBOX/repo/app-themes/insomnia-theme/blue-purple/insomnia-plugin-jenerated-blue-purple/index.js"
  assert_exists "$plugin/package.json"
  assert_contains "-> Plugins and choose Reload."
  assert_contains 'choose "Jenerated Blue Purple"'
}

# GIVEN Blue Purple's plugin copied before, with a file from an older version
#       in it, and another plugin of the user's own
# WHEN choosing Insomnia and Blue Purple again, then Sunset
# THEN Blue Purple's folder is replaced by a fresh copy, Sunset's plugin is
#      added beside it, and the other plugin is left alone
test_insomnia_replaces_its_own_plugin() {
  fake_os Linux
  plugins="$SANDBOX/home/.config/Insomnia/plugins"
  mkdir -p "$plugins/insomnia-plugin-jenerated-blue-purple" "$plugins/insomnia-plugin-other"
  printf 'old\n' >"$plugins/insomnia-plugin-jenerated-blue-purple/stale.js"
  printf '{}\n' >"$plugins/insomnia-plugin-other/package.json"
  run_setup "1\ninsomnia\n1\n1\n"
  run_setup "1\ninsomnia\n1\n2\n"
  assert_status 0
  assert_missing "$plugins/insomnia-plugin-jenerated-blue-purple/stale.js"
  assert_exists "$plugins/insomnia-plugin-jenerated-blue-purple/index.js"
  assert_exists "$plugins/insomnia-plugin-jenerated-sunset/index.js"
  assert_file_equals "$plugins/insomnia-plugin-other/package.json" "{}"
}

# GIVEN Insomnia installed through Flatpak and through Snap, and on a Mac
# WHEN choosing Insomnia
# THEN each of their plugins folders gets the plugin; and on a Mac it goes in
#      Application Support
test_insomnia_themes_flatpak_snap_and_macos() {
  fake_os Linux
  mkdir -p "$SANDBOX/home/.var/app/rest.insomnia.Insomnia" "$SANDBOX/home/snap/insomnia"
  run_setup "1\ninsomnia\n1\n1\n"
  assert_status 0
  for dir in "$SANDBOX/home/.config/Insomnia/plugins" \
    "$SANDBOX/home/.var/app/rest.insomnia.Insomnia/config/Insomnia/plugins" \
    "$SANDBOX/home/snap/insomnia/current/.config/Insomnia/plugins"; do
    assert_exists "$dir/insomnia-plugin-jenerated-blue-purple/index.js"
  done
  fake_os Darwin
  run_setup "1\ninsomnia\n1\n1\n"
  assert_status 0
  assert_exists "$SANDBOX/home/Library/Application Support/Insomnia/plugins/insomnia-plugin-jenerated-blue-purple/index.js"
}

# GIVEN Sublime Text 4
# WHEN choosing Sublime Text and Blue Purple
# THEN the color scheme is linked into its Packages/User folder, and it says
#      to choose the scheme and the Adaptive theme from the command palette
test_sublime_links_the_color_scheme() {
  fake_os Linux
  run_setup "1\nsublime\n1\n1\ny\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/.config/sublime-text/Packages/User/jenerated-blue-purple.sublime-color-scheme" \
    "$SANDBOX/repo/app-themes/sublime-theme/jenerated-blue-purple.sublime-color-scheme"
  assert_missing "$SANDBOX/home/.config/sublime-text-3"
  assert_contains '"UI: Select Color Scheme", then "Jenerated Blue Purple"'
  assert_contains '"Adaptive"'
}

# GIVEN Sublime Text 3's folder, and Sublime Text installed through Flatpak
#       and through Snap
# WHEN choosing Sublime Text
# THEN each of their Packages/User folders gets the color scheme too
test_sublime_themes_st3_flatpak_and_snap() {
  fake_os Linux
  mkdir -p "$SANDBOX/home/.config/sublime-text-3" "$SANDBOX/home/.var/app/com.sublimetext.three" \
    "$SANDBOX/home/snap/sublime-text"
  run_setup "1\nsublime\n1\n1\ny\n1\n"
  assert_status 0
  for dir in "$SANDBOX/home/.config/sublime-text" "$SANDBOX/home/.config/sublime-text-3" \
    "$SANDBOX/home/.var/app/com.sublimetext.three/config/sublime-text" \
    "$SANDBOX/home/snap/sublime-text/current/.config/sublime-text"; do
    assert_link "$dir/Packages/User/jenerated-blue-purple.sublime-color-scheme" \
      "$SANDBOX/repo/app-themes/sublime-theme/jenerated-blue-purple.sublime-color-scheme"
  done
}

# GIVEN a Mac
# WHEN choosing Sublime Text
# THEN the color scheme goes in Application Support
test_sublime_on_macos_uses_application_support() {
  fake_os Darwin
  run_setup "1\nsublime\n1\n1\ny\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/Library/Application Support/Sublime Text/Packages/User/jenerated-blue-purple.sublime-color-scheme" \
    "$SANDBOX/repo/app-themes/sublime-theme/jenerated-blue-purple.sublime-color-scheme"
}

# GIVEN a Mac
# WHEN choosing Xcode and Blue Purple
# THEN the theme is linked into Xcode's themes folder under the palette's
#      name (which Xcode lists it by), and it explains how to choose it
test_xcode_links_the_theme_on_macos() {
  fake_os Darwin
  run_setup "1\nxcode\n1\n1\ny\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/Library/Developer/Xcode/UserData/FontAndColorThemes/Jenerated Blue Purple.xccolortheme" \
    "$SANDBOX/repo/app-themes/xcode-theme/jenerated-blue-purple.xccolortheme"
  assert_contains 'Themes, and'
  assert_contains 'choose "Jenerated Blue Purple".'
}

# GIVEN a Linux system
# WHEN searching the app menu for Xcode
# THEN it isn't offered, since Xcode only runs on a Mac
test_xcode_is_only_offered_on_macos() {
  fake_os Linux
  run_setup "1\nxcode\nslack\n1\n1\n"
  assert_status 0
  assert_contains 'No app matches "xcode".'
}

# GIVEN RStudio's settings in the usual place
# WHEN choosing RStudio and Blue Purple
# THEN the theme is linked into ~/.config/rstudio/themes, and it explains
#      where to choose it
test_rstudio_links_the_theme() {
  fake_os Linux
  run_setup "1\nrstudio\n1\n1\ny\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/.config/rstudio/themes/jenerated-blue-purple.rstheme" \
    "$SANDBOX/repo/app-themes/rstudio-theme/jenerated-blue-purple.rstheme"
  assert_contains "Tools -> Global Options -> Appearance"
  assert_contains 'Choose "Jenerated Blue Purple" as the Editor theme'
}

# GIVEN RSTUDIO_CONFIG_HOME set to another folder, as RStudio allows
# WHEN choosing RStudio
# THEN the theme goes in that folder's themes folder instead
test_rstudio_uses_rstudio_config_home() {
  fake_os Darwin
  TEST_RSTUDIO_CONFIG_HOME="$SANDBOX/home/rs-config" run_setup "1\nrstudio\n1\n1\ny\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/rs-config/themes/jenerated-blue-purple.rstheme" \
    "$SANDBOX/repo/app-themes/rstudio-theme/jenerated-blue-purple.rstheme"
  assert_missing "$SANDBOX/home/.config/rstudio"
}

# GIVEN no Emacs folder yet
# WHEN choosing Emacs and Blue Purple
# THEN the theme is linked into ~/.emacs.d (where Emacs looks for themes by
#      default), and it explains how to load it and keep it
test_emacs_links_the_theme() {
  fake_os Linux
  run_setup "1\nemacs\n1\n1\ny\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/.emacs.d/jenerated-blue-purple-theme.el" \
    "$SANDBOX/repo/app-themes/emacs-theme/jenerated-blue-purple-theme.el"
  assert_contains "M-x load-theme RET jenerated-blue-purple RET"
  assert_contains "M-x customize-themes"
}

# GIVEN Emacs set up in ~/.config/emacs (and no ~/.emacs.d or ~/.emacs)
# WHEN choosing Emacs
# THEN the theme goes in ~/.config/emacs, the folder Emacs uses then
test_emacs_uses_the_config_folder() {
  fake_os Linux
  mkdir -p "$SANDBOX/home/.config/emacs"
  run_setup "1\nemacs\n1\n1\ny\n1\n"
  assert_status 0
  assert_exists "$SANDBOX/home/.config/emacs/jenerated-blue-purple-theme.el"
  assert_missing "$SANDBOX/home/.emacs.d"
}

# GIVEN a ~/.emacs file as well as ~/.config/emacs
# WHEN choosing Emacs
# THEN the theme goes in ~/.emacs.d, since Emacs prefers it whenever there's
#      a ~/.emacs
test_emacs_prefers_emacs_d_when_there_is_a_dot_emacs() {
  fake_os Linux
  mkdir -p "$SANDBOX/home/.config/emacs"
  printf ';; my settings\n' >"$SANDBOX/home/.emacs"
  run_setup "1\nemacs\n1\n1\ny\n1\n"
  assert_status 0
  assert_exists "$SANDBOX/home/.emacs.d/jenerated-blue-purple-theme.el"
  assert_missing "$SANDBOX/home/.config/emacs/jenerated-blue-purple-theme.el"
}

# GIVEN Qt Creator installed the usual way and through Flatpak
# WHEN choosing Qt Creator and Blue Purple
# THEN the color scheme is linked into both styles folders, and it explains
#      where to choose it, and to pick Qt Creator's own dark theme to match
test_qtcreator_links_the_color_scheme() {
  fake_os Linux
  mkdir -p "$SANDBOX/home/.var/app/io.qt.QtCreator"
  run_setup "1\nqt creator\n1\n1\ny\n1\n"
  assert_status 0
  for dir in "$SANDBOX/home/.config/QtProject/qtcreator/styles" \
    "$SANDBOX/home/.var/app/io.qt.QtCreator/config/QtProject/qtcreator/styles"; do
    assert_link "$dir/jenerated-blue-purple.xml" "$SANDBOX/repo/app-themes/qtcreator-theme/jenerated-blue-purple.xml"
  done
  assert_contains "Text Editor -> Font & Colors"
  assert_contains 'Choose "Jenerated Blue Purple" as the Color Scheme.'
  assert_contains "Dark or Light theme"
}

# GIVEN a Mac
# WHEN choosing Qt Creator
# THEN the color scheme goes in ~/.config/QtProject, where Qt Creator keeps
#      its settings on a Mac too
test_qtcreator_on_macos_uses_dot_config() {
  fake_os Darwin
  run_setup "1\nqt creator\n1\n1\ny\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/.config/QtProject/qtcreator/styles/jenerated-blue-purple.xml" \
    "$SANDBOX/repo/app-themes/qtcreator-theme/jenerated-blue-purple.xml"
}

# GIVEN Linux
# WHEN choosing Unreal Engine and Blue Purple
# THEN the theme is linked into Unreal's folder for your own themes, in
#      ~/.config/Epic, and it explains where to choose it and to duplicate it
#      before editing
test_unreal_links_the_theme() {
  fake_os Linux
  run_setup "1\nunreal\n1\n1\ny\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/.config/Epic/UnrealEngine/Slate/Themes/jenerated-blue-purple.json" \
    "$SANDBOX/repo/app-themes/unreal-theme/jenerated-blue-purple.json"
  assert_contains "Editor Preferences -> General -> Appearance"
  assert_contains 'choose "Jenerated Blue Purple" as the Active Theme.'
  assert_contains "choose Duplicate"
}

# GIVEN a Mac
# WHEN choosing Unreal Engine
# THEN the theme goes in ~/Library/Application Support/Epic, where Unreal
#      keeps your settings on a Mac
test_unreal_on_macos_uses_application_support() {
  fake_os Darwin
  run_setup "1\nunreal\n1\n1\ny\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/Library/Application Support/Epic/UnrealEngine/Slate/Themes/jenerated-blue-purple.json" \
    "$SANDBOX/repo/app-themes/unreal-theme/jenerated-blue-purple.json"
}

# GIVEN OBS Studio installed the usual way and through Flatpak
# WHEN choosing OBS Studio and Blue Purple
# THEN the style is linked into both themes folders, and it explains where
#      to choose it
test_obs_links_the_style() {
  fake_os Linux
  mkdir -p "$SANDBOX/home/.var/app/com.obsproject.Studio"
  run_setup "1\nobs studio\n1\n1\ny\n1\n"
  assert_status 0
  for dir in "$SANDBOX/home/.config/obs-studio/themes" \
    "$SANDBOX/home/.var/app/com.obsproject.Studio/config/obs-studio/themes"; do
    assert_link "$dir/jenerated-blue-purple.ovt" "$SANDBOX/repo/app-themes/obs-theme/jenerated-blue-purple.ovt"
  done
  assert_contains "Settings -> Appearance"
  assert_contains 'Choose Yami as the Theme, and "Jenerated Blue Purple" as the Style.'
}

# GIVEN a Mac
# WHEN choosing OBS Studio
# THEN the style goes in ~/Library/Application Support/obs-studio/themes
test_obs_on_macos_uses_application_support() {
  fake_os Darwin
  run_setup "1\nobs studio\n1\n1\ny\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/Library/Application Support/obs-studio/themes/jenerated-blue-purple.ovt" \
    "$SANDBOX/repo/app-themes/obs-theme/jenerated-blue-purple.ovt"
}

# GIVEN LibreOffice's unopkg, and LibreOffice closed
# WHEN choosing LibreOffice and Blue Purple
# THEN it packages the theme as an .oxt holding the extension's files,
#      installs it with "unopkg add --force", and explains where to turn it on
test_libreoffice_installs_the_extension() {
  fake_os Linux
  fake_command pgrep "exit 1"
  fake_command unopkg "printf '%s\\n' \"\$@\" >\"$SANDBOX/unopkg-args\""
  run_setup "1\nlibreoffice\n1\n1\n"
  assert_status 0
  oxt="$SANDBOX/repo/app-themes/libreoffice-theme/jenerated-blue-purple.oxt"
  result="$("$(find_python)" -c '
import sys, zipfile
print(sorted(zipfile.ZipFile(sys.argv[1]).namelist()))
' "$oxt")"
  [ "$result" = "['META-INF/manifest.xml', 'description.txt', 'description.xml', 'theme.xcu']" ] ||
    fail "unexpected .oxt contents: $result"
  assert_file_equals "$SANDBOX/unopkg-args" "add
--force
$oxt"
  assert_contains "Installed."
  assert_contains "LibreOffice -> Appearance"
  assert_contains 'Tick "Enable application theming", choose "Jenerated Blue Purple" as the'
}

# GIVEN LibreOffice's unopkg, and LibreOffice open
# WHEN choosing LibreOffice
# THEN it doesn't run unopkg (which needs LibreOffice closed), and explains
#      adding the .oxt in Tools -> Extensions instead
test_libreoffice_open_adds_the_extension_by_hand() {
  fake_os Linux
  fake_command pgrep "exit 0"
  fake_command unopkg "touch \"$SANDBOX/unopkg-ran\""
  run_setup "1\nlibreoffice\n1\n1\n"
  assert_status 0
  assert_missing "$SANDBOX/unopkg-ran"
  assert_contains "Tools -> Extensions, click Add"
  assert_contains "app-themes/libreoffice-theme/jenerated-blue-purple.oxt"
}

SPYDER_INI=".config/spyder-py3/config/spyder.ini"

# spyder_ini path -> writes a small spyder.ini with a custom theme of the
# user's own (custom-0) and an editor setting.
spyder_ini() {
  mkdir -p "$(dirname "$1")"
  printf '%s\n' '[main]' 'version = 87.2.0' '' '[appearance]' 'selected = spyder/dark' \
    "custom_names = ['custom-0']" 'custom-0/name = My Theme' 'custom-0/background = #000000' \
    '' '[editor]' 'wrap = True' >"$1"
}

# spyder_value ini option -> prints an [appearance] option from spyder.ini.
spyder_value() {
  "$(find_python)" -c '
import configparser, sys
p = configparser.ConfigParser(interpolation=None)
p.optionxform = str
p.read(sys.argv[1])
print(p["appearance"].get(sys.argv[2], ""))
' "$1" "$2"
}

# GIVEN Spyder's settings with a custom theme of the user's own, and Spyder
#       closed
# WHEN choosing Spyder and Blue Purple, and answering yes to making it the
#      current theme
# THEN spyder.ini is backed up, Blue Purple becomes the next custom theme
#      (custom-1, keeping the user's custom-0) and is selected, and the rest
#      of the file is kept
test_spyder_adds_and_selects_the_theme() {
  fake_os Linux
  fake_command pgrep "exit 1"
  ini="$SANDBOX/home/$SPYDER_INI"
  spyder_ini "$ini"
  cp "$ini" "$SANDBOX/original.ini"
  run_setup "1\nspyder\n1\n1\ny\n"
  assert_status 0
  assert_same_file "$ini.before-jenerated" "$SANDBOX/original.ini"
  [ "$(spyder_value "$ini" custom_names)" = "['custom-0', 'custom-1']" ] || fail "expected custom-0 and custom-1"
  [ "$(spyder_value "$ini" custom-1/name)" = "Jenerated Blue Purple" ] || fail "expected custom-1 to be Blue Purple"
  [ "$(spyder_value "$ini" custom-0/name)" = "My Theme" ] || fail "expected the user's theme to be kept"
  [ "$(spyder_value "$ini" selected)" = "custom-1" ] || fail "expected Blue Purple to be selected"
  assert_file_contains "$ini" "custom-1/normal = ('#DBDEE1', False, False)"
  assert_file_contains "$ini" "wrap = True"
}

# GIVEN Blue Purple added to Spyder before
# WHEN choosing Spyder and Blue Purple again, and answering no to selecting it
# THEN it updates the same custom theme instead of adding another, and the
#      current theme is left alone
test_spyder_updates_its_own_theme() {
  fake_os Linux
  fake_command pgrep "exit 1"
  ini="$SANDBOX/home/$SPYDER_INI"
  spyder_ini "$ini"
  run_setup "1\nspyder\n1\n1\nn\n"
  run_setup "1\nspyder\n1\n1\nn\n"
  assert_status 0
  [ "$(spyder_value "$ini" custom_names)" = "['custom-0', 'custom-1']" ] || fail "expected no third custom theme"
  [ "$(spyder_value "$ini" selected)" = "spyder/dark" ] || fail "expected the current theme to be left alone"
  assert_contains "Syntax"
}

# GIVEN Spyder's settings, and Spyder running
# WHEN choosing Spyder
# THEN its settings are left alone, and it says to close Spyder first
test_spyder_waits_while_spyder_is_open() {
  fake_os Linux
  fake_command pgrep "exit 0"
  ini="$SANDBOX/home/$SPYDER_INI"
  spyder_ini "$ini"
  cp "$ini" "$SANDBOX/original.ini"
  run_setup "1\nspyder\n1\n1\n"
  assert_status 0
  assert_contains "Spyder is open"
  assert_same_file "$ini" "$SANDBOX/original.ini"
}

# GIVEN Spyder has never been opened (no spyder.ini)
# WHEN choosing Spyder
# THEN it says to open Spyder once first, and creates nothing
test_spyder_explains_before_first_run() {
  fake_os Linux
  fake_command pgrep "exit 1"
  run_setup "1\nspyder\n1\n1\n"
  assert_status 0
  assert_contains "Spyder hasn't been opened yet"
  assert_missing "$SANDBOX/home/.config/spyder-py3"
}

# GIVEN a Mac with Spyder's settings, and SPYDER_CONFDIR pointing elsewhere
#       on Linux
# WHEN choosing Spyder
# THEN the Mac's ~/.spyder-py3 and the SPYDER_CONFDIR folder get the theme
test_spyder_on_macos_and_with_spyder_confdir() {
  fake_command pgrep "exit 1"
  fake_os Darwin
  spyder_ini "$SANDBOX/home/.spyder-py3/config/spyder.ini"
  run_setup "1\nspyder\n1\n1\nn\n"
  assert_status 0
  [ "$(spyder_value "$SANDBOX/home/.spyder-py3/config/spyder.ini" custom-1/name)" = "Jenerated Blue Purple" ] ||
    fail "expected the theme in ~/.spyder-py3"
  fake_os Linux
  spyder_ini "$SANDBOX/home/spyder-conf/config/spyder.ini"
  TEST_SPYDER_CONFDIR="$SANDBOX/home/spyder-conf" run_setup "1\nspyder\n1\n1\nn\n"
  assert_status 0
  [ "$(spyder_value "$SANDBOX/home/spyder-conf/config/spyder.ini" custom-1/name)" = "Jenerated Blue Purple" ] ||
    fail "expected the theme in the SPYDER_CONFDIR folder"
}

# GIVEN a Linux system with a clipboard tool
# WHEN choosing Mattermost and Blue Purple
# THEN it prints Blue Purple's Mattermost theme on one line, as valid JSON
#      with the palette's colors, copies it to the clipboard, and explains
#      where to paste it
test_mattermost_prints_and_copies_the_theme() {
  fake_os Linux
  run_setup "1\nmattermost\n1\n1\n"
  assert_status 0
  assert_contains "(Copied to your clipboard.)"
  assert_contains "Copy and paste to share theme colors"
  result="$("$(find_python)" -c '
import json, sys
theme = json.loads(open(sys.argv[1]).read())
print(theme["type"], theme["centerChannelBg"], theme["codeTheme"])
' "$SANDBOX/clipboard")"
  [ "$result" = "custom #12131c monokai" ] || fail "expected the clipboard to hold Blue Purple's theme, got: $result"
  line="$(printf '%s\n' "$OUTPUT" | grep '^{ "type": "custom"')"
  [ "$line" = "$(cat "$SANDBOX/clipboard")" ] || fail "expected the printed theme, on one line, to be what was copied"
}

# GIVEN a Mac
# WHEN choosing Slack
# THEN the theme string is copied with pbcopy
test_slack_uses_pbcopy_on_macos() {
  fake_os Darwin
  fake_command pbcopy "cat > \"$SANDBOX/pbcopy-used\""
  run_setup "1\nslack\n1\n1\n"
  assert_status 0
  assert_exists "$SANDBOX/pbcopy-used"
}

# GIVEN a Linux system with a clipboard tool
# WHEN choosing Jellyfin and Blue Purple
# THEN the CSS is copied to the clipboard, it says where the file is, and it
#      explains both places to paste it
test_jellyfin_copies_the_css() {
  fake_os Linux
  run_setup "1\njellyfin\n1\n1\n"
  assert_status 0
  assert_contains "app-themes/jellyfin-theme/jenerated-blue-purple.css"
  assert_contains "(Copied to your clipboard.)"
  assert_same_file "$SANDBOX/clipboard" "$SANDBOX/repo/app-themes/jellyfin-theme/jenerated-blue-purple.css"
  assert_contains "Dashboard -> Branding"
  assert_contains "Settings -> Display"
}

# GIVEN a Linux system with no clipboard tool
# WHEN choosing Slack and Blue Purple
# THEN the theme string is printed, without claiming it was copied
test_slack_without_a_clipboard_tool_still_prints_the_string() {
  fake_os Linux
  rm -f "$SANDBOX"/bin/pbcopy "$SANDBOX"/bin/wl-copy "$SANDBOX"/bin/xclip "$SANDBOX"/bin/xsel
  # Hide any real clipboard tools by giving setup.sh a PATH without them.
  mkdir -p "$SANDBOX/minbin"
  for tool in bash sh sed head tr grep readlink rm ln mkdir mv cat dirname basename uname; do
    [ -e "$SANDBOX/bin/$tool" ] && continue
    ln -s "$(command -v "$tool")" "$SANDBOX/minbin/$tool"
  done
  fake_no_python
  OUTPUT="$(printf '1\nslack\n1\n1\n' |
    HOME="$SANDBOX/home" PATH="$SANDBOX/bin:$SANDBOX/minbin" WAYLAND_DISPLAY= \
      "$SANDBOX/minbin/bash" "$SANDBOX/repo/setup.sh" 2>&1)"
  STATUS=$?
  assert_status 0
  assert_contains "$(tr -d '\n' <"$SANDBOX/repo/app-themes/slack-theme/blue-purple.txt")"
  assert_not_contains "Copied to your clipboard"
}

run_tests
