# TerraForge Mobile — v0.4.1-dev.2 (validated regional world manifests and safe export)

Standalone **Godot 4.7.2** terrain shaping addon. No Terrain3D dependency, native library, or changes to game files. Designed for Android editor testing with Mobile Renderer.

## Install / use

1. Copy **only** `addons/terra_forge/` into the root of any Godot 4.7.2 project.
2. Open **Project > Project Settings > Plugins**, enable **TerraForge Mobile**.
3. Open a saved 3D scene (Node3D root). In the **3D editor toolbar**, tap **Terrain** (next to **Brush**) to open the compact tools popup.
4. Tap **+ New** to create an empty, initially flat terrain. The popup closes so the 3D view remains unobstructed.
5. Tap **Terrain** again to choose Raise / Lower / Smooth / Flatten / Ridge / Valley / Ramp / Stamp / Weather and adjust Size and Power.
6. Toggle **Brush** next to the Terrain button, then drag a finger or left mouse button across the surface. Toggle it off to move the editor camera.
7. In the popup, **Save** writes Float32 heights; separately save the scene with Godot. **Quality** selects Mobile / Balanced / High.

## Features implemented

- **Lossless Float32 height storage** in a versioned `.tfh` height file (little-endian TFH1 header + row-major Float32 samples).
- **Resident visual tiles**: allocate only camera-near tile nodes, with maximum active tile budget. Drop far mesh/collision nodes on travel.
- **3 mesh LODs**: strides 1, 2, 4 with seam-conformed edges and 8m hysteresis. Surface normals are computed from seam-adjusted mesh. At **same-LOD tile boundaries**, gradients now sample across the shared border to reduce lighting seams on curved slopes.
- **Top surface fix**: corrected the terrain's triangle winding; previously it was backface-culled and only the grey LOD skirts appeared, creating a fake hollow/checkerboard view.
- **Compact toolbar UI**: removed the giant bottom dock; one **Terrain** popup button and one **Brush** toggle live in Godot's 3D editor toolbar. The popup is clamped to the mobile viewport.
- **Incremental node allocation**: in v0.2.1 the tile meshes were capped per frame but all tile nodes were created together. v0.2.2 now creates only the permitted number of tile nodes per frame, too.
- **Centered new terrain**: new flat grids start centered around the scene origin, so the edit camera is less likely to miss them. A new terrain writes its Float32 data immediately (save the scene separately).
- **Duplicate touch guard**: ignores synthetic mouse taps shortly after Android touch events.
- **Editor camera following** through `EditorInterface.get_editor_viewport_3d(0).get_camera_3d()`. Scene camera following while running.
- **Collision only at closest LOD**, with properly uniform scaling and pre-scaled height values.
- **Per-frame tile rebuild budget**, with edited/dirtied tiles queued rather than regenerating the whole map at once. Repeated height edits now mark one affected tile rectangle rather than submitting thousands of per-sample dirty notifications.
- Touch/mouse shaping with **distance-spaced stamps** (one touch-movement path now yields similar heights regardless of event count), 20-step local Undo/Redo, 2.5-second idle autosave, corrupt file write guard.
- Live resident tile/vertex counts and CPU build/edit timings in the compact Terrain popup, plus a non-destructive **Check** self-test.

## Advanced sculpting (v0.3)

- **Ridge**: draw a full crest path, **release to apply**. One continuous asymmetric corridor is calculated. Coherent warp samples are cached across overlapping path segments, with a **65,536-sample cap** to bound temporary memory; height values are still Float32.
- **Valley**: draw a full incision path, **release to apply**. It uses the same bounded warp cache as Ridge. Valley geometry is still **artist-directed** rather than automatically aligned to drainage basins.
- **Ramp**: drag from start to finish and release. The tool makes one sloping corridor whose ending elevation is the existing end-point elevation plus **Rise** (initially +5m); negative Rise creates descending ramps. Nothing changes until release, and one drag is one Undo step. Single ramps are limited to 256m for mobile CPU safety
- **Stamp**: one touch applies a deterministic **Hill**, **Crater** (bowl + lip) or **Mesa**. Its once-perfect circular outline uses a bounded world-space noise warp and slight anisotropy, tapering exactly to zero at the brush border. Still a procedural shape, not simulated rock formation.
- **Weather**: tap a steep area and release for 1–6 bounded thermal passes (up to 32m). It now uses two scans of the four neighbors rather than allocating candidate arrays per sample. Material is transferred conservatively; **no water flow or sediment simulation is claimed**.
- **Smooth**: two-pass neighborhood snapshot plus a 55% bilateral blend reduces directional scan artifacts while retaining some high-contrast edges. Ramp/Stamp/Weather controls remain contextual; Undo/Redo and Float32 data format are unchanged.
- Mobile **Check** button tests Float32 roundtrip, path consistency, local mass balance and reports CPU processing times without changing the user's terrain.

