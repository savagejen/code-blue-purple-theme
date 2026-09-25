#!/usr/bin/env bash
# Tests for palette-creator/serve.py.
#
# Usage: tests/palette-creator/test_palette_creator.sh
#
# Each test starts serve.py from a throwaway copy of the repository, on a free
# port, and talks to it with curl. Needs Python 3.11 or later and curl; the
# tests are skipped without them.

source "$(dirname "$0")/../lib.sh"

PYTHON="$(find_python)"
if [ -z "$PYTHON" ] || ! command -v curl >/dev/null 2>&1; then
  printf 'skipped: the Palette Creator tests need Python 3.11 or later and curl\n'
  exit 0
fi

WIP_REL="palette-creator/work-in-progress-palette.toml"

# start_server -> starts serve.py in the sandbox and waits until it answers.
# Sets PORT, and stops the server when the test ends. Fake commands in
# $SANDBOX/bin come first on its PATH. Save dialogs are off (so a test never
# opens a real one) unless the test sets DIALOG="" and fakes one.
start_server() {
  PORT="$("$PYTHON" -c '
import socket
s = socket.socket()
s.bind(("127.0.0.1", 0))
print(s.getsockname()[1])
')"
  PALETTE_CREATOR_DIALOG="${DIALOG-none}" PATH="$SANDBOX/bin:$PATH" \
    "$PYTHON" "$SANDBOX/repo/palette-creator/serve.py" --no-browser --port "$PORT" \
    >"$SANDBOX/server.log" 2>&1 &
  SERVER_PID=$!
  trap 'kill "$SERVER_PID" 2>/dev/null; rm -rf "$SANDBOX"' EXIT
  for _ in $(seq 100); do
    curl -s -o /dev/null "http://127.0.0.1:$PORT/" && return
    "$PYTHON" -c 'import time; time.sleep(0.05)'
  done
  fail "serve.py didn't start: $(cat "$SANDBOX/server.log")"
}

# get path [curl options...] -> sets OUTPUT to the body and CODE to the status.
get() {
  local path="$1"
  shift
  OUTPUT="$(curl -s -w '\n%{http_code}' "$@" "http://127.0.0.1:$PORT$path")"
  CODE="${OUTPUT##*$'\n'}"
  OUTPUT="${OUTPUT%$'\n'*}"
}

# post path json [curl options...] -> posts JSON; sets OUTPUT and CODE.
post() {
  local path="$1" body="$2"
  shift 2
  get "$path" -X POST -H "Content-Type: application/json" --data-binary "$body" "$@"
}

# json expression -> prints a Python expression over the response, as `d`.
json() {
  printf '%s' "$OUTPUT" | "$PYTHON" -c "
import json, sys
d = json.load(sys.stdin)
print($1)
"
}

# palette_body [slug] [python...] -> prints {"palette": ...} for the
# work-in-progress palette, or with a slug, for that palette in palettes/
# after loading it into the work in progress (as "Load from" does). The Python
# statements can change it as `p`. Extra JSON fields can be set on `b`.
palette_body() {
  local script="${2:-}" response
  if [ -n "${1:-}" ]; then
    response="$(curl -s -X POST -H "Content-Type: application/json" \
      --data-binary "{\"filename\": \"$1-palette.toml\"}" "http://127.0.0.1:$PORT/api/load")"
  else
    response="$(curl -s "http://127.0.0.1:$PORT/api/palette")"
  fi
  printf '%s' "$response" | "$PYTHON" -c "
import json, sys
p = json.load(sys.stdin)['palette']
b = {}
colors = {c['key']: c for g in p['groups'] for c in g['colors']}
$script
b['palette'] = p
print(json.dumps(b))
"
}

assert_code() {
  [ "$CODE" = "$1" ] || fail "expected HTTP $1, got $CODE"
}

# assert_json expression expected
assert_json() {
  local actual
  actual="$(json "$1")"
  [ "$actual" = "$2" ] || fail "expected $1 to be '$2', got '$actual'"
}

# --- Tests: starting ---------------------------------------------------------

