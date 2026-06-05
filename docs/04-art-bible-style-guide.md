# Goblin Mode — Art Bible / Style Guide

*Defines the look and sound. Since art can't be drawn in text, this describes the direction precisely so concept art and mood boards can be built against it. Visual placeholders are marked `[TODO]`.*

## Visual pillars / mood

Three words to hold every art decision against: **grubby, mischievous, characterful.** The world should feel handmade and a little gross in a charming way — like a storybook drawn by a goblin. Cute enough that you root for the little menaces, grimy enough that it's clearly the wrong side of the tracks.

Every visual choice serves the **"underdog farce"** tone — see the [Tone Charter](08-narrative-and-glossary.md). The art is in on the joke: goblins are charming losers, the tall folk are pompous and oblivious, and nobody is ever genuinely harmed.

`[TODO: assemble a mood board — pixel-art roguelikes with strong personality, storybook-fantasy palettes, "cozy but feral" references.]`

## Art style & resolution

- **2D pixel art.** Chunky, readable sprites over fussy detail — readability beats realism, especially during chaotic raids.
- **Base resolution:** ~32×32 goblins on a low pixel-art base canvas, scaled up cleanly (integer scaling — whole-number multiples so pixels stay crisp). Lock the exact size in the prototype, but `~32×32` is the planning anchor everything else is sized against. (See [decisions log](00-decisions-log.md).)
- **Perspective: top-down (three-quarter / 3-4 oblique view), LOCKED** — see the [GDD](02-game-design-document.md). This drives sprite construction: a three-quarter view means sprites need **directional facings** (at minimum left/right/up/down; ideally also the diagonals) rather than a single side-on pose, because the player and the AI both reason about 360-degree movement and line-of-sight. Budget for this when scoping animation — each facing multiplies the frames an animation needs. Mirror left/right to halve that cost where the art allows.
- **Silhouette-first.** Goblins, guards, and loot must be identifiable by silhouette alone so the player parses a busy raid instantly — and silhouettes must still read from the top-down three-quarter angle, not just side-on.

## Color palette & lighting direction

- **Warren (day phase):** warm, earthy, cozy-grubby — mud browns, mossy greens, torch-orange glow. Home should feel safe and a bit silly.
- **Raids (night phase):** cool, tense — deep blues and purples, pools of warm lantern light the goblin must avoid. Lighting is a *gameplay* element: light = danger, shadow = safety.
- **"Goblin Mode" state — a DUAL read.** The frenzy must read instantly as *two things at once*: powered-up AND wildly exposed. The art has to say "gloriously reckless," never "invincible," so that a death in Goblin Mode reads as *earned*, not unfair.
  - **Power tint:** a hot, saturated accent (sickly green / hot pink chaos tint) on the goblin so the buffed state is obvious.
  - **"You are EXPOSED" signal, layered on top of the tint:** the noise meter pinned to max, the alert UI flashing, and a frantic edge to the music (see Audio below). The frenzy *looks* great and *feels* dangerous on purpose.
- **Accessibility — never colour alone.** The Goblin Mode state must NOT be encoded in colour only (it would vanish for colour-blind players). Pair the power tint with a non-colour cue: a distinct silhouette change (e.g. spiked/bristling outline) plus a constant animation tell (a shaking/vibrating idle). The flashing alert UI and pinned noise meter are themselves shape/motion cues, not colour ones. See the accessibility note in [docs/08](08-narrative-and-glossary.md).
- Use a **limited, cohesive palette** (a fixed set of swatches) for a unified pixel-art look. `[TODO: define the master palette.]`

> **First outsourcing spend (planned).** Spend nothing on art until Milestone 2 clears its go/no-go gate. The first paid art is a small pre-production package — **mood board + master palette + key/capsule art** — after which everything else is self-produced in that style (audio stays in-house). "Capsule art" is the little cover image a game shows on its Steam page; it is a **top-3 commercial lever** — roughly 68–88% of Steam Next Fest wishlists come from people who only ever see the capsule and never play the demo — so it's worth paying a professional for. See [decisions log](00-decisions-log.md) and the go-to-market plan in the [roadmap](05-project-plan-roadmap.md).

## Character & environment style

- **Goblins:** small, big-eared, expressive, varied — different colors, accessories, and silhouettes so the procedurally generated roster feels like individuals. Personality through animation and tiny details, not high resolution.
- **The tall folk (guards/townsfolk):** larger, slower-reading silhouettes — visually "the establishment" the goblins are needling.
- **Environments:** the warren is built from grimy, improvised materials (roots, scrap, stolen signage). Towns are tidy, well-lit, and prosperous — a deliberate contrast that reinforces the goblins' underdog mischief.

## UI / HUD style

- **Raid HUD:** minimal and unobtrusive — noise meter, alert level, dawn timer, and sack weight, themed as grubby hand-scrawled goblin iconography. The screen should stay readable at a glance under pressure.
- **Warren UI:** a cozier management panel — bigger, friendlier, tactile, like rummaging through a goblin's junk drawer.
- Diegetic-feeling fonts and icons over generic clean UI. `[TODO: UI mockups for both HUD and management screens.]`

## Animation direction

- **Snappy and exaggerated** — squash-and-stretch, anticipation, comedic timing. A goblin getting caught should be funny.
- Key animation beats: sneak, sprint, grab/stuff-in-sack, get-startled, "goblin mode" transformation, death.
- **Death feedback comes in tiers** (the design hook is *attachment*, so death scales with investment — see [decisions log](00-decisions-log.md)):
  - **Low-investment goblin** (a fresh baseline recruit): pure **slapstick** — a comedic, undignified pratfall. Easy to author, plays for laughs.
  - **Leveled / equipped goblin** (a named member of the gang you've been rotating): a brief **bittersweet-funny beat** — a pathetic little salute, a dropped trinket — that lands the loss without turning maudlin. Still in the farce, just with a lump in the throat.
  - How many distinct death animations to author is decided in the prototype, because the roster design (a small named gang vs. a faceless pool) dictates how much attachment each death must carry. Keep this `[TODO]` open until then.
- Lots of small idle/reaction animations in the warren to make goblins feel alive between raids.

## Audio & music direction

- **Music:** two moods mirroring the loop. Warren = warm, playful, loopy folk/percussion. Raids = tense, minimal, percussive, escalating with the alert level. "Goblin mode" = a chaotic, gleeful spike with a **frantic edge** — part of the dual "you are EXPOSED" signal above, so the frenzy *sounds* reckless, not safe.
- **Keep the tension and the comedy separate** (this protects the tone — see [Tone Charter, docs/08](08-narrative-and-glossary.md)): "spotted / chased" stays genuinely **tense**; the comedy sting plays ONLY on **"fully caught"** (released after the goblin fails), so the humour reads as charming, not cruel.
- **SFX:** squelchy, comedic goblin foley; satisfying loot "clinks"; rising alert stingers; a triumphant sting on escape, a pathetic comedy sting on capture.
- **Voice:** no real language — goblin gibberish / grunts (cheap to produce, high charm, no localization cost).
- `[TODO: collect an audio reference playlist; produce a short greybox audio test during the vertical slice.]`

## Reference notes

Keep a living folder of references (with sources credited) for palette, goblin design, town design, UI, and audio. **Create original art** — use references for direction and mood only, never to copy another artist's work. `[TODO: set up the reference library.]`
