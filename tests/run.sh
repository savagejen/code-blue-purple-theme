#!/usr/bin/env bash
# Runs every test file (tests/<script>/test_*.sh).
#
# Usage: tests/run.sh

set -u

cd "$(dirname "$0")"

status=0
for file in */test_*.sh; do
  [ -f "$file" ] || continue
  printf '\n### %s\n\n' "$file"
  bash "$file" || status=1
done

exit "$status"
