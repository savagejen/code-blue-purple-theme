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

# run_setup "answers" -> runs setup.sh, feeding it the answers (use \n between
# them), and sets OUTPUT and STATUS.
run_setup() {
  OUTPUT="$(printf '%b' "$1" |
    HOME="$SANDBOX/home" PATH="$SANDBOX/bin:$PATH" WAYLAND_DISPLAY= \
      bash "$SANDBOX/repo/setup.sh" 2>&1)"
  STATUS=$?
}

# --- Tests: menus ------------------------------------------------------------

test_app_menu_on_linux_includes_the_terminals() {
  fake_os Linux
  run_setup "2\n1\n"
  assert_contains "1) VS Code"
  assert_contains "2) Slack"
  assert_contains "3) Obsidian"
  assert_contains "4) Ptyxis (Ubuntu terminal)"
  assert_contains "5) Tilix (terminal)"
}

test_app_menu_on_macos_hides_the_linux_terminals() {
  fake_os Darwin
  run_setup "2\n1\n"
  assert_contains "1) VS Code"
  assert_contains "2) Slack"
  assert_contains "3) Obsidian"
  assert_not_contains "Ptyxis"
  assert_not_contains "Tilix"
}

test_theme_menu_lists_every_palette() {
  run_setup "2\n1\n"
  for file in "$SANDBOX"/repo/palettes/*-palette.toml; do
    name="$(sed -n 's/^name *= *"\(.*\)".*/\1/p' "$file" | head -n 1)"
    assert_contains ") $name"
  done
}

test_theme_menu_lists_a_new_palette() {
  sed -e 's/^name = .*/name = "Forest"/' -e 's/^slug = .*/slug = "forest"/' \
    "$SANDBOX/repo/palettes/sunset-palette.toml" \
    >"$SANDBOX/repo/palettes/forest-palette.toml"
  run_setup "2\n1\n"
  assert_contains ") Forest"
}

test_invalid_choices_ask_again() {
  run_setup "\nabc\n0\n9\n-1\n2\n1\n"
  assert_status 0
  count="$(printf '%s\n' "$OUTPUT" | grep -c 'Please enter a number between 1 and')"
  [ "$count" -eq 5 ] || fail "expected 5 re-prompts, got $count"
  assert_contains "Your Slack theme string"
}

test_no_answer_exits_with_error() {
  run_setup ""
  assert_status 1
  assert_contains "no choice made"
}

# --- Tests: generating -------------------------------------------------------

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

test_blue_purple_works_without_python() {
  fake_no_python
  run_setup "2\n1\n"
  assert_status 0
  assert_contains "Python 3.11+ not found"
  assert_contains "$(tr -d '\n' <"$SANDBOX/repo/slack-theme/blue-purple.txt")"
}

test_other_palettes_need_python() {
  fake_no_python
  run_setup "2\n2\n"
  assert_status 1
  assert_contains "generating Sunset needs Python 3.11 or later"
}

# --- Tests: VS Code ----------------------------------------------------------

test_vscode_links_the_extension() {
  run_setup "1\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/.vscode/extensions/jenerated-themes" "$SANDBOX/repo/vs-code-theme"
  assert_contains 'Choose "Jenerated Blue Purple"'
}

test_vscode_already_linked_is_left_alone() {
  mkdir -p "$SANDBOX/home/.vscode/extensions"
  ln -s "$SANDBOX/repo/vs-code-theme" "$SANDBOX/home/.vscode/extensions/jenerated-themes"
  run_setup "1\n1\n"
  assert_status 0
  assert_contains "Already installed"
  assert_not_contains "Replace it"
}

test_vscode_replaces_an_old_copy_when_asked() {
  mkdir -p "$SANDBOX/home/.vscode/extensions/jenerated-themes"
  run_setup "1\n1\ny\n"
  assert_status 0
  assert_contains "An older install exists"
  assert_link "$SANDBOX/home/.vscode/extensions/jenerated-themes" "$SANDBOX/repo/vs-code-theme"
}

test_vscode_replaces_a_link_to_another_folder() {
  mkdir -p "$SANDBOX/home/.vscode/extensions" "$SANDBOX/elsewhere"
  ln -s "$SANDBOX/elsewhere" "$SANDBOX/home/.vscode/extensions/jenerated-themes"
  run_setup "1\n1\n\n"
  assert_status 0
  assert_link "$SANDBOX/home/.vscode/extensions/jenerated-themes" "$SANDBOX/repo/vs-code-theme"
  assert_exists "$SANDBOX/elsewhere"
}