# GIVEN no work-in-progress palette yet
# WHEN serve.py starts
# THEN it creates one from Blue Purple and says so
test_first_start_creates_the_work_in_progress_palette() {
  start_server
  assert_same_file "$SANDBOX/repo/$WIP_REL" "$SANDBOX/repo/palettes/blue-purple-palette.toml"
  OUTPUT="$(cat "$SANDBOX/server.log")"
  assert_contains "Created $WIP_REL from Blue Purple"
  assert_contains "Palette Creator is running at http://127.0.0.1:$PORT/"
}

# GIVEN a work-in-progress palette made from Sunset
# WHEN serve.py starts
# THEN it keeps that palette and serves it
test_start_keeps_an_existing_work_in_progress_palette() {
  cp "$SANDBOX/repo/palettes/sunset-palette.toml" "$SANDBOX/repo/$WIP_REL"
  start_server
  assert_same_file "$SANDBOX/repo/$WIP_REL" "$SANDBOX/repo/palettes/sunset-palette.toml"
  get /api/palette
  assert_json 'd["palette"]["name"]' "Sunset"
}

# GIVEN serve.py is running on a port
# WHEN a second serve.py tries the same port
# THEN it exits with status 1, suggesting another port
test_port_in_use_is_reported() {
  start_server
  OUTPUT="$("$PYTHON" "$SANDBOX/repo/palette-creator/serve.py" --no-browser --port "$PORT" 2>&1)"
  STATUS=$?
  assert_status 1
  assert_contains "Can't use port $PORT"
  assert_contains "try another with --port"
}

# GIVEN serve.py is running
# WHEN the browser asks for the page
# THEN it gets the Palette Creator page
test_serves_the_page() {
  start_server
  get /
  assert_code 200
  assert_contains "<title>Palette Creator</title>"
}

# GIVEN serve.py is running
# WHEN asking for a path it doesn't have
# THEN it answers 404
test_unknown_path_is_not_found() {
  start_server
  get /palette-creator/serve.py
  assert_code 404
  post /api/nothing '{"palette": {}}'
  assert_code 404
}

# --- Tests: loading ----------------------------------------------------------

# GIVEN the work-in-progress palette is Blue Purple
# WHEN the page loads it
# THEN it gets the header comments, name, slug, and colors in their titled
#      groups, with notes and references kept as written
test_loads_the_palette_with_its_groups_and_notes() {
  start_server
  get /api/palette
  assert_code 200
  assert_json 'd["source"]' "$WIP_REL"
  assert_json 'd["palette"]["header"][0]' "Dark blue/purple with high contrast text and a near-black 'midnight'"
  assert_json 'd["palette"]["description"]' "Dark blue/purple with high contrast text and a near-black 'midnight' background."
  assert_json 'd["palette"]["slug"]' "blue-purple"
  assert_json '[g["title"] for g in d["palette"]["groups"]][0]' "Backgrounds, darkest to lightest"
  assert_json 'len(d["palette"]["groups"])' "6"
  assert_json 'd["palette"]["groups"][0]["colors"][0]' \
    "{'key': 'bg_chrome', 'value': '#0a0b13', 'note': 'activity bar, title bar, status bar'}"
  assert_json '[c for g in d["palette"]["groups"] for c in g["colors"] if c["key"] == "term_red"][0]["value"]' "red"
}

# GIVEN a work-in-progress palette that isn't valid TOML
# WHEN the page loads it
# THEN it answers 422 with the error and the file's name, so the page can
#      offer to load another palette
test_broken_work_in_progress_palette_is_reported() {
  printf 'name = "Broken\n' >"$SANDBOX/repo/$WIP_REL"
  start_server
  get /api/palette
  assert_code 422
  assert_json 'd["source"]' "$WIP_REL"
  assert_contains "not a valid palette file"
}

# --- Tests: saving the work in progress --------------------------------------

# GIVEN the work-in-progress palette is Blue Purple
# WHEN saving it without changes
# THEN the file is byte for byte the same as Blue Purple's palette
test_saving_unchanged_keeps_the_file_exactly() {
  start_server
  post /api/save "$(palette_body)"
  assert_json 'd["ok"]' "True"
  assert_same_file "$SANDBOX/repo/$WIP_REL" "$SANDBOX/repo/palettes/blue-purple-palette.toml"
}

