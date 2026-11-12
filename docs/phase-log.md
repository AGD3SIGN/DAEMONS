# Phase log

Newest entries at the top. Each entry: what's done, decisions, what's next.

---

## 2026-11-11 — Pyrewall joins the roster

- Pyrewall (phoenix x firewall) is now a real Daemon: CMDB #023, Security/Power, legendary (`"legendary": true`),
  base stat total 580, catch rate 3, slow growth, 3 Encryption logs. Learns Static Zap, Firewall Up, Heatsink Slam,
  Latency Spike, Brownout, and two new signature moves: **Burn Rule** (Security, 90, 30% Overheat) at 40 and
  **Ash Reboot** (Power, heal 50%) at 50, then Thermal Runaway at 60.
- Battle art comes from the same pixel map as the title (`tools/art_import/pixel_map_sheet.gd`), so it matches.
- Title card now shows the real CMDB number (No. 023). Not placed in the world yet (design: post-game legendary).
- Tests: 252/252. Checked in a battle at 1280x720.

---

## 2026-11-11 — New title screen (Start Screen Style Guide)

- Brandon designed a new start screen (PDF style guide, 1280x720 HTML reference): CRT boot-screen look with a
  synthwave grid floor, circuit traces with traveling pulses, floating bits, a glitching DAEMONS logo, and the
  legendary **Pyrewall** (phoenix x firewall) bobbing in the middle with rings, embers, flame flicker, core pulse
  and eye blink, a LEGENDARY card, PRESS START, and a NEW GAME · CONTINUE · OPTIONS row.
- Built in Godot as `scripts/ui/title_screen.gd` + `scripts/ui/title/` (TitleStyle constants, TitleBackdrop,
  TitleHero + shader, TitleLogo, background and CRT overlay shaders). The 1280x720 frame is scaled to fit and the
  background/floor extend on wider or taller screens instead of letterboxing. Pyrewall is drawn from the mirrored
  map in `data/title_screen.json` (one texture, per-pixel animation in a shader). The card is data-driven so
  other legendaries can rotate in.
