"""Turn a TikTok URL into text artifacts a recipe can be written from.

Usage: python extractor/extract.py <url> [--out work] [--frames 12] [--keep-media]

Writes work/<video_id>/:
  meta.json       source url, creator, caption, duration, word count, needs_visual
  transcript.txt  faster-whisper transcript
  frames/*.jpg    evenly spaced stills (on-screen text, quantities, plating)

The downloaded video is deleted afterwards unless --keep-media is passed.
Prints the path to meta.json on success.
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

import yt_dlp
from yt_dlp.networking.impersonate import ImpersonateTarget

LOW_SPEECH_WORDS = 25
WHISPER_MODEL = "small"


def find_ffmpeg() -> str:
    exe = shutil.which("ffmpeg")
    if exe:
        return exe
    # winget installs a link here, but existing shells may not have it on PATH yet
    link = Path(os.environ.get("LOCALAPPDATA", "")) / "Microsoft/WinGet/Links/ffmpeg.exe"
    if link.exists():
        return str(link)
    sys.exit("ffmpeg not found on PATH")


def download(url: str, dest: Path, ffmpeg: str) -> tuple[dict, Path]:
    opts = {
        # smallest mp4 that still has readable on-screen text
        "format": "best[height<=720][ext=mp4]/best[ext=mp4]/best",
        "outtmpl": str(dest / "%(id)s.%(ext)s"),
        "ffmpeg_location": str(Path(ffmpeg).parent),
        "quiet": True,
        "no_warnings": True,
        "noprogress": True,
        # TikTok rejects plain requests; needs yt-dlp[curl-cffi]
        "impersonate": ImpersonateTarget("chrome"),
    }
    # yt-dlp follows vt.tiktok.com / vm.tiktok.com redirects itself
    with yt_dlp.YoutubeDL(opts) as ydl:
        info = ydl.extract_info(url, download=True)
        path = Path(ydl.prepare_filename(info))
    return info, path


def transcribe(media: Path) -> str:
    from faster_whisper import WhisperModel

    model = WhisperModel(WHISPER_MODEL, device="cpu", compute_type="int8")
    segments, _ = model.transcribe(str(media), vad_filter=True)
    return " ".join(s.text.strip() for s in segments).strip()


def extract_frames(media: Path, out_dir: Path, duration: float, count: int, ffmpeg: str) -> list[str]:
    out_dir.mkdir(parents=True, exist_ok=True)
    interval = max(duration / count, 1.0) if duration else 3.0
    subprocess.run(
        [ffmpeg, "-loglevel", "error", "-y", "-i", str(media),
         "-vf", f"fps=1/{interval:.3f},scale=720:-2",
         "-frames:v", str(count), "-q:v", "3",
         str(out_dir / "frame_%02d.jpg")],
        check=True,
    )
    return sorted(p.name for p in out_dir.glob("frame_*.jpg"))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("url")
    ap.add_argument("--out", default="work")
    ap.add_argument("--frames", type=int, default=12)
    ap.add_argument("--keep-media", action="store_true")
    args = ap.parse_args()

    ffmpeg = find_ffmpeg()
    root = Path(args.out)
    tmp = root / "_download"
    tmp.mkdir(parents=True, exist_ok=True)

    info, media = download(args.url, tmp, ffmpeg)
    job = root / info["id"]
    job.mkdir(parents=True, exist_ok=True)

    try:
        transcript = transcribe(media)
        (job / "transcript.txt").write_text(transcript + "\n", encoding="utf-8")
        frames = extract_frames(media, job / "frames", info.get("duration") or 0, args.frames, ffmpeg)
    finally:
        if not args.keep_media:
            media.unlink(missing_ok=True)

    words = len(transcript.split())
    meta = {
        "source_url": args.url,
        "canonical_url": info.get("webpage_url"),
        "video_id": info["id"],
        "creator": info.get("uploader") or info.get("creator"),
        "creator_handle": info.get("uploader_id"),
        "caption": info.get("description") or "",
        "duration": info.get("duration"),
        "transcript_words": words,
        "needs_visual": words < LOW_SPEECH_WORDS,
        "frames": frames,
    }
    (job / "meta.json").write_text(json.dumps(meta, indent=2, ensure_ascii=False), encoding="utf-8")
    print(job / "meta.json")


if __name__ == "__main__":
    main()
