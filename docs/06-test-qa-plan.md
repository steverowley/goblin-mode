# Goblin Mode — Test / QA Plan

*For a solo dev, QA is mostly about two things: catching bugs cheaply, and — far more important for a roguelike — finding out whether the game is actually fun. Both are covered here.*

## Testing approach

Four complementary layers:

- **Functional testing** — does it work? Movement, stealth, loot pickup, save/load, raid generation, warren economy, mode transitions.
- **Playtesting (the priority)** — is it fun? Is the core loop compelling? Where do players get bored, confused, or frustrated? For a roguelike sim, this is the most valuable testing you'll do.
- **Balance testing** — are difficulty, economy, and progression tuned? Is "goblin mode" tempting but fair? Do raids feel risky without feeling unfair?
- **Compatibility testing** — does it run on a range of PC hardware (low-end laptop to high-end), windowed/fullscreen, keyboard and controller, common resolutions?

## What gets tested

- **Core raid loop:** stealth detection, noise/alert behavior, combat, loot weight, dawn timer, escape, death/capture handling.
- **Procedural generation:** every generated raid is **completable** (reachable loot and exit), readable, and not degenerate. This needs automated validation, not just manual play.
- **Warren systems:** building, job assignment, resource production, upgrades, recruiting.
- **Progression & economy:** meta-progression persists correctly across goblin deaths; resource sinks/sources stay balanced.
- **Save/load:** no corruption, no lost progress, sensible autosave.
- **Multiplayer (if/when built):** co-op sync, host migration/disconnects, no desyncs. *[TODO: expand when multiplayer scope is confirmed.]*

## Playtest cadence & capturing feedback

- **Weekly self-playtest** with a short written note: what felt good, what dragged, what confused you.
- **Friends-and-family builds** at the vertical slice — watch people play *without helping them*; silence reveals the most.
- **Wider playtests** at alpha/beta via itch.io builds, a Discord/Steam playtest, or a focused tester group.
- **Capture methods:** an in-game feedback key, a simple form, recorded sessions where possible, and (later) lightweight analytics on raid outcomes, deaths, and where players quit.
- Tag every piece of feedback as **fun/design**, **bug**, or **balance** so it routes to the right backlog.

## Bug triage & severity levels

| Severity | Definition | Response |
|----------|------------|----------|
| **S1 — Blocker** | Crash, save corruption, unwinnable/softlocked raid | Fix before any release build |
| **S2 — Major** | Core feature broken or badly degraded | Fix before the milestone ships |
| **S3 — Minor** | Noticeable but has a workaround | Schedule into a normal cycle |
| **S4 — Polish** | Cosmetic, rare, low impact | Backlog; fix opportunistically |

Track bugs on the same board as features, labeled by severity. Commit fixes with Conventional Commits (e.g. `fix: prevent softlock when exit spawns behind locked gate`).

## Release / readiness criteria

A build is releasable when:

- Zero open **S1** bugs and no known **S2** bugs in core loops.
- A new player can reach and understand the core loop without external help.
- Procedural raids pass automated solvability validation across a large sample.
- Save/load is reliable across update boundaries (don't break existing saves).
- Performance holds 60 FPS on the target low-end machine.
- *(No console certification needed — PC-only. If a console port is ever pursued, add platform cert criteria here.)*
