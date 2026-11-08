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
Optional `"status_immunities": ["overheated"]` on a type: Daemons of that type can't get those statuses.
Current: Hardware can't Overheat, Power can't be Throttled, Malware can't be Corrupted.
Dual types multiply: `DataRegistry.type_multiplier("network", ["hardware", "power"])`.

## moves.json
| Field | Values |
|---|---|
| type | a type id, or `none` (typeless: always 1x, no STAB) |
| category | `physical` (Throughput vs Hardening), `special` (Compute vs Encryption), `status` |
| power | 0 for status moves, 1–250 otherwise |
| accuracy | 1–100, or **0 = never misses** |
| max_pp | 1–64 |
| priority | −7 to 7 (higher goes first) |
| effect | `{ "id": ..., "params": {...} }`, see below |

Move effects:
| id | params |
|---|---|
| `none` | — |
| `status_chance` | `status` (throttled, corrupted, overheated, standby, hung, looping), `chance` 1–100 |
| `stat_change` | `target` self/foe, `changes` `{stat: ±1..6}`, `chance` 1–100. Stats: throughput, hardening, compute, encryption, bandwidth, accuracy, evasion |
| `drain` | `fraction` of damage dealt healed |
| `recoil` | `fraction` of damage dealt taken back |
| `heal` | `fraction` of max Uptime |
| `multi_hit` | `min`, `max` hits |

**Force Quit** (`force_quit`) is the 0-PP fallback: when every move a Daemon knows is out of PP, choosing
FIGHT uses it automatically (fight slot `BattleSim.FALLBACK_SLOT`). Typeless, power 50, never misses, 1/4 recoil.
It's never put in a learnset. Change it here; the id is `BattleSim.FALLBACK_MOVE`.

## species.json
| Field | Values |
|---|---|
| types | 1 or 2 type ids |
| base_stats | uptime, throughput, hardening, compute, encryption, bandwidth (1–255 each) |
| growth_rate | fast, medium_fast, medium_slow, slow, erratic, fluctuating |
| catch_rate | 1–255 (higher = easier) |
| base_exp | 1–400 |
| log_yield | Experience Logs given when defeated, `{stat: 1–3}`, total ≤ 3 |
| learnset | `[{ "level": 1, "move": "bump" }]` |
| evolutions | `[{ "to": id, "trigger": "level", "level": 16 }]`, `"item"` + `"item": id` (item must have the `evolve` effect), or `"sync"`. `[]` for none |
| cmdb | `{ "category": "Penguin / Echo Unit", "entry": "..." }` |

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
- Uptime = floor((2×Base + BuildQuality + floor(Logs/4)) × Level / 100) + Level + 10
- Others = floor((floor((2×Base + BuildQuality + floor(Logs/4)) × Level / 100) + 5) × profile), profile = 1.1 / 1.0 / 0.9
- Build Quality: 0–31 per stat (random when created). Experience Logs: 0–252 per stat, 510 total.
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

## dialogue/*.json
Every file is an object of `dialogue id → list of steps`. Ids must be unique across all files.
| step | example |
|---|---|
| text | `{"speaker": "Mom", "text": "Hi, {player}!"}` |
| yes/no | `{"choice": "Heal your Daemons?", "yes": [steps], "no": [steps]}` |
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

NPC events can also have `"hide_if_flag": "flag"` to disappear once that flag is set.

## Save files (user://save_a.json, save_b.json)
`{"version", "save_count", "saved_at", "checksum" (sha256 of the data), "data": GameState.to_dict()}`.
Saves alternate between the two files; loading picks the newest one whose checksum matches.
When the save format changes, bump `SaveManager.SAVE_VERSION` and add a step to `migrate()`.
v2 (2026-11-08) renamed the redesigned species ids (`SaveManager.V2_SPECIES_RENAMES`).
Options live separately in user://settings.cfg.

## Phase 7 additions
**Maps:** optional `"music": "town"` (track id, see AudioManager) and `"tint": "#7c88bc"` (darkens the map, e.g. the Wi-Fi Dead Zone).
**Laser doors:** `{"type": "barrier", "x": 7, "y": 9, "open_flags": ["port_1", "port_3"], "closed_flags": ["port_2"]}` blocks its tile until every open flag is set and no closed flag is. Re-checked after every dialogue.
**Arrival triggers:** a trigger zone on a spawn point runs when you arrive there (cutscenes).
**Trainers:** `"story": true` (rival fights: losing doesn't black out, the story continues). Music is picked automatically: battle_boss (has a cert), battle_rival (story), battle_trainer.

| dialogue command | example |
|---|---|
| name_player | `{"cmd": "name_player"}` (presets or type a name) |
| choose_starter | `{"cmd": "choose_starter", "options": ["chipmunk", "pingo", "glowbit"], "level": 5}` sets got_starter + starter_<id> |
| move_player | `{"cmd": "move_player", "path": ["down"]}` |
| set_flag false | `{"cmd": "set_flag", "flag": "port_2", "value": false}` |
