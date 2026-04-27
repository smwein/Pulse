import { fetchExerciseDb } from "./fetchExercises.ts";

const data = await fetchExerciseDb();
console.log(`First entry:`, JSON.stringify(data[0], null, 2));
console.log(`Total entries: ${data.length}`);
