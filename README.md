# DAEMONS

A GBA-style, top-down, turn-based monster collector where tech comes alive. You're the new hire on the
help desk in **Root Valley**: catch Daemons in Quarantine Keys, earn Certifications, and stop the
**Ransom** syndicate. Built with Godot 4.7 (GDScript).

> Working title. Placeholder art is generated in code until real art lands.
> The playable demo runs from New Game to the first Certification (about 30-45 minutes).

## Run it
```bash
brew install --cask godot        # Godot 4.7.x
godot --path .                   # play
godot --path . --editor          # open in the editor
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
| `autoload/` | DataRegistry, GameState, SaveManager, Settings, AudioManager, SceneRouter, ScreenFitter |
| `docs/` | [Design doc](docs/design.md), [phase log](docs/phase-log.md) |

## Progress
- [x] Phase 0 — Project setup
- [x] Phase 1 — Data layer, Daemon stats and EXP
- [x] Phase 2 — Battle simulation (damage, statuses, capture, AI)
- [x] Phase 3 — Battle screen
- [x] Phase 4 — Overworld, maps, NPCs, dialogue
- [x] Phase 5 — Wild encounters, Active Stack, Bag, CMDB, Server Rack, shop
- [x] Phase 6 — Trainers, Certifications, black-out, saving, options
- [x] Phase 7 — Vertical slice (intro, Route 1, Wi-Fi Dead Zone, Patch Town, Desktop Support Dept.)
- [~] Phase 8 — Platform builds: touch controls, prompts, lifecycle, export presets done ([docs/build.md](docs/build.md)); device builds pending
- [ ] Phase 9+ — Steam page, content, polish, launch

## Legal
All names, creatures, art, text and code are original. No Pokémon assets, names or code are used.
