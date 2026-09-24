#!/usr/bin/env bash
# Tests for jenerate.py.
#
# Usage: tests/jenerate/test_jenerate.sh
#
# Each test runs jenerate.py from a throwaway copy of the repository, so the
# themes it generates or removes never touch the real one. Needs Python 3.11
# or later; the tests are skipped without it.

source "$(dirname "$0")/../lib.sh"

PYTHON="$(find_python)"
if [ -z "$PYTHON" ]; then
  printf 'skipped: jenerate.py needs Python 3.11 or later\n'
  exit 0
fi

# run_jenerate args... -> runs jenerate.py from the sandbox repository and
# sets OUTPUT and STATUS.
run_jenerate() {
  OUTPUT="$(cd "$SANDBOX/repo" && "$PYTHON" jenerate.py "$@" 2>&1)"
  STATUS=$?
  # Every failure should be a readable message, never a Python crash.
  assert_not_contains "Traceback"
}

# write_palette path name slug [extra lines...] -> writes a palette that
# copies Sunset's colors, under a new name and slug, plus any extra lines
# (which land in [colors]).
write_palette() {
  local path="$1" name="$2" slug="$3"
  shift 3
  sed -e "s|^name = .*|name = \"$name\"|" -e "s|^slug = .*|slug = \"$slug\"|" \
    "$SANDBOX/repo/palettes/sunset-palette.toml" >"$path"
  for line in "$@"; do
    printf '%s\n' "$line" >>"$path"
  done
}

# Paths of the generated files for a slug.
vscode_theme() { printf '%s' "$SANDBOX/repo/vs-code-theme/themes/jenerated-$1-color-theme.json"; }
ptyxis_palette() { printf '%s' "$SANDBOX/repo/ptyxis-theme/$1.palette"; }
slack_theme() { printf '%s' "$SANDBOX/repo/slack-theme/$1.txt"; }
obsidian_theme() { printf '%s' "$SANDBOX/repo/obsidian-theme/$1"; }
tilix_scheme() { printf '%s' "$SANDBOX/repo/tilix-theme/$1.json"; }
PACKAGE_JSON_REL="vs-code-theme/package.json"

# Prints package.json's theme labels, one per line, in order.
package_labels() {
  "$PYTHON" -c '
import json, sys
for theme in json.load(open(sys.argv[1]))["contributes"]["themes"]:
    print(theme["label"])
' "$SANDBOX/repo/$PACKAGE_JSON_REL"
}

assert_valid_json() {
  "$PYTHON" -m json.tool "$1" >/dev/null 2>&1 || fail "expected $1 to be valid JSON"
}

# --- Tests: arguments --------------------------------------------------------

test_no_palettes_is_an_error() {
  run_jenerate
  assert_status 2
  assert_contains "name at least one palette"
}

test_list_shows_palettes_and_marks_generated() {
  run_jenerate --list
  assert_status 0
  assert_contains "* blue-purple"
  assert_contains "  sunset"
  assert_contains "Sunset"
  assert_contains "* = generated"
}

test_list_marks_a_palette_once_generated() {
  run_jenerate sunset
  run_jenerate --list
  assert_contains "* sunset"
}

test_list_rejects_palette_names() {
  run_jenerate --list sunset
  assert_status 2
  assert_contains "--list doesn't take palettes"
}

test_list_and_remove_together_is_an_error() {
  run_jenerate --list --remove
  assert_status 2
  assert_contains "not allowed with argument"
}

test_unknown_palette_is_an_error() {
  run_jenerate nope
  assert_status 1
  assert_contains "No palette named 'nope'"
}

# --- Tests: generating -------------------------------------------------------

test_generates_every_app_theme() {
  run_jenerate sunset
  assert_status 0
  assert_contains "Generated Sunset (sunset)"
  assert_exists "$(vscode_theme sunset)"
  assert_exists "$(ptyxis_palette sunset)"
  assert_exists "$(slack_theme sunset)"
  assert_exists "$(obsidian_theme sunset)/theme.css"
  assert_exists "$(obsidian_theme sunset)/manifest.json"
  assert_exists "$(tilix_scheme sunset)"
}

