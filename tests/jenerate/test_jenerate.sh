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
vscode_theme() { printf '%s' "$SANDBOX/repo/app-themes/vs-code-theme/themes/jenerated-$1-color-theme.json"; }
ptyxis_palette() { printf '%s' "$SANDBOX/repo/app-themes/ptyxis-theme/$1.palette"; }
slack_theme() { printf '%s' "$SANDBOX/repo/app-themes/slack-theme/$1.txt"; }
obsidian_theme() { printf '%s' "$SANDBOX/repo/app-themes/obsidian-theme/$1"; }
tilix_scheme() { printf '%s' "$SANDBOX/repo/app-themes/tilix-theme/$1.json"; }
vim_scheme() { printf '%s' "$SANDBOX/repo/app-themes/vim-theme/colors/jenerated-$1.vim"; }

# The tests read expected colors from the palette itself, so palettes can be
# changed without changing the tests.
#   color key [palette]     -> the color's #rrggbb, following references
#   color_rgb key [palette] -> its "r, g, b"
#   color_hsl key [palette] -> its "h|s|l" (whole degrees and percents)
# The palette defaults to palettes/sunset-palette.toml in the sandbox.
color_forms() {
  "$PYTHON" -c '
import colorsys, sys, tomllib
form, key, path = sys.argv[1:]
colors = tomllib.load(open(path, "rb"))["colors"]
value = colors[key]
while not value.startswith("#"):
    value = colors[value]
r, g, b = (int(value[i:i + 2], 16) for i in (1, 3, 5))
h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
print({"hex": value, "rgb": f"{r}, {g}, {b}",
       "hsl": f"{round(h * 360) % 360}|{round(s * 100)}|{round(l * 100)}"}[form])
' "$1" "$2" "${3:-$SANDBOX/repo/palettes/sunset-palette.toml}"
}
color() { color_forms hex "$@"; }
color_rgb() { color_forms rgb "$@"; }
color_hsl() { color_forms hsl "$@"; }

# with_references file -> rewrites a palette so term_red refers to red and
# term_bright_black to text_faint, whatever it had before.
with_references() {
  grep -v -e '^term_red = ' -e '^term_bright_black = ' "$1" >"$1.tmp"
  printf '%s\n' 'term_red = "red"' 'term_bright_black = "text_faint"' >>"$1.tmp"
  mv "$1.tmp" "$1"
}
PACKAGE_JSON_REL="app-themes/vs-code-theme/package.json"

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

# GIVEN the repository
# WHEN jenerate.py runs with no palettes named
# THEN it exits with status 2 and asks for at least one palette
test_no_palettes_is_an_error() {
  run_jenerate
  assert_status 2
  assert_contains "name at least one palette"
}

# GIVEN Blue Purple is generated and Sunset isn't
# WHEN running --list
# THEN both are listed by slug and name, with only Blue Purple starred
test_list_shows_palettes_and_marks_generated() {
  run_jenerate --list
  assert_status 0
  assert_contains "* blue-purple"
  assert_contains "  sunset"
  assert_contains "Sunset"
  assert_contains "* = generated"
}

# GIVEN Sunset has just been generated
# WHEN running --list
# THEN Sunset is starred
test_list_marks_a_palette_once_generated() {
  run_jenerate sunset
  run_jenerate --list
  assert_contains "* sunset"
}

# GIVEN the repository
# WHEN running --list with a palette name
# THEN it exits with status 2, saying --list doesn't take palettes
test_list_rejects_palette_names() {
  run_jenerate --list sunset
  assert_status 2
  assert_contains "--list doesn't take palettes"
}

# GIVEN the repository
# WHEN running --list and --remove together
# THEN argparse rejects the combination with status 2
test_list_and_remove_together_is_an_error() {
  run_jenerate --list --remove
  assert_status 2
  assert_contains "not allowed with argument"
}

# GIVEN no palette with the slug 'nope'
# WHEN generating 'nope'
# THEN it exits with status 1, saying there's no palette by that name
test_unknown_palette_is_an_error() {
  run_jenerate nope
  assert_status 1
  assert_contains "No palette named 'nope'"
}

# --- Tests: generating -------------------------------------------------------

# GIVEN the Sunset palette
# WHEN generating it
# THEN it reports success and writes the VS Code, Ptyxis, Slack, Obsidian and
#      Tilix files
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
  assert_exists "$(vim_scheme sunset)"
}

# GIVEN the Sunset palette
# WHEN generating it
# THEN no generated file has a {{ placeholder left in it
test_fills_in_every_placeholder() {
  run_jenerate sunset
  for file in "$(vscode_theme sunset)" "$(ptyxis_palette sunset)" "$(slack_theme sunset)" \
    "$(obsidian_theme sunset)/theme.css" "$(obsidian_theme sunset)/manifest.json" \
    "$(tilix_scheme sunset)" "$(vim_scheme sunset)"; do
    assert_file_not_contains "$file" "{{"
  done
}

