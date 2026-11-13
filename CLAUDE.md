# DAEMONS — project rules for Claude Code

## What this is
An early-2000s handheld-style, top-down, turn-based creature-collecting RPG with an IT theme.
Creatures are "Daemons". Capture device is a "Quarantine Key". Healing is the "Help Desk".
The full design doc lives in docs/design.md — read it before adding content.
Progress lives in docs/phase-log.md.

## Documentation
Project notes are mirrored in the Obsidian vault at
/Volumes/BlueHD/GitHub/Mah_brain/Projects/Daemons/ (Overview, Phase-Plan, Devlog/, Features/,
Architecture/, Bugs/, Assets.md, Design/). After finishing a phase or step, update the vault:
check off Phase-Plan tasks, add/append Devlog/YYYY-MM-DD.md, and record decisions in
Architecture/System-Notes.md. Append; don't overwrite.

## Tech stack
- Engine: Godot 4.7, GDScript only (no C# — iOS C# support is still experimental).
- Targets: macOS, Windows, iOS, Android (Linux/Steam Deck as a bonus).
- Tests: GUT (Godot Unit Test) in tests/. Run headless:
  `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
- Map editing: Godot TileMapLayer (LDtk optional later).
- Art: Aseprite exports PNG into assets/. Placeholder art is fine until Phase 7.

## Rendering rules
- Base resolution 320x180 (16:9), stretch mode canvas_items, scale mode integer, texture filter Nearest.
- Tiles 16x16. Overworld characters 20x28 frames, centered on their 16x16 tile. Battle sprites 64x64.
- On wider/taller screens, show more world instead of letterboxing where possible.

## Architecture rules (do not break these)
1. Data-driven. Species, moves, types, items, encounters, trainers live in data/ as JSON
   (or .tres Resources) and are loaded by a DataRegistry autoload. No hard-coded stats in scripts.
2. Battle logic is a pure simulation in scripts/battle/sim/. It does NOT touch nodes, UI, or audio.
   It takes actions in, outputs an ordered list of BattleEvents (e.g. "move_used", "damage",
   "status_applied", "fainted", "capture_shake"). The UI in scripts/battle/ui/ plays those events back.
3. All randomness goes through a seeded RNG object passed into the sim, so battles are replayable in tests.
4. Game state (party, rack storage, bag, flags, money, CMDB) lives in a GameState autoload
   and is serialized by SaveManager to JSON with a version number and checksum. Two save slots that
   alternate on write, so a crash mid-save never corrupts both.
5. Overworld movement is grid-based (one tile per step, tweened). Collision and tile behaviors
   (hot zone, ledge, warp, water) come from TileSet custom data, not per-tile scripts.
6. NPCs/signs/warps/triggers are small event nodes with exported properties + a dialogue/script id.
7. Input goes through named actions (ui_accept, ui_cancel, move_up, etc.) so keyboard, gamepad,
   and touch controls all map to the same thing.

## Conventions
- snake_case files, PascalCase class_name, typed GDScript everywhere.
- One feature per branch/commit. Run tests before saying a phase is done.
- After each phase (or sub-step): commit with a message describing what was done, then push to origin.
- Never add Pokémon names, assets, sounds, or code from pokeemerald / Pokémon Essentials / Showdown.
  Mechanics can be inspired by them; code and content must be original.
- Capture is menu-based inside battle only. No real-time throwing of capture items in the overworld.

## Folder layout
res://
  autoload/        DataRegistry, GameState, SaveManager, AudioManager, SceneRouter
  data/            species, moves, types, items, config_profiles, tiles (.json), maps/, encounters/, dialogue/, trainers/
  scenes/          overworld/, battle/, ui/, menus/
  scripts/         battle/sim/, battle/ui/, overworld/, ui/, util/
  assets/          sprites/daemons/, sprites/characters/, tiles/, ui/, fonts/, audio/
  tests/
  docs/            design.md, phase-log.md, data-format.md, build.md, art-prompts/
  art_src/         source art (ChatGPT sheets) per evolution line; gdignored, excluded from exports
  tools/           art_import/ (import_sheet.gd, import_character.gd, polish_sheet.py), art_prompts/, export_ios.sh, run_ios_simulator.sh
