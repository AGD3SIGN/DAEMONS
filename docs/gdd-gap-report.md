# HEXFORGED — GDD gap report

Written 2026-11-15 (step 1 of Master Prompt v2). Compares what's built against docs/gdd.md, which wins wherever they
disagree. Sources: the repo, docs/phase-log.md, and the game data (species, encounters, trainers, certifications,
maps, dialogue). Nothing has been changed yet.

## 1. Matches the GDD (keep as is)

**Engine and architecture**
- Godot 4.7, GDScript; data-driven JSON with a validator; headless battle sim emitting events; seeded RNG; JSON saves
  with checksum and two alternating slots; save anywhere; autosave on mobile suspend (Options toggle).
- 320x180 base, integer scaling, nearest filter, 16x16 tiles, 64x64 battle sprites, 15-color sheets.

**Vocabulary and systems**
- Hexforged, Quarantine Keys (Thumb Drive → Encrypted Key → Hardware Token → Root Key), CMDB written as asset
  records, Help Desk ("Have you tried turning it off and on again?"), Supply Closet, Server Rack, Active Stack of 6,
  8 Departments / Certifications, Ransom (Phishers, Exploit Kits), Kevin replies-all.
- Items: Coffee, Energy Drink, Pizza Friday, Hard Reboot, Firewall Rule, Ctrl+Z, Scripts pocket, Overclock Chip,
  Credits.
- 6 stats (Build Quality, Experience Logs, Config Profiles), 12 types, starter triangle Hardware > Software > Network >
  Hardware, Security immune to Malware.
- Statuses including **Infected** (the Corrupted → Infected rename is already done; save v4 migrates).
- Capture is menu-based inside battle only.

