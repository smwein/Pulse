import { fetchExerciseDb } from "./fetchExercises.ts";
import { downloadAllImages } from "./downloadImages.ts";
import { encodeExerciseClip } from "./encodeMp4.ts";

const all = await fetchExerciseDb();
const sample = all.slice(0, 1);
const downloaded = await downloadAllImages(sample);
for (const ex of sample) {
  const images = downloaded.get(ex.id)!;
  console.log(`Encoding ${ex.id} from ${images.length} images…`);
  const { mp4Path, posterPath } = await encodeExerciseClip(ex.id, images);
  console.log(`  MP4: ${mp4Path}`);
  console.log(`  Poster: ${posterPath}`);
}