# GIVEN the Sunset palette
# WHEN generating it
# THEN the Slack, Ptyxis and VS Code files contain Sunset's colors and name
test_uses_the_palette_colors() {
  run_jenerate sunset
  # The Slack template's order: sidebar, hover, accent, bright text, hover,
  # text, green, red, chrome, text.
  expected=""
  for key in bg_sidebar bg_hover accent text_bright bg_hover text green red bg_chrome text; do
    expected="$expected${expected:+,}$(color "$key")"
  done
  assert_file_equals "$(slack_theme sunset)" "$expected"
  assert_file_contains "$(ptyxis_palette sunset)" "Name=Sunset"
  assert_file_contains "$(ptyxis_palette sunset)" "Cursor=$(color accent)"
  assert_file_contains "$(vscode_theme sunset)" '"name": "Jenerated Sunset"'
}

# GIVEN the VS Code template writes {{accent}}33
# WHEN generating Sunset
# THEN the theme has Sunset's accent followed by 33
test_keeps_transparency_suffixes() {
  run_jenerate sunset
  assert_file_contains "$(vscode_theme sunset)" "\"$(color accent)33\""
}

# GIVEN a palette where term_red refers to red, and term_bright_black to
#       text_faint
# WHEN generating it
# THEN the Ptyxis palette has the referenced colors' hex values
test_follows_color_references() {
  write_palette "$SANDBOX/repo/palettes/refs-palette.toml" "Refs" "refs"
  with_references "$SANDBOX/repo/palettes/refs-palette.toml"
  run_jenerate refs
  assert_status 0
  assert_file_contains "$(ptyxis_palette refs)" "Color1=$(color red)"
  assert_file_contains "$(ptyxis_palette refs)" "Color8=$(color text_faint)"
}

# GIVEN a palette where term_red refers to danger, which refers to alarm, which
#       is #123456
# WHEN generating it
# THEN term_red comes out as #123456
test_follows_chained_color_references() {
  write_palette "$SANDBOX/chain.toml" "Chain" "chain" \
    'term_red = "danger"' 'danger = "alarm"' 'alarm = "#123456"'
  # Drop the palette's own term_red so the one added above is the only one.
  grep -v '^term_red = "red"' "$SANDBOX/chain.toml" >"$SANDBOX/repo/palettes/chain-palette.toml"
  run_jenerate chain
  assert_status 0
  assert_file_contains "$(ptyxis_palette chain)" "Color1=#123456"
}

# GIVEN the Sunset palette
# WHEN generating it
# THEN the VS Code theme and package.json are valid JSON
test_vscode_theme_is_valid_json() {
  run_jenerate sunset
  assert_valid_json "$(vscode_theme sunset)"
  assert_valid_json "$SANDBOX/repo/$PACKAGE_JSON_REL"
}

# GIVEN a template with spaces inside some placeholders, like {{ accent }}
# WHEN generating Sunset
# THEN every placeholder is filled in
test_placeholders_may_have_spaces() {
  printf '{{ accent }}|{{name}}|{{  slug  }}\n' >"$SANDBOX/repo/app-themes/slack-theme/slack-theme.txt.tmpl"
  run_jenerate sunset
  assert_status 0
  assert_file_equals "$(slack_theme sunset)" "$(color accent)|Sunset|sunset"
}

# GIVEN the committed Blue Purple files
# WHEN regenerating Blue Purple
# THEN every file, and package.json, matches what's committed
test_blue_purple_matches_the_committed_files() {
  # The committed Blue Purple files must be what jenerate.py produces, so the
  # default stays in sync with its palette and the templates.
  run_jenerate blue-purple
  assert_status 0
  for rel in app-themes/vs-code-theme/themes/jenerated-blue-purple-color-theme.json \
    app-themes/ptyxis-theme/blue-purple.palette app-themes/slack-theme/blue-purple.txt \
    app-themes/obsidian-theme/blue-purple/theme.css app-themes/obsidian-theme/blue-purple/manifest.json \
    app-themes/tilix-theme/blue-purple.json app-themes/vim-theme/colors/jenerated-blue-purple.vim; do
    assert_same_file "$SANDBOX/repo/$rel" "$REPO/$rel"
  done
  # Generating other palettes changes your package.json, so compare against
  # the one git has (staged, or else committed), which lists only Blue Purple.
  git -C "$REPO" show ":$PACKAGE_JSON_REL" >"$SANDBOX/committed-package.json"
  assert_same_file "$SANDBOX/repo/$PACKAGE_JSON_REL" "$SANDBOX/committed-package.json"
}

# GIVEN Blue Purple and Sunset
# WHEN generating blue-purple,sunset
# THEN both are generated
test_several_palettes_with_commas() {
  run_jenerate blue-purple,sunset
  assert_status 0
  assert_contains "Generated Blue Purple (blue-purple)"
  assert_contains "Generated Sunset (sunset)"
}

# GIVEN Blue Purple and Sunset
# WHEN generating them as separate arguments
# THEN both are generated
test_several_palettes_with_spaces() {
  run_jenerate blue-purple sunset
  assert_status 0
  assert_contains "Generated Blue Purple (blue-purple)"
  assert_contains "Generated Sunset (sunset)"
}