- Menu: left/right (or up/down, stick), accept/Start, mouse hover + click, tap to select then tap again; CONTINUE
  greyed out and skipped without a save; on touch the menu stacks vertically. Options gained CRT EFFECTS and LESS
  MOTION (the browser's prefers-reduced-motion also counts).
- Bundled VT323 (OFL) next to Press Start 2P. Version tag shows the web deploy's run number.
- Tests: 250/250. Checked at 1280x720, 375x812 portrait (deck) and 812x375 landscape (touch overlay).

---

## 2026-11-09 — Phone browser layout (portrait control deck)

- Brandon's phone (portrait): the game filled the tall screen, the map was tiny in the middle and the touch
  buttons covered the text box.
- New `web/touch_deck.js`: on touch devices held upright the game is a 4:3 screen at the top and a handheld-style
  deck sits below (d-pad you can roll your thumb across, A, B, MENU, RUN toggle, light haptics on Android).
  Input reaches the game through JavaScriptBridge (`window.daemonsDeck`) as the usual actions; TouchControls
  "deck mode" hides the overlay. Web preset: head include + canvas resize policy 0.
- Checked at 375x812 in the browser: title, menu navigation and New Game all driven from the deck; landscape
  falls back to the full-screen game + overlay. Tests: 234/234.
- Landscape touch: the overworld text box now stops short of the A/B buttons (`TouchControls.reserved_right()`),
  full width with keyboard/gamepad or under the portrait deck. Tests: 235/235.
- Landscape touch d-pad is now a fixed cross (arms 44pt+ wide, arrows, pressed arm lights up) instead of a
  floating ring; directions come from its center so you can roll your thumb. The text box fits between it and
  A/B. Checked with real touch events at phone-landscape size. Tests: 237/237.

---

## 2026-11-09 — Battle intro uses battle-size character art

- Brandon: the trainers in the battle intro looked nothing like the uploaded art. They were the 16x24 walking
  frames scaled up 3x, which drops the faces and shading.
- `import_character.gd` now also writes `<id>_battle.png` (front + back at 48x72) straight from the source sheet,
  with a de-fringe step (the sources' outlines are blended into the magenta background and came out purple).
  Polished to 16 colors. `BattleScene.trainer_frame` uses it (falls back to the walking frame).
- Tests: 232/232 (every character has battle art, the intro draws it 1:1).

---

## 2026-11-08 — Battle intro, Kevin bursts in, Chipmunk faces the right way

**Done**
- Chipmunk, Munkboard, Mainmunk and Wormhole had back views drawn facing left (away from the foe). New species
  field `"art": {"flip_back": true}` mirrors the player's sprite for them.
- Trainer battle intro: you (from behind) and the opponent's character sprite slide onto the platforms, the
  intro line plays, then each trainer slides out of frame right before their Daemon comes out. Wild battles show
  only you. Trainers got `"sprite"` ids (Kevin, Theo, Tina, Dana, Intern, Sam, Jo, Hal, Pete).
- Starter cutscene: you walk up to the Manager, and after you pick, Kevin bursts through the front door and runs
  up to you. New NPC `"hidden": true` plus dialogue steps `show_npc`, `hide_npc`, and `move_npc` with
  `"to": "player"` / `"run": true` (shortest free path, then both face each other).
- The slice audit treats hidden NPCs as not there (Kevin waits on the exit mat).
- Tests: 231/231 (new: flip, trainer intro, wild intro, Kevin burst-in, Kevin hidden on later visits). Mac export
  smoke test passes; web build re-exported.

---

## 2026-11-08 — Browser (Web) build

**Done**
- `Web` export preset (no threads: works on itch.io / GitHub Pages without special headers). `tools/serve_web.sh`
  exports and serves it locally. 39 MB on disk, ~10 MB compressed download.
- Played in the browser: loads with a clean console, New Game, maps + character art, dialogue, menus, mouse
  clicks, save -> reload -> CONTINUE (IndexedDB). Walking couldn't be checked in Claude's hidden browser pane
  (2 fps there); it uses the same code as desktop.
- Fixed while testing (affects every build): the title's save header ("TIME 0:00  CERTS 0") ran past the menu box;
  menu is now 180 px, with a test that the longest header fits.
- docs/build.md: web section with itch.io upload steps. Tests: 227/227.

---

## 2026-11-08 — Fix: black screen after New Game in the Mac build

- Cause: the new NPC sprite check used `FileAccess.file_exists` on `res://assets/...png`. Exports repack images,
  so the file isn't there; the check failed and 8 of 9 maps refused to load. Tests passed (they run from the
  project). Fixed with `ResourceLoader.exists`.
- New `-- --check-data` startup option (DataRegistry checks every map, then quits) and
  `tools/smoke_test_mac_build.sh`, which runs it on the exported app. Proven: fails on the buggy build, passes
  on the fix. Added to docs/build.md as a step after every Mac export.

---

## 2026-11-08 — Overworld character art

**Done**
- Brandon's 18 ChatGPT character sheets (3 frames x 4 directions) in `art_src/characters/`.
- `tools/art_import/import_character.gd`: finds the pose grid from the gaps in the art (the poses aren't on an
  even grid; equal thirds cut through them), keys the background (shared `clear_mask` with the Daemon importer),
  one scale for all 12 frames, each anchored by its feet -> `assets/sprites/characters/<id>.png` at 16x24.
  Polished to 12 colors.
- Overworld characters now 16x24 (CLAUDE.md allows it): `CharacterSprites.place()` lifts the frame so the feet
  stay on the 16x16 tile; draw order by row (`depth()`) so lower characters stand in front.
- NPC `look.sprite` picks the art; 21 of 24 NPCs mapped (Kevin's mom, gate guard and angler still placeholders).
  The data checker rejects a sprite id with no file.
- Tests: 226/226 (importer on an off-grid sheet, NPCs use their art and stand on the tile, draw order,
  every character sheet is 48x96 with <=12 colors).

---

## 2026-11-08 — Move effects

**Done**
- Every move now has its own battle effect, defined in `data/moves.json` as `"fx"` (data-driven, like everything else).
- `scripts/battle/ui/battle_fx.gd`: 16 pixel-art effect pieces (burst, stream of packets/envelopes/code/cells, rings,
  beam, lightning bolt, rising/falling glyphs, orbit, glitch, screen flash/dim, blue-screen cover, shield, brick
  wall, X stamp, slices) colored by move type by default; each step draws in its own layer so parallel steps work.
- Plays after the attacker's lunge and before the hit; skipped when battle animations are off (time_scale 0).
- Data checker rejects unknown kinds, glyphs, colors and `on` values.
- Tests: 222/222 (every move has a distinct effect, every piece is used, every effect plays and cleans up).

---

## 2026-11-08 — Art revamp: 19 new Daemon sheets

**Done**
- Brandon revamped 19 Daemons in ChatGPT (all but the Chipmunk line): cleaner pixel art, 6x2 = 12 poses on a
  1536x1024 canvas. Saved as `art_src/daemons/<line>/<id>_gpt_v<stage>_r2.webp` (newest file wins on import).
- `import_sheet.gd` reads the 6x2 layout: finds the two pose rows from the gap between them, cuts each pose as a
  square from its own column with one size per sheet, fills the 4 missing poses (white silhouette for evolve).
- Background keying fixed: magenta is now matched against the sheet's own background color (strict), so hot pinks
  and purples survive (Botgeon's and Spigeon's ruffs were being cut out); magenta-ish edge blends touching the
  background are peeled off (removed a purple fringe and stray specks).
- All 22 re-imported and polished to 15 colors. Tests: 217/217 (new: 6x2 layout).

---

## 2026-11-08 — Art polish pass (Aseprite)

**Done**
- Aseprite 1.3.18.6 built from source; diivi Aseprite MCP installed outside the repo (local Claude Code scope).
- `tools/art_import/polish_sheet.py`: per sheet, weighted k-means (sqrt of pixel count) picks 15 colors from the
  sheet's own pixels so small accents survive; Aseprite (via the MCP's tools) snaps every pixel and exports.
  First try with Aseprite's own reduction dropped Pingo's cyan effects and white glow; this fixed it.
- All 22 sheets polished: ~8,000-25,000 colors -> 15 each, flat GBA-style shading. Brandon approved the Pingo sample.
- Tests: 216/216 (new: every sheet has at most 16 colors).

---

## 2026-11-08 — Art: the whole roster

**Done**
- Source sheets for all 22 Daemons in `art_src/daemons/01-Chipmunk/` … `08-Singles/`; imported with `-- --all`.
- Every Daemon now uses its sheet in battle, CMDB, Summary and the starter picker; no placeholders left.
- Tests: 215/215 (new: every species has a sheet).

**Next:** an enhancement pass (palette, outlines, stray pixels), likely with Aseprite.

---

## 2026-11-08 — Art: Chipmunk and Pingo lines

**Done**
- Source art now lives in one folder per line: `art_src/daemons/01-Chipmunk/` … `08-Singles/` (`<id>_gpt_v<stage>.png`).
- `import_sheet.gd -- --all` imports every sheet found there (newest file wins if a Daemon has two).
- The importer handles already-transparent sheets and drops the see-through halos background removers leave.
- In the game: Chipmunk, Munkboard, Mainmunk, Pingo, Pengwan, Emperoute. Tests: 214/214.

---

## 2026-11-08 — Bug review

**Done**
- **Bug #2 fixed (0 PP soft-lock):** new typeless move **Force Quit** (power 50, never misses, 1/4 recoil, never
  learned). With no PP on any move, FIGHT uses it automatically for the player; the AI switches if it can,
  otherwise Force Quits. Before, the AI picked a 0-PP move, the sim rejected it, and the battle repeated forever.
  0-PP moves are now greyed out in the FIGHT menu; "X has no PP left!" is shown first.
- **Bug #14 (iOS "Mouse is not supported" at startup):** comes from Godot itself (`scene/main/window.cpp`, root
  window enter-tree asks for the mouse position without checking the device has one). Harmless; won't fix here.
- Tests: 212/212 (4 new, including an end-to-end trainer battle that starts with 0 PP).

---

## 2026-11-08 — Art pipeline: first real Daemon sprites

