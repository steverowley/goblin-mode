# Goblin Mode — Narrative & Glossary

*The canonical home of the Tone Charter (every other doc cross-references it here), plus the text/narrative plan, the goblin name generator, the shared glossary, accessibility rules, and the asset-naming convention. Like the rest of the suite this is a **living hypothesis** — revise it as the prototype teaches us what's true. Open questions are marked `[TODO]` and mirrored in the [decisions log](00-decisions-log.md).*

## Tone Charter

This is the constitution for the game's humour. Every system — art, audio, writing, death feedback — answers to it. The spine is **"underdog farce."**

**What "underdog farce" means in one breath:** the goblins are the butt of the joke at least as often as the tall folk are. The comedy comes from *incompetence and slapstick* — a goblin tripping over its own sack, a guard too oblivious to notice the chaos behind him — never from anyone genuinely suffering. The tall folk are *pompous and oblivious*, the goblins are *charming losers*, and a dash of gross-out (squelches, snot, a wheel of cheese eaten whole) gives it flavour without turning mean.

The single named playtest question that guards this whole charter: **"Is the humour landing as charming, not cruel?"** If a beat makes the goblins pitiable instead of funny, or makes a human's misfortune feel like real harm, it has failed the charter and gets cut or reworked. (This is why the tone risk is scored **Medium/High** in the [risk register](07-risk-register.md) — tone is easy to get wrong and hard to recover once players read the game as mean-spirited.)

### ALWAYS

- A goblin's failure is **slapstick**: it overpacks, the sack bursts, it scatters loot down the stairs, it knocks itself out on a low beam.
- The tall folk are **pompous and oblivious** — a guard yawns through an alarm, a merchant fusses over a doily while his pantry is stripped bare.
- The goblin is the **little menace you root for**: scrappy, feral, in over its head, and somehow endearing for it.
- Gross-out is **charming-gross**: squelchy foley, a goblin gnawing something it shouldn't, mud everywhere. Cute enough to root for, grimy enough to be the wrong side of the tracks.
- "Goblin Mode" frenzy plays its chaos for **gleeful, reckless comedy** — the goblin is having the time of its life right up until it doesn't escape.
- Death of a low-investment goblin is a **comedic pratfall**; death of a beloved named goblin earns a **brief bittersweet-funny beat** (a pathetic salute, a dropped trinket) — see death feedback tiers in the [GDD](02-game-design-document.md) and [art bible](04-art-bible-style-guide.md).

### NEVER

- **Never** comedy from a victim's genuine suffering — no human screaming in real fear, no pleading, no on-screen injury played for laughs.
- **Never** a tall-folk character who is sympathetic and *then* harmed; if they're harmed at all it's bloodless, off-screen pratfall stuff (a guard bonked into a comedy daze, not wounded).
- **Never** cruelty toward the goblins either — they lose, they faceplant, they get shooed out the door; they are not tortured, degraded, or made genuinely pitiable.
- **Never** grimdark, gore, or shock-horror. The world is grubby, not grim.
- **Never** punching down at real-world groups; the "tall folk" are a fantasy establishment, not a stand-in for any real people.
- **Never** a gross-out gag that reads as disturbing rather than silly. Snot is funny; suffering is not.

### Audio rule (tone-critical)

Keep the **tension and the comedy on separate tracks** so the farce never undercuts the stakes:

- **Spotted / chased = genuinely tense.** Rising alert stingers, escalating percussion, a real "get out NOW" pulse. No jokes here — the danger has to be felt or the loop has no teeth.
- **Comedy sting = ONLY on "fully caught."** The pathetic comedy sting plays *after* the goblin has failed and is being shooed out (released, not harmed). That timing is what makes the humour read as charming: we laugh *with* the loser after the fact, not *at* someone in peril.

This mirrors the audio direction in the [art bible](04-art-bible-style-guide.md) and the "Goblin Mode = EXPOSED" signal: the frenzy *sounds* reckless and dangerous on purpose, so a death in it reads as **earned, not unfair.**

## Narrative & text plan

A deliberately small text surface, written by one person, with **no localization and no recorded voice-over** (see hard constraint below). Most of the game's "story" is *emergent* — assembled by the player out of procedural goblins, named-crew permadeath, and the day/night loop — with only a thin layer of *scripted* text on top. This keeps the writing workload sane for a solo dev while leaning into the strength of the design: each loss is a tiny story the player tells themselves.

### Rough text-surface estimate

These are planning anchors, sized against the [launch content caps](02-game-design-document.md) (1 biome, ~4 rooms, ~8 traits), not commitments. Re-budget once the prototype locks roster size and trait count.

