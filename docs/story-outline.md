# DAEMONS — Story Outline (APPROVED 2026-11-13)

Drafted and approved 2026-11-13: Brandon accepted every recommendation in section 7. Nothing here is built yet
except Act 1. Levels and smaller beats can still move during building. Follows the design doc's four-line outline, the
master roster (Nos. 000–178) and the Battle Scene spec.

## 1. The pitch in one paragraph
It's your first week on the Root Valley Help Desk. A ransomware crew called **Ransom** starts encrypting the
valley one town at a time, and every Help Desk that goes dark leaves people with no way to heal their Daemons.
You earn 8 Certifications, fix what Ransom breaks, and find out the crew is led by the valley's old sysadmin,
laid off when "everything moved to the cloud". It ends with the one thing nobody in IT believes in: a restore
from backups that actually works, because someone tested them.

**Tone:** office comedy, never mean. Jokes come from real IT life (tickets, reply-all, "have you tried turning it
off and on again", Friday deploys). Stakes are real but small-town: lost data, dark Help Desks, worried people.
No demonic or occult imagery; Daemons are background processes.

**Theme:** maintenance is heroism. The flashy fix never saves the day; the boring habit (testing backups,
patching, labeling cables) does.

## 2. Cast

### Your side
| Who | Role | Notes |
|---|---|---|
| **You** | New help-desk hire | Named at the start. Silent, competent, slightly overworked. |
| **Kevin** | Rival, always replies-all | Loud, competitive, secretly scared of failing. Arc in section 4. |
| **Marge**, the Manager | Your boss at Onboarding Town | Calm, dry humor. Quietly runs a backup restore drill every Friday and bribes the team with pizza. This is the ending's payoff (see Act 5). |
| **Mom** | At home | Calls you about her printer. Heals your team in the post-game. |

### Department heads (the 8 Certifications)
Order and types come from data/certifications.json. Names approved 2026-11-13.

| # | Department | Town | Type | Head (proposal) | Personality | Ace (Lv) |
|---|---|---|---|---|---|---|
| 1 | Desktop Support | Patch Town | Hardware | **Dana** (built) | "Hardware that refuses to die." | Servurtle 13 |
| 2 | Networking | Port City | Network | **Ping Okoro** | Harbor-master energy; talks in latency jokes | Calfiber 19 (balance: Orcable was too strong at 20) |
| 3 | DevOps | DevOps Heights | Software | **Devi Shah** | Deploys on Fridays to prove a point | Mothread 26 |
| 4 | Facilities | Power Plant | Power | **Rolf Brandt** | Old-school, owns 40 extension cords, all labeled | Coolapotamus 35 (placeholder until Power art; Surgupine planned) |
| 5 | SecOps | SecOps Fortress | Security | **Major Vesna Kalb** | Trusts no one, including you, until you pass | Crabinet 41 (placeholder until Security art; Authoberman planned) |
| 6 | Data & Analytics | Lakeside Labs (new town) | Data | **Quinn Pivot** | Speaks only in charts | Datadam 43 |
| 7 | Mobile | Signal Ridge (new town) | Mobile | **Tasha Bars** | Never off her phone; it's always at 2% | Moosetower 48 |
| 8 | AI Lab | AI Lab campus | AI | **Dr. Ada Lumen** | Kind, a bit too trusting of her models | Neurowl 53 |

### Ransom
| Who | Role | Notes |
|---|---|---|
| **Phishers** | Grunts | Gray hoodies, fake lanyards. Use Spigeon, Phishgill, Wigglog, Cuckling. Phisher Pete is the first one (built). |
| **Exploit Kits** | 3 admins | **Zed** (zero-days, fast and smug; Spoofish, Trojuckoo), **Brute** (brute force, says everything three times; Rootrat, Cryptodile), **Lyra** (social engineering, impersonates people; Lyrefake, Spyquito). |
| **Cron**, the leader | The valley's old sysadmin | Did everything on a schedule, so everyone called him Cron. Laid off when the Board moved the backups "to the cloud" (into Clondor's care) and called him "redundant". Ace: **Extortodile** (Malware, the Hashling line). |

**Cron's motive (the twist, kept sympathetic):** he believes nobody ever tests backups, so the valley's "cloud
migration" was a lie that cost him his job. Ransom encrypts everything to prove that when it's all gone, nobody
can restore it, and then sell the valley the key. He's half right: the Board never tested anything. He's wrong
about one person: your Manager tested every Friday.

