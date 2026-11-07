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
