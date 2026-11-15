# HEXFORGED — Game Design Document

Nov 15, 2026 · @Brandon Torres

## 1. Game Overview

HEXFORGED is a GBA-era, top-down, turn-based monster collector where you start as an entry-level help desk tech and end up saving Root Valley from the Ransom crew's corruption.

**Pitch:** You're the new help desk hire in Root Valley, where every piece of tech is run by a creature built by code. Someone has hijacked the machine that made them and is turning the valley's own creatures against it. Catch them, clean them, train them, and restore the network before everything gets encrypted.

| Item | Decision |
| --- | --- |
| Title | HEXFORGED (creatures built by code). Renamed from DAEMONS because players read it as "demons." |
| Creatures | Hexforged (same word for one or many) |
| Genre | Turn-based monster-collecting RPG, top-down, GBA-era pixel art |
| Core fantasy | Zero-to-hero: the lowest person on the org chart saves the whole valley |
| Story goal | Fun, mysterious and challenging; the story is a reason to keep playing, not a wrapper |
| Tone | The Office (quick one-liners, awkward workplace humor) + The IT Crowd (tech absurdity) on top of Pokémon-style gameplay |
| Tagline | FUSE is cut (no fusing mechanic). Suggested: **CATCH · CLEAN · RESTORE**. Alternatives: CATCH · PATCH · RESTORE, CATCH · TRAIN · REBOOT, "Have you tried turning it off and on again?" |

**Hook that sets it apart:** the creatures aren't wild animals. Every Hexforged was compiled for a job and lives inside the system it runs. Corruption is a broken computer, and cleaning corrupted creatures is how you heal the valley.

## 2. Audience & Player Experience

HEXFORGED is an all-ages, single-player, sit-down-and-play game for IT people and monster-collector fans equally.

| Item | Decision |
| --- | --- |
| Audience | IT folks and monster-collector fans, equally |
| Age | All ages. Ransom's menace stays cartoony, no dark content |
| Humor rule | Every joke works on two layers: funny to anyone on the surface, funnier if you've worked a help desk. Deep jargon is seasoning, not the main course |
| Players | Single-player for v1. Trading/Sync is parked for "way later, maybe" |
| Sessions | Built for sit-down sessions, but save-anywhere plus autosave on mobile so short bursts aren't punished |
| Target length | 100+ hours for completionists over time, through story + side content + collection + post-game + expansions (see Scope) |

## 3. Core Mechanics & Gameplay Loop

The core loop is classic monster-collector: explore, battle, catch, build a stack of 6, beat Department bosses for Certifications, unlock new areas. HEXFORGED adds a corruption-and-cleaning layer that only shows up once the story reveals it.

### Core loop

1. Explore an area; step into hot zones (cable tangles, server racks, Wi-Fi dead zones) for wild encounters.
2. Battle turn-based; weaken and catch with a Quarantine Key (menu-based, inside battle only).
3. Build and train your Active Stack (6); store the rest in the Server Rack.
4. Clear trainers, side tickets and quest chains for credits and items.
5. Beat the Department boss → earn a Certification → raise the level cap and unlock the next area.
6. Fill the CMDB.

### Vocabulary (locked)

| Classic idea | HEXFORGED |
| --- | --- |
| Monsters | Hexforged |
| Capture device | Quarantine Key: Thumb Drive → Encrypted Key → Hardware Token → Root Key |
| Dex | CMDB (entries written like asset records) |
| Heal center | Help Desk ("Have you tried turning it off and on again?") |
| Shop | Supply Closet |
| PC storage | Server Rack |
| Party | Active Stack |
| Gyms / badges | Departments / Certifications (8) |
| Elite Four / Champion | The C-Suite / The Board |
| Evil team | Ransom (grunts: Phishers, admins: Exploit Kits) |
| Evolution | Upgrading |
| Potions / Revive / Repel / Escape Rope | Coffee, Energy Drink, Pizza Friday / Hard Reboot / Firewall Rule / Ctrl+Z |
| TMs / Rare Candy / Money | Scripts / Overclock Chip / Credits |
| Rival | Kevin, who replies-all to everything |

### Stats, types, statuses

