# El desborde: iPhone screenshots

These are actual `simctl` captures from the iPhone 17 Pro simulator, at
1206 x 2622 pixels. The source is commit `fc891070f285e9f4bfd7f016546cfc91afce193a`,
captured in [workflow run 33950749012](https://github.com/jrubiosainz/notebookgame/actions/runs/33950749012).
The run also builds the unsigned iOS Release app. These are not physical-device
captures or a TestFlight distribution.

| Capture | What it shows |
| --- | --- |
| 01-cover | Illustrated cover and the original paper button style |
| 02-prologue | The opening story |
| 03-first-pigment | Full-screen exploration, original joystick and unpainted chest |
| 04-brown-awakening | The same chest after applying brown |
| 05-a-light-in-the-ink | Night, firelight, shelter, walls and paths |
| 06-notebook-atlas | Connected pages across three depths |
| 07-the-violet-seam | A deeper page and the next pigment |
| 08-the-workbench | Construction recipes, shown only when opened |
| 09-the-bag | Supplies, local map, objectives and secondary actions |

`overview.png` simply arranges three of these unaltered screenshots. Reproduce
the gallery using `swift tools/contact_sheet.swift <downloaded-captures> <output.png>`.

The captures use Debug-only fixtures from `AdventurePreviewFixtures`: the opening
and first page are fresh states; later scenes seed reachable progress and a camp
to make visual comparisons reproducible. The actual campaign is separately
walked through using the game engine's movement, interaction and survival APIs.
Fixtures neither load nor overwrite the player's adventure save.

To regenerate the iPhone images, run the **iPhone adventure** workflow on this
branch and download its `iphone-screenshots` artifact. A dependency-free native
macOS preview of the same renderer is documented in the repository README.
