# Style guide

The whole point of this repo is that one art direction is applied to every
generated image, mechanically, with no per-asset drift. This document explains
how that works and what to change when you want a different look.

## The contract

`tools/style.py` is the single source of truth. Every prompt is built by
`build_prompt()`:

```
STYLE_PREFIX  +  subject  +  [FACE_RULE]  +  [sheet_rule(frames)]  +  STYLE_SUFFIX
```

Nothing else ever calls the image API directly. An asset definition in
`tools/manifest.py` supplies only the **subject** — what the thing is — plus a
few switches:

```python
Asset("tree_pine",  "a tall skinny pine tree",           face=True)
Asset("nib_walk_down", "the hero seen from the front",   sheet=4, size="1536x1024")
```

If you find yourself adding style words to a subject string, stop: that is the
thing this design exists to prevent.

## The wording that actually matters

The first attempt at this style produced beautiful, detailed *etchings* —
completely wrong. These specific phrases were what pulled it back to a child's
doodle, and removing any of them regresses the look:

- **"Loose childlike hand-drawn doodle"** — without *childlike*, the model draws
  a competent adult illustrator.
- **"Thick bold wobbly marker outlines of uneven weight"** — without *thick bold
  wobbly marker*, lines become thin, even, and engraved.
- **"Chunky simple shapes, minimal detail"** — without this, detail creeps back
  in and the halftone turns into fine cross-hatching.
- **"Naive sketchbook margin-doodle aesthetic"** — anchors the whole thing.
- **"Strictly monochrome black and white"** — repeated in the suffix, because
  the model will otherwise sneak in a warm paper tint.

Shading is always **halftone dots plus light cross-hatching**. Never grey fills:
grey fills look printed, dots look drawn.

## Faces

Almost every object in the reference has a face, and that single decision is
what makes the world read as "doodles" rather than "assets". `FACE_RULE` is
applied whenever `face=True`:

> the object has a cute tiny face with two simple dot eyes and a small curved
> smile

Faces go on rocks, plants, trees, stumps, cacti and props. They do **not** go on
UI elements, tiles, or the backdrop.

## Sheets

Animation frames are generated as a single strip in one request, not as N
separate requests. This is essential: separate requests drift, one image cannot.
`sheet_rule(n)` asks for `n` evenly spaced panels on one row with identical
character size and framing, and `postprocess.py` slices the result into
`frame_0.png … frame_{n-1}.png`.

## Post-processing

`tools/postprocess.py` runs on everything and does three jobs:

1. **Force grayscale.** Belt and braces against colour casts.
2. **Knock out the background.** Flood-fill from the edges to alpha, so props
   sit on the map instead of on a grey square. Skipped for backdrops and tiles.
3. **Trim and slice.** Crop to the drawn content, then cut sheets into frames.

Tiles are deliberately *not* trimmed or knocked out — they need to stay square
and edge-to-edge so the ground tessellates.

## Changing the look

### Adventure color is gameplay

The source illustrations remain monochrome. `Adventure/NotebookVisuals.swift`
supplies the six consistent pigment colors; `AdventureWorldNode` applies a
translucent color wash only after the simulation records that the object was
painted. Unfinished objects are pale and carry a pigment marker. Their familiar
faces, outlines and hatching are preserved.

Ruled warm paper, uneven stains, folded paths and a pink eraser are drawn at
runtime. Night uses a dark mask with soft cutouts around burning campfires and
shelters. This intentional runtime color is not a reason to remove grayscale
enforcement from the generation pipeline.

The live interface must not reserve a header/footer or resemble a dashboard.
Reuse `ui/joystick_base`, `ui/joystick_knob`, `ui/button` and the original heart
drawings. Keep secondary actions, the atlas and inventory inside the illustrated
bag panel. Page titles are temporary annotations, not permanent chrome.

Nib's adventure poses use the existing `characters/nib/walk_down`, `walk_up`
and `walk_side` frame families. Keep their aspect ratios and anchor their feet
to the same ground point. Use the directional resting frame rather than swapping
to a differently shaded idle drawing. The cover stays tool-free; brushes and
erasers appear briefly during gestures, never as permanently floating ornaments.

```bash
# edit tools/style.py
python tools/generate_assets.py --force
```

That regenerates all 53 assets in the new style. Because the style lives in one
place, the game cannot end up half-restyled.

To preview a change cheaply before committing to a full run:

```bash
python tools/generate_assets.py --only tree_pine --force
python tools/generate_assets.py --only nib_idle  --force
```