| Text asset | Rough size | Scripted or emergent | Notes |
|---|---|---|---|
| Trait names + one-liners | ~8 traits × (1 name + 1 short flavour line) | **Scripted** | One pithy line per trait; the *effect* is felt in play, the line just sells the personality. |
| Room / biome flavour | ~4 rooms + Farmlands biome blurbs | **Scripted** | A handful of short descriptors; grubby, hand-scrawled voice. |
| The Old Goblin — tutorial lines | ~15–30 short lines | **Scripted** | The elder who teaches the loop; the only sustained "character voice." Keep terse and funny. |
| Escape / death quips | a small rotating pool (~20–40 short barks) | **Scripted pool, emergent delivery** | Triggered by emergent events (clean escape, comedic capture, named-goblin death). Tiered to match death feedback. |
| Goblin names + epithets | **procedural** (see generator below) | **Emergent** | The single biggest "narrative" surface, and it writes itself. |
| Wall-of-the-dead / legacy records | short templated lines ("Grobnar, felled at the Capital, looted 4 cheeses") | **Emergent (templated)** | Fills from the legacy hooks in the [GDD](02-game-design-document.md). |

The honest takeaway: the *written* surface is modest. The heavy narrative lifting is done by **two animation assets, which are therefore load-bearing narrative content, not just polish:**

- **The comedic-death animations** (tiered: slapstick pratfall for a fresh recruit, bittersweet-funny beat for a beloved named goblin). These *are* the story of each permadeath. How many distinct death animations to author is decided in the prototype, because roster design dictates how much attachment each death must carry — keep this `[TODO]` open (mirrors the open item in the [art bible](04-art-bible-style-guide.md) and [decisions log](00-decisions-log.md)).
- **The "Goblin Mode" transformation animation.** It has to read instantly as *powered-up AND wildly exposed* — that dual read is the whole emotional contract of the frenzy, so the transformation does narrative work a line of text never could.

### Hard constraint (do not relax without an explicit decision)

> **No localization. No recorded voice-over. Goblin gibberish only.** All character "voice" is grunts, squeaks, and nonsense syllables — cheap to produce, high charm, and it sidesteps both translation cost and VO recording/direction entirely. On-screen text stays sparse and plain enough that it isn't a localization burden if that ever changes. This is a scope-protecting constraint for a solo dev; relaxing it is a real decision, not a tweak.

## Goblin name generator

Procedural names are core to "each loss a tiny story" — a goblin you can name is a goblin you can mourn (or laugh at). The rule set is intentionally simple so it ships in the slice and is easy to tune.

**Base rule: `prefix + suffix`** drawn from small syllable pools. Both pools lean grubby, comedic, and easy to read aloud.

- **Prefix pool (sound):** *Grob, Snag, Mug, Niz, Bork, Krad, Glum, Wort, Skib, Nub, Drip, Gob, Zed, H?nk, Mok, Splug, …*
- **Suffix pool (sound):** *-nik, -gar, -lo, -bul, -zit, -drot, -kins, -wort, -snot, -ix, -uld, -gore (silly, not gory), …*

Example pulls: *Grobnik, Snaglo, Mugzit, Nizbul, Borkkins, Splugdrot.*

**Occasional trait-based epithet (~1 in 4 goblins, tunable):** append a short epithet earned from the goblin's standout trait or a notable feat, so names quietly carry character.

- Trait-seeded: a sneaky goblin → *Snaglo the Quiet*; a Kleptomaniac → *Mugzit Sticky-Fingers*; a Light Sleeper-hunter who keeps tripping alarms → *Borkkins the Loud*.
- Feat-seeded (assigned in play, feeds the legacy/wall-of-the-dead records): *Grobnik Cheese-Thief*, *Nizbul Who-Fell-Twice*.

**Guard rails:** dedupe against the current living roster and the recent dead so two goblins don't share a name in the same breath; keep names short (one word + optional epithet) for HUD and tombstone readability; keep the pools on the right side of the [Tone Charter](#tone-charter) — silly, never slurs, never genuinely grim. The exact pools are content, not code, so they can grow without touching logic. `[TODO: finalize the syllable pools and the epithet trigger rate during the slice, once trait count is locked.]`

## Glossary

Shared vocabulary so every doc means the same thing by the same word. (Where a term has a deeper system behind it, the linked doc is the source of truth.)