**Corruption and lore**
- The corrupted-creature rules: same species, Malware as second type, Throughput ×1.10 / Encryption ×0.90, "A wild
  ERR::CABLESNAKE spawned!", Quarantined pocket, clean at any Help Desk, Malware lines can't be corrupted, CMDB
  COMPROMISED / Recovered, corrupted look (ashy palette, #D41E3C, shifted rows, void squares, red pupils). The code
  stays; it only needs gating (conflicts below).
- Lore: built, never born. Breeding wording was removed from CMDB entries, the design doc and art prompts. "Upgrading"
  is the word in UI text.

**UI and presentation**
- Title boot text (`mounting /dev/hexforge … OK`, `179 entities indexed`), `hexforge@field` console bar, `man`-line
  help text.
- Department puzzles that ramp up (ticket triage → packet lanes → pipeline → power budget → stealth + forensics).
- Keyboard, controller and touch: Godot touch overlay (landscape), web phone deck (portrait), per-device button
  prompts, CONTROLS screen, control hints.
- Options already present: text speed, music and SFX volume, battle animations, reduced motion, CRT effects, control
  hints, autosave on suspend.

**Story locations that already fit**
- Restorephant shown in The Basement, Clondor at Cloud Summit, Sudofox taken at the Abandoned Data Center (as text
  beats; the people around them are the old cast).

**Extras not in the GDD (no conflict; keep unless you say otherwise)**
- The phone (pause menu as apps, with a Maps app).
- In-game Feedback form.
- End-of-demo credits screen.

## 2. Conflicts with the GDD (fix this session)

| # | Conflict | Where | Fix (step) |
|---|---|---|---|
| C1 | design.md "Story" is the previous prompt's version (5 acts, corruption in Act 1 tickets, sysadmin possibly the villain) | docs/design.md | Step 2: short summary pointing to gdd.md §4 |
| C2 | Region list and map order differ: the Wi-Fi Dead Zone sits between Route 1 and Patch Town; Routes 3 and 4 don't exist; DevOps Heights connects to both the Data Center and the Power Plant (the old story did the Data Center first); there's no Data/Analytics Dept | design.md, data/maps | Step 2 updates the doc. **The maps themselves are future work** (Routes 2–4 are listed as not this session). The Dead Zone move is a map change; see question Q1 |
| C3 | Tagline is CATCH · FUSE · COMPILE | data/title_screen.json, README, docs | Step 2: one constant, `CATCH · CLEAN · RESTORE` (PENDING_APPROVAL) |
| C4 | CLAUDE.md lacks gdd.md as required reading and the "works on every screen" input rule | CLAUDE.md | Step 2 |
| C5 | hx_ dialogue stubs follow the old 5-act prompt: corrupted creatures in Act 1 tickets, a building encrypted on screen in Act 1, a "who is the Ransom leader" reveal, PENDING_APPROVAL on trio beats | data/dialogue/hx_*.json | Step 3: rewrite to the 7 acts |
| C6 | **Built Acts 1–2 content shows things the GDD saves for later.** Patch Town ends Act 1 with Ransom's "YOUR FILES HAVE BEEN QUARANTINED. -R" email. Port City (Act 2) has Zed breaching Port 443, Pyrewall going dark, and the Port City Help Desk encrypted. Cron (old villain, the sysadmin) appears at the Data Center and Cloud Summit. Act 2 in the GDD is "creatures oddly aggressive, weird Port 443 traffic". | data/dialogue (patch_town, port_city, act2_part2, act3), maps | Step 3 covers the stubs only. **Rewriting the built beats is bigger than this session**; I'll list exact lines in the demo backlog (D1) unless you want them done now. See Q2 |
| C7 | Corruption isn't gated: corrupted_chance is non-zero before the Power Plant (Route 2 .25, Port City .35, The Basement .4), and the Quarantined pocket, Help Desk cleaning offer and CMDB status show from the start | data/encounters, field_menus, dialogue_runner, cmdb_panel | Step 4: `corruption_revealed` flag + validation; zero those three tables |
| C8 | Demo ends after Major Kalb (SecOps, old Act 3) | data/dialogue/act3.json (`end_demo`) | Step 5: teaser at Port City after Cert 2, `DEMO_BUILD` export flag. The end_demo screen is reused |
| C9 | No level cap; EXP never stops | battle_sim, item_use | Step 6 |
| C10 | Upgrade triggers are `level`, `item` and `sync`; there's no `flag` or `cert` | data_validator, daemon_instance | Step 7 (`sync` stays; it's one species, Discohare) |
| C11 | No `demo` field on species. **Acts 1–2 encounter tables and trainers lean on expansion creatures (Nos. 028+).** Route 1: Antsistor, Dillodisk, Pasteslug. Dead Zone: Clawptop, Coolippo, Tieweaver, Pixelsier, Spinode, Hummodem. Route 2: Spinode, Tieweaver, Dillodisk, Proxkit, Hummodem. Port City: Calfiber, Proxkit, Spinode, Tieweaver, Jellyband. Trainers: Ping Okoro (Spinode, Proxkit, Calfiber), Net Admin Nia, Packet Pat, Phisher Phil, Lineworker Lou, Gamer Gabe | data/species.json, encounters, trainers | Step 8. **The new rule fails on today's content.** See Q3 |
| C12 | Demo roster says Nos. 001–025, but 023 Captchat, 024 Phishgill and 025 Cumulonimbyte aren't built (no data or art); 026 Hallucinaut and 027 Uptimus aren't either | species.json | Step 8 marks what exists; the missing three are demo backlog (D3) |
| C13 | Certification order: built is Hardware, Network, Software, Facilities, **Security (5th), Data (6th)**, Mobile, AI. GDD: Cert 5 Data/Analytics, Cert 6 SecOps | data/certifications.json | Swap the order values in Step 6, since level caps key off cert count (no map changes) |
| C14 | Battle menu labels are EXECUTE / STACK / INVENTORY / DISCONNECT (from the Battle Scene Spec); the GDD says FIGHT / STACK / BAG / RUN | battle_menu.gd | Small rename. See Q4 (which doc wins for this one) |
| C15 | The GDD mentions "the Dept 1 cable-routing gym"; Dept 1 is now ticket triage, and the cable-like puzzle is Dept 2's packet lanes | department_1/2 | See Q5 |