test_fills_in_every_placeholder() {
  run_jenerate sunset
  for file in "$(vscode_theme sunset)" "$(ptyxis_palette sunset)" "$(slack_theme sunset)" \
    "$(obsidian_theme sunset)/theme.css" "$(obsidian_theme sunset)/manifest.json" \
    "$(tilix_scheme sunset)"; do
    assert_file_not_contains "$file" "{{"
  done
}

test_uses_the_palette_colors() {
  run_jenerate sunset
  assert_file_equals "$(slack_theme sunset)" \
    "#21141b,#301d26,#e4572e,#ffffff,#301d26,#f2e4dc,#9ad96b,#ff4d5e,#110a0e,#f2e4dc"
  assert_file_contains "$(ptyxis_palette sunset)" "Name=Sunset"
  assert_file_contains "$(ptyxis_palette sunset)" "Cursor=#e4572e"
  assert_file_contains "$(vscode_theme sunset)" '"name": "Jenerated Sunset"'
}

test_keeps_transparency_suffixes() {
  run_jenerate sunset
  # The template writes {{accent}}33 for a translucent accent.
  assert_file_contains "$(vscode_theme sunset)" '"#e4572e33"'
}

test_follows_color_references() {
  run_jenerate sunset
  # term_red = "red", and red = "#ff4d5e".
  assert_file_contains "$(ptyxis_palette sunset)" "Color1=#ff4d5e"
  # term_bright_black = "text_faint", and text_faint = "#6a4d58".
  assert_file_contains "$(ptyxis_palette sunset)" "Color8=#6a4d58"
}

test_follows_chained_color_references() {
  write_palette "$SANDBOX/chain.toml" "Chain" "chain" \
    'term_red = "danger"' 'danger = "alarm"' 'alarm = "#123456"'
  # Drop the palette's own term_red so the one added above is the only one.
  grep -v '^term_red = "red"' "$SANDBOX/chain.toml" >"$SANDBOX/repo/palettes/chain-palette.toml"
  run_jenerate chain
  assert_status 0
  assert_file_contains "$(ptyxis_palette chain)" "Color1=#123456"
}

test_vscode_theme_is_valid_json() {
  run_jenerate sunset
  assert_valid_json "$(vscode_theme sunset)"
  assert_valid_json "$SANDBOX/repo/$PACKAGE_JSON_REL"
}

test_placeholders_may_have_spaces() {
  printf '{{ accent }}|{{name}}|{{  slug  }}\n' >"$SANDBOX/repo/slack-theme/slack-theme.txt.tmpl"
  run_jenerate sunset
  assert_status 0
  assert_file_equals "$(slack_theme sunset)" "#e4572e|Sunset|sunset"
}

test_blue_purple_matches_the_committed_files() {
  # The committed Blue Purple files must be what jenerate.py produces, so the
  # default stays in sync with its palette and the templates.
  run_jenerate blue-purple
  assert_status 0
  for rel in vs-code-theme/themes/jenerated-blue-purple-color-theme.json \
    ptyxis-theme/blue-purple.palette slack-theme/blue-purple.txt \
    obsidian-theme/blue-purple/theme.css obsidian-theme/blue-purple/manifest.json \
    tilix-theme/blue-purple.json; do
    assert_same_file "$SANDBOX/repo/$rel" "$REPO/$rel"
  done
  # Generating other palettes changes your package.json, so compare against
  # the committed one, which lists only Blue Purple.
  git -C "$REPO" show "HEAD:$PACKAGE_JSON_REL" >"$SANDBOX/committed-package.json"
  assert_same_file "$SANDBOX/repo/$PACKAGE_JSON_REL" "$SANDBOX/committed-package.json"
}

test_several_palettes_with_commas() {
  run_jenerate blue-purple,sunset
  assert_status 0
  assert_contains "Generated Blue Purple (blue-purple)"
  assert_contains "Generated Sunset (sunset)"
}

