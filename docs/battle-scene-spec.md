# Battle Scene Implementation Spec ("Server Floor")

Brandon's spec, 2026-11-13 (source: "Daemon — Battle Scene Implementation Spec.pdf"). Implemented 2026-11-13;
see "How it's built" at the end for where each part lives and what differs.

## Overview
Replace the grass-field battle scene with a **"Server Floor"** arena that fits Daemon's world: creatures fused
with IT hardware. Two screen states: the wild **encounter** intro and the **command menu**. Keep the existing
tamer and Daemon sprites as they are.

Rules:
- Daemon is not "demon". No demonic, occult or hellfire imagery anywhere.
- It reads as a data center or terminal, not a field. No grass, sky or nature ground.
- Internal resolution 960×640 (3:2), scaled by whole numbers with nearest-neighbor filtering. Every coordinate
  below is in that space, origin top-left.

## Art direction
A dark data center: a back wall of server racks with status LEDs, a glowing raised-floor grid, and "socket pads"
where the grass ovals used to be. UI panels look like process cards and terminal windows: hard edges, 3 px
borders, solid 6 px black drop shadows, no rounded corners, no soft gradients.

### Fixed UI tokens
| Token | Hex | Used for |
|---|---|---|
| host | #3ee6ff | player side: pad, console border, prompt, selected command |
| wild | #ff7a3d | wild side: pad, wild card border, WILD/UNVERIFIED tags |
| panel | #0c1626 | status cards, zone tag, command panel background |
| console | #050a12 | terminal body, UP bar track |
| consoleHeader | #0b1424 | terminal title bar |
| textPrimary | #e8f1ff | levels, numbers |
| textConsole | #d9fbe6 | terminal text, cursor block |
| textMuted | #8fa8cf | title bar text, man line, key hints |
| label | #9fb4d6 | "UP" label |
| barEdge | #2a3a58 | UP bar border, unselected button border, empty signal bar |
| segEmpty | #16223a | empty UP segment |
| upHigh / upMid / upLow | #3dff9a / #ffc43d / #ff4d4d | UP fill above 50% / 21–50% / 20% and below |

### Zone palettes (only the arena changes; UI tokens stay)
| Token | Server Floor | Coolant Loop | Overheat |
|---|---|---|---|
| bg (back wall) | #0a1120 | #05181b | #170909 |
| rack | #111c31 | #0b2428 | #261111 |
| rackEdge | #22344f | #1b4a4f | #4a2020 |
| unit (rack slot) | #0d1729 | #082024 | #1e0d0d |
| floor | #070e1a | #041214 | #120606 |
| grid | #1f5b78 | #1f7f78 | #7a2e1c |
| trim (horizon + zone tag) | #3ee6ff | #7dfff0 | #ffb03d |
| leds (cycle of 4) | #3dff9a #3dff9a #3ee6ff #ffc43d | #7dfff0 #7dfff0 #b9f6ff #3dff9a | #ff5a3d #ffb03d #ff5a3d #ffe07d |
| zone tag text | SERVER FLOOR | COOLANT LOOP | OVERHEAT |

### Fonts (bundled, OFL)
- **Pixelify Sans** 500/700: Daemon names, levels, command labels.
- **VT323**: terminal text, the > prompt, HP numbers, percentages.
- **Silkscreen**: small-caps labels (tags, the UP label, title bar, zone tag, key hints).

## Screen layout (back to front; x, y, w×h)
| # | Layer | Box | Encounter | Menu |
|---|---|---|---|---|
| 1 | back wall | 0,0 960×640 | yes | yes |
| 2 | server rack row | 10,58 940×244, bottoms at y 302 | yes | yes |
| 3 | raised-floor grid | 0,300 960×340 | yes | yes |
| 4 | horizon trim | 0,298 960×4 | yes | yes |
| 5 | wild socket pad | 590,318 290×64 | yes | yes |
| 6 | "UNKNOWN HOST" label | 590,388, 290 wide, centered | yes | no |
| 7 | wild Daemon sprite | on the wild pad (spec: 627,186 217×161) | yes | yes |
| 8 | player socket pad | 40,420 400×92 | yes | yes |
| 9 | tamer sprite (back) | on the player pad (spec: 147,202 186×264) | yes | yes |
| 10 | wild status card | 28,28, 430 wide (~116 tall) | yes | yes |
| 11 | zone tag | top-right, 28 from top and right | yes | yes |
| 12 | player status card | right 28, y 384, 420 wide (~82 tall) | no | yes |
| 13 | console (full width) | 16,476 928×148 | yes | no |
| 14 | console (left part) | 16,476 flexible×148 | no | yes |
| 15 | command panel | right 16, y 476, 420×148, 12 px gap from the console | no | yes |
| 16 | scanline overlay | 0,0 960×640 | optional | optional |

