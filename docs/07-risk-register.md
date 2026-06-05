# Goblin Mode — Risk Register

*The honest list of what could go wrong, and what to do about it. For a solo, no-deadline project the biggest risks are scope and motivation, not technology. Revisit this at every milestone review.*

| # | Risk | Likelihood | Impact | Mitigation | Owner |
|---|------|------------|--------|------------|-------|
| 1 | **Scope creep / feature bloat** — the day/night + roguelike + sim + multiplayer combo is ambitious for one person | High | High | Ruthlessly protect the vertical slice; keep a "cut list"; defer multiplayer and extra biomes until the core is proven | You |
| 2 | **Core loop isn't fun in playtests** — sneaking/raiding doesn't land | Medium | High | Prototype the raid first and gate full production on a fun vertical slice; be willing to redesign or stop | You |
| 3 | **Solo motivation / burnout** — no deadline can mean no momentum, or grinding yourself out | High | High | Weekly playable build + devlog for visible progress; small milestones; allow breaks; share builds for encouraging feedback | You |
| 4 | **Multiplayer netcode swallows the project** — classic solo-dev trap | High | High | Ship single-player first; build co-op before competitive; consider async competitive; treat MP as post-launch if needed | You |
| 5 | **Procedural generation feels repetitive or breaks** | Medium | High | Strong hand-authored chunks; automated solvability checks; biome variety; tune via playtests | You |
| 6 | **Art/audio pipeline bottleneck** — one person can't produce all assets fast enough | Medium | Medium | Lean on tools (Aseprite, Bfxr) and asset stores; budget a contractor for a pre-launch polish pass | You |
| 7 | **Stealth AI feels unfair or exploitable** | Medium | Medium | Prototype guard sight/noise early; extensive balance playtesting; clear feedback so players understand detection | You |
| 8 | **Market crowding** — many roguelikes and management sims compete for attention | Medium | Medium | Lean hard into the distinct "goblin mode" hook and comedic tone; build a Steam wishlist/devlog audience early | You |
| 9 | **Monetization underperforms** — premium indie sales are unpredictable | Medium | Medium | Strong store page + trailer + demo; consider Early Access for runway and feedback; keep production costs low | You |
| 10 | **Engine choice regret** — switching engines mid-project is very costly | Low | High | Two-day Godot/Unity bake-off before committing; don't switch after the prototype without a hard reason | You |
| 11 | **Save-system bugs corrupt progress** — especially damaging given persistent warren | Low | High | Robust serialization, autosave + backups, test save/load across updates so patches don't break saves | You |
| 12 | **Tone misfires** — "goblin mode" humor reads as crude or off-putting | Low | Medium | Keep it mischievous not mean-spirited; test the comedy with playtesters; iterate on writing/animation | You |

## How to use this register

Re-score likelihood and impact at each milestone review. Anything that becomes **High/High** gets an explicit plan or a scope cut *that cycle*. The top three to watch from day one are **#1 scope creep, #3 burnout, and #4 multiplayer** — those sink more solo projects than any technical problem.
