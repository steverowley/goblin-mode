# Goblin Mode — Technical Design Document

*For the engineering side of the project (you, plus any future collaborators). Plain-language where possible. Deep specifics are marked `[TODO]` to confirm during the prototype.*

## Target engine & rationale

**Recommendation: Godot 4 (with GDScript, optionally C#).**

Why Godot for this project:
- **Free and open-source** — no royalties, ideal for a solo premium release.
- **Excellent 2D pipeline** — first-class support for pixel art, tilemaps, and 2D lighting, which is exactly what a 2D pixel roguelike needs.
- **Lightweight and fast to iterate** — short edit-test cycles matter a lot when you're playtesting "is this fun?" daily.

Strong alternative: **Unity** — bigger asset store and more tutorials, which can speed up a solo dev, at the cost of licensing complexity and a heavier editor. **Avoid Unreal** here — it's overkill for 2D pixel art. *[TODO: build the same tiny movement prototype in Godot and Unity for a day each, then commit to one.]*

## Platform & performance targets

- **Primary:** Windows PC (Steam). Godot also exports to Linux and macOS cheaply later.
- **Performance:** comfortably 60 FPS on a modest laptop (integrated graphics). Pixel-art 2D makes this very achievable; the main cost will be lots of on-screen agents (goblins + guards) and pathfinding, not graphics.
- **Resolution:** render at a low pixel-art base resolution, scale up cleanly to common monitor sizes.

## Core systems architecture

Think of the codebase as a few cooperating systems:

- **Game state / mode manager** — switches between the **Warren (day)** scene and the **Raid (night)** scene and carries data between them (loot earned, goblins alive).
- **Warren simulation** — rooms, job assignments, resource production ticking over time. A relatively simple state machine + timers.
- **Raid generator** — assembles procedural levels from hand-authored tile "chunks" per biome, places loot, guards, and exits with difficulty parameters.
- **Goblin/agent system** — shared stats, traits, inventory, and AI hooks used by both player goblins and (with different brains) guards.
- **Stealth & alert system** — line-of-sight, noise propagation, and a town-wide alert level that escalates AI behavior.
- **Economy & progression** — resources, upgrades, meta-progression that persists across goblin deaths.
- **UI layer** — separate, data-driven HUD (raids) and management UI (warren).

A clean split between the day and night scenes is the most important architectural decision — keep them loosely coupled and pass a small, well-defined "save state" object between them.

## Save system & data

- **Single persistent save** capturing warren state, roster of living goblins (with traits/gear), resources, and unlocks.
- Roguelike runs (raids) are transient — only the **banked result** of a raid writes to the save, on successful escape.
- Use a simple serialized format (Godot resources or JSON). Save on return-to-warren and on quit. *[TODO: decide autosave cadence and whether to allow mid-raid saving — generally roguelikes don't.]*

## Networking (multiplayer is in scope)

This is the highest-effort, highest-risk part of the project for a solo dev. Recommended phasing:

- **Phase 1:** ship single-player only. Build all systems "network-aware" in structure but don't implement netcode yet.
- **Phase 2:** add **co-op raids** first (2–4 players, one host) using Godot's high-level multiplayer API or a service like Steam's networking. Co-op is more forgiving than competitive.
- **Phase 3 (optional / post-launch):** competitive "rival warren." Strongly consider making this **asynchronous** (you raid a snapshot of a rival's warren) to avoid hard real-time sync problems.

**Recommendation:** treat multiplayer as a post-vertical-slice, post-single-player goal. Do not let it block proving the core loop is fun. *[TODO: confirm whether multiplayer is launch-critical or a fast-follow — this single decision drives much of the schedule.]*

## Third-party tools & middleware

- **Art:** Aseprite (pixel art + animation).
- **Audio:** a free DAW (e.g. Reaper/LMMS) + sfxr/Bfxr for retro SFX.
- **Version control:** Git + a remote (GitHub/GitLab), with Git LFS for art assets.
- **Project tracking:** a lightweight board (e.g. a Trello/Notion/GitHub Projects kanban).
- **Steam:** Steamworks SDK for store, achievements, and (later) networking.
- Commit using **Conventional Commits** (e.g. `feat: add noise meter to raid HUD`, `fix: guard pathfinding stuck on doors`) to keep history readable.

## Key technical risks

| Risk | Why it matters | First mitigation |
|------|----------------|------------------|
| Procedural generation feels samey or breaks | The raid layer is half the game | Hand-author strong chunks; validate every generated level is solvable |
| Stealth AI is the hardest thing to get "feeling fair" | Core to the fun | Prototype guard line-of-sight/noise early, before content |
| Multiplayer netcode scope explosion | Classic solo-dev trap | Defer it; ship single-player first; co-op before competitive |
| Performance with many agents | Lots of goblins/guards + pathfinding | Cap agent counts; use efficient navigation; profile early |
| Engine choice regret | Switching later is expensive | Two-day bake-off before committing (see above) |
