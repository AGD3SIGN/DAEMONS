# Phase log

Newest entries at the top. Each entry: what's done, decisions, what's next.

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
