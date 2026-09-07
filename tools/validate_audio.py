#!/usr/bin/env python3
"""Validate committed Notebook Quest WAVs using only the Python standard library."""

from __future__ import annotations

import argparse
from array import array
import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys
import wave


ROOT = Path(__file__).resolve().parents[1]
MUSIC = {"cover", "surface", "depths", "seam", "night", "restored"}
EFFECTS = {
    "step_1": (.08, .18), "step_2": (.08, .18), "step_3": (.08, .18),
    "paint": (.30, .55), "erase": (.22, .42), "erased": (.25, .5),
    "pigment": (1.2, 1.8), "pickup": (.15, .32), "chest": (.45, .8),
    "build": (.38, .7), "fire_light": (.38, .75), "page_turn": (.3, .65),
    "talk": (.12, .26), "ui_tap": (.04, .1), "denied": (.1, .23),
    "eat": (.2, .45), "rest": (.65, 1.1), "memory": (1.5, 2.2),
    "hurt": (.12, .32), "respawn": (1.0, 1.6),
}
AMBIENCE = {"fire": (8, 12), "ink": (12, 16), "night_air": (12, 16)}


def require(condition: bool, message: str):
    if not condition:
        raise ValueError(message)


def inspect(root: Path) -> dict:
    manifest = json.loads((root / "manifest.json").read_text())
    expected = {f"music/{name}.wav" for name in MUSIC}
    expected |= {f"effects/{name}.wav" for name in EFFECTS}
    expected |= {f"ambience/{name}.wav" for name in AMBIENCE}
    entries = manifest["assets"]
    require(len(entries) == len(expected), "Expected exactly 29 manifest entries")
    require({entry["path"] for entry in entries} == expected, "Manifest asset set differs from contract")
    require({p.relative_to(root).as_posix() for p in root.rglob("*.wav")} == expected,
            "Missing or unexpected WAV files")
    total_bytes = 0
    music_frames = set()
    for entry in entries:
        relative = entry["path"]
        kind, filename = relative.split("/")
        name = filename[:-4]
        path = root / relative
        total_bytes += path.stat().st_size
        with wave.open(str(path), "rb") as wav:
            require(wav.getcomptype() == "NONE", f"{relative}: must be uncompressed PCM")
            channels, width, rate, frames = (wav.getnchannels(), wav.getsampwidth(),
                                            wav.getframerate(), wav.getnframes())
            require(width == 2 and channels in (1, 2) and rate >= 22050,
                    f"{relative}: expected mono/stereo 16-bit PCM at >=22050 Hz")
            require(rate == manifest["sample_rate"] == entry["sample_rate"],
                    f"{relative}: inconsistent sample rate")
            require(channels == entry["channels"] and frames == entry["frames"]
                    and entry["bits_per_sample"] == 16,
                    f"{relative}: inconsistent dimensions")
            require(entry["kind"] == kind and entry["loop"] == (kind != "effects"),
                    f"{relative}: incorrect kind/loop metadata")
            raw = wav.readframes(frames)
        require(len(raw) == frames * channels * width, f"{relative}: truncated PCM")
        samples = array("h")
        samples.frombytes(raw)
        if sys.byteorder != "little":
            samples.byteswap()
        peak = max(abs(s) for s in samples) / 32768
        rms = math.sqrt(sum(s * s for s in samples) / len(samples)) / 32768
        duration = frames / rate
        jump = max(abs(samples[ch] - samples[-channels + ch]) / 32768 for ch in range(channels))
        require(0.005 < rms < .16, f"{relative}: RMS outside comfortable non-silent range: {rms:.4f}")
        require(peak < .9, f"{relative}: clipping/headroom failure: {peak:.4f}")
        require(abs(peak - entry["peak"]) < 1e-7 and abs(rms - entry["rms"]) < 1e-7,
                f"{relative}: metric mismatch")
        require(abs(duration - entry["duration_seconds"]) < 1e-6,
                f"{relative}: duration metadata mismatch")
        require(abs(jump - entry["seam_jump"]) < 1e-7, f"{relative}: seam metadata mismatch")
        require(hashlib.sha256(path.read_bytes()).hexdigest() == entry["sha256"],
                f"{relative}: SHA-256 mismatch")
        if kind == "music":
            music_frames.add(frames)
            require(channels == 2 and 40 <= duration <= 60, f"{relative}: invalid music format/duration")
            require(samples[0::2] != samples[1::2], f"{relative}: no stereo variation")
            require(.04 <= rms <= .13, f"{relative}: unexpected music loudness")
            require(jump < .02, f"{relative}: audible loop discontinuity: {jump:.5f}")
            # Check every half-second, including the wrap, for accidental empty bars.
            window = rate // 2 * channels
            for at in range(0, len(samples), window):
                block = samples[at:at + window]
                block_rms = math.sqrt(sum(s * s for s in block) / len(block)) / 32768
                require(block_rms > .003, f"{relative}: silent half-second at {at / rate / channels:.2f}s")
        elif kind == "ambience":
            low, high = AMBIENCE[name]
            require(low <= duration <= high, f"{relative}: invalid ambient duration")
            require(jump < .02, f"{relative}: ambient loop discontinuity: {jump:.5f}")
        else:
            low, high = EFFECTS[name]
            require(low <= duration <= high, f"{relative}: invalid effect duration")
            require(all(samples[ch] == samples[-channels + ch] == 0 for ch in range(channels)),
                    f"{relative}: one-shot must begin and end at zero")
        require(all(abs(sum(samples[ch::channels]) / frames / 32768) < .002
                    for ch in range(channels)), f"{relative}: excessive DC offset")
        print(f"OK {relative:26s} {duration:5.2f}s  peak={peak:.3f} rms={rms:.3f} seam={jump:.5f}")
    require(len(music_frames) == 1, "Music loops must share one exact duration")
    require(total_bytes < 30_000_000, f"Audio budget exceeded: {total_bytes:,} bytes")
    require(manifest["music_grid"]["loop_seconds"] * manifest["sample_rate"]
            == next(iter(music_frames)), "Music grid does not match sample length")
    print(f"PASS: {len(entries)} assets, {total_bytes / 1_000_000:.2f} MB, all formats/levels/seams/hashes valid.")
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT / "assets/audio")
    parser.add_argument("--reproducibility", action="store_true",
                        help="Regenerate in place and require identical WAV and manifest hashes (needs NumPy).")
    args = parser.parse_args()
    try:
        manifest = inspect(args.root)
        if args.reproducibility:
            before = hashlib.sha256((args.root / "manifest.json").read_bytes()).hexdigest()
            subprocess.run([sys.executable, str(ROOT / "tools/generate_audio.py"),
                            "--output", str(args.root)], check=True)
            after = hashlib.sha256((args.root / "manifest.json").read_bytes()).hexdigest()
            require(before == after, "Regeneration changed manifest or PCM hashes")
            second = inspect(args.root)
            require(manifest == second, "Regeneration changed asset metadata")
            print("PASS: full deterministic regeneration is byte-for-byte identical.")
    except (ValueError, KeyError, OSError, wave.Error, subprocess.CalledProcessError) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