# GIVEN Sunset has been loaded into the work in progress
# WHEN saving the work-in-progress file
# THEN it's byte for byte the same as Sunset's palette, comments and all
test_saving_a_palette_started_from_sunset() {
  start_server
  post /api/save "$(palette_body sunset)"
  assert_json 'd["ok"]' "True"
  assert_json 'd["message"]' "Saved $WIP_REL"
  assert_same_file "$SANDBOX/repo/$WIP_REL" "$SANDBOX/repo/palettes/sunset-palette.toml"
}

# GIVEN the accent is changed to #123456
# WHEN saving
# THEN only that value changes, with its note still lined up
test_saving_a_change_keeps_the_layout() {
  start_server
  post /api/save "$(palette_body "" 'colors["accent"]["value"] = "#123456"')"
  assert_json 'd["ok"]' "True"
  assert_file_contains "$SANDBOX/repo/$WIP_REL" 'accent = "#123456"             # cursor, focus, buttons, badges'
  changed="$(diff "$SANDBOX/repo/$WIP_REL" "$SANDBOX/repo/palettes/blue-purple-palette.toml" | grep -c '^[<>]')"
  [ "$changed" = "2" ] || fail "expected one line to change, got $changed changed lines"
}

# GIVEN a color set to something that isn't a color
# WHEN saving
# THEN it's refused with jenerate.py's message, and the file is unchanged
test_saving_an_invalid_palette_changes_nothing() {
  start_server
  post /api/save "$(palette_body "" 'colors["accent"]["value"] = "blue-purple"')"
  assert_json 'd["ok"]' "False"
  assert_json 'd["error"]' "color \`accent\` = 'blue-purple' is not a #rrggbb value or the name of another color"
  assert_same_file "$SANDBOX/repo/$WIP_REL" "$SANDBOX/repo/palettes/blue-purple-palette.toml"
}

# --- Tests: the description --------------------------------------------------

# The color note that ends every palette's header comment.
COLOR_NOTE='# Every color is a #rrggbb hex value, or the name of another color in this
# file. Templates add transparency themselves (e.g. {{accent}}33).'

# header_of file -> prints a palette file's header comment (the lines before
# its name).
header_of() {
  sed '/^name = /,$d' "$1" | sed '$d'
}

# GIVEN the work-in-progress palette
# WHEN changing its description and saving
# THEN the header comment becomes the new description, then a blank comment
#      line, then the color note, and the rest of the file is unchanged
test_changing_the_description_rewrites_the_header() {
  start_server
  post /api/save "$(palette_body "" 'p["description"] = "A new description."')"
  assert_json 'd["ok"]' "True"
  expected="# A new description.
#
$COLOR_NOTE"
  [ "$(header_of "$SANDBOX/repo/$WIP_REL")" = "$expected" ] ||
    fail "unexpected header: $(header_of "$SANDBOX/repo/$WIP_REL")"
  diff <(sed -n '/^name = /,$p' "$SANDBOX/repo/$WIP_REL") \
    <(sed -n '/^name = /,$p' "$SANDBOX/repo/palettes/blue-purple-palette.toml") >/dev/null ||
    fail "expected everything after the header to be unchanged"
}

# GIVEN a long description with two paragraphs, typed with Windows line
#       endings
# WHEN saving
# THEN each paragraph is wrapped to fit 78 columns, the paragraphs are
#      separated by a blank comment line, and loading it gives the
#      description back
test_long_descriptions_are_wrapped_by_paragraph() {
  start_server
  post /api/save "$(palette_body "" 'p["description"] = "A long first paragraph that goes on well past the width of one line in a palette file, so it has to wrap.\r\n\r\nA second paragraph."')"
  assert_json 'd["ok"]' "True"
  long="$(header_of "$SANDBOX/repo/$WIP_REL" | awk 'length > 78' | wc -l | tr -d ' ')"
  [ "$long" = "0" ] || fail "expected every header line to fit 78 columns"
  expected="# A long first paragraph that goes on well past the width of one line in a
# palette file, so it has to wrap.
#
# A second paragraph.
#
$COLOR_NOTE"
  [ "$(header_of "$SANDBOX/repo/$WIP_REL")" = "$expected" ] ||
    fail "unexpected header: $(header_of "$SANDBOX/repo/$WIP_REL")"
  get /api/palette
  assert_json 'd["palette"]["description"]' "A long first paragraph that goes on well past the width of one line in a palette file, so it has to wrap.

A second paragraph."
}