**Done**
- `tools/art_import/import_sheet.gd` (run headless): slices an AI sprite sheet into 4x4 poses, removes the
  background (magenta anywhere; a plain color only from the edges so white bellies survive), shrinks each to 64x64
  → `assets/sprites/daemons/<id>_sheet.png`. Sources live in `art_src/` (gdignored, excluded from exports).
- `DaemonSprites`: sheets first (`pose(id, name)`, `POSES`), then `_front/_back.png`, then the placeholder.
- `BattlePlayer`: plays the poses: breathing idle loop, physical/special attack, hurt, faint, foe status poses
  (asleep/overheated/throttled); the player's Daemon uses the back-view poses.
- Imported Pengwan and Emperoute. Tests: 208/208 (importer, pose lookup, a battle that shows the poses).

---

## 2026-11-08 — Phase 8: iOS Simulator + touch fixes

**Done**
- Built Godot 4.7.2's iOS simulator library for Apple Silicon from source (the stock one is Intel-only).
  `tools/export_ios.sh` merges it into the export; `tools/run_ios_simulator.sh` builds and launches on the Simulator.
- Played in the iPhone 17 Simulator: title, menu, Onboarding Town, walking with the touch d-pad.
- Fixed 3 touch bugs it exposed: tap-to-start did nothing (title background ate taps); tapping dialogue and
  CMDB/Summary/Trainer Card panels did nothing (Panels eat taps); touch controls hidden whenever a controller
  is paired (the Simulator reports one). Tests: 204/204.

**Open:** a harmless `mouse_get_position` error on iOS startup.

---

## 2026-11-08 — Phase 8: iOS build with a free Apple account

**Done**
- `tools/export_ios.sh` exports the Xcode project to `build/ios/`, filling the Team ID from the git-ignored `.ios_team_id` only during the export.
- iOS preset now exports the project only (`export_project_only=true`); Xcode signs automatically with the free Personal Team.
- Checked: the project compiles for iPhone (unsigned `xcodebuild`, BUILD SUCCEEDED). The iOS Simulator can't link on Apple Silicon because Godot's simulator library is Intel-only.

**Next:** run it on the iPhone from Xcode.

---

## 2026-11-08 — Roster: same-animal evolution lines + sprite prompts

**Done**
- Every evolution line now keeps the same animal (it grows up while its tech upgrades). Renamed:
  Motherboar/Mainframe → **Munkboard/Mainmunk** (chipmunk), Routeroo/Meshkraken → **Pengwan/Emperoute** (penguin),
  Bitling/Scriptor/Compilox → **Glowbit/Scriptfly/Compilume** (firefly), Spamlet/Spamwich → **Spigeon/Botgeon** (pigeon),
  Diskette/Zipdrive → **Ziphare/Discohare** (rabbit). New CMDB categories and entries. Stats, levels, types, moves unchanged.
- Updated encounters, trainers (`kevin_rival_1_glowbit`), dialogue, debug tools, tests, design doc.
- **Save version 2:** `SaveManager.migrate` renames old ids in values, keys and flag suffixes, so existing saves keep their Daemons.
- `tools/art_prompts/build_prompts.py` → `docs/art-prompts/`: one full ChatGPT prompt per stage for all 22 Daemons
  (1024x1024, 4x4 grid of 64x64 sprites at 4x: front, reactions, back, evolution/specials, menu icon).
- Tests: 202/202.

---

## 2026-11-08 — Phase 8: Platform support (code done; builds need toolchain + devices)

**Done**
- **TouchControls** autoload: floating d-pad (lower-left; push past the ring to run), A = check icon, B = back-arrow icon, MENU = three lines. ≥44pt targets converted from points to the game's logical pixels per device, inside notch/home-indicator safe areas (mobile only). Vector-drawn so it's crisp at any density. Sends the same named actions as keyboard/gamepad (with menu repeat). Fake mouse clicks from touches on the controls are swallowed so they don't press menus underneath. Shown on touchscreens, hidden when a gamepad connects or a pad button is pressed, and hidden during battles (everything there is tappable; it covered the HP panel).
- **InputPrompts** autoload: tracks keyboard / Xbox / PlayStation / Nintendo / touch from the last input; labels buttons to match (Z, A, Cross, Nintendo B, "tap"). Title prompt follows it.
- **AppLifecycle** autoload: on mobile background → pause the tree and autosave if idle in the overworld (never mid-battle/dialogue); Options → AUTOSAVE toggle.
- **export_presets.cfg**: macOS (universal), Windows (x86_64, data embedded), iOS, Android (arm64). All include `*.json`, exclude tests/tools/docs/GUT. App id com.agd3sign.daemons, version 0.1.0. Phones are sensor-landscape.
- **docs/build.md**: setup + per-platform export, signing and notarization, device install, Play testing rule, done-when checklist.
- Debug menu: "Touch controls (try with mouse)".
- Tests: `tests/test_platform.gd` (11). 201/201 passing.

**Fixes during the phase:** desktop safe area (menu bar/Dock) pushed the d-pad off-screen → safe areas only on mobile; touch buttons covered battle HP → hidden in battle.

**Toolchain installed (with your OK):** Godot 4.7.2 export templates; OpenJDK 17 + Android command-line tools, platform-tools, build-tools 35, Android 35 (Google's SDK license accepted); Godot Editor Settings pointed at both; debug keystore created.

**Builds (all exported cleanly):**
| Platform | Result |
|---|---|
| macOS universal | `build/macos/Daemons.zip` 60 MB, x86_64 + arm64, ad-hoc signed. **Launched it: all data loaded.** |
| Windows x86_64 | `build/windows/Daemons.exe` 110 MB (PE32+ GUI). Not run (needs a Windows PC). |
| Android arm64 debug | `build/android/Daemons.apk` 29 MB, com.agd3sign.daemons 0.1.0, targetSdk 36. Not installed (no phone connected). |
| iOS | Not exported: needs your Apple Team ID in the preset. |

Export needed two project settings: ETC2/ASTC import on (Apple Silicon/mobile) and an app icon (placeholder Pingo, `assets/ui/icon.png`).

**Still to do for done-when (needs devices/accounts):** play the slice on the Mac build, a Windows PC, an iPhone (add Team ID → Xcode) and an Android phone (USB debugging → `adb install`). Developer ID + notarization for distribution.

---

## 2026-11-07 — Phase 7: Vertical slice ✅ (code + content; art/audio still placeholder)

**The slice:** New Game → wake up, name yourself → Mom → Help Desk → manager's e-waste bin starter choice → Kevin bursts in and takes the starter that beats yours → rival battle #1 (losing doesn't black out) → Route 1 (3 trainers) → Wi-Fi Dead Zone (dark, 2 trainers incl. a Ransom "Phisher") → Patch Town (Help Desk, shop, gate) → Desktop Support Department (patch-panel laser-door puzzle, 2 techs, Department Head Dana) → Desktop Support Cert → the gate opens → end-of-demo message.

