#!/usr/bin/env python3
"""Render Notebook Quest's original, deterministic acoustic miniature score.

Requires Python 3.10+ and NumPy. No recordings, soundfonts, or network services.
All synthesis and composition data are authored here; see docs/AUDIO.md.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import wave

import numpy as np


ROOT = Path(__file__).resolve().parents[1]
RATE = 22050
SEED = 841721
EIGHTH = 1 / 3
BAR = 2.0
BARS = 24
LOOP_SECONDS = BAR * BARS
MUSIC_ORIGIN_SAMPLES = 109
MUSIC_NAMES = ("cover", "surface", "depths", "seam", "night", "restored")
EFFECT_SECONDS = {
    "step_1": 0.13, "step_2": 0.14, "step_3": 0.12,
    "paint": 0.44, "erase": 0.32, "erased": 0.38,
    "pigment": 1.48, "pickup": 0.23, "chest": 0.67,
    "build": 0.55, "fire_light": 0.57, "page_turn": 0.49,
    "talk": 0.20, "ui_tap": 0.07, "denied": 0.18,
    "eat": 0.33, "rest": 0.88, "memory": 1.90,
    "hurt": 0.23, "respawn": 1.30,
}
AMBIENCE_SECONDS = {"fire": 10.0, "ink": 14.0, "night_air": 14.0}
MOODS = {
    "cover": "A hand-cranked music box opens a hopeful story; felt keys answer.",
    "surface": "Lilting felt piano, thumbed strings, breath flute and paper brush.",
    "depths": "Low wooden resonances, suspended minor harmony, patient discovery.",
    "seam": "Floating harmonics, sparse high music box and an airy bowed halo.",
    "night": "Hushed low strings and distant breath; watchful, never horror.",
    "restored": "The opening theme returns with fuller, warm acoustic resolution.",
}


def rng_for(label: str) -> np.random.Generator:
    digest = hashlib.sha256(f"{SEED}:{label}".encode()).digest()
    return np.random.default_rng(int.from_bytes(digest[:8], "little"))


def hz(midi: float) -> float:
    return 440.0 * 2 ** ((midi - 69) / 12)


def timebase(seconds: float) -> np.ndarray:
    return np.arange(round(seconds * RATE), dtype=np.float64) / RATE


def edge_fade(x: np.ndarray, attack: float = 0.003, release: float = 0.025) -> np.ndarray:
    x = x.copy()
    a = min(len(x), max(2, round(attack * RATE)))
    r = min(len(x), max(2, round(release * RATE)))
    x[:a] *= np.sin(np.linspace(0, np.pi / 2, a)) ** 2
    x[-r:] *= np.sin(np.linspace(np.pi / 2, 0, r)) ** 2
    return x


def colored_noise(
    rng: np.random.Generator, n: int, low: float = 80, high: float = 5000,
    pink: float = 0.0,
) -> np.ndarray:
    """FFT filtering gives periodic noise for both one-shots and ambient beds."""
    f = np.fft.rfftfreq(n, 1 / RATE)
    weight = (1 - np.exp(-(f / low) ** 2)) * np.exp(-(f / high) ** 4)
    weight *= (np.maximum(f, low) / 400) ** (-pink / 2)
    spectrum = np.fft.rfft(rng.normal(size=n)) * weight
    spectrum[0] = 0
    x = np.fft.irfft(spectrum, n=n)
    return x / (np.std(x) + 1e-12)


def tone(instrument: str, midi: float, hold: float, rng: np.random.Generator) -> np.ndarray:
    """Damped physical modes, rather than square/saw oscillators or GM sounds."""
    f = hz(midi)
    if instrument == "felt":
        length = min(6.0, max(2.0, hold + 2.3))
        t = timebase(length)
        x = np.zeros(len(t))
        # Detuned paired strings, weak inharmonicity and felt-damped upper modes.
        for k in range(1, 13):
            fk = f * k * math.sqrt(1 + 0.000065 * k * k)
            if fk > RATE * 0.43:
                break
            amplitude = (1 / k ** 1.7) * (1 if k < 4 else 0.62)
            decay = (1.45 + 55 / f) / (1 + 0.29 * (k - 1))
            damping = np.exp(-t / decay) * np.exp(-np.maximum(t - hold, 0) / 0.8)
            phase = rng.uniform(-0.08, 0.08)
            pair = np.sin(2 * np.pi * fk * t + phase)
            pair += 0.30 * np.sin(2 * np.pi * fk * 1.0012 * t + phase)
            x += amplitude * pair * damping
        hammer = colored_noise(rng, len(t), 180, 2000, 0.8)
        x += 0.020 * hammer * np.exp(-t / 0.017)
        x *= 1 - np.exp(-t / 0.005)
        return edge_fade(x * 0.62, 0.003, 0.12)
    if instrument in ("pluck", "bass"):
        bass = instrument == "bass"
        t = timebase(min(5.5, hold + (2.5 if bass else 1.7)))
        x = np.zeros(len(t))
        position = 0.29 if bass else 0.23
        for k in range(1, 16):
            fk = f * k * (1 + 0.000018 * k * k)
            if fk > RATE * 0.42:
                break
            amplitude = abs(math.sin(np.pi * k * position)) / k ** 1.45
            decay = (1.65 if bass else 0.88) / (1 + 0.3 * (k - 1))
            x += amplitude * np.sin(2 * np.pi * fk * t) * np.exp(-t / decay)
        # The small wooden soundboard has a short, non-pitched resonance.
        x += 0.04 * np.sin(2 * np.pi * 183 * t) * np.exp(-t / 0.06)
        x += 0.018 * colored_noise(rng, len(t), 300, 2500) * np.exp(-t / 0.011)
        return edge_fade(x * (0.88 if bass else 0.85), 0.0025, 0.10)
    if instrument == "box":
        t = timebase(min(6.0, max(2.3, hold + 2.3)))
        x = np.zeros(len(t))
        for ratio, amp, decay in ((1, 1, 1.7), (2.001, .18, .60),
                                  (3.987, .075, .24), (5.43, .035, .13)):
            if f * ratio < RATE * .42:
                x += amp * np.sin(2 * np.pi * f * ratio * t) * np.exp(-t / decay)
        x *= (1 - np.exp(-t / .006))
        return edge_fade(x * .67, .003, .12)
    if instrument == "flute":
        t = timebase(hold + .45)
        vibrato = .0018 * np.sin(2 * np.pi * 4.4 * t) * (1 - np.exp(-t / .3))
        drift = .0007 * np.sin(2 * np.pi * .73 * t + rng.uniform(0, 6.28))
        phase = 2 * np.pi * f * np.cumsum(1 + vibrato + drift) / RATE
        envelope = (1 - np.exp(-t / .055)) * np.exp(-np.maximum(t - hold, 0) / .115)
        x = np.sin(phase) + .13 * np.sin(2 * phase) + .045 * np.sin(3 * phase)
        breath = colored_noise(rng, len(t), 450, 3100, 0.6)
        x = (x + .045 * breath) * envelope * (.97 + .03 * np.sin(2 * np.pi * 2.1 * t))
        return edge_fade(x * .56, .025, .17)
    if instrument in ("bow", "halo"):
        halo = instrument == "halo"
        t = timebase(hold + 2.1)
        phase_drift = .009 * np.sin(2 * np.pi * .33 * t + rng.uniform(0, 6.28))
        x = np.zeros(len(t))
        for k in range(1, 7):
            if k * f > RATE * .42:
                break
            amp = 1 / k ** (2.7 if halo else 2.1)
            x += amp * np.sin(2 * np.pi * f * k * .9990 * t + phase_drift)
            x += amp * .7 * np.sin(2 * np.pi * f * k * 1.0013 * t - phase_drift)
        envelope = (1 - np.exp(-t / .45)) * np.exp(-np.maximum(t - hold, 0) / .63)
        return edge_fade(x * envelope * .28, .18, .35)
    raise ValueError(f"Unknown instrument: {instrument}")


class Canvas:
    def __init__(self, seconds: float, stereo: bool = True, loop: bool = False):
        self.audio = np.zeros((round(seconds * RATE), 2 if stereo else 1), dtype=np.float64)
        self.loop = loop

    def add(self, x: np.ndarray, seconds: float, gain: float = 1, pan: float = 0):
        start = round(seconds * RATE)
        if self.audio.shape[1] == 2:
            weights = np.array([math.cos((pan + 1) * np.pi / 4),
                                math.sin((pan + 1) * np.pi / 4)]) * gain
        else:
            weights = np.array([gain])
        if self.loop:
            # Wrap the actual sustained notes and releases, never fade the song.
            offset = 0
            while offset < len(x):
                at = (start + offset) % len(self.audio)
                count = min(len(x) - offset, len(self.audio) - at)
                self.audio[at:at + count] += x[offset:offset + count, None] * weights
                offset += count
        else:
            left = max(0, -start)
            at = max(0, start)
            count = min(len(x) - left, len(self.audio) - at)
            if count > 0:
                self.audio[at:at + count] += x[left:left + count, None] * weights

    def note(self, inst: str, midi: float, seconds: float, hold: float,
             gain: float, pan: float, rng: np.random.Generator):
        self.add(tone(inst, midi, hold, rng), seconds, gain, pan)


def room(audio: np.ndarray, rng: np.random.Generator, wet: float, decay: float) -> np.ndarray:
    """A damped stereo room with circular convolution: all late tails wrap."""
    n, channels = audio.shape
    t = timebase(decay * 1.7)
    out = audio.copy()
    for ch in range(channels):
        ir = colored_noise(rng, len(t), 110, 3000 if decay < 3 else 2300, .7)
        ir *= np.exp(-t * 4.1 / decay) * (1 - np.exp(-t / .028))
        ir = edge_fade(ir, .017, .20)
        ir *= .45 / math.sqrt(float(np.sum(ir * ir)))
        for delay, amplitude in ((.037, .25), (.061, .18), (.097, .13), (.149, .08)):
            index = round((delay + ch * .008) * RATE)
            ir[index] += amplitude
        padded = np.zeros(n)
        # All supplied assets are longer than their room kernels.
        for at in range(0, len(ir), n):
            part = ir[at:at + n]
            padded[:len(part)] += part
        source = audio[:, ch]
        if channels == 2:
            source = .82 * source + .18 * audio[:, 1 - ch]
        out[:, ch] += wet * np.fft.irfft(np.fft.rfft(source) * np.fft.rfft(padded), n=n)
    return out


# The original "a line becomes a path" theme. Offsets and lengths are in eighths.
# Three distinct eight-bar sentences form one 48-second circular miniature.
THEME = [
    [(0, 74, 1.6), (2, 78, .8), (3.25, 76, 1.6), (5.1, 69, .65)],
    [(.2, 73, 1.5), (2.4, 74, .8), (3.5, 78, 1.8)],
    [(0, 71, 2.5), (3, 74, .8), (4.25, 81, 1.35)],
    [(.2, 79, 1.5), (2.2, 78, .85), (3.5, 76, 2.0)],
    [(0, 78, 2.0), (2.75, 76, .8), (4, 74, 1.6)],
    [(.2, 71, 1.1), (1.75, 74, 1.0), (3.2, 76, 2.2)],
    [(0, 73, 1.6), (2.1, 71, .8), (3.4, 69, 2.0)],
    [(.2, 76, .9), (1.6, 73, 1.3), (3.4, 74, .7), (4.7, 73, .65)],
    [(0, 78, 2.2), (2.8, 81, .8), (4.1, 78, 1.4)],
    [(.4, 76, 1.5), (2.5, 74, 2.6)],
    [(0, 71, 1.2), (1.5, 74, .8), (2.8, 78, 1.3), (4.5, 76, 1)],
    [(.4, 73, 2.2), (3.1, 69, 2.2)],
    [(0, 74, .8), (1.25, 76, .8), (2.5, 78, 1.5), (4.5, 81, 1)],
    [(.3, 79, 2.2), (3.1, 78, .8), (4.4, 74, 1.1)],
    [(0, 76, 1.4), (2, 73, 1), (3.5, 71, 1.8)],
    [(.2, 69, 2.0), (3.6, 73, 1.6)],
    [(0, 74, 1.6), (2, 78, .8), (3.3, 76, 1.6), (5.15, 69, .55)],
    [(.1, 73, 1.2), (1.8, 74, 1.1), (3.3, 78, 2.0)],
    [(0, 71, 2), (2.8, 74, 1), (4.3, 79, 1.1)],
    [(.2, 78, 1.5), (2.3, 76, 2.3)],
    [(0, 74, 2.1), (2.8, 71, 1), (4.3, 74, 1.3)],
    [(.2, 76, 1.2), (2, 78, .8), (3.5, 79, 1.7)],
    [(0, 78, 1), (1.5, 76, 1), (3.2, 73, 2.0)],
    [(.2, 74, 3.3), (4.7, 69, .6)],
]

# Root, followed by an open, playable middle-register voicing.
CHORDS = {
    "D": (38, (57, 62, 66, 69, 76)),
    "D/F#": (42, (57, 62, 66, 69, 76)),
    "G": (43, (55, 62, 66, 71, 74)),
    "G/B": (35, (55, 62, 67, 71, 74)),
    "Bm": (35, (54, 61, 66, 69, 74)),
    "Em": (40, (55, 59, 62, 66, 74)),
    "A": (33, (57, 61, 64, 69, 71)),
    "Asus": (33, (57, 62, 64, 69, 71)),
    "F#m": (42, (54, 61, 64, 69, 73)),
}
HARMONIES = {
    "cover": ["D", "D/F#", "G", "G", "Bm", "Em", "Asus", "A",
              "Bm", "G", "Em", "A", "D/F#", "G", "Asus", "A",
              "D", "D/F#", "G", "Em", "Bm", "G", "A", "D"],
    "surface": ["D", "D/F#", "G", "Em", "Bm", "Em", "Asus", "A",
                "D/F#", "G", "Bm", "A", "D", "G", "Em", "Asus",
                "D", "D/F#", "G", "Em", "Bm", "G", "A", "D"],
    "depths": ["Bm", "Bm", "G", "Em", "F#m", "Em", "Asus", "F#m",
               "Bm", "Em", "G", "F#m", "Bm", "G", "Em", "F#m",
               "Bm", "D/F#", "G", "Em", "Bm", "Em", "Asus", "Bm"],
    "seam": ["D", "Asus", "G", "G", "Bm", "Em", "Asus", "A",
             "Bm", "G", "Em", "Asus", "D", "G", "Em", "A",
             "D", "D/F#", "G", "Em", "Bm", "G", "Asus", "D"],
    "night": ["Bm", "Bm", "Em", "Em", "F#m", "Em", "Asus", "F#m",
              "Bm", "G", "Em", "F#m", "Bm", "G", "Em", "F#m",
              "Bm", "Bm", "G", "Em", "Bm", "G", "F#m", "Bm"],
    "restored": ["D", "D/F#", "G", "Em", "Bm", "Em", "Asus", "A",
                 "D/F#", "G", "Bm", "A", "D", "G", "Em", "A",
                 "D", "D/F#", "G", "Em", "Bm", "G", "A", "D"],
}


def paper_pulse(rng: np.random.Generator, heavy: bool = False) -> np.ndarray:
    t = timebase(.15 if heavy else .12)
    noise = colored_noise(rng, len(t), 190, 2300 if heavy else 3700, .5)
    x = noise * np.exp(-t / (.035 if heavy else .019)) * .24
    if heavy:
        x += np.sin(2 * np.pi * (105 * t - 35 * t * t)) * np.exp(-t / .028) * .5
    return edge_fade(x, .004, .025)


def music(name: str) -> np.ndarray:
    rng = rng_for("music/" + name)
    canvas = Canvas(LOOP_SECONDS, loop=True)
    dark = name in ("depths", "night")
    sparse = name in ("night", "seam")
    for bar, chord_name in enumerate(HARMONIES[name]):
        root, chord = CHORDS[chord_name]
        now = bar * BAR
        phrase = bar // 8
        # A small dynamic arc within each sentence, not a tiled four-note loop.
        expression = (.88, .95, 1.03, .94, 1.04, 1.0, .94, .83)[bar % 8]
        bow_notes = (chord[0], chord[2], chord[3])
        if name == "night":
            bow_notes = (root + 12, chord[0])
        for j, pitch in enumerate(bow_notes):
            register = 12 if name == "seam" and j > 0 else 0
            gain = {"cover": .022, "surface": .025, "depths": .042,
                    "seam": .036, "night": .036, "restored": .040}[name]
            canvas.note("halo" if name in ("cover", "seam") else "bow",
                        pitch + register, now + .03 + j * .065,
                        1.65, gain * expression, (j - 1) * .46, rng)
        bass_gain = {"cover": .047, "surface": .083, "depths": .075,
                     "seam": .028, "night": .038, "restored": .095}[name]
        canvas.note("bass", root + (12 if name == "cover" else 0),
                    now + .025, 1.5, bass_gain * expression, -.12, rng)
        if name in ("surface", "restored") and bar % 4 != 3:
            canvas.note("bass", root + 7, now + 1.04, .8,
                        bass_gain * .46, -.08, rng)

        patterns = ((0, 2, 3, 1, 4, 2), (0, 3, 1, 4, 2, 3),
                    (1, 2, 4, 0, 3, 2), (0, 2, 3, 4, 2, 1))
        pattern = patterns[bar % 4]
        for eighth, index in enumerate(pattern):
            if name == "night" and eighth not in (1, 4):
                continue
            if name == "seam" and eighth not in (0, 2, 5):
                continue
            if name == "depths" and eighth not in (0, 2, 3, 5):
                continue
            inst = "felt" if dark or name == "cover" else "pluck"
            pitch = chord[index]
            if name == "seam":
                pitch += 12
            gain = {"cover": .056, "surface": .068, "depths": .047,
                    "seam": .042, "night": .028, "restored": .074}[name]
            articulation = (1, .66, .79, .89, .66, .72)[eighth]
            offset = eighth * EIGHTH + rng.uniform(-.009, .010)
            canvas.note(inst, pitch, now + .028 + offset, .4,
                        gain * articulation * expression,
                        -.38 + .15 * (index % 4), rng)
        if name == "restored":
            for j, pitch in enumerate((chord[1], chord[2], chord[4])):
                canvas.note("felt", pitch, now + 1.07 + j * .025, .65,
                            .039 * expression, .16 + j * .10, rng)

        melody = THEME[bar]
        for i, (offset, pitch, length) in enumerate(melody):
            if name == "night" and (bar % 2 or i > 0):
                continue
            if name == "depths" and i % 2 == 1:
                continue
            if name == "seam" and i == 1 and bar % 3:
                continue
            if name == "cover":
                inst = "box" if phrase != 1 else "felt"
                gain, transpose = .092, 0
            elif name == "surface":
                inst = "flute" if phrase == 1 else "felt"
                gain, transpose = .098 if inst == "felt" else .061, 0
            elif name == "depths":
                inst, gain, transpose = "flute", .070, -12
                length *= 1.5
            elif name == "seam":
                inst, gain, transpose = "box", .061, 12
            elif name == "night":
                inst, gain, transpose = "flute", .035, -12
                length = 3.8
            else:
                inst = "flute" if phrase != 1 else "felt"
                gain, transpose = .079 if inst == "flute" else .096, 0
            canvas.note(inst, pitch + transpose,
                        now + offset * EIGHTH + .04 + rng.uniform(-.012, .012),
                        length * EIGHTH, gain * expression * rng.uniform(.91, 1.05),
                        .17 if inst != "box" else .24, rng)
            if name == "restored" and i == 0 and bar % 2 == 0:
                canvas.note("box", pitch + 12, now + offset * EIGHTH + .085,
                            .6, .022 * expression, -.40, rng)

        # Short answering figures live in the gaps, rather than doubling melody.
        if bar % 4 == 3 and name not in ("night", "depths"):
            for j, pitch in enumerate((chord[2] + 12, chord[1] + 12)):
                canvas.note("pluck" if name != "seam" else "halo", pitch,
                            now + 1.55 + j * .20, .36, .024, -.52, rng)
        if name in ("surface", "restored"):
            for beat in (0, 1):
                canvas.add(paper_pulse(rng, beat == 0), now + .02 + beat,
                           (.020 if name == "surface" else .025) * expression,
                           -.27 if beat else .18)
            if bar % 2 == 0:
                canvas.add(paper_pulse(rng), now + 1.68, .009, .42)
        elif name == "depths" and bar % 4 == 0:
            canvas.add(paper_pulse(rng, True), now + .08, .015, -.3)

    wet = {"cover": .30, "surface": .26, "depths": .37,
           "seam": .48, "night": .30, "restored": .31}[name]
    decay = 3.2 if sparse else (2.7 if dark else 2.0)
    # The same 4.94 ms origin shift chooses a gentle sample slope in all six
    # arrangements while preserving their phase alignment and every reverb tail.
    return np.roll(room(canvas.audio, rng, wet, decay), -MUSIC_ORIGIN_SAMPLES, axis=0)


def noise_gesture(rng: np.random.Generator, seconds: float, low: float,
                  high: float, points: list[tuple[float, float]], pink: float = 0.5):
    t = timebase(seconds)
    noise = colored_noise(rng, len(t), low, high, pink)
    envelope = np.interp(t, [p[0] for p in points], [p[1] for p in points])
    return edge_fade(noise * envelope, .003, .012)


def chirp(seconds: float, start: float, finish: float, decay: float = .08) -> np.ndarray:
    t = timebase(seconds)
    phase = 2 * np.pi * (start * t + (finish - start) * t * t / (2 * seconds))
    x = (np.sin(phase) + .12 * np.sin(phase * 2)) * np.exp(-t / decay)
    return edge_fade(x, .004, .025)


def effect(name: str) -> np.ndarray:
    rng = rng_for("effects/" + name)
    seconds = EFFECT_SECONDS[name]
    stereo = name in ("pigment", "memory", "respawn", "rest", "chest")
    c = Canvas(seconds, stereo=stereo)
    if name.startswith("step_"):
        variant = int(name[-1])
        c.add(noise_gesture(rng, seconds, 140, 1800 + variant * 170,
                           [(0, 0), (.013, .5), (.038, .24), (seconds, 0)]), 0, .19)
        c.add(chirp(.09, 145 + variant * 12, 85, .025), .012, .042)
    elif name == "paint":
        c.add(noise_gesture(rng, seconds, 380, 4800,
                           [(0, 0), (.06, .20), (.19, .65), (.31, .27), (seconds, 0)]),
              0, .12)
        c.add(chirp(.20, 370, 570, .10), .15, .085)
        c.add(chirp(.10, 870, 550, .045), .29, .046)
    elif name == "erase":
        t = timebase(seconds)
        scrub = colored_noise(rng, len(t), 250, 3300, .7)
        envelope = np.sin(np.pi * t / seconds) ** 1.2
        envelope *= .32 + .68 * np.sin(2 * np.pi * 7.0 * t) ** 2
        c.add(edge_fade(scrub * envelope, .012, .035), 0, .085)
    elif name == "erased":
        c.add(noise_gesture(rng, seconds, 480, 6200,
                           [(0, 0), (.025, .6), (.12, .22), (seconds, 0)]), 0, .11)
        for at in (.055, .10, .17, .24):
            c.add(chirp(.07, rng.uniform(700, 1200), 310, .017), at, .025)
    elif name == "pigment":
        # The title theme's first gesture blossoms into four distinct colors.
        for i, pitch in enumerate((74, 78, 76, 81)):
            c.note("box", pitch, .025 + i * .22, .3, .13, -.5 + i / 3, rng)
            c.note("felt", pitch - 12, .025 + i * .22, .25, .045, .2, rng)
    elif name == "pickup":
        c.add(chirp(.17, 730, 1100, .050), .005, .13)
        c.add(chirp(.12, 1460, 1500, .035), .07, .036)
    elif name == "chest":
        t = timebase(.35)
        creak = np.sin(2 * np.pi * (170 * t + 35 * t * t + .7 * np.sin(36 * t)))
        creak += .35 * colored_noise(rng, len(t), 120, 1800, .8)
        c.add(edge_fade(creak * np.sin(np.pi * t / .35) ** 2), .015, .075, -.2)
        for i, pitch in enumerate((78, 81, 86)):
            c.note("box", pitch, .26 + i * .09, .14, .083, -.2 + .2 * i, rng)
    elif name == "build":
        for i, at in enumerate((.015, .16, .32)):
            c.add(paper_pulse(rng, True), at, (.22, .18, .25)[i])
            c.add(chirp(.12, 290 + i * 75, 230 + i * 70, .026), at, .055)
        c.add(noise_gesture(rng, .20, 420, 4200,
                           [(0, 0), (.05, .38), (.11, .16), (.20, 0)]), .20, .09)
    elif name == "fire_light":
        c.add(noise_gesture(rng, .17, 700, 5700,
                           [(0, 0), (.03, .65), (.1, .38), (.17, 0)]), .005, .11)
        c.add(noise_gesture(rng, .42, 55, 720,
                           [(0, 0), (.08, .9), (.20, .5), (.42, 0)], 1.0), .13, .10)
        for at in (.18, .28, .41):
            c.add(paper_pulse(rng), at, .055)
    elif name == "page_turn":
        c.add(noise_gesture(rng, seconds, 320, 5900,
                           [(0, 0), (.04, .18), (.15, .64), (.24, .31),
                            (.30, .52), (.40, .09), (seconds, 0)]), 0, .10)
        c.add(chirp(.18, 145, 95, .07), .26, .034)
    elif name == "talk":
        for at, f in ((.007, 370), (.094, 465)):
            c.add(chirp(.10, f, f * 1.07, .035), at, .11)
            c.add(noise_gesture(rng, .08, 550, 1300,
                               [(0, 0), (.02, .2), (.08, 0)]), at, .03)
    elif name == "ui_tap":
        c.add(chirp(seconds, 620, 520, .017), 0, .12)
        c.add(paper_pulse(rng)[:len(c.audio)], 0, .023)
    elif name == "denied":
        for at, f in ((.006, 220), (.086, 184)):
            c.add(chirp(.085, f, f * .91, .024), at, .115)
            c.add(paper_pulse(rng), at, .055)
    elif name == "eat":
        for at in (.01, .12, .23):
            c.add(noise_gesture(rng, .09, 230, 3200,
                               [(0, 0), (.012, .65), (.04, .20), (.09, 0)]), at, .10)
            c.add(chirp(.07, 270, 170, .025), at, .043)
    elif name == "rest":
        c.add(noise_gesture(rng, .73, 180, 2200,
                           [(0, 0), (.14, .36), (.38, .18), (.73, 0)], 1), .015, .067)
        c.note("box", 78, .08, .3, .086, -.24, rng)
        c.note("felt", 74, .24, .35, .13, .25, rng)
    elif name == "memory":
        for i, (pitch, at) in enumerate(((74, .025), (78, .32), (76, .62), (69, 1.02))):
            c.note("felt", pitch, at, .35, .15, -.30 + i * .2, rng)
            c.note("box", pitch + 12, at + .015, .2, .043, .25 - i * .15, rng)
    elif name == "hurt":
        c.add(noise_gesture(rng, seconds, 170, 3500,
                           [(0, 0), (.013, .68), (.07, .40), (.12, .14),
                            (.15, .24), (seconds, 0)]), 0, .125)
        c.add(chirp(.13, 240, 110, .04), .015, .085)
    elif name == "respawn":
        c.add(noise_gesture(rng, 1.15, 270, 2900,
                           [(0, 0), (.18, .12), (.50, .04), (.83, .19), (1.15, 0)],
                           1), .025, .047, -.2)
        for i, pitch in enumerate((81, 78, 74, 69, 74, 78, 86)):
            c.note("box", pitch, .015 + i * .155, .18,
                   .07 if i < 4 else .085, -.5 + i / 6, rng)
    else:
        raise ValueError(name)
    # One-shot tails end at zero; no circular reverb can leak before an action.
    for ch in range(c.audio.shape[1]):
        c.audio[:, ch] = edge_fade(c.audio[:, ch], .002, min(.16, seconds * .23))
    return c.audio


def ambience(name: str) -> np.ndarray:
    rng = rng_for("ambience/" + name)
    seconds = AMBIENCE_SECONDS[name]
    c = Canvas(seconds, stereo=False, loop=True)
    t = timebase(seconds)
    if name == "fire":
        bed = colored_noise(rng, len(t), 50, 1900, 1.2)
        bed *= .68 + .16 * np.sin(2 * np.pi * 3 * t / seconds) + .13 * np.sin(2 * np.pi * 7 * t / seconds)
        c.add(bed, 0, .024)
        for _ in range(47):
            duration = rng.uniform(.025, .13)
            ct = timebase(duration)
            crackle = colored_noise(rng, len(ct), 500, rng.uniform(2300, 5500))
            crackle *= np.exp(-ct / (duration * .20))
            c.add(edge_fade(crackle, .0018, .009), rng.uniform(0, seconds),
                  rng.uniform(.019, .061))
        for at in (1.3, 3.85, 7.2, 8.5):
            c.add(chirp(.16, 125, 65, .036), at, .03)
    elif name == "ink":
        bed = colored_noise(rng, len(t), 38, 750, 1.2)
        bed *= .75 + .20 * np.sin(2 * np.pi * 2 * t / seconds)
        c.add(bed, 0, .026)
        for _ in range(21):
            at = rng.uniform(0, seconds)
            duration = rng.uniform(.12, .32)
            c.add(chirp(duration, rng.uniform(125, 230), rng.uniform(60, 105), .06),
                  at, rng.uniform(.018, .048))
        c.add(colored_noise(rng, len(t), 550, 1800, 1), 0, .004)
    else:
        breath = colored_noise(rng, len(t), 130, 2200, 1.3)
        breath *= .65 + .22 * np.sin(2 * np.pi * 2 * t / seconds) + .09 * np.sin(2 * np.pi * 5 * t / seconds)
        c.add(breath, 0, .024)
        for at, pitch in ((1.4, 87), (4.6, 83), (8.3, 90), (11.8, 85)):
            tiny = chirp(.22, hz(pitch), hz(pitch) * .98, .055)
            c.add(tiny, at, .0065)
            c.add(tiny, at + .29, .003)
    return c.audio


def master(audio: np.ndarray, kind: str, name: str) -> np.ndarray:
    audio = audio - np.mean(audio, axis=0)
    rms = float(np.sqrt(np.mean(audio ** 2)))
    if kind == "music":
        target = {"cover": .086, "surface": .092, "depths": .079,
                  "seam": .069, "night": .055, "restored": .098}[name]
        gain = min(target / max(rms, 1e-12), .77 / max(np.max(np.abs(audio)), 1e-12))
    elif kind == "ambience":
        target = {"fire": .026, "ink": .024, "night_air": .017}[name]
        gain = min(target / max(rms, 1e-12), .40 / max(np.max(np.abs(audio)), 1e-12))
    else:
        target = .070
        if name.startswith("step_"):
            target = .038
        elif name in ("ui_tap", "talk", "denied"):
            target = .049
        elif name in ("memory", "rest", "respawn"):
            target = .060
        gain = min(target / max(rms, 1e-12), .66 / max(np.max(np.abs(audio)), 1e-12))
    audio *= gain
    # Gentle analogue-style peak rounding, with ample headroom for game mixing.
    audio = .88 * np.tanh(audio / .88)
    if kind == "effects":
        for ch in range(audio.shape[1]):
            audio[:, ch] = edge_fade(audio[:, ch], .001, .005)
    return audio


def save_wav(path: Path, audio: np.ndarray) -> dict:
    path.parent.mkdir(parents=True, exist_ok=True)
    pcm = np.rint(audio * 32767).astype("<i2")
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(audio.shape[1])
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(pcm.tobytes())
    decoded = pcm.astype(np.float64) / 32768
    return {
        "duration_seconds": round(len(pcm) / RATE, 6),
        "sample_rate": RATE,
        "channels": audio.shape[1],
        "bits_per_sample": 16,
        "frames": len(pcm),
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "peak": round(float(np.max(np.abs(decoded))), 8),
        "rms": round(float(np.sqrt(np.mean(decoded ** 2))), 8),
        "seam_jump": round(float(np.max(np.abs(decoded[0] - decoded[-1]))), 8),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "assets/audio")
    parser.add_argument("--only", nargs="+", help="Render selected asset basenames only.")
    args = parser.parse_args()
    names = set(MUSIC_NAMES) | set(EFFECT_SECONDS) | set(AMBIENCE_SECONDS)
    if args.only and not set(args.only) <= names:
        parser.error("Unknown asset name(s): " + ", ".join(sorted(set(args.only) - names)))
    manifest_path = args.output / "manifest.json"
    existing = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
    entries = {entry["path"]: entry for entry in existing.get("assets", [])}
    for kind, labels, renderer in (
        ("music", MUSIC_NAMES, music),
        ("effects", EFFECT_SECONDS, effect),
        ("ambience", AMBIENCE_SECONDS, ambience),
    ):
        for name in labels:
            if args.only and name not in args.only:
                continue
            print(f"Rendering {kind}/{name}...", flush=True)
            audio = master(renderer(name), kind, name)
            relative = f"{kind}/{name}.wav"
            metrics = save_wav(args.output / relative, audio)
            entries[relative] = {"path": relative, "kind": kind,
                                 "loop": kind != "effects", **metrics}
            print(f"  {metrics['duration_seconds']:.2f}s  peak {metrics['peak']:.3f}"
                  f"  RMS {metrics['rms']:.3f}  seam {metrics['seam_jump']:.5f}", flush=True)
    manifest = {
        "format_version": 1,
        "title": "Notebook Quest: El desborde — original acoustic miniatures",
        "license": "MIT",
        "authorship": "Original composition and offline physical/modal synthesis; no sampled recordings.",
        "generator": "tools/generate_audio.py",
        "seed": SEED,
        "sample_rate": RATE,
        "music_grid": {"meter": "6/8", "dotted_quarter_bpm": 60, "bars": BARS,
                       "loop_seconds": LOOP_SECONDS, "tonal_family": "D major / B minor",
                       "origin_offset_samples": MUSIC_ORIGIN_SAMPLES},
        "track_moods": MOODS,
        "assets": [entries[path] for path in sorted(entries)],
    }
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
    print(f"Wrote {len(entries)} manifest entries to {manifest_path}", flush=True)


if __name__ == "__main__":
    main()
