import { FreeExerciseDbEntry } from "./types.js";

const SOURCE_URL = "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json";

export async function fetchExerciseDb(): Promise<FreeExerciseDbEntry[]> {
  console.log(`Fetching source data from ${SOURCE_URL}…`);
  const response = await fetch(SOURCE_URL);
  if (!response.ok) {
    throw new Error(`Failed to fetch exercises.json: ${response.status} ${response.statusText}`);
  }
  const data = (await response.json()) as FreeExerciseDbEntry[];
  console.log(`Fetched ${data.length} exercises.`);
  return data;
}