# GIVEN the work-in-progress palette
# WHEN emptying its description and saving
# THEN the header comment is just the color note
test_an_empty_description_leaves_the_color_note() {
  start_server
  post /api/save "$(palette_body "" 'p["description"] = ""')"
  assert_json 'd["ok"]' "True"
  [ "$(header_of "$SANDBOX/repo/$WIP_REL")" = "$COLOR_NOTE" ] ||
    fail "unexpected header: $(header_of "$SANDBOX/repo/$WIP_REL")"
}

# GIVEN a description with a tab in it
# WHEN checking the palette
# THEN it's refused, saying why
test_descriptions_cant_have_control_characters() {
  start_server
  post /api/check "$(palette_body "" 'p["description"] = "Tab\there"')"
  assert_json 'd["error"]' "the description can't contain tabs or other control characters"
}

# GIVEN Sunset loaded into the work in progress
# WHEN saving it as a palette with a new description
# THEN the saved palette has the new description
test_save_as_palette_keeps_the_description() {
  start_server
  post /api/save "$(palette_body sunset 'p["description"] = "Sunset, described again."; b["target"] = "palette"; b["filename"] = "sunset-palette.toml"; b["overwrite"] = True')"
  assert_json 'd["ok"]' "True"
  assert_file_contains "$SANDBOX/repo/palettes/sunset-palette.toml" "# Sunset, described again."
}

# GIVEN a palette that says scheme = "light"
# WHEN loading it and saving it unchanged
# THEN the scheme line is kept, and the file is byte for byte the same
test_the_scheme_setting_is_kept() {
  { sed -n '1,/^slug = /p' "$SANDBOX/repo/palettes/sunset-palette.toml"
    echo 'scheme = "light"'
    sed '1,/^slug = /d' "$SANDBOX/repo/palettes/sunset-palette.toml"; } >"$SANDBOX/repo/palettes/lit-palette.toml"
  sed -i 's/^slug = .*/slug = "lit"/' "$SANDBOX/repo/palettes/lit-palette.toml"
  start_server
  post /api/load '{"filename": "lit-palette.toml"}'
  assert_json 'd["palette"]["scheme"]' "light"
  post /api/save "$(palette_body)"
  assert_json 'd["ok"]' "True"
  assert_same_file "$SANDBOX/repo/$WIP_REL" "$SANDBOX/repo/palettes/lit-palette.toml"
}

# --- Tests: checking ---------------------------------------------------------

# GIVEN the work-in-progress palette
# WHEN the page checks it
# THEN it's accepted
test_check_accepts_a_valid_palette() {
  start_server
  post /api/check "$(palette_body)"
  assert_code 200
  assert_json 'd' "{'ok': True}"
}

# GIVEN colors that refer to each other in a loop
# WHEN the page checks the palette
# THEN it's refused with jenerate.py's message, without a temporary file's
#      path in it
test_check_reports_a_loop() {
  start_server
  post /api/check "$(palette_body "" 'colors["text"]["value"] = "term_white"')"
  assert_json 'd["ok"]' "False"
  assert_contains "refers to itself in a loop"
  assert_not_contains "palette.toml:"
  assert_not_contains "/tmp"
}

# GIVEN the accent color has been removed
# WHEN the page checks the palette
# THEN it's refused, naming the color the templates need
test_check_reports_a_color_the_templates_need() {
  start_server
  post /api/check "$(palette_body "" '
for g in p["groups"]:
    g["colors"] = [c for c in g["colors"] if c["key"] != "accent"]
for c in colors.values():
    if c["value"] == "accent":
        c["value"] = "#5865F3"
')"
  assert_json 'd["ok"]' "False"
  assert_contains "the palette has no color named accent"
}

