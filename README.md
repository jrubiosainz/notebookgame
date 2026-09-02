# Notebook Quest

A hand-drawn black-and-white RPG for iOS, set inside the margins of a school
notebook. Every rock, tree and monster is a doodle with a face, and **every
single visual asset in the game is generated with Azure OpenAI `gpt-image-2`**
from one shared style contract, so the whole game looks like it was drawn by one
person in one sitting.

---

## What is in here

| Path | What it is |
| --- | --- |
| `NotebookGame/` | The iOS app: Swift 5, SpriteKit, SwiftUI shell. |
| `tools/` | The Python asset pipeline that talks to `gpt-image-2`. |
| `assets/` | Generated art. Bundled into the app as a folder reference. |
| `docs/` | Style guide and asset pipeline notes. |

---

## The game

You are **Nib**, a doodle in the margin of somebody's notebook. **The Big
Smudge** is bleeding across the page and erasing everyone. Walk three maps, fight
the things that live in the ink, and scrub the page clean.

- Top-down movement with a floating virtual joystick
- Random encounters, turn-based battles, five unlockable skills
- Ink as the magic resource, coins as currency, hearts for health
- Items, two equipment slots, a pencil-case shop stall, a camp that heals you
- A save file that survives being backgrounded, and a boss at the end

**Maps:** Pencil Plains → Eraser Desert → Inkwell Woods.

---

## Building the app

Requirements: **Xcode 16 or newer**, iOS 17 deployment target.

```bash
open NotebookGame/NotebookGame.xcodeproj
```

Pick a simulator or device and run. There is nothing to install; the project has
no third-party dependencies.

The project uses Xcode 16 file-system synchronized groups, so new Swift files
are picked up automatically — just drop them in `NotebookGame/NotebookGame/`.
If you are on an older Xcode, regenerate the project instead:

```bash
brew install xcodegen
cd NotebookGame && xcodegen
```

> `assets/` is added as a **folder reference**, not a group. That is deliberate:
> it keeps `assets/<category>/<name>.png` intact inside the bundle, which is
> exactly the path the Python generator writes and the Swift `Art` loader reads.
> There is no manual bookkeeping between the two.

---

## Regenerating the art

All art is reproducible. See [`docs/ASSETS.md`](docs/ASSETS.md) for the full
walkthrough; the short version:

```bash
pip install -r tools/requirements.txt
cp .env.example .env.local        # then fill in your Azure values
python tools/generate_assets.py   # ~53 assets, resumable, cached
python tools/make_icon.py         # builds the app icon from the title art
```

Useful flags:

```bash
python tools/generate_assets.py --list             # show every asset and its state
python tools/generate_assets.py --only props       # one category
python tools/generate_assets.py --only tree_pine   # one asset
python tools/generate_assets.py --force            # ignore the cache
```

Generation is **idempotent**: each asset is cached against a hash of its final
prompt, so re-running only regenerates what actually changed. Interrupt it and
run it again; it picks up where it left off.

---

## Keeping the look consistent

This was the hard requirement, so it is enforced structurally rather than by
discipline.

`tools/style.py` holds the *only* description of the art direction. No prompt is
ever sent to the model raw — every one is assembled by `build_prompt()`:

```
STYLE_PREFIX  +  subject  +  [face rule]  +  [sheet rule]  +  STYLE_SUFFIX
```

An entry in `tools/manifest.py` therefore only ever describes *what the thing
is*, never *how it should look*:

```python
Asset("tree_pine", "a tall skinny pine tree", face=True)
```

To restyle the entire game you edit `style.py` and re-run with `--force`. You
never touch individual prompts. `tools/postprocess.py` then enforces true
grayscale and knocks the flat background out to alpha, because the model
occasionally sneaks in a faint colour cast.

Full details, including the exact wording that matters, are in
[`docs/STYLE_GUIDE.md`](docs/STYLE_GUIDE.md).

---

## Validating without a compiler

Two checks cover the things Xcode structurally cannot catch, and both are worth
running before you build.

**The maps.** They are ASCII art in `Data/MapCatalog.swift`, which is lovely to
edit and very easy to get subtly wrong. This parses the Swift source and checks
row widths, unknown tile characters, and whether every NPC, chest and exit is
standing somewhere actually reachable:

```bash
python tools/validate_maps.py
```

It caught three real bugs during development: an NPC inside a tree, a chest under
a tree, and an exit walled off by scenery.

**The asset names.** Swift asks for art by string, and the generator produces it
by string, and nothing checks that those two sets of strings agree — the
compiler is happy with any literal, and the generator is happy making something
nobody loads. So the convention gets a test:

```bash
python tools/validate_assets.py
```

It caught four real mismatches on its first run (`fx_slash` vs `slash_fx`, a
`ui/panel` that was never in the manifest, a battle backdrop nobody was
generating, and a hero-from-behind texture that already existed as frame 0 of the
walk-up cycle).

---

## Project layout

```
NotebookGame/NotebookGame/
  App/       SwiftUI entry point and the SpriteView host
  Core/      GameState (save + derived stats), Art loader, Paper theme, Haptics
  Data/      Bestiary, items, equipment, and the three maps
  Models/    Stats, progression curve, items, save file
  Scenes/    Title, Overworld, Battle
  Systems/   Tile map + collision, battle maths, player node
  UI/        Joystick, buttons, dialogue, HUD, menu and shop panels
```

`Systems/BattleEngine.swift` is deliberately free of SpriteKit so the combat
maths can be reasoned about (and tested) on its own.

---

## Status

The art pipeline and the game logic are complete. **The Swift code has not been
compiled yet** — it was written on a Windows machine, where no Swift toolchain
for iOS exists. Expect to fix a small number of compile errors on the first
build on a Mac. Everything that *could* be verified without a compiler was: the
maps are checked by script, and the asset names are cross-checked between the
generator and the game.

---

## Licence

MIT. See [LICENSE](LICENSE).