# GIVEN Sunset
# WHEN generating ' sunset , ,'
# THEN Sunset is generated and the empty names are ignored
test_ignores_stray_commas_and_spaces() {
  run_jenerate " sunset , ,"
  assert_status 0
  assert_contains "Generated Sunset (sunset)"
}

# GIVEN a Forest palette outside palettes/
# WHEN generating it by its path
# THEN its themes are generated
test_palette_given_as_a_path() {
  mkdir -p "$SANDBOX/elsewhere"
  write_palette "$SANDBOX/elsewhere/forest-palette.toml" "Forest" "forest"
  run_jenerate "$SANDBOX/elsewhere/forest-palette.toml"
  assert_status 0
  assert_contains "Generated Forest (forest)"
  assert_exists "$(slack_theme forest)"
}

# GIVEN a palette file outside palettes/ named odd.toml, whose slug is
#       different-slug
# WHEN generating it by its path
# THEN the themes are named after the slug, not the file
test_slug_comes_from_the_file_not_its_name() {
  # Outside palettes/, a palette file can be named anything.
  mkdir -p "$SANDBOX/elsewhere"
  write_palette "$SANDBOX/elsewhere/odd.toml" "Odd" "different-slug"
  run_jenerate "$SANDBOX/elsewhere/odd.toml"
  assert_status 0
  assert_exists "$(slack_theme different-slug)"
  assert_missing "$(slack_theme odd)"
}

# GIVEN the repository, and a palette, each in a folder with a space in its path
# WHEN running jenerate.py from another folder with that palette, then
#      removing it
# THEN the themes are written inside the repository and package.json lists
#      them, and removing deletes them again
test_repo_in_a_folder_with_spaces() {
  mkdir -p "$SANDBOX/My Projects" "$SANDBOX/My Palettes"
  mv "$SANDBOX/repo" "$SANDBOX/My Projects/repo"
  local repo="$SANDBOX/My Projects/repo"
  sed -e 's/^name = .*/name = "Forest"/' -e 's/^slug = .*/slug = "forest"/' \
    "$repo/palettes/sunset-palette.toml" >"$SANDBOX/My Palettes/forest.toml"
  OUTPUT="$(cd "$SANDBOX" && "$PYTHON" "$repo/jenerate.py" "$SANDBOX/My Palettes/forest.toml" 2>&1)"
  STATUS=$?
  assert_status 0
  assert_exists "$repo/app-themes/obsidian-theme/forest/theme.css"
  assert_exists "$repo/app-themes/tilix-theme/forest.json"
  assert_file_contains "$repo/$PACKAGE_JSON_REL" '"path": "./themes/jenerated-forest-color-theme.json"'
  OUTPUT="$(cd "$SANDBOX" && "$PYTHON" "$repo/jenerate.py" --remove forest 2>&1)"
  STATUS=$?
  assert_status 0
  assert_missing "$repo/app-themes/obsidian-theme/forest"
  assert_missing "$repo/app-themes/tilix-theme/forest.json"
}

# --- Tests: color formats --------------------------------------------------

# render_colors placeholders... -> generates Sunset with a Slack template of
# just those placeholders, separated by |, and sets RENDERED.
render_colors() {
  local template="" key
  for key in "$@"; do
    template="$template${template:+|}{{$key}}"
  done
  printf '%s\n' "$template" >"$SANDBOX/repo/app-themes/slack-theme/slack-theme.txt.tmpl"
  run_jenerate sunset
  RENDERED="$(cat "$(slack_theme sunset)")"
}

# GIVEN a template using {{accent_rgb}}
# WHEN generating Sunset
# THEN it becomes Sunset's accent as "r, g, b"
test_colors_are_available_as_rgb() {
  render_colors accent_rgb
  assert_status 0
  expected="$(color_rgb accent)"
  [ "$RENDERED" = "$expected" ] || fail "expected accent_rgb '$expected', got '$RENDERED'"
}

# GIVEN a template using {{accent_h}}, {{accent_s}} and {{accent_l}}
# WHEN generating Sunset
# THEN they become Sunset's accent's hue, saturation and lightness
test_colors_are_available_as_hsl() {
  render_colors accent_h accent_s accent_l
  expected="$(color_hsl accent)"
  [ "$RENDERED" = "$expected" ] || fail "expected accent h|s|l '$expected', got '$RENDERED'"
}

# GIVEN a palette where term_red refers to red, and a template using
#       {{term_red_rgb}}
# WHEN generating it
# THEN it becomes red's "r, g, b"
test_referenced_colors_get_formats_too() {
  write_palette "$SANDBOX/repo/palettes/refs-palette.toml" "Refs" "refs"
  with_references "$SANDBOX/repo/palettes/refs-palette.toml"
  printf '%s\n' '{{term_red_rgb}}' >"$SANDBOX/repo/app-themes/slack-theme/slack-theme.txt.tmpl"
  run_jenerate refs
  assert_status 0
  assert_file_equals "$(slack_theme refs)" "$(color_rgb red)"
}

