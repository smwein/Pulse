import "dotenv/config";
import { fetchExerciseDb } from "./fetchExercises.ts";
import { downloadAllImages } from "./downloadImages.ts";
import { encodeExerciseClip } from "./encodeMp4.ts";
import { uploadFile } from "./uploadR2.ts";

const all = await fetchExerciseDb();
const sample = all.slice(0, 1);
const downloaded = await downloadAllImages(sample);
for (const ex of sample) {
  const { mp4Path, posterPath } = await encodeExerciseClip(ex.id, downloaded.get(ex.id)!);
  console.log(`Uploading MP4 for ${ex.id}…`);
  await uploadFile(mp4Path, `exercises/${ex.id}.mp4`, "video/mp4");
  console.log(`Uploading poster for ${ex.id}…`);
  await uploadFile(posterPath, `exercises/${ex.id}-poster.jpg`, "image/jpeg");
  console.log(`Done. Should be at:`);
  console.log(`  ${process.env.R2_PUBLIC_URL}/exercises/${ex.id}.mp4`);
  console.log(`  ${process.env.R2_PUBLIC_URL}/exercises/${ex.id}-poster.jpg`);
}