Sprites stand with their feet on the center of their pad (wild ~y 347, tamer ~y 466). The player card overlaps the
bottom edge of the wild pad slightly, on purpose.

## Components
- **Rack row:** 9 racks, 92 px wide, 14 px gaps, heights 232, 244, 220, 244, 236, 244, 224, 244, 232, sharing a
  bottom edge at the horizon. Body = rack with a 2 px rackEdge border (top and sides, no bottom), padding 8 top /
  7 sides; a 6 px rackEdge cap bar, then slots with 6 px gaps. Slots per rack = floor((height − 20) / 20). Each
  slot is 14 px tall (unit fill, 1 px rackEdge border) with two 4×4 LEDs and a 2 px vent line.
  LED colors: k = (rackIndex × 7 + slotIndex × 3) mod 11; LED 1 = leds[k mod 4]; LED 2 = #2a3a58 (off) when
  k mod 3 = 0, else leds[(k+1) mod 4].
- **Raised-floor grid:** floor fill; 3 px grid lines every 96 px on a plane tilted back (~64°), top edge pinned at the
  horizon, centered vanishing point, lines converging toward the racks. The top 70 px fade from floor to
  transparent. Horizon trim: a 4 px line at y 298 with an 18 px glow.
- **Socket pads:** ellipse, 3 px border in the side color, 10–12% fill, ~30 px outer glow at 35–45%, and a 2 px
  dashed inner ring (inset 10×26 on the wild pad, 14×38 on the player pad).
- **Wild status card:** panel fill, 3 px wild border, 6 px shadow; padding 12/16/14, 6 px row gaps.
  Row 1: WILD tag (filled) + UNVERIFIED tag (outline), Lv right-aligned (Pixelify 22 bold).
  Row 2: name (Pixelify 36 bold, white). Row 3: "UP" (Silkscreen 14), the UP bar, percentage (VT323 22, 46 wide).
  UP bar: 20 segments, 2 px gaps, in a console track with a 2 px barEdge border and 3 px padding; 12 px segments;
  filled = round(UP% / 5).
- **Player status card (menu only):** same build, host border, padding 10/16/12. Row 1: HOST tag, name
  (Pixelify 26 bold), level (Pixelify 20). Row 2: UP, 20-segment bar (10 px segments), HP/MAX (VT323 20).
- **Zone tag:** panel fill, 2 px trim border, padding 6×12, Silkscreen 12 #cfe3ff "ZONE // <NAME>", then a signal
  meter of four 4 px bars (5/8/11/14 px tall, 2 px gaps; three trim, the fourth barEdge).
