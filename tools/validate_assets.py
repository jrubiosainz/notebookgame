#!/usr/bin/env python3
"""Cross-checks the asset names Swift asks for against the ones Python makes.

Nothing catches this class of bug otherwise: the Swift compiler is happy with
any string literal, and the generator is happy producing an asset nobody loads.
The two sides only agree by convention, so the convention gets a test.

    python tools/validate_assets.py
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import manifest  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
SWIFT_ROOT = ROOT / "NotebookGame" / "NotebookGame"

# Art.texture("rock_small", in: "props")
TEXTURE = re.compile(r'Art\.texture\(\s*"([^"]+)"\s*,\s*in:\s*"([^"]+)"')
# Art.frames(in: "characters/nib/walk_down", fallback: "nib_idle", ...)
FRAMES = re.compile(r'Art\.frames\(\s*in:\s*"([^"]+)"')
# Data-driven names, e.g. spriteName: "scribble" or sprite: "pencil_case_stall"
LITERAL = re.compile(r'"([A-Za-z0-9_]+)"')

# Generated on purpose, but consumed by the toolchain rather than by the game.
NOT_LOADED_BY_THE_GAME = {
    "title/app_icon",  # flattened into Assets.xcassets by tools/make_icon.py
}


def declared() -> tuple[set[str], set[str]]:
    """Returns (single image keys, sliced frame folders), both without extension."""
    singles: set[str] = set()
    folders: set[str] = set()
    for asset in manifest.ALL_ASSETS:
        if asset.slice_to:
            folders.add(asset.slice_to)
        else:
            singles.add(asset.key)
    return singles, folders


def main() -> int:
    singles, folders = declared()
    problems: list[str] = []
    used_singles: set[str] = set()
    used_folders: set[str] = set()

    swift_files = sorted(SWIFT_ROOT.rglob("*.swift"))
    if not swift_files:
        print(f"No Swift sources under {SWIFT_ROOT}")
        return 1

    # Assets referenced by bare name from the data catalogs rather than by a
    # literal Art.texture(...) call.
    basenames: dict[str, set[str]] = {}
    for key in singles | folders:
        basenames.setdefault(key.rsplit("/", 1)[-1], set()).add(key)
    referenced_by_name: set[str] = set()

    for path in swift_files:
        src = path.read_text(encoding="utf-8")
        rel = path.relative_to(ROOT)

        for name, folder in TEXTURE.findall(src):
            key = f"{folder}/{name}"
            used_singles.add(key)
            if key not in singles:
                hint = " (that is a sliced sheet, use Art.frames)" if key in folders else ""
                problems.append(f"{rel}: Art.texture -> '{key}' is not in the manifest{hint}")

        for folder in FRAMES.findall(src):
            used_folders.add(folder)
            if folder not in folders:
                problems.append(f"{rel}: Art.frames -> '{folder}' is not a sliced sheet in the manifest")

        for literal in LITERAL.findall(src):
            if literal in basenames:
                referenced_by_name |= basenames[literal]

    orphans = sorted((singles | folders)
                     - used_singles - used_folders
                     - referenced_by_name - NOT_LOADED_BY_THE_GAME)

    print(f"{len(swift_files)} Swift files scanned")
    print(f"{len(used_singles)} textures and {len(used_folders)} frame sets referenced directly")
    print(f"{len(referenced_by_name)} more referenced by name from the data catalogs")

    if orphans:
        # Not fatal, but usually means an asset was renamed on one side only.
        print(f"\n{len(orphans)} generated asset(s) that nothing appears to load:")
        for key in orphans:
            print("  . " + key)

    if problems:
        print(f"\n{len(problems)} problem(s):")
        for prob in problems:
            print("  - " + prob)
        return 1

    print("\nEvery asset Swift asks for is produced by the pipeline.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