test_several_palettes_with_spaces() {
  run_jenerate blue-purple sunset
  assert_status 0
  assert_contains "Generated Blue Purple (blue-purple)"
  assert_contains "Generated Sunset (sunset)"
}

test_ignores_stray_commas_and_spaces() {
  run_jenerate " sunset , ,"
  assert_status 0
  assert_contains "Generated Sunset (sunset)"
}

test_palette_given_as_a_path() {
  mkdir -p "$SANDBOX/elsewhere"
  write_palette "$SANDBOX/elsewhere/forest-palette.toml" "Forest" "forest"
  run_jenerate "$SANDBOX/elsewhere/forest-palette.toml"
  assert_status 0
  assert_contains "Generated Forest (forest)"
  assert_exists "$(slack_theme forest)"
}

test_slug_comes_from_the_file_not_its_name() {
  # Outside palettes/, a palette file can be named anything.
  mkdir -p "$SANDBOX/elsewhere"
  write_palette "$SANDBOX/elsewhere/odd.toml" "Odd" "different-slug"
  run_jenerate "$SANDBOX/elsewhere/odd.toml"
  assert_status 0
  assert_exists "$(slack_theme different-slug)"
  assert_missing "$(slack_theme odd)"
}

# --- Tests: color formats --------------------------------------------------

# render_colors placeholders... -> generates Sunset with a Slack template of
# just those placeholders, separated by |, and sets RENDERED.
render_colors() {
  local template="" key
  for key in "$@"; do
    template="$template${template:+|}{{$key}}"
  done
  printf '%s\n' "$template" >"$SANDBOX/repo/slack-theme/slack-theme.txt.tmpl"
  run_jenerate sunset
  RENDERED="$(cat "$(slack_theme sunset)")"
}

test_colors_are_available_as_rgb() {
  # Sunset's accent is #e4572e.
  render_colors accent_rgb
  assert_status 0
  [ "$RENDERED" = "228, 87, 46" ] || fail "expected accent_rgb '228, 87, 46', got '$RENDERED'"
}

test_colors_are_available_as_hsl() {
  render_colors accent_h accent_s accent_l
  [ "$RENDERED" = "14|77|54" ] || fail "expected accent h|s|l '14|77|54', got '$RENDERED'"
}

test_referenced_colors_get_formats_too() {
  # term_red = "red", and red = "#ff4d5e".
  render_colors term_red_rgb
  [ "$RENDERED" = "255, 77, 94" ] || fail "expected term_red_rgb '255, 77, 94', got '$RENDERED'"
}

test_color_format_edge_cases() {
  write_palette "$SANDBOX/repo/palettes/edges-palette.toml" "Edges" "edges" \
    'grey = "#808080"' 'white = "#FFFFFF"' 'black = "#000000"' 'almost_red = "#ff0001"'
  printf '%s\n' '{{grey_h}},{{grey_s}},{{grey_l}}|{{white_rgb}}|{{white_l}}|{{black_rgb}}|{{black_l}}|{{almost_red_h}}' \
    >"$SANDBOX/repo/slack-theme/slack-theme.txt.tmpl"
  run_jenerate edges
  assert_status 0
  # A hue just under 360 degrees rounds to 0, not 360.
  assert_file_equals "$(slack_theme edges)" "0,0,50|255, 255, 255|100|0, 0, 0|0|0"
}

test_a_defined_color_wins_over_a_derived_one() {
  write_palette "$SANDBOX/repo/palettes/clash-palette.toml" "Clash" "clash" 'accent_rgb = "#010203"'
  printf '%s\n' '{{accent_rgb}}' >"$SANDBOX/repo/slack-theme/slack-theme.txt.tmpl"
  run_jenerate clash
  assert_status 0
  assert_file_equals "$(slack_theme clash)" "#010203"
}

# --- Tests: Tilix -----------------------------------------------------------

test_tilix_scheme_is_valid_json() {
  run_jenerate sunset
  assert_valid_json "$(tilix_scheme sunset)"
}

