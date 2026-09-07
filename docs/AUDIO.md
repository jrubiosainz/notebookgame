# El desborde — original audio

The score and sound effects are original works authored for **Notebook Quest:
El desborde**. Every sample is synthesized offline from the composition and
instrument definitions in `tools/generate_audio.py`: there are no downloaded
recordings, copyrighted melodies, soundfonts, generative cloud services, or
external audio assets. The code, compositions, and generated audio are available
under the same **MIT license** as the repository.

## Musical direction

A small acoustic ensemble inhabits the paper world: paired, slightly detuned
felt-piano strings; thumbed string and wooden-body modes; soft inharmonic
music-box tines; breath-driven flute; and a warm, slowly bowed harmonic layer.
Paper-brush percussion stays below the melodic instruments. The original
“a line becomes a path” theme opens D–F♯–E–A, but develops through three
eight-bar sentences with answering figures, altered rhythms, register changes,
inversions, and a return. It is not a tiled four-note sample.

All six stereo tracks are **48 seconds, 24 bars of 6/8 at dotted-quarter
60 BPM** (quarter-note 90 BPM), in the shared D-major/B-minor tonal family:

| File | Arrangement |
| --- | --- |
| `music/cover.wav` | Hopeful storybook music box, with a felt-key middle section. |
| `music/surface.wav` | Gentle exploratory piano, plucked arpeggios, flute and paper brush. |
| `music/depths.wav` | Lower-register flute and wood resonances over suspended minor harmony. |
| `music/seam.wav` | Weightless high tines, widely spaced harmonics, and a long airy room. |
| `music/night.wav` | Hushed low strings and occasional distant flute; tension without horror stings. |
| `music/restored.wav` | The theme resolves into a fuller piano/flute arrangement with upper box accents. |

Sustains and releases wrap around the song buffer; stereo room reflections use
**circular convolution**. There is no end-of-track fade, silent padding, or
truncated reverb. Small timing and velocity differences are seeded, not random
between builds. All tracks share a 109-sample (4.94 ms) circular origin offset,
chosen for a gentle slope at every join without changing their relative phase.
Levels retain headroom; these are not loudness-maximized masters.
Music has deliberately different but neighboring RMS levels, with night quieter.
Keep playback phase aligned when crossfading between arrangements, or use a
1.5–3-second crossfade. The source files themselves contain no start/end fade.

## Runtime assets

All WAVs are little-endian, uncompressed **16-bit PCM at 22,050 Hz**.
There are **29 files**, approximately **28 MB** total:

- Six stereo music loops.
- Twenty effects: `step_1`, `step_2`, `step_3`, `paint`, `erase`, `erased`,
  `pigment`, `pickup`, `chest`, `build`, `fire_light`, `page_turn`, `talk`,
  `ui_tap`, `denied`, `eat`, `rest`, `memory`, `hurt`, `respawn`.
  Small physical gestures are mono; discoveries, memories and transitions have
  restrained stereo placement. Every effect begins and ends at zero.
- Three mono ambient loops: `ambience/fire.wav` (10 seconds),
  `ambience/ink.wav` and `ambience/night_air.wav` (14 seconds each). These use
  filtered periodic noise, irregular soft crackles, low liquid bubbles, and
  distant tiny textures rather than recognizable field recordings.

Effects combine noise with tactile envelopes and damped resonances: paint has a
brush sweep and liquid tint; erase uses modulated rubber friction; erased ink
fizzes away; footsteps compress and release paper; page turns rustle and flex.
Discovery and memory cues quote the original score. The three footstep variants
have matched RMS to avoid inconsistent walking volume.

`assets/audio/manifest.json` lists exact paths, formats, lengths, frame counts,
loop flags, peak/RMS measurements, seam jumps and SHA-256 hashes. Paths are
relative to `assets/audio/`. It contains no timestamps or machine-specific data.
The generator does not touch native code or project integration.

## Reproduce and verify

Use Python 3.10+ (on this machine, `/opt/homebrew/bin/python3`, not the old system
Python). Rendering requires only NumPy; validation without regeneration uses
only the standard library. Install NumPy into your existing Python environment
or a local virtual environment if `import numpy` fails.
The delivered set was rendered with **CPython 3.14.7 and NumPy 2.5.2**.

```sh
/opt/homebrew/bin/python3 tools/generate_audio.py
/opt/homebrew/bin/python3 tools/validate_audio.py
/opt/homebrew/bin/python3 tools/validate_audio.py --reproducibility
```

`--reproducibility` validates, regenerates all assets **in place**, and verifies
identical manifest and WAV hashes. Keep the same Python/NumPy/platform toolchain
for strict byte equality; floating-point library differences on another platform
may change the least-significant PCM bit without changing the composition.
Individual assets can be rerendered with, for example,
`tools/generate_audio.py --only surface paint`; the manifest retains other entries.
`--output assets/audio-review` can render an alternate comparison set.

The validator enforces the exact 29-file contract, required duration ranges,
stereo music, consistent music length, sample format, no clipping, non-silence,
comfortable RMS, low DC, music/ambient loop jumps below 0.02, silent-free music
windows, one-shot zero endpoints, all manifest hashes, and a 30 MB WAV budget.
No extra test runner or build framework is involved.
