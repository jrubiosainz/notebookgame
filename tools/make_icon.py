"""Builds the iOS app icon from the generated title art.

App icons may not contain transparency, so this flattens the generated PNG onto
the paper colour and writes a square 1024x1024 image straight into the asset
catalogue.

    python tools/make_icon.py
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "title" / "app_icon.png"
DESTINATION = (
    ROOT
    / "NotebookGame"
    / "NotebookGame"
    / "Assets.xcassets"
    / "AppIcon.appiconset"
    / "app_icon.png"
)

# Matches Paper.background in the game so the icon and the app agree.
PAPER = (224, 224, 224)
SIZE = 1024


def main() -> int:
    if not SOURCE.exists():
        print(f"missing {SOURCE.relative_to(ROOT)} - run generate_assets.py first")
        return 1

    art = Image.open(SOURCE).convert("RGBA")

    # Fit the artwork inside a small margin, preserving its aspect ratio.
    margin = int(SIZE * 0.06)
    box = SIZE - margin * 2
    scale = min(box / art.width, box / art.height)
    art = art.resize((max(1, int(art.width * scale)), max(1, int(art.height * scale))),
                     Image.LANCZOS)

    canvas = Image.new("RGB", (SIZE, SIZE), PAPER)
    canvas.paste(art, ((SIZE - art.width) // 2, (SIZE - art.height) // 2), art)

    DESTINATION.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(DESTINATION, "PNG")
    print(f"wrote {DESTINATION.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