# GIVEN a palette with grey, white, black and #ff0001 (a hue just under 360)
# WHEN generating it with a template of their RGB and HSL forms
# THEN each value is right, and #ff0001's hue is 0, not 360
test_color_format_edge_cases() {
  write_palette "$SANDBOX/repo/palettes/edges-palette.toml" "Edges" "edges" \
    'grey = "#808080"' 'white = "#FFFFFF"' 'black = "#000000"' 'almost_red = "#ff0001"'
  printf '%s\n' '{{grey_h}},{{grey_s}},{{grey_l}}|{{white_rgb}}|{{white_l}}|{{black_rgb}}|{{black_l}}|{{almost_red_h}}' \
    >"$SANDBOX/repo/app-themes/slack-theme/slack-theme.txt.tmpl"
  run_jenerate edges
  assert_status 0
  # A hue just under 360 degrees rounds to 0, not 360.
  assert_file_equals "$(slack_theme edges)" "0,0,50|255, 255, 255|100|0, 0, 0|0|0"
}

# GIVEN a palette that defines its own accent_rgb color
# WHEN generating it with a template using {{accent_rgb}}
# THEN the palette's own color is used, not accent's RGB numbers
test_a_defined_color_wins_over_a_derived_one() {
  write_palette "$SANDBOX/repo/palettes/clash-palette.toml" "Clash" "clash" 'accent_rgb = "#010203"'
  printf '%s\n' '{{accent_rgb}}' >"$SANDBOX/repo/app-themes/slack-theme/slack-theme.txt.tmpl"
  run_jenerate clash
  assert_status 0
  assert_file_equals "$(slack_theme clash)" "#010203"
}

# --- Tests: Tilix -----------------------------------------------------------

# GIVEN the Sunset palette
# WHEN generating it
# THEN the Tilix scheme is valid JSON
test_tilix_scheme_is_valid_json() {
  run_jenerate sunset
  assert_valid_json "$(tilix_scheme sunset)"
}

# GIVEN the Sunset palette
# WHEN generating it
# THEN the Tilix scheme has Sunset's name, background, foreground, 16 terminal
#      colors and cursor color
test_tilix_scheme_uses_the_palette() {
  run_jenerate sunset
  result="$("$PYTHON" -c '
import json, sys
s = json.load(open(sys.argv[1]))
print(s["name"], s["background-color"], s["foreground-color"],
      len(s["palette"]), s["palette"][1], s["palette"][15], s["cursor-background-color"])
' "$(tilix_scheme sunset)")"
  expected="Jenerated Sunset $(color bg) $(color text) 16 $(color term_red) $(color term_bright_white) $(color accent)"
  [ "$result" = "$expected" ] || fail "expected Tilix scheme values '$expected', got '$result'"
}

# GIVEN Sunset has been generated
# WHEN removing Sunset
# THEN its Tilix scheme is deleted and the template is kept
test_remove_deletes_the_tilix_scheme() {
  run_jenerate sunset
  run_jenerate --remove sunset
  assert_contains "Removed app-themes/tilix-theme/sunset.json"
  assert_missing "$(tilix_scheme sunset)"
  assert_exists "$SANDBOX/repo/app-themes/tilix-theme/scheme.json.tmpl"
}

# --- Tests: Vim --------------------------------------------------------------

# GIVEN the Sunset palette
# WHEN generating it
# THEN the Vim colorscheme is named after the slug and uses Sunset's colors,
#      including followed references in the terminal colors
test_vim_scheme_uses_the_palette() {
  run_jenerate sunset
  scheme="$(vim_scheme sunset)"
  assert_file_contains "$scheme" "let g:colors_name = 'jenerated-sunset'"
  assert_file_contains "$scheme" "guibg=$(color bg)"
  assert_file_contains "$scheme" "'$(color term_red)'"
}

# GIVEN the Sunset palette
# WHEN generating it and loading the colorscheme in the real Vim
# THEN it loads without errors, with the palette's background
test_vim_scheme_loads_in_vim() {
  command -v vim >/dev/null 2>&1 || return 0
  run_jenerate sunset
  bg="$(color bg | tr 'A-F' 'a-f')"
  vim -Nu NONE -i NONE -es --cmd "set rtp^=$SANDBOX/repo/app-themes/vim-theme" -c "set termguicolors" \
    -c "try | colorscheme jenerated-sunset | call writefile([g:colors_name . ' ' . tolower(synIDattr(hlID('Normal'), 'bg#')) . ' [' . v:errmsg . ']'], '$SANDBOX/vim-result') | catch | call writefile([v:exception], '$SANDBOX/vim-result') | endtry" \
    -c 'qa!' </dev/null >/dev/null 2>&1
  assert_file_equals "$SANDBOX/vim-result" "jenerated-sunset $bg []"
}

# GIVEN Sunset has been generated
# WHEN removing Sunset
# THEN its Vim colorscheme is deleted, and the colors folder and Blue
#      Purple's colorscheme are kept
test_remove_deletes_the_vim_scheme() {
  run_jenerate sunset
  run_jenerate --remove sunset
  assert_contains "Removed app-themes/vim-theme/colors/jenerated-sunset.vim"
  assert_missing "$(vim_scheme sunset)"
  assert_exists "$(vim_scheme blue-purple)"
}