## 3. Missing, needed for the demo (future sessions, priority order)

1. **D1 Rewrite the built Acts 1–2 beats to the GDD** (C6). Remove the -R email at Patch Town, the Port 443 breach and
   Pyrewall going dark, and the encrypted Port City Help Desk. Add "it's just bad signal" aggression, weird Port 443
   traffic, Kevin at trouble spots, the 3-2-1 in-joke ticket, and the first old tape label. Act 1 onboarding tickets
   should teach catching, battling and items.
2. **D2 Act 2 map order**: Route 2 → Wi-Fi Dead Zone → Port City (today the Dead Zone is reached before Patch Town).
   Needs a map rework of Route 1 / Dead Zone / Patch Town / Route 2 connections.
3. **D3 Demo roster gaps**: build Captchat (023), Phishgill (024) and Cumulonimbyte (025) (data + art), approve
   expansion candidates (Q3), then rebuild Acts 1–2 encounter tables and trainer teams from the approved roster (about
   30–35 creatures).
4. **D4 Help desk ticket system v1** (GDD milestone 4: ticket queue in the pause menu, priorities, rewards) and the
   HR-style onboarding tickets with "Skip training — I've done this before".
5. **D5 Kudos v1** (milestone 4).
6. **D6 Pause menu per the GDD**: Tickets and Kudos entries (the phone can host them as apps).
7. **D7 Real art** for the demo cast (Phishers, Port City / Patch Town NPCs, Ping Okoro, Act 1–2 trainers) and
   tiles; real audio from Brandon and his son (music hooks, Help Desk jingle, a cry per Hexforged).
8. **D8 Battle menu labels** per Q4.
9. **D9 Accessibility basics for the demo**: type shown as icon + text (not color only), screen-shake/flash toggle,
   hold vs. toggle for run. The full accessibility menu is post-demo (below).
10. **D10 Platform**: Steam page + itch.io upload, Android tester recruitment (12 testers × 14 days; start early).

## 4. Missing, not needed until after the demo

