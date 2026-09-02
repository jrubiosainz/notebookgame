"""Declarative catalogue of every visual asset in NotebookGame.

Add an entry here and run ``python tools/generate_assets.py`` to produce it.
Nothing else in the pipeline needs to change.
"""

from dataclasses import dataclass, field

from style import DEFAULT_QUALITY, DEFAULT_SIZE, TALL_SIZE, WIDE_SIZE


@dataclass(frozen=True)
class Asset:
    key: str                      # output path under assets/, without extension
    subject: str                  # bare description; style is applied by style.py
    face: bool = False            # give the subject the signature doodle face
    sheet: tuple[int, int] | None = None   # (cols, rows) for animation sheets
    size: str = DEFAULT_SIZE
    quality: str = DEFAULT_QUALITY
    transparent: bool = True      # sprites need alpha; backdrops do not
    trim: bool = True             # crop away empty margins after generation
    slice_to: str | None = None   # write sliced frames to this folder


# --------------------------------------------------------------------------
# Playable characters
# --------------------------------------------------------------------------
CHARACTERS = [
    Asset(
        key="characters/nib_walk_down",
        subject=(
            "a small kid adventurer named Nib with wild spiky hair, a plain "
            "t-shirt, shorts and simple shoes, seen from the front walking "
            "toward the viewer, thin noodle arms and legs mid-stride"
        ),
        face=True,
        sheet=(4, 1),
        size=WIDE_SIZE,
        slice_to="characters/nib/walk_down",
    ),
    Asset(
        key="characters/nib_walk_up",
        subject=(
            "the same small spiky-haired kid adventurer Nib seen from behind, "
            "back of the head and back of the t-shirt visible, no face shown, "
            "walking away from the viewer mid-stride"
        ),
        sheet=(4, 1),
        size=WIDE_SIZE,
        slice_to="characters/nib/walk_up",
    ),
    Asset(
        key="characters/nib_walk_side",
        subject=(
            "the same small spiky-haired kid adventurer Nib in strict side "
            "profile facing right, walking mid-stride, arms swinging"
        ),
        face=True,
        sheet=(4, 1),
        size=WIDE_SIZE,
        slice_to="characters/nib/walk_side",
    ),
    Asset(
        key="characters/nib_idle",
        subject=(
            "the same small spiky-haired kid adventurer Nib standing still "
            "facing the viewer, relaxed, arms at his sides, big goofy grin"
        ),
        face=True,
    ),
    Asset(
        key="characters/nib_attack",
        subject=(
            "the same small spiky-haired kid adventurer Nib in side profile "
            "facing right, swinging a giant oversized pencil like a sword in a "
            "big dramatic arc, action pose, motion lines"
        ),
        face=True,
        sheet=(3, 1),
        size=WIDE_SIZE,
        slice_to="characters/nib/attack",
    ),
    Asset(
        key="characters/nib_hurt",
        subject=(
            "the same small spiky-haired kid adventurer Nib recoiling "
            "backwards in pain, eyes squeezed shut, arms flailing, a few "
            "little shock marks around his head"
        ),
    ),
]

# --------------------------------------------------------------------------
# Enemies
# --------------------------------------------------------------------------
ENEMIES = [
    Asset(
        key="enemies/scribble",
        subject=(
            "a Scribble monster: a chaotic ball of tangled scrawled pen loops "
            "with two skinny legs, grumpy angry eyebrows"
        ),
        face=True,
    ),
    Asset(
        key="enemies/smudge",
        subject=(
            "a Smudge monster: a blobby melting puddle of smeared graphite "
            "with drippy edges and two stubby arms, sly grin"
        ),
        face=True,
    ),
    Asset(
        key="enemies/eraser_bug",
        subject=(
            "an Eraser Bug: a fat pink-less rubber eraser shaped like a beetle "
            "with six tiny legs and little antennae, crumbs falling off it"
        ),
        face=True,
    ),
    Asset(
        key="enemies/clip_crab",
        subject=(
            "a Paperclip Crab: a crab whose whole body and claws are bent from "
            "a single big paperclip wire, scuttling sideways"
        ),
        face=True,
    ),
    Asset(
        key="enemies/doodle_bat",
        subject=(
            "a Doodle Bat: a tiny round bat with oversized ragged torn-paper "
            "wings and big ears, flapping in mid air"
        ),
        face=True,
    ),
    Asset(
        key="enemies/ink_slime",
        subject=(
            "an Ink Slime: a wobbly droplet-shaped blob of spilled ink with a "
            "glossy highlight, jiggling"
        ),
        face=True,
    ),
    Asset(
        key="enemies/big_smudge",
        subject=(
            "The Big Smudge, a huge intimidating boss monster: a towering "
            "mountain of smeared charcoal with long dripping arms, a wide "
            "jagged toothy grin and two glaring eyes, looming over the viewer"
        ),
        size=TALL_SIZE,
    ),
]

