# TerraForge Mobile — v0.2.1 (surface + compact mobile UI fixes)

Standalone **Godot 4.7.2** terrain shaping addon. No Terrain3D dependency, native library, or changes to game files. Designed for Android editor testing with Mobile Renderer.

## Install / use

1. Copy **only** `addons/terra_forge/` into the root of any Godot 4.7.2 project.
2. Open **Project > Project Settings > Plugins**, enable **TerraForge Mobile**.
3. Open a saved 3D scene (Node3D root). In the **3D editor toolbar**, tap **Terrain** (next to **Brush**) to open the compact tools popup.
4. Tap **+ New** to create an empty, initially flat terrain. The popup closes so the 3D view remains unobstructed.
5. Tap **Terrain** again to choose Raise / Lower / Smooth / Flatten and adjust Size and Power.
6. Toggle **Brush** next to the Terrain button, then drag a finger or left mouse button across the surface. Toggle it off to move the editor camera.
7. In the popup, **Save** writes Float32 heights; separately save the scene with Godot. **Quality** selects Mobile / Balanced / High.

## Features implemented

- **Lossless Float32 height storage** in a versioned `.tfh` height file (little-endian TFH1 header + row-major Float32 samples).
- **Resident visual tiles**: allocate only camera-near tile nodes, with maximum active tile budget. Drop far mesh/collision nodes on travel.
- **3 mesh LODs**: tile sampling strides 1, 2 and 4 with descending mesh complexity. Adaptive skirts cover cracks where neighboring levels meet.
- **Top surface fix**: corrected the terrain's triangle winding; previously it was backface-culled and only the grey LOD skirts appeared, creating a fake hollow/checkerboard view.
- **Compact toolbar UI**: removed the giant bottom dock; one **Terrain** popup button and one **Brush** toggle live in Godot's 3D editor toolbar. Popup settings are hidden while sculpting.
- **Editor camera following** through `EditorInterface.get_editor_viewport_3d(0).get_camera_3d()`. Scene camera following while running.
- **Collision only at closest LOD**, with properly uniform scaling and pre-scaled height values.
- **Per-frame tile rebuild budget**, with edited/dirtied tiles queued rather than regenerating the whole map at once.
- Touch/mouse shaping, 20-step local Undo/Redo, 2.5-second idle autosave, corrupt file write guard.
- Live tile stats in the editor dock.

## Mobile streaming budgets (initial estimates; NOT performance measurements)

| Profile | View radius | Max resident tiles | LOD0 / LOD1 radii | Rebuilds per frame |
| --- | ---: | ---: | ---: | ---: |
| Mobile - light | 160m | 64 | 56m / 104m | 1 |
| Balanced (default) | 224m | 96 | 72m / 144m | 2 |
| High detail | 320m | 160 | 112m / 208m | 3 |

The **full Float32 height field remains in RAM**. This version streams visible **mesh + physics tiles**, not source height files from storage. It is not an infinite terrain system.

## File safety / project isolation

- This feature branch only writes paths inside `addons/terra_forge/`. It does not alter the FareOyunu game, player, project settings, or scenes.
- When a user creates a terrain in their own project, height data is saved to `res://terraforge_data/<scene>_<id>.tfh`. This is user-generated runtime content, not part of this repository's changes.
- Heightmap files are written to a temporary path then renamed. If the existing height file is corrupt/unreadable, editing and saving are blocked until recovered externally.
- Save both the scene **and** its linked `.tfh` data file when migrating a project.
- Generated tile meshes and collision nodes are internal children and are not persisted into scenes.

## Limitations / pending validation

- **The 0.2.0 UI loaded on the user's Android 11 Godot 4.7.2 editor**, but showed the hollow checkerboard due to backface-culling. Version 0.2.1 corrects the winding and replaces the bottom dock. The revised version itself still requires on-device validation; source tests were added but could not be executed here.
- Skirts conceal visual cracks, but geometry remains LOD-discontinuous at T-junctions; precise edge stitching will follow.
- The full Float32 heightmap is resident even when no mesh tile is loaded. File-backed streaming is not yet implemented.
- Tile mesh builds happen on the main thread, strictly limited per frame. A later stage can move mesh input preparation to worker threads.
- Collision is disabled for lower-detail tiles and enabled only near the camera. This is for performance; far-away physics interactions require a separate collision strategy.
- The first generation has no texture painter, terrain stamps, foliage, erosion or 3D assets.
- The 20 Undo/Redo entries live only in the terrain node's memory; Godot's global editor Undo/Redo integration remains pending.
- Brush strength depends on how many input events arrive (future update: fixed-distance or time-normalized stamping).

## Automated tests

From a project containing the addon:

```bash
godot --headless --path /path/to/project --script res://addons/terra_forge/tests/test_height_store.gd
godot --headless --path /path/to/project --script res://addons/terra_forge/tests/test_lod_policy.gd
godot --headless --path /path/to/project --script res://addons/terra_forge/tests/test_surface_faces.gd
```

See [MOBILE_TEST_PLAN.md](MOBILE_TEST_PLAN.md) for hands-on Android checks and acceptance criteria. These tests have **not yet been executed** with the Godot engine here.

## Next stages

1. Confirm v0.2.1 displays solid terrain on Android 11, and that the compact popup opens/closes without shrinking the viewport.
2. Add progressive mesh generation that prevents frame spikes during initial loading.
3. Implement true LOD seam stitching + sample-independent camera brush interaction.
4. Add lightweight tile-based 2–4 material painter and GPU budget presets.
5. Extend to file-backed height tile streaming, bounded collision cache, foliage cells and profiling.

## License / origin

Independent implementation. No Terrain3D source files copied.
