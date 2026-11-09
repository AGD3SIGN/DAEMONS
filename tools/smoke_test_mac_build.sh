#!/bin/bash
# Smoke test for the exported Mac build: launches the real exported app with no window, lets it boot
# (DataRegistry loads and checks all game data and every map), and fails if anything printed an error.
# Catches problems the GUT tests can't see because they run from the project folder, not an export
# (e.g. a check that looks for a .png that exports repack into .godot/imported).
#
#   ./tools/smoke_test_mac_build.sh            # after: godot --headless --export-release "macOS" build/macos/Daemons.zip
set -uo pipefail
cd "$(dirname "$0")/.."
APP="build/macos/Daemons.app"
if [[ ! -d "$APP" ]]; then
  [[ -f build/macos/Daemons.zip ]] || { echo "No Mac build. Export it first (docs/build.md)." >&2; exit 1; }
  (cd build/macos && unzip -q -o Daemons.zip)
fi
OUT="$("$APP/Contents/MacOS/Daemons" --headless --quit-after 240 -- --check-data 2>&1)"
echo "$OUT" | grep -E "DataRegistry:" || true
ERRORS="$(echo "$OUT" | grep -E "ERROR|SCRIPT ERROR|Parse Error" || true)"
if [[ -n "$ERRORS" ]]; then
  echo "FAILED: the exported build printed errors:" >&2
  echo "$ERRORS" >&2
  exit 1
fi
echo "OK: the exported build boots cleanly."
