# Data format

All game data lives in `data/` as JSON. DataRegistry loads it at startup and DataValidator
(`scripts/util/data_validator.gd`) checks it. Errors print as one line each, like
`species › chipmunk › learnset[2]: unknown move 'heatsnk_slam'`.

Ids are `lower_snake_case` and unique within a file. Lists, not objects, so duplicates get caught.

## types.json
```json
{ "types": [ { "id": "hardware", "name": "Hardware", "color": "#e0703c" } ],
  "chart": { "hardware": { "software": 2, "network": 0.5 } } }
```
`chart[attacker][defender]` is 0, 0.5 or 2. Anything missing = 1.
Optional `"status_immunities": ["overheated"]` on a type: Forgeling of that type can't get those statuses.
Current: Hardware can't Overheat, Power can't be Throttled, Malware can't be Infected.
Dual types multiply: `DataRegistry.type_multiplier("network", ["hardware", "power"])`.

## moves.json
| Field | Values |
|---|---|
| type | a type id, or `none` (typeless: always 1x, no STAB) |
| category | `physical` (Throughput vs Hardening), `special` (Compute vs Encryption), `status` |
| power | 0 for status moves, 1–250 otherwise |
| accuracy | 1–100, or **0 = never misses** |
| max_pp | 1–64. Shown to players as **Cycles** ("CYC 20/25"); the field keeps its old name |
| priority | −7 to 7 (higher goes first) |
| effect | `{ "id": ..., "params": {...} }`, see below |

Move effects:
| id | params |
|---|---|
| `none` | — |
| `status_chance` | `status` (throttled, infected, overheated, standby, hung, looping), `chance` 1–100 |
| `stat_change` | `target` self/foe, `changes` `{stat: ±1..6}`, `chance` 1–100. Stats: throughput, hardening, compute, encryption, bandwidth, accuracy, evasion |
| `drain` | `fraction` of damage dealt healed |
| `recoil` | `fraction` of damage dealt taken back |
| `heal` | `fraction` of max Uptime |
| `multi_hit` | `min`, `max` hits |

**fx** (optional, every move has one): the move's battle effect, a list of steps played between "X ran Y!"
and the hit (`scripts/battle/ui/battle_fx.gd`). Each step: `kind` (burst, stream, rings, beam, bolt, rise, fall,
orbit, glitch, flash, dim, cover, shield, wall, xmark, slices), optional `color` ("type" = the move's type color,
or "#rrggbb"), `on` ("user"/"target"), `glyph` for particles (square, dot, plus, arrow_up, arrow_down, z, key,
envelope, cell, code, wave, hook, drop), size/count/radius knobs, and `"parallel": true` to start the next step at
once. Example (Packet Flood): `[{"kind": "stream", "count": 18, "size": 3}, {"kind": "burst", "count": 10}]`.

**Force Quit** (`force_quit`) is the 0-Cycles fallback: when every move a Forgeling knows is out of Cycles, choosing
FIGHT uses it automatically (fight slot `BattleSim.FALLBACK_SLOT`). Typeless, power 50, never misses, 1/4 recoil.
It's never put in a learnset. Change it here; the id is `BattleSim.FALLBACK_MOVE`.

## species.json
| Field | Values |
|---|---|
| number | CMDB number from the master roster (0–999, unique). Shown as "#028" in the CMDB list and "DMN-028" on the record. Gaps are fine: roster slots not built yet keep their number. Keep the file sorted by it |
| types | 1 or 2 type ids |
| base_stats | uptime, throughput, hardening, compute, encryption, bandwidth (1–255 each) |
| growth_rate | fast, medium_fast, medium_slow, slow, erratic, fluctuating |
| catch_rate | 1–255 (higher = easier) |
| base_exp | 1–400 |
| log_yield | Experience Logs given when defeated, `{stat: 1–3}`, total ≤ 3 |
| learnset | `[{ "level": 1, "move": "bump" }]` |
| evolutions | `[{ "to": id, "trigger": "level", "level": 16 }]`, `"item"` + `"item": id` (item must have the `evolve` effect), or `"sync"`. `[]` for none |
| cmdb | `{ "category": "Penguin / Echo Unit", "entry": "..." }` |
| art (opt) | `{ "flip_back": true }` mirrors the back poses in battle (for sheets whose back view was drawn facing left; your Forgelings must face up-right toward the foe) |
| legendary (opt) | `true` for legendaries (Pyrewall). Informational for now; low `catch_rate` does the gameplay work |

