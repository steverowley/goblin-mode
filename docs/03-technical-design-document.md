# Goblin Mode — Technical Design Document

*For the engineering side of the project (you, plus any future collaborators). Plain-language where possible. Deep specifics are marked `[TODO]` to confirm during the prototype.*

## Target engine & rationale

**DECISION: Godot 4 + GDScript, locked unless a hard blocker appears in the prototype.** (See [decisions log](00-decisions-log.md).)

Why Godot for this project:
- **Free and open-source** — no royalties, ideal for a solo premium release.
- **Excellent 2D pipeline** — first-class support for pixel art, tilemaps, and 2D lighting, which is exactly what a 2D pixel roguelike needs.
- **Lightweight and fast to iterate** — short edit-test cycles matter a lot when you're playtesting "is this fun?" daily.

Unity was the runner-up (bigger asset store, more tutorials) but loses on licensing complexity and a heavier editor; Unreal is overkill for 2D pixel art. The choice is made — **Milestone 0 is a one-day Godot smoke test** (confirm tooling installs, a project runs, and 2D lights work on the target machine), **not** a Godot-vs-Unity bake-off.

## Platform & performance targets

- **Primary:** Windows PC (Steam). Godot also exports to Linux and macOS cheaply later.
- **Performance:** comfortably 60 FPS on a modest laptop (integrated graphics). Pixel-art 2D makes this very achievable; the main cost will be lots of on-screen agents (goblins + guards) and pathfinding, not graphics.
- **Resolution:** render at a low pixel-art base resolution, scale up cleanly to common monitor sizes.

## Perspective (and what it commits us to)

**Top-down (three-quarter / 3-4 oblique view), LOCKED.** The prototype confirms it; it is not "to be discovered." Everything technical below assumes this single camera convention, and several systems get *simpler* because of it:

