# Goblin Mode — Art Bible / Style Guide

*Defines the look and sound. Since art can't be drawn in text, this describes the direction precisely so concept art and mood boards can be built against it. Visual placeholders are marked `[TODO]`.*

## Visual pillars / mood

Three words to hold every art decision against: **grubby, mischievous, characterful.** The world should feel handmade and a little gross in a charming way — like a storybook drawn by a goblin. Cute enough that you root for the little menaces, grimy enough that it's clearly the wrong side of the tracks.

`[TODO: assemble a mood board — pixel-art roguelikes with strong personality, storybook-fantasy palettes, "cozy but feral" references.]`

## Art style & resolution

- **2D pixel art.** Chunky, readable sprites over fussy detail — readability beats realism, especially during chaotic raids.
- **Base resolution:** a low pixel-art canvas scaled up cleanly (integer scaling). `[TODO: lock exact sprite sizes in prototype, e.g. 32×32 goblins.]`
- **Silhouette-first.** Goblins, guards, and loot must be identifiable by silhouette alone so the player parses a busy raid instantly.

## Color palette & lighting direction

- **Warren (day phase):** warm, earthy, cozy-grubby — mud browns, mossy greens, torch-orange glow. Home should feel safe and a bit silly.
- **Raids (night phase):** cool, tense — deep blues and purples, pools of warm lantern light the goblin must avoid. Lighting is a *gameplay* element: light = danger, shadow = safety.
- **"Goblin Mode" state:** a hot, saturated accent (sickly green / hot pink chaos tint) so the frenzy reads instantly on screen.
- Use a **limited, cohesive palette** (a fixed set of swatches) for a unified pixel-art look. `[TODO: define the master palette.]`

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
- Key animation beats: sneak, sprint, grab/stuff-in-sack, get-startled, "goblin mode" transformation, comedic death.
- Lots of small idle/reaction animations in the warren to make goblins feel alive between raids.

## Audio & music direction

- **Music:** two moods mirroring the loop. Warren = warm, playful, loopy folk/percussion. Raids = tense, minimal, percussive, escalating with the alert level. "Goblin mode" = a chaotic, gleeful spike.
- **SFX:** squelchy, comedic goblin foley; satisfying loot "clinks"; rising alert stingers; a triumphant or pathetic sting on escape vs. capture.
- **Voice:** no real language — goblin gibberish / grunts (cheap to produce, high charm, no localization cost).
- `[TODO: collect an audio reference playlist; produce a short greybox audio test during the vertical slice.]`

## Reference notes

Keep a living folder of references (with sources credited) for palette, goblin design, town design, UI, and audio. **Create original art** — use references for direction and mood only, never to copy another artist's work. `[TODO: set up the reference library.]`
