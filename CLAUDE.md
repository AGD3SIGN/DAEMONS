# HEXFORGED — project rules for Claude Code

## What this is
An early-2000s handheld-style, top-down, turn-based creature-collecting RPG with an IT theme.
Creatures are "Forgelings". Capture device is a "Quarantine Key". Healing is the "Help Desk".
**docs/gdd.md is the source of truth** (story, acts, world order, demo scope). Read it, docs/design.md and
docs/phase-log.md before adding content. Where anything disagrees with the GDD, the GDD wins.

## Name and lore (2026-11-15)
- The game was called DAEMONS; players read it as "demons". It's now **HEXFORGED**, and the creatures are
  **Forgelings** (one Forgeling, many Forgelings; renamed from "Hexforged" 2026-11-15 because it didn't read well in sentences). Code identifiers, class names, file names, species ids and
  `DMN-###` CMDB ids still say Daemon/DMN until Brandon decides on a code rename; player-facing text says Forgelings.
- Lore rules (docs/gdd.md §4), everywhere:
  1. Forgelings are **built, never born**. No breeding, eggs, nests, parents or babies. Stages are upgrades.
  2. Every Forgeling was compiled by the **Hexforge** for a job and lives in the system it runs.
  3. Corruption is a **broken computer**, never demonic: no horns, devil wings, skulls, flames or occult imagery.
  4. **All ages.** Ransom's menace stays cartoony.
  5. Humor works on **two layers**: funny to anyone, funnier to IT people.
- Corruption is a slow reveal: no ERR:: Forgelings before the Power Plant (flag `corruption_revealed`).
- **Keyboard, controller and touch must all work on every screen.**
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
- Battle scene: a 960x640 frame scaled by whole numbers of physical pixels ("Server Floor" arena, see
  docs/battle-scene-spec.md). No grass/sky/field visuals in battle.

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

## Player feedback
Open reports from the private AGD3SIGN/daemons-feedback repo are listed at session start. When fixing one,
mention it in the commit and close it with `gh issue close <n> -R AGD3SIGN/daemons-feedback -c "Fixed in <sha>"`.
Never put the GitHub token in the game or in git; it lives only as a Worker secret.

## Conventions
- snake_case files, PascalCase class_name, typed GDScript everywhere.
- One feature per branch/commit. Run tests before saying a phase is done.
- After each phase (or sub-step): commit with a message describing what was done, then push to origin.
- Never add Pokémon names, assets, sounds, or code from pokeemerald / Pokémon Essentials / Showdown.
  Mechanics can be inspired by them; code and content must be original.
- Capture is menu-based inside battle only. No real-time throwing of capture items in the overworld.

## Folder layout
res://
  autoload/        DataRegistry, GameState, SaveManager, AudioManager, SceneRouter, ScreenFitter, Settings,
                   InputPrompts, TouchControls, AppLifecycle
  data/            species, moves, types, items, config_profiles, tiles, balance, level_caps, region_map, tickets,
                   kudos, certifications, demo_roster, demo_end, title_screen, whats_new, feedback, build_info (.json);
                   maps/, encounters/, dialogue/ (per-town files + hx_* story placeholders), trainers/
  scenes/          overworld/, battle/, ui/, debug/, menus/ (empty for now)
  scripts/         battle/ (battle_scene.gd, sim/, ui/), overworld/ (+ events/), ui/ (+ title/), daemon/, util/, debug/
  assets/          sprites/daemons/ (<id>_sheet.png), sprites/characters/, tiles/, ui/, fonts/, audio/
  tests/           test_*.gd (GUT, flat)
  docs/            gdd.md, design.md, phase-log.md, data-format.md, build.md, story-outline.md, story-demo-draft.md,
                   battle-scene-spec.md, whats-new-spec.md, slice-audit.md, gdd-gap-report.md, rename-leftovers.md,
                   art-prompts/
  art_src/         source art (ChatGPT sheets): forgelings/<NN-Line>/<id>_gpt_v<stage>[_rN].png|webp, characters/;
                   gdignored and excluded from exports, but committed to git
  services/        feedback-worker/ (Cloudflare Worker: in-game feedback -> private AGD3SIGN/daemons-feedback issues)
  tools/           feedback/ (feedback_report.sh, run by the SessionStart hook), art_import/ (import_sheet.gd,
                   import_character.gd, pixel_map_sheet.gd, polish_sheet.py), art_prompts/ (build_prompts.py),
                   export_ios.sh, run_ios_simulator.sh, serve_web.sh, smoke_test_mac_build.sh, setup_input_map.gd,
                   build_placeholder_tiles.gd
  web/             touch_deck.js (on-screen controls for the web build, copied into the export)
  addons/          gut/ (GUT test framework, third-party)
  build/           export output per platform (gitignored)
  .github/         workflows/web.yml (tests, then web export to GitHub Pages on every push to main)
  .claude/         launch.json, settings, skills/