test_tilix_scheme_uses_the_palette() {
  run_jenerate sunset
  result="$("$PYTHON" -c '
import json, sys
s = json.load(open(sys.argv[1]))
print(s["name"], s["background-color"], s["foreground-color"],
      len(s["palette"]), s["palette"][1], s["palette"][15], s["cursor-background-color"])
' "$(tilix_scheme sunset)")"
  # term_red = "red" = #ff4d5e, and term_bright_white = "text_bright" = #ffffff.
  [ "$result" = "Jenerated Sunset #1b1117 #f2e4dc 16 #ff4d5e #ffffff #e4572e" ] ||
    fail "unexpected Tilix scheme values: $result"
}

test_remove_deletes_the_tilix_scheme() {
  run_jenerate sunset
  run_jenerate --remove sunset
  assert_contains "Removed tilix-theme/sunset.json"
  assert_missing "$(tilix_scheme sunset)"
  assert_exists "$SANDBOX/repo/tilix-theme/scheme.json.tmpl"
}

# --- Tests: Obsidian ---------------------------------------------------------

test_obsidian_manifest_names_the_theme() {
  run_jenerate sunset
  assert_valid_json "$(obsidian_theme sunset)/manifest.json"
  assert_file_contains "$(obsidian_theme sunset)/manifest.json" '"name": "Jenerated Sunset"'
}

test_obsidian_css_uses_the_palette() {
  run_jenerate sunset
  css="$(obsidian_theme sunset)/theme.css"
  assert_file_contains "$css" "--color-accent: #e4572e;"
  assert_file_contains "$css" "--accent-h: 14;"
  assert_file_contains "$css" "--accent-s: 77%;"
  assert_file_contains "$css" "--accent-l: 54%;"
  assert_file_contains "$css" "--color-red-rgb: 255, 77, 94;"
  assert_file_contains "$css" "--background-primary: #1b1117;"
}

test_obsidian_css_braces_balance() {
  run_jenerate sunset
  css="$(obsidian_theme sunset)/theme.css"
  open="$(tr -cd '{' <"$css" | wc -c | tr -d ' ')"
  close="$(tr -cd '}' <"$css" | wc -c | tr -d ' ')"
  [ "$open" = "$close" ] || fail "expected balanced braces, got $open { and $close }"
}

test_remove_deletes_the_obsidian_folder() {
  run_jenerate sunset
  run_jenerate --remove sunset
  assert_status 0
  assert_missing "$(obsidian_theme sunset)"
  assert_exists "$SANDBOX/repo/obsidian-theme/theme.css.tmpl"
}

test_remove_keeps_a_folder_with_other_files() {
  run_jenerate sunset
  echo mine >"$(obsidian_theme sunset)/notes.txt"
  run_jenerate --remove sunset
  assert_status 0
  assert_missing "$(obsidian_theme sunset)/theme.css"
  assert_exists "$(obsidian_theme sunset)/notes.txt"
}

# --- Tests: package.json -----------------------------------------------------

test_package_json_lists_each_generated_theme() {
  run_jenerate sunset
  assert_contains "Updated $PACKAGE_JSON_REL"
  labels="$(package_labels)"
  [ "$labels" = "$(printf 'Jenerated Blue Purple\nJenerated Sunset')" ] ||
    fail "expected package.json to list Blue Purple then Sunset, got: $labels"
  assert_file_contains "$SANDBOX/repo/$PACKAGE_JSON_REL" \
    '"path": "./themes/jenerated-sunset-color-theme.json"'
}

test_package_json_keeps_the_base_fields() {
  run_jenerate sunset
  assert_file_contains "$SANDBOX/repo/$PACKAGE_JSON_REL" '"name": "jenerated-themes"'
  assert_file_contains "$SANDBOX/repo/$PACKAGE_JSON_REL" '"uiTheme": "vs-dark"'
}

