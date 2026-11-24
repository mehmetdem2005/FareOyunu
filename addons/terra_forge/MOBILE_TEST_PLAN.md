# Android on-device verification (not yet run)

Target editor: Godot **4.7.2**, Android **11**, **Mobile** rendering method.

## Smoke test

1. Copy only `addons/terra_forge` to a test project.
2. Enable the plugin from **Project Settings > Plugins**.
3. Open a saved 3D scene with a Node3D root.
4. Create a terrain, enable Brush, and sculpt near the center.
5. Verify a **solid top surface with no gray grid-wall skirts**. Use the compact **Terrain** popup in the 3D toolbar; the old bottom dock must be absent. Move the 3D camera to the far corner; resident/pending numbers should change when the popup is open.
6. Switch to **Mobile - light**; compare resident count, responsiveness and LOD seams.
7. Disable Brush; confirm normal camera navigation returns. Close the popup and verify the full viewport height remains usable.
8. Save Float32 data **and the scene**. Close/reopen editor and check heights.
9. Undo/redo 20 changes. Verify file bytes remain unchanged when only the camera moves.
10. Disconnect/re-enable plugin, check no duplicate tile nodes are saved.

## Advanced brush checks (0.3.1)

- Draw Ridge and Valley at 3 different angles; the shape is applied on touch release and must look continuous, without repeated circular humps
- Make a Ramp with **Rise = +6m** on flat terrain: zero at the start and +6m at its centerline end, with a smooth shoulder; then Undo and Redo
- Make another Ramp with a negative Rise value and confirm descending slope
- Select each Stamp profile (Hill/Crater/Mesa) and tap once; crater must show depressed center and raised rim
- Drag while Stamp is selected: it must stamp only once per touch, not at every drag event
- Switch tools mid-session without expanding the persistent 3D toolbar

## Shape fidelity and LOD stability (v0.3.2)

- Create one Hill, Mesa and Crater stamp: inspect edge shape from above and at ground level, checking for abrupt square borders or repeated identical circles
- Smooth an artificial peak from four camera directions; no X/Z directional streak should appear
- Orbit slowly around LOD transition radii (~72/144m): tile reconstruction should not rapidly alternate every time the camera crosses an exact boundary
- Verify shading on LOD0/1/2 tile joins: normals are computed from visible geometry, but slight shading differences can still occur
- On Mobile profile, compare pending tile rebuilds and peak Mesh CPU milliseconds while sculpting at tile borders

## Geomorphology and profiler checks

- Press **Terrain > Check**. Record PASS/FAIL and Float32/Path/Weather CPU times without modifying the original map
- Draw a new ridge over a flat world. Test from ground level; asymmetry should look coherent and not like identical cones
- Test **Weather** on steep and flat slopes. Material should move only on steep slopes, with no square edge
- Record Tiles, Vertices, Mesh last/max ms, Sculpt last/max ms before/after camera movement
- Compare balanced/mobile rendering on exactly the same camera path; observe p95 frame times, p99 spikes, thermal behavior and memory

## v0.3.3 quality checks

- On a scene with an intentionally missing `.tfh`, **Brush must remain disabled** and **Save must not create/overwrite** a blank replacement. On a separately created new scene, + New must still save correctly
- Test steep curved surfaces with side-by-side LOD0 and LOD1 tile boundaries for residual lighting stripes
- With **Terrain > Check**, record the new drainage calculation time; verify it never silently changes the loaded game's terrain
- Check a real-world representative valley manually: a local MFD patch report is not evidence of actual sediment or global hydrology
- Draw a winding 200m Ridge path and record Sculpt last/max ms; CPU allocation should be bounded by the warp-cache cap

## Stress tests

- Draw the same path once slowly and once quickly, with the same Brush Size/Power on clean areas; compare sculpt depths. A stroke should not become stronger just because Android sends more drag events.
- Verify Undo/Redo after a long continuous touch stroke, and verify a tap creates just one stamp.
- Continuous painting for at least 20 minutes and rapid orbit/pan near world boundaries.
- Repeated camera teleport between opposite corners; no stale tile load should be visible.
- Check seams at LOD0/LOD1, LOD0/LOD2 and LOD1/LOD2 transitions (including steep slopes). No vertical gray walls should appear.\n- On new terrain creation, check the centered flat plane and that the initial .tfh file exists before the first brush stroke.\n- Move camera rapidly after enabling the addon: tile nodes must appear incrementally instead of all at once.
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

This is a **resident tile streaming prototype**, not asynchronous disk IO or an infinite-world solution. The complete Float32 height array remains in RAM; only visible mesh/collision tile nodes are streamed, now created within per-frame budgets. Adjacent LOD edges use interpolated border heights rather than visible gray skirts; full edge-topology stitching remains future work. No claim of performance improvement over Terrain3D is made before profiling on Android.
