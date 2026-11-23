# Stage 1 — Direct-source terrain preview (2026-11-24)

Scope: **only** 4 independently sourced textureless island preview meshes + a combined editor world scene. No map drawings or conversion to 32-bit.

All four uploaded files with .png filenames have JPEG magic bytes. They are **byte copied** into correctly named .jpg files; SHA256, dimension, codec and source filenames are versioned in `data/terrain/sources.json`. No source pixel changes.

`tools/terrain/build_preview_meshes.py` reads RGB JPEG brightness as L and constructs a preview GLB from sampled height values, clipping the sea background triangles at a small visual-only threshold 0.020. This creates **mesh vertices only**, not a new heightmap. The display threshold and preview vertical scale are not authoritative coastline or elevations in metres.

The scene hierarchy references external island .tscn, .tres and GLB assets; placement exists in a separate world preview resource. The editor @tool scripts only adjust transforms; no chunk/physics/network dependencies.

Local complete ZIP: 6 tests passed: source hash/format, four islands, GLB no material/texture, mesh normals, external scene references, and no regenerated heightmap assets.

Unverified: Godot 4.7.2 actual editor import, Mobile Renderer on phone and scale aesthetics. GitHub text-only branch is missing 8 binary assets (4 JPEGs, 4 GLBs); do not claim GitHub branch imports cleanly.
