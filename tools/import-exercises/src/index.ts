import { fetchExerciseDb } from "./fetchExercises.ts";
import { downloadAllImages } from "./downloadImages.ts";

const all = await fetchExerciseDb();
const sample = all.slice(0, 3);
console.log(`Downloading images for ${sample.length} exercises (smoke test)…`);
const results = await downloadAllImages(sample);
for (const [id, paths] of results) {
  console.log(`  ${id} → ${paths.length} images: ${paths.join(", ")}`);
}
