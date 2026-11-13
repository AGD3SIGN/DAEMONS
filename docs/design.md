# DAEMONS — IT Monster Tamer: Game Design + Phased Build Plan

> Working title. "Daemons" are the creatures (named after Unix background processes). Do a trademark search before going public with the name.
>
> How to use this doc:
> 1. Section 1 is the creative concept. Edit it however you want.
> 2. Section 2 is a ready-made `CLAUDE.md`. Drop it in the repo root so Claude Code always has the project rules.
> 3. Section 3 has the phases. Each one is a self-contained prompt you paste into Claude Code, plus a "done when" checklist. Do one phase (or one sub-step) per session, commit, playtest, move on.

---

## 1. The concept

### Pitch
An early-2000s handheld-style, top-down, turn-based creature collector set in a world where tech comes alive. You're a new hire on the help desk at **Root Valley**, a tech town where wild Daemons live in server rooms, cable runs, abandoned data centers and the cloud. Catch them, train them, patch them into stronger versions, earn all 8 **Certifications**, and take down **Ransom**, a syndicate that's encrypting the whole valley.

### Core loop
Explore → find wild Daemons in "hot zones" (**cable tangles**, server racks, Wi-Fi dead zones) → battle → **Quarantine** them into a USB key → build an **Active Stack** of 6 → beat trainers and Department bosses → unlock new areas → fill the **CMDB**.

