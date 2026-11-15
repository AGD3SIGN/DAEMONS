# DAEMONS Demo (Acts 1–3): Story Draft

**Status:** DRAFT, written 2026-11-15 for Brandon's review. Nothing in this doc is built yet.

It builds on the approved outline in docs/story-outline.md and keeps everything already in the game:
- the cast
- Ransom and Cron
- Marge's Pizza Friday
- the 3-2-1 backup trio
- Pyrewall falling at Port 443
- Kevin's arc

What's new:
- a **countdown**
- an **insider mystery** you solve with evidence
- **choices that carry forward**
- hands-on **IT incident scenes**
- a demo that ends on a real **cliffhanger** instead of a sentry saying "that's the demo"

Acts 4–5 are the full release and only change where this draft says so (section 6).

---

## 1. What changes in one paragraph

Ransom isn't just encrypting towns at random. Cron has scheduled one job, `quarantine_valley`, for **Friday at
5:00 PM**: the moment the whole valley's backups get wiped and the key deleted. The demo runs Monday to
Thursday night, and every act ends with the clock closer to zero. Along the way you find evidence that someone
*inside* the Help Desk is helping Ransom. Act 3 ends with SecOps tracing the attack to the server closet behind
**Marge's office**. They take her in, your badge is revoked, every screen in the valley shows
`SEE YOU AT FIVE. -R`, and the demo cuts to black.

The full game later reveals the twist that pays off the ending already planned. Marge's closet held the only
machine that could reach every backup, because she was the only person testing them. Cron relayed his attack
through it on purpose. The habit that saves the valley is exactly what made her look guilty.

## 2. Tone: intense, still DAEMONS
- **Higher stakes:** a real deadline, someone you trust under arrest, your own home hit by Ransom.
- **The jokes stay:** they're IT jokes, and they get drier as things get worse ("Have you tried turning the
  valley off and on again?").
- **Nobody dies.** The danger is losing data, losing trust, and losing your job, which in IT is plenty.

## 2b. Kevin's voice (rewritten in game 2026-11-15)
An obnoxious know-it-all who clearly isn't IT savvy: confident, loud, wrong. Every choice and evidence beat
involving him should keep that voice. When he's caught out (phished in Act 2) he deflects first ("It had a LOGO"),
then quietly fixes it (MFA on everything, done badly: "Multi-Factor Awesomeness"). He never says sorry outright.

## 3. The four new threads

### 3a. The countdown (Friday 5:00 PM)
- The cold open shows a terminal at 2:13 AM: `cron: job quarantine_valley scheduled FRI 17:00`.
- Each act ends on a date card, like a security camera timestamp:
  `MON 08:00`, `TUE 23:40 — 65h left`, `THU 23:59 — 17h left`.
- It's story only, never a real-time timer, so nobody's play gets punished. The clock shows on the pause menu's CARD screen.

### 3b. The insider (evidence you collect)
Six pieces of evidence are spread through Acts 1–3. Most are optional and found by checking terminals, reading
logs and talking to NPCs. They're kept in a new **EVIDENCE** list (pause menu, next to CMDB).

| # | Evidence | Where | How you get it |
|---|---|---|---|
| 1 | A cloned Help Desk badge (serial HD-0001) | Dead Zone, Phisher Pete | After beating him (always) |
| 2 | Badge log: HD-0001 swiped into the Onboarding Help Desk at 2:13 AM | Onboarding Help Desk PC | Check it after Act 1 (optional) |
| 3 | Kevin's login from `r00tvalley.co` at 3 AM | DevOps Heights auth logs | The log puzzle (always) |
| 4 | A sticky note on Cron's laptop: "relay via the drill box. M has the keys." | Abandoned Data Center | After Cron leaves (always) |
| 5 | Brownout schedule matching the backup-drill times | Power Plant, breaker notes | Optional |
| 6 | A traceroute ending at 10.0.0.1, the Onboarding Town backup closet | SecOps Fortress analyst | Optional, before Kalb |

At the end of Act 3, Kalb asks you to **present evidence** (pick 3 from your list). Your picks don't change the
cliffhanger, which always happens. They change:
- how Kalb treats you
- whether she quietly hands you a **temporary badge**, which carries into Act 4 as an early key item
- one extra line from Marge

### 3c. Choices that carry forward (flags)
Small choices, remembered and paid off within the demo:

| Act | Choice | Pays off |
|---|---|---|
| 1 | Kevin replies-all to the ransom email. **Grab his phone / let it go** | Act 2: if you grabbed it, he admits you were right when he's phished. If you let it go, he blames himself. Sets how warm the Act 3 summit team-up is. |
| 1 | Mom's printer ticket: **fix it properly / tell her to restart it** | Act 1 ending: a properly fixed printer prints the ransom note (funny and creepy). Otherwise the restart reveals it on her PC. |
| 2 | Port 443 live incident (see 3d): **the order you respond in** | Whether the Port City Help Desk is fully locked or half-working, and which evidence you catch. |
| 2 | A stranger in DevOps Heights asks for your password "for the deploy" (Lyra in disguise). **Refuse / give it** | Refuse: you spot her tells and she flees. Give it: a hard ambush battle, and Kalb mentions it in Act 3. |
| 3 | Power Plant brownout: **save the hospital's power / the Help Desk's** | Hospital: the Power Plant Help Desk stays offline (heal at the pop-up), and townsfolk thank you. Help Desk: easier healing, and one guilty NPC line. |

