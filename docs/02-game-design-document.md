# Goblin Mode — Game Design Document (GDD)

*This is the living heart of the project. Expect to revise it constantly as playtests teach you what's actually fun. Everything here is a starting hypothesis, not a contract.*

## Overview

Goblin Mode is a roguelike sim for PC. **Single-player at launch; co-op raids planned as a post-1.0 fast-follow; competitive "rival warren" is cut.** The player leads a goblin warren through a repeating **day/night cycle**: by **day** you manage and grow the warren (a base-building economy); by **night** you send a goblin on a procedurally generated **raid** into the lands of the "tall folk" to steal resources. Loot funds permanent warren growth. Individual goblins can die permanently on raids, but the warren persists — so death is a setback, not a game over.

The ownable hook is the **offence-side day/night inversion**: every other day/night game has you *defending* a base; here you are the monster doing the raiding. Logline: *"Build a goblin warren by day, raid the humans' towns by night — a roguelike where you're the monster under the bed."* Key creative decisions are indexed in [the decisions log](00-decisions-log.md); the comedy/tone rules that govern every system below live in the [Tone Charter](08-narrative-and-glossary.md).

## Core gameplay loop

**The minute-to-minute (night raid):** sneak → grab loot → avoid or fight guards → manage your noise/alert meter → escape before dawn.

**The session loop (one day):**
1. **Morning — Plan.** Review the warren, assign goblins to jobs, craft gear, choose tonight's target settlement.
2. **Night — Raid.** Take one goblin (or a small party in post-1.0 co-op) into a procedural level. Loot, sabotage, survive, escape.
3. **Dawn — Return.** Bring the haul home. Spend it on warren upgrades, recruit new goblins, level up survivors.

**The meta loop (many days):** the warren grows from a single muddy tunnel into a sprawling lair; you unlock new biomes, settlement types, factions, and goblin abilities; difficulty and reward both climb.

## Mechanics & systems

### Day phase — Warren management (sim/strategy)

The day phase is **asymmetric**, not a second full-weight game. It stays mostly light — review the warren, spend last night's haul — *but every morning forces ONE consequential choice* that changes **how** tonight's raid plays, not just how much raw power you bring. The point is a quick, juicy decision with a clear consequence you feel on the raid, so the day never becomes a spreadsheet chore that competes with the night for attention. (Hypothesis to validate in playtests: is one forced choice per morning enough friction to feel meaningful without slowing the loop?)