# GIVEN a name with a double quote, then a slug with capitals
# WHEN the page checks each
# THEN each is refused with jenerate.py's message
test_check_reports_bad_names_and_slugs() {
  start_server
  post /api/check "$(palette_body "" 'p["name"] = "Evil\"Name"')"
  assert_json 'd["error"]' "\`name\` can't contain quotes, slashes, backslashes, <, >, & or line breaks"
  post /api/check "$(palette_body "" 'p["slug"] = "Not-A-Slug"')"
  assert_contains "'Not-A-Slug' is not a valid slug"
}

# GIVEN a note with a line break, a color defined twice, and a color name with
#       a dash
# WHEN the page checks each
# THEN each is refused, saying what's wrong
test_check_reports_bad_notes_and_color_names() {
  start_server
  post /api/check "$(palette_body "" 'colors["accent"]["note"] = "two\nlines"')"
  assert_json 'd["error"]' "The note for \`accent\` can't contain line breaks"
  post /api/check "$(palette_body "" 'p["groups"][0]["colors"].append(dict(colors["accent"]))')"
  assert_json 'd["error"]' "color \`accent\` is defined twice"
  post /api/check "$(palette_body "" 'p["groups"][0]["colors"].append({"key": "bad-key", "value": "#000000", "note": ""})')"
  assert_json 'd["error"]' "'bad-key' can't be a color name (use letters, numbers and underscores)"
}

# GIVEN a palette with its groups missing
# WHEN the page checks it
# THEN it's refused as incomplete, not with a crash
test_check_reports_an_incomplete_palette() {
  start_server
  post /api/check '{"palette": {"name": "X", "slug": "x"}}'
  assert_code 200
  assert_json 'd["error"]' "the palette sent by the page is incomplete"
}

# --- Tests: saving as a palette ----------------------------------------------

# fake_dialog exit-status [path] -> fakes the save dialogs (zenity, kdialog and
# osascript): each records its arguments in $SANDBOX/dialog-args, prints the
# path as the chosen file, and exits with the status. Turns dialogs on.
fake_dialog() {
  for tool in zenity kdialog osascript; do
    fake_command "$tool" "printf '%s\n' \"\$@\" >\"$SANDBOX/dialog-args\"
printf '%s\n' '${2:-}'
exit $1"
  done
  DIALOG=""
}

FOREST='p["name"] = "Forest"; p["slug"] = "forest"; b["target"] = "palette"'

# GIVEN no save dialog
# WHEN saving a palette with the slug forest as a palette
# THEN it asks the page for a file name, suggesting forest-palette.toml, and
#      writes nothing yet
test_save_as_palette_without_a_dialog_asks_for_a_name() {
  start_server
  post /api/save "$(palette_body "" "$FOREST")"
  assert_json 'd["ok"]' "False"
  assert_json 'd["choose_name"]' "True"
  assert_json 'd["default"]' "forest-palette.toml"
  assert_missing "$SANDBOX/repo/palettes/forest-palette.toml"
}

# GIVEN no save dialog, and the page has asked for a name
# WHEN saving as forest-palette.toml
# THEN palettes/forest-palette.toml is written, the message says how to
#      generate it, and jenerate.py can generate it
test_save_as_palette_with_a_typed_name() {
  start_server
  post /api/save "$(palette_body "" "$FOREST; b['filename'] = 'forest-palette.toml'")"
  assert_json 'd["ok"]' "True"
  assert_json 'd["message"]' "Saved palettes/forest-palette.toml. Generate its themes with: ./jenerate.py forest"
  assert_file_contains "$SANDBOX/repo/palettes/forest-palette.toml" 'name = "Forest"'
  OUTPUT="$(cd "$SANDBOX/repo" && "$PYTHON" jenerate.py forest 2>&1)"
  assert_contains "Generated Forest (forest)"
}

# GIVEN Sunset's palette exists, and no save dialog
# WHEN saving a changed Sunset as sunset-palette.toml, first without and then
#      with permission to replace it
# THEN the first save asks, leaving the file alone, and the second replaces it
test_save_as_palette_asks_before_replacing() {
  start_server
  cp "$SANDBOX/repo/palettes/sunset-palette.toml" "$SANDBOX/sunset-before.toml"
  changed='colors["accent"]["value"] = "#123456"; b["target"] = "palette"; b["filename"] = "sunset-palette.toml"'
  post /api/save "$(palette_body sunset "$changed")"
  assert_json 'd["ok"]' "False"
  assert_json 'd["exists"]' "True"
  assert_json 'd["message"]' "palettes/sunset-palette.toml already exists"
  assert_same_file "$SANDBOX/repo/palettes/sunset-palette.toml" "$SANDBOX/sunset-before.toml"
  post /api/save "$(palette_body sunset "$changed; b['overwrite'] = True")"
  assert_json 'd["ok"]' "True"
  assert_file_contains "$SANDBOX/repo/palettes/sunset-palette.toml" 'accent = "#123456"'
}

