#!/usr/bin/env bash
# Tests for the git hooks in .githooks/.
#
# Usage: tests/hooks/test_hooks.sh
#
# Each test runs the hook from a throwaway copy of the repository, so the
# palettes it adds never touch the real one.

source "$(dirname "$0")/../lib.sh"

# run_hook -> runs the pre-commit hook in the sandbox and sets OUTPUT and
# STATUS.
run_hook() {
  OUTPUT="$(sh "$SANDBOX/repo/.githooks/pre-commit" 2>&1)"
  STATUS=$?
}

# write_palette_with slug accent -> writes palettes/<slug>-palette.toml, a
# copy of Sunset with the given accent color.
write_palette_with() {
  sed -e "s|^slug = .*|slug = \"$1\"|" -e "s|^accent = \"#[0-9a-fA-F]*\"|accent = \"$2\"|" \
    "$SANDBOX/repo/palettes/sunset-palette.toml" >"$SANDBOX/repo/palettes/$1-palette.toml"
}

# --- Tests: the colors to avoid ----------------------------------------------

# GIVEN the palettes in palettes/
# WHEN running the pre-commit hook
# THEN it allows the commit, since none of them uses a color to avoid
test_the_published_palettes_avoid_the_listed_colors() {
  run_hook
  assert_status 0
  [ -z "$OUTPUT" ] || fail "expected no output"
}

# GIVEN a palette whose accent is #0abab5, a listed color written in
#       lowercase
# WHEN running the pre-commit hook
# THEN it refuses the commit, naming the file, line and color
test_a_listed_color_is_refused() {
  write_palette_with teal "#0abab5"
  line="$(grep -n '^accent = ' "$SANDBOX/repo/palettes/teal-palette.toml" | cut -d: -f1)"
  run_hook
  assert_status 1
  assert_contains "These palettes use colors listed in palettes/avoid-these.txt:"
  assert_contains "palettes/teal-palette.toml:$line  #0abab5"
}

# GIVEN a palette whose accent is #0ABAB6, one digit off a listed color
# WHEN running the pre-commit hook
# THEN it allows the commit: only the exact codes are refused
test_a_nearby_shade_is_allowed() {
  write_palette_with teal "#0ABAB6"
  run_hook
  assert_status 0
}

# GIVEN a listed color outside palettes/, in the Palette Creator's draft
# WHEN running the pre-commit hook
# THEN it allows the commit: the hook only checks palettes/
test_colors_outside_palettes_are_not_checked() {
  write_palette_with teal "#0ABAB5"
  mv "$SANDBOX/repo/palettes/teal-palette.toml" "$SANDBOX/repo/palette-creator/work-in-progress-palette.toml"
  run_hook
  assert_status 0
}

# GIVEN palettes/avoid-these.txt
# WHEN reading each line
# THEN every line is blank, a comment ("# ...") or a #rrggbb color, so a
#      mistyped color can't be silently skipped
test_every_line_of_the_list_is_a_color_or_a_comment() {
  OUTPUT="$(grep -n -v -E '^$|^#( .*)?$|^#[0-9A-Fa-f]{6}[[:space:]]*$' "$SANDBOX/repo/palettes/avoid-these.txt")"
  [ -z "$OUTPUT" ] || fail "expected only colors and comments, but these lines are neither"
}

run_tests