# --------------------------------------------------------------------------
# Friendly NPCs
# --------------------------------------------------------------------------
NPCS = [
    Asset(
        key="npcs/old_inkwell",
        subject=(
            "a big round old glass inkwell bottle with a wide heavy base and a "
            "cork stopper sitting on top like a little hat, alive and friendly, "
            "with a long feather quill pen leaning in the neck and thick ink "
            "swirling inside the glass"
        ),
        face=True,
    ),
    Asset(
        key="npcs/pencil_case_stall",
        subject=(
            "a big zippered pencil case standing upright and opened wide like a "
            "market stall, the unzipped front flap folded out above it as an "
            "awning, pencils erasers and small supply jars neatly displayed "
            "inside, a tiny blank hanging sign board above"
        ),
    ),
    Asset(
        key="npcs/bench_elder",
        subject=(
            "an old doodle man with a huge round beard and a tiny hat sitting "
            "on a simple wooden park bench, waving hello"
        ),
        face=True,
    ),
    Asset(
        key="npcs/hiker",
        subject=(
            "a friendly hiker kid wearing a baseball cap and a big backpack, "
            "standing and waving"
        ),
        face=True,
    ),
]

# --------------------------------------------------------------------------
# Scenery props
# --------------------------------------------------------------------------
PROPS = [
    Asset(key="props/rock_small", subject="a small round pebble", face=True),
    Asset(key="props/rock_large", subject="a big chunky boulder", face=True),
    Asset(key="props/grass_tuft", subject="a spiky tuft of wild grass", face=True),
    Asset(key="props/bush", subject="a round fluffy cloud-shaped bush", face=True),
    Asset(key="props/tree_round", subject="a short tree with a round bubbly cloud-shaped canopy", face=True),
    Asset(key="props/tree_pine", subject="a tall triangular pine tree", face=True),
    Asset(key="props/stump", subject="a wide chopped tree stump showing its rings", face=True),
    Asset(key="props/cactus", subject="a tall saguaro cactus with two arms and little spines", face=True),
    Asset(key="props/flower", subject="a single daisy flower on a thin stem", face=True),
    Asset(key="props/skull", subject="a small cartoon animal skull with horns lying in the sand"),
    Asset(key="props/signpost", subject="a wooden signpost with one blank arrow-shaped board"),
    Asset(key="props/chest", subject="a small wooden treasure chest with a curved lid and a big latch, closed"),
    Asset(key="props/chest_open", subject="the same small wooden treasure chest with its lid flipped open and sparkles coming out"),
    Asset(key="props/inkwell", subject="a glass inkwell bottle with a cork and a quill feather stuck in it"),
    Asset(key="props/campfire", subject="a small campfire of crossed logs with wobbly flames"),
]