**Engine**
- Arrival triggers (cutscene when you spawn onto a trigger), laser-door `barrier` events re-checked after dialogue, `move_player` scripted walking, map `music` + darkness `tint` (CanvasModulate).
- Dialogue commands: `name_player` (presets or typed), `choose_starter` (sprite preview + CMDB line + confirm), `move_player`; `set_flag` with `value: false` toggles.
- Story trainers (`"story": true`): no black-out on a loss; flag set either way.
- Music hooks everywhere (AudioManager.play_music / play_jingle, files in assets/audio/music|jingles/<id>.ogg drop in by name): town, route, dead_zone, help_desk, department, battle_wild/trainer/rival/boss, victory, heal jingle. Silent until a soundtrack exists.
- **Text paging:** long lines split into pages that fit 3 lines (was clipping; Bug #7).
- New Game no longer hands out a placeholder starter; 3000 CR start.

**Content**
- 2 new Daemons: **Ramster** (Hardware, hamster + RAM stick) and **Servurtle** (Hardware, turtle + rack server). Slice roster: 11 (3 starters + Dustbunny, Wormby, Cablesnake, Spamlet, Floppit, Fanbat, Ramster, Servurtle).
- Maps: Wi-Fi Dead Zone, Patch Town, Patch Town Help Desk, Desktop Support Dept.; Route 1 opened north; story edits to your house, Help Desk, Onboarding Town.
- Trainers (8 + Kevin): Intern Ian, Sysadmin Sam, Jogger Jo (Route 1); Signal Hunter Hal, Phisher Pete (Dead Zone); Tech Theo, Tech Tina, Department Head Dana (Dept.).
- Encounters: Dead Zone table (Cablesnake, Fanbat, Ramster, Spamlet, Floppit Lv5-8); Ramster added to Route 1.

**Playtest by script — `SliceAudit` (docs/slice-audit.md):** walks every map from New Game with the real movement rules. Result: **0 problems** — 9/9 maps reachable, 17 arrival points all lead back home, every warp/NPC/sign/hidden item reachable, every checked flag is set somewhere, the cert is awarded where it's checked, the laser door is solvable. A test proves it catches a walled-off exit. Bug #2 (0 PP) judged low risk in the slice (lowest move set = 55 PP).

**Balance (Dana, 60 simulated fights each, no items, player plays its best attack):**
| Starter | Lv14 team | Lv12 team |
|---|---|---|
| Chipmunk | 60/60 | 22/60 |
| Pingo | 60/60 | 59/60 |
| Bitling | 56/60 | 8/60 |
Tuning to get there: Cablesnake learns Ping at 9 (was 16) so it can cover Hardware; Bitling learns Data Dump at 12 (neutral coverage); Dana uses the basic AI and a 2-Daemon team (Ramster 12, Servurtle 13) — her original Fanbat + smart AI boosting was a wall for Bitling (5/60).

**Tests:** test_vertical_slice.gd (6), test_slice_audit.gd (2), paging test; story tests replaced the old town-Kevin tests. 190/190 passing.

**Not done in this phase (needs you / outside Claude Code):** real art (Aseprite: slice Daemons, characters, tilesets), music + SFX, and a human playthrough by someone new ("done when").

---

## 2026-11-07 — Phase 6: Trainers, progression, saving ✅

**Done**
- **Trainers** (`data/trainers/*.json`): team, AI tier, prize, sight range, intro/defeat/after lines, optional cert. NPCs with `"trainer"` spot you in a straight line (blocked by anything solid), show "!", walk up, say their intro and battle. Talking to an unbeaten trainer also starts it. Beaten = flag `trainer_<id>`; they then say their "after" line. Route 1 now has Intern Ian and Sysadmin Sam; Kevin uses trainer data.
- **Rewards:** winning shows the defeat line, pays the prize ("You got 160 CR for winning!") and awards the trainer's cert if it has one.
- **Certifications** (`data/certifications.json`, 8, original names): `give_cert` and `if_cert` dialogue, cert-gated progress through dialogue + `hide_if_flag` NPCs. Trainer card shows them as colored badges.
- **Black-out:** losing any battle → lose half your credits, team healed, wake at the last Help Desk you healed at (`heal_party` records it; defaults to Onboarding Town's Help Desk).
- **SaveManager:** JSON with version + sha256 checksum + save_count; two slots that alternate; loads the newest valid slot (damaged, hand-edited or newer-version files are skipped); `migrate()` hook. Saves location, stack, racks, bag, flags, certs, CMDB, credits, play time, trainer ID, black-out point, repel.
- **Pause menu:** CMDB, STACK, BAG, CARD, SAVE, OPTIONS, DEBUG (debug builds), CLOSE. Trainer card (name, ID, credits, CMDB, play time, cert badges). Save asks to confirm.
- **Options** (Settings autoload, user://settings.cfg): text speed (slow/mid/fast/instant, used by every text box), music volume, SFX volume, battle animations on/off.
- **Title menu:** CONTINUE (with time + certs), NEW GAME (placeholder start: Chipmunk Lv5 in your house until the Phase 7 intro), DEBUG MENU.
- Play time only counts during gameplay.
- README added.
- Tests: `tests/test_progression.gd` (20). 181/181 passing.

**Done-when:** beat a trainer, save, quit, relaunch, continue exactly where you were. ✔ (test: battle → save → reset → load → overworld at the same tile, facing, credits and trainer flag)

**Fixes during the phase**
- JSON turns ints into floats on reload, so a checksum over the original data never matched. Checksums are now computed over the round-tripped data.
- Damaged save files are parsed quietly (a half-written file after a crash is expected, not an error).

**Notes**
- No cert-gated area exists yet; the first gate comes with Phase 7/10 content.
- Design doc's "Network+" example is a CompTIA trademark; certs use original names.

**Next:** Phase 7 — vertical slice: intro + starter choice, Route 1, Wi-Fi Dead Zone, Patch Town, Desktop Support Department.

---

## 2026-11-07 — Phase 5: Collecting systems ✅

**Done**
- **Wild encounters:** `data/encounters/<map>.json` (rate per step + weighted slots per tile type). Onboarding Town and Route 1 cable tangles have tables. Stepping on a hot zone rolls (`Encounters.roll`), flashes the screen, and starts a wild battle; you return to the same spot. First wild meeting records where it was found for the CMDB.
- **Firewall Rule** (repel): blocks encounters below your lead's level for 100 steps, with an "expired" message.
- **Pause menu** (Space/Tab/Start): CMDB, STACK, BAG, DEBUG (debug builds), CLOSE.
- **Active Stack:** list with level/Uptime/status; SUMMARY (3 pages: info + CMDB text, stats with profile +/-, moves with type/category/power/accuracy; up/down switches Daemon; Build Quality hidden), SWAP to reorder, ITEM to use something on it.
- **Bag:** 4 pockets (Items, Quarantine Keys, Scripts, Key Items) switched with left/right, item descriptions, USE / TOSS (with quantity). `ItemUse` handles Coffee/Energy Drink/Pizza Friday/Hard Reboot/Overclock Chip (level + upgrade check)/Legacy Driver (item upgrade)/Firewall Rule.
- **CMDB:** every Daemon numbered, seen/quarantined counts, entry page (sprite, category, types, where found, entry text once quarantined).
- **Server Rack:** 12 racks × 30 at the Help Desk's rack terminal: WITHDRAW, DEPOSIT, MOVE between racks (left/right flips racks). Won't let you deposit your last Daemon that can fight. Catches overflow into the rack when the stack is full.
- **Supply Closet:** clerk at the Help Desk counter. BUY (stock list, quantity, total, confirm) and SELL (half price). Credits shown. Debug menu gives 3000 CR.
- New UI pieces: `MenuList` (scrolling list, keyboard/gamepad/mouse, pages with left/right), `SummaryPanel`, `CmdbPanel`, `FieldMenus` (all field flows), quantity chooser.
- GameState: racks, credits, repel_steps, cmdb_found_at, add_daemon overflow, deposit/withdraw/move, swap_stack, lead_level, heal_stack.
- Tests: `tests/test_collecting.gd` (14), including menu flows driven by real input events and the full loop. 161/161 passing.

**Done-when:** walk into a cable tangle → catch it → store it in the Server Rack → heal at the Help Desk → see it in the CMDB. ✔ (tested end to end except the walk, which is tested separately)

**Found in screenshots and fixed:** the stack submenu covered the HP/status column (submenus moved bottom-right); the Moves page details overflowed and showed "40.0" (one compact line per move, whole numbers).

**Notes**
- A move learned from an Overclock Chip in the field with 4 slots full is skipped with a message (no replace prompt outside battle yet).
- Losing a wild battle doesn't black out yet (Phase 6).

**Next:** Phase 6 — trainer line-of-sight battles, Department bosses + certifications, black-out, saving, full pause menu, options.

---

## 2026-11-07 — Phase 4b: Map events + dialogue ✅

**Done**
- Event nodes in `scripts/overworld/events/` (exported properties, built from each map's `events` list): WarpEvent, SignEvent, NpcEvent (solid, faces you, optional wander, move_path), TriggerEvent (zone + once/requires/unless flags), HiddenItemEvent.
- Dialogue system: `data/dialogue/*.json` scripts with text + speaker, yes/no choices, if_flag branches, and commands set_flag, give_item, give_daemon, heal_party, start_battle, move_npc. `{player}` fills in the name ("New Hire" until the intro asks). `DialogueRunner` runs them; the overworld shows a typewriter text box (shared `TextBox`, renamed from BattleTextBox), a speaker name tab, and the YES/NO menu.
- Press A facing an NPC / sign / hidden item to interact; counters reach one tile further.
- Warps fade out/in. Battles started from dialogue return you to the same spot (GameState.location now includes facing).
- Validation: every dialogue step and command, every map event (dialogue ids, items, species, warp targets, NPCs on walkable tiles).
- 8 interior tiles (exit mat, interior wall, rug, table, bed, server rack, plant, bookshelf).
- New maps: Your House (Mom gives 3 Coffee once), Kevin's House, Help Desk (heal across the counter; intern offers a Dustbunny), Route 1: Cable Run stub (signs, hidden 2x Thumb Drive, road north "closed for maintenance").
- Onboarding Town events: 3 doors + north exit, 3 signs, Kevin (offers a battle), a wandering townsperson, a kid who "dances" (move_npc), a one-time warning trigger at the north exit, a hidden Coffee.
- Fixes: camera offset ignored map limits (8px strip past the edge) → camera now positioned instead; background is black around small rooms.
- Tests: `tests/test_map_events.gd` (13). 147/147 passing overall.

**Phase 4 complete.** Done-when met: walk out of your house, talk to people, read signs, go through doors between maps.

**Notes**
- Trainer line-of-sight, defeat text and prize money are Phase 6; Kevin's battle is a plain dialogue → battle for now.
- The townsperson wanders with unseeded randomness (fine for the overworld; battles stay seeded).

**Next:** Phase 5 — wild encounters in cable tangles, Active Stack menu, Server Rack, Bag, CMDB, Help Desk heal, Supply Closet shop.

---

## 2026-11-07 — Phase 4a: Overworld movement + Onboarding Town ✅

**Done**
- Placeholder tileset `assets/tiles/placeholder_overworld.png` (16 tiles, drawn by `tools/build_placeholder_tiles.gd`) + `data/tiles.json` (name, atlas, collision, behavior). `OverworldTiles` builds a TileSet with custom data layers "name"/"collision"/"behavior".
- Maps are text grids in `data/maps/<id>.json` (legend + rows + spawns), validated on load. `MapView` builds a TileMapLayer and answers tile_info / is_walkable from the TileSet custom data.
- **Onboarding Town** (30x25): your house, Kevin's house, the Help Desk (blue roof), pond with fences, flowers, 3 signs, 3 cable tangle patches (hot zones), ledges, exit north to Route 1.
- `PlayerController`: one tile per step, 4 tiles/sec walking, 8 running (hold run). Tap turns in place, hold walks, direction changes mid-walk don't pause. Walls bump with a sound (throttled) and walk-in-place. Ledges hop down 2 tiles with an arc + shadow, can't climb up. Signals `stepped(cell, behavior)` and `bumped`.
- Camera follows the player and stays inside the map. Area-name banner slides in on arrival.
- Placeholder character sheet (3 frames × 4 directions, 16x16) in `CharacterSprites`; real art at `assets/sprites/characters/<id>.png` overrides.
- `AudioManager.play_sfx()` with synthesized placeholder blips (bump, select, confirm); real files in `assets/audio/sfx/` override.
- `GameState.location` tracks map + cell (for saves in Phase 6).
- Debug menu: "Overworld: Onboarding Town". In the overworld, Space/Tab (menu) returns to the debug menu for now.
- Tests: `tests/test_overworld.gd` (12). 134/134 passing overall.

**Decisions**
- Maps are text grids in JSON instead of painted in the Godot editor. Readable, diffable, easy for me to build; behavior still comes from TileSet custom data. A converter to editor-paintable scenes can come later if you want to paint maps by hand.
- Tile behavior lives in tiles.json and is loaded into the TileSet at runtime (no hand-made .tres yet).
- Single tile layer for now (no roofs drawn over the player).

**Next:** Phase 4b — warps (doors, Route 1 exit), signs, NPCs, triggers, hidden items, dialogue system.

---

## 2026-11-07 — Phase 3: Battle UI ✅

**Done**
- `scenes/battle/battle_scene.tscn` + `scripts/battle/battle_scene.gd` (BattleScene): GBA layout at 320x180, anchored so bigger views still fit. Foe top-right on a platform with its panel top-left; your Daemon (back sprite) bottom-left with Uptime numbers + EXP bar bottom-right; text box along the bottom.
- Turn loop on top of BattleSim: command menu (FIGHT / STACK / BAG / RUN), move menu (PP + type), stack list (crashed/in-battle greyed out), bag (battle items + Quarantine Keys; keys disabled vs trainers), forced replacement after a crash, AI foe, "uninstall a move?" prompt when a 5th move comes in.
- `BattlePlayer` plays every event: typewriter text, slide in/out, attack lunge, hit blink + shake, smooth Uptime/EXP bars with live numbers, crash drop, stat up/down tint, status tags (THR/COR/OVH/SBY/HNG), Quarantine Key throw → absorb → shakes → break free or dim, level-up stat popup.
- After battle: "Your X is upgrading!" sequence (flashing silhouettes, X/Esc cancels), new moves from the new form, caught Daemon goes to the Active Stack (or Server Rack when full), CMDB seen/caught updated.
- `BattleTextBox`, `BattleInfoPanel`, `BattleMenu`, `CursorButton`, `UiTheme`, `DaemonSprites` (placeholder 64x64 front/back generated from type colors, id-based shape, size by base stat total; real PNGs in assets/sprites/daemons/<id>_front.png / _back.png are used automatically).
- Input: every menu works with keyboard, gamepad (ui_* actions) and mouse/touch (hover moves the cursor, click/tap selects, BACK buttons for touch). Text advances on Z/X/click/tap.
- Debug menu (`scenes/debug/debug_menu.tscn`, title → Start in debug builds): wild Dustbunny, random wild, Kevin, watch AI vs Kevin, heal + restock, Daemon Lab. Gives a starter team + bag on first visit.
- Opening the battle scene directly (F6) runs a demo vs Dustbunny (`-- --auto` to watch).
- `SceneRouter.goto(path, params)` passes data to the next scene. `GameState.add_daemon()`.
- Tests: `tests/test_battle_ui.gd` (10). Full wild battle, Root Key capture, Kevin with forced switches, level-up → upgrade, all through the real screen at time_scale 0. 122/122 passing overall.

**Bugs found and fixed while building**
- Menus collapsed to zero size: `set_anchors_preset()` on a node already in the tree keeps its old (zero) rect. Switched to `set_anchors_and_offsets_preset()` everywhere; added a layout test.
- Command menu text touched the edge; move info overflowed ("PERIPHERAL PHYS"). Widened and simplified.

**Decisions**
- UI is built in code (layout constants in `battle_scene.gd`), not in .tscn files. Faster to iterate now; can move to scenes when real art arrives.
- Battle text waits for a button press (GBA feel) except "X ran Y!", key shakes and switch-outs, which pause briefly.
- Move category (physical/special) isn't shown in the move menu, like Gen 3.

**Not verified by eye**
- The capture and upgrade animations were checked by tests, not by watching them.

**Next:** Phase 4a — overworld: grid movement, TileSet custom data, Onboarding Town.

---

## 2026-11-07 — Phase 2c: Capture, running, AI, console battle ✅

**Done**
- **Run chance:** equal or faster always escapes; otherwise floor(mine × 128 / theirs) + 30 × attempts out of 256. A failed escape uses the turn (`run_failed`).
- **Quarantine capture** (wild battles, player only): a = floor((3·Max − 2·Current) × catch_rate × key bonus / (3·Max)) × status bonus (2 Standby/Hung, 1.5 Throttled/Corrupted/Overheated). a ≥ 255 always catches; otherwise 4 checks against floor(1048560 / ⁴√(16711680 / a)). Events: `capture_shake` (1–3), then `captured` (outcome "caught", `state.captured`) or `capture_failed {shakes}`. Measured: Thumb Drive on a full-Uptime Dustbunny catches ~1 in 3; in Standby ~2 in 3; Root Key always.
- **BattleAI** (`scripts/battle/sim/battle_ai.gd`): random / basic / smart, plus `choose_replacement()`. Smart inflicts status on healthy targets, boosts early, heals under 40%, and switches out of super-effective matchups (max 2 voluntary switches per battle so two smart sides can't ping-pong). Uses state.rng, so AI battles replay exactly.
- **BattleText** (`scripts/battle/ui/battle_text.gd`): event → text-box line, all original IT-flavored wording ("A wild Dustbunny spawned!", "Pingo ran Ping!", "Done! Floppit was Quarantined!"). Phase 3 reuses it.
- **Console battle** (`scenes/debug/console_battle.tscn`): play in the terminal, or `--auto` for AI vs AI. Options: `--trainer` (Kevin, 3 Daemons, smart AI), `--seed N`, `--ai random|basic|smart`.
- Added `daemon` names to heal/revived/drain/recoil events for text.
- Tests: `tests/test_battle_capture_ai.gd` (15). 112/112 passing overall.
- Batch check: 60 auto battles (30 wild, 30 vs Kevin) all finish; avg 3.4 / 17.8 turns, max 23.

**Run it**
```
godot --headless --path . res://scenes/debug/console_battle.tscn
godot --headless --path . res://scenes/debug/console_battle.tscn -- --trainer --seed 3
godot --headless --path . res://scenes/debug/console_battle.tscn -- --auto --trainer
```

**Notes for later**
- Bug #2 (no fallback move at 0 PP) is still open; deferred to the bug review. The console stops with "Stuck" if it ever happens.
- The test team won all 60 auto battles. That team is a few levels above Kevin's, so this isn't real balance data; check in Phase 11.

**Phase 2 complete. Next:** Phase 3 — battle UI (GBA layout, menus, animated event playback).

---

## 2026-11-07 — Phase 2b: Damage, statuses, effects, EXP ✅

**Done** (`scripts/battle/sim/battle_sim.gd`; full event list at the top of the file)
- Damage: floor(floor(floor(2L/5+2) × Power × Atk/Def) / 50) + 2, then crit ×1.5 (1/16), roll 85–100%, STAB ×1.5, type chart. Min 1 unless immune. `calc_damage()` takes crit + roll as arguments so tests can check exact numbers.
- Physical = Throughput vs Hardening; special = Compute vs Encryption. Crits ignore the attacker's drops and the defender's boosts. Overheated halves physical damage.
- Accuracy with accuracy/evasion stages (3-based multipliers). Accuracy 0 never misses.
- Statuses: Throttled (half Bandwidth, 25% skip), Corrupted (1/8 per turn), Overheated (1/16 per turn, half physical), Standby (1–3 turns, no PP used), Hung (20%/turn recovery), Looping (2–5 turns, 1/3 self-hit at 40 power). One major status at a time; Looping stacks on top.
- Status immunities by type (data): Hardware/Overheated, Power/Throttled, Malware/Corrupted.
- Move effects are a registry of small handlers keyed by effect id: status_chance, stat_change, drain, recoil, heal, multi_hit (2–5 hits weighted 3/3/1/1 out of 8).
- Crashing: `fainted` → EXP to the player → `switch_needed` or `battle_end`. `BattleSim.forced_switch()` sends in a replacement; turns are refused until it's done.
- EXP = floor(base_exp × foe level / 7), ×1.5 vs trainers, split between participants still standing. Each participant gets the foe's full Experience Logs. Level-ups (and learned moves) happen mid-battle.
- `upgrade_ready` events come after `battle_end` for anyone who levelled up into an upgrade. The caller calls `evolve()`.
- `DaemonInstance.status_turns` added (saved) for Standby.
- Tests: `tests/test_battle_damage.gd` (25). 97/97 passing overall.

**Decisions**
- Status immunities are my pick (mirroring the classic type/status pairs). Easy to change in types.json.
- Crashed Daemons lose their status.
- Exp formula is the simple Gen-3 one (no level scaling).

**Not yet**
- No "Struggle" when every move is out of PP: a trainer battle could soft-lock. Add in 2c.

**Next:** Phase 2c — run chance, Quarantine capture, trainer AI tiers, console text battle.

---

## 2026-11-07 — Phase 2a: Battle sim structure ✅

**Done** (all in `scripts/battle/sim/`, no nodes/UI/audio)
- `BattleAction`: fight(slot), switch_to(index), item(item_id, target_index), run().
- `BattleSide`: stack, active Daemon, items (copied back to the bag by the caller), stat stages and volatile effects (reset on switch).
- `BattleState`: two sides, seeded RNG, turn counter, field, wild/trainer, outcome.
- `BattleSim`: `start()`, `run_turn()`, `validate_action()`, `turn_order()`, `effective_bandwidth()`, `stage_multiplier()`.
  - Order: run → switch → item → fight; then move priority; then Bandwidth (stages, Throttled halves); then a seeded coin flip.
  - Invalid actions return one `invalid_action` event with a readable reason; the turn isn't played.
  - Battle items work now: Coffee/Energy Drink (heal, capped), Pizza Friday (heal + cure), Hard Reboot (revive at half).
  - Event list is documented at the top of `battle_sim.gd`.
- Tests: `tests/test_battle_turn_order.gd` (19). 72/72 passing overall.

**Placeholders for later steps**
- `_resolve_move()` is empty: moves use PP and emit `move_used` but do no damage yet (Phase 2b).
- Running always succeeds in wild battles (Phase 2c adds the Bandwidth-based chance).
- Quarantine Keys are rejected in battle until Phase 2c.

**Decisions**
- The sim changes the real DaemonInstances (Uptime, PP, status carry over after battle, like the classic games). Stat stages and volatile effects live on BattleSide and vanish after battle.
- The sim reads species/move/item data from DataRegistry (data only, no scene access).
- The tie-break roll happens every turn, even without a tie, so the RNG sequence never depends on which actions were picked.

**Next:** Phase 2b — damage, accuracy, crits, STAB, type effectiveness, stat stages, statuses, move effects, fainting, EXP.

---

## 2026-11-07 — Debug: Daemon Lab

`scenes/debug/daemon_lab.tscn` is a hands-on test screen for Phase 1. Debug builds open it when you press Start on the title.
Controls: Left/Right = Daemon, Up/Down = level, Z = Overclock Chip (+1 level, shows learned moves),
Shift = reroll Build Quality/profile, Space = upgrade, X = back. It re-checks save/load on every change.
Remove the title-screen hook when Phase 7 adds the real intro. Tests: `tests/test_daemon_lab.gd` (53/53 overall).

---

## 2026-11-07 — Phase 1b: DaemonInstance + stat math ✅

**Done**
- `data/config_profiles.json`: 25 Config Profiles (5 neutral), validated (every up/down pair once, no Uptime). Includes Aggressive, Defensive and Power-Saver from the design doc.
- `scripts/daemon/growth_rate.gd` (GrowthRate): the 6 EXP curves + level_for_exp.
- `scripts/daemon/daemon_instance.gd` (DaemonInstance): species, nickname, level, total_exp, current_uptime, status, 4 move slots with PP, build_quality, experience_logs, config_profile, original_trainer_id.
  - `create(species, level, rng)`: seeded random Build Quality + profile, last 4 learnable moves, full Uptime.
  - Stat formulas from docs/design.md (integer math, floored).
  - `gain_exp()` / `level_up()` return events: level_up (with stat gains), move_learned, move_learn_pending (4 moves already; UI asks which to forget, then `learn_move(id, slot)`).
  - `add_experience_logs()` with 252/510 caps. `heal_full()`.
  - `check_evolution("level" | "item", item_id | "sync")` + `evolve()` (damage taken carries over).
  - `to_dict()` / `from_dict()`, safe after a JSON round trip; returns null for unknown species.
- Tests: `tests/test_daemon_instance.gd` (21). 50/50 passing overall.

**Decisions**
- Field is `total_exp` (not `exp`) because `exp()` is a built-in GDScript function.
- Uptime goes up by the level-up gain (fainted Daemons stay at 0).
- Moves learned while 4 slots are full are not auto-replaced; the event lets the UI ask.
- Evolution is only checked/applied; deciding *when* (after battle, on item use, on Sync) is the caller's job.

**Next:** Phase 2a — headless battle sim: BattleState, actions, turn order, BattleEvents, seeded RNG.

---

## 2026-11-07 — Phase 1a: Data layer ✅

**Done**
- `data/types.json`: 12 types + the type chart from docs/design.md (only non-1 cells stored), plus a UI color per type.
- `data/moves.json`: 30 original moves across 9 types, using effects none, status_chance, stat_change, drain, recoil, heal, multi_hit.
- `data/species.json`: 20 Daemons. The 3 starter lines (BST 310/405/530, upgrade at 16/34), plus Wormby→Wormhole (22), Spamlet→Spamwich (25), Dustbunny, Fanbat, Cablesnake→Patchviper (24), Floppit→Diskette (Legacy Driver item)→Zipdrive (Sync). Every growth rate is used at least once.
- `data/items.json`: the 11 items from the doc + **Legacy Driver** (needed for Floppit's item upgrade).
- `scripts/util/data_validator.gd` (DataValidator): required fields, ranges, enums, effect params, and cross-references (types, learnset moves, evolution targets, evolution items). One readable line per error.
- DataRegistry loads all 4 files at boot, reports JSON parse errors with file + line, exposes `get_species/get_move/get_item` and `type_multiplier(attack, defender_types)`.
- `docs/data-format.md`: field reference for editing data by hand.
- Tests: `tests/test_data_registry.gd` (19). 29/29 passing overall. Game boots with "12 types, 30 moves, 20 species, 12 items loaded".

**Decisions**
- Data files are lists with an `id` field (not objects keyed by id) so duplicate ids get caught.
- Move `accuracy: 0` means "never misses" (self-buffs, heals).
- Added `log_yield` to species (Experience Logs given on defeat; Phase 2b needs it). Max 3 total.
- Status moves use `status_chance` with chance 100 rather than a separate effect.
- Records stay plain Dictionaries from JSON. Numbers come back as floats; cast with int().

**Watch for later**
- Phase 8: export presets need `*.json` in the "non-resource files" filter or data won't ship.

**Next:** Phase 1b — DaemonInstance, stat formulas, EXP curves, level up, evolution checks, save dicts.

---

## 2026-11-07 — Phase 0 fix: black borders at odd window sizes ✅

**Problem:** Godot's built-in integer stretch expands the view to the window's shape, then rounds the scale down, so most window sizes showed thick black borders.
**Fix:** `autoload/screen_fitter.gd` (ScreenFitter) picks scale = floor(min(window / 320x180)), then sets the view to window / scale. Borders are now under one scaled pixel, and extra space shows more world. Min window size 320x180. Tests: `tests/test_screen_fitter.gd` (10/10 passing overall).
**Note:** at 1x in a large window you see a lot of extra space around a small title; that's expected and only happens when the window is under 640 wide or 360 tall.

---

## 2026-11-07 — Phase 0: Project setup ✅

**Done**
- Godot 4.7.2 project "Daemons" (installed via Homebrew). Renderer: GL Compatibility (desktop + mobile).
- 320x180 base, stretch `canvas_items`, aspect `expand` (shows more world on wider screens), scale `integer`, texture filter Nearest, 2D pixel snapping on. Dev window 1280x720 (4x).
- Folder layout from CLAUDE.md (empty folders hold `.gitkeep`).
- Autoload stubs: DataRegistry, GameState, SaveManager, AudioManager, SceneRouter.
- GUT 9.7.1 in `addons/gut`, plugin enabled. `tests/test_project_setup.gd`: 6 tests, all passing.
- Input actions (all devices): see table below. Generated by `tools/setup_input_map.gd`.
- Title scene `scenes/ui/title_screen.tscn` with Press Start 2P (OFL 1.1, license in `assets/fonts/LICENSE.txt`), font imported with antialiasing/hinting off.
- `.gitignore`, `docs/design.md`, this log.

**Input map**
| Action | Keyboard | Gamepad |
|---|---|---|
| move_* / ui_* directions | Arrows, WASD | D-pad, left stick |
| ui_accept | Z, Enter, KP Enter | A (south) |
| ui_cancel | X, Esc, Backspace | B (east) |
| menu | Space, Tab | Start |
| run | Shift | X (west) |

**Decisions**
- `run` is a separate button (Shift / west face button) instead of "hold B" so it never collides with ui_cancel. Easy to change in `tools/setup_input_map.gd`.
- Pressing Start on the title just prints for now; Phase 7 routes it to the intro / continue menu.

**Run tests**
```
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

**Next:** Phase 1a — data layer (types, moves, species, items JSON + DataRegistry validation + tests).
