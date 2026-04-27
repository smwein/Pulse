// Source: free-exercise-db schema (one entry per exercise)
export interface FreeExerciseDbEntry {
  id: string;                      // e.g. "3_4_Sit-Up"
  name: string;
  force: "pull" | "push" | "static" | null;
  level: "beginner" | "intermediate" | "expert";
  mechanic: "compound" | "isolation" | null;
  equipment: string | null;
  primaryMuscles: string[];
  secondaryMuscles: string[];
  instructions: string[];
  category: string;                // "strength" | "stretching" | "plyometrics" | etc.
  images: string[];                // e.g. ["3_4_Sit-Up/0.jpg", "3_4_Sit-Up/1.jpg"]
}

// Target: what we publish to R2 in the Pulse manifest
export interface PulseExerciseAsset {
  id: string;                      // same as source id
  name: string;
  category: string;
  level: "beginner" | "intermediate" | "expert";
  equipment: string | null;
  primaryMuscles: string[];
  secondaryMuscles: string[];
  instructions: string[];
  videoURL: string;                // public R2 URL to the looping MP4
  posterURL: string;               // public R2 URL to the first-frame JPEG
}

export interface PulseManifest {
  version: number;                 // unix timestamp at build time
  generatedAt: string;             // ISO date
  exerciseCount: number;
  exercises: PulseExerciseAsset[];
}