## items.json
| Field | Values |
|---|---|
| pocket | items, keys (Quarantine Keys), scripts, key_items |
| price | Credits, 0 = can't buy |
| effect | `heal_uptime {amount}`, `full_restore`, `revive {fraction}`, `repel {steps}`, `escape`, `capture {bonus}`, `level_up`, `evolve` |

Starter design rule so far: each starter line has base stat totals of 310 / 405 / 530.

## config_profiles.json
25 profiles. Each raises one stat by 10% and lowers another by 10% (`up`, `down`), or is neutral
(`up` and `down` both `null`; there are 5 neutral ones). Uptime is never affected.
Each non-neutral up/down pair appears exactly once.

## How stats are calculated (scripts/daemon/daemon_instance.gd)
- core = floor((2×Base + 2×BuildQuality + floor(Logs/2)) × Level / 100)
- Uptime = core + Level + 12
- Others = floor((core + 6) × profile / 100), profile = 110 (boosted) / 100 / 95 (lowered)
- Build Quality: 0–15 per stat (random when created). Experience Logs: 0–64 per stat, 192 total.
- 21 Config Profiles in `data/config_profiles.json`: "balanced" plus every (up, down) pair of the 5 battle stats.
- Saves from before 2026-11-13 (save version 2) are converted on load: Build Quality halved, Logs scaled by 64/252.
- EXP curves: `scripts/daemon/growth_rate.gd`. Total EXP to reach level 100: fast 800,000 · medium_fast 1,000,000 · medium_slow 1,059,860 · slow 1,250,000 · erratic 600,000 · fluctuating 1,640,000.

## tiles.json (overworld tiles)
One entry per 16x16 tile in `assets/tiles/placeholder_overworld.png` (8 per row).
| Field | Values |
|---|---|
| name | unique id used by map legends |
| atlas | [column, row] in the PNG |
| collision | true = can't walk onto it |
| behavior | none, hot_zone (wild encounters, Phase 5), ledge_down (hop down only), water (blocked until surfing), door (warp, Phase 4b), counter (talk across) |

These become TileSet custom data ("name", "collision", "behavior"), which movement reads.
Regenerate the placeholder PNG: `godot --headless -s res://tools/build_placeholder_tiles.gd`.

## maps/<id>.json
```json
{ "id": "onboarding_town", "name": "Onboarding Town",
  "legend": { ".": "grass", "T": "tree" },
  "rows": [ "TTTT", "T..T", "TTTT" ],
  "spawns": { "default": { "x": 1, "y": 1, "facing": "down" } } }
```
Each row is one line of the map; every row must be the same width. Each character must be in the
legend. Spawns must be on a walkable tile. Maps load on first use and are validated then.

### Map events (`"events": [...]` in a map file)
| type | fields | what it does |
|---|---|---|
| warp | x, y, to_map, to_spawn | step on it → fade to that map's spawn. Put on doors, exit mats, route edges |
| sign | x, y, dialogue | press A facing it |
| npc | id, x, y, facing, dialogue, wander (opt), look {shirt, hair} (opt) | solid; press A facing it (turns to you). Wanders within 2 tiles if wander is true |
| trigger | x, y, w, h (opt), dialogue, once_flag / requires_flag / unless_flag (opt) | runs when you walk into the zone |
| hidden_item | x, y, item, count (opt), flag | press A facing that tile to find it, once |

Counters let you talk across them (A reaches one tile further).

NPC `look`: `shirt` and `hair` colors draw a 16x16 placeholder; `"sprite": "<id>"` uses the character art in
`assets/sprites/characters/<id>.png` instead (3 frames x 4 directions of 20x28, centered on the tile with the feet on it). The data
checker fails if that file doesn't exist.