test_package_json_uses_each_themes_type() {
  sed 's/"type": "dark"/"type": "light"/' \
    "$SANDBOX/repo/vs-code-theme/themes/color-theme.json.tmpl" >"$SANDBOX/light.tmpl"
  cp "$SANDBOX/light.tmpl" "$SANDBOX/repo/vs-code-theme/themes/color-theme.json.tmpl"
  run_jenerate sunset
  assert_status 0
  uitheme="$("$PYTHON" -c '
import json, sys
themes = json.load(open(sys.argv[1]))["contributes"]["themes"]
print({t["label"]: t["uiTheme"] for t in themes}["Jenerated Sunset"])
' "$SANDBOX/repo/$PACKAGE_JSON_REL")"
  [ "$uitheme" = "vs" ] || fail "expected uiTheme vs for a light theme, got $uitheme"
}

test_a_broken_theme_file_is_reported() {
  printf '{"name": "Broken",\n' >"$(vscode_theme broken)"
  run_jenerate sunset
  assert_status 1
  assert_contains "jenerated-broken-color-theme.json: not a valid theme file"
  assert_contains "Regenerate it with ./jenerate.py, or delete it."
}

test_a_theme_file_without_a_name_is_reported() {
  printf '{"type": "dark"}\n' >"$(vscode_theme nameless)"
  run_jenerate sunset
  assert_status 1
  assert_contains "jenerated-nameless-color-theme.json: not a valid theme file"
}

test_removing_a_broken_theme_fixes_it() {
  printf '{"name": "Broken",\n' >"$(vscode_theme broken)"
  run_jenerate --remove broken
  assert_status 0
  assert_contains "Removed vs-code-theme/themes/jenerated-broken-color-theme.json"
}

test_package_json_is_not_rewritten_when_unchanged() {
  run_jenerate sunset
  run_jenerate sunset
  assert_status 0
  assert_not_contains "Updated"
}

# --- Tests: removing ---------------------------------------------------------

test_remove_deletes_the_themes() {
  run_jenerate sunset
  run_jenerate --remove sunset
  assert_status 0
  assert_contains "Removed slack-theme/sunset.txt"
  assert_missing "$(vscode_theme sunset)"
  assert_missing "$(ptyxis_palette sunset)"
  assert_missing "$(slack_theme sunset)"
  assert_exists "$SANDBOX/repo/palettes/sunset-palette.toml"
}

test_remove_updates_package_json() {
  run_jenerate sunset
  run_jenerate --remove sunset
  labels="$(package_labels)"
  [ "$labels" = "Jenerated Blue Purple" ] ||
    fail "expected package.json to list only Blue Purple, got: $labels"
}

test_remove_leaves_other_palettes_alone() {
  run_jenerate sunset
  run_jenerate --remove sunset
  assert_exists "$(slack_theme blue-purple)"
  assert_exists "$(vscode_theme blue-purple)"
}

test_remove_something_not_generated() {
  run_jenerate --remove sunset
  assert_status 0
  assert_contains "sunset: nothing to remove"
}

test_remove_by_path_uses_the_files_slug() {
  mkdir -p "$SANDBOX/elsewhere"
  write_palette "$SANDBOX/elsewhere/odd.toml" "Odd" "different-slug"
  run_jenerate "$SANDBOX/elsewhere/odd.toml"
  run_jenerate --remove "$SANDBOX/elsewhere/odd.toml"
  assert_status 0
  assert_missing "$(slack_theme different-slug)"
}

# --- Tests: bad palettes -----------------------------------------------------

test_palette_file_name_must_match_its_slug() {
  write_palette "$SANDBOX/repo/palettes/twilight-palette.toml" "Twilight" "dusk"
  run_jenerate twilight
  assert_status 1
  assert_contains "twilight-palette.toml: palettes in palettes/ must be named after their slug; rename it to dusk-palette.toml"
  assert_missing "$(slack_theme dusk)"
}

test_list_reports_a_misnamed_palette() {
  write_palette "$SANDBOX/repo/palettes/twilight-palette.toml" "Twilight" "dusk"
  run_jenerate --list
  assert_status 1
  assert_contains "rename it to dusk-palette.toml"
}

test_color_that_is_not_a_string() {
  printf 'name = "Numbers"\nslug = "numbers"\n[colors]\naccent = 5\n' \
    >"$SANDBOX/repo/palettes/numbers-palette.toml"
  run_jenerate numbers
  assert_status 1
  assert_contains 'color `accent` must be a quoted string'
}

