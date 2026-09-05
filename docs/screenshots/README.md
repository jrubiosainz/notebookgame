# El desborde: iPhone screenshots

These are actual `simctl` captures from the iPhone 17 Pro simulator, at
1206 x 2622 pixels. The source is version 2.1 (build 3), commit
`1d0050fb29e08766de4e85a85b9dd24e05e37c53`, captured in
[workflow run 33959915583](https://github.com/jrubiosainz/notebookgame/actions/runs/33959915583).
The run also builds the unsigned iOS Release app. These are not physical-device
captures or a TestFlight distribution.

| Capture | What it shows |
| --- | --- |
| 01-cover | Illustrated cover, original paper buttons and Nib without a decorative eraser |
| 02-prologue | The opening story |
| 03-first-pigment | Full-screen exploration, original joystick and Nib's directional resting pose |
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

`nib-motion.gif` is a separate native macOS recording of the **same SpriteKit
character animator** used on iPhone. It shows four walking directions plus
painting and erasing, with held tools put away after each gesture. It is a pose
showcase, not an iPhone screen recording. Reproduce it with the native preview's
`--animate <output.gif>` option.

To regenerate the iPhone images, run the **iPhone adventure** workflow on this
branch and download its `iphone-screenshots` artifact. A dependency-free native
macOS preview of the same renderer is documented in the repository README.
