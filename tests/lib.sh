# Shared helpers for the shell tests. Source it from a test file, define
# test_* functions, then call run_tests at the end.
#
# Each test runs in a subshell with its own sandbox:
#   $SANDBOX/repo  a copy of the repository as git sees it (generated files
#                  other than the committed Blue Purple ones are left out)
#   $SANDBOX/home  an empty home folder
#   $SANDBOX/bin   fake commands, put first on PATH by the test's run helper
# If the test file defines after_sandbox, it runs once the sandbox is ready.

set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_BASE="${TMPDIR:-/tmp}"
TMP_BASE="${TMP_BASE%/}"

# --- Sandbox -----------------------------------------------------------------

make_sandbox() {
  SANDBOX="$(mktemp -d "$TMP_BASE/jenerated-tests.XXXXXX")"
  mkdir -p "$SANDBOX/repo" "$SANDBOX/home" "$SANDBOX/bin"
  # Tracked files plus new ones that aren't ignored: the repository as it
  # would be committed, without anyone's locally generated palettes. (Files
  # deleted but still tracked are skipped.) One tar copies them all, which is
  # much faster than copying file by file.
  git -C "$REPO" ls-files -z --cached --others --exclude-standard |
    while IFS= read -r -d '' file; do
      [ -f "$REPO/$file" ] && printf '%s\0' "$file"
    done |
    (cd "$REPO" && tar --null -T - -cf -) | tar -xf - -C "$SANDBOX/repo"
}

# fake_command name body -> puts a script called `name` in $SANDBOX/bin.
fake_command() {
  printf '#!/bin/sh\n%s\n' "$2" >"$SANDBOX/bin/$1"
  chmod +x "$SANDBOX/bin/$1"
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

# --- Assertions --------------------------------------------------------------
# Output assertions check $OUTPUT and $STATUS, set by the test's run helper.

FAILED=0

fail() {
  printf '    FAIL: %s\n' "$1"
  FAILED=1
}

assert_status() {
  [ "$STATUS" -eq "$1" ] || fail "expected exit status $1, got $STATUS"
}

assert_contains() {
  case "$OUTPUT" in
    *"$1"*) ;;
    *) fail "expected output to contain: $1" ;;
  esac
}

assert_not_contains() {
  case "$OUTPUT" in
    *"$1"*) fail "expected output not to contain: $1" ;;
  esac
}

# assert_link path target
assert_link() {
  if [ ! -L "$1" ]; then
    fail "expected a symlink at $1"
  elif [ "$(readlink "$1")" != "$2" ]; then
    fail "expected $1 -> $2, got -> $(readlink "$1")"
  fi
}

assert_exists() {
  [ -e "$1" ] || fail "expected $1 to exist"
}

assert_missing() {
  [ ! -e "$1" ] || fail "expected $1 not to exist"
}

# assert_file_equals path expected
assert_file_equals() {
  if [ ! -f "$1" ]; then
    fail "expected file $1"
  elif [ "$(cat "$1")" != "$2" ]; then
    fail "expected $1 to contain '$2', got '$(cat "$1")'"
  fi
}

# assert_file_contains path text
assert_file_contains() {
  if [ ! -f "$1" ]; then
    fail "expected file $1"
  elif ! grep -qF -- "$2" "$1"; then
    fail "expected $1 to contain: $2"
  fi
}

# assert_file_not_contains path text
assert_file_not_contains() {
  if [ -f "$1" ] && grep -qF -- "$2" "$1"; then
    fail "expected $1 not to contain: $2"
  fi
}

# assert_same_file actual expected
assert_same_file() {
  cmp -s "$1" "$2" || fail "expected $1 to match $2"
}

# --- Runner ------------------------------------------------------------------

# Runs every test_* function, each in its own subshell and sandbox, and exits
# non-zero if any failed. On failure, prints the last $OUTPUT.
run_tests() {
  local passed=0 failed=0 test
  for test in $(declare -F | awk '{print $3}' | grep '^test_'); do
    if (
      make_sandbox
      trap 'rm -rf "$SANDBOX"' EXIT
      if declare -F after_sandbox >/dev/null; then after_sandbox; fi
      OUTPUT=""
      "$test"
      if [ "$FAILED" -ne 0 ]; then
        printf '    output:\n'
        printf '%s\n' "$OUTPUT" | sed 's/^/      | /'
      fi
      exit "$FAILED"
    ); then
      printf 'ok    %s\n' "$test"
      passed=$((passed + 1))
    else
      printf 'FAIL  %s\n' "$test"
      failed=$((failed + 1))
    fi
  done

  printf '\n%d passed, %d failed\n' "$passed" "$failed"
  [ "$failed" -eq 0 ]
}
