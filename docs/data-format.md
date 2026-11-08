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
| type | a type id |
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
