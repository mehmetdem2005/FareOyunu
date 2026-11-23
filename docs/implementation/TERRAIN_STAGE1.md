# FareOyunu — textureless terrain stage 1 (2026-11-24)

The four separate island scenes reference EXTERNAL GLB editor preview meshes and .tres definitions; their canonical sources remain four immutable single-channel FLOAT32 EXRs, tracked by SHA256 in data/terrain/sources.json. No surface textures/materials, no collision, ocean, chunk streaming, game/world layout, RPC, or server implementation.

Open `project.godot` in Godot 4.7.2 Mobile, then open `scenes/terrain/island_*.tscn`. Preview model appears from the externally imported GLB without running the game. Select `data/terrain/island_*.tres` to change preview width/height/depth. These are abstract preview units, NOT metres or authoritative server physics. To change terrain shape edit the EXR and rerun tools/terrain/build_preview_meshes.py; source checksums must then be revised with provenance.

**Binary limitation:** GitHub connected text writes cannot upload the 4 EXRs and 4 GLBs in this operation. The complete binary assets are delivered in the downloadable project ZIP alongside this PR. They must be placed at their recorded paths; until then the GitHub branch alone is not a complete importable project.

Locally verified: EXR float32/checksum, GLB face count, normals +Y, no embedded materials/textures/images, external-only scene refs (6 unit tests). Godot 4.7.2 editor import and Android device proof **not yet performed** (engine not installed in build environment). Earlier historical 1536×1536 SE01 manifest remains unchanged; new southeast source is versioned separately.

**STOP:** Do not implement chunk, physics, server, water, foliage or any additional systems during this phase.
