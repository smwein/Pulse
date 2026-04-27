import "dotenv/config";
import { writeFile, readFile, mkdir, access } from "node:fs/promises";
import { dirname } from "node:path";
import pLimit from "p-limit";
import { fetchExerciseDb } from "./fetchExercises.js";
import { downloadAllImages } from "./downloadImages.js";
import { encodeExerciseClip } from "./encodeMp4.js";
import { uploadFile, uploadJson } from "./uploadR2.js";
import { buildManifest } from "./buildManifest.js";
import { FreeExerciseDbEntry } from "./types.js";

const PROCESS_CONCURRENCY = 2;          // Wrangler invocations are heavy
const ERROR_RATE_ABORT_THRESHOLD = 0.05;
const TRACKER_PATH = "./cache/uploaded.json";

const dryRun = process.argv.includes("--dry-run");
const force = process.argv.includes("--force");

interface UploadTracker {
  uploaded: Record<string, true>; // exerciseId -> done
}

async function fileExists(path: string): Promise<boolean> {
  try {
    await access(path);
    return true;
  } catch {
    return false;
  }
}

async function loadTracker(): Promise<UploadTracker> {
  if (force) {
    console.log("--force: ignoring upload tracker, will re-upload all exercises.");
    return { uploaded: {} };
  }
  if (!(await fileExists(TRACKER_PATH))) {
    return { uploaded: {} };
  }
  try {
    const text = await readFile(TRACKER_PATH, "utf-8");
    return JSON.parse(text) as UploadTracker;
  } catch (e) {
    console.warn(`Tracker file corrupt, starting fresh: ${String(e).slice(0, 200)}`);
    return { uploaded: {} };
  }
}

async function saveTracker(tracker: UploadTracker): Promise<void> {
  await mkdir(dirname(TRACKER_PATH), { recursive: true });
  // Write atomically: write to .tmp, rename
  const tmpPath = `${TRACKER_PATH}.tmp`;
  await writeFile(tmpPath, JSON.stringify(tracker, null, 2));
  await writeFile(TRACKER_PATH, JSON.stringify(tracker, null, 2));
}

async function processOne(
  ex: FreeExerciseDbEntry,
  imagesByExercise: Map<string, string[]>,
  tracker: UploadTracker
): Promise<void> {
  const images = imagesByExercise.get(ex.id);
  if (!images || images.length === 0) {
    throw new Error(`no source images`);
  }

  // Encode (skips internally if MP4 + poster already exist)
  const { mp4Path, posterPath } = await encodeExerciseClip(ex.id, images);

  if (dryRun) {
    return;
  }

  // Upload — skip if already tracked as uploaded
  if (tracker.uploaded[ex.id]) {
    return;
  }

  await uploadFile(mp4Path, `exercises/${ex.id}.mp4`, "video/mp4");
  await uploadFile(posterPath, `exercises/${ex.id}-poster.jpg`, "image/jpeg");

  // Mark uploaded — note: we save the tracker on each success below in main()
  tracker.uploaded[ex.id] = true;
}

async function main() {
  console.log(`Pulse content pipeline${dryRun ? " (DRY RUN)" : ""}${force ? " (FORCE)" : ""}\n`);

  // 1. Fetch source data
  const all = await fetchExerciseDb();

  // 2. Download all source images
  console.log(`\nDownloading source images (resumes from cache)…`);
  const imagesByExercise = await downloadAllImages(all);

  // 3. Load upload tracker
  const tracker = await loadTracker();
  const alreadyUploadedCount = Object.keys(tracker.uploaded).length;
  if (alreadyUploadedCount > 0 && !force && !dryRun) {
    console.log(`Found ${alreadyUploadedCount} previously uploaded exercises in tracker — will skip those.`);
  }

  // 4. Process (encode + upload) with concurrency
  console.log(`\nProcessing ${all.length} exercises (concurrency=${PROCESS_CONCURRENCY})…`);
  const limit = pLimit(PROCESS_CONCURRENCY);
  let completed = 0;
  const errors: { id: string; error: string }[] = [];
  let savesPending = 0;

  await Promise.all(
    all.map((ex) =>
      limit(async () => {
        try {
          const wasUploaded = tracker.uploaded[ex.id];
          await processOne(ex, imagesByExercise, tracker);
          if (!wasUploaded && tracker.uploaded[ex.id]) {
            // Successful new upload — save tracker (debounce: every 5 saves)
            savesPending++;
            if (savesPending >= 5) {
              await saveTracker(tracker);
              savesPending = 0;
            }
          }
        } catch (e) {
          errors.push({ id: ex.id, error: String(e).slice(0, 300) });
        }
        completed++;
        if (completed % 25 === 0 || completed === all.length) {
          console.log(`  ${completed}/${all.length} processed (${errors.length} errors)`);
        }
      })
    )
  );

  // Final tracker save
  if (!dryRun) {
    await saveTracker(tracker);
  }

  // 5. Check error rate
  const errorRate = errors.length / all.length;
  if (errorRate > ERROR_RATE_ABORT_THRESHOLD) {
    console.error(`\nFAIL: ${errors.length} errors (>${(ERROR_RATE_ABORT_THRESHOLD * 100).toFixed(0)}%). Not publishing manifest.`);
    console.error(`First 10 errors:`);
    errors.slice(0, 10).forEach((e) => console.error(`  ${e.id}: ${e.error}`));
    process.exit(1);
  }

  // 6. Build manifest from successful exercises
  const failedIds = new Set(errors.map((e) => e.id));
  const successfulEntries = all.filter((ex) => !failedIds.has(ex.id));
  const manifest = buildManifest(successfulEntries);

  // 7. Save manifest locally
  await mkdir("./output", { recursive: true });
  await writeFile("./output/manifest.json", JSON.stringify(manifest, null, 2));
  console.log(`\nManifest: ${manifest.exerciseCount} exercises (${errors.length} excluded due to errors).`);

  if (dryRun) {
    console.log(`(DRY RUN — manifest written to output/manifest.json, not uploaded.)`);
    return;
  }

  // 8. Upload manifest
  await uploadJson("exercises/manifest.json", manifest);
  console.log(`\n✓ Manifest published.`);
  console.log(`  ${process.env.R2_PUBLIC_URL}/exercises/manifest.json`);

  if (errors.length > 0) {
    console.warn(`\n${errors.length} exercises were skipped:`);
    errors.forEach((e) => console.warn(`  ${e.id}: ${e.error.slice(0, 200)}`));
  }
}

main().catch((e) => {
  console.error("\nPipeline failed:", e);
  process.exit(1);
});
