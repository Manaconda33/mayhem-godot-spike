# Manaconda sprite import test

## Result

**Pass: 29 of 29 clips, 293 of 293 registered frames.** The packaged right-facing WebP atlases load in Godot 4.6.3 without changing the source images or frame rectangles. The mirrored preview uses the same decoded frame with `AnimatedSprite2D.scale.x = -1`; no left-facing atlas is needed. No asset rework is required.

This test is isolated behind **ASSET TEST** on the hub. The Jam core-loop scene and its placeholder visuals remain unchanged.

## Source and import

- Conda-Jam source: `Manaconda33/Conda-Jam`, `main` at `6b6958fc483907045f4f32b1cc8613a52da9df22`.
- The 29 packaged WebP files are copied byte-for-byte into `assets/jam/manaconda/`. Together they are 1,305,626 bytes, matching the Manaconda total in `GENERATED_POSES.md`.
- `manaconda-layouts.json` registers the five locomotion clips. Eighteen additional action layout files in the same `tools/generate-art/` directory register the other 24 clips. The test preserves those JSON files and reads their integer rectangles directly; it does not recalculate or edit them.
- `MANACONDA_ART.md` and `manaconda-package.py` document the original five-clip locomotion package. The 29-clip completion checkpoint is newer; its additional clips are packaged and mapped by the 18 per-action layout files. The test uses those existing source files without changing Conda-Jam.
- Godot import settings for each sheet: **Lossless** (`compress/mode=0`), mipmaps off, alpha-edge fix off, alpha premultiplication off, and no size limit. The preview sets nearest-neighbor sampling and atlas clipping.
- Alpha-edge fix must be off for this zero-rework check: Godot's default setting changes RGB on low-alpha edge pixels. With it disabled, the smoke harness compares every decoded RGBA source byte against the imported texture and finds no differences.
- Each clip's visible lower edge is constant across its frames. Locomotion atlases land at source row 96; action atlases land at row 94, leaving a consistent two-pixel transparent foot pad. The preview offsets each clip's pivot to put its visible lower edge on the ground line.

## Per-clip results

“Foot row” is the exclusive lower edge of the visible pixels inside each source frame rectangle. Each clip has the same value for every frame. `Flip` passes for every clip because the preview applies an X scale of exactly `-1` to the same imported atlas region using nearest sampling.

| Clip | Frames | Packaged sheet | Foot edge | Frame check | Flip |
| --- | ---: | --- | ---: | --- | --- |
| idle | 6 | `manaconda-idle-right.webp` | 96 px | Pass | Pass |
| idle-ball | 4 | `manaconda-idle-ball-right.webp` | 96 px | Pass | Pass |
| dribble | 10 | `manaconda-dribble-right.webp` | 96 px | Pass | Pass |
| run | 11 | `manaconda-run-right.webp` | 96 px | Pass | Pass |
| dribble-run | 11 | `manaconda-dribble-run-right.webp` | 96 px | Pass | Pass |
| shoot | 10 | `manaconda-shoot-right.webp` | 94 px | Pass | Pass |
| pass | 6 | `manaconda-pass-right.webp` | 94 px | Pass | Pass |
| pass-overhead | 6 | `manaconda-pass-overhead-right.webp` | 94 px | Pass | Pass |
| pass-behind | 6 | `manaconda-pass-behind-right.webp` | 94 px | Pass | Pass |
| receive | 4 | `manaconda-receive-right.webp` | 94 px | Pass | Pass |
| pickup | 5 | `manaconda-pickup-right.webp` | 94 px | Pass | Pass |
| layup | 8 | `manaconda-layup-right.webp` | 94 px | Pass | Pass |
| layup-reverse | 8 | `manaconda-layup-reverse-right.webp` | 94 px | Pass | Pass |
| block | 4 | `manaconda-block-right.webp` | 94 px | Pass | Pass |
| steal | 8 | `manaconda-steal-right.webp` | 94 px | Pass | Pass |
| push | 11 | `manaconda-push-right.webp` | 94 px | Pass | Pass |
| rebound | 5 | `manaconda-rebound-right.webp` | 94 px | Pass | Pass |
| fall | 10 | `manaconda-fall-right.webp` | 94 px | Pass | Pass |
| celebrate | 10 | `manaconda-celebrate-right.webp` | 94 px | Pass | Pass |
| dunk-power | 15 | `manaconda-dunk-power-right.webp` | 94 px | Pass | Pass |
| dunk-windmill | 15 | `manaconda-dunk-windmill-right.webp` | 94 px | Pass | Pass |
| dunk-reverse | 15 | `manaconda-dunk-reverse-right.webp` | 94 px | Pass | Pass |
| dunk-360 | 15 | `manaconda-dunk-360-right.webp` | 94 px | Pass | Pass |
| dunk-tomahawk | 15 | `manaconda-dunk-tomahawk-right.webp` | 94 px | Pass | Pass |
| dunk-double | 15 | `manaconda-dunk-double-right.webp` | 94 px | Pass | Pass |
| dunk-clutch | 15 | `manaconda-dunk-clutch-right.webp` | 94 px | Pass | Pass |
| dunk-scythe | 15 | `manaconda-dunk-scythe-right.webp` | 94 px | Pass | Pass |
| alley-oop-power | 15 | `manaconda-alley-oop-power-right.webp` | 94 px | Pass | Pass |
| alley-oop-reverse | 15 | `manaconda-alley-oop-reverse-right.webp` | 94 px | Pass | Pass |

The automated check is `godot --headless --path . --script tests/jam_asset_import_smoke.gd`. It verifies all 293 frame crops against the source layout rectangles, rejects blank frames, checks in-clip foot-row stability and pivot-to-line alignment, checks X-flip behavior, and compares imported texture pixels with the decoded source WebP bytes.

## Rework list

**None.** No sheet edits, re-exports, re-layouts, frame changes, or source-repository changes were made.
