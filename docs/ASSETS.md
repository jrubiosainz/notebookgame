# Asset pipeline

Every image in the game comes from Azure OpenAI `gpt-image-2`. Nothing is drawn
by hand, and nothing is downloaded from anywhere else.

## Prerequisites

- Python 3.10+
- An Azure OpenAI / AI Services resource with a **`gpt-image-2`** deployment

```bash
pip install -r tools/requirements.txt
```

## Configuration

Copy the template and fill it in:

```bash
cp .env.example .env.local
```

```ini
AZURE_OPENAI_ENDPOINT=https://<your-resource>.cognitiveservices.azure.com
AZURE_OPENAI_KEY=<key>
IMAGE_DEPLOYMENT=<your gpt-image-2 deployment name>
```

`.env.local` is git-ignored. Do not commit it.

If you have the Azure CLI, you can pull both values straight out of the
resource:

```bash
az cognitiveservices account show      -n <resource> -g <rg> --query properties.endpoint -o tsv
az cognitiveservices account keys list -n <resource> -g <rg> --query key1 -o tsv
```

To find deployments that can actually serve this model:

```bash
az cognitiveservices account deployment list -n <resource> -g <rg> \
  --query "[?contains(properties.model.name,'image')].{dep:name,model:properties.model.name,cap:sku.capacity}" -o table
```

> **`.env.local` wins over your shell.** This bit us: the pipeline originally
> used `os.environ.setdefault`, and a pre-existing global `AZURE_OPENAI_ENDPOINT`
> on the machine silently beat the repo config, producing 53 identical 404s.
> `load_env()` now *overwrites* ambient variables and reads the file as
> `utf-8-sig` (PowerShell writes a BOM). Please don't revert that.

## Running it

```bash
python tools/generate_assets.py
```

Roughly 53 assets. Expect **2–3 hours** at `quality: "high"` with a
capacity-2 deployment; the concurrency (`MAX_WORKERS`) is set to match, and
raising it past your deployment's capacity just buys you 429s.

Flags:

| Flag | Effect |
| --- | --- |
| `--list` | Print every asset, its category, and whether it is already generated |
| `--only <key>` | Generate one asset, or one whole category |
| `--force` | Ignore the cache and regenerate |
| `--workers N` | Override concurrency |

It is safe to interrupt and re-run. Each asset caches a hash of its final
prompt in `assets/.cache.json`; unchanged assets are skipped, so a re-run only
picks up failures and edits. Failures are reported at the end with their HTTP
status — re-running is the retry mechanism.

## What gets produced

```
assets/
  characters/   hero idle + walk cycles (down / up / side), sliced into frames
  enemies/      the bestiary, one image each, plus the boss
  npcs/         villagers, the vendor, the sage
  props/        trees, rocks, bushes, chests, signs, tents, crates
  tiles/        paper, path, sand, stone, water — square, seamless-ish
  ui/           hearts, ink drop, coin, buttons, panel frame, joystick
  title/        logo, backdrop, app icon source
```

Animation sheets arrive as one wide strip and are cut into
`assets/characters/<name>/frame_0.png`, `frame_1.png`, …

## The app icon

App Store icons may not contain alpha, but everything the pipeline produces is
transparent by design. So there is a separate flattening step:

```bash
python tools/make_icon.py
```

It composites `assets/title/app_icon.png` onto the paper colour at 1024×1024 and
writes it into `Assets.xcassets/AppIcon.appiconset/`.

## How Swift finds all this

`assets/` is added to the Xcode target as a **folder reference** (blue folder),
not a group. The directory structure therefore survives into the app bundle, and
`Core/Art.swift` resolves paths against `Bundle.main.resourceURL`:

```swift
Art.texture("tree_pine", in: "props")      // assets/props/tree_pine.png
Art.frames("nib_walk_down", in: "characters")  // assets/characters/nib_walk_down/frame_*.png
```

Which means the Python side and the Swift side share one convention and need no
manifest, no codegen, and no manual re-adding of files to the project.

## Cost note

`quality: "high"` is not cheap, and a full run is ~53 images. During
development, drop `quality` to `"medium"` in `tools/manifest.py` for iteration
and only do a `"high"` pass when the style is settled.
