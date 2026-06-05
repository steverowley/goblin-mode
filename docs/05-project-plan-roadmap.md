# Goblin Mode — Project Plan / Roadmap

*Solo developer, Agile/iterative. Durations below are rough and assume part-time-to-full-time solo effort; adjust to your real availability. The point isn't to hit exact dates — it's to always know the next meaningful milestone. Treat this whole document as a living hypothesis: revise it constantly as the prototype teaches you what's true. Key resolved choices link to [the decisions log](00-decisions-log.md).*

**Soft target:** a playable **Early Access** build within **~12 months of full-effort work**. This is a direction, not a promise — see the time-box rule below.

**Time-box rule (cut, don't extend):** every milestone has a "high" estimate. **If any milestone exceeds its high estimate, the next review must CUT scope, not extend the timeline.** A solo project dies by quietly slipping deadlines; it survives by shipping a smaller thing. The [cut-list](#cut-list-living) below is where deferred scope goes to wait.

## Why Agile/iterative for this game

You don't yet know if the core loop is fun — nobody does until it's playable. So you build in short cycles, playtest constantly, and let the design evolve. Waterfall (plan everything, then build) only fits fixed-scope, fixed-deadline work — the opposite of an exploratory solo roguelike.

## Milestones

Game-dev milestones, ordered. The **Fun Probe (M0.5)** and the **Vertical Slice (M2)** are the two that matter most — they're the moments you find out whether the game is worth making, before you've spent real money or months of art.

| Milestone | What "done" means | Rough duration |
|-----------|-------------------|----------------|
| **0. Engine smoke test** | One-day check that the tooling installs and 2D lights work in Godot 4. Confirm, don't deliberate. | ~1 day |
| **0.5. Fun Probe** | The cheapest possible test that the core *feels* good: one hand-built room, one goblin, move/sneak/grab/noise, 1–2 guards, an exit, a dawn timer. No art, no warren. **Hard bar to pass:** a stranger plays ~10 minutes and *wants another go*. | ~1–2 weeks |
| **1. Prototype** | Ugly-but-playable single raid that layers the real systems (line-of-sight, [noise propagation](03-technical-design-document.md), analytic gameplay lighting, the [agent/brain seam](03-technical-design-document.md)) onto the Fun Probe. Still one hand-built level. | ~4–8 weeks |
| **2. Vertical Slice** | **One** hand-built level, fully realised: the Recruitment/Breeding Den room + one full Farmlands raid + the death/respawn loop, end to end, genuinely fun. **The go/no-go gate** — and where the Early Access decision is made. | ~3–6 months |
| **3. Alpha** | All core systems present but rough: warren management, **procedural raid generation + the [solvability validator](06-test-qa-plan.md)**, 2 biomes, progression, "Goblin Mode," soft economy, the "Capital" victory wall + endless/legend hooks. Content not final. | ~3–6 months |
| **4. Beta** | Feature-complete single-player at the [launch content caps](#launch-content-caps). Balancing, polish, bug-fixing, full content pass. (Co-op is **not** here — it's a post-1.0 fast-follow.) | ~3–6 months |
| **5. Launch (Steam)** | Store page, trailer, the [Next Fest demo](#demo-next-fest), Early Access or polished 1.0, marketing beats. | ~1–2 months run-up |

*Total is deliberately open-ended, but anchored by the ~12-month soft Early-Access target above. **Every milestone is a continue / pivot / cut checkpoint** — and per the time-box rule, an overrun triggers a cut, never a quiet extension.*

> **Why M0 shrank.** Godot 4 + GDScript is locked unless a hard blocker appears in the prototype, so there's no engine bake-off to run — M0 is a one-day sanity check, not a week-long Godot-vs-Unity comparison. Unity stays a single sentence: it was considered and set aside; don't reopen it without a hard reason (see [risk register](07-risk-register.md), risk #10). The reclaimed week goes into the Fun Probe. *(See [decisions log](00-decisions-log.md): Engine.)*

## Milestone 0.5 — the "Fun Probe"

A *vertical slice* (M2) is expensive: it proves a polished piece is fun. But there's a cheaper question to answer first — *is the raw core loop even worth polishing?* The Fun Probe answers that for almost nothing.

**What it is:** one hand-built room, one goblin you control, the four verbs (move / sneak / grab / make-noise), 1–2 guards, an exit, and a dawn timer counting down. Placeholder shapes for everything. The very first thing to tune here is the **loot / weight / timer triangle** (see [game design doc](02-game-design-document.md)) — that's the first balance question of the whole project.

**The hard success bar:** *a stranger plays for ~10 minutes and wants another go — with zero art and zero warren.* If that doesn't happen, the loop needs rethinking before anything else gets built.

**What is explicitly NOT in the Fun Probe** (resisting these is the point):

- No warren, no warren management, no economy or upkeep.
- No procedural generation — it's one hand-built level.
- No goblin traits, no roster, no permadeath consequences.
- No "Goblin Mode" frenzy.
- No save/load.
- No art beyond placeholder shapes.

Carrying this discipline forward: **the entire vertical slice uses ONE hand-built level.** Procedural generation *and* the [solvability validator](06-test-qa-plan.md) (the automated check that a generated level is actually finishable) are deferred to **Alpha** — the slice's hand-built level is trivially solvable, so neither is needed to find out if the game is fun. *(See [decisions log](00-decisions-log.md): Vertical slice.)*

## Phase breakdown

1. **Pre-production (Milestones 0 – 1).** Prove the core raid is fun, cheaply. Run the one-day engine smoke test, then the Fun Probe, then layer the real systems into the Prototype. Resist building the warren, content, or anything multiplayer-shaped until sneaking-and-stealing feels good on its own.
2. **Vertical slice (Milestone 2).** Make one hand-built level genuinely polished and fun, end to end. **Hard gate — the gate question is "is it FUN?", not "are the features in?"** If it isn't fun here, fix the design or stop; don't scale up an unfun loop. **Two decisions are made AT this gate:** (a) go / no-go on full production, and (b) Early Access vs polished 1.0 (see [Launch model](#launch-model-early-access-vs-10)). Marketing also starts here as a parallel track (see [Go-to-market](#go-to-market)).
3. **Production (Milestones 3 – 4).** Build breadth up to the [launch content caps](#launch-content-caps): the second biome, the trait set, rooms, procgen + solvability, economy balance, the endgame wall. Single-player only; co-op is post-1.0. Playtest every cycle.
4. **Launch (Milestone 5).** Polish, marketing, release. **Early Access is the default plan** (see below) — well-suited to roguelikes and to a solo dev who benefits from player feedback and early revenue.

## Team & roles

Solo — you wear every hat. Lean on tools (Aseprite for pixel art, Bfxr for sound effects) to cover gaps.

**Outsourcing — decided:** spend **nothing** on contractors until the **M2 go/no-go gate** clears. Once it does, the first money goes into **art**, not audio or code, because art is the production bottleneck and the top commercial lever. The recommended first spend is a small **paid pre-production art package** — a mood board, a master colour palette, and key/capsule art (the "box art" Steam shows in the store) — which you then self-produce *in-style* from. **Keep audio in-house** (Bfxr + library music). This re-scores the art-bottleneck risk to **High / Medium** (see [risk register](07-risk-register.md), risk #6). *(See [decisions log](00-decisions-log.md): Outsourcing.)*

| Role | Who | Notes |
|------|-----|-------|
| Design | You | GDD owner |
| Programming | You | Godot 4 / GDScript |
| Art | You (+ paid pre-production package post-M2) | Aseprite pixel art, produced in-style |
| Audio | You | SFX (Bfxr) + library music — in-house |
| QA / playtesting | You + recruited players | See [Test / QA Plan](06-test-qa-plan.md) |
| Marketing | You | Steam page, devlog (YouTube + TikTok Shorts), Discord — parallel track from M2 |

## Dependencies

- The Fun Probe (M0.5) must clear its "stranger wants another go" bar **before** the real systems get layered into the Prototype.
- The Prototype (M1) must validate fun **before** any warren/content investment.
- The Vertical Slice (M2) gates full production **and** the Early Access decision **and** the start of marketing.
- **Single-player at launch; co-op raids are a planned post-1.0 fast-follow; competitive "rival warren" is cut.** So co-op depends on a shipped, solid single-player game — it is *not* a launch dependency. Do **not** build systems speculatively "network-aware" (a known solo-dev trap). Pay exactly one cheap seam: keep raid logic in a self-contained scene driven by an injected controller object (local input now, networkable later) and keep simulation out of visual `_process` code. (See [technical design doc](03-technical-design-document.md) for the seam; [decisions log](00-decisions-log.md): Multiplayer.)
- Steam page + trailer depend on presentable footage — earliest a 15-second clip + key art from the vertical slice (M2).
- The [Next Fest demo](#demo-next-fest) depends on the slice being stable enough to hand to strangers unattended.
- No contractor spend until M2 clears (see Team & roles).

## Launch model — Early Access vs 1.0 {#launch-model-early-access-vs-10}

**This is an explicit decision item, made AT the M2 go/no-go gate — not now.** The default is **Early Access** (shipping a smaller, genuinely-fun-but-unfinished game to paying players, then updating it over months). EA is well-suited to roguelikes and to a solo dev who benefits from player feedback and early revenue.

**The condition:** Early Access is the default launch plan, **contingent on a sustainable ~monthly update cadence**. If at the M2 gate you don't believe you can keep up a roughly-monthly stream of updates, the fallback is a **polished 1.0** instead. *(See [decisions log](00-decisions-log.md): Early Access.)*

> The launch model also interacts with the financial goal (below): a passion project that just needs to recoup costs can take the polished-1.0 path; an income-replacing target leans harder on EA's earlier revenue and longer tail.

## Launch content caps

To make "ship in ~12 months" real, the launch scope is **capped**. These are hard ceilings, not targets to exceed — anything beyond them is post-launch / EA content and goes on the [cut-list](#cut-list-living):

- **1 biome**, fully polished (Farmlands / humans). A **2nd biome is post-launch / EA content.**
- **~4 rooms** in the warren (the slice's room is the Recruitment / Breeding Den).
- **~8 goblin traits**, each one a *felt* active modifier on a raid (not passive spreadsheet math).
- **1 guard archetype + 1 patrol variant.**
- **1 goblin body**, with palette / accessory variation for visual variety.

The first vertical-slice content is a subset of these: the Den room, the Farmlands biome, and **4–6 traits** that each visibly change a raid. *(See [game design doc](02-game-design-document.md) for the trait/room detail; [decisions log](00-decisions-log.md): First-slice content.)*

## Demo (Steam Next Fest) {#demo-next-fest}

The demo is a **real, planned roadmap beat**, not just a marketing nicety — it's the marquee moment of the launch run-up. Plan **one** Steam Next Fest with a polished demo, and **release the demo 2–4 weeks before the Fest** so it accrues wishlists going in.

**QA readiness criterion (one line):** *a stranger can play the demo start-to-finish, unattended, with no crash and no soft-lock, and the build has survived a full [save round-trip + migration test](06-test-qa-plan.md).*

## Go-to-market

**Marketing is a parallel track that starts at M2 — not at M5.** Wishlists compound slowly; starting at launch is too late.

- **Wishlist target:** aim for **~20–30k wishlists pre-launch**, which historically supports a **~5k first-month sales floor**. (~7k wishlists is the rough threshold for Steam's "Popular Upcoming" list, a meaningful free-visibility boost.)
- **Store page:** go live as soon as the slice yields a **15-second clip + key art** (earliest at M2). The page itself is a wishlist-collection tool, so earlier is better.
- **The demo:** one Steam Next Fest with a polished demo as the marquee beat (see above). Note that **~68–88% of Next Fest wishlists come from people who never play the demo** — they wishlist off the trailer and capsule. That makes **capsule / key art quality a top-3 commercial lever**, which is exactly why the first contractor money goes into art (see Team & roles).
- **Devlog channels (named, not generic "socials"):** **YouTube + TikTok Shorts** for reach, plus a **Discord** for the core community. Post a short clip on a regular cadence from M2 onward.

## Budget & break-even

A short, honest money picture. **Price (planning anchor): $14.99 at 1.0 / $12.99 Early Access intro (re-confirm at store-page time).** **Estimated cash outlay:** the **Steam Direct fee ($100, one-time, recoupable)**, an **optional contractor art pass** (the pre-production package above — budget this only after M2), and **paid tools** (e.g. Aseprite, a one-time ~$20). **Net per copy:** Steam takes 30%, leaving **~$10.49** per sale at the $14.99 anchor (less at the $12.99 EA intro). **Break-even** on a no-contractor budget is therefore **low hundreds of sales**; with a modest contractor pass, **low thousands**.

**State the financial goal honestly, because it changes everything downstream** (the EA decision, the scope caps, and how much contractor spend is justified): is this a **passion project that just needs to recoup its costs**, or an **income-replacing** venture? For context on how hard the high end is: of the ~20,000 games released on Steam in 2025, only **~300 cleared $1M in revenue**. Plan for the passion-project floor; treat anything above it as upside. *(See [decisions log](00-decisions-log.md): Budget / break-even.)*

## Cut-list (living) {#cut-list-living}

The time-box rule sends scope *here*, not into the bin — this is a **living document**, revised every milestone review. When a milestone overruns its high estimate, the next review moves the lowest-priority in-scope item onto this list. Current contents (deferred, not abandoned):

- Co-op raids (post-1.0 fast-follow).
- Competitive "rival warren" mode (**cut**, not deferred).
- 2nd biome and beyond (post-launch / EA content).
- Procedural generation + solvability validator (deferred to Alpha).
- Any trait, room, guard, or body type beyond the [launch content caps](#launch-content-caps).

## Key dates / cadence

**No fixed calendar dates.** The plan is anchored by the **~12-month soft Early-Access target** and governed by the **time-box rule** (overrun → cut, don't extend), not by a Gantt chart. The working cadence:

- **Weekly:** a playable build + a short devlog note to yourself (and, from M2, a public clip on the [devlog channels](#go-to-market)).
- **Per milestone:** a continue / pivot / cut review against the question "is this still fun and worth continuing?" — and, on overrun, an explicit scope cut.
- **At M2 specifically:** the go/no-go gate plus the Early Access vs 1.0 decision.

If you later commit to a target launch window or a Next Fest month, backfill real dates here — but keep them subordinate to the cut rule.
