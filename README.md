# 👺 Goblin Mode

> Build a goblin warren by day, raid the humans' towns by night — a roguelike where you're the monster under the bed.

**Goblin Mode** is a 2D pixel-art roguelike sim for PC where embracing your inner gremlin is the whole point. By **day** you manage and grow a ramshackle goblin warren. By **night** you slip into the towns of the "tall folk" to steal, sabotage, and grab every shiny thing not nailed down — then barely escape before dawn. When a goblin dies on a raid, the warren lives on, and the next goblin grabs a rusty knife and takes their turn. The ownable hook is the **offence-side day/night inversion**: every other day/night game has you defending — here you're the monster doing the raiding. It ships **single-player at launch; co-op raids are planned as a post-1.0 fast-follow**.

> ⚠️ **Status: Pre-production.** This repo currently holds the planning docs. The game is not playable yet — follow along as it takes shape.

## ✨ The pitch

- **Day / night loop** — a calm base-building management layer feeds a tense, run-based raiding layer, so the game never gets monotonous.
- **A roster, not a hero** — you command a horde of characterful, expendable goblins instead of protecting one precious character.
- **"Goblin Mode" state** — a risk/reward frenzy: faster, stronger, greedier, far more likely to die a glorious death.
- **Personality-driven permadeath** — procedurally generated goblins with traits and names make every loss a tiny story.

**Closest comps.** The nearest *mechanical* comparison is **The Swindle** (a procgen stealth-heist roguelike — we study its known repetition problem as a design warning). **Goblin Stone** is a direct competitor we aim to out-position: more action and stealth, less turn-based tactics.

> 📣 *Press-only one-liner (not the store tagline):* "It's **Hades**' raid-and-return loop crossed with **RimWorld**'s colony management, wearing the grubby charm of **Goblin Stone** and **Overlord**."

## 🎮 At a glance

| | |
|---|---|
| **Genre** | Roguelike · RPG · Strategy/Sim |
| **Platform** | PC — Steam at launch; itch.io for early/playtest builds |
| **Players** | Single-player at launch; co-op planned post-1.0 |
| **Art style** | 2D pixel art |
| **Engine** | Godot 4 + GDScript *(locked unless the prototype hits a hard blocker — see [Technical Design Document](./docs/03-technical-design-document.md))* |
| **Monetization** | Premium (one-time purchase) |

## 📚 Planning docs

> **Start here: [Decisions Log](./docs/00-decisions-log.md)** — the index of resolved decisions (and what's still open). The other docs defer to it.

1. **[Game Concept / Pitch](./docs/01-game-concept-pitch.md)** — the hook and elevator pitch
2. **[Game Design Document](./docs/02-game-design-document.md)** — mechanics, systems, and the core loop
3. **[Technical Design Document](./docs/03-technical-design-document.md)** — engine, architecture, and tech risks
4. **[Art Bible / Style Guide](./docs/04-art-bible-style-guide.md)** — visual and audio direction
5. **[Project Plan / Roadmap](./docs/05-project-plan-roadmap.md)** — milestones from prototype to launch
6. **[Test / QA Plan](./docs/06-test-qa-plan.md)** — testing and playtesting approach
7. **[Risk Register](./docs/07-risk-register.md)** — what could go wrong, and the plan for it
8. **[Narrative & Glossary](./docs/08-narrative-and-glossary.md)** — Tone Charter, text plan, glossary, accessibility, and asset-naming conventions

## 🗺️ Roadmap

| Milestone | Goal |
|-----------|------|
| **0 · Smoke test** | One-day Godot check — tooling installs, 2D lights work. |
| **1 · Prototype** | One playable raid — is sneaking around as a goblin fun? |
| **2 · Vertical Slice** | One polished warren room + one full raid + death/respawn loop. The go/no-go gate (and where Early Access is decided). |
| **3 · Alpha** | All core systems present, content rough |
| **4 · Beta** | Feature-complete single-player, balanced and polished |
| **Demo · Steam Next Fest** | A polished, self-contained demo as the marquee marketing beat — released 2–4 weeks early. Readiness criterion: it survives a full QA pass with no crashes or softlocks across a batch of fresh raid seeds. |
| **5 · Launch** | Steam release (default: Early Access) |

> Every milestone is a **continue / pivot / cut** checkpoint — see the [roadmap](./docs/05-project-plan-roadmap.md).

## 🛠️ Building & running

> _Coming soon — the project hasn't reached a playable build yet. Build instructions will land here once the prototype exists._

## 🤝 Contributing

This is a solo project in early pre-production, so it's **feedback and ideas only** — no code contributions. Open an issue to share a thought or suggestion. Note that ideas submitted this way may be used in the game without compensation.

## 📄 License

**Proprietary — All Rights Reserved.** Code and assets are © the project author; no use, copying, or distribution without permission. (Code and asset licenses may be split out separately later.)