# --- Tests: Obsidian ---------------------------------------------------------

# GIVEN the Sunset palette
# WHEN generating it
# THEN the Obsidian manifest is valid JSON naming the theme Jenerated Sunset
test_obsidian_manifest_names_the_theme() {
  run_jenerate sunset
  assert_valid_json "$(obsidian_theme sunset)/manifest.json"
  assert_file_contains "$(obsidian_theme sunset)/manifest.json" '"name": "Jenerated Sunset"'
}

# GIVEN the Sunset palette
# WHEN generating it
# THEN the Obsidian CSS has Sunset's accent (as hex and HSL), red as RGB and
#      background
test_obsidian_css_uses_the_palette() {
  run_jenerate sunset
  css="$(obsidian_theme sunset)/theme.css"
  IFS='|' read -r h s l <<<"$(color_hsl accent)"
  assert_file_contains "$css" "--color-accent: $(color accent);"
  assert_file_contains "$css" "--accent-h: $h;"
  assert_file_contains "$css" "--accent-s: $s%;"
  assert_file_contains "$css" "--accent-l: $l%;"
  assert_file_contains "$css" "--color-red-rgb: $(color_rgb red);"
  assert_file_contains "$css" "--background-primary: $(color bg);"
}

# GIVEN the Sunset palette
# WHEN generating it
# THEN the Obsidian CSS has as many { as }
test_obsidian_css_braces_balance() {
  run_jenerate sunset
  css="$(obsidian_theme sunset)/theme.css"
  open="$(tr -cd '{' <"$css" | wc -c | tr -d ' ')"
  close="$(tr -cd '}' <"$css" | wc -c | tr -d ' ')"
  [ "$open" = "$close" ] || fail "expected balanced braces, got $open { and $close }"
}

# GIVEN Sunset has been generated
# WHEN removing Sunset
# THEN its Obsidian folder is deleted and the templates are kept
test_remove_deletes_the_obsidian_folder() {
  run_jenerate sunset
  run_jenerate --remove sunset
  assert_status 0
  assert_missing "$(obsidian_theme sunset)"
  assert_exists "$SANDBOX/repo/app-themes/obsidian-theme/theme.css.tmpl"
}

# GIVEN Sunset has been generated and someone added a file to its Obsidian
#       folder
# WHEN removing Sunset
# THEN the generated files are deleted but the folder and the added file stay
test_remove_keeps_a_folder_with_other_files() {
  run_jenerate sunset
  echo mine >"$(obsidian_theme sunset)/notes.txt"
  run_jenerate --remove sunset
  assert_status 0
  assert_missing "$(obsidian_theme sunset)/theme.css"
  assert_exists "$(obsidian_theme sunset)/notes.txt"
}

# --- Tests: package.json -----------------------------------------------------

# GIVEN Blue Purple is generated
# WHEN generating Sunset
# THEN package.json lists Blue Purple then Sunset, with Sunset's theme path
test_package_json_lists_each_generated_theme() {
  run_jenerate sunset
  assert_contains "Updated $PACKAGE_JSON_REL"
  labels="$(package_labels)"
  [ "$labels" = "$(printf 'Jenerated Blue Purple\nJenerated Sunset')" ] ||
    fail "expected package.json to list Blue Purple then Sunset, got: $labels"
  assert_file_contains "$SANDBOX/repo/$PACKAGE_JSON_REL" \
    '"path": "./themes/jenerated-sunset-color-theme.json"'
}

# GIVEN package.json.tmpl's fields
# WHEN generating Sunset
# THEN package.json keeps the extension name and marks the theme as dark
test_package_json_keeps_the_base_fields() {
  run_jenerate sunset
  assert_file_contains "$SANDBOX/repo/$PACKAGE_JSON_REL" '"name": "jenerated-themes"'
  assert_file_contains "$SANDBOX/repo/$PACKAGE_JSON_REL" '"uiTheme": "vs-dark"'
}

# GIVEN a VS Code template changed to make light themes
# WHEN generating Sunset
# THEN package.json gives Sunset the light uiTheme, vs
test_package_json_uses_each_themes_type() {
  sed 's/"type": "dark"/"type": "light"/' \
    "$SANDBOX/repo/app-themes/vs-code-theme/themes/color-theme.json.tmpl" >"$SANDBOX/light.tmpl"
  cp "$SANDBOX/light.tmpl" "$SANDBOX/repo/app-themes/vs-code-theme/themes/color-theme.json.tmpl"
  run_jenerate sunset
  assert_status 0
  uitheme="$("$PYTHON" -c '
import json, sys
themes = json.load(open(sys.argv[1]))["contributes"]["themes"]
print({t["label"]: t["uiTheme"] for t in themes}["Jenerated Sunset"])
' "$SANDBOX/repo/$PACKAGE_JSON_REL")"
  [ "$uitheme" = "vs" ] || fail "expected uiTheme vs for a light theme, got $uitheme"
}