## dialogue/*.json
Every file is an object of `dialogue id → list of steps`. Ids must be unique across all files.
| step | example |
|---|---|
| text | `{"speaker": "Mom", "text": "Hi, {player}!"}` |
| yes/no | `{"choice": "Heal your Forgelings?", "yes": [steps], "no": [steps]}` |
| flag check | `{"if_flag": "got_coffee", "then": [steps], "else": [steps]}` |
| set_flag | `{"cmd": "set_flag", "flag": "met_kevin", "value": true}` |
| give_item | `{"cmd": "give_item", "item": "coffee", "count": 3}` |
| give_daemon | `{"cmd": "give_daemon", "species": "dustbunny", "level": 5}` |
| heal_party | `{"cmd": "heal_party"}` |
| start_battle | `{"cmd": "start_battle", "trainer_name": "Kevin", "ai": "basic", "foe": [["spigeon", 6]]}` (ends the dialogue; you come back to the same spot) |
| move_npc | `{"cmd": "move_npc", "npc": "self", "path": ["up", "down"]}` |

## encounters/<map id>.json
```json
{ "rate": 0.12,
  "zones": { "cable_tangle": [ { "species": "dustbunny", "min": 2, "max": 4, "weight": 35 } ] } }
```
`rate` is the chance per step on a hot_zone (or water) tile. Zones are keyed by tile name. Slots are
picked by weight; level is random in min..max. A Firewall Rule blocks results below the lead's level.

### More dialogue commands
| command | example |
|---|---|
| open_shop | `{"cmd": "open_shop", "stock": ["coffee", "thumb_drive"]}` (items need a price) |
| open_rack | `{"cmd": "open_rack"}` (Server Rack storage) |

## trainers/<file>.json
Object of `trainer id → trainer`. Ids are unique across files.
```json
"intern_ian": { "name": "Intern Ian", "team": [["dustbunny", 4], ["wormby", 4]], "ai": "basic",
  "prize": 160, "sight": 3, "cert": "desktop_support",
  "intro": "Battle me!", "defeat": "I should have opened a ticket first...", "after": "I'm still on probation." }
```
`sight` = how many tiles ahead they spot you (0 / missing = only when you talk to them). `cert` is optional
(Department bosses). Put a trainer on a map with an npc event: `{"type": "npc", "id": "intern_ian", "x": 11,
"y": 18, "facing": "left", "trainer": "intern_ian"}` (add "dialogue" too for custom talk). Beating one sets
the flag `trainer_<id>`.

## certifications.json
8 entries: id, name, department, type (badge color), order (slot on the trainer card).

### More dialogue
| step | example |
|---|---|
| start_battle (trainer) | `{"cmd": "start_battle", "trainer": "kevin_town"}` |
| give_cert | `{"cmd": "give_cert", "cert": "networking"}` |
| cert check | `{"if_cert": "networking", "then": [steps], "else": [steps]}` |

NPC events can also have `"hide_if_flag": "flag"` to disappear once that flag is set, or `"hidden": true` to
start off the map (not drawn, not solid) until a `show_npc` cutscene step brings them in.

Trainers can have `"sprite": "<character id>"` (assets/sprites/characters/<id>.png). In battle, that figure
(front view) and you (from behind) slide onto the platforms first, then step out of frame as each side's first
Forgelings comes out. Wild battles show only you.

## title_screen.json

Copy and the featured legendary for the title screen (built to the 2026-11-11 Start Screen Style Guide; every
layout/color/timing value lives in `scripts/ui/title/title_style.gd`).

- `tagline`, `prompt`: text under the logo and the blinking prompt.
- `boot_log`: terminal lines typed in the bottom-left; `{count}` becomes the number of species.
- `featured`: legendaries that can take the hero spot (the first one is shown today). Each has `id`, `label`,
  `name`, `fusion`, `flavor` (the card), `a11y` (screen-reader label) and `sprite`. If `id` is a species the
  card shows its CMDB number; a title-only legendary needs a `number` instead.
  `sprite`:
  - `half`: the LEFT half of the pixel map, rows of up to 16 characters (`.` = transparent). Rows are padded
    to 16 and mirrored, so the sprite is 32 wide with no seam. Drawn at 11x.
  - `palette`: character -> `#hex`, or `"accent"` to follow the theme accent color.
  - `anim`: character -> `flicker` (flame), `core` / `core_accent` (pulse), or `eye` (blink).

