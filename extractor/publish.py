"""Post a converted recipe to the Recipe Box app.

Usage: python extractor/publish.py work/<video_id> [--overwrite]

Merges meta.json + transcript.txt + recipe.json from the job folder and
POSTs them (with the chosen cover frame) to <RECIPES_URL>/api/recipes.

Config comes from the environment or extractor/.env:
  RECIPES_URL        e.g. https://mendicant.com   (default http://localhost:3000)
  RECIPES_API_TOKEN  bearer token matching the app's recipes_api_token

On success the job folder is deleted; prints the recipe URL.
"""

import argparse
import json
import os
import shutil
import sys
from pathlib import Path

import requests  # installed with yt-dlp[default]


def load_env() -> None:
    env_file = Path(__file__).with_name(".env")
    if env_file.exists():
        for line in env_file.read_text(encoding="utf-8").splitlines():
            key, sep, value = line.partition("=")
            if sep and not key.strip().startswith("#"):
                os.environ.setdefault(key.strip(), value.strip())


def build_payload(job: Path) -> tuple[dict, Path | None]:
    meta = json.loads((job / "meta.json").read_text(encoding="utf-8"))
    recipe = json.loads((job / "recipe.json").read_text(encoding="utf-8"))
    transcript = (job / "transcript.txt").read_text(encoding="utf-8").strip()

    payload = {
        **{k: recipe.get(k) for k in ("title", "servings", "total_time", "ingredients", "steps", "notes")},
        "source_url": meta.get("canonical_url") or meta["source_url"],
        "video_id": meta["video_id"],
        "creator": meta.get("creator"),
        "caption": meta.get("caption"),
        "transcript": transcript,
    }
    cover_name = recipe.get("cover_frame")
    cover = job / "frames" / cover_name if cover_name else None
    return payload, cover if cover and cover.exists() else None


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("job", type=Path)
    ap.add_argument("--overwrite", action="store_true")
    ap.add_argument("--keep", action="store_true", help="keep the job folder after posting")
    args = ap.parse_args()

    load_env()
    base = os.environ.get("RECIPES_URL", "http://localhost:3000").rstrip("/")
    token = os.environ.get("RECIPES_API_TOKEN")
    if not token:
        sys.exit("RECIPES_API_TOKEN is not set (environment or extractor/.env)")

    payload, cover = build_payload(args.job)
    data = {"payload": json.dumps(payload, ensure_ascii=False)}
    if args.overwrite:
        data["overwrite"] = "1"

    files = {"cover": (cover.name, cover.open("rb"), "image/jpeg")} if cover else None
    try:
        resp = requests.post(f"{base}/api/recipes", headers={"Authorization": f"Bearer {token}"},
                             data=data, files=files, timeout=60)
    finally:
        if files:
            files["cover"][1].close()

    body = resp.json() if resp.headers.get("content-type", "").startswith("application/json") else {}
    if resp.status_code == 201:
        if not args.keep:
            shutil.rmtree(args.job)
        print(body["url"])
    elif resp.status_code == 409:
        sys.exit(f"ALREADY EXISTS: {body.get('url')} (rerun with --overwrite to replace)")
    else:
        sys.exit(f"HTTP {resp.status_code}: {body.get('error') or resp.text[:500]}")


if __name__ == "__main__":
    main()
