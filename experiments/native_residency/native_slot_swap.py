#!/usr/bin/env python3
"""Apply AFTER pack_rf.py, to a disposable upstream checkout only.
No shipping build applies this patch. Fixed occupied-slot exchange, not full streaming.
"""
from pathlib import Path
import sys
root = Path(sys.argv[1])
def edit(path, old, new):
    p = root / path
    s = p.read_text()
    if s.count(old) != 1:
        raise RuntimeError(f"Unexpected anchor {path}: {old!r}")
    p.write_text(s.replace(old, new))

edit("src/generated_texture.h",
    "bool is_dirty() const { return _dirty; }",
    "bool is_dirty() const { return _dirty; }\n\tbool tf_is_packed_rf() const { return _packed_rf; }")
edit("src/terrain_3d_data.h",
    "void remove_regionp(const Vector3 &p_global_position, const bool p_update = true);",
    """// Experiment: read-only, collision-disabled scratch node only.
	Error tf_exchange_slot(const Vector2i &p_old, const Ref<Terrain3DRegion> &p_incoming,
			const TypedArray<Vector2i> &p_pins);
	void remove_regionp(const Vector3 &p_global_position, const bool p_update = true);""")
edit("src/terrain_3d_data.cpp", '#include "terrain_3d_material.h"',
    '#include "terrain_3d_material.h"\n#include <godot_cpp/classes/rendering_server.hpp>')
