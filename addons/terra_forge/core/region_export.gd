@tool
extends RefCounted
## Transactional first-export of the *visible composite* Float32 heights.
## No existing TFH/TFL file is modified; output directory must not exist.
## The region world is published by ONE directory rename after full checks.
const STORE = preload("res://addons/terra_forge/core/height_store.gd")
const LAYERS = preload("res://addons/terra_forge/core/height_layers.gd")
const REGIONS = preload("res://addons/terra_forge/core/region_store.gd")
const MANIFEST = preload("res://addons/terra_forge/core/region_manifest.gd")

static func _fail(error: Error, staged: String = "") -> Dictionary:
    return {"error": error, "staging": staged}

static func export_file(source_path: String, output_dir: String, cache_pages: int = 4) -> Dictionary:
    if source_path.is_empty() or output_dir.is_empty():
        return _fail(ERR_INVALID_PARAMETER)
    if cache_pages < 1 or cache_pages > 64:
        return _fail(ERR_INVALID_PARAMETER)
    var extension: String = source_path.get_extension().to_lower()
    if extension not in ["tfh", "tfl"] or not FileAccess.file_exists(source_path):
        return _fail(ERR_FILE_NOT_FOUND)
    var output_abs: String = ProjectSettings.globalize_path(output_dir)
    if DirAccess.dir_exists_absolute(output_abs) or FileAccess.file_exists(output_dir):
        return _fail(ERR_ALREADY_EXISTS)
    var file: FileAccess = FileAccess.open(source_path, FileAccess.READ)
    if file == null:
        return _fail(FileAccess.get_open_error())
    var source_format: String = file.get_buffer(4).get_string_from_ascii()
    file.close()
    if (extension == "tfh" and source_format != "TFH1") or (
        extension == "tfl" and source_format not in ["TFL1", "TFL2"]
    ):
        return _fail(ERR_FILE_CORRUPT)

    var heights: PackedFloat32Array = PackedFloat32Array()
    var dimensions: Vector2i = Vector2i.ZERO
    var spacing: float = 1.0
    if extension == "tfh":
        var source = STORE.new()
        var read_error: Error = source.load_file(source_path)
        if read_error != OK:
            return _fail(read_error)
        dimensions = source.cells
        spacing = source.spacing
        heights = source.heights
    else:
        var stack = LAYERS.new()
        var read_error: Error = stack.load_file(source_path)
        if read_error != OK:
            return _fail(read_error)
        dimensions = stack.cells
        spacing = stack.spacing
        # Export visible composite only; editable layer stack remains in
        # the unmodified source TFL1/TFL2, NOT in regional pages.
        heights = stack.compose()
    if heights.size() != (dimensions.x + 1) * (dimensions.y + 1):
        return _fail(ERR_INVALID_DATA)
    for value in heights:
        if not is_finite(value):
            return _fail(ERR_INVALID_DATA)

    var source_sha: String = FileAccess.get_sha256(source_path)
    if source_sha.length() != MANIFEST.HASH_BYTES:
        return _fail(ERR_FILE_CORRUPT)

    # Never reuse another failed conversion's staging location.
    var staging: String = output_dir + ".staging_" + str(Time.get_ticks_usec())
    var staging_abs: String = ProjectSettings.globalize_path(staging)
    if DirAccess.dir_exists_absolute(staging_abs):
        return _fail(ERR_ALREADY_EXISTS)
    var mk: Error = DirAccess.make_dir_recursive_absolute(staging_abs)
    if mk != OK:
        return _fail(mk)
    var store = REGIONS.new()
    var init: Error = store.initialize(staging, dimensions, spacing, cache_pages)
    if init != OK:
        return _fail(init, staging)
    var count: Vector2i = store.page_count()
    var pages: Array[Dictionary] = []
    var row_stride: int = dimensions.x + 1
    for z in range(count.y):
        for x in range(count.x):
            var values: PackedFloat32Array = PackedFloat32Array()
            values.resize(REGIONS.PAGE_VALUES)
            var origin_x: int = x * REGIONS.PAGE_WIDTH
            var origin_z: int = z * REGIONS.PAGE_WIDTH
            for local_z in range(REGIONS.PAGE_WIDTH):
                var gz: int = origin_z + local_z
                if gz > dimensions.y:
                    break
                for local_x in range(REGIONS.PAGE_WIDTH):
                    var gx: int = origin_x + local_x
                    if gx > dimensions.x:
                        break
                    values[local_z * REGIONS.PAGE_WIDTH + local_x] = heights[gz * row_stride + gx]
            var key: Vector2i = Vector2i(x, z)
            var error: Error = store.create_page_with_samples(key, values)
            if error != OK:
                # Staging is deliberately retained for forensic inspection;
                # it has NOT been promoted to the canonical output path.
                return _fail(error, staging)
            var region_file: String = store._path_for(key)
            var digest: String = FileAccess.get_sha256(region_file)
            if digest.length() != MANIFEST.HASH_BYTES:
                return _fail(ERR_FILE_CORRUPT, staging)
            pages.append({"x": x, "z": z, "sha256": digest})
    var flushed: Error = store.flush_all()
    if flushed != OK:
        return _fail(flushed, staging)
    var doc: Dictionary = MANIFEST.create_document(
        dimensions, spacing, source_format, source_sha, pages
    )
    if doc.is_empty():
        return _fail(ERR_INVALID_DATA, staging)
    var manifest_error: Error = MANIFEST.save(staging, doc)
    if manifest_error != OK:
        return _fail(manifest_error, staging)
    var checked: Dictionary = MANIFEST.load(staging, true)
    if int(checked.get("error", ERR_FILE_CORRUPT)) != OK:
        return _fail(int(checked["error"]), staging)
    # A source could change while the converter is computing thousands of
    # pages. Never publish a manifest claiming the wrong source snapshot.
    if FileAccess.get_sha256(source_path) != source_sha:
        return _fail(ERR_FILE_CORRUPT, staging)
    # Filesystem staging: source unchanged, target absent until this point.
    # A rename makes the whole verified snapshot visible in one step.
    var publish_error: Error = DirAccess.rename_absolute(staging_abs, output_abs)
    if publish_error != OK:
        return _fail(publish_error, staging)
    return {
        "error": OK,
        "directory": output_dir,
        "source_sha256": source_sha,
        "flattened_layers": source_format != "TFH1",
        "pages": pages.size(),
        "cells": dimensions,
        "spacing": spacing
    }
