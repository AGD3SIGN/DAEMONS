# Building DAEMONS

Export presets live in `export_presets.cfg` (macOS, Windows, iOS, Android). Every preset bundles the
`*.json` game data and leaves out `tests/`, `tools/`, `docs/` and the GUT addon. Builds go to `build/`
(git-ignored). App id everywhere: `com.agd3sign.daemons` (change it in the presets if you want another).

## 0. One-time setup (all platforms)

1. **Godot 4.7.2** (`brew install --cask godot`).
2. **Export templates** for the exact same version:
   Godot editor → Editor → Manage Export Templates → Download and Install.
   Or from the command line (about 1 GB):
   ```bash
   curl -L -o /tmp/godot_templates.tpz https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz
   mkdir -p ~/Library/Application\ Support/Godot/export_templates/4.7.2.stable
   unzip -o /tmp/godot_templates.tpz -d /tmp/godot_templates
   cp -R /tmp/godot_templates/templates/* ~/Library/Application\ Support/Godot/export_templates/4.7.2.stable/
   ```
3. Run the tests first: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`

Command-line export (any preset, after setup):
```bash
godot --headless --export-release "macOS" build/macos/Daemons.zip
godot --headless --export-release "Windows" build/windows/Daemons.exe
godot --headless --export-debug   "Android" build/android/Daemons.apk
godot --headless --export-debug   "iOS"     build/ios/Daemons.ipa
```

## 1. macOS (universal: Apple Silicon + Intel)

- **For yourself:** export as above. Godot ad-hoc signs it; unzip and run. If macOS blocks it, right-click → Open.
- **For other people (Steam/itch/direct):** it must be signed with a **Developer ID Application** certificate and **notarized**. This needs the paid **Apple Developer Program ($99/yr)**; even Steam requires it for Mac builds.
  1. developer.apple.com → Certificates → create **Developer ID Application**, install it in Keychain.
     Check: `security find-identity -v -p codesigning` shows "Developer ID Application: …".
     (This Mac currently only has an "Apple Development" certificate, which is for testing, not distribution.)
  2. Make an app-specific password at appleid.apple.com, then store a notary profile:
     `xcrun notarytool store-credentials daemons-notary --apple-id YOU@EXAMPLE.COM --team-id TEAMID`
  3. In the Godot editor → Project → Export → macOS:
     Code Signing = Xcode codesign, Identity = your Developer ID; Notarization = Xcode notarytool,
     Keychain profile = `daemons-notary`. Export. Godot signs, uploads and staples.
  4. Check: `spctl -a -vv build/macos/Daemons.app` should say "accepted, source=Notarized Developer ID".
  - Steam: no App Sandbox (leave Sandbox off), Hardened Runtime on (Godot default).

## 2. Windows (x86_64)

- Exports from this Mac fine: `build/windows/Daemons.exe` (the data is embedded in the .exe).
- **Test on a real Windows PC**: copy the .exe over and double-click. SmartScreen will warn about an unknown publisher until the build is code-signed (optional; an OV/EV certificate costs money; Steam builds don't need it).
- Custom .exe icon: needs `rcedit` (and Wine on a Mac) set in Editor Settings → Export → Windows. Optional.

## 3. iOS (iPhone / iPad)

Needs Xcode (installed: Xcode 27) and an Apple account.
1. Find your **Team ID**: developer.apple.com → Membership (paid), or Xcode → Settings → Accounts (a free Personal Team works for your own phone; apps expire after 7 days).
2. Put it in the iOS preset: `application/app_store_team_id`.
3. Export → Godot writes an Xcode project next to the .ipa path (`build/ios/`).
4. Open `build/ios/Daemons.xcodeproj` in Xcode, plug in your iPhone, pick it as the run target, press Run.
   First time: on the phone, Settings → General → VPN & Device Management → trust your developer certificate. Also turn on Developer Mode (Settings → Privacy & Security).
- Orientation is landscape (either way). Touch controls appear automatically. Notch/home-indicator safe areas are respected.

## 4. Android

Needs a JDK and the Android SDK (not installed on this Mac yet):
```bash
brew install --cask temurin@17
brew install --cask android-commandlinetools
sdkmanager "platform-tools" "build-tools;35.0.0" "platforms;android-35" "cmdline-tools;latest"
```
1. Godot editor → Editor Settings → Export → Android: set **Java SDK Path** (`/usr/libexec/java_home -v 17`) and **Android SDK Path** (usually `/opt/homebrew/share/android-commandlinetools`).
2. A debug keystore is created automatically for debug exports.
3. On the phone: Settings → About → tap Build number 7 times → Developer options → USB debugging on.
4. Export Debug, then install: `adb install -r build/android/Daemons.apk` (or use the one-click deploy button in the editor toolbar).
- **Google Play:** release builds need your own upload keystore (keep it safe forever) and an `.aab` (turn on Gradle build). New personal Play accounts need **12 testers opted in for 14 straight days** before going live; start that early.

## 5. What's different on phones (already in the game)

| Feature | How it works |
|---|---|
| Touch controls | Floating d-pad (lower-left, push far to run), check = confirm, arrow = back, three lines = menu. ≥44pt targets, inside safe areas. Hidden when a gamepad connects. |
| Button prompts | Title and hints say Z / A / Cross / B / "tap" to match what you're using. |
| Backgrounding | The game pauses; if you're idle in the overworld it autosaves (Options → Autosave). |
| Screen | Landscape, pixel-perfect integer scaling, extra space shows more world. |

Try the touch controls on a Mac: Debug Menu → "Touch controls (try with mouse)".

## 6. Done-when checklist (Phase 8)

- [ ] Mac: export, run the slice start to finish
- [ ] Windows PC: run the .exe
- [ ] iPhone: run from Xcode, play with touch controls
- [ ] Android phone: install the APK, play with touch controls
- [ ] (Distribution) Developer ID + notarized Mac build
