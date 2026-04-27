import "dotenv/config";
import { FreeExerciseDbEntry, PulseExerciseAsset, PulseManifest } from "./types.js";

const PUBLIC_URL = process.env.R2_PUBLIC_URL;
if (!PUBLIC_URL) {
  throw new Error("Missing R2_PUBLIC_URL env var");
}

export function buildExerciseAsset(entry: FreeExerciseDbEntry): PulseExerciseAsset {
  return {
    id: entry.id,
    name: entry.name,
    category: entry.category,
    level: entry.level,
    equipment: entry.equipment,
    primaryMuscles: entry.primaryMuscles,
    secondaryMuscles: entry.secondaryMuscles,
    instructions: entry.instructions,
    videoURL: `${PUBLIC_URL}/exercises/${entry.id}.mp4`,
    posterURL: `${PUBLIC_URL}/exercises/${entry.id}-poster.jpg`,
  };
}

export function buildManifest(entries: FreeExerciseDbEntry[]): PulseManifest {
  const exercises = entries.map(buildExerciseAsset);
  return {
    version: Math.floor(Date.now() / 1000),
    generatedAt: new Date().toISOString(),
    exerciseCount: exercises.length,
    exercises,
  };
}
