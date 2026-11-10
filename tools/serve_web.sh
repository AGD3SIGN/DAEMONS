#!/bin/bash
# Exports the browser build and serves it at http://localhost:8060 (Ctrl+C to stop).
#   ./tools/serve_web.sh            # export + serve
#   ./tools/serve_web.sh --no-export  # just serve the last export
# The web build has no threads, so a plain static server works (no special headers), same as itch.io.
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "${1:-}" != "--no-export" ]]; then
  mkdir -p build/web
  touch build/.gdignore
  godot --headless --export-release "Web" build/web/index.html
  cp web/touch_deck.js build/web/  # phone control deck (portrait), loaded by the export's head include
fi
echo "Open http://localhost:8060 in your browser. Ctrl+C to stop."
python3 -m http.server 8060 --bind 127.0.0.1 --directory build/web