Concrete examples of the morning choice (pick a small rotating set for the slice):
- **Loadout fork — you can't take everything.** Take the lockpicks *or* the stink bomb tonight, not both — opening barred routes vs. buying a panic escape.
- **Pre-raid intel.** Spend Shinies on a scout report that reveals one map weakness (a guard's patrol gap, an unlocked side door, where the best loot sits) — power you trade currency for.
- **Crew pick.** Choose **which goblin** goes out, knowing their traits suit (or fight) tonight's target — a sneaky runt for a guarded manor, a brawler for a lightly-watched barn.
- **Rations call.** Cook tonight's food into a raid buff *or* bank it against the warren's upkeep — feeding the raider vs. feeding the home.
- **Patch or push.** Spend the morning's scarce labour repairing damaged gear *or* digging a new room — recover vs. expand.

- **Rooms & building.** Dig and build rooms: kitchen (turns raw food into meals that buff raids), workshop (crafts and repairs gear), **Recruitment / Breeding Den** (adds new goblins; see the anti-softlock rule under Win/lose), storeroom (capacity), shrine (meta-upgrades). The vertical slice commits to the **Recruitment / Breeding Den as its first built room** because it's the one that proves the warren-persists / goblins-are-expendable fantasy; the wider room list grows post-launch (see launch content caps under Level / content structure). *(Resolves the earlier room-list TODO — logged in [the decisions log](00-decisions-log.md).)*
- **Job assignment.** Assign idle goblins to jobs that run passively (cooking, crafting, foraging, repairing) so the warren produces value while you raid.
- **Economy inputs.** Food (keeps the warren fed and fuels raid buffs), Shinies (currency for upgrades, intel, recruiting), Scrap (crafting material), and rare relics (unlock big upgrades).
- **One scarce resource (forces a real choice).** Keep at least one input genuinely tight so the morning fork *costs* something. The current candidate is **labour / goblin-hours** — you never have enough goblins to staff every job *and* field your best raider, so assigning the crew is itself the allocation decision. (Food is the backup candidate if labour proves too abstract in testing.)

### Night phase — Raiding (roguelike action-RPG)
- **Movement & stealth.** **Top-down (three-quarter / 3-4 oblique view), LOCKED** — the prototype confirms it, so stealth assumes **360-degree line-of-sight**: guards see in a cone you can flank from any side, and there's no "behind the camera" safe lane the way a side-on game gives you. Crouch/sneak, hiding spots (shadow, cover, under furniture), and breaking line-of-sight are the core defensive verbs. A **Noise meter** and **Alert level** govern how aware the town becomes. *(Resolves the earlier perspective TODO — logged in [the decisions log](00-decisions-log.md).)*
- **Noise (design view).** Noise is the second sense you outwit alongside sight. The game emits discrete **noise events** — a footstep, a dropped sack, a smashed pot — each with a loudness value, and that sound spreads *along the level's paths*: it rounds corners and through doorways but is muffled by walls, so a clatter two rooms away barely registers while the same clatter next door brings a guard. Each guard has a hearing threshold (the "Light Sleeper" trait lowers it). The player gets honest feedback: a **HUD noise meter** plus a brief **visual ping** at the source so a bad noise reads as *your* mistake, not a random gotcha. *(Player-facing summary; the propagation tech lives in the [Technical Design Document](03-technical-design-document.md).)*
- **Combat.** Light, scrappy melee plus improvised tools (slingshot, stink bombs, grab-and-throw objects). Goblins are weak head-on — stealth and tricks beat brute force.
- **Loot & extraction (the greed curve).** Grab items of varying weight/value; the heavier your sack, the slower and noisier you get (risk/reward). The core tension is **"one more room?"**, and it's tuned by three numbers we balance *together*: **loot value**, **sack-weight slowdown**, and the **dawn timer**. Two rules keep the greed honest:
  - **Partial banking — death isn't all-or-nothing.** Shinies you've *pocketed* are safe; the big haul *in your hands* is what's at risk. Drop-points / a getaway cart let you stash a run mid-raid, so a bad death costs the last grab, not the whole night. The fantasy: "pocketed shinies are safe, the one in your hands is at risk."
  - **Soft dawn escalator — not a hard cliff.** As dawn nears, danger and alert *ramp* (more guards waking, faster patrols, twitchier hearing) rather than the level slamming shut at a fixed second. Pushing for one more room stays a live, tempting gamble instead of a stopwatch you simply beat.
  - Optional sabotage objectives (douse the forge, free the livestock) grant bonus rewards.
  - *Tuning note:* this loot ↔ weight ↔ timer triangle is the **first balance question** the slice answers — it's what makes the raid fun before any art exists.
- **"Goblin Mode" state (the extraction tool).** A meter that fills as you cause chaos. Trigger it and the goblin goes feral — but its spine is **escape utility, not a generic damage buff**:
  - **Fear-immune sprint** — you stop flinching and just *run*.
  - **Smash through locked or barred exits** — frenzy opens routes that were sealed.
  - **Ignore the sack-weight cap without slowing** — carry the impossible haul, briefly.
  - **Grab fixed / bolted objects** — wrench loose the things you couldn't normally take.
  - It's the answer to *"I've grabbed too much and the town's awake — how do I get OUT?"* For comedy, frenzy also fires **involuntary trait triggers** (a Kleptomaniac veering off to snatch a worthless spoon mid-sprint, an Iron Stomach pausing to eat the evidence). To match it, there's a tier of higher-value **"fenced" loot** that *only banks if you escape* — the frenzy is how you grab it, the escape is how you keep it.
  - **You are EXPOSED, not invincible.** The moment it triggers, the read is unmistakable: the **noise meter pins to max**, the **alert UI flashes**, and the music goes frantic. Frenzy makes death *more* likely, not less — so a glorious wipeout reads as a gamble you took, never an unfair shove.
- **The escape.** Reach an exit before the soft dawn escalator overwhelms you. Carried (un-banked) loot only banks if you escape; die or get caught and you lose what's *in your hands* (but keep pocketed loot and all meta-progress).

### Progression & RPG systems
- **Per-goblin growth.** Each goblin has stats (Sneak, Brawn, Cunning, Guts), a few **traits**, and equippable gear. Survivors level up.
- **Traits change a RAID, not a spreadsheet.** Traits are **felt, active modifiers** you notice mid-raid, not passive math you read on a stat screen. The slice ships **4–6** of these so the difference between two goblins is obvious in the first minute of play. Starting set (tune in prototype):
  - **Sneakthief** — quieter footsteps; buffs the stealth you can already feel (the "good" pick for a guarded target).
  - **Light Sleeper** — *for the player it's a liability*: this goblin's nerves make it emit involuntary noise (gasps, fidgets) under stress, tripping guard hearing. (Mirrors the guard trait of the same name — see Noise.)
  - **Kleptomaniac** — ties into Goblin Mode: in frenzy it involuntarily veers to grab nearby shinies, comedic and occasionally costly.
  - **Iron Stomach** — can eat field loot to top up a little Food/health mid-raid, but may pause to do it at the worst moment.
  - **Butterfingers** — higher chance to *drop* carried loot when hit or startled (a dropped-sack noise event), trading reliability for slapstick.
  - **Cowardly** — bolts toward the nearest exit when alert spikes; sometimes a lifesaver, sometimes it sprints you straight into a guard.
  - *(Resolves the trait-roster TODO — the full trait library grows post-launch; logged in [the decisions log](00-decisions-log.md).)*
- **A small named crew, not a faceless pool.** You actively rotate a persistent gang of **3–5 named goblins** rather than drawing from an anonymous stack — concentrating attachment is what makes a death *land*. (Detail in Story & characters.)
- **Permadeath + meta-progression.** When a goblin dies, you keep banked loot and any permanent warren/shrine upgrades. New recruits inherit the warren's accumulated bonuses (roguelike meta-progression, à la Rogue Legacy / Hades).

## Game world / setting

A grubby low-fantasy world seen from the bottom of the social ladder. Goblins are treated as vermin by humans, dwarves, and elves — so raiding is equal parts survival and petty revenge. The world is organized into **biomes**, each with its own settlement type, loot, hazards, and faction (Farmlands/humans, Mountain Holds/dwarves, Glade Villages/elves, …). The vertical slice and launch commit to **one fully-polished biome: the Farmlands (humans)** — barns, pantries, sleepy night-watch — because it's the most legible setting for teaching stealth and the clearest fit for the "monster under the bed" fantasy. Further biomes (Mountain Holds, Glade Villages) are deliberate **post-launch / Early Access growth**, not launch scope. *(Resolves the biome-roster TODO by committing the slice pick while leaving the full roster open — logged in [the decisions log](00-decisions-log.md).)*

## Story & characters

Light, comedic, environmental storytelling rather than heavy plot. A loose arc: your warren starts as the runts nobody respects and grows into a legend the tall folk tell scary stories about. Recurring characters: **The Old Goblin** (tutorial-giving elder) and a **small, named crew of 3–5 goblins** the player actively rotates and grows attached to. (Concentrating attachment on a few named goblins, rather than a faceless pool, is what gives permadeath its punch.) Humour is central and governed by the [Tone Charter](08-narrative-and-glossary.md) — the spine is *underdog farce*, never grimdark.

- **Tiered death feedback.** Not every death gets the same send-off. A fresh, low-investment runt dies in pure **slapstick** (a comedic flail, an undignified squish). A leveled-up, geared goblin you'd grown attached to gets a brief **bittersweet-funny** beat — a pathetic little salute, a dropped trinket left behind. Matching the weight of the death to your investment is what keeps the comedy charming rather than callous. *(Final form is a prototype call, since it sets how many death animations to author — see [decisions log](00-decisions-log.md).)*
- **Legacy hooks.** A fallen goblin's name and best feat are recorded (a wall of the dead / warren saga). A successor can inherit a dead goblin's gear or carry a **grudge** against the settlement that killed it — small narrative threads that make the rotating roster feel continuous.

## Level / content structure

- **Warren:** one persistent, player-built hub that grows over the campaign.
- **Raids:** procedurally generated levels assembled from hand-authored room/tile chunks, themed per biome, so each raid is fresh but readable. Difficulty scales with the warren's progress and the chosen target's risk tier.

**Launch content caps (a solo dev's scope discipline).** Shipping a small, *polished* slice beats shipping a sprawling, thin one. The 1.0 hard caps are:

| Content | Launch cap | Notes |
|---------|-----------|-------|
| Biomes | **1, fully polished** (Farmlands/humans) | A 2nd biome is post-launch / EA content. |
| Raid rooms (chunk types) | **~4** | Enough variety to keep procgen readable. |
| Traits | **~8** | Slice ships 4–6; the rest fill in by 1.0. |
| Enemies | **1 guard archetype + 1 patrol variant** | One readable threat, taught well. |
| Goblin art | **1 body** with palette + accessory variation | Reskins, not new rigs, carry visual variety. |

These are ceilings, not targets — if a cap proves too much for one person, cut, don't crunch.

## Player progression & economy

| Resource | Earned by | Spent on |
|----------|-----------|----------|
| Food | Raiding pantries, foraging job | Keeping the warren fed, cooking raid buffs |
| Shinies | Stealing valuables | Warren upgrades, recruiting, gear |
| Scrap | Raiding/scavenging | Crafting and repairing gear |
| Relics (rare) | High-risk objectives | Major shrine/meta unlocks |

**Soft-economy stakes.** Raids need to *matter*, so the warren carries a gentle ongoing pressure: a **Food upkeep** (and/or morale) it must keep meeting, or goblins grumble, drift off, or go hungry. A few empty-handed nights bite — that's the point — but the pressure is **soft, never a death spiral** (see the anti-softlock rule under Win/lose: you can always claw back). It gives every raid a reason beyond "more shinies."

Pacing goal: early raids are low-stakes and forgiving; as the warren grows, targets get richer and deadlier, the upkeep climbs, and the "goblin mode" risk/reward tension sharpens.

## Controls / UX

Perspective is **top-down (three-quarter / 3-4 oblique view), LOCKED** — the prototype confirms it, so the whole control scheme assumes free movement in all directions, not a left/right side-on plane.

- **Raids:** 8-directional WASD/controller movement (the goblin sprite faces the direction it moves), dedicated sneak, grab/interact, attack/use-tool, and a trigger for "goblin mode." Because sight is **360-degree**, the player needs to read guard facing at a glance — guards telegraph their vision cone, and the player can flank from any side. Readable HUD: noise meter, alert level, dawn-escalator state, sack weight, and the goblin-mode meter.
- **Sprite construction.** ~32×32 goblins on a low pixel-art base canvas (lock the exact size in the prototype), authored with the **facings** a top-down view needs (at minimum 4-direction; up/down/left/right) rather than the single left/right pair a side-on game would use.
- **Warren:** point-and-click / cursor-driven management UI for building and job assignment.
- Full keyboard+mouse and controller support. *(Resolves the perspective TODO — top-down is locked; logged in [the decisions log](00-decisions-log.md).)*

## Multiplayer

**Single-player at launch; co-op raids planned as a post-1.0 fast-follow; competitive "rival warren" is cut.**

- **Co-op raids (post-1.0):** 2–4 players take a goblin gang into one raid together — more chaos, more carry capacity, shared escape timer. This is a *fast-follow*, not a launch feature.
- **We do NOT build the game "network-aware" up front** — that's a known solo-dev trap. We pay exactly **one cheap seam** so co-op is achievable later: keep raid logic in a self-contained scene driven by an *injected controller object* (local input now, networkable later), and keep simulation out of visual `_process` code. (Architecture detail in the [Technical Design Document](03-technical-design-document.md).)
- Competitive play is cut entirely, so there is no rival-warren design to resolve here.

## Win / lose conditions

- **Raid level:** "win" = escape with loot before the dawn escalator overwhelms you; "lose" = goblin dies or is captured (you lose only the un-banked loot in its hands, not the run).
- **Campaign:** open-ended. The penciled climax for Alpha is **"the Capital"** — a mega-settlement victory wall the warren works up to raiding — followed by a **post-game endless / escalation** mode and a **legend score** that tallies your warren's notoriety (biggest hauls, named-goblin feats, the Capital cleared). These are *Alpha* goals, not slice goals.
- **No permanent game over (anti-softlock guarantee).** The soft-economy pressure (Food/morale) can hurt, but it can never trap you in an unrecoverable hole. Two backstops enforce the promise:
  1. The **Recruitment / Breeding Den always passively produces a free baseline goblin on a timer** — so you can never be permanently out of goblins.
  2. A **zero-cost foraging option always exists** — so you can always claw back a little Food without risking a raid.
  Together these mean a run can stall and sting, but the warren can always produce one more goblin and scrape one more meal — there is no dead end.

## Audio direction (high level)

Playful, percussive, a little grubby — squelchy goblin foley, tense low drones as the alert level climbs, and a frantic edge under "goblin mode." A deliberate split keeps the tone honest: **"spotted / chased" stays genuinely tense** (the danger has to feel real), and the **comedy sting fires ONLY on "fully caught"** — the moment after failure, when the goblin's been nabbed and released. This way the raid reads as exciting rather than goofy, and the laugh lands on the pratfall, not on the chase. Detailed direction lives in the [Art Bible](04-art-bible-style-guide.md); the comedy rules behind this split live in the [Tone Charter](08-narrative-and-glossary.md).