test_vscode_keeps_an_old_copy_when_declined() {
  mkdir -p "$SANDBOX/home/.vscode/extensions/jenerated-themes"
  touch "$SANDBOX/home/.vscode/extensions/jenerated-themes/keep-me"
  run_setup "1\n1\nn\n"
  assert_status 1
  assert_contains "left the existing install alone"
  assert_exists "$SANDBOX/home/.vscode/extensions/jenerated-themes/keep-me"
}

test_vscode_warns_about_a_packaged_copy() {
  mkdir -p "$SANDBOX/home/.vscode/extensions/local.jenerated-themes-1.0.0"
  run_setup "1\n1\n"
  assert_status 0
  assert_contains "you also have a packaged copy installed (local.jenerated-themes-1.0.0)"
}

test_vscode_removes_obsolete_file_with_only_this_extension() {
  mkdir -p "$SANDBOX/home/.vscode/extensions"
  printf '{"local.jenerated-themes-1.0.0":true}' >"$SANDBOX/home/.vscode/extensions/.obsolete"
  run_setup "1\n1\n\n"
  assert_status 0
  assert_contains "marked as uninstalled"
  assert_missing "$SANDBOX/home/.vscode/extensions/.obsolete"
}

test_vscode_keeps_other_obsolete_entries() {
  mkdir -p "$SANDBOX/home/.vscode/extensions"
  printf '{"a.first-1.0.0":true,"local.jenerated-themes-1.0.0":true,"b.second-2.0.0":true}' \
    >"$SANDBOX/home/.vscode/extensions/.obsolete"
  run_setup "1\n1\n\n"
  assert_status 0
  assert_file_equals "$SANDBOX/home/.vscode/extensions/.obsolete" \
    '{"a.first-1.0.0":true,"b.second-2.0.0":true}'
}

test_vscode_ignores_obsolete_file_without_this_extension() {
  mkdir -p "$SANDBOX/home/.vscode/extensions"
  printf '{"a.first-1.0.0":true}' >"$SANDBOX/home/.vscode/extensions/.obsolete"
  run_setup "1\n1\n"
  assert_status 0
  assert_not_contains "marked as uninstalled"
  assert_file_equals "$SANDBOX/home/.vscode/extensions/.obsolete" '{"a.first-1.0.0":true}'
}

# --- Tests: Ptyxis -----------------------------------------------------------

test_ptyxis_links_the_palette() {
  fake_os Linux
  run_setup "4\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/.local/share/org.gnome.Ptyxis/palettes/blue-purple.palette" \
    "$SANDBOX/repo/ptyxis-theme/blue-purple.palette"
  assert_contains 'choose "Blue Purple"'
}

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

test_tilix_links_the_scheme() {
  fake_os Linux
  run_setup "5\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/$TILIX_SCHEMES/jenerated-blue-purple.json" \
    "$SANDBOX/repo/tilix-theme/blue-purple.json"
  assert_contains 'choose "Jenerated Blue Purple"'
}

test_tilix_links_a_generated_palette() {
  fake_os Linux
  run_setup "5\n2\n"
  assert_status 0
  assert_link "$SANDBOX/home/$TILIX_SCHEMES/jenerated-sunset.json" \
    "$SANDBOX/repo/tilix-theme/sunset.json"
  assert_exists "$SANDBOX/repo/tilix-theme/sunset.json"
}

test_tilix_leaves_other_schemes_alone() {
  fake_os Linux
  mkdir -p "$SANDBOX/home/$TILIX_SCHEMES"
  echo mine >"$SANDBOX/home/$TILIX_SCHEMES/blue-purple.json"
  run_setup "5\n1\n"
  assert_status 0
  assert_file_equals "$SANDBOX/home/$TILIX_SCHEMES/blue-purple.json" "mine"
}

test_tilix_already_linked_is_left_alone() {
  fake_os Linux
  run_setup "5\n1\n"
  run_setup "5\n1\n"
  assert_status 0
  assert_contains "Already installed"
}

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

test_obsidian_theme_folder_matches_its_manifest() {
  make_vault "$SANDBOX/Notes"
  know_vaults "$LINUX_CONFIG" "$SANDBOX/Notes"
  run_setup "3\n2\n1\n"
  assert_status 0
  assert_file_contains "$(obsidian_theme "$SANDBOX/Notes" "Sunset")/manifest.json" \
    '"name": "Jenerated Sunset"'
  assert_exists "$(obsidian_theme "$SANDBOX/Notes" "Sunset")/theme.css"
}

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

test_obsidian_vault_with_spaces_in_its_path() {
  make_vault "$SANDBOX/My Work"
  know_vaults "$LINUX_CONFIG" "$SANDBOX/My Work"
  run_setup "3\n1\n1\n"
  assert_status 0
  assert_link "$(obsidian_theme "$SANDBOX/My Work" "Blue Purple")" "$SANDBOX/repo/obsidian-theme/blue-purple"
}