test_colors_that_are_not_a_table() {
  printf 'name = "Flat"\nslug = "flat"\ncolors = "#123456"\n' \
    >"$SANDBOX/repo/palettes/flat-palette.toml"
  run_jenerate flat
  assert_status 1
  assert_contains '`colors` must be a [colors] table'
}

test_palette_with_a_syntax_error() {
  write_palette "$SANDBOX/repo/palettes/broken-palette.toml" "Broken" "broken" \
    'accent = "#123456"'
  run_jenerate broken
  assert_status 1
  assert_contains "broken-palette.toml: not a valid palette file: Cannot overwrite a value"
  assert_not_contains "Traceback"
}

test_list_with_a_broken_palette() {
  printf 'name = "Broken\n' >"$SANDBOX/repo/palettes/broken-palette.toml"
  run_jenerate --list
  assert_status 1
  assert_contains "broken-palette.toml: not a valid palette file"
  assert_not_contains "Traceback"
}

test_palette_without_a_name() {
  grep -v '^name = ' "$SANDBOX/repo/palettes/sunset-palette.toml" \
    >"$SANDBOX/repo/palettes/broken-palette.toml"
  run_jenerate broken
  assert_status 1
  assert_contains 'missing top-level `name` string'
}

test_palette_without_a_slug() {
  grep -v '^slug = ' "$SANDBOX/repo/palettes/sunset-palette.toml" \
    >"$SANDBOX/repo/palettes/broken-palette.toml"
  run_jenerate broken
  assert_status 1
  assert_contains 'missing top-level `slug` string'
}

test_color_that_refers_to_itself() {
  write_palette "$SANDBOX/repo/palettes/loop-palette.toml" "Loop" "loop" 'ouroboros = "ouroboros"'
  run_jenerate loop
  assert_status 1
  assert_contains 'color `ouroboros` refers to itself in a loop'
}

test_colors_that_refer_to_each_other_in_a_loop() {
  write_palette "$SANDBOX/repo/palettes/loop-palette.toml" "Loop" "loop" \
    'ping = "pong"' 'pong = "ping"'
  run_jenerate loop
  assert_status 1
  assert_contains "refers to itself in a loop"
}

test_color_that_is_not_hex_or_a_name() {
  write_palette "$SANDBOX/repo/palettes/bad-palette.toml" "Bad" "bad" 'mystery = "blurple"'
  run_jenerate bad
  assert_status 1
  assert_contains "color \`mystery\` = 'blurple' is not a #rrggbb value"
}

test_short_hex_is_rejected() {
  write_palette "$SANDBOX/repo/palettes/bad-palette.toml" "Bad" "bad" 'tiny = "#fff"'
  run_jenerate bad
  assert_status 1
  assert_contains "color \`tiny\` = '#fff' is not a #rrggbb value"
}

test_missing_color_is_named_and_nothing_is_written() {
  grep -v '^accent = ' "$SANDBOX/repo/palettes/sunset-palette.toml" |
    sed -e 's/^name = .*/name = "Holey"/' -e 's/^slug = .*/slug = "holey"/' \
      >"$SANDBOX/repo/palettes/holey-palette.toml"
  run_jenerate holey
  assert_status 1
  assert_contains "the palette has no color named accent"
  assert_missing "$(vscode_theme holey)"
  assert_missing "$(ptyxis_palette holey)"
  assert_missing "$(slack_theme holey)"
}

test_a_bad_palette_stops_before_later_ones() {
  write_palette "$SANDBOX/repo/palettes/bad-palette.toml" "Bad" "bad" 'mystery = "blurple"'
  run_jenerate bad,sunset
  assert_status 1
  assert_missing "$(slack_theme sunset)"
}


# --- Tests: unsafe palettes --------------------------------------------------
# A palette may come from someone else, so its slug and name must not be able
# to reach files outside the repository or break the generated files.

