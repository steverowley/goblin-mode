# Goblin Mode — Game Design Document (GDD)

*This is the living heart of the project. Expect to revise it constantly as playtests teach you what's actually fun. Everything here is a starting hypothesis, not a contract.*

## Overview

Goblin Mode is a single- and multiplayer roguelike sim for PC. The player leads a goblin warren through a repeating **day/night cycle**: by **day** you manage and grow the warren (a base-building economy); by **night** you send a goblin on a procedurally generated **raid** into the lands of the "tall folk" to steal resources. Loot funds permanent warren growth. Individual goblins can die permanently on raids, but the warren persists — so death is a setback, not a game over.

## Core gameplay loop

**The minute-to-minute (night raid):** sneak → grab loot → avoid or fight guards → manage your noise/alert meter → escape before dawn.

**The session loop (one day):**
1. **Morning — Plan.** Review the warren, assign goblins to jobs, craft gear, choose tonight's target settlement.
2. **Night — Raid.** Take one goblin (or a small party in co-op) into a procedural level. Loot, sabotage, survive, escape.
3. **Dawn — Return.** Bring the haul home. Spend it on warren upgrades, recruit new goblins, level up survivors.

**The meta loop (many days):** the warren grows from a single muddy tunnel into a sprawling lair; you unlock new biomes, settlement types, factions, and goblin abilities; difficulty and reward both climb.

## Mechanics & systems

### Day phase — Warren management (sim/strategy)
- **Rooms & building.** Dig and build rooms: kitchen (turns raw food into meals that buff raids), workshop (crafts gear), breeding pit / recruitment den (adds new goblins), storeroom (capacity), shrine (meta-upgrades). *[TODO: finalize room list during prototype.]*
- **Job assignment.** Assign idle goblins to jobs that run passively (cooking, crafting, foraging, repairing) so the warren produces value while you raid.
- **Economy inputs.** Food (keeps the warren alive and fuels raids), Shinies (currency for upgrades), Scrap (crafting material), and rare relics (unlock big upgrades).

### Night phase — Raiding (roguelike action-RPG)
- **Movement & stealth.** Top-down or side-on (decide in prototype) movement with crouch/sneak, hiding spots, and line-of-sight stealth. A **Noise meter** and **Alert level** govern how aware the town becomes.
- **Combat.** Light, scrappy melee plus improvised tools (slingshot, stink bombs, grab-and-throw objects). Goblins are weak head-on — stealth and tricks beat brute force.
- **Loot & sabotage.** Grab items of varying weight/value; the heavier your sack, the slower and noisier you get (risk/reward). Optional sabotage objectives (douse the forge, free the livestock) grant bonus rewards.
- **"Goblin Mode" state.** A meter that fills as you cause chaos. Trigger it to enter a frenzied state: faster, stronger, immune to fear, but loud, reckless, and unable to sneak. High risk, high loot, high chance of a glorious death.
- **The escape.** Reach an exit before the dawn timer runs out. Carried loot only banks if you escape; die or get caught and you lose what you were carrying (but keep meta-progress).

### Progression & RPG systems
- **Per-goblin growth.** Each goblin has stats (Sneak, Brawn, Cunning, Guts), a few random **traits** (e.g. "Light Sleeper," "Kleptomaniac," "Cowardly," "Iron Stomach"), and equippable gear. Survivors level up.
- **Permadeath + meta-progression.** When a goblin dies, you keep banked loot and any permanent warren/shrine upgrades. New recruits inherit the warren's accumulated bonuses (roguelike meta-progression, à la Rogue Legacy / Hades).

## Game world / setting

A grubby low-fantasy world seen from the bottom of the social ladder. Goblins are treated as vermin by humans, dwarves, and elves — so raiding is equal parts survival and petty revenge. The world is organized into **biomes**, each with its own settlement type, loot, hazards, and faction (e.g. Farmlands/humans, Mountain Holds/dwarves, Glade Villages/elves). *[TODO: finalize biome roster.]*

## Story & characters

Light, comedic, environmental storytelling rather than heavy plot. A loose arc: your warren starts as the runts nobody respects and grows into a legend the tall folk tell scary stories about. Recurring characters: **The Old Goblin** (tutorial-giving elder), a rival warren (multiplayer/competitive hook), and named goblins the player grows attached to. Humor is central — the tone is mischievous, never grimdark.

## Level / content structure

- **Warren:** one persistent, player-built hub that grows over the campaign.
- **Raids:** procedurally generated levels assembled from hand-authored room/tile chunks, themed per biome, so each raid is fresh but readable. Difficulty scales with the warren's progress and the chosen target's risk tier.

## Player progression & economy

| Resource | Earned by | Spent on |
|----------|-----------|----------|
| Food | Raiding pantries, foraging job | Keeping the warren fed, cooking raid buffs |
| Shinies | Stealing valuables | Warren upgrades, recruiting, gear |
| Scrap | Raiding/scavenging | Crafting and repairing gear |
| Relics (rare) | High-risk objectives | Major shrine/meta unlocks |

Pacing goal: early raids are low-stakes and forgiving; as the warren grows, targets get richer and deadlier, and the "goblin mode" risk/reward tension sharpens.

## Controls / UX

- **Raids:** WASD/controller movement, dedicated sneak, grab/interact, attack/use-tool, and a trigger for "goblin mode." Readable HUD: noise meter, alert level, dawn timer, sack weight.
- **Warren:** point-and-click / cursor-driven management UI for building and job assignment.
- Full keyboard+mouse and controller support. *[TODO: confirm perspective — top-down vs side-on — in the prototype; it affects the whole control scheme.]*

## Multiplayer (single-player and multiplayer, per intake)
- **Co-op raids:** 2–4 players take a goblin gang into one raid together — more chaos, more carry capacity, shared escape timer.
- **Competitive "rival warren":** asynchronous or direct competition to out-loot a rival warren. *[TODO: decide async vs real-time; networking scope is the single biggest risk for a solo dev — see Technical Design Doc.]*

## Win / lose conditions

- **Raid level:** "win" = escape with loot before dawn; "lose" = goblin dies or is captured (lose carried loot, not the run).
- **Campaign:** open-ended. A soft "victory" milestone (e.g. reaching legendary warren status / clearing the hardest biome) plus an endless mode for replay. There is no permanent game over as long as the warren can produce one more goblin.

## Audio direction (high level)

Playful, percussive, a little grubby — squelchy goblin foley, comedic stingers when caught, tense low drones as the alert level climbs, triumphant chaos when "goblin mode" triggers. Detailed direction lives in the Art Bible.
