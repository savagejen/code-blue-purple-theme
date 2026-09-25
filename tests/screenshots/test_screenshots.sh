#!/usr/bin/env bash
# Tests for palette-creator/screenshots.py.
#
# Usage: tests/screenshots/test_screenshots.sh
#
# Each test runs screenshots.py from a throwaway copy of the repository, with
# HOME pointed at an empty folder. The README update is tested directly
# (--readme-only). A full run uses fake node and npm commands, so no browser
# or network is needed: the fake node checks the Palette Creator is running,
# then writes placeholder screenshots. Needs Python 3.11 or later and curl.

source "$(dirname "$0")/../lib.sh"

PYTHON="$(find_python)"
if [ -z "$PYTHON" ] || ! command -v curl >/dev/null 2>&1; then
  printf 'skipped: the screenshot tests need Python 3.11 or later and curl\n'
  exit 0
fi

README_REL="palettes/README.md"

# run_screenshots [options...] -> runs screenshots.py in the sandbox, and sets
# OUTPUT and STATUS.
run_screenshots() {
  OUTPUT="$(cd "$SANDBOX/repo" && HOME="$SANDBOX/home" XDG_CACHE_HOME= \
    PATH="$SANDBOX/bin:$PATH" "$PYTHON" palette-creator/screenshots.py "$@" 2>&1)"
  STATUS=$?
}

# add_palette slug name [screenshot] -> adds a palette copied from Sunset,
# described as "The <name> palette, for testing.", and with "screenshot", a
# placeholder screenshot of it.
add_palette() {
  {
    printf '# The %s palette, for testing.\n' "$2"
    # Sunset's file from the end of its description on.
    sed -n '/^#$/,$p' "$SANDBOX/repo/palettes/sunset-palette.toml"
  } | sed -e "s/^name = .*/name = \"$2\"/" -e "s/^slug = .*/slug = \"$1\"/" \
    >"$SANDBOX/repo/palettes/$1-palette.toml"
  [ "${3:-}" = "screenshot" ] && printf 'png' >"$SANDBOX/repo/palettes/Screenshots/$1.png"
  return 0
}

