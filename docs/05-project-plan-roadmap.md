# Goblin Mode — Project Plan / Roadmap

*Solo developer, no fixed deadline, Agile/iterative. Durations below are rough and assume part-time-to-full-time solo effort; adjust to your real availability. The point isn't to hit exact dates — it's to always know the next meaningful milestone.*

## Why Agile/iterative for this game

You don't yet know if the core loop is fun — nobody does until it's playable. So you build in short cycles, playtest constantly, and let the design evolve. Waterfall (plan everything, then build) only fits fixed-scope, fixed-deadline work — the opposite of an exploratory solo roguelike.

## Milestones

Game-dev milestones, ordered. The **Vertical Slice** is the single most important one — it's the moment you find out whether the game is worth making.

| Milestone | What "done" means | Rough duration |
|-----------|-------------------|----------------|
| **0. Engine bake-off** | Tiny movement prototype in Godot (and optionally Unity); engine chosen | ~1–2 weeks |
| **1. Prototype** | Ugly-but-playable single raid: move, sneak, grab loot, get caught, escape. Tests "is sneaking around as a goblin fun?" | ~4–8 weeks |
| **2. Vertical Slice** | One polished warren room + one full raid on one biome + death/respawn loop, end to end, genuinely fun. The go/no-go gate. | ~2–4 months |
| **3. Alpha** | All core systems present but rough: warren management, 2–3 biomes, progression, "goblin mode," economy. Content not final. | ~3–6 months |
| **4. Beta** | Feature-complete single-player. Co-op raids in if pursued. Balancing, polish, bug-fixing, full content pass. | ~3–6 months |
| **5. Launch (Steam)** | Store page, trailer, Early Access or 1.0, marketing beats. | ~1–2 months run-up |

*Total is deliberately open-ended given "no fixed deadline." Treat each milestone as a checkpoint to decide whether to continue, pivot, or cut scope.*

## Phase breakdown

1. **Pre-production (Milestones 0–1).** Prove the core raid is fun. Resist building the warren, content, or multiplayer until sneaking-and-stealing feels good on its own.
2. **Vertical slice (Milestone 2).** Make one tiny piece genuinely polished and fun. **Hard gate:** if it isn't fun here, fix the design or stop — don't scale up an unfun loop.
3. **Production (Milestones 3–4).** Build breadth: biomes, goblin traits, rooms, economy balance, and (if pursued) co-op. Playtest every cycle.
4. **Launch (Milestone 5).** Polish, marketing, release. Strongly consider **Steam Early Access** — well-suited to roguelikes and to a solo dev who benefits from player feedback and early revenue.

## Team & roles

Solo — you wear every hat. Realistic mitigations: lean on the asset/audio store and tools (Aseprite, Bfxr) to cover gaps; consider a contract artist or composer for a polish pass before launch. `[TODO: decide which one discipline (art vs. audio vs. code) to outsource if budget allows.]`

| Role | Who | Notes |
|------|-----|-------|
| Design | You | GDD owner |
| Programming | You | Godot/GDScript |
| Art | You (+ possible contractor) | Aseprite pixel art |
| Audio | You (+ possible contractor) | SFX + music |
| QA / playtesting | You + recruited players | See QA Plan |
| Marketing | You | Steam page, devlog, socials |

## Dependencies

- Engine choice (M0) blocks everything technical.
- Core raid prototype (M1) must validate fun **before** warren/content investment.
- Vertical slice (M2) gates full production.
- Single-player core must be solid **before** any multiplayer work begins.
- Steam page + trailer depend on having presentable footage (earliest from the vertical slice).

## Key dates

No fixed deadline. Recommended cadence instead of dates:

- **Weekly:** a playable build + short devlog note to yourself.
- **Per milestone:** a go/no-go review against the question "is this still fun and worth continuing?"
- `[TODO: if you later set a target launch window or Early Access date, backfill real dates here.]`