- Routes 2–4 as new maps (Route 2 exists; Routes 3 and 4 don't), the final route, Data/Analytics Dept, Mobile Dept,
  AI Lab, HQ Tower, optional side areas per act.
- Acts 3–7 story content, `[INSIDER]` unmasking, the C-Suite and The Board, the trio restore ending, Kevin cleared in
  Act 4, vendor reveal.
- The Power Plant corruption reveal event (only stubbed this session), the cleaning tutorial, catchable corrupted
  creatures for real.
- Quest chains (recovery-service towns), the sysadmin notes hunt.
- Accessibility options menu: high-contrast and colorblind terminal themes, text scaling, full remapping, one-handed
  mode, "where was I?" recap, objective reminder.
- World-corruption tile sets (second tile set per affected area) and healing after the restore.
- Per-location battle backgrounds (today: 3 palettes chosen per map).
- Corrupted-battle music remix, Hexforged cries.
- Hard mode and secret upgrades, post-game (Hallucinaut, Uptimus, clean Pyrewall, the trio catchable), trading.
- Steam achievement sync for Kudos.

## Questions before I go on

- **Q1 (C2)** Moving the Wi-Fi Dead Zone after Route 2 is a map rework. Do it in a later session (D2), keeping the
  current Dead Zone placement for now?
- **Q2 (C6)** The built Act 1–2 story beats (the -R email, Pyrewall going dark, the encrypted Help Desk, Cron) conflict
  with the GDD. Rewrite them this session, or leave them for D1 and only rewrite the stubs?
- **Q3 (C11)** The step 8 rule ("Acts 1–2 only use `demo: true`") fails today. Options:
  (a) mark the expansion creatures already in Acts 1–2 as candidates and pass the check only after you approve them;
  (b) approve them now as `demo: true` (about 13 species);
  (c) strip them from the tables and teams now, which leaves Ping's Networking team with only Cablesnake, Patchviper
  and the Pingo line.
- **Q4 (C14)** Battle menu: FIGHT / STACK / BAG / RUN (GDD) or keep EXECUTE / STACK / INVENTORY / DISCONNECT (your
  earlier Battle Scene Spec)?
- **Q5 (C15)** Is the GDD's "Dept 1 cable-routing gym" a request to change Dept 1's puzzle, or a loose reference to
  the existing puzzles?

---

## Session results (2026-11-15, steps 2–10)

Your answers: Q1 → follow the GDD (Acts 1–2 map order done now, later acts in the backlog); Q2 → rewrite the built
Act 1–2 beats this session; Q3 → list the expansion creatures as pending candidates; Q4 → keep EXECUTE / STACK /
INVENTORY / DISCONNECT (the GDD's FIGHT / STACK / BAG / RUN should be updated to match); Q5 → no answer yet, Dept 1
keeps ticket triage.

| Conflict | Status |
|---|---|
| C1 design.md story | Fixed: short summary pointing to gdd.md §4 |
| C2 region order | design.md fixed. Acts 1–2 maps rewired to the GDD order (Route 1 → Patch Town → Route 2 → Wi-Fi Dead Zone → Port City); the Dead Zone moved to Act 2 levels. Routes 3–4, the Power Plant before the Data Center, and the Data Dept remain backlog |
| C3 tagline | Fixed: CATCH · CLEAN · RESTORE (PENDING_APPROVAL), only in data/title_screen.json |
| C4 CLAUDE.md | Fixed |
| C5 stubs | Fixed: 19 area files for the 7 acts |
| C6 built Act 1–2 beats | Fixed: phishing email instead of -R, Port 443 only flickers ("bad signal"), Pyrewall stays up, Help Desk closed for rewiring, Zed removed from Port City, Kevin at trouble spots. Later-act content (Cron, Marge, Sudofox at the Data Center) is outside the demo and still old |
| C7 corruption gating | Fixed: corruption_revealed (Power Plant), zero chances before it, validator check, hidden UI |
| C8 demo ending | Fixed: Port City teaser after Cert 2; DEMO_BUILD ends there |
| C9 level cap | Fixed (placeholder caps, TBD) |
| C10 upgrade triggers | Fixed: flag and cert added |
| C11 demo roster | Field + check added; 12 pending candidates in data/demo_roster.json |
| C12 Nos. 023–025 | Still missing (demo backlog D3) |
| C13 cert order | Fixed: Data is Cert 5, Security Cert 6 |
| C14 battle menu | Kept by your choice; update the GDD |
| C15 Dept 1 puzzle | Waiting on Q5 |

### Input audit (step 9)
- Every screen works with keyboard and controller (all actions have pad bindings, checked by a test).
- Touch: every screen is reachable through the touch layer (web phone deck in portrait, the in-game overlay in
  landscape: d-pad, A, B, MENU, RUN), plus direct taps on menus, the phone, Maps, YES/NO, the battle menus, the
  CMDB/trainer card and the end card. Maps on touch is through the phone (no separate button).
- Fixed: the Summary screen only closed on a tap; tapping its left or right edge now flips pages.
- Gaps for the demo (D9): mouse-only desktop play can't walk the overworld, change Options values or use the
  quantity picker without a keyboard (touch and controller can); no remapping yet; no hold-vs-toggle for RUN.

### Demo candidates waiting for you (step 8)
From the Acts 1–2 encounter tables (the master roster isn't in the repo, so this uses where they live in the game):
Clawptop #028 (Dead Zone), Antsistor #031 (Route 1), Coolippo #034 (Dead Zone), Dillodisk #036 (Route 1, Route 2),
Pasteslug #038 (Route 1), Pixelsier #039 (Dead Zone; Gamer Gabe), Tieweaver #040 (Route 2, Dead Zone, Port City;
Lineworker Lou, Net Admin Nia), Spinode #041 (Route 2, Dead Zone, Port City; Ping, Nia, Phisher Phil), Calfiber #044
(Port City; Ping), Proxkit #046 (Route 2, Port City; Ping, Packet Pat), Hummodem #048 (Route 2, Dead Zone),
Jellyband #049 (Port City).
