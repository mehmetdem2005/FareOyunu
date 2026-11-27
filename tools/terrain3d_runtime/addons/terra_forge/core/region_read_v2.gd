@tool
extends RefCounted
## B2 read helpers, synchronous and pure data only. B3 will use them in IO worker.
const IDX = preload("res://addons/terra_forge/core/region_index_v2.gd")
const PAGE = preload("res://addons/terra_forge/core/region_page_codec.gd")

static func open_root(directory: String) -> Dictionary:
    # Explicit format: do not silently pick a format in a mixed directory.
    if FileAccess.file_exists(directory.path_join("manifest.tfm")):
        return {"error": ERR_INVALID_DATA}
    return IDX.load_root(directory)

static func read_page(directory: String, root, key: Vector2i) -> Dictionary:
    if root == null or directory.is_empty():
        return {"error": ERR_INVALID_PARAMETER}
    var sk: Vector2i = root.shard_for_page(key)
    if sk.x < 0:
        return {"error": ERR_INVALID_PARAMETER}
    var shard: Dictionary = IDX.load_shard(directory, root, sk)
    if shard["error"] != OK:
        return shard
    return read_from_shard(directory, root, shard["index"], key)

## Internal fast path: shard must have been verified against this exact root.
static func read_from_shard(directory: String, root, shard, key: Vector2i) -> Dictionary:
    var digest: PackedByteArray = shard.page_digest(key)
    if digest.is_empty():
        return {"error": ERR_INVALID_PARAMETER}
    return PAGE.load_page(directory.path_join("r_%05d_%05d.tfr" % [key.x, key.y]), root.cells(), root.spacing(), key, digest)

static func verify_all(directory: String, root, cancelled: Callable = Callable(), progress: Callable = Callable()) -> Dictionary:
    if root == null:
        return {"error": ERR_INVALID_PARAMETER}
    var count: Vector2i = root.shard_count()
    var pages: Vector2i = root.page_count()
    var checked: int = 0
    for z in range(count.y):
        for x in range(count.x):
            if cancelled.is_valid() and cancelled.call():
                return {"error": ERR_SKIP, "verified_pages": checked}
            var sk: Vector2i = Vector2i(x, z)
            var loaded: Dictionary = IDX.load_shard(directory, root, sk)
            if loaded["error"] != OK:
                return {"error": loaded["error"], "shard": sk, "verified_pages": checked}
            var shard = loaded["index"]
            var edge: Vector2i = shard.extent()
            for lz in range(edge.y):
                for lx in range(edge.x):
                    if cancelled.is_valid() and cancelled.call():
                        return {"error": ERR_SKIP, "verified_pages": checked}
                    var key: Vector2i = sk * 16 + Vector2i(lx, lz)
                    var result: Dictionary = read_from_shard(directory, root, shard, key)
                    if result["error"] != OK:
                        return {"error": result["error"], "page": key, "verified_pages": checked}
                    checked += 1
                    if progress.is_valid():
                        progress.call("verify pages", checked, pages.x * pages.y)
    return {"error": OK, "verified_pages": checked}