# write_unsafe_palette slug -> writes $SANDBOX/unsafe.toml with that slug.
write_unsafe_palette() {
  write_palette "$SANDBOX/unsafe.toml" "Unsafe" "placeholder"
  sed "s|^slug = .*|slug = \"$1\"|" "$SANDBOX/unsafe.toml" >"$SANDBOX/unsafe.tmp"
  mv "$SANDBOX/unsafe.tmp" "$SANDBOX/unsafe.toml"
}

test_slug_cannot_escape_the_repository_when_generating() {
  write_unsafe_palette "../../escaped"
  run_jenerate "$SANDBOX/unsafe.toml"
  assert_status 1
  assert_contains "'../../escaped' is not a valid slug"
  assert_missing "$SANDBOX/escaped.palette"
  assert_missing "$SANDBOX/escaped.txt"
}

test_slug_cannot_escape_the_repository_when_removing() {
  write_unsafe_palette "../../escaped"
  echo keep >"$SANDBOX/escaped.palette"
  echo keep >"$SANDBOX/escaped.txt"
  run_jenerate --remove "$SANDBOX/unsafe.toml"
  assert_status 1
  assert_contains "is not a valid slug"
  assert_exists "$SANDBOX/escaped.palette"
  assert_exists "$SANDBOX/escaped.txt"
}

test_slugs_must_be_lowercase_words_and_dashes() {
  for slug in "Sunset" "sun set" "sun_set" "sun/set" "-sunset" "sunset-" "sun--set" "" "."; do
    write_unsafe_palette "$slug"
    run_jenerate "$SANDBOX/unsafe.toml"
    assert_status 1
    assert_contains "is not a valid slug"
  done
}

test_valid_slugs_are_accepted() {
  for slug in "a" "sunset2" "deep-blue-sea" "80s-neon"; do
    write_unsafe_palette "$slug"
    run_jenerate "$SANDBOX/unsafe.toml"
    assert_status 0
    assert_exists "$(slack_theme "$slug")"
  done
}

test_slug_on_the_command_line_is_checked() {
  run_jenerate --remove ..
  assert_status 1
  assert_contains "'..' is not a valid slug"
  run_jenerate Sunset
  assert_status 1
  assert_contains "'Sunset' is not a valid slug"
}

test_name_cannot_contain_a_quote() {
  # A TOML literal string ('...') holds the quote as is.
  write_palette "$SANDBOX/evil.toml" "placeholder" "evil"
  {
    printf '%s\n' "name = 'Evil\"'"
    grep -v '^name = ' "$SANDBOX/evil.toml"
  } >"$SANDBOX/repo/palettes/evil-palette.toml"
  run_jenerate evil
  assert_status 1
  assert_contains "\`name\` can't contain quotes, slashes, backslashes or line breaks"
  assert_missing "$(vscode_theme evil)"
}

test_name_cannot_contain_a_line_break() {
  write_palette "$SANDBOX/repo/palettes/evil-palette.toml" 'Evil\\nBackground=#ff0000' "evil"
  run_jenerate evil
  assert_status 1
  assert_contains "\`name\` can't contain quotes, slashes, backslashes or line breaks"
  assert_missing "$(ptyxis_palette evil)"
}

test_name_cannot_contain_a_backslash() {
  write_palette "$SANDBOX/repo/palettes/evil-palette.toml" 'Evil\\\\' "evil"
  run_jenerate evil
  assert_status 1
  assert_contains "\`name\` can't contain quotes, slashes, backslashes or line breaks"
}

test_name_cannot_contain_a_slash() {
  # The name also names the Obsidian theme's folder.
  write_palette "$SANDBOX/repo/palettes/evil-palette.toml" 'Night/Day' "evil"
  run_jenerate evil
  assert_status 1
  assert_contains "\`name\` can't contain quotes, slashes, backslashes or line breaks"
}

test_name_may_use_other_characters() {
  write_palette "$SANDBOX/repo/palettes/cafe-palette.toml" "Café d'Or (Night)" "cafe"
  run_jenerate cafe
  assert_status 0
  assert_valid_json "$(vscode_theme cafe)"
  assert_file_contains "$(ptyxis_palette cafe)" "Name=Café d'Or (Night)"
}

run_tests