test_obsidian_finds_vaults_on_macos() {
  fake_os Darwin
  make_vault "$SANDBOX/Notes"
  know_vaults "Library/Application Support/obsidian/obsidian.json" "$SANDBOX/Notes"
  run_setup "3\n1\n1\n"
  assert_status 0
  assert_contains "1) $SANDBOX/Notes"
}

test_obsidian_finds_vaults_from_flatpak() {
  make_vault "$SANDBOX/Notes"
  know_vaults ".var/app/md.obsidian.Obsidian/config/obsidian/obsidian.json" "$SANDBOX/Notes"
  run_setup "3\n1\n1\n"
  assert_contains "1) $SANDBOX/Notes"
}

test_obsidian_lists_a_vault_known_twice_once() {
  make_vault "$SANDBOX/Notes"
  know_vaults "$LINUX_CONFIG" "$SANDBOX/Notes"
  know_vaults ".var/app/md.obsidian.Obsidian/config/obsidian/obsidian.json" "$SANDBOX/Notes"
  run_setup "3\n1\n1\n"
  assert_contains "2) Another folder"
}

test_obsidian_asks_for_a_path_when_no_vaults_are_known() {
  make_vault "$SANDBOX/Notes"
  run_setup "3\n1\n$SANDBOX/Notes/\n"
  assert_status 0
  assert_contains "Path to your vault folder:"
  assert_not_contains "Another folder"
  assert_link "$(obsidian_theme "$SANDBOX/Notes" "Blue Purple")" "$SANDBOX/repo/obsidian-theme/blue-purple"
}

test_obsidian_another_folder_expands_the_home_folder() {
  make_vault "$SANDBOX/Notes"
  make_vault "$SANDBOX/home/Vault"
  know_vaults "$LINUX_CONFIG" "$SANDBOX/Notes"
  run_setup "3\n1\n2\n~/Vault\n"
  assert_status 0
  assert_link "$(obsidian_theme "$SANDBOX/home/Vault" "Blue Purple")" "$SANDBOX/repo/obsidian-theme/blue-purple"
}

test_obsidian_missing_folder_is_an_error() {
  run_setup "3\n1\n$SANDBOX/Nowhere\n"
  assert_status 1
  assert_contains "there's no folder at $SANDBOX/Nowhere"
}

test_obsidian_asks_before_using_a_folder_that_isnt_a_vault() {
  mkdir -p "$SANDBOX/Plain"
  run_setup "3\n1\n$SANDBOX/Plain\nn\n"
  assert_status 1
  assert_contains "has no .obsidian folder"
  assert_missing "$SANDBOX/Plain/.obsidian"
}

test_obsidian_uses_a_folder_that_isnt_a_vault_when_told_to() {
  mkdir -p "$SANDBOX/Plain"
  run_setup "3\n1\n$SANDBOX/Plain\ny\n"
  assert_status 0
  assert_link "$(obsidian_theme "$SANDBOX/Plain" "Blue Purple")" "$SANDBOX/repo/obsidian-theme/blue-purple"
}

test_obsidian_already_linked_is_left_alone() {
  make_vault "$SANDBOX/Notes"
  know_vaults "$LINUX_CONFIG" "$SANDBOX/Notes"
  run_setup "3\n1\n1\n"
  run_setup "3\n1\n1\n"
  assert_status 0
  assert_contains "Already installed"
}

test_obsidian_replaces_an_old_copy_when_asked() {
  make_vault "$SANDBOX/Notes"
  mkdir -p "$(obsidian_theme "$SANDBOX/Notes" "Blue Purple")"
  know_vaults "$LINUX_CONFIG" "$SANDBOX/Notes"
  run_setup "3\n1\n1\ny\n"
  assert_status 0
  assert_contains "An older install exists"
  assert_link "$(obsidian_theme "$SANDBOX/Notes" "Blue Purple")" "$SANDBOX/repo/obsidian-theme/blue-purple"
}

# --- Tests: Slack ------------------------------------------------------------

test_slack_prints_and_copies_the_theme_string() {
  fake_os Linux
  theme="$(tr -d '\n' <"$SANDBOX/repo/slack-theme/blue-purple.txt")"
  run_setup "2\n1\n"
  assert_status 0
  assert_contains "    $theme"
  assert_contains "(Copied to your clipboard.)"
  assert_file_equals "$SANDBOX/clipboard" "$theme"
}

test_slack_uses_pbcopy_on_macos() {
  fake_os Darwin
  fake_command pbcopy "cat > \"$SANDBOX/pbcopy-used\""
  run_setup "2\n1\n"
  assert_status 0
  assert_exists "$SANDBOX/pbcopy-used"
}

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
