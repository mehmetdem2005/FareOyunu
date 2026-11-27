@tool
extends RefCounted
## TFM1: signed-by-checksum (NOT authenticated) manifest for region exports.
## A world becomes visible only after ALL TFR1 pages and manifest validate.
## Content-addresses each page by its full-file SHA-256.
const MAGIC: String = "TFM1"
const FILE_NAME: String = "manifest.tfm"
const MAX_MANIFEST_BYTES: int = 2 * 1024 * 1024
const HASH_BYTES: int = 64
const PAGE_WIDTH: int = 32
const MAX_PAGES: int = 10000
const REGIONS = preload("res://addons/terra_forge/core/region_store.gd")

static func _hash_bytes(data: PackedByteArray) -> String:
    var ctx: HashingContext = HashingContext.new()
    if ctx.start(HashingContext.HASH_SHA256) != OK:
        return ""
    if ctx.update(data) != OK:
        return ""
    return ctx.finish().hex_encode()

static func _valid_dimensions(cells: Vector2i, spacing: float) -> bool:
    return (
        cells.x >= 32 and cells.y >= 32
        and cells.x <= REGIONS.MAX_WORLD_CELLS
        and cells.y <= REGIONS.MAX_WORLD_CELLS
        and cells.x % PAGE_WIDTH == 0 and cells.y % PAGE_WIDTH == 0
        and is_finite(spacing) and spacing > 0.0
    )

static func create_document(
        dimensions: Vector2i,
        sample_spacing: float,
        source_format: String,
        source_digest: String,
        pages: Array[Dictionary]
    ) -> Dictionary:
    if not _valid_dimensions(dimensions, sample_spacing):
        return {}
    if source_format not in ["TFH1", "TFL1", "TFL2"] or source_digest.length() != HASH_BYTES:
        return {}
    var nx: int = int(dimensions.x / PAGE_WIDTH) + 1
    var nz: int = int(dimensions.y / PAGE_WIDTH) + 1
    if pages.size() != nx * nz or pages.size() > MAX_PAGES:
        return {}
    for z in range(nz):
        for x in range(nx):
            var page: Dictionary = pages[z * nx + x]
            if int(page.get("x", -1)) != x or int(page.get("z", -1)) != z:
                return {}
            if str(page.get("sha256", "")).length() != HASH_BYTES:
                return {}
    return {
        "schema": MAGIC,
        "page_format": REGIONS.MAGIC,
        "page_width": PAGE_WIDTH,
        "cells_x": dimensions.x,
        "cells_z": dimensions.y,
        "spacing": sample_spacing,
        "pages_x": nx,
        "pages_z": nz,
        "source_format": source_format,
        "source_sha256": source_digest,
        "flattened_layers": source_format != "TFH1",
        "pages": pages
    }

static func save(directory: String, document: Dictionary) -> Error:
    if directory.is_empty() or document.is_empty():
        return ERR_INVALID_PARAMETER
    var validated: Dictionary = _validated_document(document)
    if validated.is_empty():
        return ERR_INVALID_DATA
    var target: String = directory.path_join(FILE_NAME)
    if FileAccess.file_exists(target):
        return ERR_ALREADY_EXISTS
    var absolute_dir: String = ProjectSettings.globalize_path(directory)
    var mk: Error = DirAccess.make_dir_recursive_absolute(absolute_dir)
    if mk != OK:
        return mk
    var json_text: String = JSON.stringify(validated, "\t", true)
    var content: PackedByteArray = json_text.to_utf8_buffer()
    if content.is_empty() or content.size() > MAX_MANIFEST_BYTES:
        return ERR_INVALID_DATA
    var checksum: String = _hash_bytes(content)
    if checksum.length() != HASH_BYTES:
        return ERR_FILE_CORRUPT
    var temp: String = target + ".tmp"
    var f: FileAccess = FileAccess.open(temp, FileAccess.WRITE)
    if f == null:
        return FileAccess.get_open_error()
    f.store_buffer(MAGIC.to_ascii_buffer())
    f.store_32(content.size())
    f.store_buffer(content)
    f.store_buffer(checksum.to_ascii_buffer())
    f.flush()
    f.close()
    # The canonical file does not yet exist, so validate the temp directly.
    var temp_verified: Dictionary = _read_file(temp)
    if int(temp_verified["error"]) != OK:
        return int(temp_verified["error"])
    return DirAccess.rename_absolute(
        ProjectSettings.globalize_path(temp),
        ProjectSettings.globalize_path(target)
    )