## 3. Legendaries (who they are in the story)
| No. | Daemon | Story role (proposal) | When you can catch it |
|---|---|---|---|
| 000 | **Pyrewall** | Guardian of **Port 443**, the secure dock in Port City. Ransom breaches it in Act 2 and knocks it offline; that's how the encryption spreads. You see it fall. | **Post-game**, rebuilt at Port 443 (keeps your Nov 11 "post-game" decision and gives it a story role too). |
| 176 | **Restorephant** | The on-site backup, deep in The Basement. Ransom tries to wipe its tapes; you stop them. | After the ending, in the Basement's deepest level. |
| 177 | **Clondor** | The off-site cloud copy, circling Cloud Summit. Ransom tries to delete it; it flees higher. | After the ending, at the summit. |
| 178 | **Sudofox** | Holds the root key every restore needs. Ransom captures it at the Abandoned Data Center and locks it in an encrypted Quarantine Key. Freed at HQ Tower. | Joins you at the ending (gift), or catchable post-game. |
| 026 | **Hallucinaut** | Post-game. The AI Lab's experiment that wandered off; confidently wrong about where it is. | Post-game. |
| 027 | **Uptimus** | Post-game. The valley's power-grid guardian, under the Power Plant. | Post-game. |

The **3-2-1 backup rule** (3 copies, 2 kinds of storage, 1 off-site) is the trio's theme: Restorephant (on-site),
Clondor (off-site), Sudofox (the key). The final restore needs all three.

## 4. The story, act by act

Levels: wild ranges, then trainer levels, then the department ace.

### Act 1 — Onboarding (BUILT, incl. the "-R" email beat and Marge's name, 2026-11-13)
Onboarding Town → Route 1 → Wi-Fi Dead Zone → Patch Town. Wild 2–8, trainers 4–8, Dana's ace 13.
- Day 1, starter from the e-waste bin, Kevin's first battle.
- Phisher Pete in the Dead Zone: "Ransom will hear about this... Who's Ransom?" (first hint).
- Dana: Desktop Support Cert. Route 2 is closed ("Port City, coming soon").
- **New ending beat for Act 1:** as you leave Patch Town, every phone in town buzzes with the same email:
  "YOUR FILES HAVE BEEN QUARANTINED. -R". Kevin replies-all to it.