`tools/art_import/pixel_map_sheet.gd -- <id>` turns a featured sprite into that Forgeling's battle sheet
(`assets/sprites/daemons/<id>_sheet.png`, 2x, poses by shape so it stays under 16 colors).

`data/build_info.json` (`{"build": n}`) is the build number on the title's version tag; the web deploy writes
its run number there before exporting.

## feedback.json (in-game Feedback)
`{"endpoint": "https://daemons-feedback.<you>.workers.dev", "min_message": 10, "max_message": 2000, "categories": ["bug", "idea", "other"]}`.
`endpoint` must be `""` (feature off) or an `https://` URL of the relay in `services/feedback-worker/`. The limits must
match the Worker's `LIMITS`. Offline reports wait in `user://feedback_outbox.json`.

## balance.json (tuning knobs)
`{"starting_credits": 3000, "exp_divisor": 7, "trainer_exp_bonus": 1.5, "exp_scaling": {"power": 2.5, "offset": 10}, "uptime_bonus": 20, "damage": {"level_offset": 4, "divisor": 108}, "loss_penalty": {"percent": 10, "cap_base": 300, "cap_per_cert": 300}}`.
EXP per defeated foe = floor(base_exp x level / exp_divisor), x trainer_exp_bonus in trainer battles, split between
participants, then each share x ((2 x foe + offset) / (foe + mine + offset)) ^ power (exp_scaling; power 0 = off).
Max Uptime = core + level + `uptime_bonus` (a flat bonus that matters most at low levels).
Damage = floor(Power x Atk x (level + `level_offset`) / (Def x `divisor`)) + 2, then crit, roll, native type, effectiveness.
tests/test_early_balance.gd keeps early fights winnable but not pushovers, and fails if any early foe can
one-shot a full-Uptime starter without a crit.
Blacking out costs `percent`% of your credits, at most `cap_base + cap_per_cert x certs` (`GameState.blackout_loss()`).

## region_map.json (the phone's Maps app)
`{"name", "locations": [{"id", "name", "kind": town|route|wild|dungeon|locked, "x": 0-288, "y": 0-136, "maps": [map ids],
"blurb", optional "label_at": above|below|left|right, "short", "show_if_flag"}], "links": [[place, place]],
"exits": [{"from": place, "label"}]}`. Every map in data/maps must belong to exactly one place (`DataRegistry.region_of`).
A place is named once visited (`GameState.visited`), shown as ??? when it's next to a visited place, hidden otherwise;
`show_if_flag` places appear only once the flag is set.

