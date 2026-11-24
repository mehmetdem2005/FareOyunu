# TerraForge Mobile — v0.3.2 (shape quality + stable LOD + fewer CPU allocations)

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
- **3 mesh LODs**: strides 1, 2, 4 with lower-resolution edges conforming to neighboring tiles; an **8-meter distance hysteresis** reduces rapid LOD switching. Surface normals/visual slope colors now derive from the actual seam-adjusted mesh, not stale high-resolution height samples.
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

- **Ridge**: draw a full crest path, **release to apply**. One coherent noise-warped, asymmetric corridor is calculated per path. Heights are not stacked by repeated circular stamps.
- **Valley**: draw a full drainage-like incision path, **release to apply**. Same coherent corridor approach as Ridge, with a broader cross-section. This is not a true catchment solver.
- **Ramp**: drag from start to finish and release. The tool makes one sloping corridor whose ending elevation is the existing end-point elevation plus **Rise** (initially +5m); negative Rise creates descending ramps. Nothing changes until release, and one drag is one Undo step. Single ramps are limited to 256m for mobile CPU safety
- **Stamp**: one touch applies a deterministic **Hill**, **Crater** (bowl + lip) or **Mesa**. Its once-perfect circular outline uses a bounded world-space noise warp and slight anisotropy, tapering exactly to zero at the brush border. Still a procedural shape, not simulated rock formation.
- **Weather**: tap a steep area and release for 1–6 bounded thermal passes (up to 32m). It now uses two scans of the four neighbors rather than allocating candidate arrays per sample. Material is transferred conservatively; **no water flow or sediment simulation is claimed**.
- **Smooth**: two-pass neighborhood snapshot plus a 55% bilateral blend reduces directional scan artifacts while retaining some high-contrast edges. Ramp/Stamp/Weather controls remain contextual; Undo/Redo and Float32 data format are unchanged.
- Mobile **Check** button tests Float32 roundtrip, path consistency, local mass balance and reports CPU processing times without changing the user's terrain.

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
```

See [MOBILE_TEST_PLAN.md](MOBILE_TEST_PLAN.md) for hands-on Android checks and acceptance criteria. These tests have **not yet been executed** with the Godot engine here.

## Quality gate before materials and foliage

Read [QUALITY_GATE.md](QUALITY_GATE.md). The addon **is not certified optimized or professionally realistic** until Godot 4.7.2 Android tests confirm real-world shape quality, physics/LOD seams, stability, frame-time percentiles and memory use. The on-device **Check** button is a partial geometry/CPU smoke test, not a replacement for sustained frame/GPU profiling.

## Next stages

1. Validate v0.3.2 on Android 11 and run **Terrain > Check**, documenting the result and measured times.
2. Inspect long ridge/valley shape quality at ground-camera height and fix contour artifacts.
3. Validate thermal mass-balance, LOD edge normals, seam continuity and collision on-device.
4. Prototype a catchment-aware drainage solver *after* proving the current path/slope algorithm stays responsive on the phone; simple D8 routing alone creates visibly artificial drainage on flat areas.
5. Only after the [quality gate](QUALITY_GATE.md) passes, move to materials and object placement.

## License / origin

Independent implementation. No Terrain3D source files copied.