## P1 manifest and safe heightfield export (0.4.1-dev.2)

- Added `core/region_manifest.gd`: checksummed **TFM1 manifest**, recording source format and source SHA-256, world dimensions/spacing, unique region coordinates and the SHA-256 digest of **every TFR1 page**. A verifier rejects altered/missing/wrong-world pages.
- Added `core/region_export.gd`: **explicit, non-destructive export** from `TFH1` or `TFL1/TFL2`. The input source remains unchanged.
- TFL layer documents are exported as their **current visible composite Float32 heights**. The exported region snapshot is **flattened**, not a replacement for editable layers. Preserve the original TFL!
- Regions are written to a **new uniquely named staging directory**, verified one-by-one and checked against the TFM1 manifest. Only then is the whole staged directory renamed into the requested destination.
- Destination must **not exist**. Failures leave the canonical destination absent and keep staging data for diagnosis; the script never deletes old terrain or overwrites a prior export.
- `REGIONS.create_page_with_samples()` writes complete Float32 pages without per-sample disk transactions, with strict bounds/finite validation.
- New headless regression: `tests/test_region_export.gd`, including exact Float32 border comparisons, source byte immutability, checksum tampering, incomplete worlds and overwrite refusal.
- **Not yet bound to live terrain rendering or collision.** These are isolated export/verification APIs, and the current live game RAM usage is unchanged. See [REGION_STREAMING_PLAN_TR.md](REGION_STREAMING_PLAN_TR.md).

## Experimental regional height streaming prototype (0.4.1-dev.1)

- Added `core/region_store.gd`: disk-backed **Float32 32×32 sample pages** with a bounded LRU resident cache, strict read errors for missing pages, dirty writeback, and checksummed `TFR1` region files.
- Every sample has one owner: border x=32 belongs only to region 1. This prevents duplicate height values on neighbor seams.
- Each page saves via a staged `.tmp`, SHA-256 verification and the previous verified `.bak`. A corrupt primary is never silently replaced with zero heights.
- Added `tests/test_region_store.gd`: cache residency, border samples, writeback, reload, backups, corrupted data, incomplete temporary files and wrong-world rejection.
- **IMPORTANT:** This is a **standalone, opt-in-free core experiment**; it is **NOT wired into TerraForgeTerrain** yet. The existing live terrain still loads the entire height map and has **no measured RAM reduction** from this work. Old `.tfh` and `.tfl` are preserved.
- Read [REGION_STREAMING_PLAN_TR.md](REGION_STREAMING_PLAN_TR.md) for the staged integration plan and limitations.

## TFL2 crash-safety and integrity (0.4.0-dev.3)

- Saves now use **TFL2** with a SHA-256 checksum over the entire binary payload, appended as a 64-byte ASCII hexadecimal footer. Loading checks the checksum **before** replacing the live layer data.
- Writes are staged to `.tmp`, checksum-verified, then atomically renamed to the authoritative `.tfl`. Before replacement, the prior valid `.tfl` is rotated through `.bak.tmp` into a **last-known-good `.bak`**.
- A corrupt authoritative `.tfl` cannot be overwritten by Save. The terrain remains **read-only** instead of silently falling back to older data.
- If a valid `.bak` exists, the compact layer toolbar exposes **Restore**. Recovery is deliberate and keeps the damaged original in `.corrupt_<timestamp>`. It restores the **previous save**, so edits since that save may be lost.
- A brand-new `.tfl` has **no `.bak` until the next successful save**. Keep independent project backups.
- Existing **TFL1** documents still load. Explicit Save migrates them to TFL2 and preserves the previous TFL1 in `.bak`; the legacy `.tfh` is untouched.
- `test_layer_integrity.gd` covers payload tampering, verified backup, refusal to overwrite corruption, explicit recovery, TFL1 migration and partial temporary files.
- A SHA-256 digest detects accidental changes; it is not encryption or authenticated protection against deliberate replacement.

## P1 opt-in live sculpting (0.4.0-dev.2)

