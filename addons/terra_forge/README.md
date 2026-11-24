# TerraForge Mobile — v0.1.0 (first functional slice)

A **standalone** Godot 4.7.2 3D terrain editor addon, developed without Terrain3D, native libraries, or any changes to game scenes. Mobile Renderer is the initial target.

## Install
1. Copy `addons/terra_forge/` into any Godot 4.7.2 project.
2. Open **Project > Project Settings > Plugins** and enable **TerraForge Mobile**.
3. Open a 3D scene; find the **TerraForge** bottom panel and choose **Create Terrain**.
4. Select the generated `TerraForgeTerrain` node and toggle **Brush ON**.
5. Use left mouse drag or a single touch to Raise, Lower, Smooth or Flatten. **Brush OFF** returns normal editor camera controls.
6. Tap **Save**, or leave the brush idle for auto-save after ~3 seconds.

## Scope & data integrity
- Adds nothing outside `addons/terra_forge/` to the source repository.
- When users create terrain, its Float32 data is saved to a separate `res://terraforge_data/*.tfh` file in *their project*. The scene references this file via `data_file`; both scene and data file must be preserved when moving a project.
- A `.tfh` file is simple raw Float32 data (magic TFH1, UInt32 cells x/z, Float32 spacing, Float32 height samples row-major). It is **not** a PNG, and no quantization happens.
- Auto-save uses a temporary file and rename so interrupted writes do not overwrite a valid previous file.
- Generated tile mesh and collision children are transient; the saved scene stores only the terrain node settings.
- For preview, the entire 256×256 m grid is initially built as 32×32 m tiles. **LOD, streaming, materials, instancing, and imported heightmaps are NOT implemented in v0.1.0.**
- The editing surface is a minimum viable tool, not a performance claim against Terrain3D.

## Current limitations
- Exact Android 11 / Godot 4.7.2 device validation remains outstanding.
- Touch dispatch in the Godot Android *editor* must be verified on-device.
- Scene changes from creating a terrain node are saved by Godot's normal scene Save operation.
- Undo/Redo buttons track the last 20 brush strokes in local memory, not the global EditorUndoRedoManager yet.
- Changing width, depth, spacing or data path on an existing node requires a scene reload; saved Float32 data is authoritative.

## Development sequence
1. v0.1 — height store, editable tile meshes, touch/mouse sculpt, undo/redo, save/load.
2. v0.2 — offscreen tile streaming and LOD variants, seam tests, collision scheduling.
3. v0.3 — layered lightweight material shader and painting.
4. v0.4 — terrain stamps, foliage cells and more brushes.
5. v0.5 — profiling Android hardware, optimizing hot paths and crash tests.

## License
New TerraForge implementation. No Terrain3D source files copied.