# fake_playwright -> fakes npm (it "installs" Playwright into the prefix it's
# given) and node (it records its arguments, checks the Palette Creator
# answers at the address it's given, and writes a placeholder screenshot for
# each palette).
fake_playwright() {
  fake_command npm "prefix=''
while [ \$# -gt 0 ]; do [ \"\$1\" = --prefix ] && prefix=\"\$2\"; shift; done
mkdir -p \"\$prefix/node_modules/playwright\" \"\$prefix/node_modules/.bin\"
printf '#!/bin/sh\nexit 0\n' >\"\$prefix/node_modules/.bin/playwright\"
chmod +x \"\$prefix/node_modules/.bin/playwright\"
touch \"$SANDBOX/npm-ran\""
  fake_command node "base=\"\$2\"; out=\"\$3\"; shift 3
curl -s \"\$base/api/palette\" >\"$SANDBOX/node-saw\" || exit 1
printf '%s\n' \"\$@\" >\"$SANDBOX/node-palettes\"
for f in \"\$@\"; do printf 'new png' >\"\$out/\${f%-palette.toml}.png\"; done"
}

# --- Tests: updating the README ----------------------------------------------

# GIVEN the repository's README and screenshots
# WHEN updating the README
# THEN nothing changes, and it says the README is up to date
test_readme_already_up_to_date() {
  cp "$SANDBOX/repo/$README_REL" "$SANDBOX/before.md"
  run_screenshots --readme-only
  assert_status 0
  assert_contains "palettes/README.md is up to date"
  assert_same_file "$SANDBOX/repo/$README_REL" "$SANDBOX/before.md"
}

# GIVEN a new Forest palette with a screenshot
# WHEN updating the README
# THEN a section for it is added at the end, with its name, slug,
#      description, screenshot and key colors, and the rest is unchanged
test_readme_adds_a_section_for_a_new_palette() {
  cp "$SANDBOX/repo/$README_REL" "$SANDBOX/before.md"
  add_palette forest Forest screenshot
  run_screenshots --readme-only
  assert_status 0
  assert_contains "Updated palettes/README.md (added forest)"
  expected="## Forest

\`forest\`

The Forest palette, for testing.

![The Forest palette in the Palette Creator's preview](Screenshots/forest.png)

$(sed -n 's/^Editor .*Sidebar/&/p' "$SANDBOX/repo/$README_REL" | tail -n 1)"
  actual="$(sed -n '/^## Forest$/,$p' "$SANDBOX/repo/$README_REL")"
  [ "$actual" = "$expected" ] || fail "unexpected Forest section:
$actual"
  cmp -s <(head -c "$(wc -c <"$SANDBOX/before.md")" "$SANDBOX/repo/$README_REL") "$SANDBOX/before.md" ||
    fail "expected the existing README to be unchanged before the new section"
}

# GIVEN a new palette without a screenshot
# WHEN updating the README
# THEN no section is added, and it says why
test_readme_skips_a_palette_without_a_screenshot() {
  add_palette forest Forest
  run_screenshots --readme-only
  assert_status 0
  assert_contains "No screenshot of forest, so it isn't added to palettes/README.md"
  assert_file_not_contains "$SANDBOX/repo/$README_REL" "## Forest"
}

# GIVEN Sunset's accent has changed
# WHEN updating the README
# THEN only Sunset's key colors line changes, to the new accent
test_readme_refreshes_key_colors() {
  cp "$SANDBOX/repo/$README_REL" "$SANDBOX/before.md"
  sed 's/^accent = "#[0-9a-fA-F]*"/accent = "#123456"/' "$SANDBOX/repo/palettes/sunset-palette.toml" >"$SANDBOX/sunset.toml"
  cp "$SANDBOX/sunset.toml" "$SANDBOX/repo/palettes/sunset-palette.toml"
  run_screenshots --readme-only
  assert_status 0
  changed="$(diff "$SANDBOX/before.md" "$SANDBOX/repo/$README_REL" | grep '^>')"
  case "$changed" in
    "> Editor "*"Accent \`#123456\`"*) ;;
    *) fail "expected only Sunset's key colors to change, got: $changed" ;;
  esac
  [ "$(diff "$SANDBOX/before.md" "$SANDBOX/repo/$README_REL" | grep -c '^[<>]')" = "2" ] ||
    fail "expected exactly one line to change"
}

# GIVEN Aurora's palette has been deleted, but its README section and
#       screenshot remain
# WHEN updating the README
# THEN both are reported, and neither is removed
test_readme_reports_palettes_that_are_gone() {
  rm "$SANDBOX/repo/palettes/aurora-palette.toml"
  run_screenshots --readme-only
  assert_status 0
  assert_contains "palettes/README.md has a section for aurora, which isn't a palette any more"
  assert_contains "palettes/Screenshots/aurora.png is of aurora, which isn't a palette any more"
  assert_file_contains "$SANDBOX/repo/$README_REL" "## Aurora"
  assert_exists "$SANDBOX/repo/palettes/Screenshots/aurora.png"
}

# GIVEN an empty README
# WHEN updating it
# THEN it gets a heading and a section for every palette with a screenshot
test_readme_is_started_when_empty() {
  : >"$SANDBOX/repo/$README_REL"
  run_screenshots --readme-only
  assert_status 0
  assert_file_contains "$SANDBOX/repo/$README_REL" "# Palettes"
  for slug in $(cd "$SANDBOX/repo/palettes" && ls *-palette.toml | sed 's/-palette.toml//'); do
    assert_file_contains "$SANDBOX/repo/$README_REL" "](Screenshots/$slug.png)"
  done
}

# GIVEN a new palette with a screenshot
# WHEN updating the README twice
# THEN the second time changes nothing
test_readme_update_is_repeatable() {
  add_palette forest Forest screenshot
  run_screenshots --readme-only
  cp "$SANDBOX/repo/$README_REL" "$SANDBOX/after-first.md"
  run_screenshots --readme-only
  assert_contains "palettes/README.md is up to date"
  assert_same_file "$SANDBOX/repo/$README_REL" "$SANDBOX/after-first.md"
}

# --- Tests: taking screenshots -----------------------------------------------

# GIVEN a new Forest palette, and fake node and npm
# WHEN taking screenshots
# THEN Playwright is "installed" into ~/.cache, the Palette Creator is running
#      while node takes the screenshots, every palette gets one, Forest gets a
#      README section, and the repository's own draft is never created
test_full_run_takes_screenshots_and_updates_the_readme() {
  fake_playwright
  add_palette forest Forest
  run_screenshots
  assert_status 0
  assert_exists "$SANDBOX/npm-ran"
  assert_exists "$SANDBOX/home/.cache/jenerated-themes/playwright/node_modules/playwright"
  assert_file_contains "$SANDBOX/node-saw" '"palette"'
  for file in "$SANDBOX"/repo/palettes/*-palette.toml; do
    slug="$(basename "$file" -palette.toml)"
    assert_file_equals "$SANDBOX/repo/palettes/Screenshots/$slug.png" "new png"
  done
  assert_contains "Updated palettes/README.md (added forest)"
  assert_missing "$SANDBOX/repo/palette-creator/work-in-progress-palette.toml"
}

# GIVEN Playwright already installed in ~/.cache
# WHEN taking screenshots
# THEN npm isn't run again
test_full_run_reuses_an_installed_playwright() {
  fake_playwright
  mkdir -p "$SANDBOX/home/.cache/jenerated-themes/playwright/node_modules/playwright" \
    "$SANDBOX/home/.cache/jenerated-themes/playwright/node_modules/.bin"
  printf '#!/bin/sh\nexit 0\n' >"$SANDBOX/home/.cache/jenerated-themes/playwright/node_modules/.bin/playwright"
  chmod +x "$SANDBOX/home/.cache/jenerated-themes/playwright/node_modules/.bin/playwright"
  run_screenshots
  assert_status 0
  assert_missing "$SANDBOX/npm-ran"
  assert_file_equals "$SANDBOX/repo/palettes/Screenshots/sunset.png" "new png"
}

# GIVEN no node or npm
# WHEN taking screenshots
# THEN it stops, saying they're needed, before changing anything
test_full_run_needs_node() {
  mkdir -p "$SANDBOX/minbin"
  ln -s "$(command -v "$PYTHON")" "$SANDBOX/minbin/$PYTHON"
  cp "$SANDBOX/repo/palettes/Screenshots/sunset.png" "$SANDBOX/before.png"
  OUTPUT="$(cd "$SANDBOX/repo" && HOME="$SANDBOX/home" XDG_CACHE_HOME= PATH="$SANDBOX/minbin" \
    "$SANDBOX/minbin/$PYTHON" palette-creator/screenshots.py 2>&1)"
  STATUS=$?
  assert_status 1
  assert_contains "Updating screenshots needs Node.js and npm (for Playwright)"
  assert_same_file "$SANDBOX/repo/palettes/Screenshots/sunset.png" "$SANDBOX/before.png"
}

run_tests
