# Phase log

Newest entries at the top. Each entry: what's done, decisions, what's next.

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
