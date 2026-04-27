import { mkdir, writeFile, access } from "node:fs/promises";
import { dirname, join } from "node:path";
import pLimit from "p-limit";
import { FreeExerciseDbEntry } from "./types.ts";

const IMAGE_BASE = "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises";
const CACHE_DIR = "./cache/images";
const DOWNLOAD_CONCURRENCY = 8;

async function fileExists(path: string): Promise<boolean> {
  try {
    await access(path);
    return true;
  } catch {
    return false;
  }
}

async function downloadOne(relativePath: string): Promise<string> {
  const localPath = join(CACHE_DIR, relativePath);

  if (await fileExists(localPath)) {
    return localPath;
  }

  const url = `${IMAGE_BASE}/${relativePath}`;
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Failed to download ${url}: ${response.status}`);
  }
  const buffer = Buffer.from(await response.arrayBuffer());
  await mkdir(dirname(localPath), { recursive: true });
  await writeFile(localPath, buffer);
  return localPath;
}

export async function downloadAllImages(
  exercises: FreeExerciseDbEntry[]
): Promise<Map<string, string[]>> {
  const limit = pLimit(DOWNLOAD_CONCURRENCY);
  const results = new Map<string, string[]>();

  let completed = 0;
  const total = exercises.length;

  await Promise.all(
    exercises.map((ex) =>
      limit(async () => {
        const localPaths = await Promise.all(ex.images.map(downloadOne));
        results.set(ex.id, localPaths);
        completed++;
        if (completed % 50 === 0 || completed === total) {
          console.log(`  Downloaded images for ${completed}/${total} exercises`);
        }
      })
    )
  );

  return results;
}
