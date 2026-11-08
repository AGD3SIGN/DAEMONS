#!/bin/bash
# Exports the iOS build as an Xcode project in build/ios/ (open Daemons.xcodeproj, plug in your iPhone, Run).
# The Apple Team ID is personal, so it stays out of git: put it in .ios_team_id (git-ignored) or IOS_TEAM_ID.
# The preset in export_presets.cfg keeps an empty Team ID; this script fills it only for the export.
set -euo pipefail
cd "$(dirname "$0")/.."
TEAM="${IOS_TEAM_ID:-$(cat .ios_team_id 2>/dev/null || true)}"
TEAM="$(echo "$TEAM" | tr -d '[:space:]')"
if [[ ! "$TEAM" =~ ^[A-Z0-9]{10}$ ]]; then
  echo "Put your 10-character Apple Team ID in .ios_team_id (see docs/build.md)." >&2
  exit 1
fi
cp export_presets.cfg export_presets.cfg.bak
trap 'mv export_presets.cfg.bak export_presets.cfg' EXIT
sed -i '' "s/^application\/app_store_team_id=\"\"/application\/app_store_team_id=\"$TEAM\"/" export_presets.cfg
mkdir -p build/ios
touch build/.gdignore  # keep Godot from scanning exported files as project resources
godot --headless --export-debug "iOS" build/ios/Daemons.ipa

# Godot's stock simulator library is Intel-only, which the Apple Silicon iOS Simulator can't run. If an
# arm64 simulator library has been built from source (docs/build.md), merge it into the export.
SIM_LIB="${GODOT_IOS_SIM_LIB:-$HOME/Library/Application Support/Godot/custom_templates/4.7.2.stable/libgodot.ios.template_debug.arm64.simulator.a}"
SLICE="build/ios/Daemons.xcframework/ios-arm64_x86_64-simulator/libgodot.a"
if [[ -f "$SIM_LIB" && -f "$SLICE" ]]; then
  if ! lipo -archs "$SLICE" | grep -qw arm64; then
    lipo -create "$SLICE" "$SIM_LIB" -output "$SLICE.fat" && mv "$SLICE.fat" "$SLICE"
  fi
  echo "Simulator: arm64 library merged ($(lipo -archs "$SLICE"))."
fi
echo "Done: open build/ios/Daemons.xcodeproj in Xcode (iPhone), or run tools/run_ios_simulator.sh."
