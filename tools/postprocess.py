"""Turn a raw gpt-image-2 PNG into a game-ready asset.

The model returns a 1024px (or larger) square with the subject floating in the
middle. Before SpriteKit can use it we need to:

1. Force true monochrome. The model occasionally sneaks in a faint colour cast
   which would break the strict black-and-white art direction.
2. Knock out any residual flat background to alpha for sprites.
3. Trim the empty margin so the sprite's anchor point is meaningful.
4. Slice animation sheets into individual numbered frames.
"""

from __future__ import annotations

import io
from pathlib import Path

from PIL import Image, ImageChops

# Pixels this close to the corner colour are treated as background.
BG_TOLERANCE = 26
# Alpha below this is considered fully empty when computing the trim box.
ALPHA_FLOOR = 12
# Breathing room left around a trimmed sprite, in pixels.
TRIM_PADDING = 6


def _to_monochrome(img: Image.Image) -> Image.Image:
    """Desaturate while preserving alpha, enforcing the black-and-white rule."""
    alpha = img.getchannel("A")
    grey = img.convert("L").convert("RGB")
    grey.putalpha(alpha)
    return grey


def _knockout_background(img: Image.Image) -> Image.Image:
    """Make a flat, uniform background transparent.

    Only runs when the four corners agree on a colour, so illustrations that
    legitimately reach the edge are left untouched.
    """
    w, h = img.size
    corners = [
        img.getpixel((0, 0)),
        img.getpixel((w - 1, 0)),
        img.getpixel((0, h - 1)),
        img.getpixel((w - 1, h - 1)),
    ]
    opaque = [c for c in corners if c[3] > 200]
    if len(opaque) < 3:
        return img  # already has alpha where it matters

    ref = opaque[0]
    for c in opaque[1:]:
        if max(abs(a - b) for a, b in zip(c[:3], ref[:3])) > BG_TOLERANCE:
            return img  # corners disagree, this is real artwork

    flat = Image.new("RGB", img.size, ref[:3])
    delta = ImageChops.difference(img.convert("RGB"), flat).convert("L")
    mask = delta.point(lambda v: 0 if v <= BG_TOLERANCE else 255)

    out = img.copy()
    existing = out.getchannel("A")
    out.putalpha(ImageChops.darker(existing, mask))
    return out


def _trim(img: Image.Image) -> Image.Image:
    box = img.getchannel("A").point(lambda v: 255 if v > ALPHA_FLOOR else 0).getbbox()
    if not box:
        return img
    left, top, right, bottom = box
    return img.crop((
        max(0, left - TRIM_PADDING),
        max(0, top - TRIM_PADDING),
        min(img.width, right + TRIM_PADDING),
        min(img.height, bottom + TRIM_PADDING),
    ))


def _slice(img: Image.Image, cols: int, rows: int, dest: Path) -> None:
    """Cut a sheet into evenly sized cells and trim each frame individually."""
    dest.mkdir(parents=True, exist_ok=True)
    for old in dest.glob("frame_*.png"):
        old.unlink()

    cw, ch = img.width // cols, img.height // rows
    index = 0
    for row in range(rows):
        for col in range(cols):
            cell = img.crop((col * cw, row * ch, (col + 1) * cw, (row + 1) * ch))
            cell = _trim(cell)
            if cell.width < 8 or cell.height < 8:
                continue  # empty cell, the model left it blank
            cell.save(dest / f"frame_{index}.png", "PNG", optimize=True)
            index += 1


def process(
    blob: bytes,
    out_path: Path,
    *,
    trim: bool = True,
    transparent: bool = True,
    slice_grid: tuple[int, int] | None = None,
    slice_to: Path | None = None,
) -> None:
    img = Image.open(io.BytesIO(blob)).convert("RGBA")
    img = _to_monochrome(img)

    if transparent:
        img = _knockout_background(img)

    if slice_grid and slice_to:
        # Slice from the untrimmed sheet so every cell keeps its grid position.
        _slice(img, slice_grid[0], slice_grid[1], slice_to)

    if trim:
        img = _trim(img)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    img.save(out_path, "PNG", optimize=True)
