# Goblin Mode — Test / QA Plan

*For a solo dev, QA is mostly about two things: catching bugs cheaply, and — far more important for a roguelike — finding out whether the game is actually fun. Both are covered here.*

## Testing approach

Five complementary layers:

- **Functional testing** — does it work? Movement, stealth, loot pickup, save/load, raid generation, warren economy, mode transitions.
- **Automated testing** — a cheap safety net that runs without me. Three pieces (detailed in the [Technical Design Doc](03-technical-design-document.md#automated-testing)): (1) **unit tests** in GUT or gdUnit4 (the two common Godot test frameworks) over the logic-heavy, easy-to-break bits — agent/component behaviour, economy math, save logic; (2) the **headless solvability validator** — a script run under `godot --headless` (no window, so it can run in CI, the automated "did anything break?" check that fires on every commit) that checks large batches of generated raid seeds and *fails the build* on any unsolvable layout; (3) the **save round-trip + migration test** (write → read → identical, plus loading old-version save fixtures). These turn two release criteria below — "raids pass automated validation" and "saves survive updates" — into checks the machine enforces, not promises I have to remember.
- **Playtesting (the priority)** — is it fun? Is the core loop compelling? Where do players get bored, confused, or frustrated? For a roguelike sim, this is the most valuable testing you'll do.
- **Balance testing** — are difficulty, economy, and progression tuned? Is "goblin mode" tempting but fair? Do raids feel risky without feeling unfair?
- **Compatibility testing** — does it run on a range of PC hardware (low-end laptop to high-end), windowed/fullscreen, keyboard and controller, common resolutions?

## What gets tested

- **Core raid loop:** stealth detection, noise/alert behavior, combat, loot weight, dawn timer, escape, death/capture handling.
- **Procedural generation:** every generated raid is **completable** (reachable loot and exit), readable, and not degenerate. This needs automated validation, not just manual play — the [headless solvability validator](03-technical-design-document.md#automated-testing) does graph reachability from spawn that *respects locked-door/key dependencies* (a key is an edge that unlocks a region) to confirm spawn → every required objective → at least one exit, optionally checking a lower-bound traversal time against the dawn timer. It fails CI on any unsolvable seed; in-game it rerolls with a hard attempt cap and falls back to a known-good authored layout, so a bad seed never blocks play. *(Scheduled as an **Alpha** deliverable — the vertical slice's one hand-built level is trivially solvable, so the validator isn't needed yet.)*
- **Warren systems:** building, job assignment, resource production, upgrades, recruiting.
- **Progression & economy:** meta-progression persists correctly across goblin deaths; resource sinks/sources stay balanced.
- **Save/load:** no corruption, no lost progress, sensible autosave — backed by the automated **save round-trip + migration test** (see [Save system & data](03-technical-design-document.md#save-system--data)), which loads fixtures saved under older `schema_version`s to prove a player's warren survives updates.
- **Co-op (when built post-1.0):** co-op sync, host migration/disconnects, no desyncs. Single-player is the launch scope; co-op raids are a planned post-1.0 fast-follow and competitive "rival warren" is cut, so there's nothing networked to test until then — don't write network test harnesses speculatively. *(See [decisions log](00-decisions-log.md): Multiplayer.)*

## Playtest cadence & capturing feedback

- **Weekly self-playtest** with a short written note: what felt good, what dragged, what confused you.
- **Friends-and-family builds** at the vertical slice — watch people play *without helping them*; silence reveals the most.
- **Wider playtests** at alpha/beta via itch.io for early/playtest builds (Steam is the launch storefront), a Discord/Steam playtest, or a focused tester group.
- **Capture methods:** an in-game feedback key, a simple form, recorded sessions where possible, and (later) lightweight analytics on raid outcomes, deaths, and where players quit.
- Tag every piece of feedback as **fun/design**, **bug**, or **balance** so it routes to the right backlog.

**Named playtest questions** — ask these at every wider playtest, alongside "is it fun?":

- **"Is the humour landing as charming, not cruel?"** The tone spine is underdog farce — goblins are the butt of the joke as often as the tall folk, and no one is genuinely harmed (see the [Tone Charter](08-narrative-and-glossary.md)). If a tester reads a moment as mean rather than funny, that's a tone bug, not a balance one — route it to fun/design.
- **"When Goblin Mode fires, does death read as earned?"** Goblin Mode is an *extraction* tool that makes you EXPOSED, not invincible — the moment it triggers, the noise meter pins to max, the alert UI flashes, and the music goes frantic. The test is whether players who wipe out in frenzy feel *they* gambled and lost (good) versus feeling cheated by an unfair shove (a signal bug). Validate this signal in both balance and playtesting.

## Bug triage & severity levels

| Severity | Definition | Response |
|----------|------------|----------|
| **S1 — Blocker** | Crash, save corruption, unwinnable/softlocked raid (see the defined test below) | Fix before any release build |
| **S2 — Major** | Core feature broken or badly degraded | Fix before the milestone ships |
| **S3 — Minor** | Noticeable but has a workaround | Schedule into a normal cycle |
| **S4 — Polish** | Cosmetic, rare, low impact | Backlog; fix opportunistically |

Track bugs on the same board as features, labeled by severity. Commit fixes with Conventional Commits (e.g. `fix: prevent softlock when exit spawns behind locked gate`).

**What counts as an S1 "unwinnable/softlocked raid":** the game promises *no permanent game over* — so the bar is concrete, not a feeling. A raid is softlocked if a generated layout has no path from spawn to a required objective and an exit (caught by the [headless solvability validator](03-technical-design-document.md#automated-testing)). The *warren* is softlocked if the player can ever be trapped in an unrecoverable hole — which the anti-softlock guarantee forbids: the Recruitment / Breeding Den always passively produces a free baseline goblin on a timer, and a zero-cost foraging option always exists (see the anti-softlock rule under Win/lose in the [GDD](02-game-design-document.md)). Any state that defeats *either* backstop — no reachable raid, or no way to claw back goblins/Food — is an S1 by definition.

## Release / readiness criteria

A build is releasable when:

- Zero open **S1** bugs and no known **S2** bugs in core loops.
- A new player can reach and understand the core loop without external help.
- Procedural raids pass the [headless solvability validator](03-technical-design-document.md#automated-testing) across a large batch of seeds in CI — green, not spot-checked by hand. *(Alpha onward — pre-Alpha builds use the hand-built level.)*
- Save/load is reliable across update boundaries — the automated [save round-trip + migration test](03-technical-design-document.md#save-system--data) passes, including fixtures from prior `schema_version`s, so existing warrens survive the update.
- The [GUT / gdUnit4 unit suite](03-technical-design-document.md#automated-testing) is green (agent, economy, save logic).
- **Performance holds 60 FPS at the stated agent budget on the target low-end machine** (integrated graphics) — the worst-case raid at ~20–30 active alertable agents plus a busy warren, not a quiet scene (this is the M2/Alpha exit test in [Performance: agent budgets & the sim tick](03-technical-design-document.md#performance-agent-budgets--the-sim-tick)).
- **Demo readiness (at the [Next Fest demo](05-project-plan-roadmap.md#demo-next-fest) beat):** the demo build is stable enough to hand to a stranger *unattended* — no S1/S2 in the demo slice, a clean first-run experience, and the [tone and Goblin Mode playtest questions](#playtest-cadence--capturing-feedback) answered "yes" — since most Next Fest wishlists come from people who watch but never play, the demo's first 60 seconds are the marketing.
- *(No console certification needed — PC-only. If a console port is ever pursued, add platform cert criteria here.)*