# GIVEN a VS Code theme file with broken JSON
# WHEN generating Sunset
# THEN it exits with status 1, naming the file and how to fix it
test_a_broken_theme_file_is_reported() {
  printf '{"name": "Broken",\n' >"$(vscode_theme broken)"
  run_jenerate sunset
  assert_status 1
  assert_contains "jenerated-broken-color-theme.json: not a valid theme file"
  assert_contains "Regenerate it with ./jenerate.py, or delete it."
}

# GIVEN a VS Code theme file with no name
# WHEN generating Sunset
# THEN it exits with status 1, naming the file
test_a_theme_file_without_a_name_is_reported() {
  printf '{"type": "dark"}\n' >"$(vscode_theme nameless)"
  run_jenerate sunset
  assert_status 1
  assert_contains "jenerated-nameless-color-theme.json: not a valid theme file"
}

# GIVEN a VS Code theme file with broken JSON
# WHEN removing that palette
# THEN the file is deleted and package.json is rebuilt without errors
test_removing_a_broken_theme_fixes_it() {
  printf '{"name": "Broken",\n' >"$(vscode_theme broken)"
  run_jenerate --remove broken
  assert_status 0
  assert_contains "Removed app-themes/vs-code-theme/themes/jenerated-broken-color-theme.json"
}

# GIVEN Sunset has been generated
# WHEN generating it again
# THEN package.json isn't rewritten
test_package_json_is_not_rewritten_when_unchanged() {
  run_jenerate sunset
  run_jenerate sunset
  assert_status 0
  assert_not_contains "Updated"
}

# --- Tests: removing ---------------------------------------------------------

# GIVEN Sunset has been generated
# WHEN removing Sunset
# THEN its generated files are deleted and its palette is kept
test_remove_deletes_the_themes() {
  run_jenerate sunset
  run_jenerate --remove sunset
  assert_status 0
  assert_contains "Removed app-themes/slack-theme/sunset.txt"
  assert_missing "$(vscode_theme sunset)"
  assert_missing "$(ptyxis_palette sunset)"
  assert_missing "$(slack_theme sunset)"
  assert_exists "$SANDBOX/repo/palettes/sunset-palette.toml"
}

# GIVEN Sunset has been generated
# WHEN removing Sunset
# THEN package.json lists only Blue Purple
test_remove_updates_package_json() {
  run_jenerate sunset
  run_jenerate --remove sunset
  labels="$(package_labels)"
  [ "$labels" = "Jenerated Blue Purple" ] ||
    fail "expected package.json to list only Blue Purple, got: $labels"
}

# GIVEN Sunset has been generated
# WHEN removing Sunset
# THEN Blue Purple's files are kept
test_remove_leaves_other_palettes_alone() {
  run_jenerate sunset
  run_jenerate --remove sunset
  assert_exists "$(slack_theme blue-purple)"
  assert_exists "$(vscode_theme blue-purple)"
}

# GIVEN Sunset hasn't been generated
# WHEN removing Sunset
# THEN it succeeds, saying there's nothing to remove
test_remove_something_not_generated() {
  run_jenerate --remove sunset
  assert_status 0
  assert_contains "sunset: nothing to remove"
}

# GIVEN a palette outside palettes/ whose slug differs from its file name has
#       been generated
# WHEN removing it by its path
# THEN the themes named after its slug are deleted
test_remove_by_path_uses_the_files_slug() {
  mkdir -p "$SANDBOX/elsewhere"
  write_palette "$SANDBOX/elsewhere/odd.toml" "Odd" "different-slug"
  run_jenerate "$SANDBOX/elsewhere/odd.toml"
  run_jenerate --remove "$SANDBOX/elsewhere/odd.toml"
  assert_status 0
  assert_missing "$(slack_theme different-slug)"
}

# --- Tests: bad palettes -----------------------------------------------------

# GIVEN twilight-palette.toml in palettes/ with the slug dusk
# WHEN generating twilight
# THEN it exits with status 1, asking for it to be renamed, and writes nothing
test_palette_file_name_must_match_its_slug() {
  write_palette "$SANDBOX/repo/palettes/twilight-palette.toml" "Twilight" "dusk"
  run_jenerate twilight
  assert_status 1
  assert_contains "twilight-palette.toml: palettes in palettes/ must be named after their slug; rename it to dusk-palette.toml"
  assert_missing "$(slack_theme dusk)"
}

# GIVEN twilight-palette.toml in palettes/ with the slug dusk
# WHEN running --list
# THEN it exits with status 1, asking for it to be renamed
test_list_reports_a_misnamed_palette() {
  write_palette "$SANDBOX/repo/palettes/twilight-palette.toml" "Twilight" "dusk"
  run_jenerate --list
  assert_status 1
  assert_contains "rename it to dusk-palette.toml"
}

# GIVEN a palette with accent = 5
# WHEN generating it
# THEN it exits with status 1, saying the color must be a quoted string
test_color_that_is_not_a_string() {
  printf 'name = "Numbers"\nslug = "numbers"\n[colors]\naccent = 5\n' \
    >"$SANDBOX/repo/palettes/numbers-palette.toml"
  run_jenerate numbers
  assert_status 1
  assert_contains 'color `accent` must be a quoted string'
}