- **6 stats:** Uptime (HP), Throughput (Atk), Hardening (Def), Compute (Sp. Atk), Encryption (Sp. Def), Bandwidth (Speed). IVs = Build Quality, EVs = Experience Logs, Natures = Config Profiles.
- **12 types:** Hardware, Network, Software, Power, Cloud, Data, Security, Malware, Legacy, Mobile, AI, Peripheral. Starter triangle: Hardware > Software > Network > Hardware. Security is immune to Malware. Full draft chart lives in the build plan; tune in playtesting.
- **Statuses:** Throttled, Infected (renamed from Corrupted to avoid clashing with corrupted creatures), Overheated, Standby, Hung, Looping.

### Corruption & cleaning (revealed mid-game)

- Corruption is **not** a day-one mechanic. Players discover it slowly; the first real corrupted (ERR::) Hexforged appears at the halfway point (Act 4).
- A corrupted Hexforged is the same species in a glitched, hostile state: gains Malware as a second type, Throughput ×1.10, Encryption ×0.90 (tune later). Battle text: "A wild ERR::CABLESNAKE spawned!"
- Catch it → it goes to a Quarantined bag pocket (can't battle) → clean it at any Help Desk → it joins your stack as the normal version.
- Malware lines Ransom built from scratch (Hashling, Wormby, Spigeon, Phishgill, etc.) can't be corrupted or cleaned; they're normal catchable species.
- As areas are cleaned up after the restore, they visibly heal (see Art).

### Upgrades

Upgrades are triggered by **items and events, not just levels**: firmware, patches and Cert unlocks. This fits the lore (they're new versions, not growing up). Overclock Chips and upgrade items can speed certain lines up.

### Level cap

Each Certification sets a level cap. **EXP stops at the cap until you earn the next Cert.** Exact cap per Cert is set during balancing.

### Difficulty

- Boss fights and puzzle gyms ramp up gradually as the game goes on (smarter AI, switching, status moves; harder puzzles like the Dept 1 cable-routing gym).
- **Hard mode** unlocks after beating the game: higher-level Hexforged and **secret upgrades**. Planned for a later release, not v1.

### Legal guardrails

Capture stays menu-based inside turn-based battles: no real-time throwing in the overworld, no capture reticle, no summon-then-auto-battle. All names, designs, UI, music and code are original.

## 4. Story, Lore & Characters

The story is a slow-burn mystery: a cloud vendor secretly running Ransom has hijacked the Hexforge to corrupt the valley's creatures, and the laid-off sysadmin who built everything is helping you from the shadows.

### Lore rules

1. **Hexforged are built, never born.** No breeding, eggs, nests, parents or babies. Stages are upgrades (new versions).
2. Every Hexforged was compiled by the **Hexforge** for a job and lives inside the system it runs (Cablesnakes in cable runs, Fanbats in server rooms, Pingos in routers). A "wild" one is running loose with no handler; catching it assigns it to you.
3. **Corruption is a broken computer, not a demon.** Glitched and damaged, never hellish. No horns, devil wings, skulls, flames or occult imagery anywhere.

### Backstory

Years ago Root Valley had one sysadmin, `[SYSADMIN_NAME]`, who held everything together. He wrote the Hexforge, a compiler that turns code into living creatures. Its first and finest build was **Pyrewall (No. 000)**, set to guard **Port 443**, the gate the forge talks through. He also quietly set up the valley's backups by the 3-2-1 rule.

Then the valley "moved to the cloud" with `[VENDOR_NAME]`, and the sysadmin got laid off. On his last night he pushed an untested protection build, `encrypt_for_safekeeping()`. His access was cut mid-compile, leaving the Hexforge glitched with an open backdoor through Port 443.

### The villain (locked: Option B combo)

- **`[RANSOM_LEADER]`** runs `[VENDOR_NAME]`, the cloud vendor that sold the migration. They found the backdoor and use it to corrupt good Hexforged and compile new malware ones, then sell towns a fake "recovery service." Break it, sell the fix.
- **`[INSIDER]`**, a C-Suite member, signed the vendor contract and laid off the sysadmin on purpose. Unmasked during the HQ Tower climb.
- **Kevin is the red herring.** He keeps turning up where things go wrong. Cleared in Act 4; he was just very annoying.

### The sysadmin

Never seen on screen. Known only through **notes, commits and tape labels**. Some notes are old (left from when he worked there); some are **fresh**, because he's helping discreetly from the shadows. The player assumes they're all old until one is dated this week. Epilogue gag: rehired as a contractor at three times his old salary; Kevin replies-all to the announcement.

### The backup trio (kept, built in deliberately)

Based on the real 3-2-1 backup rule (3 copies, 2 kinds of media, 1 off-site). The sysadmin's notes form a breadcrumb trail to the safety net he built.

| Legendary | Role | Where | Story beat |
| --- | --- | --- | --- |
| Restorephant (No. 176, elephant, Data/Legacy) | On-site backup (tape vault) | The Basement, deepest level | Act 3: recognizes the sysadmin's handwriting; he set it up |
| Clondor (No. 177, condor, Cloud/Network) | Off-site cloud copy | Cloud Summit | Act 5: tests you, then hands over the off-site copy |
| Sudofox (No. 178, red fox, Security) | Root key needed for any restore | Stolen by Ransom → freed at HQ Tower | Act 5: you learn it was stolen; Act 7: you free it |

Early hook: a Help Desk ticket mentions "the 3-2-1 rule" as an office in-joke nobody remembers. All three are catchable post-game.

### Pacing (7 acts)

| Act | Areas | What the player learns |
| --- | --- | --- |
| 1. Onboarding | Onboarding Town → Route 1 → Patch Town **(Cert 1, Hardware)** | Plain IT problems and humor. Starter from the e-waste bin (Chipmunk, Pingo or Glowbit). First old tape label. The 3-2-1 in-joke. Phishers are petty scammers |
| 2. Bad Signal | Route 2 → Wi-Fi Dead Zone → Port City **(Cert 2, Network)** | Creatures oddly aggressive ("it's just bad signal"). Weird Port 443 traffic. Kevin keeps showing up. **Demo ends here** with a glitched creature that flees |
| 3. Legacy | Route 3 → The Basement → DevOps Heights **(Cert 3, Software)** | Hexforge manual: creatures were built. Meet Restorephant. First fresh note. Commit history: `temp fix, will clean up later`, then an unknown account. A creature glitches mid-battle and flees |
| 4. Outage | Route 4 → Power Plant **(Cert 4, Power)** | Rolling blackouts. **First real ERR:: Hexforged (halfway point).** Corruption gets a name. Kevin cleared |
| 5. Breach | Abandoned Data Center → Cloud Summit → Data Dept **(Cert 5)** | The forge and corrupted ERR::PYREWALL. Sudofox's root key stolen. The vendor revealed as Ransom. Clondor's off-site copy |
| 6. Incident Response | SecOps Fortress **(Cert 6)** → Mobile Dept **(Cert 7)** → AI Lab **(Cert 8)** | Corruption everywhere, towns encrypted. Fight back town by town; recovery-service quest chains open. SecOps gives the patch, but you need root |
| 7. Restore | Final route → HQ Tower | C-Suite, insider unmasked, The Board, `[RANSOM_LEADER]`. Free Sudofox; the trio runs the restore ("The backups were tested. A miracle."); patch the forge; Pyrewall cleaned first; the valley returns to normal |

Ransom's malware lines stay in the world as normal species after the ending; they just can't corrupt anything anymore.

### Post-game hook

Someone is still sending code to the forge from outside the valley. Hallucinaut and Uptimus are the post-game legendaries; clean Pyrewall becomes catchable (timing TBD). This hook also leads into future regions.

## 5. World: Root Valley

Root Valley is the only region at launch; it's longer than the original 13-area plan because routes now sit between every town, and optional side areas are scattered across every act. New regions come later as expansions.

- **Main path (in order):** Onboarding Town, Route 1: Cable Run, Patch Town, Route 2, Wi-Fi Dead Zone, Port City, Route 3, The Basement, DevOps Heights, Route 4, Power Plant, Abandoned Data Center, Cloud Summit, Data/Analytics Dept, SecOps Fortress, Mobile Dept, AI Lab, final route, HQ Tower.
- **Change from the old plan:** the Power Plant now comes before the Abandoned Data Center, so the blackouts set up the forge reveal.
- **Optional side areas:** at least one per act, for extra creatures, items, sysadmin notes and quest chains. Names and contents `[TBD]`.
- **Hot zones:** cable tangles (tall grass), server racks, Wi-Fi dead zones, water.
- **Corruption on the map:** as the story goes on, later areas look more corrupted (flickering lights, glitched tiles); they heal after the restore.

## 6. Side Content & Long-Term Play

Side content is where most of the 100+ hours come from, and it can keep growing after launch.

### Help desk tickets

Optional side quests written as tickets ("Ticket #4471: Karen's Wi-Fi is 'broken'"), tracked in a ticket queue in the pause menu with priority levels. Rewards: credits and items that help in encounters and battles.

### Quest chains

Longer multi-part, story-ish quests. Examples:

- Helping a town that paid Ransom's "recovery service" get its systems back.
- Towns that paid vs. towns that refused, each with their own fallout.

### The sysadmin's notes hunt

A multi-part hunt for every note, commit and tape label the sysadmin left, old and fresh. Doubles as optional lore and a breadcrumb trail.

### Kudos (achievements)

In-game achievements called **Kudos**, e.g. "Kudos unlocked: Turned It Off and On Again (clean 10 corrupted Hexforged)." Mostly bragging rights plus small cosmetics (trainer card flair, Employee of the Month plaques on the Help Desk wall). Synced to Steam achievements later.

### Where the hours come from

| Layer | Rough hours (estimate, not a benchmark) | Ships |
| --- | --- | --- |
| Main story (7 acts + side areas) | 30–40 | Launch |
| Tickets + quest chains + notes hunt | 15–25 | Launch, grows after |
| Completing the CMDB (179 + corrupted variants) | 20–30 | Grows with content updates |
| Post-game (Hallucinaut, Uptimus, outside-the-valley hook) | 10–20 | Update after launch |
| Hard mode + secret upgrades | replay | Later release |
| New regions | — | Expansions |

## 7. Art & Visual Direction

GBA-era pixel art with a terminal-style UI, a world that visibly corrupts as the story goes, and battle backgrounds that change by location.

- **Resolution:** 320x180 base, integer scaling, nearest filtering. 16x16 tiles and overworld characters; 64x64 battle sprites.
- **Sprite rules:** hard pixels only (no anti-aliasing, gradients or glow), tinted 1 px outline, light from top-left, max 15 colors. Same animal for a whole line; 3-stage lines at 55/70/85% height, 2-stage at 55/70%.
- **Pipeline:** sprite sheets generated with ChatGPT using the GPT Base Style prompt (one stage per image), then cleaned up. Full rules in the character bible docs.
- **Corrupted look:** ashy palette, error red `#D41E3C` accents, broken tech, glitch-shifted rows, void squares, red pupils; same silhouette. Never hellish.
- **World corruption:** Act 1 towns bright and saturated; later areas get flickering lights and glitched tiles; areas heal back after the restore. Affected areas need a second tile set.
- **Battle backgrounds:** different per location, habitat and Department (server room, cable tangle, Cloud Summit, inside each Department, etc.).
- **UI:** terminal style throughout: boot text (`mounting /dev/hexforge … OK`, `179 entities indexed`), `hexforge@field` console bar, `man` lines for menu help, battle menu FIGHT / STACK / BAG / RUN. Must stay readable for low-vision players (see Accessibility).

## 8. Audio Direction

Music and sound are made in-house by Brandon and his son, in a GBA-style chiptune sound.

- **Music hooks:** town, route, battle, trainer battle, boss, victory, Help Desk jingle, plus area themes as content grows.
- **Corrupted battles:** a glitched remix of the battle theme (default; their call).
- **SFX:** chiptune blips, hits and menu sounds; a short cry per Hexforged.
- **Tools:** their choice (the old plan suggested Furnace or Bosca Ceoil for music, jsfxr/ChipTone for SFX).
- **Voice acting:** none; all dialogue is text.

## 9. Platforms, Tech & Accessibility

Steam (Mac + Windows) first, Android soon after, iOS later, with keyboard, controller and touch all fully working from day one.

### Platforms & tech

| Item | Decision |
| --- | --- |
| Launch order | Steam (macOS + Windows) → Android soon after → iOS later. Demo on Steam + itch.io |
| Engine | Godot 4.7, GDScript only |
| Architecture | Data-driven JSON content, headless battle sim emitting events, seeded RNG, JSON saves with checksum and two alternating slots (see CLAUDE.md) |
| Input | Keyboard, controller and touch all first-class from day one; touch layer with floating d-pad and A/B, matching button prompts per device |
| Online | None for v1 |
| Android prep | New personal Google Play accounts need 12 testers opted in for 14 straight days before publishing; start early |

### Accessibility

Goal: fully playable for players with visual, hearing, motor and cognitive impairments.

- **Visual:** scalable text, high-contrast and colorblind-safe terminal themes (no relying on green-on-black alone), type shown as icon + text not just color, screen-shake and flash toggles.
- **Hearing:** every sound-only cue also has a visual cue; all dialogue is text already.
- **Motor:** full remapping, one-handed play, hold vs. toggle options, no timed inputs, adjustable text speed and auto-advance.
- **Cognitive:** ticket queue and objective reminder, a "where was I?" recap on load, clear menus, optional battle hints.

## 10. Business Model

Commercial premium game; pricing waits on player feedback and an IP check.

- **Model:** premium. Free demo first.
- **Price:** `[TBD]` after demo feedback. The old plan's reference point was $15–20 on Steam, with mobile free-to-try plus a one-time unlock.
- **Expansions:** a mix of free and paid (details later). New regions arrive as expansions.
- **Launch blockers:** trademark search on "Hexforged" and an IP lawyer review before any paid release (not legal advice).

## 11. UI/UX Flow & Onboarding

The player's first week on the job is the tutorial, wrapped in a terminal-style UI that works the same on keyboard, controller and touch.

- **New player flow:** title (boot text) → new game → Day 1 at the help desk → manager offers a starter from the e-waste bin → Kevin picks the counter and replies-all → onboarding tickets.
- **Tutorial:** HR-style onboarding training tickets teach catching, battling and items (cleaning gets its own tutorial when corruption is revealed in Act 4). A "Skip training — I've done this before" option for veterans.
- **Key screens:** title, battle (FIGHT / STACK / BAG / RUN), pause menu (CMDB, Stack, Bag, Tickets, Kudos, Trainer Card, Save, Options), Server Rack, Supply Closet, Help Desk, CMDB entry, trainer card with Certifications.
- **UX principles:** every menu works with keyboard, controller and touch; consistent `man`-line help text; save anywhere; autosave on mobile suspend.

## 12. Scope, Demo & Milestones

The next target is a demo covering Acts 1–2 with about 30–35 creatures; everything else waits until that ships. No target date yet.

### Team

- Brandon: design and code (with Claude Code)
- ChatGPT: sprite generation from prompts, cleaned up by Brandon
- Brandon's son: music and sound effects

### The demo

- **Covers:** Acts 1–2, through Port City and Cert 2.
- **Ends on a hook:** a scripted one-off encounter with a glitched creature; the CMDB shows `Status: UNKNOWN`; it flees before you can catch it. Then "Thanks for playing." The real corruption reveal stays saved for the Power Plant.
- **Creatures:** the 28 already-designed Hexforged (Nos. 000–027) plus a few expansion creatures that live in early areas. The other \~145 stay concepts until after the demo.
- **Not in the demo:** catchable corrupted creatures, cleaning, Hard mode, post-game, trading.

### Milestones

1. **Lock the design** — this GDD. Update the story agent prompt to match (see Open Decisions).
2. **Core systems** — build plan Phases 0–6: data layer, battle sim, battle UI, overworld, collecting, trainers and saves. Touch, controller and keyboard all working.
3. **Vertical slice (Act 1)** — Onboarding Town to Cert 1, polished, with real art and audio hooks.
4. **Demo (Acts 1–2)** — Route 2, Wi-Fi Dead Zone, Port City, Cert 2, ticket system v1, Kudos v1, the teaser ending.
5. **Platform builds** — Mac, Windows, Android. Steam page + itch.io; collect feedback and wishlists.
6. **Full game** — Acts 3–7, corruption and cleaning, quest chains, notes hunt, 8 Certs, the C-Suite and The Board.
7. **Launch, then post-launch** — post-game, Hard mode, more creatures, new regions as expansions.

### Nice to have (not v1)

Trading / Sync, online features, Hard mode, secret upgrades, new regions, Steam achievement sync.

## 13. Open Decisions

- [ ] Final tagline (suggested: CATCH · CLEAN · RESTORE)
- [ ] `[SYSADMIN_NAME]`
- [ ] `[RANSOM_LEADER]` and `[VENDOR_NAME]`
- [ ] Which C-Suite member is `[INSIDER]`
- [ ] When clean Pyrewall becomes catchable
- [ ] Whether Ransom trainers use corrupted starters
- [ ] Level cap number per Cert
- [ ] Optional side areas: names and contents per act
- [ ] Which expansion creatures join the demo roster
- [ ] Code/ID rename (`DMN-###` → `HXF-###`, class and file names)
- [ ] Balancing: corrupted stat mods, encounter `corrupted_chance` per area
- [ ] Price and free vs. paid expansion split
- [ ] Trademark check on "Hexforged" + IP review
- [ ] **Update the story agent prompt** (`hexforged-master-prompt.md`): its Act 1 still has corrupted creatures in your first tickets and the old sysadmin-villain framing. It needs the new 7-act pacing, Option B villain and halfway reveal before Claude Code builds story content.
