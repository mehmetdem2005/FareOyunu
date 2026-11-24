# Android on-device verification (not yet run)

Target editor: Godot **4.7.2**, Android **11**, **Mobile** rendering method.

## Smoke test

1. Copy only `addons/terra_forge` to a test project.
2. Enable the plugin from **Project Settings > Plugins**.
3. Open a saved 3D scene with a Node3D root.
4. Create a terrain, enable Brush, and sculpt near the center.
5. Move the editor 3D camera to the far corner; confirm resident/pending numbers change.
6. Switch to **Mobile - light**; compare resident count, responsiveness and LOD seams.
7. Disable Brush; confirm normal camera navigation returns.
8. Save Float32 data **and the scene**. Close/reopen editor and check heights.
9. Undo/redo 20 changes. Verify file bytes remain unchanged when only the camera moves.
10. Disconnect/re-enable plugin, check no duplicate tile nodes are saved.

## Stress tests

- Continuous painting for at least 20 minutes and rapid orbit/pan near world boundaries.
- Repeated camera teleport between opposite corners; no stale tile load should be visible.
- Check seams at LOD0/LOD1 and LOD1/LOD2 transitions (including steep slopes).
- Check physics aligns with sculpted mesh under default and 0.5m sample spacing.
- While saving, abruptly close the editor and reopen the last good file.
- Try a corrupt `.tfh` file: painting and saving must be blocked.
- Record frame time, memory, battery and perceived device heat on actual hardware.

## Targets (not measured yet)

- 30 FPS while moving camera in a representative scene
- No terrain cracks visible at play camera height
- Mobile profile respects max 64 resident tiles and rebuilds at most 1 tile/frame
- No height quantization on Float32 roundtrip

## Implementation notes

This is a **resident tile streaming prototype**, not asynchronous disk IO or an infinite-world solution. The complete Float32 height array remains in RAM; only visible mesh/collision tile nodes are streamed. LOD skirts conceal cracks; true stitched edge topology remains future work. No claim of performance improvement over Terrain3D is made before profiling on Android.