# GIVEN a palette where colors is a string, not a table
# WHEN generating it
# THEN it exits with status 1, saying colors must be a [colors] table
test_colors_that_are_not_a_table() {
  printf 'name = "Flat"\nslug = "flat"\ncolors = "#123456"\n' \
    >"$SANDBOX/repo/palettes/flat-palette.toml"
  run_jenerate flat
  assert_status 1
  assert_contains '`colors` must be a [colors] table'
}

# GIVEN a palette that sets accent twice, which isn't valid TOML
# WHEN generating it
# THEN it exits with status 1 with a readable error, not a traceback
test_palette_with_a_syntax_error() {
  write_palette "$SANDBOX/repo/palettes/broken-palette.toml" "Broken" "broken" \
    'accent = "#123456"'
  run_jenerate broken
  assert_status 1
  assert_contains "broken-palette.toml: not a valid palette file: Cannot overwrite a value"
  assert_not_contains "Traceback"
}

# GIVEN a palette in palettes/ with an unclosed quote
# WHEN running --list
# THEN it exits with status 1 with a readable error, not a traceback
test_list_with_a_broken_palette() {
  printf 'name = "Broken\n' >"$SANDBOX/repo/palettes/broken-palette.toml"
  run_jenerate --list
  assert_status 1
  assert_contains "broken-palette.toml: not a valid palette file"
  assert_not_contains "Traceback"
}

# GIVEN a palette with no name
# WHEN generating it
# THEN it exits with status 1, saying the name is missing
test_palette_without_a_name() {
  grep -v '^name = ' "$SANDBOX/repo/palettes/sunset-palette.toml" \
    >"$SANDBOX/repo/palettes/broken-palette.toml"
  run_jenerate broken
  assert_status 1
  assert_contains 'missing top-level `name` string'
}

# GIVEN a palette with no slug
# WHEN generating it
# THEN it exits with status 1, saying the slug is missing
test_palette_without_a_slug() {
  grep -v '^slug = ' "$SANDBOX/repo/palettes/sunset-palette.toml" \
    >"$SANDBOX/repo/palettes/broken-palette.toml"
  run_jenerate broken
  assert_status 1
  assert_contains 'missing top-level `slug` string'
}

# GIVEN a color that refers to itself
# WHEN generating the palette
# THEN it exits with status 1, naming the color and the loop
test_color_that_refers_to_itself() {
  write_palette "$SANDBOX/repo/palettes/loop-palette.toml" "Loop" "loop" 'ouroboros = "ouroboros"'
  run_jenerate loop
  assert_status 1
  assert_contains 'color `ouroboros` refers to itself in a loop'
}

# GIVEN two colors that refer to each other
# WHEN generating the palette
# THEN it exits with status 1, reporting the loop
test_colors_that_refer_to_each_other_in_a_loop() {
  write_palette "$SANDBOX/repo/palettes/loop-palette.toml" "Loop" "loop" \
    'ping = "pong"' 'pong = "ping"'
  run_jenerate loop
  assert_status 1
  assert_contains "refers to itself in a loop"
}

# GIVEN a color set to 'blurple', which is neither #rrggbb nor another color
# WHEN generating the palette
# THEN it exits with status 1, naming the color and its value
test_color_that_is_not_hex_or_a_name() {
  write_palette "$SANDBOX/repo/palettes/bad-palette.toml" "Bad" "bad" 'mystery = "blurple"'
  run_jenerate bad
  assert_status 1
  assert_contains "color \`mystery\` = 'blurple' is not a #rrggbb value"
}

# GIVEN a color set to the short form '#fff'
# WHEN generating the palette
# THEN it exits with status 1, saying it's not a #rrggbb value
test_short_hex_is_rejected() {
  write_palette "$SANDBOX/repo/palettes/bad-palette.toml" "Bad" "bad" 'tiny = "#fff"'
  run_jenerate bad
  assert_status 1
  assert_contains "color \`tiny\` = '#fff' is not a #rrggbb value"
}

# GIVEN a palette with no accent color, which the templates need
# WHEN generating it
# THEN it exits with status 1, naming accent, and writes none of its files
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

# GIVEN the Tilix template has been deleted
# WHEN generating Sunset
# THEN it exits with status 1, naming the template, and writes none of
#      Sunset's files
test_missing_template_is_named_and_nothing_is_written() {
  rm "$SANDBOX/repo/app-themes/tilix-theme/scheme.json.tmpl"
  run_jenerate sunset
  assert_status 1
  assert_contains "app-themes/tilix-theme/scheme.json.tmpl: template not found"
  assert_missing "$(vscode_theme sunset)"
  assert_missing "$(slack_theme sunset)"
}

# GIVEN package.json.tmpl has been deleted
# WHEN generating Sunset
# THEN it exits with status 1, naming the template
test_missing_package_json_template_is_named() {
  rm "$SANDBOX/repo/app-themes/vs-code-theme/package.json.tmpl"
  run_jenerate sunset
  assert_status 1
  assert_contains "app-themes/vs-code-theme/package.json.tmpl: template not found"
}

