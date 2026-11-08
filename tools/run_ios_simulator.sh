#!/bin/bash
# Builds the exported Xcode project (build/ios/, from tools/export_ios.sh) for the iOS Simulator and
# launches it on a booted simulator (or the one named in $1, e.g. "iPhone 17").
# Needs the arm64 simulator library built from Godot source on Apple Silicon (see docs/build.md).
set -euo pipefail
cd "$(dirname "$0")/.."
DEVICE="${1:-booted}"
DERIVED="build/ios_sim_derived"
if [[ "$DEVICE" != "booted" ]]; then
  xcrun simctl boot "$DEVICE" 2>/dev/null || true
  open -a Simulator
fi
xcodebuild -project build/ios/Daemons.xcodeproj -scheme Daemons -configuration Debug \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' ARCHS=arm64 ONLY_ACTIVE_ARCH=NO \
  -derivedDataPath "$DERIVED" CODE_SIGNING_ALLOWED=NO build -quiet
APP="$DERIVED/Build/Products/Debug-iphonesimulator/Daemons.app"
xcrun simctl install "$DEVICE" "$APP"
xcrun simctl launch "$DEVICE" com.agd3sign.daemons
echo "Launched Daemons on the $DEVICE simulator."
