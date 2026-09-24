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

# run_setup "answers" [options...] -> runs setup.sh with the options, feeding
# it the answers (use \n between them), and sets OUTPUT and STATUS. It runs
# from $RUN_FROM (default $SANDBOX), and runs $SETUP (default the sandbox
# repository's setup.sh).
run_setup() {
  local answers="$1"
  shift
  OUTPUT="$(cd "${RUN_FROM:-$SANDBOX}" && printf '%b' "$answers" |
    HOME="$SANDBOX/home" PATH="$SANDBOX/bin:$PATH" WAYLAND_DISPLAY= \
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
# WHEN setup.sh starts
# THEN the app menu lists VS Code, Slack, Obsidian, Ptyxis and Tilix
test_app_menu_on_linux_includes_the_terminals() {
  fake_os Linux
  run_setup "2\n1\n"
  assert_contains "1) VS Code"
  assert_contains "2) Slack"
  assert_contains "3) Obsidian"
  assert_contains "4) Ptyxis (Ubuntu terminal)"
  assert_contains "5) Tilix (terminal)"
}

# GIVEN a Mac
# WHEN setup.sh starts
# THEN the app menu lists VS Code, Slack and Obsidian, but not Ptyxis or Tilix
test_app_menu_on_macos_hides_the_linux_terminals() {
  fake_os Darwin
  run_setup "2\n1\n"
  assert_contains "1) VS Code"
  assert_contains "2) Slack"
  assert_contains "3) Obsidian"
  assert_not_contains "Ptyxis"
  assert_not_contains "Tilix"
}

# GIVEN the palettes in palettes/
# WHEN choosing an app
# THEN the theme menu lists every palette by name
test_theme_menu_lists_every_palette() {
  run_setup "2\n1\n"
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
  run_setup "2\n1\n"
  assert_contains ") Forest"
}

# GIVEN a Forest palette whose name and slug use TOML's single quotes
# WHEN choosing Slack and Forest
# THEN Forest is listed by name and generated
test_theme_menu_reads_single_quoted_names() {
  sed -e "s/^name = .*/name = 'Forest'/" -e "s/^slug = .*/slug = 'forest'/" \
    "$SANDBOX/repo/palettes/sunset-palette.toml" >"$SANDBOX/repo/palettes/forest-palette.toml"
  run_setup "2\n2\n"
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
  run_setup "2\n1\n"
  assert_contains "2) Forest"
}

# GIVEN a palette in palettes/ that isn't valid TOML
# WHEN choosing an app
# THEN it stops before the theme menu, naming the broken palette
test_theme_menu_stops_on_an_unreadable_palette() {
  printf 'name = "Broken\n' >"$SANDBOX/repo/palettes/broken-palette.toml"
  run_setup "2\n1\n"
  assert_status 1
  assert_contains "broken-palette.toml: not a valid palette file"
  assert_contains "fix the palette named above"
  assert_not_contains "Which theme"
}

# GIVEN answers that are empty, not numbers, or out of range
# WHEN they're typed at the app menu
# THEN each one asks again, and a valid answer then carries on
test_invalid_choices_ask_again() {
  run_setup "\nabc\n0\n9\n-1\n2\n1\n"
  assert_status 0
  count="$(printf '%s\n' "$OUTPUT" | grep -c 'Please enter a number between 1 and')"
  [ "$count" -eq 5 ] || fail "expected 5 re-prompts, got $count"
  assert_contains "Your Slack theme string"
}

# GIVEN no input at all
# WHEN setup.sh asks which app
# THEN it exits with status 1, saying no choice was made
test_no_answer_exits_with_error() {
  run_setup ""
  assert_status 1
  assert_contains "no choice made"
}

# --- Tests: generating -------------------------------------------------------

# GIVEN Python 3.11 or later
# WHEN choosing Slack and Sunset
# THEN Sunset's themes are generated and added to package.json
test_generates_the_chosen_palette() {
  run_setup "2\n2\n"
  assert_status 0
  assert_contains "Generated Sunset (sunset)"
  assert_exists "$SANDBOX/repo/slack-theme/sunset.txt"
  assert_exists "$SANDBOX/repo/ptyxis-theme/sunset.palette"
  assert_exists "$SANDBOX/repo/vs-code-theme/themes/jenerated-sunset-color-theme.json"
  grep -q '"Jenerated Sunset"' "$SANDBOX/repo/vs-code-theme/package.json" ||
    fail "expected package.json to list Jenerated Sunset"
}

# GIVEN no Python 3.11 or later
# WHEN choosing Slack and Blue Purple
# THEN it succeeds using the committed Blue Purple files
test_blue_purple_works_without_python() {
  fake_no_python
  run_setup "2\n1\n"
  assert_status 0
  assert_contains "Python 3.11+ not found"
  assert_contains "$(tr -d '\n' <"$SANDBOX/repo/slack-theme/blue-purple.txt")"
}

# GIVEN no Python 3.11 or later
# WHEN choosing Slack and Sunset
# THEN it exits with status 1, saying generating Sunset needs Python
test_other_palettes_need_python() {
  fake_no_python
  run_setup "2\n2\n"
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
  printf 'mystery = "blurple"\n' >>"$SANDBOX/repo/palettes/bad-palette.toml"
  run_setup "5\n1\n"
  assert_status 1
  assert_contains "1) Bad"
  assert_contains "color \`mystery\` = 'blurple' is not a #rrggbb value"
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
  run_setup "5\n2\n"
  assert_status 0
  assert_link "$SANDBOX/home/.config/tilix/schemes/jenerated-sunset.json" "$repo/tilix-theme/sunset.json"
  assert_exists "$repo/tilix-theme/sunset.json"
  run_setup "1\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/.vscode/extensions/jenerated-themes" "$repo/vs-code-theme"
  run_setup "3\n1\n$SANDBOX/Notes\n"
  assert_status 0
  assert_link "$SANDBOX/Notes/.obsidian/themes/Jenerated Blue Purple" "$repo/obsidian-theme/blue-purple"
}

# --- Tests: VS Code ----------------------------------------------------------

# GIVEN no VS Code extension installed
# WHEN choosing VS Code and Blue Purple
# THEN the extension folder is linked into ~/.vscode/extensions, and it says
#      which theme to choose
test_vscode_links_the_extension() {
  run_setup "1\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/.vscode/extensions/jenerated-themes" "$SANDBOX/repo/vs-code-theme"
  assert_contains 'Choose "Jenerated Blue Purple"'
}

# GIVEN the extension is already linked to this repository
# WHEN choosing VS Code again
# THEN it says it's already installed and doesn't offer to replace it
test_vscode_already_linked_is_left_alone() {
  mkdir -p "$SANDBOX/home/.vscode/extensions"
  ln -s "$SANDBOX/repo/vs-code-theme" "$SANDBOX/home/.vscode/extensions/jenerated-themes"
  run_setup "1\n1\n"
  assert_status 0
  assert_contains "Already installed"
  assert_not_contains "Replace it"
}

# GIVEN an old copy of the extension folder
# WHEN choosing VS Code and answering yes to replacing it
# THEN the copy is replaced with a link
test_vscode_replaces_an_old_copy_when_asked() {
  mkdir -p "$SANDBOX/home/.vscode/extensions/jenerated-themes"
  run_setup "1\n1\ny\n"
  assert_status 0
  assert_contains "An older install exists"
  assert_link "$SANDBOX/home/.vscode/extensions/jenerated-themes" "$SANDBOX/repo/vs-code-theme"
}

# GIVEN the extension linked to some other folder
# WHEN choosing VS Code and accepting the default answer
# THEN the link points at this repository, and the other folder is kept
test_vscode_replaces_a_link_to_another_folder() {
  mkdir -p "$SANDBOX/home/.vscode/extensions" "$SANDBOX/elsewhere"
  ln -s "$SANDBOX/elsewhere" "$SANDBOX/home/.vscode/extensions/jenerated-themes"
  run_setup "1\n1\n\n"
  assert_status 0
  assert_link "$SANDBOX/home/.vscode/extensions/jenerated-themes" "$SANDBOX/repo/vs-code-theme"
  assert_exists "$SANDBOX/elsewhere"
}

# GIVEN an old copy of the extension folder
# WHEN choosing VS Code and answering no to replacing it
# THEN it exits with status 1 and the copy is untouched
test_vscode_keeps_an_old_copy_when_declined() {
  mkdir -p "$SANDBOX/home/.vscode/extensions/jenerated-themes"
  touch "$SANDBOX/home/.vscode/extensions/jenerated-themes/keep-me"
  run_setup "1\n1\nn\n"
  assert_status 1
  assert_contains "left the existing install alone"
  assert_exists "$SANDBOX/home/.vscode/extensions/jenerated-themes/keep-me"
}

# GIVEN a packaged (.vsix) copy of the extension is installed
# WHEN choosing VS Code
# THEN it warns about the packaged copy so the two don't clash
test_vscode_warns_about_a_packaged_copy() {
  mkdir -p "$SANDBOX/home/.vscode/extensions/local.jenerated-themes-1.0.0"
  run_setup "1\n1\n"
  assert_status 0
  assert_contains "you also have a packaged copy installed (local.jenerated-themes-1.0.0)"
}

# GIVEN VS Code's .obsolete file lists only this extension
# WHEN choosing VS Code and pressing Enter once VS Code is closed
# THEN the .obsolete file is deleted
test_vscode_removes_obsolete_file_with_only_this_extension() {
  mkdir -p "$SANDBOX/home/.vscode/extensions"
  printf '{"local.jenerated-themes-1.0.0":true}' >"$SANDBOX/home/.vscode/extensions/.obsolete"
  run_setup "1\n1\n\n"
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
  run_setup "1\n1\n\n"
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
  run_setup "1\n1\n"
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
  run_setup "1\n1\n"
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
  run_setup "4\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/.local/share/org.gnome.Ptyxis/palettes/blue-purple.palette" \
    "$SANDBOX/repo/ptyxis-theme/blue-purple.palette"
  assert_contains 'choose "Blue Purple"'
}

# GIVEN the Ptyxis palette is already linked
# WHEN choosing Ptyxis again
# THEN it succeeds and the link is still right
test_ptyxis_running_twice_is_fine() {
  fake_os Linux
  run_setup "4\n1\n"
  run_setup "4\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/.local/share/org.gnome.Ptyxis/palettes/blue-purple.palette" \
    "$SANDBOX/repo/ptyxis-theme/blue-purple.palette"
}

# --- Tests: Tilix -----------------------------------------------------------

TILIX_SCHEMES=".config/tilix/schemes"

# GIVEN a Linux system
# WHEN choosing Tilix and Blue Purple
# THEN the scheme is linked into Tilix's schemes folder as
#      jenerated-blue-purple.json, and it says which scheme to choose
test_tilix_links_the_scheme() {
  fake_os Linux
  run_setup "5\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/$TILIX_SCHEMES/jenerated-blue-purple.json" \
    "$SANDBOX/repo/tilix-theme/blue-purple.json"
  assert_contains 'choose "Jenerated Blue Purple"'
}

# GIVEN a Linux system
# WHEN choosing Tilix and Sunset
# THEN Sunset's scheme is generated and linked
test_tilix_links_a_generated_palette() {
  fake_os Linux
  run_setup "5\n2\n"
  assert_status 0
  assert_link "$SANDBOX/home/$TILIX_SCHEMES/jenerated-sunset.json" \
    "$SANDBOX/repo/tilix-theme/sunset.json"
  assert_exists "$SANDBOX/repo/tilix-theme/sunset.json"
}

# GIVEN a scheme of the user's own called blue-purple.json
# WHEN choosing Tilix and Blue Purple
# THEN their scheme is untouched
test_tilix_leaves_other_schemes_alone() {
  fake_os Linux
  mkdir -p "$SANDBOX/home/$TILIX_SCHEMES"
  echo mine >"$SANDBOX/home/$TILIX_SCHEMES/blue-purple.json"
  run_setup "5\n1\n"
  assert_status 0
  assert_file_equals "$SANDBOX/home/$TILIX_SCHEMES/blue-purple.json" "mine"
}

# GIVEN the Tilix scheme is already linked
# WHEN choosing Tilix again
# THEN it says it's already installed
test_tilix_already_linked_is_left_alone() {
  fake_os Linux
  run_setup "5\n1\n"
  run_setup "5\n1\n"
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
  run_setup "5\n1\nn\n"
  assert_status 1
  assert_file_equals "$SANDBOX/home/$TILIX_SCHEMES/jenerated-blue-purple.json" "old"
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
  run_setup "3\n1\n1\n"
  assert_status 0
  assert_contains "1) $SANDBOX/Notes"
  assert_contains "2) Another folder (type its path)"
  assert_link "$(obsidian_theme "$SANDBOX/Notes" "Blue Purple")" "$SANDBOX/repo/obsidian-theme/blue-purple"
  assert_contains 'choose "Jenerated Blue Purple"'
}

# GIVEN a known vault
# WHEN choosing Obsidian and Sunset
# THEN the theme's folder name matches the name in its manifest.json
test_obsidian_theme_folder_matches_its_manifest() {
  make_vault "$SANDBOX/Notes"
  know_vaults "$LINUX_CONFIG" "$SANDBOX/Notes"
  run_setup "3\n2\n1\n"
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
  run_setup "3\n1\n1\n"
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
  run_setup "3\n1\n1\n"
  assert_status 0
  assert_link "$(obsidian_theme "$SANDBOX/My Work" "Blue Purple")" "$SANDBOX/repo/obsidian-theme/blue-purple"
}

# GIVEN a Mac with Obsidian's vault list in ~/Library/Application Support
# WHEN choosing Obsidian
# THEN the vault is offered
test_obsidian_finds_vaults_on_macos() {
  fake_os Darwin
  make_vault "$SANDBOX/Notes"
  know_vaults "Library/Application Support/obsidian/obsidian.json" "$SANDBOX/Notes"
  run_setup "3\n1\n1\n"
  assert_status 0
  assert_contains "1) $SANDBOX/Notes"
}

# GIVEN Obsidian's vault list in the Flatpak config folder
# WHEN choosing Obsidian
# THEN the vault is offered
test_obsidian_finds_vaults_from_flatpak() {
  make_vault "$SANDBOX/Notes"
  know_vaults ".var/app/md.obsidian.Obsidian/config/obsidian/obsidian.json" "$SANDBOX/Notes"
  run_setup "3\n1\n1\n"
  assert_contains "1) $SANDBOX/Notes"
}

# GIVEN the same vault in two of Obsidian's vault lists
# WHEN choosing Obsidian
# THEN it's offered once
test_obsidian_lists_a_vault_known_twice_once() {
  make_vault "$SANDBOX/Notes"
  know_vaults "$LINUX_CONFIG" "$SANDBOX/Notes"
  know_vaults ".var/app/md.obsidian.Obsidian/config/obsidian/obsidian.json" "$SANDBOX/Notes"
  run_setup "3\n1\n1\n"
  assert_contains "2) Another folder"
}

# GIVEN no Obsidian vault list
# WHEN choosing Obsidian and typing a vault's path with a trailing slash
# THEN it asks for the path directly and links the theme into that vault
test_obsidian_asks_for_a_path_when_no_vaults_are_known() {
  make_vault "$SANDBOX/Notes"
  run_setup "3\n1\n$SANDBOX/Notes/\n"
  assert_status 0
  assert_contains "Path to your vault folder:"
  assert_not_contains "Another folder"
  assert_link "$(obsidian_theme "$SANDBOX/Notes" "Blue Purple")" "$SANDBOX/repo/obsidian-theme/blue-purple"
}

# GIVEN a known vault, and another vault in the home folder
# WHEN choosing 'Another folder' and typing ~/Vault
# THEN ~ is expanded and the theme is linked into that vault
test_obsidian_another_folder_expands_the_home_folder() {
  make_vault "$SANDBOX/Notes"
  make_vault "$SANDBOX/home/Vault"
  know_vaults "$LINUX_CONFIG" "$SANDBOX/Notes"
  run_setup "3\n1\n2\n~/Vault\n"
  assert_status 0
  assert_link "$(obsidian_theme "$SANDBOX/home/Vault" "Blue Purple")" "$SANDBOX/repo/obsidian-theme/blue-purple"
}

# GIVEN a vault called Notes in the folder setup.sh is run from
# WHEN typing the relative path Notes
# THEN the theme is linked into that vault, not looked for in the repository
test_obsidian_relative_path_is_relative_to_where_setup_ran() {
  mkdir -p "$SANDBOX/work/Notes/.obsidian"
  RUN_FROM="$SANDBOX/work"
  run_setup "3\n1\nNotes\n"
  assert_status 0
  assert_link "$(obsidian_theme "$SANDBOX/work/Notes" "Blue Purple")" "$SANDBOX/repo/obsidian-theme/blue-purple"
}

# GIVEN no Obsidian vault list
# WHEN pressing Enter without typing a path
# THEN it exits with status 1, saying no vault was given
test_obsidian_empty_path_is_an_error() {
  run_setup "3\n1\n\n"
  assert_status 1
  assert_contains "no vault given"
}

# GIVEN no Obsidian vault list
# WHEN typing the path of a folder that doesn't exist
# THEN it exits with status 1, saying there's no folder there
test_obsidian_missing_folder_is_an_error() {
  run_setup "3\n1\n$SANDBOX/Nowhere\n"
  assert_status 1
  assert_contains "there's no folder at $SANDBOX/Nowhere"
}

# GIVEN a folder with no .obsidian folder in it
# WHEN typing its path and answering no
# THEN it exits with status 1 without creating anything in the folder
test_obsidian_asks_before_using_a_folder_that_isnt_a_vault() {
  mkdir -p "$SANDBOX/Plain"
  run_setup "3\n1\n$SANDBOX/Plain\nn\n"
  assert_status 1
  assert_contains "has no .obsidian folder"
  assert_missing "$SANDBOX/Plain/.obsidian"
}

# GIVEN a folder with no .obsidian folder in it
# WHEN typing its path and answering yes
# THEN the theme is linked into it
test_obsidian_uses_a_folder_that_isnt_a_vault_when_told_to() {
  mkdir -p "$SANDBOX/Plain"
  run_setup "3\n1\n$SANDBOX/Plain\ny\n"
  assert_status 0
  assert_link "$(obsidian_theme "$SANDBOX/Plain" "Blue Purple")" "$SANDBOX/repo/obsidian-theme/blue-purple"
}

# GIVEN the theme is already linked into a vault
# WHEN choosing the same vault again
# THEN it says it's already installed
test_obsidian_already_linked_is_left_alone() {
  make_vault "$SANDBOX/Notes"
  know_vaults "$LINUX_CONFIG" "$SANDBOX/Notes"
  run_setup "3\n1\n1\n"
  run_setup "3\n1\n1\n"
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
  run_setup "3\n1\n1\ny\n"
  assert_status 0
  assert_contains "An older install exists"
  assert_link "$(obsidian_theme "$SANDBOX/Notes" "Blue Purple")" "$SANDBOX/repo/obsidian-theme/blue-purple"
}

# --- Tests: preparing a commit ----------------------------------------------

# The generated files git tracks: Blue Purple's defaults.
BLUE_PURPLE_FILES="vs-code-theme/themes/jenerated-blue-purple-color-theme.json
ptyxis-theme/blue-purple.palette
slack-theme/blue-purple.txt
obsidian-theme/blue-purple/theme.css
obsidian-theme/blue-purple/manifest.json
tilix-theme/blue-purple.json"

# Fails unless package.json matches the committed one.
assert_package_json_is_committed() {
  git -C "$REPO" show HEAD:vs-code-theme/package.json >"$SANDBOX/committed-package.json"
  assert_same_file "$SANDBOX/repo/vs-code-theme/package.json" "$SANDBOX/committed-package.json"
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
  assert_exists "$SANDBOX/repo/tilix-theme/sunset.json"
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
    "$SANDBOX/repo/vs-code-theme/package.json.tmpl" >"$SANDBOX/package.json.tmpl"
  cp "$SANDBOX/package.json.tmpl" "$SANDBOX/repo/vs-code-theme/package.json.tmpl"
  sandbox_jenerate sunset
  run_setup "" --prep-commit
  assert_status 0
  assert_file_contains "$SANDBOX/repo/vs-code-theme/package.json" '"version": "1.1.0"'
  assert_file_contains "$SANDBOX/repo/vs-code-theme/package.json" '"label": "Jenerated Blue Purple"'
  assert_file_not_contains "$SANDBOX/repo/vs-code-theme/package.json" "Sunset"
}

# GIVEN a template has been changed
# WHEN running setup.sh --prep-commit
# THEN Blue Purple's generated file picks up the change, ready to commit
test_prep_commit_regenerates_blue_purple_from_changed_templates() {
  printf '{{accent}}|{{name}}\n' >"$SANDBOX/repo/slack-theme/slack-theme.txt.tmpl"
  run_setup "" --prep-commit
  assert_status 0
  assert_file_equals "$SANDBOX/repo/slack-theme/blue-purple.txt" "#5865F2|Blue Purple"
}

# GIVEN no Python 3.11 or later
# WHEN running setup.sh --prep-commit
# THEN it exits with status 1, saying it needs Python, and changes nothing
test_prep_commit_needs_python() {
  sandbox_jenerate sunset
  cp "$SANDBOX/repo/vs-code-theme/package.json" "$SANDBOX/before.json"
  fake_no_python
  run_setup "" --prep-commit
  assert_status 1
  assert_contains "--prep-commit needs Python 3.11 or later"
  assert_same_file "$SANDBOX/repo/vs-code-theme/package.json" "$SANDBOX/before.json"
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
  theme="$(tr -d '\n' <"$SANDBOX/repo/slack-theme/blue-purple.txt")"
  run_setup "2\n1\n"
  assert_status 0
  assert_contains "    $theme"
  assert_contains "(Copied to your clipboard.)"
  assert_file_equals "$SANDBOX/clipboard" "$theme"
}

# GIVEN a Mac
# WHEN choosing Slack
# THEN the theme string is copied with pbcopy
test_slack_uses_pbcopy_on_macos() {
  fake_os Darwin
  fake_command pbcopy "cat > \"$SANDBOX/pbcopy-used\""
  run_setup "2\n1\n"
  assert_status 0
  assert_exists "$SANDBOX/pbcopy-used"
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
  OUTPUT="$(printf '2\n1\n' |
    HOME="$SANDBOX/home" PATH="$SANDBOX/bin:$SANDBOX/minbin" WAYLAND_DISPLAY= \
      "$SANDBOX/minbin/bash" "$SANDBOX/repo/setup.sh" 2>&1)"
  STATUS=$?
  assert_status 0
  assert_contains "$(tr -d '\n' <"$SANDBOX/repo/slack-theme/blue-purple.txt")"
  assert_not_contains "Copied to your clipboard"
}

run_tests
