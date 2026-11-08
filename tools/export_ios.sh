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
godot --headless --export-debug "iOS" build/ios/Daemons.ipa
echo "Done: open build/ios/Daemons.xcodeproj in Xcode."
