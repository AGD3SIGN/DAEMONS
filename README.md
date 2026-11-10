# DAEMONS

A GBA-style, top-down, turn-based monster collector where tech comes alive. You're the new hire on the
help desk in **Root Valley**: catch Daemons in Quarantine Keys, earn Certifications, and stop the
**Ransom** syndicate. Built with Godot 4.7 (GDScript).

**▶ Play in your browser: https://agd3sign.github.io/DAEMONS/** (updates automatically on every push to `main`
once the tests pass; see `.github/workflows/web.yml`).

> Working title. All 22 Daemons have pixel-art battle sprites and 18 overworld characters have walking sprites
> (AI-drafted, imported and polished with Aseprite); 3 minor NPCs still use placeholders. The playable demo runs from New Game to the first Certification
> (about 30-45 minutes). Builds for macOS, Windows, Android and iOS: [docs/build.md](docs/build.md).

## Run it
```bash
brew install --cask godot        # Godot 4.7.x
godot --path .                   # play
godot --path . --editor          # open in the editor
./tools/serve_web.sh             # browser version at http://localhost:8060
```
In debug builds the title menu also has a **Debug Menu** (test battles, the Daemon Lab, overworld shortcuts).

## Controls
| Action | Keyboard | Gamepad | Mouse / touch |
|---|---|---|---|
| Move | Arrows / WASD | D-pad / left stick | — |
| Confirm / talk | Z / Enter | A | Click / tap |
| Back | X / Esc | B | BACK buttons |
| Run (hold) | Shift | X | — |
| Menu | Space / Tab | Start | — |

On phones and tablets an on-screen d-pad and buttons appear (drag in the lower left to move, push far to run).

## Tests
```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```
A playable text battle in the terminal (no graphics):
```bash
godot --headless --path . res://scenes/debug/console_battle.tscn
```

## Where things live
| Folder | What |
|---|---|
| `data/` | All game content as JSON: Daemons, moves, types, items, maps, dialogue, encounters, trainers. Format: [docs/data-format.md](docs/data-format.md) |
| `scripts/battle/sim/` | The battle rules, pure and seeded (no UI) |
| `scripts/battle/`, `scripts/overworld/`, `scripts/ui/` | Battle screen, overworld, menus |
| `autoload/` | DataRegistry, GameState, SaveManager, AudioManager, SceneRouter, ScreenFitter, Settings, InputPrompts, TouchControls, AppLifecycle |
| `assets/sprites/daemons/` | One battle sheet per Daemon: `<id>_sheet.png`, 4x4 poses of 64x64 |
| `assets/sprites/characters/` | Overworld walking sheets: `<id>.png`, 3 frames x 4 directions of 16x24 |
| `art_src/daemons/`, `art_src/characters/` | Source art (ChatGPT sheets). Not shipped in builds |
| `tools/` | Art importer and polish script, art-prompt generator, iOS export and Simulator scripts |
| `docs/` | [Design doc](docs/design.md), [phase log](docs/phase-log.md), [data formats](docs/data-format.md), [builds](docs/build.md), [art prompts](docs/art-prompts/README.md) |

## Art
Daemon sprites go from a ChatGPT prompt to the game in four steps (details in [docs/art-prompts/README.md](docs/art-prompts/README.md)):
1. Generate a sheet with the prompt for that Daemon's stage (`docs/art-prompts/`, built by `tools/art_prompts/build_prompts.py`).
2. Save it as `art_src/daemons/<NN-Line>/<id>_gpt_v<stage>.png` (or `.webp`). 4x4 (16 poses) and 6x2 (12 poses) layouts both work.
3. Import every sheet: `godot --headless -s tools/art_import/import_sheet.gd -- --all` (background removed, poses cut to 64x64).
4. Polish to ~15 colors with Aseprite through the Aseprite MCP: `tools/art_import/polish_sheet.py` (setup in the vault's Assets > Tools).

Overworld characters work the same way: save `art_src/characters/<id>_gpt_v1.png` (3 columns: stand, step,
step x 4 rows: down, up, left, right), run `godot --headless -s tools/art_import/import_character.gd -- --all`,
polish with `polish_sheet.py --colors 12`, and set `"sprite": "<id>"` in the NPC's `look` in its map.

A test fails if a Daemon has no sheet or a sheet has more than 16 colors. Each move's battle effect is data too:
`"fx"` in `data/moves.json` (see [docs/data-format.md](docs/data-format.md)).

## Progress
- [x] Phase 0 — Project setup
- [x] Phase 1 — Data layer, Daemon stats and EXP
- [x] Phase 2 — Battle simulation (damage, statuses, capture, AI)
- [x] Phase 3 — Battle screen
- [x] Phase 4 — Overworld, maps, NPCs, dialogue
- [x] Phase 5 — Wild encounters, Active Stack, Bag, CMDB, Server Rack, shop
- [x] Phase 6 — Trainers, Certifications, black-out, saving, options
- [x] Phase 7 — Vertical slice (intro, Route 1, Wi-Fi Dead Zone, Patch Town, Desktop Support Dept.)
- [~] Phase 8 — Platform builds: touch controls, prompts, lifecycle, export presets, Mac/Windows/Android/iOS builds and the iOS Simulator done ([docs/build.md](docs/build.md)); testing on real devices pending
- [x] Art: all 22 Daemons drawn, imported and polished; every move has its own battle effect
- [x] Overworld character art (18 characters; Kevin's mom, the gate guard and the angler still placeholders)
- [ ] Phase 9+ — Steam page, content, polish, launch

## Legal
All names, creatures, art, text and code are original. No Pokémon assets, names or code are used.
