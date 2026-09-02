#!/usr/bin/env python3
"""Static checks on the hand-authored maps in MapCatalog.swift.

The world is written as ASCII art, which is lovely to edit and very easy to get
subtly wrong: a row one character short, an NPC standing inside a tree, an exit
placed on water. Xcode cannot catch any of that, so we check it here.

    python tools/validate_maps.py
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SWIFT = ROOT / "NotebookGame/NotebookGame/Data/MapCatalog.swift"
SAVE = ROOT / "NotebookGame/NotebookGame/Models/SaveGame.swift"

BLOCKING_GROUND = set("~")
BLOCKING_PROPS = set("TtRbcSCip")
KNOWN_GROUND = set(".,s#~")
KNOWN_PROPS = set(" TtRrgbcSfkCip")

STRING = re.compile(r'"((?:[^"\\]|\\.)*)"')


def rows(body: str, layer: str) -> list[str]:
    m = re.search(layer + r":\s*\[(.*?)\]", body, re.S)
    return STRING.findall(m.group(1)) if m else []


def main() -> int:
    src = SWIFT.read_text(encoding="utf-8")
    problems: list[str] = []
    checked = 0

    maps = re.findall(r"static let (\w+) = MapDef\((.*?)\n    \)\n", src, re.S)
    if not maps:
        print("Could not parse any maps out of MapCatalog.swift")
        return 1

    for name, body in maps:
        ground = rows(body, "groundRows")
        props = rows(body, "propRows")
        if not ground or not props:
            problems.append(f"{name}: missing a layer")
            continue

        width, height = len(ground[0]), len(ground)
        geometry_ok = True

        for i, r in enumerate(ground):
            if len(r) != width:
                problems.append(f"{name}: groundRows[{i}] is {len(r)} wide, expected {width}")
                geometry_ok = False
            for c in sorted(set(r) - KNOWN_GROUND):
                problems.append(f"{name}: groundRows[{i}] has unknown tile {c!r}")
                geometry_ok = False

        if len(props) != height:
            problems.append(f"{name}: propRows has {len(props)} rows, ground has {height}")
            geometry_ok = False
        for i, r in enumerate(props):
            if len(r) != width:
                problems.append(f"{name}: propRows[{i}] is {len(r)} wide, expected {width}")
                geometry_ok = False
            for c in sorted(set(r) - KNOWN_PROPS):
                problems.append(f"{name}: propRows[{i}] has unknown prop {c!r}")
                geometry_ok = False

        if not geometry_ok:
            continue  # positional checks would just be noise

        def walkable(x: int, y: int) -> tuple[bool, str]:
            if not (0 <= x < width and 0 <= y < height):
                return False, "out of bounds"
            if ground[y][x] in BLOCKING_GROUND:
                return False, f"ground {ground[y][x]!r}"
            if props[y][x] in BLOCKING_PROPS:
                return False, f"prop {props[y][x]!r}"
            return True, ""

        placements: list[tuple[str, int, int]] = []
        for m in re.finditer(r'NPCDef\(id: "(\w+)".*?x: (\d+), y: (\d+)', body, re.S):
            placements.append((f"npc {m.group(1)}", int(m.group(2)), int(m.group(3))))
        for m in re.finditer(r'ChestDef\(id: "(\w+)", x: (\d+), y: (\d+)', body, re.S):
            placements.append((f"chest {m.group(1)}", int(m.group(2)), int(m.group(3))))

        for label, x, y in placements:
            checked += 1
            ok, why = walkable(x, y)
            if not ok:
                problems.append(f"{name}: {label} at ({x},{y}) is unreachable - {why}")

        for m in re.finditer(
            r'ExitDef\(x: (\d+), y: (\d+), targetMap: "(\w+)",\s*targetX: (\d+), targetY: (\d+)',
            body, re.S,
        ):
            x, y, target = int(m.group(1)), int(m.group(2)), m.group(3)
            checked += 1
            ok, why = walkable(x, y)
            if not ok:
                problems.append(f"{name}: exit at ({x},{y}) is unreachable - {why}")
            if f'id: "{target}"' not in src:
                problems.append(f"{name}: exit points at unknown map '{target}'")

        print(f"OK  {name:16} {width}x{height}  {len(placements)} placements")

    # The starting tile lives in SaveGame, not the map file.
    save_src = SAVE.read_text(encoding="utf-8")
    sx = re.search(r"var tileX: Int = (\d+)", save_src)
    sy = re.search(r"var tileY: Int = (\d+)", save_src)
    smap = re.search(r'var mapID: String = "(\w+)"', save_src)
    if sx and sy and smap:
        for name, body in maps:
            if f'id: "{smap.group(1)}"' not in body:
                continue
            g, p = rows(body, "groundRows"), rows(body, "propRows")
            x, y = int(sx.group(1)), int(sy.group(1))
            if not (0 <= y < len(g) and 0 <= x < len(g[0])):
                problems.append(f"start tile ({x},{y}) is outside {smap.group(1)}")
            elif g[y][x] in BLOCKING_GROUND or p[y][x] in BLOCKING_PROPS:
                problems.append(f"start tile ({x},{y}) in {smap.group(1)} is blocked")
            else:
                checked += 1
                print(f"OK  start tile      ({x},{y}) on {smap.group(1)}")

    if problems:
        print(f"\n{len(problems)} problem(s):")
        for prob in problems:
            print("  - " + prob)
        return 1

    print(f"\nAll maps valid. {checked} placements checked.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
