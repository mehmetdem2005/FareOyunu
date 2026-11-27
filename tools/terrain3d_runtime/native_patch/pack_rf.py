#!/usr/bin/env python3
"""Apply a narrowly scoped upload-only patch to pinned Terrain3D source.
CPU RF images stay authoritative; raw bytes become non-sRGB RGBA8 transport.
Only custom shaders explicitly carrying TERRAFORGE_PACKED_RF_V1 opt in.
"""
from pathlib import Path
import sys
root = Path(sys.argv[1])
def edit(path, pairs):
    p = root / path
    src = p.read_text()
    for old, new in pairs:
        if src.count(old) != 1:
            raise RuntimeError(f"Unexpected source anchor: {path}: {old!r}")
        src = src.replace(old, new)
    p.write_text(src)
edit("src/generated_texture.h", [
    ("int _size = 0;", "int _size = 0;\n\tbool _packed_rf = false;"),
    ("RID create(const TypedArray<Image> &p_layers);", "RID create(const TypedArray<Image> &p_layers, bool p_packed_rf = false);"),
])
edit("src/generated_texture.cpp", [
    ("#include <godot_cpp/classes/rendering_server.hpp>", "#include <godot_cpp/classes/rendering_server.hpp>\n#include <godot_cpp/variant/packed_byte_array.hpp>"),
    ("void GeneratedTexture::clear() {", """// RF and RGBA8 are both 4 bytes per texel. No float conversion or quantization.
static Ref<Image> tf_pack_rf(const Ref<Image> &source) {
	ERR_FAIL_COND_V(source.is_null() || source->is_empty() ||
			source->get_format() != Image::FORMAT_RF || source->has_mipmaps(), Ref<Image>());
	return Image::create_from_data(source->get_width(), source->get_height(),
			false, Image::FORMAT_RGBA8, source->get_data());
}

void GeneratedTexture::clear() {
	_packed_rf = false;"""),
    ("RID GeneratedTexture::create(const TypedArray<Image> &p_layers) {", "RID GeneratedTexture::create(const TypedArray<Image> &p_layers, bool p_packed_rf) {\n\t_packed_rf = p_packed_rf;"),
    ("_rid = RS->texture_2d_layered_create(p_layers, RenderingServer::TEXTURE_LAYERED_2D_ARRAY);", """if (_packed_rf) {
			TypedArray<Image> packed;
			for (int i = 0; i < p_layers.size(); i++) {
				Ref<Image> source = p_layers[i];
				Ref<Image> image = tf_pack_rf(source);
				ERR_FAIL_COND_V(image.is_null(), RID());
				packed.push_back(image);
			}
			_rid = RS->texture_2d_layered_create(packed, RenderingServer::TEXTURE_LAYERED_2D_ARRAY);
		} else {
			_rid = RS->texture_2d_layered_create(p_layers, RenderingServer::TEXTURE_LAYERED_2D_ARRAY);
		}"""),
    ("RS->texture_2d_update(_rid, p_image, p_layer);", """if (_packed_rf) {
		Ref<Image> packed = tf_pack_rf(p_image);
		ERR_FAIL_COND(packed.is_null());
		RS->texture_2d_update(_rid, packed, p_layer);
	} else {
		RS->texture_2d_update(_rid, p_image, p_layer);
	}"""),
])
edit("src/terrain_3d_data.cpp", [
    ('#include "terrain_3d_data.h"', '#include "terrain_3d_data.h"\n#include "terrain_3d_material.h"\n#include <godot_cpp/classes/shader.hpp>'),
    ("void Terrain3DData::update_maps(const MapType p_map_type, const bool p_all_regions, const bool p_generate_mipmaps) {", """void Terrain3DData::update_maps(const MapType p_map_type, const bool p_all_regions, const bool p_generate_mipmaps) {
	const Ref<Terrain3DMaterial> tf_material = _terrain->get_material();
	bool tf_packed_rf = false;
	if (tf_material.is_valid() && tf_material->is_shader_override_enabled()) {
		const Ref<Shader> shader = tf_material->get_shader_override();
		tf_packed_rf = shader.is_valid() && shader->get_code().contains("TERRAFORGE_PACKED_RF_V1");
	}"""),
    ("_generated_height_maps.create(_height_maps);", "_generated_height_maps.create(_height_maps, tf_packed_rf);"),
    ("_generated_control_maps.create(_control_maps);", "_generated_control_maps.create(_control_maps, tf_packed_rf);"),
])
print("TERRAFORGE_RF_UPLOAD_PATCH_APPLIED")