static func _read_file(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {"error": ERR_FILE_NOT_FOUND}
    var f: FileAccess = FileAccess.open(path, FileAccess.READ)
    if f == null:
        return {"error": FileAccess.get_open_error()}
    var size: int = f.get_length()
    if size < 8 + HASH_BYTES + 2 or size > 8 + HASH_BYTES + MAX_MANIFEST_BYTES:
        return {"error": ERR_FILE_CORRUPT}
    if f.get_buffer(4).get_string_from_ascii() != MAGIC:
        return {"error": ERR_FILE_CORRUPT}
    var content_length: int = int(f.get_32())
    if content_length < 2 or content_length > MAX_MANIFEST_BYTES or size != 8 + content_length + HASH_BYTES:
        return {"error": ERR_FILE_CORRUPT}
    var content: PackedByteArray = f.get_buffer(content_length)
    var digest: String = f.get_buffer(HASH_BYTES).get_string_from_ascii()
    if content.size() != content_length or digest != _hash_bytes(content):
        return {"error": ERR_FILE_CORRUPT}
    var parser: JSON = JSON.new()
    if parser.parse(content.get_string_from_utf8()) != OK:
        return {"error": ERR_FILE_CORRUPT}
    if typeof(parser.data) != TYPE_DICTIONARY:
        return {"error": ERR_INVALID_DATA}
    var data: Dictionary = _validated_document(parser.data)
    if data.is_empty():
        return {"error": ERR_INVALID_DATA}
    return {"error": OK, "document": data}

static func _validated_document(data: Dictionary) -> Dictionary:
    if str(data.get("schema", "")) != MAGIC or str(data.get("page_format", "")) != REGIONS.MAGIC:
        return {}
    if int(data.get("page_width", -1)) != PAGE_WIDTH:
        return {}
    var dimensions: Vector2i = Vector2i(int(data.get("cells_x", -1)), int(data.get("cells_z", -1)))
    var sp: float = float(data.get("spacing", 0.0))
    if not _valid_dimensions(dimensions, sp):
        return {}
    var nx: int = int(dimensions.x / PAGE_WIDTH) + 1
    var nz: int = int(dimensions.y / PAGE_WIDTH) + 1
    if int(data.get("pages_x", -1)) != nx or int(data.get("pages_z", -1)) != nz:
        return {}
    var src: String = str(data.get("source_format", ""))
    if src not in ["TFH1", "TFL1", "TFL2"]:
        return {}
    if str(data.get("source_sha256", "")).length() != HASH_BYTES:
        return {}
    if bool(data.get("flattened_layers", src != "TFH1")) != (src != "TFH1"):
        return {}
    var listed: Variant = data.get("pages", null)
    if typeof(listed) != TYPE_ARRAY:
        return {}
    var pages: Array = listed
    if pages.size() != nx * nz or pages.size() > MAX_PAGES:
        return {}
    for z in range(nz):
        for x in range(nx):
            var obj: Variant = pages[z * nx + x]
            if typeof(obj) != TYPE_DICTIONARY:
                return {}
            var page: Dictionary = obj
            if int(page.get("x", -1)) != x or int(page.get("z", -1)) != z:
                return {}
            if str(page.get("sha256", "")).length() != HASH_BYTES:
                return {}
    return data

static func load(directory: String, verify_pages: bool = true) -> Dictionary:
    if directory.is_empty():
        return {"error": ERR_INVALID_PARAMETER}
    var manifest: Dictionary = _read_file(directory.path_join(FILE_NAME))
    if int(manifest["error"]) != OK or not verify_pages:
        return manifest
    var doc: Dictionary = manifest["document"]
    var dims: Vector2i = Vector2i(int(doc["cells_x"]), int(doc["cells_z"]))
    var store = REGIONS.new()
    var err: Error = store.initialize(directory, dims, float(doc["spacing"]), 1)
    if err != OK:
        return {"error": err}
    for listed in doc["pages"]:
        var page: Dictionary = listed
        var key: Vector2i = Vector2i(int(page["x"]), int(page["z"]))
        var path: String = store._path_for(key)
        if not FileAccess.file_exists(path):
            return {"error": ERR_FILE_NOT_FOUND, "page": key}
        if FileAccess.get_sha256(path) != str(page["sha256"]):
            return {"error": ERR_FILE_CORRUPT, "page": key}
        var checked: Dictionary = store._parse_page(path, key)
        if int(checked["error"]) != OK:
            return {"error": int(checked["error"]), "page": key}
    return manifest