edit("src/terrain_3d_data.cpp",
    "void Terrain3DData::remove_regionp(const Vector3 &p_global_position, const bool p_update) {",
    """// Caller owns snapshot hash verification, generation/ticket checks and near/halo pins.
	// This prototype deliberately refuses editing, physics, instancing and scene saving.
Error Terrain3DData::tf_exchange_slot(const Vector2i &p_old,
		const Ref<Terrain3DRegion> &p_incoming, const TypedArray<Vector2i> &p_pins) {
	if (!_terrain || IS_EDITOR || !_terrain->has_meta("tf_slot_experiment") ||
			_terrain->get_meta("tf_slot_experiment") != Variant(true) ||
			!_terrain->get_data_directory().is_empty() || int(_terrain->get_collision_mode()) != 0 ||
			_terrain->get_editor() || _region_map_dirty || p_incoming.is_null()) {
		return ERR_UNAVAILABLE;
	}
	if (p_pins.has(p_old) || p_incoming->is_deleted() || p_incoming->is_modified() ||
			p_incoming->is_edited() || p_incoming->get_instances().size() != 0) {
		return ERR_BUSY;
	}
	const Vector2i incoming = p_incoming->get_location();
	const int old_index = get_region_map_index(p_old);
	const int new_index = get_region_map_index(incoming);
	const int slot = get_region_id(p_old);
	const int count = _region_locations.size();
	if (old_index < 0 || new_index < 0 || slot < 0 || slot >= count ||
			count < 1 || count > 64 || incoming == p_old || _regions.has(incoming) ||
			_region_map[new_index] != 0 || Vector2i(_region_locations[slot]) != p_old ||
			_regions.size() != count || _height_maps.size() != count ||
			_control_maps.size() != count || _color_maps.size() != count ||
			_generated_height_maps.size() != count || _generated_control_maps.size() != count ||
			_generated_color_maps.size() != count) {
		return ERR_INVALID_DATA;
	}
	// Reject any unsynchronized arrays and non-scratch region content.
	if (_generated_height_maps.is_dirty() || _generated_control_maps.is_dirty() ||
			_generated_color_maps.is_dirty() || !_generated_height_maps.tf_is_packed_rf() ||
			!_generated_control_maps.tf_is_packed_rf() ||
			!_generated_height_maps.get_rid().is_valid() ||
			!_generated_control_maps.get_rid().is_valid() ||
			!_generated_color_maps.get_rid().is_valid()) {
		return ERR_UNCONFIGURED;
	}
	for (const Vector2i &loc : _region_locations) {
		const Terrain3DRegion *reg = get_region_ptr(loc);
		if (!reg || reg->is_deleted() || reg->is_modified() || reg->is_edited() ||
				!reg->get_instances().is_empty()) {
			return ERR_BUSY;
		}
	}
	if (p_incoming->get_region_size() != _region_size ||
			p_incoming->get_vertex_spacing() != _vertex_spacing ||
			p_incoming->is_color_compressed()) {
		return ERR_INVALID_DATA;
	}
	const Ref<Image> height = p_incoming->get_height_map();
	const Ref<Image> control = p_incoming->get_control_map();
	const Ref<Image> color = p_incoming->get_color_map();
	const Ref<Image> old_color = _color_maps[slot];
	if (height.is_null() || control.is_null() || color.is_null() || old_color.is_null() ||
			height->is_empty() || control->is_empty() || color->is_empty() ||
			height->get_format() != Image::FORMAT_RF || control->get_format() != Image::FORMAT_RF ||
			color->get_format() != Image::FORMAT_RGBA8 || old_color->get_format() != Image::FORMAT_RGBA8 ||
			height->get_size() != _region_sizev || control->get_size() != _region_sizev ||
			color->get_size() != _region_sizev || height->has_mipmaps() ||
			control->has_mipmaps() || color->has_mipmaps() != old_color->has_mipmaps()) {
		return ERR_INVALID_DATA;
	}
	// Stage both packed layers before changing any CPU or GPU mapping.
	const Ref<Image> packed_h = Image::create_from_data(_region_size, _region_size,
			false, Image::FORMAT_RGBA8, height->get_data());
	const Ref<Image> packed_c = Image::create_from_data(_region_size, _region_size,
			false, Image::FORMAT_RGBA8, control->get_data());
	if (packed_h.is_null() || packed_c.is_null() || packed_h->is_empty() || packed_c->is_empty()) {
		return ERR_OUT_OF_MEMORY;
	}
	TypedArray<Vector2i> next_locations;
	next_locations.resize(count);
	for (int i = 0; i < count; ++i) {
		next_locations[i] = i == slot ? incoming : Vector2i(_region_locations[i]);
	}
	// RenderingServer submission order: same three RIDs, one layer each.
	// Upload API is void; no driver completion/rollback guarantee. Not production atomic.
	RS->texture_2d_update(_generated_height_maps.get_rid(), packed_h, slot);
	RS->texture_2d_update(_generated_control_maps.get_rid(), packed_c, slot);
	RS->texture_2d_update(_generated_color_maps.get_rid(), color, slot);
	// Publish matching CPU map and indices. No delete flag or filesystem operation.
	_regions.erase(p_old);
	_regions[incoming] = p_incoming;
	_region_locations = next_locations;
	_height_maps[slot] = height;
	_control_maps[slot] = control;
	_color_maps[slot] = color;
	_region_map[old_index] = 0;
	_region_map[new_index] = slot + 1;
	calc_height_range(false);
	emit_signal("maps_changed");
	emit_signal("height_maps_changed");
	emit_signal("control_maps_changed");
	emit_signal("color_maps_changed");
	emit_signal("region_map_changed");
	_terrain->snap();
	return OK;
}

void Terrain3DData::remove_regionp(const Vector3 &p_global_position, const bool p_update) {""")
edit("src/terrain_3d_data.cpp",
    'ClassDB::bind_method(D_METHOD("get_region_count"), &Terrain3DData::get_region_count);',
    '''ClassDB::bind_method(D_METHOD("get_region_count"), &Terrain3DData::get_region_count);
	ClassDB::bind_method(D_METHOD("tf_exchange_slot", "old_location", "incoming", "pins"), &Terrain3DData::tf_exchange_slot);''')
print("TF_NATIVE_SLOT_EXPERIMENT_PATCH_APPLIED")
