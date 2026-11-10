# Building DAEMONS

Export presets live in `export_presets.cfg` (macOS, Windows, iOS, Android). Every preset bundles the
`*.json` game data and leaves out `tests/`, `tools/`, `docs/` and the GUT addon. Builds go to `build/`
(git-ignored). App id everywhere: `com.agd3sign.daemons` (change it in the presets if you want another).

## Status on this Mac (2026-11-08)

| Platform | Build | Ran it? |
|---|---|---|
| macOS (universal, ad-hoc signed) | ✅ `build/macos/Daemons.zip` (60 MB) | ✅ launches and loads all data |
| Windows x86_64 | ✅ `build/windows/Daemons.exe` (110 MB) | needs a Windows PC |
| Android arm64 (debug) | ✅ `build/android/Daemons.apk` (29 MB), targetSdk 36 | needs a phone (USB debugging) |
| Web (browser) | ✅ `build/web/` via `tools/serve_web.sh`; plays in Chrome/Safari | itch.io-ready zip: `build/daemons-web.zip` |
| iOS (free Personal Team) | ✅ Xcode project in `build/ios/` via `tools/export_ios.sh`; compiles for iPhone | needs your iPhone (Run from Xcode) |

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
./tools/export_ios.sh   # iOS: fills in your Team ID from .ios_team_id, writes build/ios/Daemons.xcodeproj
```

**After any Mac export, run the smoke test:**
```bash
./tools/smoke_test_mac_build.sh
```
It runs the exported app with no window, checks all game data and every map (`-- --check-data`), and fails on
any error. The GUT tests run from the project folder, so they can't catch export-only problems: on 2026-11-08 a
check that looked for a character `.png` passed in the tests but broke 8 of 9 maps in the export (exports repack
images), and New Game showed a black screen.

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

Works with a **free** Apple ID (Personal Team). No paid program needed to play on your own iPhone.

1. Xcode → Settings → Accounts: sign in with your Apple ID.
2. Your Team ID is in your development certificate (the code after `OU=`):
   `security find-certificate -c "Apple Development" -p | openssl x509 -noout -subject`
3. Save it in `.ios_team_id` at the project root. It's git-ignored because it's a personal account detail;
   the preset in `export_presets.cfg` keeps an empty Team ID. (Or set `IOS_TEAM_ID` in the environment.)
4. `./tools/export_ios.sh` writes the Xcode project to `build/ios/` (the preset exports the project only;
   Xcode does the signing).
5. Open `build/ios/Daemons.xcodeproj`, plug in your iPhone, pick it as the run target, press Run.
   First time on the phone: Settings → Privacy & Security → Developer Mode on (restart), and
   Settings → General → VPN & Device Management → trust your developer certificate.

Free Personal Team limits: the app stops opening after **7 days** (plug in and Run again to renew), max 3
of your own apps on the device, no TestFlight or App Store. The paid program ($99/yr) removes those.

### iOS Simulator (Apple Silicon)

Godot's stock simulator library is Intel-only, and the iOS 26 Simulator only runs arm64 apps. Fix: build
Godot's simulator library for arm64 from the same source as your Godot (one-time, about 5 minutes on an M-series Mac):
```bash
brew install scons
git clone --depth 1 --branch 4.7.2-stable https://github.com/godotengine/godot.git /Volumes/BlueHD/godot-build/godot-4.7.2
cd /Volumes/BlueHD/godot-build/godot-4.7.2
scons platform=ios target=template_debug arch=arm64 simulator=yes -j11
mkdir -p ~/Library/Application\ Support/Godot/custom_templates/4.7.2.stable
cp bin/libgodot.ios.template_debug.arm64.simulator.a ~/Library/Application\ Support/Godot/custom_templates/4.7.2.stable/
```
(This Mac already has it, built 2026-11-08.) After that, `./tools/export_ios.sh` merges it in automatically, and
```bash
./tools/run_ios_simulator.sh            # or: ./tools/run_ios_simulator.sh "iPhone 17"
```
builds for the Simulator and launches the game. The Simulator uses the OpenGL Compatibility renderer, which
is what Daemons uses anyway. Rebuild the library when you upgrade Godot (change the version in both paths).
Game logs: the game's ERROR lines show in Console.app / `log stream` under subsystem `com.agd3sign.daemons`.

- Orientation is landscape (either way). Touch controls appear automatically. Notch/home-indicator safe areas are respected.

## 4. Android

Needs a JDK and the Android SDK. **This Mac is already set up** (2026-11-08): OpenJDK 17 (Homebrew, no admin password needed),
Android command-line tools, platform-tools, build-tools 35, Android 35 platform, Godot Editor Settings pointed at both, and a debug keystore.
To set up another Mac:
```bash
brew install openjdk@17
brew install --cask android-commandlinetools
export JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
yes | sdkmanager --licenses   # accepts Google's Android SDK License Agreement
sdkmanager "platform-tools" "build-tools;35.0.0" "platforms;android-35"
```
1. Godot editor → Editor Settings → Export → Android: **Java SDK Path** = the JAVA_HOME above, **Android SDK Path** = `/opt/homebrew/share/android-commandlinetools`.
2. Debug keystore: `~/Library/Application Support/Godot/keystores/debug.keystore` (standard debug values: alias androiddebugkey, password android).
3. On the phone: Settings → About → tap Build number 7 times → Developer options → USB debugging on.
4. Export Debug, then install: `adb install -r build/android/Daemons.apk` (or use the one-click deploy button in the editor toolbar).
- **Google Play:** release builds need your own upload keystore (keep it safe forever) and an `.aab` (turn on Gradle build). New personal Play accounts need **12 testers opted in for 14 straight days** before going live; start that early.

## 4b. Web (play in a browser)

The `Web` preset builds a browser version (WebAssembly + WebGL 2, the Compatibility renderer the game already uses).
It's the **no-threads** variant, so it runs on any static host without special server headers (itch.io, GitHub
Pages, any web server).

```bash
./tools/serve_web.sh      # export to build/web/ and serve at http://localhost:8060
```
Then open http://localhost:8060 in Chrome, Safari, Firefox or Edge. Click the game once so it gets keyboard focus.

- **Size:** 39 MB on disk, about **10 MB to download** (hosts compress it). The game data itself is under 1 MB; the
  rest is the engine. The browser caches it after the first visit.
- **Saves** go in the browser's storage (IndexedDB): they survive reloads, but each browser/device has its own,
  and clearing site data deletes them.
- **Sound** starts after the first click or key press (browsers require it); the title screen covers that.
- **Phones:** the touch controls work in mobile browsers.
- Release builds have no Debug Menu.
- Checked 2026-11-08: loads with no console errors, New Game, maps and character art, dialogue, menus, mouse
  clicks, save → reload → CONTINUE.

### Putting it on itch.io (your account)
1. Make sure `build/web/touch_deck.js` is there (`serve_web.sh` copies it; an editor export doesn't), then zip the contents of `build/web/` (not the folder itself): `cd build/web && zip -r ../daemons-web.zip .`
2. itch.io → Create new project → Kind of project: **HTML** → upload the zip → tick **"This file will be played
   in the browser"**.
3. Embed options: viewport **960 x 540** (16:9, 3x the game's 320x180), tick **Fullscreen button**. Leave
   "SharedArrayBuffer support" off (not needed).
4. Visibility: **Draft** or **Restricted** (password) while you collect feedback; Public when ready.

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
- [ ] iPhone: run from Xcode, play with touch controls (project exports and compiles)
- [ ] Android phone: install the APK, play with touch controls
- [ ] (Distribution) Developer ID + notarized Mac build

## Project settings that exports need
- `rendering/textures/vram_compression/import_etc2_astc = true`: required for Apple Silicon/universal Mac and mobile exports (doesn't change the pixel art).
- `application/config/icon = res://assets/ui/icon.png`: placeholder (Pingo). Replace with real art at 512x512 or larger.

## GitHub Pages (automatic)
`.github/workflows/web.yml` runs on every push to `main`: downloads Godot 4.7.2 + the web templates (cached),
imports, runs the GUT suite, exports the `Web` preset and deploys `build/web` to https://agd3sign.github.io/DAEMONS/.
If a test fails, nothing is deployed and the live page keeps the last good build. Run it by hand from the
Actions tab ("Run workflow"). Progress: `gh run list --workflow web.yml`.

## Phones in the browser
Upright on a touch device, `web/touch_deck.js` (loaded by the Web preset's head include) makes the game a 4:3
screen at the top and draws a control deck below it: d-pad, A (OK), B (back), MENU, and RUN (tap to toggle).
The deck talks to the game through `window.daemonsDeck` (TouchControls deck mode hides the in-game overlay).
Sideways or on desktop the game fills the window and the in-game overlay is used. The preset uses canvas resize
policy 0 so Godot follows the canvas size the page sets.
