---
name: convert-recipe
description: Convert a TikTok recipe video link into a written recipe and post it to the Recipe Box app. Use when the user says "convert this recipe", pastes a tiktok.com / vt.tiktok.com / vm.tiktok.com link, or asks to add a TikTok recipe to the recipe box.
---

# Convert a TikTok recipe

Run everything from the project root (`E:\workspaces\tiktok_recipe`). Handle each URL on its own; one failure must not stop the others.

## 1. Extract

```bash
py -3.12 extractor/extract.py "<url>"
```

Prints `work/<video_id>/meta.json`. The folder also has `transcript.txt` and `frames/frame_NN.jpg`. The video itself is already deleted.

If yt-dlp fails with "Unexpected response", "Unable to extract" or any other extractor error, TikTok has probably changed its site. Upgrade once and retry:

```bash
py -3.12 -m pip install --user -U --pre "yt-dlp[default,curl-cffi]"
```

If it still fails, report the error to the user and move on.

## 2. Read the sources

- Read `meta.json` (caption, creator, `needs_visual`) and `transcript.txt`.
- **Frames:** if `needs_visual` is true, the video is mostly music with on-screen text. Read every frame and transcribe the text on screen: ingredients, amounts and steps. Otherwise read 3–4 frames spread across the video. That's enough to check for text overlays with quantities and to choose a cover.
- Many creators put the full recipe in the caption. When they do, it's usually the most exact source for quantities.

## 3. Write `work/<video_id>/recipe.json`

```json
{
  "title": "string",
  "servings": "string or null",
  "total_time": "string or null",
  "ingredients": [{"quantity": "1 1/2", "unit": "cups", "item": "beef broth", "note": null, "estimated": false}],
  "steps": ["one instruction per string"],
  "notes": ["string"],
  "cover_frame": "frame_NN.jpg"
}
```

Rules:
- **Never invent quantities.** If no source states an amount, set `quantity` and `unit` to null and `estimated` to true. Use `"to taste"` in `note` where that fits.
- Quantities stay strings, e.g. `"1/2"` and `"1 1/2"`.
- Fix obvious mis-transcriptions of ingredient names, such as "time" → "thyme" or "cumming" → "cumin".
- When the transcript, caption and on-screen text disagree, pick the most specific one and add a note describing the conflict.
- Write steps in plain imperative language. Drop filler and jokes, but keep useful tips as notes.
- Add a note if servings aren't stated.
- `cover_frame`: the frame that best shows the finished dish, not a person talking or raw ingredients.

## 4. Publish

```bash
py -3.12 extractor/publish.py work/<video_id>
```

It reads `RECIPES_URL` and `RECIPES_API_TOKEN` from `extractor/.env` and prints the recipe URL. The job folder is deleted after it posts successfully.

- `ALREADY EXISTS`: the video was converted before. Ask the user before re-running with `--overwrite`, which replaces the existing recipe. The site has no edit or delete for now, so `--overwrite` is also how to fix a bad conversion.
- `HTTP 401`: the token in `extractor/.env` doesn't match the app's `recipes_api_token` credential.
- Connection refused while pointed at localhost: start the app with `bin/dev`, or point `RECIPES_URL` at production.

## 5. Report

Give the user the recipe title, the URL, and anything they should check: estimated quantities, conflicts, or recipes read mostly from frames.
