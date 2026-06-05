# Goblin Mode — Game Concept / Pitch

*Working title. Solo project. PC-first. Premium (one-time purchase). 2D pixel art.*

## Elevator pitch

> **Build a goblin warren by day, raid the humans' towns by night — a roguelike where you're the monster under the bed.**

That's the capsule logline (the one-sentence Steam hook). The ownable angle underneath it: every *other* day/night game has you **defending** — here the inversion is flipped and **you are the monster doing the raiding**. You're the problem the hero gets sent to deal with, not the hero. That offence-side day/night loop is the hook nobody else is selling.

By day you run a ramshackle warren; by night you slip into the towns of the "tall folk" to steal, sabotage, and grab every shiny thing not nailed down. **Goblin Mode** is a 2D pixel-art roguelike where embracing your inner gremlin is the whole point — and where dying just means the next goblin in the warren grabs a rusty knife and takes their turn.

## Genre & platform

A blend that holds together around a day/night rhythm:

- **Roguelike** — procedurally generated nightly raids, run-based, individual goblins are expendable.
- **RPG** — goblins have stats, traits, and gear; you build them up over time.
- **Strategy / Sim** — by day you grow and manage the warren as a small base-building economy.

Platform: **PC — Steam at launch; itch.io for early/playtest builds.** Single-player at launch; co-op raids planned as a post-1.0 fast-follow; competitive "rival warren" is cut. (See the [GDD](./02-game-design-document.md) and the [decisions log](./00-decisions-log.md).)

## Target audience

Players who love the moment-to-moment chaos of roguelikes (Hades, Dead Cells) but also enjoy the "just one more day" pull of management sims (Dwarf Fortress, RimWorld, Goblin Stone). The tone draws people who find goblins genuinely funny — the internet "goblin mode" crowd — and who want a power fantasy that's mischievous rather than heroic. The humour spine is "underdog farce" (charming, never cruel); the canonical rules live in the [Tone Charter](./08-narrative-and-glossary.md).

## Core fantasy — what makes it fun

You are the little menace. Not the chosen hero — the problem the hero gets sent to deal with. The joy is in being small, scrappy, and a bit feral: scurrying through a sleeping town, cramming a wheel of cheese into your sack, knocking over a lantern just because, and barely escaping as the alarm bell rings. Then you waddle home and use the haul to make your warren bigger, weirder, and meaner.

## Unique selling points

- **The day/night loop.** Two distinct modes feeding each other — a calm management layer and a tense raiding layer — so the game never gets monotonous. The day phase isn't a passive shop screen: each **morning forces one consequential choice** that changes *how* tonight's raid plays, not just how strong you are. Take lockpicks *or* a stink bomb (not both); spend on pre-raid intel that reveals a map weakness; pick which goblin's traits suit tonight's target. At least one warren resource is kept scarce enough that this is a real allocation decision, not a freebie.
- **A roster, not a hero.** You don't protect one precious character; you command a horde of characterful, disposable goblins. Losing one stings a little and is also kind of funny.
- **"Goblin mode" as a mechanic.** A risk/reward *extraction tool*: a frenzy state where your goblin goes fear-immune, smashes through locked or barred exits, ignores the sack's weight cap without slowing, and rips fixed or bolted loot free — but it pins your noise meter to max and flashes "you are EXPOSED," so death reads as earned, not unfair. The big "fenced" frenzy loot only banks if you actually escape.
- **Personality-driven permadeath.** Procedurally generated goblins with traits and names make each loss a tiny story.

## Comparable titles

**Closest mechanical comp: The Swindle.** A procgen stealth-heist roguelike — the nightly "break in, grab the loot, get out before it goes wrong" loop is the part of Goblin Mode that most resembles an existing game. Its known weakness (raids start to feel samey) is exactly our biggest design risk, so we study it as a warning, not just a flattering reference.

**Direct competitor to out-position: Goblin Stone.** Same goblin-underdog tone, but it's turn-based party tactics. We win the comparison by being more *action/stealth* and less turn-based — the raid is something you *play with your hands* in real time, not a battle you queue up.

For press one-liners only (never the store tagline): "It's **Hades**' raid-and-return loop crossed with **RimWorld**'s colony management, wearing the grubby charm of **Goblin Stone** and **Overlord**." We'll also test 2–3 candidate loglines on the target audience before locking the store hook. (See the [decisions log](./00-decisions-log.md).)

## Monetization at a glance

**Premium, one-time purchase.** No microtransactions, no ads. Possible paid cosmetic packs or a content expansion post-launch, but the base game is complete on its own.

Planning anchor: **$14.99 at 1.0 / $12.99 Early Access intro** (re-confirm at store-page time). After Steam's 30% cut, that's roughly **$10.49 net per copy**. Early Access is the default launch plan, decided at the Milestone 2 go/no-go gate and contingent on a sustainable ~monthly update cadence; otherwise we ship a polished 1.0 instead. (See the [decisions log](./00-decisions-log.md).)

## First proof-of-concept target: the Vertical Slice

Games don't ship a software-style MVP — the equivalent is a **vertical slice**: one fully polished sliver of the game that proves the core is fun. For Goblin Mode that's **one warren room + one full night raid on one settlement type + the death-and-respawn loop**, playable end to end and genuinely enjoyable. Everything in the roadmap builds toward and out from that slice.