## Upgrade triggers (GDD: items and events, not only levels)
Species `"evolutions": [{"to": id, "trigger": ...}]`, triggers:
`{"trigger": "level", "level": 16}` · `{"trigger": "item", "item": "legacy_driver"}` (an item with the `evolve`
effect: firmware, patches) · `{"trigger": "flag", "flag": "port443_flicker"}` (a story event) ·
`{"trigger": "cert", "certs": 2}` (Certifications held) · `{"trigger": "sync"}` (Discohare's old special).
Flag and cert upgrades happen right after the dialogue that sets the flag or awards the Cert, and after a boss
battle's Cert (stack and racks; corrupted ones wait until cleaned).

**Triggers still to decide (Brandon), current values kept:**
- Chipmunk → Munkboard (level: Lv 16)
- Munkboard → Mainmunk (level: Lv 34)
- Pingo → Pengwan (level: Lv 16)
- Pengwan → Emperoute (level: Lv 34)
- Glowbit → Scriptfly (level: Lv 16)
- Scriptfly → Compilume (level: Lv 34)
- Wormby → Wormhole (level: Lv 22)
- Spigeon → Botgeon (level: Lv 25)
- Cablesnake → Patchviper (level: Lv 24)
- Floppit → Ziphare (item: legacy_driver)
- Ziphare → Discohare (sync: sync)
- Clawptop → Deskclaw (level: Lv 20)
- Deskclaw → Crabinet (level: Lv 38)
- Antsistor → Transistant (level: Lv 18)
- Transistant → Siliqueen (level: Lv 36)
- Coolippo → Coolapotamus (level: Lv 28)
- Dillodisk → Armadrive (level: Lv 26)
- Spinode → Meshpider (level: Lv 18)
- Meshpider → Arachnet (level: Lv 34)
- Calfiber → Orcable (level: Lv 30)
- Proxkit → Proxferret (level: Lv 24)

## level_caps.json (GDD level cap)
`{"note": "...", "caps": [14, 20, 28, 36, 42, 48, 54, 60, 100]}`: `caps[n]` is the highest level while holding n
Certifications. **Placeholder numbers (TBD), flagged for balancing.** EXP stops at the cap and the overflow is
discarded (battle: "MUNKBOARD needs a new certification to grow further.", once per battle); Overclock Chips are
refused at the cap and not used up. Validated: 9 levels, 1-100, never going down. Battle config `level_cap` overrides
(tests). Certification order follows the GDD: Data is Cert 5, Security Cert 6.

## Corrupted Forgelings (2026-11-15)
The same species in a glitched, hostile state (Ransom's code pushed through the broken Hexforge). Not a separate
species or CMDB entry: `DaemonInstance.is_corrupted` (saved as `"corrupted"`).
- **species.json** optional block, only for species met in the wild and never Malware lines (validated):
  `"corrupted": {"sprite_front": "assets/sprites/hexforged/corrupted/<id>_front.png", "name_prefix": "ERR::",
  "add_type": "Malware", "stat_mods": {"throughput": 1.10, "encryption": 0.90}}`. Blocks so far: Pyrewall,
  Cablesnake, Floppit, Dustbunny, Fanbat, Ramster, Servurtle.
- **While corrupted:** second type becomes Malware (Security hits it super-effectively), stats x `stat_mods`
  (never Uptime), name `ERR::CABLESNAKE`. Trainer AI unchanged.
- **Encounters:** per-slot `"corrupted_chance": 0.0-1.0` (only on species with a block). Battle config foe entry
  `[species, level, true]` spawns the corrupted version.
- **Catching:** any Quarantine Key; it goes to `GameState.quarantined` (Bag > QUARANTINED page), never the stack or
  rack, and can't battle. **Cleaning:** dialogue `{"cmd": "clean_quarantined"}` (in every Help Desk script) runs
  the shared CleanEffect (scripts/ui/clean_effect.gd: glitch slices, falling void squares, 4-step dithered palette
  swap) and adds the clean version like a new catch: "ERR::CABLESNAKE was restored to CABLESNAKE!".
- **CMDB:** seeing one counts as seen; record shows `Status: COMPROMISED | Note: Unauthorized code detected. Do not
  connect to production.` until a Help Desk cleans one (`Status: Recovered`).
- **Art:** front-only 6 frames (idle, idle_b, attack, special, hurt, faint), 384x64. Until it exists,
  DaemonSprites.corrupted_pose() makes a placeholder from the normal pose (ashy palette, shifted rows, red #D41E3C
  pupils, void pixels).

## Save files (user://save_a.json, save_b.json)
`{"version", "save_count", "saved_at", "checksum" (sha256 of the data), "data": GameState.to_dict()}`.
Saves alternate between the two files; loading picks the newest one whose checksum matches.
When the save format changes, bump `SaveManager.SAVE_VERSION` and add a step to `migrate()`.
v2 (2026-11-08) renamed the redesigned species ids (`SaveManager.V2_SPECIES_RENAMES`).
Options live separately in user://settings.cfg.

## Phase 7 additions
**Maps:** optional `"music": "town"` (track id, see AudioManager) and `"tint": "#7c88bc"` (darkens the map, e.g. the Wi-Fi Dead Zone), and `"battle_zone"`: `server_floor` (default), `coolant_loop` or `overheat`, the battle arena palette for fights in that area.
**Laser doors:** `{"type": "barrier", "x": 7, "y": 9, "open_flags": ["port_1", "port_3"], "closed_flags": ["port_2"]}` blocks its tile until every open flag is set and no closed flag is. Re-checked after every dialogue.
**Arrival triggers:** a trigger zone on a spawn point runs when you arrive there (cutscenes).
**Trainers:** `"story": true` (rival fights: losing doesn't black out, the story continues). Music is picked automatically: battle_boss (has a cert), battle_rival (story), battle_trainer.

| dialogue command | example |
|---|---|
| name_player | `{"cmd": "name_player"}` (presets or type a name) |
| choose_starter | `{"cmd": "choose_starter", "options": ["chipmunk", "pingo", "glowbit"], "level": 5}` sets got_starter + starter_<id> |
| move_player | `{"cmd": "move_player", "path": ["down"]}` |
| set_flag false | `{"cmd": "set_flag", "flag": "port_2", "value": false}` |
| show_npc | `{"cmd": "show_npc", "npc": "kevin_burst", "facing": "up"}` (a `"hidden"` NPC appears on its tile) |
| hide_npc | `{"cmd": "hide_npc", "npc": "kevin_burst"}` |
| choose (step) | `{"choose": "What's the fix?", "title": "FIX", "options": [{"label": "CLEAN DUST", "then": [...]}, ...], "cancel": [...]}`: 2–8 answers in the side list, labels up to 12 characters |
| if_var (step) | `{"if_var": "load", "op": ">", "value": 12, "then": [...], "else": [...]}` (ops `== != < <= > >=`) |
| add_var / set_var | `{"cmd": "add_var", "var": "load", "value": -4}` / `{"cmd": "set_var", "var": "pipeline", "value": 0}`; counters live in `GameState.counters` (saved) |
| clear_flags | `{"cmd": "clear_flags", "flags": ["log_auth", "log_vpn"]}` |
| send_player | `{"cmd": "send_player", "spawn": "default"}`: after the dialogue's event finishes, fade and move to that spawn on this map |

| end_demo | `{"cmd": "end_demo"}`: sets `demo_complete`, saves, plays the end card + credits from `data/demo_end.json` (`card` lines, `credits` [role, name] pairs, `thanks`) |

Text can show a counter: `"LOAD METER: {var:load} / 12 kW"`.

**Packet lanes** (tiles `lane_up/down/left/right`, behaviors `slide_*`): stepping on one carries you along its arrow
until you land on a tile that isn't a lane, the next tile is blocked, or the ride would revisit a tile.
**Cameras:** `{"type": "camera", "x", "y" (a solid tile), "facing", "range", "turns": ["right", "down"], "turn_every": 2,
"send_to": "default", "dialogue": "caught_by_camera", "off_flag": "sec_found"}`. They turn on your steps; if the
beam covers you after a turn you're walked back to `send_to`.
**Dark rooms:** a map's `"dark_until_flag": "brk_lights"` (+ optional `"dark_tint"`) keeps it dark until the flag is set.

### Department challenges (2026-11-15)
| Dept | Challenge | Mechanic | Door opens when |
|---|---|---|---|
| 1 Desktop Support | Ticket triage | 3 users, pick the fix (choose); a wrong fix starts a fight | ticket_a/b/c_fixed |
| 2 Networking | Packet lanes | lane maze, 16+ moves, no soft-locks (tests/test_departments.gd checks it) | (no door: reach Ping) |
| 3 DevOps | Pipeline | 6 stages in order via `pipeline` counter; out of order or the Friday hotfix rolls back + bug fight | pipeline_green |
| 4 Facilities | Power budget | dark room, 7 breakers, `load` counter, over 12 kW trips back to Ransom's state; servers off crashes | servers + cooling + door on, rig off |
| 5 SecOps | Stealth + forensics | turning cameras, 3 log printouts, name the account (svc_backup); wrong answer re-shreds the logs | sec_found |
| move_npc to player | `{"cmd": "move_npc", "npc": "kevin_burst", "to": "player", "run": true}` (walks the shortest free path to a tile next to you; both turn to face each other. `"run"` doubles the speed, also works with `"path"`) |