# GIVEN Sunset's palette exists, and no save dialog
# WHEN saving it unchanged as sunset-palette.toml
# THEN it's saved without asking, since nothing would be lost
test_save_as_palette_unchanged_doesnt_ask() {
  start_server
  post /api/save "$(palette_body sunset 'b["target"] = "palette"; b["filename"] = "sunset-palette.toml"')"
  assert_json 'd["ok"]' "True"
  assert_same_file "$SANDBOX/repo/palettes/sunset-palette.toml" "$REPO/palettes/sunset-palette.toml"
}

# GIVEN no save dialog
# WHEN typing a name with a folder in it, a name in palettes/ that doesn't
#      match the slug, or a name without .toml
# THEN each is refused, saying why, and nothing is written
test_save_as_palette_refuses_unusable_typed_names() {
  start_server
  post /api/save "$(palette_body "" "$FOREST; b['filename'] = '../forest-palette.toml'")"
  assert_json 'd["error"]' "type just a file name, of a file in palettes/"
  assert_missing "$SANDBOX/repo/forest-palette.toml"
  post /api/save "$(palette_body "" "$FOREST; b['filename'] = 'woods.toml'")"
  assert_contains "has to be named forest-palette.toml"
  assert_missing "$SANDBOX/repo/palettes/woods.toml"
  post /api/save "$(palette_body "" "$FOREST; b['filename'] = 'forest-palette.txt'")"
  assert_json 'd["error"]' "forest-palette.txt: palette files need to end in .toml"
}

# GIVEN a save dialog
# WHEN saving a palette with the slug forest as a palette
# THEN the dialog opens in palettes/ suggesting forest-palette.toml, and the
#      file it returns is written
test_save_as_palette_opens_the_dialog_in_palettes() {
  fake_dialog 0 "$SANDBOX/repo/palettes/forest-palette.toml"
  start_server
  post /api/save "$(palette_body "" "$FOREST")"
  assert_json 'd["ok"]' "True"
  assert_json 'd["message"]' "Saved palettes/forest-palette.toml. Generate its themes with: ./jenerate.py forest"
  assert_file_contains "$SANDBOX/dialog-args" "$SANDBOX/repo/palettes"
  assert_file_contains "$SANDBOX/dialog-args" "forest-palette.toml"
  assert_file_contains "$SANDBOX/repo/palettes/forest-palette.toml" 'slug = "forest"'
}

# GIVEN a save dialog, where a folder outside palettes/ is chosen
# WHEN saving as a palette
# THEN it's saved there, and the message gives jenerate.py its path
test_save_as_palette_somewhere_else() {
  mkdir -p "$SANDBOX/My Palettes"
  fake_dialog 0 "$SANDBOX/My Palettes/woods.toml"
  start_server
  post /api/save "$(palette_body "" "$FOREST")"
  assert_json 'd["ok"]' "True"
  assert_json 'd["message"]' "Saved $SANDBOX/My Palettes/woods.toml. Generate its themes with: ./jenerate.py $SANDBOX/My Palettes/woods.toml"
  assert_file_contains "$SANDBOX/My Palettes/woods.toml" 'slug = "forest"'
}

# GIVEN a save dialog that's cancelled
# WHEN saving as a palette
# THEN nothing is written, and the page is told it wasn't saved
test_save_as_palette_dialog_cancelled() {
  fake_dialog 1
  start_server
  post /api/save "$(palette_body "" "$FOREST")"
  assert_json 'd["ok"]' "False"
  assert_json 'd["cancelled"]' "True"
  assert_missing "$SANDBOX/repo/palettes/forest-palette.toml"
}