- **Line-of-sight is 360°.** On a top-down map a guard can be approached from any direction, so stealth is "am I in this guard's vision cone / am I lit?" computed in 2D space — not a side-on "is something in front of me?" Sneaking behind a guard is a real, readable tactic.
- **Navigation is a flat 2D grid.** No jumping, no platforming, no z-layers to reconcile — agents path across one walkable tile grid (see [Navigation](#navigation-astargrid2d)). This is the main reason the nav and noise systems can share a graph.
- **Lighting is a 2D top-down field.** Lamps cast pools of light on the floor plane; "lit-ness" is a property of a tile/position, not a 3D volume (see [2D lighting as gameplay](#2d-lighting-as-gameplay)).
- **Sprites need facings, not depth.** Goblins are ~32×32 on a low pixel-art base canvas (lock the exact size in the prototype) and are authored with directional facings (e.g. 4- or 8-way) rather than a single profile view — note this for the art pipeline.

## Core systems architecture

Think of the codebase as a few cooperating systems:

- **Game state / mode manager** — switches between the **Warren (day)** scene and the **Raid (night)** scene and carries data between them (loot earned, goblins alive).
- **Warren simulation** — rooms, job assignments, resource production ticking over time. A relatively simple state machine + timers.
- **Raid generator** — assembles procedural levels from hand-authored tile "chunks" per biome, places loot, guards, and exits with difficulty parameters.
- **Goblin/agent system** — shared stats, traits, inventory, and AI hooks used by both player goblins and (with different brains) guards.
- **Stealth & alert system** — line-of-sight, noise propagation, and a town-wide alert level that escalates AI behavior.
- **Economy & progression** — resources, upgrades, meta-progression that persists across goblin deaths.
- **UI layer** — separate, data-driven HUD (raids) and management UI (warren).

A clean split between the day and night scenes is the most important architectural decision — keep them loosely coupled and pass a small, well-defined "save state" object between them (see [Day/night scene swap](#daynight-scene-swap-the-gamestate-contract)).

### Agent design: composition over inheritance

*Composition over inheritance* means: instead of one giant `Goblin` class that everything inherits from (which tangles guard logic, player logic, and trait logic into one file), an **Agent** is a thin shell that you bolt small, optional parts onto. This keeps each piece testable and stops "add a trait" from meaning "touch core agent code."

- A thin **Agent** (a `CharacterBody2D`) hosts optional **component nodes**: `HealthComponent`, `MovementComponent`, and a `Senses` component (line-of-sight, hearing, noise emission).
- Plus a pluggable **Brain** that decides what the agent does: `PlayerControlledBrain` for your goblin, `GuardBrain` for the tall folk. Swapping the brain is how the same body becomes a player or an enemy.
- Stats live in a shared **StatBlock** resource (read-only authored data). **Traits are data resources** that register behaviour modifiers, so adding a trait never edits the core agent.
- **M1 seam test:** reuse the *same* `Senses`/noise component for both the player goblin and the first guard. If one component serves both, the seam is proven.

## Save system & data

- **Single persistent save** capturing warren state, roster of living goblins (with traits/gear), resources, and unlocks.
- Roguelike runs (raids) are transient — only the **banked result** of a raid writes to the save, on successful escape.
- **Format: versioned JSON** (or `FileAccess` `store_var` with object support *disabled*) for ALL mutable player state. Every save carries a `schema_version` field, and we keep small **migration** functions that upgrade an old save to the current shape on load. This matters because the save format *will* change as the game grows — migrations mean a player's warren survives updates instead of corrupting.
- Use Godot **Resources only for read-only authored content** (tile chunks, trait definitions, stat blocks) — **never** for save files. Resources can execute code on load and are brittle across updates, which makes them unsafe and fragile for player data.
- **Autosave on phase boundaries** (end of day → raid, return from raid → warren, and on quit). **Plus** a single-slot, resumable **mid-raid "suspend save"** so you can stop a raid and come back — but it is **deleted the instant a raid resolves** (escape or death). That keeps it crash-safe without becoming a save-scum loophole: there's no live mid-raid save to reload after a bad outcome.
- **Test it from day one** — a save round-trip test (write → read → identical) plus a migration test that loads fixtures from older `schema_version`s (see [Automated testing](#automated-testing)).

## Networking & multiplayer

**Single-player at launch; co-op raids planned as a post-1.0 fast-follow; competitive "rival warren" is cut.** (See [decisions log](00-decisions-log.md).) Netcode is the classic solo-dev scope explosion, so we are not building it for launch — and, importantly, **not** building systems speculatively "network-aware" up front. Trying to make everything multiplayer-ready before you have a fun single-player game is a known trap that slows every system down for a feature that may never ship.

Instead we pay **one cheap architectural seam** now, and nothing more:

- **Keep raid logic in a self-contained scene driven by an injected controller object.** The raid scene doesn't reach out for "the keyboard" itself; it's *handed* a controller that supplies commands. Today that controller reads local input. Later, a networked controller could feed the same commands from a remote player — without rewriting the raid. (This is the same `Brain` seam from [Agent design](#agent-design-composition-over-inheritance): the raid scene cares about *commands*, not *where they came from*.)
- **Keep simulation out of visual `_process` code.** Game state (positions, alerts, noise, economy) advances in its own update path, separate from the per-frame drawing code. Mixing the two is what makes a game impossible to network (or even to pause/test) later; keeping them apart is good practice regardless.

That's the whole investment. If co-op happens after 1.0, the plan is the gentler version first: **co-op raids** (2–4 players, one host) using Godot's high-level multiplayer API or Steam's networking. Competitive play is explicitly out of scope.

## Third-party tools & middleware

- **Art:** Aseprite (pixel art + animation).
- **Audio:** a free DAW (e.g. Reaper/LMMS) + sfxr/Bfxr for retro SFX.
- **Version control:** Git + a remote (GitHub/GitLab), with Git LFS for art assets.
- **Project tracking:** a lightweight board (e.g. a Trello/Notion/GitHub Projects kanban).
- **Steam:** Steamworks SDK for store, achievements, and (later) networking.
- Commit using **Conventional Commits** (e.g. `feat: add noise meter to raid HUD`, `fix: guard pathfinding stuck on doors`) to keep history readable.

## Stealth deep-dive: line-of-sight, noise, and light

These three systems are the heart of "is the stealth fair?", so they get spelled out. All assume the locked top-down perspective. Prototype line-of-sight, noise, and light together in **M1**, before any content.

### Noise propagation

Stealth isn't only "can a guard see me?" — it's "did a guard *hear* me?" The model is:

- The game emits discrete **noise events** — a footstep, dropped loot, a broken pot — each carrying a **loudness** value.
- Loudness **propagates along navigation-graph distance** (we reuse the same `AStarGrid2D` as pathfinding, see below), **attenuated by walls and doors**. The effect: sound rounds corners and travels down corridors, but is muffled through a wall — which is how a player intuitively expects it to work.
- A guard **investigates** when the loudness reaching it exceeds **that guard's hearing threshold**. Because the threshold is per-agent, we get traits like *Light Sleeper* (a guard that wakes/investigates at a lower loudness) for free.
- The player gets **clear feedback**: a HUD noise meter plus a brief visual "ping" at the source, so a botched-stealth death reads as earned.

### 2D lighting as gameplay

Light is a stealth mechanic (stay in shadow), so we run **two parallel, intentionally-correlated systems**: what the player *sees*, and what the AI *uses*. They must agree, but they are computed separately.

- **Gameplay "lit-ness" is computed analytically on the CPU.** Each lamp is a plain data object (position, radius, occlusion). A goblin's **exposure** = the sum of unobstructed light sources reaching it, found with a few raycasts against occluders using `PhysicsDirectSpaceState2D` (Godot's 2D physics ray-casting). This number is what guards and the stealth system read.
- **The visuals (`Light2D`) are authored to MATCH the data lamps**, so what the player sees on screen equals what the AI is reacting to. Place a visual lamp, place a matching data lamp at the same spot/radius.
- **Do NOT read the framebuffer for gameplay.** `Light2D` is rendering-only — trying to sample the rendered image to ask "is this pixel lit?" is slow and unreliable. The CPU light model is the source of truth; the renderer just draws a matching picture.

This "two correlated systems" approach is a deliberate seam and a known footgun if they drift apart, so it's on the [risk register](#key-technical-risks); prototype it in M1.

### Navigation (`AStarGrid2D`)

Use **`AStarGrid2D`** (Godot's built-in grid pathfinder) over the raid's **single, unified global tile grid** — not a separate navmesh per chunk. This one choice pays off three ways:

- It **sidesteps navmesh "seam-stitching"** — the fiddly problem of joining each chunk's navigation mesh to its neighbour's at the join.
- **Opening a door is a one-cell solidity toggle** — flip that cell from blocked to walkable and paths update; no special-case door logic in the pathfinder.
- The **same grid is reused** by the noise model (above) and the solvability check (below), so we maintain one representation of "what's walkable," not three.

Bake **walkable cells + door cells** into the chunk file format. Add a test that agents can **path across every chunk-to-chunk seam** (the join between two stitched chunks is the most likely place for a "stuck" bug).

## Performance: agent budgets & the sim tick

The graphics are cheap; the cost is *thinking* agents and pathfinding. Two budgets keep us at 60 FPS:

- **Raid: ≤ ~20–30 active *alertable* agents.** Run full line-of-sight/noise only for guards that are **awake and nearby**; a sleeping or distant guard costs almost nothing.
- **Warren: dozens of job-goblins on a SLOW sim clock (~2–4 Hz, not per-frame).** A goblin hauling ore doesn't need 60 decisions a second; ticking the warren a few times a second is invisible to the player and a fraction of the cost.

Supporting techniques: **time-sliced / staggered AI updates** (don't update every agent on the same frame), **object pooling** (reuse agent/effect objects instead of constantly creating and destroying them), and **a single warren-economy tick decoupled from render framerate**.

**Exit test:** "holds 60 FPS at the stated budget on the target low-end machine (integrated graphics)" is a measurable **M2/Alpha exit test**, not a vibe.

## Day/night scene swap: the GameState contract

Switching between Warren (day) and Raid (night) is handled by a **`GameState` autoload** (a single always-loaded script Godot keeps in memory). The contract is strict and pays off twice:

- **It holds ONLY serializable data** — the living-goblin roster *as data*, resources, unlocks, the chosen target parameters — and **never live scene-node references.** Because it's pure data, the same object **doubles as the save payload** (see [Save system & data](#save-system--data)). If it can't be saved to JSON, it doesn't belong in `GameState`.
- **Generate the raid + swap scenes asynchronously.** Use `ResourceLoader.load_threaded_request` (Godot's background loader) behind a *"descending into the town…"* loading screen, so the game doesn't freeze while a level builds.
- **Free the warren scene before generating the raid** (and vice versa) so only one big scene is in memory at a time — this keeps memory flat on integrated graphics.

## Automated testing

A solo dev can't manually re-test everything every build, so a small automated safety net is worth it from early on.

- **Unit tests with GUT or gdUnit4** (the two common Godot test frameworks) for the logic-heavy, easy-to-break pieces: agent/component behaviour, economy math, and save logic.
- **Save round-trip + migration test:** write a save, read it back, confirm it's identical; and load fixture saves from prior `schema_version`s to confirm migrations still work (see [Save system & data](#save-system--data)).
- **Headless solvability validator (Alpha deliverable).** Once raids are procedurally generated, a script run under `godot --headless` (no window, suitable for CI) checks large **batches of seeds** and **fails CI on any unsolvable layout.** It does **graph reachability from the spawn that respects locked-door/key dependencies** — treat a key as an edge that unlocks a region — to confirm: spawn → every required objective → at least one exit. Optionally it checks a lower-bound traversal time against the dawn timer. On failure it **rerolls (with a hard attempt cap) and falls back to a known-good authored layout**, so a bad seed never blocks gameplay.
- **Phasing:** stand up a **placeholder test + a headless seed-batch script during M1/M2**; schedule the **full validator as an Alpha deliverable.** It is *not* needed for the vertical slice, whose single hand-built level is trivially solvable.

## Key technical risks

| Risk | Why it matters | First mitigation |
|------|----------------|------------------|
| Procedural generation feels samey or breaks | The raid layer is half the game | Hand-author strong chunks; [headless solvability validator](#automated-testing) fails CI on any unsolvable layout |
| Stealth AI is the hardest thing to get "feeling fair" | Core to the fun | Prototype guard line-of-sight/noise early, before content |
| Visual light and gameplay "lit-ness" drift apart | Players would be punished for shadows they can't see | Two correlated systems; author `Light2D` to match the CPU light data; prototype both in M1 (see [2D lighting](#2d-lighting-as-gameplay)) |
| Multiplayer netcode scope explosion | Classic solo-dev trap | Single-player at launch; do NOT build "network-aware"; pay only the one injected-controller seam (see [Networking](#networking--multiplayer)) |
| Performance with many agents | Lots of goblins/guards + pathfinding | Per-scene agent budgets, slow warren tick, object pooling; 60 FPS exit test (see [Performance](#performance-agent-budgets--the-sim-tick)) |
| Engine choice regret | Switching later is expensive | Engine is locked to Godot 4 — don't switch after the prototype without a hard, demonstrated blocker |
