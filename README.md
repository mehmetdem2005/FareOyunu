# FareOyunu — Terrain directly from original uploaded images

Godot 4.7.2 stable / Mobile Renderer. Open `scenes/world/world_preview.tscn` to see all four textureless islands **in the editor without pressing Play**.

## Source integrity
The four files provided as `.png` actually contain **JPEG** data. They are copied **byte-for-byte unchanged** into `assets/terrain/heightmaps/*_original.jpg`; only the extension matches the actual codec. Check SHA-256 in `data/terrain/sources.json`. No regenerated/reconstructed heightmaps, smoothing, erosion, procedural relief or EXR conversion occurs.

The `*.glb` files are *geometry preview meshes*, sampled from original brightness (L) with bilinear vertex interpolation. A 0.020 display-only cutoff trims the black sea background. Neither operation produces a new heightmap or restores lost 8-bit/JPEG source precision.

## Editor controls
- All four in `scenes/world/world_preview.tscn`.
- Individual scenes: `scenes/terrain/island_*.tscn`.
- Preview-only height and width: `data/terrain/island_*.tres`.
- Provisional editor placement: `data/world/world_preview_layout.tres`.

The world layout units are not approved metres. No textures/materials, ocean, collision, chunk streaming, multiplayer or player logic have been added.

## Binary asset status
The complete 4 JPEG byte-copies and 4 GLB preview binaries are delivered in the **downloadable ZIP**. GitHub connector writes only text files here; until corresponding binary assets are committed to `assets/terrain/`, the GitHub branch alone is NOT import-ready.

Godot editor/runtime/mobile import has not been tested by the assistant. The user can import the complete ZIP locally.

Main engineering policy: AGENTS.md; pipeline: docs/production/PIPELINE.md; world architecture: docs/architecture/WORLD_ARCHITECTURE.md.
