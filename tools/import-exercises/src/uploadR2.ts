import { spawn } from "node:child_process";
import { writeFile, unlink } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import "dotenv/config";

const { R2_BUCKET } = process.env;

if (!R2_BUCKET) {
  throw new Error("Missing R2_BUCKET env var — check .env");
}

function runWrangler(args: string[]): Promise<void> {
  return new Promise((resolve, reject) => {
    const proc = spawn("wrangler", args, { stdio: ["ignore", "pipe", "pipe"] });
    let stderr = "";
    let stdout = "";
    proc.stdout.on("data", (chunk) => (stdout += chunk.toString()));
    proc.stderr.on("data", (chunk) => (stderr += chunk.toString()));
    proc.on("close", (code) => {
      if (code === 0) resolve();
      else reject(new Error(`wrangler exited ${code}: ${stderr.slice(-500) || stdout.slice(-500)}`));
    });
    proc.on("error", reject);
  });
}

/**
 * Upload a local file to R2 at the given key.
 * Uses `wrangler r2 object put bucket/key --file path --remote ...`
 * (the --remote flag forces upload to actual R2, not the local emulator).
 */
export async function uploadFile(
  localPath: string,
  key: string,
  contentType: string
): Promise<void> {
  await runWrangler([
    "r2", "object", "put",
    `${R2_BUCKET}/${key}`,
    "--file", localPath,
    "--remote",
    "--content-type", contentType,
    "--cache-control", "public, max-age=31536000, immutable",
  ]);
}

/**
 * Upload a JSON value to R2 at the given key.
 * Writes to a temp file first so wrangler can read it via --file.
 */
export async function uploadJson(key: string, value: unknown): Promise<void> {
  const tmpPath = join(tmpdir(), `pulse-upload-${Date.now()}-${Math.random().toString(36).slice(2)}.json`);
  await writeFile(tmpPath, JSON.stringify(value, null, 2));
  try {
    await runWrangler([
      "r2", "object", "put",
      `${R2_BUCKET}/${key}`,
      "--file", tmpPath,
      "--remote",
      "--content-type", "application/json; charset=utf-8",
      "--cache-control", "public, max-age=300",
    ]);
  } finally {
    await unlink(tmpPath).catch(() => {});
  }
}