# GIVEN a save dialog, where a name in palettes/ that doesn't match the slug
#       is chosen
# WHEN saving as a palette
# THEN it's refused, since jenerate.py couldn't find it, and nothing is
#      written
test_save_as_palette_dialog_refuses_a_misnamed_palette() {
  fake_dialog 0 "$SANDBOX/repo/palettes/woods.toml"
  start_server
  post /api/save "$(palette_body "" "$FOREST")"
  assert_json 'd["ok"]' "False"
  assert_contains "has to be named forest-palette.toml"
  assert_missing "$SANDBOX/repo/palettes/woods.toml"
}

# --- Tests: loading a palette ------------------------------------------------

# GIVEN no file dialog
# WHEN the page asks to load a palette
# THEN it's asked to pick a name from the palettes in palettes/, and the work
#      in progress is left alone
test_load_without_a_dialog_asks_for_a_name() {
  start_server
  post /api/load '{}'
  assert_json 'd["ok"]' "False"
  assert_json 'd["choose_name"]' "True"
  assert_json '"blue-purple-palette.toml" in d["palettes"] and "sunset-palette.toml" in d["palettes"]' "True"
  assert_same_file "$SANDBOX/repo/$WIP_REL" "$SANDBOX/repo/palettes/blue-purple-palette.toml"
}

# GIVEN no file dialog, and the page has asked for a name
# WHEN loading sunset-palette.toml
# THEN the work-in-progress file becomes an exact copy of Sunset's palette,
#      the page gets Sunset back, and later loads of the work in progress get
#      Sunset too
test_load_a_typed_name_replaces_the_work_in_progress() {
  start_server
  post /api/load '{"filename": "sunset-palette.toml"}'
  assert_json 'd["ok"]' "True"
  assert_json 'd["message"]' "Loaded palettes/sunset-palette.toml into the work-in-progress palette."
  assert_json 'd["palette"]["name"]' "Sunset"
  assert_same_file "$SANDBOX/repo/$WIP_REL" "$SANDBOX/repo/palettes/sunset-palette.toml"
  get /api/palette
  assert_json 'd["palette"]["name"]' "Sunset"
}

# GIVEN a file dialog
# WHEN the page asks to load a palette
# THEN an open dialog (not a save dialog) starts in palettes/, and the file it
#      returns is loaded
test_load_opens_the_dialog_in_palettes() {
  fake_dialog 0 "$SANDBOX/repo/palettes/sunset-palette.toml"
  start_server
  post /api/load '{}'
  assert_json 'd["ok"]' "True"
  assert_file_contains "$SANDBOX/dialog-args" "$SANDBOX/repo/palettes"
  assert_file_not_contains "$SANDBOX/dialog-args" "--save"
  assert_same_file "$SANDBOX/repo/$WIP_REL" "$SANDBOX/repo/palettes/sunset-palette.toml"
}

# GIVEN a file dialog, where a palette outside palettes/ is chosen
# WHEN loading
# THEN it's copied into the work in progress, and the message gives its path
test_load_from_somewhere_else() {
  mkdir -p "$SANDBOX/My Palettes"
  sed -e 's/^name = .*/name = "Forest"/' -e 's/^slug = .*/slug = "forest"/' \
    "$SANDBOX/repo/palettes/sunset-palette.toml" >"$SANDBOX/My Palettes/woods.toml"
  fake_dialog 0 "$SANDBOX/My Palettes/woods.toml"
  start_server
  post /api/load '{}'
  assert_json 'd["ok"]' "True"
  assert_json 'd["message"]' "Loaded $SANDBOX/My Palettes/woods.toml into the work-in-progress palette."
  assert_same_file "$SANDBOX/repo/$WIP_REL" "$SANDBOX/My Palettes/woods.toml"
}

# GIVEN a file dialog that's cancelled
# WHEN loading
# THEN nothing changes, and the page is told nothing was loaded
test_load_dialog_cancelled() {
  fake_dialog 1
  start_server
  post /api/load '{}'
  assert_json 'd["ok"]' "False"
  assert_json 'd["cancelled"]' "True"
  assert_same_file "$SANDBOX/repo/$WIP_REL" "$SANDBOX/repo/palettes/blue-purple-palette.toml"
}

