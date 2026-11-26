# Open Exercise Art

The full set of 562 exercise line drawings from
[Open Exercise Art](https://github.com/AlexMollard/Open-Exercise-Art) by
Alex Mollard (downloaded 2026-11-26), licensed **CC BY-SA 4.0**
(`LICENSE-ARTWORK.md`). `ATTRIBUTION.md` and `PROVENANCE.md` are the project's
own files. `catalogue.json` lists every drawing by id and name.

- `svg/<id>.svg`: the originals (one path, `fill="currentColor"`).
- The app ships only the drawings of its exercises, as PNGs recolored per theme
  in `assets/exercises/{light,dark}/<id>.png`. Make them with
  `tools/exercise_images.py <id>…`. The column `exercises.image` holds the id.

Credit needed wherever the drawings are shown or shared, and the recolored
copies stay under CC BY-SA 4.0:

> Exercise illustrations: Open Exercise Art / Alex Mollard, CC BY-SA 4.0
> (colors changed). https://github.com/AlexMollard/Open-Exercise-Art