### Act 2 — The Outage
*(All of Act 2 built 2026-11-13. Devi's team uses the Glowbit line until Software Daemon art exists.)*
**Route 2 → Port City (Dept 2).** Wild 9–14, trainers 12–17, ace 20.
- Port City's harbor runs on Port 443. Ransom's Phishers block the docks. You and Kevin (rival battle #2 on the
  docks) push through, too late: Zed breaches **Port 443** and Pyrewall goes dark. The harbor lights go out.
- First "encrypted" Help Desk: the Port City Help Desk is locked. A pop-up nurse station in a shipping container
  keeps working (gameplay: you can still heal, but the story shows the damage).
- Ping Okoro: Networking Cert. Calfiber and Proxkit live here.

**The Basement (Legacy dungeon).** Wild 14–18.
- Ransom (Brute) is wiping the old tape library. You fight through, protect the tapes, and see **Restorephant**
  for the first time; it stays to guard what's left.
- Find the **Legacy Driver** here (makes Ziphare reachable).

**DevOps Heights (Dept 3).** Wild 16–21, trainers 20–24, ace 26.
- Devi Shah deploys a fix to unlock the town's Help Desk on a Friday at 4:55 PM. It works. Barely.
- Kevin battle #3. **Kevin gets phished**: Ransom used his password to get into DevOps. He's mortified.
- Devi: Software Cert.

**Abandoned Data Center (Ransom hideout, mid-game climax).** Wild 20–24, admins 25–27.
- Infiltrate the old data center (cable puzzles, hot/cold aisles). Beat Zed and Brute.
- First real look at **Cron**. He's polite, tired and sure he's right. He takes **Sudofox** in an encrypted key
  and leaves. Every Help Desk in the valley shows the ransom note.
- End of Act 2: the Manager tells you, quietly, "Keep going. I've got an idea, but it needs Friday."

### Act 3 — The Breach
*(Built 2026-11-13. Rolf's and Kalb's teams are placeholders until Power/Security art exists.)*
**Power Plant (Dept 4).** Wild 24–28, trainers 27–31, ace 32.
- Ransom is cryptojacking the grid (Cryptleech everywhere). Brownouts hit the valley.
- Rolf Brandt: Facilities Cert. Uptimus is mentioned in old plant logs (post-game hook).

**Cloud Summit.** Wild 28–33.
- Ransom climbs the summit to delete the off-site copy. **Clondor** escapes higher; you meet Cron a second time.
  He explains why: the layoff letter, the untested migration. Kevin, now with MFA on everything, helps you hold the
  trail (a double battle alongside him, if we build double battles; otherwise back-to-back fights).

**SecOps Fortress (Dept 5).** Wild 30–35, trainers 34–37, ace 38.
- Major Kalb won't let you in until you pass a "phishing test" (a dialogue quiz with real tells).
- She traces Ransom's command server to **HQ Tower**, but HQ is locked to anyone without the root key.
- Kalb: Security Cert.

### Act 4 — Escalation
Three departments open in any order; Ransom hits each one. Wild 34–45, aces 43 / 48 / 53 (scaled by the order you go).
- **Lakeside Labs (Data):** Ransom poisons the data lake (Beavbit dams). Quinn Pivot: Data Cert.
- **Signal Ridge (Mobile):** Ransom pushes fake "update now!" notifications to every phone. Tasha Bars: Mobile Cert.
- **AI Lab:** Lyra uses Lyrefake to impersonate your Manager over a call and nearly talks you into handing over
  your certs. Dr. Lumen's Neurowl spots the fake. AI Lab Cert.
- With 8 certs, the valley's Departments together sign you onto the HQ Tower access list.

### Act 5 — Restore
**Kevin's last battle** at the HQ Tower doors (rival battle #5). Win or lose, he holds the lobby against Phishers so
you can go up.

**HQ Tower.** Ransom floors, Lyra, then Cron in the server room at the top.
- Beat Cron's team (ace Extortodile ~57). Free **Sudofox** from the encrypted key.
- The restore: Sudofox has the root key, but Restorephant's tapes and Clondor's copy are both "probably fine,
  never tested". Cron laughs. Then the Manager calls: they've run a restore drill every Friday for years, the
  **Pizza Friday** drills. The backups work. The valley comes back online, one Help Desk at a time.
- Cron, stunned, asks why nobody told him. The Manager: "You never came to Pizza Friday." He's offered a job:
  Backup Administrator, Fridays only.

**The C-Suite and The Board (the final challenge).** Framed as your **Annual Performance Review**.
- The CIO, CISO, CTO and CFO in a row (aces ~56–60), then **The Board** (~62), who approved the layoffs and the
  untested migration and now want to give you a "certificate of appreciation" instead of a raise. Beat them.
- Credits roll over the restored valley. Pyrewall's Port 443 dock relights in the last shot.

### Post-game
- **Pyrewall** rebuilt at Port 443 (catch it, catch rate 3).
- **Restorephant** in the Basement's deepest level, **Clondor** at the summit, **Uptimus** under the Power Plant,
  **Hallucinaut** wandering the AI Lab ("I'm definitely on the moon").
- Mom's printer finally gets fixed.

## 5. Kevin's arc (5 battles)
| # | Where | Beat |
|---|---|---|
| 1 | Onboarding Town (built) | Bursts in, picks the starter that beats yours. |
| 2 | Port City docks | Brags; then sees Pyrewall fall and goes quiet. |
| 3 | DevOps Heights | Gets phished; his password let Ransom in. |
| 4 | Cloud Summit | Turns on MFA everywhere; fights beside you. |
| 5 | HQ Tower doors | Last real battle; holds the lobby so you can go up. Ending: he stops replying-all. Mostly. |

## 6. What each act needs (rough build list)
| Act | New maps | New trainers | New Daemons used (roster) | Systems |
|---|---|---|---|---|
| 2 | Route 2, Port City, The Basement, DevOps Heights, Abandoned Data Center | ~25 | Network/Software/Legacy/Malware lines (041–065, 108–130) | Legacy Driver placement, encrypted Help Desk state |
| 3 | Power Plant, Cloud Summit, SecOps Fortress | ~20 | Power, Cloud, Security (066–107) | phishing quiz; double battle (optional) |
| 4 | Lakeside Labs, Signal Ridge, AI Lab | ~20 | Data, Mobile, AI, Peripheral (089–175) | open-order departments, level scaling |
| 5 | HQ Tower | ~15 + C-Suite + Board | trio + Extortodile | ending, credits, post-game flags |

## 7. Decisions (all approved by Brandon, 2026-11-13: the recommendation column is what we do)
| # | Decision | Options | My recommendation |
|---|---|---|---|
| 1 | Sign off on the 3-2-1 trio (Restorephant, Clondor, Sudofox) | yes / change / drop | **Yes**, as written in section 3 |
| 2 | Pyrewall's role | (a) story event at Port 443 + catchable post-game; (b) a 4th story legendary you catch during the story; (c) post-game only, no story role | **(a)**: keeps your post-game decision and uses the roster's "Port 443 breach" beat |
| 3 | Ransom leader's name | **Cron** / **Root** / your own | **Cron** (he ran everything on a schedule) |
| 4 | The Manager's name | **Marge** / keep "Manager" / your own | **Marge** |
| 5 | Department heads 2–8 names | as proposed in section 2 / your own | your call; easy to rename later |
| 6 | Finale shape | Cron climax, then the C-Suite + Board as an "Annual Performance Review" / Board as the true villain / Cron as the final boss | **Performance Review** (keeps Cron sympathetic, and the Board joke lands) |
| 7 | New towns for Depts 6–7 | Lakeside Labs + Signal Ridge / put them in existing towns | **New towns** (Act 4 needs places to go) |
| 8 | Double battles (Kevin at Cloud Summit) | build them / back-to-back fights instead | **Back-to-back for now**; double battles are a big system |
| 9 | Sudofox at the ending | given to you / catchable post-game | **Given to you** (you freed it) |
