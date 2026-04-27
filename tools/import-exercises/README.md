# pulse-import-exercises

One-time content pipeline that loads [Free Exercise DB](https://github.com/yuhonas/free-exercise-db) (Unlicense / public domain) into Cloudflare R2 for the Pulse iOS app.

## What it does

1. Fetches `dist/exercises.json` from Free Exercise DB
2. Downloads each exercise's reference photos (1–2 per exercise) from the same repo, cached on disk
3. Uses ffmpeg to combine each photo pair into a 720×720, ~3.6s looping MP4 with a 0.3s crossfade between frames (single-photo entries get a 3s static MP4)
4. Uploads MP4s + first-frame JPEG posters to R2 (`pulse` bucket, `exercises/` prefix) via `wrangler r2 object put`
5. Builds a typed `manifest.json` and uploads it to R2

## Why wrangler instead of the S3 SDK

Originally specced to use `@aws-sdk/client-s3` with R2's S3-compatible credentials. Pivoted to `wrangler r2 object put` shell-outs because (a) it uses the existing `wrangler login` OAuth session — no extra credentials to provision and (b) it sidesteps the dashboard friction of finding the S3 Access Key ID + Secret Access Key fields.

Tradeoff: each upload spawns a wrangler subprocess (~3s startup). For 873 exercises × 2 uploads with concurrency=2 this is ~30–50 minutes total, but only runs once.

## Setup

```bash
npm install
cp .env.example .env  # then fill in R2_PUBLIC_URL
```

`.env` requires:
- `R2_BUCKET` (= `pulse`)
- `R2_PUBLIC_URL` (e.g. `https://pub-<hash>.r2.dev`)

Authentication is handled by your existing `wrangler login` — no API keys in `.env`.

## Usage

```bash
# Dry run (encodes locally, no uploads)
npm run dryrun

# Full run
npm start

# Force re-upload (ignores cache/uploaded.json tracker)
npm start -- --force
```

The pipeline is **resumable** — downloaded images, encoded MP4s, and successful uploads are tracked under `cache/` and `output/`. Re-running skips completed work. If your Mac sleeps mid-run (interrupting wrangler subprocesses), just re-run `npm start` and the tracker will skip what already succeeded.

## Output

- R2 (production): `exercises/{id}.mp4`, `exercises/{id}-poster.jpg` for each exercise + `exercises/manifest.json`
- Local: same files in `output/` for inspection / re-upload
- Local: `cache/uploaded.json` tracking which exercise IDs are confirmed uploaded

## License

Source data is from `yuhonas/free-exercise-db` under the Unlicense (public domain). This pipeline code is unlicensed; treat it as private to the Pulse project.
