import { spawn } from "node:child_process";
import { mkdir, access } from "node:fs/promises";
import { dirname, join } from "node:path";
import ffmpegPath from "ffmpeg-static";

const OUTPUT_DIR = "./output";
const FRAME_DURATION_SEC = 1.5;
const CROSSFADE_SEC = 0.3;
const SIZE = 720;

if (!ffmpegPath) {
  throw new Error("ffmpeg-static did not provide a binary path");
}

async function fileExists(path: string): Promise<boolean> {
  try {
    await access(path);
    return true;
  } catch {
    return false;
  }
}

function runFfmpeg(args: string[]): Promise<void> {
  return new Promise((resolve, reject) => {
    const proc = spawn(ffmpegPath as string, args, { stdio: ["ignore", "ignore", "pipe"] });
    let stderr = "";
    proc.stderr.on("data", (chunk) => (stderr += chunk.toString()));
    proc.on("close", (code) => {
      if (code === 0) resolve();
      else reject(new Error(`ffmpeg exited with code ${code}: ${stderr.slice(-500)}`));
    });
    proc.on("error", reject);
  });
}

/**
 * Combines 1 or 2 source images into a 3s looping MP4.
 * - 2 images: hold each for 1.5s with a 0.3s crossfade between
 * - 1 image: 3s static MP4 (still loopable)
 *
 * Returns paths to the output MP4 + the poster JPEG.
 */
export async function encodeExerciseClip(
  exerciseId: string,
  sourceImages: string[]
): Promise<{ mp4Path: string; posterPath: string }> {
  if (sourceImages.length === 0) {
    throw new Error(`Exercise ${exerciseId} has no source images`);
  }

  const mp4Path = join(OUTPUT_DIR, `${exerciseId}.mp4`);
  const posterPath = join(OUTPUT_DIR, `${exerciseId}-poster.jpg`);
  await mkdir(dirname(mp4Path), { recursive: true });

  if (await fileExists(mp4Path) && await fileExists(posterPath)) {
    return { mp4Path, posterPath };
  }

  // Poster: first source image scaled+padded to 720x720
  await runFfmpeg([
    "-y",
    "-i", sourceImages[0],
    "-vf", `scale=${SIZE}:${SIZE}:force_original_aspect_ratio=decrease,pad=${SIZE}:${SIZE}:(ow-iw)/2:(oh-ih)/2:color=black`,
    "-q:v", "2",
    posterPath,
  ]);

  if (sourceImages.length === 1) {
    // Single static frame held for 3s
    await runFfmpeg([
      "-y",
      "-loop", "1",
      "-t", "3",
      "-i", sourceImages[0],
      "-vf", `scale=${SIZE}:${SIZE}:force_original_aspect_ratio=decrease,pad=${SIZE}:${SIZE}:(ow-iw)/2:(oh-ih)/2:color=black`,
      "-c:v", "libx264",
      "-pix_fmt", "yuv420p",
      "-r", "30",
      "-movflags", "+faststart",
      mp4Path,
    ]);
  } else {
    // Two-frame oscillation with crossfade.
    // Total: 2 * (FRAME_DURATION + CROSSFADE) = 3.6s
    const total = 2 * (FRAME_DURATION_SEC + CROSSFADE_SEC);
    await runFfmpeg([
      "-y",
      "-loop", "1", "-t", String(FRAME_DURATION_SEC + CROSSFADE_SEC), "-i", sourceImages[0],
      "-loop", "1", "-t", String(FRAME_DURATION_SEC + CROSSFADE_SEC), "-i", sourceImages[1],
      "-filter_complex",
        `[0:v]scale=${SIZE}:${SIZE}:force_original_aspect_ratio=decrease,pad=${SIZE}:${SIZE}:(ow-iw)/2:(oh-ih)/2:color=black,setsar=1[v0];` +
        `[1:v]scale=${SIZE}:${SIZE}:force_original_aspect_ratio=decrease,pad=${SIZE}:${SIZE}:(ow-iw)/2:(oh-ih)/2:color=black,setsar=1[v1];` +
        `[v0][v1]xfade=transition=fade:duration=${CROSSFADE_SEC}:offset=${FRAME_DURATION_SEC}[out]`,
      "-map", "[out]",
      "-c:v", "libx264",
      "-pix_fmt", "yuv420p",
      "-r", "30",
      "-t", String(total),
      "-movflags", "+faststart",
      mp4Path,
    ]);
  }

  return { mp4Path, posterPath };
}