# --------------------------------------------------------------------------
# Ground tiles - these must tile seamlessly, so no faces and no trimming
# --------------------------------------------------------------------------
TILES = [
    Asset(
        key="tiles/paper",
        subject=(
            "a seamless repeating texture of blank notebook paper with a very "
            "faint even halftone dot grain and nothing else on it"
        ),
        transparent=False,
        trim=False,
    ),
    Asset(
        key="tiles/path",
        subject=(
            "a seamless repeating texture of a sandy dirt footpath, scattered "
            "tiny specks and pebbles, edge-to-edge with no borders"
        ),
        transparent=False,
        trim=False,
    ),
    Asset(
        key="tiles/sand",
        subject=(
            "a seamless repeating texture of desert sand with gentle ripple "
            "lines, edge-to-edge with no borders"
        ),
        transparent=False,
        trim=False,
    ),
    Asset(
        key="tiles/water",
        subject=(
            "a seamless repeating texture of water drawn as calm horizontal "
            "wavy ink lines, edge-to-edge with no borders"
        ),
        transparent=False,
        trim=False,
    ),
    Asset(
        key="tiles/stone",
        subject=(
            "a seamless repeating texture of a cobblestone floor of rounded "
            "stones, edge-to-edge with no borders"
        ),
        transparent=False,
        trim=False,
    ),
]

# --------------------------------------------------------------------------
# Interface
# --------------------------------------------------------------------------
UI = [
    Asset(key="ui/heart_full", subject="a solid filled heart symbol, hand drawn"),
    Asset(key="ui/heart_empty", subject="an empty unfilled heart outline, hand drawn"),
    Asset(key="ui/ink_drop", subject="a single filled teardrop-shaped ink drop"),
    Asset(key="ui/coin", subject="a round coin stamped with a little quill pen symbol"),
    Asset(
        key="ui/dialogue_box",
        subject=(
            "an empty wide rectangular speech panel with a thick wobbly "
            "hand-drawn border and a completely blank interior"
        ),
        size=WIDE_SIZE,
    ),
    Asset(
        key="ui/button",
        subject=(
            "an empty small rounded rectangular button with a thick wobbly "
            "hand-drawn border and a completely blank interior"
        ),
        size=WIDE_SIZE,
    ),
    Asset(key="ui/joystick_base", subject="a simple hollow circle ring with a thick wobbly hand-drawn outline"),
    Asset(key="ui/joystick_knob", subject="a small solid filled circle with a thick wobbly hand-drawn outline"),
    Asset(key="ui/potion", subject="a small round-bottomed potion bottle with a cork and a bubbling liquid inside"),
    Asset(key="ui/pencil_sword", subject="a large sharpened pencil held like a sword, diagonal"),
    Asset(key="ui/shield_notebook", subject="a small shield made from a folded notebook cover with a spiral binding down one edge"),
    Asset(key="ui/star", subject="a chunky five pointed star"),
    Asset(key="ui/slash_fx", subject="a single bold curved slash swoosh mark with speed lines, an impact effect"),
    Asset(key="ui/impact_fx", subject="a spiky cartoon impact burst starburst shape, an impact effect"),
    Asset(
        key="ui/battle_backdrop",
        subject=(
            "an empty battle arena seen from a low angle: a flat patch of "
            "ground in the foreground, a simple horizon line, a few distant "
            "hills and two small trees far away, no characters, lots of empty "
            "space in the middle of the frame"
        ),
        size=WIDE_SIZE,
        transparent=False,
        trim=False,
    ),
]

# --------------------------------------------------------------------------
# Title and marketing art
# --------------------------------------------------------------------------
TITLE = [
    Asset(
        key="title/title_backdrop",
        subject=(
            "a wide establishing shot of a doodle world: a winding footpath "
            "curving over rolling hills, scattered rocks bushes and pine "
            "trees, a few clouds above, plenty of empty sky in the upper half "
            "for a logo to sit"
        ),
        size=WIDE_SIZE,
        transparent=False,
        trim=False,
    ),
    Asset(
        key="title/app_icon",
        subject=(
            "an app icon emblem: Nib, a tiny brave doodle adventurer, raises an "
            "oversized sharpened pencil like a sword while standing on an open "
            "spiral notebook; behind him is one large irregular five-point ink "
            "star and one energetic black ink swoosh; bold readable silhouette, "
            "no words or letters, centered with a generous safe margin"
        ),
        transparent=False,
        trim=False,
    ),
]

ALL_ASSETS: list[Asset] = CHARACTERS + ENEMIES + NPCS + PROPS + TILES + UI + TITLE


def by_key(key: str) -> Asset:
    for a in ALL_ASSETS:
        if a.key == key:
            return a
    raise KeyError(key)