| Term | Meaning |
|---|---|
| **Warren** | The player's persistent, player-built home base — the goblins' lair. It grows over the campaign and survives any individual goblin's death. |
| **Tall folk** | The in-world name for the humans, dwarves, elves, etc. whose towns the goblins raid — "tall" from a goblin's eye level. Pompous and oblivious by charter, never genuinely harmed. |
| **Shinies** | The core stolen currency (valuables/coin). Spent on warren upgrades, recruiting, gear, and intel. *"Pocketed shinies are safe; the one in your hands is at risk."* |
| **Scrap** | Crafting material gathered by raiding and scavenging; used to craft and repair gear. |
| **Relics** | Rare, high-risk loot from tough objectives; unlocks major shrine/meta upgrades. |
| **Biome** | A themed region with its own settlement type, loot, hazards, and faction (e.g. Farmlands/humans). Launch ships **one** fully-polished biome; more are post-launch. See the [GDD](02-game-design-document.md). |
| **Chunk** | A hand-authored room/tile building block. Raids are assembled procedurally from chunks so each one is fresh but readable. See the [technical design doc](03-technical-design-document.md). |
| **Raid** | A single night's procedurally generated heist into a tall-folk settlement: sneak in, grab loot, escape before dawn. The "night" half of the day/night loop. |
| **Fun Probe** | Milestone 0.5 — a throwaway, zero-art test of one hand-built room, one goblin, and the core verbs (move/sneak/grab/noise) vs. 1–2 guards, an exit, and a dawn timer. Success bar: *a stranger plays ~10 minutes and wants another go, with zero art and zero warren.* Deliberately excludes warren, procgen, economy, traits, Goblin Mode, and saving. See the [roadmap](05-project-plan-roadmap.md). |
| **Vertical slice** | One fully-polished sliver of the whole game — one warren room + one full night raid + the death-and-respawn loop — proving the core is *fun*, not feature-complete. The gate question is "is it fun," not feature count. |
| **Goblin Mode (the state)** | The in-game **frenzy mechanic**: a risk/reward extraction tool. The goblin goes fear-immune, sprints, smashes through locked/barred exits, ignores the sack weight cap without slowing, and rips fixed/bolted loot free — while its noise meter pins to max and the alert UI flashes "you are EXPOSED." High-value "fenced" frenzy loot only banks if you escape. |
| **Goblin Mode (the game)** | The **project itself** — this title. Capitalized and unqualified it usually means the game; when the *frenzy state* is meant, say "Goblin Mode frenzy / the Goblin Mode state." |

## Accessibility

Accessibility is a design constraint from day one, not a polish-phase add-on. The baseline rules:

- **Never encode information in colour alone.** Anything the player must read to play has to carry a second, non-colour channel (shape, icon, motion, or text). The most load-bearing case is the **Goblin Mode cue**: the green/pink "power tint" must be paired with a **shape/animation tell** — a distinct spiky/bristling silhouette plus a constant shaking/vibrating idle — so a colour-blind player still reads the frenzy instantly. The pinned noise meter and flashing alert UI are themselves motion/shape cues, not colour. (Mirrors the accessibility note in the [art bible](04-art-bible-style-guide.md).)
- **Remappable controls.** Every action must be rebindable for both keyboard and controller; never hard-code a verb to one key.
- **Adjustable text and UI scale.** The player can scale text/HUD up so it stays readable at a glance — important under raid pressure and on small or high-DPI screens.

These feed a **QA compatibility line**: *compatibility/accessibility testing confirms the game is fully playable with remappable controls, with no information conveyed by colour alone, and with text/UI scaling applied — across the supported hardware and resolutions.* (Adds an accessibility check to the compatibility pass in the [test/QA plan](06-test-qa-plan.md).)

## Asset naming & versioning convention

A plain-English filing system so a solo dev can find any asset months later, and so version control stays sane with large binary art files. Two tools are assumed: **Aseprite** (the pixel-art editor; `.aseprite` is its editable source file) and **Git LFS** ("Large File Storage" — a Git add-on that stores big binary files efficiently so the repo doesn't bloat).

**Naming scheme** — lowercase, hyphen-separated, in the order *category-subject-variant-state*:

```
goblin-base-idle.aseprite          # the editable source
goblin-base-idle.png               # the exported sprite sheet / frame
goblin-base-run-down.aseprite      # facing baked into the name (top-down needs facings)
guard-farmlands-patrol-walk.aseprite
loot-cheese.png
room-breeding-den-floor.png
ui-noise-meter.png
fx-goblin-mode-transform.aseprite  # load-bearing narrative asset
```

- **Source vs. export:** keep the editable `.aseprite` *and* the exported `.png` side by side with the same stem. The `.aseprite` is the truth; the `.png` is generated from it.
- **Facings in the name** (`-up/-down/-left/-right`, plus diagonals where authored) because the locked **top-down perspective** means most characters need directional sprites — see the [art bible](04-art-bible-style-guide.md).
- **No version numbers in filenames.** Don't make `goblin-idle-v2-final-FINAL.aseprite`. Git is the version history — let it do that job.

**Versioning with Git LFS:**

- Track binary art types with LFS so the repo stays light: e.g. `git lfs track "*.aseprite"` and `git lfs track "*.png"` (this writes a `.gitattributes` file; commit it).
- Commit the **`.aseprite` source alongside the exported sprite**, so the editable file is never lost and a teammate-of-future-you can re-export.
- Follow the suite's commit style for asset commits too (e.g. `feat(art): add breeding-den floor tiles`).

`[TODO: lock the final category prefixes once the first art pass exists; this scheme is a starting point, expected to grow with the asset list.]`
