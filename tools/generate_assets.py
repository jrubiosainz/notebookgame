#!/usr/bin/env python3
"""Generate every NotebookGame asset with Azure OpenAI gpt-image-2.

    python tools/generate_assets.py                # everything that is missing
    python tools/generate_assets.py --only enemies # one category
    python tools/generate_assets.py --force        # regenerate even if cached
    python tools/generate_assets.py --list         # show the catalogue

Configuration comes from environment variables (or a .env file at the repo
root, which is git-ignored):

    AZURE_OPENAI_ENDPOINT   https://<resource>.cognitiveservices.azure.com/
    AZURE_OPENAI_KEY        the resource key
    IMAGE_DEPLOYMENT        the gpt-image-2 deployment name

Generations are cached by a hash of the exact prompt plus generation settings,
so re-running is cheap and only genuinely changed assets cost money.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from manifest import ALL_ASSETS, Asset  # noqa: E402
from postprocess import process  # noqa: E402
from style import build_prompt  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "assets"
CACHE = ROOT / ".assetcache"
API_VERSION = "2025-04-01-preview"
MAX_WORKERS = 2          # matches the provisioned deployment capacity
MAX_RETRIES = 5


# --------------------------------------------------------------------------
# Config
# --------------------------------------------------------------------------
def load_env() -> dict[str, str]:
    # A repo-local .env is authoritative and deliberately overrides ambient
    # shell variables. Developers commonly have a stale AZURE_OPENAI_ENDPOINT
    # exported for some other project, and silently inheriting it produces a
    # very confusing wall of 404s.
    for candidate in (ROOT / ".env", ROOT / ".env.local"):
        if candidate.exists():
            for line in candidate.read_text(encoding="utf-8-sig").splitlines():
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    k, v = line.split("=", 1)
                    os.environ[k.strip()] = v.strip()

    missing = [
        k for k in ("AZURE_OPENAI_ENDPOINT", "AZURE_OPENAI_KEY", "IMAGE_DEPLOYMENT")
        if not os.environ.get(k)
    ]
    if missing:
        sys.exit(
            "Missing configuration: " + ", ".join(missing) + "\n"
            "Set them in the environment or in a .env file at the repo root.\n"
            "See docs/ASSETS.md."
        )
    return {
        "endpoint": os.environ["AZURE_OPENAI_ENDPOINT"].rstrip("/"),
        "key": os.environ["AZURE_OPENAI_KEY"],
        "deployment": os.environ["IMAGE_DEPLOYMENT"],
    }


# --------------------------------------------------------------------------
# Generation
# --------------------------------------------------------------------------
def request_image(cfg: dict[str, str], prompt: str, asset: Asset) -> bytes:
    """Call the image endpoint, retrying on throttling and transient errors."""
    url = (
        f"{cfg['endpoint']}/openai/deployments/{cfg['deployment']}"
        f"/images/generations?api-version={API_VERSION}"
    )
    body: dict[str, object] = {
        "prompt": prompt,
        "n": 1,
        "size": asset.size,
        "quality": asset.quality,
        "output_format": "png",
    }
    if asset.transparent:
        body["background"] = "transparent"

    payload = json.dumps(body).encode()
    headers = {"api-key": cfg["key"], "Content-Type": "application/json"}

    delay = 8.0
    last: Exception | None = None
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            req = urllib.request.Request(url, data=payload, headers=headers)
            with urllib.request.urlopen(req, timeout=600) as resp:
                data = json.loads(resp.read())["data"][0]
            if "b64_json" in data:
                return base64.b64decode(data["b64_json"])
            with urllib.request.urlopen(data["url"], timeout=300) as img:
                return img.read()
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode(errors="replace")[:400]
            last = RuntimeError(f"HTTP {exc.code}: {detail}")
            if exc.code not in (408, 429, 500, 502, 503, 504):
                raise last from exc
        except Exception as exc:  # noqa: BLE001 - network layer is broad by nature
            last = exc

        if attempt < MAX_RETRIES:
            print(f"    retry {attempt}/{MAX_RETRIES - 1} for {asset.key} in {delay:.0f}s")
            time.sleep(delay)
            delay = min(delay * 2, 120)

    raise RuntimeError(f"{asset.key} failed after {MAX_RETRIES} attempts: {last}")


def fingerprint(prompt: str, asset: Asset) -> str:
    blob = json.dumps(
        {
            "prompt": prompt,
            "size": asset.size,
            "quality": asset.quality,
            "transparent": asset.transparent,
        },
        sort_keys=True,
    )
    return hashlib.sha256(blob.encode()).hexdigest()[:16]


def generate_one(cfg: dict[str, str], asset: Asset, force: bool) -> str:
    prompt = build_prompt(asset.subject, face=asset.face, sheet=asset.sheet)
    digest = fingerprint(prompt, asset)

    out = ASSETS / f"{asset.key}.png"
    stamp = CACHE / f"{asset.key.replace('/', '__')}.{digest}"
    raw = CACHE / f"{asset.key.replace('/', '__')}.{digest}.raw.png"

    if not force and out.exists() and stamp.exists():
        return f"cached   {asset.key}"

    if force or not raw.exists():
        blob = request_image(cfg, prompt, asset)
        raw.parent.mkdir(parents=True, exist_ok=True)
        raw.write_bytes(blob)
    else:
        blob = raw.read_bytes()

    out.parent.mkdir(parents=True, exist_ok=True)
    process(
        blob,
        out,
        trim=asset.trim,
        transparent=asset.transparent,
        slice_grid=asset.sheet,
        slice_to=(ASSETS / asset.slice_to) if asset.slice_to else None,
    )
    stamp.write_text(prompt, encoding="utf-8")
    return f"created  {asset.key}"


# --------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------
def main() -> int:
    ap = argparse.ArgumentParser(description="Generate NotebookGame art with gpt-image-2.")
    ap.add_argument("--only", help="limit to a category prefix, e.g. enemies or props/rock")
    ap.add_argument("--force", action="store_true", help="regenerate even when cached")
    ap.add_argument("--list", action="store_true", help="print the catalogue and exit")
    ap.add_argument("--workers", type=int, default=MAX_WORKERS)
    args = ap.parse_args()

    selected = [a for a in ALL_ASSETS if not args.only or a.key.startswith(args.only)]

    if args.list:
        for a in selected:
            flags = []
            if a.sheet:
                flags.append(f"sheet {a.sheet[0]}x{a.sheet[1]}")
            if a.transparent:
                flags.append("alpha")
            print(f"{a.key:38} {a.size:10} {' '.join(flags)}")
        print(f"\n{len(selected)} assets")
        return 0

    if not selected:
        print(f"No assets match --only {args.only!r}")
        return 1

    cfg = load_env()
    CACHE.mkdir(parents=True, exist_ok=True)
    print(f"Generating {len(selected)} assets with {cfg['deployment']} "
          f"({args.workers} in parallel)\n")

    failures: list[str] = []
    done = 0
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        futures = {pool.submit(generate_one, cfg, a, args.force): a for a in selected}
        for fut in as_completed(futures):
            asset = futures[fut]
            done += 1
            try:
                print(f"[{done:3}/{len(selected)}] {fut.result()}")
            except Exception as exc:  # noqa: BLE001
                failures.append(asset.key)
                print(f"[{done:3}/{len(selected)}] FAILED   {asset.key}: {exc}")

    if failures:
        print(f"\n{len(failures)} failed: {', '.join(failures)}")
        print("Re-run the same command; completed assets are cached and will be skipped.")
        return 1

    print(f"\nAll {len(selected)} assets are up to date in {ASSETS}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