# GIVEN a bad palette followed by Sunset
# WHEN generating bad,sunset
# THEN it exits with status 1 before generating Sunset
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

# GIVEN a palette with the slug ../../escaped
# WHEN generating it by its path
# THEN it exits with status 1 and writes nothing outside the repository
test_slug_cannot_escape_the_repository_when_generating() {
  write_unsafe_palette "../../escaped"
  run_jenerate "$SANDBOX/unsafe.toml"
  assert_status 1
  assert_contains "'../../escaped' is not a valid slug"
  assert_missing "$SANDBOX/escaped.palette"
  assert_missing "$SANDBOX/escaped.txt"
}

# GIVEN a palette with the slug ../../escaped, and files outside the repository
#       that the slug points at
# WHEN removing it by its path
# THEN it exits with status 1 and those files are kept
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

# GIVEN palettes with slugs using capitals, spaces, underscores, slashes, stray
#       dashes, nothing, or a dot
# WHEN generating each
# THEN every one is rejected as not a valid slug
test_slugs_must_be_lowercase_words_and_dashes() {
  for slug in "Sunset" "sun set" "sun_set" "sun/set" "-sunset" "sunset-" "sun--set" "" "."; do
    write_unsafe_palette "$slug"
    run_jenerate "$SANDBOX/unsafe.toml"
    assert_status 1
    assert_contains "is not a valid slug"
  done
}

# GIVEN palettes with slugs of lowercase letters, numbers and single dashes
# WHEN generating each
# THEN every one is generated
test_valid_slugs_are_accepted() {
  for slug in "a" "sunset2" "deep-blue-sea" "80s-neon"; do
    write_unsafe_palette "$slug"
    run_jenerate "$SANDBOX/unsafe.toml"
    assert_status 0
    assert_exists "$(slack_theme "$slug")"
  done
}

# GIVEN slugs typed on the command line
# WHEN removing '..' or generating 'Sunset'
# THEN both are rejected as not valid slugs
test_slug_on_the_command_line_is_checked() {
  run_jenerate --remove ..
  assert_status 1
  assert_contains "'..' is not a valid slug"
  run_jenerate Sunset
  assert_status 1
  assert_contains "'Sunset' is not a valid slug"
}

# GIVEN a palette whose name contains a double quote
# WHEN generating it
# THEN it exits with status 1 and writes no VS Code theme
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

# GIVEN a palette whose name has a line break followed by a Ptyxis setting
# WHEN generating it
# THEN it exits with status 1 and writes no Ptyxis palette
test_name_cannot_contain_a_line_break() {
  write_palette "$SANDBOX/repo/palettes/evil-palette.toml" 'Evil\\nBackground=#ff0000' "evil"
  run_jenerate evil
  assert_status 1
  assert_contains "\`name\` can't contain quotes, slashes, backslashes or line breaks"
  assert_missing "$(ptyxis_palette evil)"
}

# GIVEN a palette whose name contains a backslash
# WHEN generating it
# THEN it exits with status 1, explaining which characters aren't allowed
test_name_cannot_contain_a_backslash() {
  write_palette "$SANDBOX/repo/palettes/evil-palette.toml" 'Evil\\\\' "evil"
  run_jenerate evil
  assert_status 1
  assert_contains "\`name\` can't contain quotes, slashes, backslashes or line breaks"
}

# GIVEN a palette whose name contains a slash
# WHEN generating it
# THEN it exits with status 1, explaining which characters aren't allowed
test_name_cannot_contain_a_slash() {
  # The name also names the Obsidian theme's folder.
  write_palette "$SANDBOX/repo/palettes/evil-palette.toml" 'Night/Day' "evil"
  run_jenerate evil
  assert_status 1
  assert_contains "\`name\` can't contain quotes, slashes, backslashes or line breaks"
}

# GIVEN palettes whose names are empty, only spaces, or start or end with a
#       space
# WHEN generating each
# THEN every one is rejected, and no themes are written
test_name_cannot_be_empty_or_padded() {
  for name in "" "   " " Sunset" "Sunset "; do
    write_palette "$SANDBOX/repo/palettes/blank-palette.toml" "$name" "blank"
    run_jenerate blank
    assert_status 1
    assert_contains "\`name\` can't be empty or start or end with spaces"
    assert_missing "$(obsidian_theme blank)"
  done
}

# GIVEN a palette named Café d'Or (Night)
# WHEN generating it
# THEN it succeeds, the VS Code theme is valid JSON and Ptyxis shows the name as
#      is
test_name_may_use_other_characters() {
  write_palette "$SANDBOX/repo/palettes/cafe-palette.toml" "Café d'Or (Night)" "cafe"
  run_jenerate cafe
  assert_status 0
  assert_valid_json "$(vscode_theme cafe)"
  assert_file_contains "$(ptyxis_palette cafe)" "Name=Café d'Or (Night)"
}

run_tests