- **Terrain > Enable Layers** creates a separate authoritative `.tfl` from the current `.tfh`, preserving the original byte-for-byte. It refuses to overwrite an existing layer file.
- After enabling, the same mobile menu offers a compact layer selector, **+** to create a new layer, and **On** to toggle visibility.
- All existing sculpt tools (Raise/Lower/Smooth/Flatten/Ridge/Valley/Ramp/Stamp/Weather) update only the active layer's Float32 deltas; Undo/Redo restore layer deltas and the visible composite.
- Once enabled, the TFL2 file contains both base and layers and is the **only authoritative save target**. The legacy TFH is retained as a backup snapshot and never written in layer mode.
- On reopen, a missing or invalid TFL1/TFL2 document locks the scene read-only. The plugin **never falls back** to the TFH and overwrites new work. Remember to **save the Godot scene** separately after conversion so the new layer path/mode persist.
- The active layer must be enabled at full opacity (100%) to sculpt; hiding a layer recomposes all heights, updates tile meshes/physics and clears stroke undo history to prevent inconsistent cross-layer restoration.
- This is still **experimental**. Background processing and tested multi-file crash recovery are not implemented. CI covers 18 headless regression scripts (pending latest confirmation) (including `test_live_layers.gd` and `test_layer_scene_roundtrip.gd`), not Android UI/FPS.

## P0/P1 initial implementation (0.4.0-dev.1)

- Added `core/height_layers.gd`: experimental **non-destructive additive Float32 height layer stack** with 32×32 sparse delta chunks, enable/disable, opacity, reorder, and composite-on-demand. Base elevations remain unchanged.
- Added independent `TFL1` (now upgradable to `TFL2`) versioned serialization to a `.tfl` sidecar with validated dimensions, bounded layer counts, checks for non-finite values and fail-closed corrupted files. Only explicit calls save these files; no existing `.tfh` is migrated.
- Added `tests/test_height_layers.gd` for layer fidelity, border samples, toggles, opacity, save/reload, and corrupt file isolation.
- Added `tests/run_all.sh` to run all 20 Godot regression scripts against a real project and Godot **4.7.2**.
- Extended **Terrain > Check** with a non-destructive scratch-layer smoke test, reported as `Layers ... ms`.
- The underlying P1 prototype began isolated in v0.4.0-dev.1. v0.4.0-dev.2 adds **explicit opt-in live sculpting** and per-layer Undo/Redo, without changing the default legacy behavior. Read [P0_P1_IMPLEMENTATION_TR.md](P0_P1_IMPLEMENTATION_TR.md) before enabling such integration.

## Experimental drainage analysis (0.3.3; no terrain modification)

- New `core/drainage_analysis.gd` estimates local drainage from **Float32 heights** using **priority-flood depression conditioning** and deterministic **multiple-flow-direction (MFD)** accumulation.
- An open **local patch boundary** acts as an outlet. Flat routing uses distance-to-outlet as a heap tie-break to reduce arbitrary corner bias.
- Radius is limited to **48 height samples** (at most **97×97 cells**) to bound CPU and memory on Android; larger requests are capped. Patch analysis is not global catchment modelling.
- The solver **does not** modify heights, paint channels, claim hydraulic erosion, or place water. Its test is included in **Terrain > Check**, with measured Drainage CPU time.
- Flow maps and depression fill are currently computational research data only; **no Drainage sculpt button** until output quality, rainfall balance and on-device costs have been verified.

## Missing file protection (0.3.3)

- An existing scene whose `.tfh` height file is missing or invalid becomes **read-only**; it will not silently overwrite the missing source with a blank map.
- Only the explicit **Terrain > + New** action can create a missing Float32 data file. After the first successful save, file creation permission is switched off.
- If the editor reports missing data, restore the **original linked `.tfh`** from backup instead of clicking + New.

## Mobile streaming budgets (initial estimates; NOT performance measurements)

| Profile | View radius | Max resident tiles | LOD0 / LOD1 radii | Max rebuilds/frame | CPU work cap* |
| --- | ---: | ---: | ---: | ---: | ---: |
| Mobile - light | 160m | 64 | 56m / 104m | 1 | 2.5ms |
| Balanced | 224m | 96 | 72m / 144m | 2 | 4.0ms |
| High detail | 320m | 160 | 112m / 208m | 3 | 6.0ms |

*Time budgets stop further work after a completed tile. One tile itself can exceed the budget, and CPU times are not GPU timing.*

The **full Float32 height field remains in RAM**. This version streams visible **mesh + physics tiles**, not source height files from storage. It is not an infinite terrain system.

## File safety / project isolation

- This feature branch only writes paths inside `addons/terra_forge/`. It does not alter the FareOyunu game, player, project settings, or scenes.
- When a user creates a terrain in their own project, height data is saved to `res://terraforge_data/<scene>_<id>.tfh`. This is user-generated runtime content, not part of this repository's changes.
- Heightmap files are written to a temporary path then renamed. If the existing height file is corrupt/unreadable, editing and saving are blocked until recovered externally.
- Save both the scene **and** its linked `.tfh` data file when migrating a project.
- Generated tile meshes and collision nodes are internal children and are not persisted into scenes.

## Limitations / pending validation