### 3d. Incident scenes (hands-on IT)
Short sequences built from dialogue choices where you *do* the IT job:
- **Act 1, Mom's printer** (tutorial): pick the fix from three options.
- **Act 2, Port 443 breach** (live incident): Zed is inside. Pick 3 actions in order, from:
  - isolate the dock VLAN
  - pull the uplink cable
  - call SecOps
  - restart Pyrewall
  - reply-all to warn everyone

  A good order contains the damage. "Reply-all" makes it worse, and Kevin's already doing it. Pyrewall still
  falls; this is about how bad it gets.
- **Act 2, Kevin's login** (log puzzle): read four auth log lines and point at the bad one.
- **Act 3, phishing test** (already built): stays, and now opens the evidence scene.

## 4. The demo, act by act

### Act 1: Onboarding (MON)
1. **Cold open** (new): a dark terminal, Cron's job scheduled for Friday 17:00. Cut to your alarm.
2. Starter from the e-waste bin, Kevin's first battle (tutorial fight).
3. **Mom's printer ticket** (new, interactive tutorial).
4. Route 1 and the Dead Zone. Phisher Pete drops a cloned **badge HD-0001**. "Who's Ransom?" becomes
   "Ransom has *badges*?"
5. Patch Town and Dana's Desktop Support Cert.
6. Every phone buzzes: `YOUR FILES HAVE BEEN QUARANTINED. -R`. **Choice:** stop Kevin replying-all or not.
7. **New Act 1 ending:** Mom calls. Her PC (or her printer) shows the ransom note with a timer.
   The first time Ransom is personal. Card: `TUE 06:12 — 106h left`.

### Act 2: The Outage (TUE–WED)
1. Port City. **Port 443 live incident** (new): Zed breaches it and Pyrewall goes dark.
2. The Basement: protect the tapes, first look at Restorephant.
3. DevOps Heights. Lyra's **password approach** (new choice). Devi's Friday deploy. Kevin's battle.
   The **log puzzle** reveals Kevin's password was phished.
4. Abandoned Data Center: beat Zed and Brute. Cron takes Sudofox.
   His laptop note points at "the drill box" and "M" (**evidence 4**).
5. Marge, quietly: "Keep going. I've got an idea, but it needs Friday." She won't say more, and now that line
   sounds suspicious. Card: `WED 23:40 — 41h left`.

### Act 3: The Breach (THU)
1. Power Plant: cryptojacked grid, brownouts. **Choice:** hospital or Help Desk power. Rolf's Facilities Cert.
2. Cloud Summit: Clondor flees, and Cron shows you his layoff letter: "Ask Marge what she does on Fridays."
   Kevin fights beside you, back-to-back (warmer if you trusted him in Act 1).
3. SecOps Fortress: phishing test, then Kalb's Security Cert.
4. **The cliffhanger** (new, replaces the "end of demo" sentry):
   - Kalb's analysts finish the trace. It doesn't end at HQ Tower. It ends at **10.0.0.1, the backup closet
     behind Marge's office.**
   - **Present your evidence** (pick 3).
   - Cut to Onboarding Town at night. SecOps vans. Marge walks out with Kalb, calm, carrying a pizza box.
   - She passes you and whispers: "Friday. Five o'clock. Don't let them cancel it."
   - Your badge flashes **ACCESS REVOKED**. The Onboarding Help Desk lights go dark: the first time your home
     town can't heal you.
   - Every screen in the valley: `SEE YOU AT FIVE. -R`
   - Card: `THU 23:59 — 17h left`. **DAEMONS — Act 4: Escalation. Coming soon.** Credits for the demo.

## 5. What the demo needs to build
| Piece | Size | Notes |
|---|---|---|
| Multi-option choice step in dialogue (pick 1 of N, or N in order) | small | The menu already exists (choose_from_list); the dialogue runner needs a step for it |
| EVIDENCE list (pause menu) + `give_evidence` command | small–medium | Flags underneath; a list screen like the Bag |
| Date/time cards between acts | small | A full-screen text card, like the battle intro |
| Cold open + new Act 1 ending + cliffhanger cutscene | medium | Uses show_npc / move_npc / flags; needs a dark tint for Onboarding Town at night |
| Incident scenes (printer, Port 443, log puzzle, Lyra) | medium | Mostly dialogue data once the multi-choice step exists |
| Rewrite affected dialogue (Kevin, Marge, Kalb, Cron) | medium | Data only |
| New character art: Cron, Zed, Brute, Lyra-in-disguise, Ping Okoro, Devi Shah | art | The Ransom crew and dept heads still use placeholder looks |
| Tests: every choice path completes, every evidence item is reachable, the demo ends cleanly | medium | Extends test_vertical_slice / slice audit |

## 6. Effects on Acts 4–5 (later, for the full release)
- Act 4 opens with Marge in SecOps custody and you without a badge. Clearing her becomes part of earning the
  last three certs.
- The relay twist, explained at HQ Tower: Cron routed through the drill box *because* it was the only machine
  with access to every backup.
- The Pizza Friday restore at 5:00 PM is the finale, exactly as approved. The countdown ends there.

## 7. Decisions for Brandon
| # | Decision | Options | Recommendation |
|---|---|---|---|
| 1 | Cliffhanger | (a) Marge framed and taken in (b) Onboarding Help Desk encrypted, no arrest (c) Kevin goes missing | **(a)**: strongest hook, and it pays off the planned ending |
| 2 | Countdown to Friday 5 PM | yes / no | **Yes**, story-only (no real-time timer) |
| 3 | Insider evidence + EVIDENCE list | yes / dialogue-only, no list | **Yes** |
| 4 | Incident scenes | all four / just Port 443 / none | **All four** (the printer one doubles as the tutorial) |
| 5 | Choices that carry forward | all five / fewer | **All five**; each is small |