# GIVEN a palette with a syntax error, and one missing a color the templates
#       need
# WHEN loading each
# THEN each is refused with jenerate.py's message, and the work in progress is
#      left alone
test_load_refuses_a_palette_jenerate_would_reject() {
  printf 'name = "Broken\n' >"$SANDBOX/repo/palettes/broken-palette.toml"
  grep -v '^accent = ' "$SANDBOX/repo/palettes/sunset-palette.toml" |
    sed -e 's/^name = .*/name = "Holey"/' -e 's/^slug = .*/slug = "holey"/' \
      >"$SANDBOX/repo/palettes/holey-palette.toml"
  start_server
  post /api/load '{"filename": "broken-palette.toml"}'
  assert_json 'd["ok"]' "False"
  assert_contains "not a valid palette file"
  post /api/load '{"filename": "holey-palette.toml"}'
  assert_json 'd["ok"]' "False"
  assert_contains "the palette has no color named accent"
  assert_same_file "$SANDBOX/repo/$WIP_REL" "$SANDBOX/repo/palettes/blue-purple-palette.toml"
}

# GIVEN no file dialog
# WHEN typing a name with a folder in it, a file that isn't .toml, or one
#      that doesn't exist
# THEN each is refused, saying why, and the work in progress is left alone
test_load_refuses_unusable_typed_names() {
  start_server
  post /api/load '{"filename": "../palettes/sunset-palette.toml"}'
  assert_json 'd["error"]' "type just a file name, of a file in palettes/"
  post /api/load '{"filename": "notes.txt"}'
  assert_json 'd["error"]' "notes.txt: not a palette file (.toml)"
  post /api/load '{"filename": "nope-palette.toml"}'
  assert_json 'd["error"]' "nope-palette.toml: not a palette file (.toml)"
  assert_same_file "$SANDBOX/repo/$WIP_REL" "$SANDBOX/repo/palettes/blue-purple-palette.toml"
}

# GIVEN a load request from a page on another origin
# WHEN serve.py receives it
# THEN it refuses with 403 and loads nothing
test_refuses_loads_from_other_origins() {
  start_server
  post /api/load '{"filename": "sunset-palette.toml"}' -H "Origin: http://evil.example"
  assert_code 403
  assert_same_file "$SANDBOX/repo/$WIP_REL" "$SANDBOX/repo/palettes/blue-purple-palette.toml"
}

# GIVEN serve.py is running
# WHEN asking for the old palette list, or a palette to start from
# THEN neither exists any more (loading replaced them)
test_the_old_start_from_endpoints_are_gone() {
  start_server
  get /api/palettes
  assert_code 404
  get "/api/palette?from=sunset"
  assert_json 'd["palette"]["name"]' "Blue Purple"
}

# --- Tests: requests from other websites -------------------------------------

# GIVEN a save sent as plain text, which another website could send
# WHEN serve.py receives it
# THEN it refuses with 415 and saves nothing
test_refuses_saves_that_arent_json() {
  start_server
  get /api/save -X POST -H "Content-Type: text/plain" \
    --data-binary "$(palette_body "" 'colors["accent"]["value"] = "#123456"')"
  assert_code 415
  assert_same_file "$SANDBOX/repo/$WIP_REL" "$SANDBOX/repo/palettes/blue-purple-palette.toml"
}

# GIVEN a request with another site's Host (as in DNS rebinding)
# WHEN serve.py receives it
# THEN it refuses with 403
test_refuses_other_hosts() {
  start_server
  get / -H "Host: evil.example:$PORT"
  assert_code 403
}

# GIVEN a save from a page on another origin
# WHEN serve.py receives it
# THEN it refuses with 403 and saves nothing, while the same save from its
#      own page works
test_refuses_other_origins() {
  start_server
  body="$(palette_body "" 'colors["accent"]["value"] = "#123456"')"
  post /api/save "$body" -H "Origin: http://evil.example"
  assert_code 403
  assert_same_file "$SANDBOX/repo/$WIP_REL" "$SANDBOX/repo/palettes/blue-purple-palette.toml"
  post /api/save "$body" -H "Origin: http://127.0.0.1:$PORT"
  assert_code 200
  assert_file_contains "$SANDBOX/repo/$WIP_REL" 'accent = "#123456"'
}

run_tests