- **Console:** console body, 3 px host border, 6 px shadow. Title bar 26 px (consoleHeader, 2 px #1c2a44 rule),
  Silkscreen 11: "daemon@field" in host, "~/encounter.log", "TTY1" right-aligned. Body: VT323 "> " prompt in host,
  the message in textConsole, a blinking block cursor. Encounter: 46 px text, 18×36 cursor, a pixel down-arrow
  (22×14, host) 22 px from the right and 16 px from the bottom. Menu: "> What will you run?" at 42 px, then
  "man <command> — <description>" at 26 px in textMuted with "man <command>" in host.
- **Command panel:** panel fill, 3 px host border, 6 px shadow, 12 px padding, 2×2 grid with 10 px gaps. Buttons
  ≥ 52 px tall: a 14 px caret slot, the label (Pixelify 22 bold), a key hint [1]–[4] (Silkscreen 11).
  Unselected: #08111f fill, 2 px barEdge border, #e8f1ff text (DISCONNECT in #ff9a6b). Selected: host fill and
  border, #031318 text, a > caret, #0b3a44 key hint.

| Key | Command | man line |
|---|---|---|
| 1 | EXECUTE | run one of your Daemon's moves. |
| 2 | DAEMONS | swap in another Daemon. |
| 3 | INVENTORY | open your gear and patches. |
| 4 | DISCONNECT | drop the connection and flee. |

## Animation and input
| Element | Motion | Timing |
|---|---|---|
| Rack LEDs | drop to 15% for a brief stepped flicker | 2.6 s loop; LED 1 offset (k × 0.37) mod 2.6 s, LED 2 (k × 0.61 + 0.4) mod 2.6 s |
| Wild Daemon | bobs up 6 px and back | 2.4 s ease-in-out loop |
| Pad dashed rings | opacity 55% → 100% | 2 s ease-in-out loop |
| Console cursor | hard on/off blink | 1 s, 50% duty |
| Continue arrow | drops 4 px and back, stepped | 1 s, 2 steps |
| Scanlines | 1 px black line at 16% every 3 px, static | off in settings for accessibility |

**Encounter flow:** the arena draws, the wild Daemon materializes on its pad, the wild card slides in; the console
types "> A wild <Name> spawned!", then the cursor and continue arrow show. Confirm moves on; the tamer stays on the
player pad until a Daemon is sent out, then the Daemon's back sprite replaces the tamer and the player card appears.

**Command menu input:** arrows / D-pad / stick move around the 2×2 grid; number keys 1–4 jump to a command; mouse or
touch selects on tap. Every selection change updates the man line. Confirm runs the command; Back does nothing on
the root menu. Touch targets ≥ 44 px tall at the final display scale.

**UP bar:** segments = round(UP% / 5), clamped 0–20. Damage empties segments one at a time, right to left, ~40 ms
each. Color follows the current percentage (green > 50, amber 21–50, red ≤ 20).

**Zones:** each encounter area picks one palette; only arena tokens and the zone tag text change.

## Acceptance checklist
- [x] No grass, sky or field visuals remain in the battle scene
- [x] Rack row, floor grid, horizon trim and both socket pads at the specified positions
- [x] Sprites crisp at whole-number scales with nearest-neighbor filtering
- [x] Wild card: WILD and UNVERIFIED tags, name, level, 20-segment UP bar with the color thresholds
- [x] Console: title bar, > prompt, blinking cursor, continue arrow
- [x] Command menu EXECUTE / DAEMONS / INVENTORY / DISCONNECT with arrow-key, 1–4 and pointer input
- [x] The man line updates on every selection change
- [x] All three zone palettes switch with no layout change
- [x] Scanlines can be turned off (Options > CRT EFFECTS)
- [x] The scene scales by whole numbers from 960×640 without blurring (screens of at least 960×640)

## Open items from the spec, and what we decided
- Player Daemon name, level, HP and back sprite: real data from the battle.
- Pyrewall's level: comes from encounter data (the mockup hard-coded 50).
- "UNVERIFIED" / "UNKNOWN HOST": kept as flavor text for now; confirm or replace.
- Zone per area (Brandon, 2026-11-13): Server Floor = Onboarding Town, Route 1, Patch Town; Coolant Loop = Wi-Fi Dead
  Zone; Overheat = Department 1. Set per map with `"battle_zone"` in data/maps/<id>.json.

## How it's built (2026-11-13)
- `scripts/battle/battle_scene.gd`: a 960×640 `Stage` scaled to the largest whole number of *physical* pixels that
  fits (fractional below 960×640, e.g. phones), centered; the arena and scanlines fill the rest of the view instead
  of letterboxing. Sprites, trainers, move effects and the Quarantine Key sit on a ×3 `Field` layer.
- `scripts/battle/ui/battle_style.gd`: tokens, zone palettes, fonts, panel/tag/UP-bar drawing.
- `scripts/battle/ui/battle_arena.gd`: wall, racks + LEDs, floor grid, trim, pads, UNKNOWN HOST, zone tag.
- `scripts/battle/ui/battle_info_panel.gd`: the process cards. `battle_console.gd`: the terminal (extends TextBox).
  `battle_menu.gd` + `term_button.gd`: command, move, list and confirm menus.
- Sprite sizes: our Daemon art is 64×64 frames, so the wild Daemon is ×3 (192 px) and the player's Daemon and the
  tamer are ×4, close to the spec's ×7 / ×6 boxes for the 31×23 / 31×44 mockup sprites.
- Differences from the spec, on purpose:
  - Trainer battles show a HOSTILE tag instead of WILD + UNVERIFIED.
  - The player card has a thin EXP strip along the bottom.
  - The move menu reuses the command panel (2×2, keys 1–4); its man line shows type, power and Cycles, and a BACK
    button sits in the console's lower right. Lists (DAEMONS, INVENTORY) open as a large terminal window.
  - A wild Daemon materializes with a few white flickers; a trainer's Daemon still slides in.
  - Reduced motion (Options > LESS MOTION) stops the LED flicker, pad pulse and bob.