- **The 0.2.0 UI loaded on the user's Android 11 Godot 4.7.2 editor**, but showed a hollow checkerboard due to backface-culling. Version 0.2.1 corrected the winding; v0.2.2 removes the visible skirt grid and limits node allocation. The revised versions still require device validation. Tests were authored but could not be executed here.
- Adjacent mixed-LOD borders use a simpler height interpolation. They should align without gray skirts, but can still show subtle shading differences. Exact topology stitching and geomorphing are future improvements.
- The full Float32 heightmap is resident even when no mesh tile is loaded. File-backed streaming is not yet implemented.
- Tile mesh builds **and node creation** happen on the main thread, strictly limited per frame. A later stage can move mesh input preparation to worker threads.
- Collision is disabled for lower-detail tiles and enabled only near the camera. This is for performance; far-away physics interactions require a separate collision strategy.
- Material painting and object placement are intentionally **on hold**. This version does not offer full hydraulic erosion, watershed solve, rock strata, procedural deposition, imported image stamps, or volumetric caves. The new Weather pass models thermal weathering only.
- The 20 Undo/Redo entries live only in the terrain node's memory; Godot's global editor Undo/Redo integration remains pending.
- Brush stamps are spaced by traveled **world distance**, preventing changes in the number of touch events from changing results. Holding the finger still does **not** continue to sculpt; pressure-sensitive, time-normalized holding is future work.

## Automated tests

From a project containing the addon:

```bash
godot --headless --path /path/to/project --script res://addons/terra_forge/tests/test_height_store.gd
godot --headless --path /path/to/project --script res://addons/terra_forge/tests/test_lod_policy.gd
godot --headless --path /path/to/project --script res://addons/terra_forge/tests/test_surface_faces.gd
godot --headless --path /path/to/project --script res://addons/terra_forge/tests/test_lod_seams.gd
godot --headless --path /path/to/project --script res://addons/terra_forge/tests/test_stream_budget.gd
godot --headless --path /path/to/project --script res://addons/terra_forge/tests/test_brush_sampling.gd
godot --headless --path /path/to/project --script res://addons/terra_forge/tests/test_advanced_brushes.gd
godot --headless --path /path/to/project --script res://addons/terra_forge/tests/test_geomorphology.gd
godot --headless --path /path/to/project --script res://addons/terra_forge/tests/test_lod_normals.gd
godot --headless --path /path/to/project --script res://addons/terra_forge/tests/test_shape_quality.gd
godot --headless --path /path/to/project --script res://addons/terra_forge/tests/test_data_safety.gd
godot --headless --path /path/to/project --script res://addons/terra_forge/tests/test_edge_normals.gd
godot --headless --path /path/to/project --script res://addons/terra_forge/tests/test_drainage_analysis.gd
godot --headless --path /path/to/project --script res://addons/terra_forge/tests/test_height_layers.gd
godot --headless --path /path/to/project --script res://addons/terra_forge/tests/test_live_layers.gd
godot --headless --path /path/to/project --script res://addons/terra_forge/tests/test_layer_scene_roundtrip.gd
godot --headless --path /path/to/project --script res://addons/terra_forge/tests/test_layer_integrity.gd
godot --headless --path /path/to/project --script res://addons/terra_forge/tests/test_region_store.gd
godot --headless --path /path/to/project --script res://addons/terra_forge/tests/test_region_export.gd
```

See [MOBILE_TEST_PLAN.md](MOBILE_TEST_PLAN.md) for hands-on Android checks and acceptance criteria. These tests have **not yet been executed** with the Godot engine here.

## Quality gate before materials and foliage

Read [QUALITY_GATE.md](QUALITY_GATE.md). The addon **is not certified optimized or professionally realistic** until Godot 4.7.2 Android tests confirm real-world shape quality, physics/LOD seams, stability, frame-time percentiles and memory use. The on-device **Check** button is a partial geometry/CPU smoke test, not a replacement for sustained frame/GPU profiling.

## Next stages

1. Run the complete **20-test** Godot 4.7.2 CLI regression suite (P0) and fix all parse/API/behavior failures.
2. Run **Terrain > Check** on Android 11 and record the new Layers timings (P1 scratch test).
2. Inspect long ridge/valley shape quality at ground-camera height and fix contour artifacts.
3. Validate thermal mass-balance, LOD edge normals, seam continuity and collision on-device.
4. Validate the new priority-flood/MFD **read-only** drainage analysis with synthetic depressions, flat terrain and real landscape test cases, then decide whether automatic incision is geometrically credible and affordable.
5. Only after the [quality gate](QUALITY_GATE.md) passes, move to materials and object placement.

## License / origin

Independent implementation. No Terrain3D source files copied.