### Glossary
| Term | What it is |
|---|---|
| **Daemon** | a living tech creature, named after Unix background processes |
| **Quarantine Key** | a USB stick that captures a weakened wild Daemon, chosen from the Bag in battle. Tiers: Thumb Drive → Encrypted Key → Hardware Token → Root Key (guaranteed) |
| **CMDB** | Configuration Management Database: your record of every Daemon seen and caught, written like asset records (DMN-### numbers) |
| **Help Desk** | free healing; the tech asks "Have you tried turning it off and on again?" |
| **Supply Closet** | the shop |
| **Server Rack** | storage for Daemons beyond your stack (racks = boxes of units) |
| **Active Stack** | the 6 Daemons you carry |
| **Departments** | the 8 bosses; beating one earns a **Certification**, which opens new areas |
| **The C-Suite** | CIO, CISO, CTO and CFO, then the final boss, **The Board** |
| **Ransom** | the villain syndicate (grunts = "Phishers", admins = "Exploit Kits") |
| **Upgrading** | a Daemon growing into its next stage: "Your Pingo is upgrading!" |
| **Sync** | upgrading that needs a link with another save file (later, local multiplayer) |
| **Coffee / Energy Drink / Pizza Friday** | healing items, small to full |
| **Hard Reboot** | brings back a crashed Daemon |
| **Firewall Rule** | keeps weaker wild Daemons away for a while |
| **Ctrl+Z** | escape back to a dungeon's entrance |
| **Scripts** | reusable items that teach a move |
| **Overclock Chip** | +1 level |
| **Credits** | money |
| **Cycles** | how many times a Daemon can still run a move |
| **Kevin** | your rival, the guy who always replies-all |

### Stats (6)
| Stat | Meaning |
|---|---|
| **Uptime** | how much it can take before it crashes |
| **Throughput** | physical damage |
| **Hardening** | physical defense |
| **Compute** | special damage |
| **Encryption** | special defense |
| **Bandwidth** | who goes first |

Every Daemon also has hidden **Build Quality** (0–15 per stat, random when it's created), **Experience Logs** earned from battles (up to 64 per stat, 192 total) and a **Config Profile** (21 profiles: Balanced, or +10% to one stat and −5% to another, e.g. "Aggressive", "Defensive", "Power-Saver").

Our formulas (see `scripts/daemon/daemon_instance.gd` and `scripts/battle/sim/battle_sim.gd`):
- Stats: core = (2×Base + 2×BQ + Logs/2) × Level/100; Uptime = core + Level + 12; others = (core + 6) × profile.
- Damage: Power × Atk × (Level + 10) / (Def × 120) + 2, then ×1.5 on a critical hit (1 in 20), ×0.88–1.00 random, ×1.35 when the move matches one of the user's types, × type effectiveness.
- Quarantine: chance = catch rate/255 × key bonus × status bonus (1.8 Standby/Hung, 1.4 Throttled/Corrupted/Overheated) × (1 − 0.75 × Uptime/Max). The transfer runs three stages (Scanning, Isolating, Encrypting); each passes with chance^(1/3).

### Types (12)
Hardware, Network, Software, Power, Cloud, Data, Security, Malware, Legacy, Mobile, AI, Peripheral.

Starter triangle: **Hardware** beats **Software** ("you can't patch bad RAM"), **Software** beats **Network** ("SDN reroutes it"), **Network** beats **Hardware** ("a flood of packets cooks the box").

Draft type chart (attacker → defender; 2 = super effective, ½ = resisted, 0 = no effect). This is a starting point; tune it in playtesting.

| Atk \ Def | HW | NET | SW | PWR | CLD | DATA | SEC | MAL | LEG | MOB | AI | PER |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Hardware | ½ | ½ | 2 | | | | | | 2 | | | 2 |
| Network | 2 | ½ | ½ | | 2 | | | | | 2 | | |
| Software | ½ | 2 | ½ | | | 2 | | | | | | |
| Power | 2 | | | ½ | | | | | | 2 | | 2 |
| Cloud | | | | | ½ | 2 | | | 2 | | | |
| Data | | | | | | ½ | | | | | 2 | |
| Security | | | | | | | ½ | 2 | | | | |
| Malware | | | 2 | | | 2 | 0 | ½ | | 2 | | |
| Legacy | 2 | | | | ½ | | | | ½ | | ½ | |
| Mobile | | 2 | | ½ | | | | | 2 | ½ | | |
| AI | | | 2 | | | 2 | ½ | | | | ½ | |
| Peripheral | | | | ½ | | | | | | | | ½ |

(Blank = normal damage. Security being immune to Malware gives the anti-virus fantasy.)

### Status effects
| Status | Effect |
|---|---|
| **Throttled** | Bandwidth halved, 25% chance to skip its turn |
| **Corrupted** | loses 1/8 Uptime each turn |
| **Overheated** | loses 1/16 Uptime per turn, Throughput halved |
| **Standby** | can't act for 1–3 turns |
| **Hung** | can't act; 20% chance per turn to recover |
| **Looping** | volatile; 33% chance to hit itself |

### Sample Daemons (original designs, starting roster ideas)
**Rule:** an evolution line keeps the SAME animal. The animal grows up (baby → adult → elder) while its tech upgrades (home → business → enterprise gear).

| Line | Type | Concept |
|---|---|---|
| **Chipmunk → Munkboard → Mainmunk** | Hardware (starter) | baby chipmunk + CPU heatsink (heatsink cheeks, fan tail) → adult chipmunk + motherboard (copper-trace stripes, RAM-stick cheek pouches) → huge elder chipmunk + mainframe (server-cabinet chest, cable mane, twin-fan tail) |
| **Pingo → Pengwan → Emperoute** | Network (starter) | penguin chick + home router (2 antennas, belly LEDs) → adult penguin + office switch (antenna crown, port-panel belly) → emperor penguin + internet backbone (satellite-dish crest, fiber-optic cape) |
| **Glowbit → Scriptfly → Compilume** | Software (starter) | baby firefly whose tail blinks like a cursor (`>_` face) → adult firefly with code-window wings that writes script in the air → giant firefly whose abdomen is a build-progress bar |
| **Wormby → Wormhole** | Malware | worm that tunnels through cables → space-warping worm |
| **Spigeon → Botgeon** | Malware | scruffy pigeon with envelope wings, stuffed with junk mail → huge pigeon commanding a botnet (dish feathers, "!!!" crest) |
| **Floppit → Ziphare → Discohare** | Legacy | bunny with 3.5" floppy ears → grown hare + zip disk (via a Legacy item) → elder hare + rainbow CD ears (via sync) |
| **Fanbat** | Hardware/Power | bat with case-fan wings; swarms server rooms |
| **Dustbunny** | Peripheral | early-route common; scrappy and cute |
| **Captchat** | Security | cat that only lets "humans" pass; confusion moves |
| **Cablesnake → Patchviper** | Network | snake made of tangled ethernet; lives in cable tangles |
| **Phishgill** | Malware/Data | anglerfish with a fake "login" lure |
| **Cumulonimbyte** | Cloud | storm cloud that rains data; late-game |
| **Hallucinaut** | AI | glitchy astronaut that's confidently wrong; legendary-tier |
| **Uptimus** | Power/Security | legendary UPS guardian of the valley's power grid |
| **Pyrewall** (No. 000) | Security/Hardware | legendary golden pheasant x firewall, guardian of Port 443; its wings are brick firewalls with the flames kept inside. On the title screen. Signature moves: Burn Rule, Ash Reboot |
| **Clawptop → Deskclaw → Crabinet** | Hardware | hermit crab that lives in computer cases instead of shells: laptop → desktop tower → server cabinet. Big cream-tipped right claw, eye stalks |
| **Antsistor → Transistant → Siliqueen** | Hardware | ant colony that builds circuits: transistor abdomen → microchip soldier → chip-foundry queen with a wafer abdomen |
| **Coolippo → Coolapotamus** | Hardware | hippo + liquid cooling; coolant tubes run from its nostrils to a pump, later a radiator and reservoir |
| **Dillodisk → Armadrive** | Hardware | armadillo + hard drive; aluminum shell bands, platter window, rolls up and spins when scared |
| **Pasteslug** | Hardware | slug made of thermal paste with a paste syringe in its back; always uses too much |
| **Pixelsier** | Hardware | tarsier + graphics card; enormous pixel-grid eyes, two-fan GPU backpack |
| **Tieweaver** | Hardware/Network | weaver bird that ties cables into neat zip-tied bundles |

CMDB numbers come from the master roster (179 Daemons, Nos. 000–178; `number` in species.json). Ramster (021) and Servurtle (022) stay **Hardware** (decided 2026-11-13; the roster had proposed Data and Security). Built so far: 000–022 and 028–040; 023–027 (Captchat, Phishgill, Cumulonimbyte, Hallucinaut, Uptimus) keep their slots until they are made.

Target roster: **40–60 Daemons** for v1 (about 18 evolution lines + singles + 2–3 legendaries). Design rule: every Daemon is a real animal/creature fused with a real piece of tech, and its name is a pun. No silhouettes, names or palettes borrowed from any existing monster franchise.

### Region: Root Valley (one compact region, 8–15 hours of play)
1. **Onboarding Town**: home + Help Desk HQ (start)
2. **Route 1: Cable Run**
3. **Patch Town**: Department 1, *Desktop Support* (Hardware cert)
4. **Wi-Fi Dead Zone** (dark woods; Network Daemons)
5. **Port City**: Department 2, *Networking* (Network cert)
6. **The Basement**: Legacy dungeon full of old servers
7. **DevOps Heights**: Department 3, *Software* cert
8. **Abandoned Data Center**: Ransom hideout (mid-game story)
9. **Power Plant**: *Facilities* cert (Power)
10. **Cloud Summit** (mountain)
11. **SecOps Fortress**: Security cert
12. Further Departments: Data/Analytics, Mobile, AI Lab
13. **HQ Tower**: the C-Suite + The Board

### Story beats (light, funny, IT-culture humor)
- Day 1 on the help desk; your manager gives you a starter "from the e-waste bin".
- Ransom is encrypting towns one by one; each Department boss helps you after you earn their cert.
- Twist: Ransom's leader is the valley's old sysadmin, who was laid off when everything "moved to the cloud".
- Ending: restore from backups (the backups were tested, a miracle).

### Legal guardrails (from the research; not legal advice)
- 100% original names, creature designs, UI, text, formulas and music. Never use another franchise's assets, names, fonts, sounds or code.
- Keep capture **menu-based inside turn-based battles**. No real-time throwing of a capture device in the overworld, no capture-odds reticle, no summon-then-auto-battle. That steers clear of existing capture/summon patents.
- Keep a dated design log (sketches + dates) for every Daemon.
- Trademark-search the final title. Get an IP lawyer review before a paid release. Consider an LLC.

---

## 2. CLAUDE.md

Lives at the repo root as `CLAUDE.md`.

---

## 3. Build phases (one chunk at a time)

Each phase: **Goal → Prompt → Done when.** Big phases are split into sub-steps (a/b/c) so each one fits in a single sitting. `docs/phase-log.md` records what's finished and what's next.

> **Session starter:**
> "Read CLAUDE.md, docs/design.md, and docs/phase-log.md. We're on Phase __ step __. Summarize where we are, then do only this step. Run the tests when done and update docs/phase-log.md."

### Phase 0 — Project setup (1 session)
**Goal:** Empty project that runs on Mac with the right pixel settings, test framework and folders.

**Prompt:**
> Create a new Godot 4.7 project called "Daemons" in this repo using GDScript. Set base resolution 320x180, stretch mode canvas_items, scale mode integer, default texture filter Nearest. Create the folder layout from CLAUDE.md. Add autoload stubs: DataRegistry, GameState, SaveManager, AudioManager, SceneRouter. Install GUT into addons/ and add one passing sample test. Define input actions: move_up/down/left/right, ui_accept, ui_cancel, menu, run, mapped to arrows/WASD, Z/Enter, X/Esc, and gamepad equivalents. Add a title scene with "DAEMONS — press Start" in a pixel font (use a free OFL-licensed pixel font and note its license in assets/fonts/LICENSE.txt). Add .gitignore for Godot. Copy the design doc I give you into docs/design.md. Create docs/phase-log.md.

**Done when:** project opens, title screen shows crisp pixels at any window size, `gut` test passes, and the first commit is made.

### Phase 1 — Data layer (1–2 sessions)
**Goal:** All game data in JSON, loaded and validated at startup.

**1a prompt:**
> Build the data layer. Create data/types.json (12 types + effectiveness chart from docs/design.md), data/moves.json (start with 30 moves: id, name, type, category physical/special/status, power, accuracy, max_pp, priority, effect id + params, description), data/species.json (the 3 starter lines + Wormby, Spamlet, Dustbunny, Fanbat, Cablesnake, Floppit — base stats for uptime/throughput/hardening/compute/encryption/bandwidth, types, growth_rate, catch_rate, base_exp, learnset by level, evolutions with trigger type level/item/sync, CMDB entry text), data/items.json (Coffee, Energy Drink, Pizza Friday, Hard Reboot, Firewall Rule, Ctrl+Z, Thumb Drive, Encrypted Key, Hardware Token, Root Key, Overclock Chip). DataRegistry loads all of them at startup, validates required fields and cross-references (every learnset move exists, every evolution target exists) and prints clear errors. Write GUT tests for loading and validation.

**1b prompt:**
> Create the DaemonInstance class (a caught Daemon): species id, nickname, level, exp, current uptime, status, 4 move slots with Cycles, build_quality (6 values 0–15), experience_logs (6 values, max 64 each, 192 total), config_profile (21 profiles: Balanced, or +10%/−5% to two stats), original trainer id. Implement our stat formulas (see Stats above), the growth-rate EXP curves, level up, learning moves on level up, and evolution checks. Add to_dict()/from_dict() for saving. Full GUT tests for the formulas.

**Done when:** game boots with no data errors, and tests prove stats and EXP math.

### Phase 2 — Battle simulation, no graphics (2–3 sessions)
**Goal:** A complete battle engine you can run from tests or a debug console.

**2a prompt:**
> Build the headless battle sim in scripts/battle/sim/. BattleState holds two sides (each an active Daemon + the rest of the stack), field effects, turn counter, and a seeded RNG. Each turn takes one action per side: fight(move_slot), switch(index), item(item_id, target), run. Turn order: switches first, then items, then moves by priority, then bandwidth (with throttled modifier), with random speed ties. Output a list of BattleEvent dictionaries. No nodes, no UI.

**2b prompt:**
> Add damage and effects. Damage: our formula from the Stats section above (crit 1.5 at 1 in 20, random 0.88–1.00, native-type bonus 1.35, type effectiveness). Physical uses throughput/hardening, special uses compute/encryption. Accuracy checks with accuracy/evasion stages. Stat stages −6..+6 with the standard multipliers. Status effects from docs/design.md (Throttled, Corrupted, Overheated, Standby, Hung, Looping). Move effects as a registry of small handler functions keyed by effect id (e.g. "status_chance", "stat_change", "drain", "multi_hit", "recoil"). Fainting, forced switch, battle end, EXP + experience-log gain, level ups during battle, evolution flagged for after battle.

**2c prompt:**
> Add wild battles and capture. Run chance based on bandwidth. Quarantine: our formula from the Stats section above, run as three stages (scan, isolate, encrypt). Emit capture_shake events. Add simple trainer AI tiers: "random" (picks any move), "basic" (prefers super-effective, avoids immune), "smart" (also uses status moves early and switches out of bad matchups). Write a debug scene that runs a text-only battle in the console, and GUT tests for turn order, damage range, type immunities, capture math with a fixed seed.

**Done when:** you can run a full text battle in the console, and the same seed always gives the same result.

### Phase 3 — Battle UI (2 sessions)
**Goal:** It looks and feels like an early-2000s handheld battle, in our own style.

**Prompt:**
> Build the battle scene on top of the sim. Layout at 320x180: enemy Daemon top-right on a platform with name/level/uptime bar top-left; player Daemon bottom-left (back sprite) with name/level/uptime bar + EXP bar bottom-right; text box along the bottom; command menu Fight / Stack / Bag / Run; move menu showing PP and type. A BattlePlayer reads the sim's BattleEvent list and animates each in order: typewriter text, uptime bars draining smoothly, flash/shake on hit, faint drop, capture Quarantine Key shake animation, level-up stat popup, then "upgrading" evolution scene after battle. Use placeholder colored-shape sprites generated in code if no art exists yet (64x64 front/back). Every menu works with keyboard, gamepad, and touch/mouse taps.

**Done when:** you can fight and catch a wild Dustbunny from a debug button, start to finish, with no console needed.

### Phase 4 — Overworld (2–3 sessions)
**Goal:** Walk around a grid-based top-down map.

**4a prompt:**
> Build the overworld. A TileSet with 16x16 tiles and custom data layers: collision (bool), behavior (none / hot_zone / ledge_down / water / door / counter). Player moves one tile per step with a tween (walk 4 tiles/sec, run 8 with the run button), 4-direction facing, walk animation frames, bump sound on collision, ledges you can hop down but not up. Camera follows the player and clamps to map bounds. Make a placeholder tileset in code or a simple PNG and build Onboarding Town (about 30x25 tiles) with your house, the Help Desk, and an exit to Route 1.

**4b prompt:**
> Add map events: Warp (target map + spawn point + facing, with fade transition), Sign (shows text), NPC (sprite, facing, optional wander, dialogue id, optional trainer data), Trigger zone (runs a script once, gated by a story flag), Hidden item. Build a dialogue system: data/dialogue/*.json with lines, speaker name, choices (yes/no), and commands (set_flag, give_item, give_daemon, heal_party, start_battle, move_npc). Text box with typewriter effect and advance on ui_accept. Pressing ui_accept facing an NPC/sign interacts.

**Done when:** you can walk out of your house, talk to people, read signs, and go through doors between maps.

### Phase 5 — Collecting systems (2 sessions)
**Goal:** The actual monster-collector loop.

**Prompt:**
> Add: (1) Wild encounters: data/encounters/<map>.json lists slots (species, level range, weight) per zone type (cable_tangle, server_rack, water). Each step on a hot_zone tile rolls an encounter rate; Firewall Rule item blocks encounters below your lead's level for N steps. Screen-flash transition into battle. (2) Active Stack menu: view summary (stats, moves, CMDB text, build quality hidden), reorder, use items on a Daemon. (3) Server Rack storage at Help Desks: 12 racks × 30 slots, deposit/withdraw/move. (4) Bag with pockets: Items, Keys (capture), Scripts (TMs), Key Items. (5) CMDB: seen/caught tracking with entries, sprite, type, area found. (6) Help Desk nurse NPC heals the stack. (7) Supply Closet shop with buy/sell.

**Done when:** you can walk into a cable tangle, catch something, put it in the Server Rack, heal at the Help Desk, and see it in the CMDB.

### Phase 6 — Trainers, progression, saving (2 sessions)
**Goal:** It's a real game with goals and saves.

**Prompt:**
> Add: (1) Trainer NPCs with a line-of-sight range. When the player enters it, show "!" bubble, trainer walks up, intro dialogue, battle, defeat dialogue, prize credits, then flag as beaten. (2) Department boss battles that award a Certification (stored in GameState, shown on a trainer card screen). Certifications gate progress (e.g. a "Network+" cert lets you pass the Port City firewall gate). (3) Black-out handling: lose half credits, warp to the last Help Desk. (4) SaveManager: save from the pause menu; JSON with version, checksum, play time, map + position, stack, rack, bag, flags, CMDB, credits, certs; two alternating slots; load the newest valid one; a migration hook for older versions. (5) Pause menu: CMDB, Stack, Bag, Trainer Card, Save, Options. (6) Options: text speed, music/SFX volume, battle animations on/off.

**Done when:** you can beat a trainer, save, quit, relaunch and continue exactly where you were.

### Phase 7 — Vertical slice (3–5 sessions, the big milestone)
**Goal:** 30–45 minutes of real, polished gameplay. This becomes your Steam demo later.

Scope: Onboarding Town → Route 1: Cable Run → Wi-Fi Dead Zone (short) → Patch Town → Department 1 (Desktop Support, Hardware cert). About 10 Daemons, 3 starters, 8 trainers, Kevin rival fight #1.

**Prompt:**
> Build the vertical slice described in docs/design.md Phase 7. Write the intro cutscene (first day at the help desk, manager gives you the choice of 3 starters from the e-waste bin), Kevin's first rival battle, Route 1 with trainers, the Wi-Fi Dead Zone, Patch Town, and the Department 1 building (a small puzzle: route cables to unlock doors, then the boss). Swap in real art from assets/ wherever it exists; keep placeholders elsewhere. Add music hooks: town, route, battle, trainer battle, boss, victory, Help Desk jingle. Balance levels so the cert boss is beatable at around level 12–14 without grinding. Then playtest the whole slice by reading through the scripts and listing any broken flags, dead ends or softlocks.

**Art/audio track during Phase 7 (outside Claude Code):**
- Aseprite ($19.99): draw the 10 slice Daemons (64x64 front + back, 2-frame idle), player + Kevin + NPC overworld sprites, one town tileset, one route tileset.
- Music: Furnace (chiptune tracker) or Bosca Ceoil Blue (free, easy). Or commission (about $50–150/min entry level, work-for-hire contract).
- SFX: jsfxr/ChipTone for blips, hits, menu sounds.

**Done when:** someone who's never seen it plays from title to the first cert without help or bugs.

### Phase 8 — Platform builds early (1–2 sessions)
**Goal:** Prove it runs everywhere before you make lots of content.

**Prompt:**
> Set up export presets for macOS (universal, signed and notarized with my Developer ID), Windows, iOS, and Android. Add on-screen touch controls that only show on touchscreens: floating d-pad that appears where the left thumb touches, A/B buttons on the right with icons (not letters), at least 44pt touch targets (draw the touch layer at higher resolution than the 320x180 game layer if needed), respecting safe areas/notches. Auto-hide touch controls when a gamepad connects and show matching button prompts (Xbox/PlayStation/Nintendo/keyboard). Add a pause-on-background handler for mobile and an autosave on app suspend. Document every export step in docs/build.md.

**Done when:** the vertical slice runs on your Mac, a Windows PC, your iPhone (via Xcode) and an Android phone.

Accounts needed around here: Apple Developer ($99/yr, needed even for a notarized Mac build on Steam), Steam Direct ($100 per game, recouped after $1K), Google Play (new personal accounts need 12 testers opted in for 14 straight days before going live, so start that early).

### Phase 9 — Steam page + demo (parallel with Phase 10)
**Goal:** Start collecting wishlists early.
- Steam page with 5+ screenshots, a short trailer, and the "IT humor meets monster collecting" hook.
- Release the vertical slice as a free demo months before Steam Next Fest. Aim for 2K+ wishlists before Next Fest and 7K+ before launch.
- Post devlogs/GIFs (r/gamedev, r/IndieDev, r/sysadmin, Bluesky/X, TikTok).
- Optional: itch.io build for early feedback.

### Phase 10 — Content production (the long haul; many short sessions)
**Goal:** The full game. Each session = one content chunk.

Repeatable prompt template:
> Add the next content chunk: [area name]. Build the map(s), encounter table, trainers, NPC dialogue, items, and story beats described in docs/design.md under [area]. Add these Daemons to data/species.json: [list with types and evolution notes]. Keep difficulty curve: wild levels [x–y], trainers [x–y], boss ace level [z]. Validate data, run tests, and list anything that needs art.

Suggested chunk order: Port City + Networking cert → The Basement → DevOps Heights + Software cert → Abandoned Data Center (Ransom mid-boss) → Power Plant + Facilities cert → Cloud Summit → SecOps Fortress → remaining Departments → HQ Tower (C-Suite + The Board) → post-game legendaries (Uptimus, Hallucinaut, Pyrewall — exact spot decided later).

Also in this phase: Scripts (TMs) placed around the world, move tutors, item-based upgrades (e.g. Floppit needs a "Legacy Driver"), a Sync feature (local trade between save files) if you want trade evolutions.

**Done when:** 40–60 Daemons, 8 certs, the C-Suite, credits roll. Roughly 8–15 hours.

### Phase 11 — Polish + balance (2–4 weeks of sessions)
**Prompt ideas:**
> Write a balance report: for every Daemon, list base stat total, type, available moves by level, and flag outliers. Simulate 1,000 battles between each starter's final form at level 50 with the smart AI using the headless sim and report win rates.

> Accessibility pass: text speed options, colorblind-safe type colors, remappable controls, larger text option, screen-shake toggle.

> Bug sweep: scan every dialogue file for missing flags, unreachable maps, items that can't be obtained, and trainers that can't be reached.

Plus: juice (screen transitions, particles, Daemon cries made in jsfxr), Steam Deck check (1280x800, controller only, text ≥ 9px).

### Phase 12 — Launch (PC first, then mobile)
1. **Steam (Windows + Mac)**: about $15–20. Mac build notarized, no Apple sandbox.
2. **itch.io**: same build, you pick the rev share.
3. **Mobile, a few months later**: free to try (through the first cert) + one-time $5–7 unlock. Enroll in Apple's Small Business Program and Google's 15% tier.
4. Post-launch: patches, then maybe a Sync/trade feature or a post-game expansion.

---

## 4. Rough timeline (solo, part-time)
| Phases | Rough length |
|---|---|
| 0–2 (setup, data, battle sim) | 2–4 weeks |
| 3–6 (battle UI, overworld, collecting, saves) | 1–2 months |
| 7 (vertical slice incl. art) | 1–2 months |
| 8–9 (platform builds, Steam page, demo) | 2–4 weeks |
| 10 (full content) | 6–12+ months (art is the bottleneck) |
| 11–12 (polish, launch) | 1–3 months |

Estimates, not sourced benchmarks. Keep scope tight: 40–60 Daemons, one region, one hook (the IT theme).

## 5. Daemon design sheet (copy per creature, for the design log)
```
Name:            (pun: animal + tech)
Date designed:
Type(s):
Animal + tech it's based on:
Evolution line / trigger:
Base stats (Up/Thr/Hard/Comp/Enc/Band):
Signature move:
Where found:
CMDB entry (asset-record style, 1–2 lines):
Palette (max 15 colors + transparent):
Sketch / sprite file:
```
