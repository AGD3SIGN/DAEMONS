# DAEMONS → HEXFORGED: code-level references left as they are

Written 2026-11-15 during the rename. Player-facing text now says HEXFORGED / Forgelings. Everything below still says
Daemon/DMN on purpose, waiting for Brandon's decision on a code rename (open decision 6). A rename here touches
tests, saves or published URLs, so each group notes what would break.

## Class names
- `DaemonInstance` (scripts/daemon/daemon_instance.gd), about 180 uses
- `DaemonSprites` (scripts/battle/ui/daemon_sprites.gd), about 30 uses
- `DaemonLab` scene/script (debug only)

## Files and folders
- `scripts/daemon/` (daemon_instance.gd, item_use.gd, growth_rate.gd ...)
- `scripts/battle/ui/daemon_sprites.gd`, `scripts/debug/daemon_lab.gd`, `scenes/debug/daemon_lab.tscn`
- `assets/sprites/daemons/` (every battle sheet) (source art moved to `art_src/forgelings/` on 2026-11-26)
- Tests: `test_daemon_art.gd`, `test_daemon_instance.gd`, `test_daemon_lab.gd`, plus test names like
  `test_every_daemon_has_art`

## Data and save formats (renaming needs a save migration)
- Battle event dictionary key `"daemon"` (38 uses in the sim/UI)
- Dialogue command `give_daemon`; functions `add_daemon`, `has_usable_daemon`, `show_daemon`
- Save files store DaemonInstance dictionaries; field names don't say "daemon", so saves are fine either way

## CMDB ids
- The CMDB record shows `ASSET DMN-###` (scripts/ui/cmdb_panel.gd). Proposed: `HXF-###` (pending).

## Builds, URLs and services
- Bundle / package id `com.agd3sign.daemons` (macOS, iOS, Android). Changing it makes a different app on phones
  (old installs and their saves wouldn't upgrade).
- Export file names: build/macos/Daemons.zip, build/windows/Daemons.exe, build/android/Daemons.apk,
  build/ios/Daemons.ipa / Daemons.xcodeproj (and tools/export_ios.sh, tools/run_ios_simulator.sh)
- GitHub repo `AGD3SIGN/DAEMONS` and the web build URL https://agd3sign.github.io/DAEMONS/
- Private feedback repo `AGD3SIGN/daemons-feedback`; Cloudflare Worker `daemons-feedback` (its page text now says
  HEXFORGED; redeploy with `npm run deploy`)
- Web shell: `window.daemonsDeck`, `#daemons-deck` (web/touch_deck.js)
- Local folder /Volumes/BlueHD/GitHub/Daemons and the Obsidian vault folder Projects/Daemons

## Handled already
- The app name is HEXFORGED. Desktop saves and settings are copied once from the old "Daemons" user folder
  (SaveManager.carry_over_old_user_data). Web and phone saves don't move.
