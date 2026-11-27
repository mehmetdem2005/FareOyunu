# P1.8.1 — Native clipmap profile cost audit

Pinned upstream:
- https://github.com/TokisanGames/Terrain3D/blob/v1.1.0-stable/src/terrain_3d_mesher.cpp (_generate_mesh_types, _generate_mesh, _generate_clipmap, _generate_offset_data, snap, update_aabbs).
- https://github.com/TokisanGames/Terrain3D/blob/v1.1.0-stable/src/terrain_3d.cpp (set_mesh_lods, set_mesh_size, set_vertex_spacing, __physics_process).
- Local world_surface.gdshader and terrain_runtime.gd.

## Exact source-derived topology, not measured draw counts
Each w*h quad mesh has 2*w*h triangles. LOD0 uses 16 tiles, 2 edge A, 2 edge B, 2 trim A, 2 trim B = 24 instances. Each later ring uses 12 tiles, 4 edges, 4 fills = 20 instances. Tile width m. Edge pair contributions 8*(4m+8)+8*(4m+4)=64m+96 triangles. Trim contribution 16*(4m+2), fills 32m. LOD0 triangles 32m²+128m+128; later ring 24m²+96m+96. Total = near + (L-1)*ring. Nominal outer TILE half-width for L>=2 = (2m+2)*spacing*2^(L-1), around snapped target; edge strips and morph extend/change it. Near tile half-width 2m*spacing, not guaranteed full-resolution distance (geomorph begins earlier). Tessellation zero. Counts include entire mesh topology even if culled, outside world, or discarded; actual submitted triangles/draw calls and GPU cost differ. No FPS inference.

| m | L | near triangles | outer-ring triangles each | total triangles | instances | nominal near tile half-width m | outer tile half-width m |
|---|---|---|---|---|---|---|---|
| 16 | 6 | 10368 | 7776 | 49248 | 124 | 8 | 272 |
| 16 | 7 | 10368 | 7776 | 57024 | 144 | 8 | 544 |
| 16 | 8 | 10368 | 7776 | 64800 | 164 | 8 | 1088 |
| 8 | 8 | 3200 | 2400 | 20000 | 164 | 4 | 576 |
| 32 | 6 | 36992 | 27744 | 175712 | 124 | 16 | 528 |

## Decisions
- Keep 16/7/0.25 current baseline and 850m camera far. LOD6 (16/6) removes 7776 nominal triangles but halves outer extent; not default. LOD8 adds 7776 triangles and 20 instances; potential silhouette coverage improvement, no forced change. 8/8 much lower nominal triangles but halves near tile area width and moves coarser transitions inward; not compatible with near detail requirement without visual proof. 32/6 more near coverage and triangles, not mobile default.
- Godot camera far change alone does not resize clipmap; only frustum/culling effect. Native set_mesh_lods and set_mesh_size call material update and _setup_terrain_mesher; _generate_clipmap frees/recreates instances and shared meshes. Runtime oscillation between profiles is risky; no automatic LOD setter per-frame. set_vertex_spacing rebuilds collision too; locked at .25.
- Strong native CPU candidate: snap() always sends target uniform; returns if max XZ movement < spacing; when exceeded, loops ALL LODs/instances, sends instance_set_transform and instance_teleport even when coarse ring's rounded center and next-ring test_x/z are unchanged. For baseline up to 144 transform + 144 teleport submissions per accepted snap, not measured. An isolated native patch could compare cached integer snap center and edge-selector tuple per LOD, skip unchanged ring transforms; preserve continuous shader target updates, initialization/rebuild invalidation, teleports and camera switches; do not change topology, physics or near quality. Need Android native build/toolchain, equivalence and real measurement before promotion. Do not fake this optimization in GDScript or suppress snap globally.
- Existing vertex shader height sample cost includes six height reads for non-tessellated morph/normal path, plus control and region lookup, plus region blending; fragment uses four surface texture reads. Shader safety branch/clamp cost from P1.7.10 unmeasured. Prior V2 report 59.99 FPS excluding 2 stalls at cap; no uncapped reserve measurement. Prefer removing redundant native submissions and unused shader work over lowering geometry. 
- P1.8.2: consider fixed safe startup profile / opt-in profile or measured camera range with conservative hysteresis, no automatic rebuild while walking; near quality and visible horizon protected. P1.8.3 native geomorph transitions visual verification. P1.8.4 conservative culling only after visibility proof. No new benchmark per user.
- Current source audit is complete; device timing and actual render equivalence remain open. No runtime change in this commit. P1.7.10 package passed 46021022190, visual verification still open. P1.7.5–8 remain deferred, not complete. Overall 14/43 source/implementation/package milestones.