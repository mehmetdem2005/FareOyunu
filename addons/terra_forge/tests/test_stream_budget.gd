@tool
extends SceneTree
## Regression: initial tile Node allocation must obey frame budget.
const TERRAIN = preload("res://addons/terra_forge/terrain/terra_forge_terrain.gd")
const STORE = preload("res://addons/terra_forge/core/height_store.gd")

func _initialize() -> void:
    var terrain: TerraForgeTerrain = TERRAIN.new()
    terrain.height_data = STORE.new()
    terrain.height_data.initialize(Vector2i(256, 256), 1.0)
    terrain._terrain_material = StandardMaterial3D.new()
    terrain._stream_anchor = Vector3(128, 10, 128)
    terrain._stream_anchor_valid = true
    terrain.max_visible_tiles = 16
    terrain.tile_updates_per_frame = 2
    terrain.view_distance = 224.0
    terrain._sync_resident_tiles()
    if terrain._tile_nodes.size() != 0 or terrain._tile_queue.size() != 16:
        _fail("Initial sync allocated tiles outside the frame budget", terrain)
        return
    # The production scheduler has TWO limits: count and elapsed time.
    # A slow runner can legitimately stop after one tile. Assert forward
    # progress, the hard count cap and conservation on EVERY drain instead
    # of assuming two meshes always fit into the default 3 ms time budget.
    for frame in range(16):
        if terrain._tile_queue.is_empty():
            break
        var before: int = terrain._tile_nodes.size()
        terrain._drain_tile_queue()
        var after: int = terrain._tile_nodes.size()
        var built: int = after - before
        if built < 1 or built > terrain.tile_updates_per_frame or after + terrain._tile_queue.size() != 16:
            _fail("Frame exceeded build cap, lost work or made no progress", terrain)
            return
    if terrain._tile_nodes.size() != 16 or not terrain._tile_queue.is_empty():
        _fail("Bounded drains failed to finish all desired tiles", terrain)
        return
    terrain._stream_anchor = Vector3(99999, 0, 99999)
    terrain._sync_resident_tiles()
    if not terrain._tile_nodes.is_empty() or not terrain._tile_queue.is_empty():
        _fail("Off-map camera left stale mesh or pending tiles", terrain)
        return
    terrain.free()
    print("PASS: TerraForge allocates resident mesh nodes incrementally")
    quit(0)

func _fail(message: String, terrain: Node) -> void:
    push_error("TerraForge streaming test failed: " + message)
    terrain.free()
    quit(1)
