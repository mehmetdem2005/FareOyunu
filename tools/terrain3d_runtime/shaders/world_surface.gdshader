// Copyright © 2023-2026 Cory Petkovsek, Roope Palmroos, and Contributors.
// This shader is the minimum needed to allow the terrain to function, without any texturing.

shader_type spatial;
render_mode blend_mix,depth_draw_opaque,cull_back,diffuse_burley,specular_schlick_ggx,skip_vertex_transform;

/* This is an example stripped down shader with maximum performance in mind.
 * Only Autoshader/Base/Over/Blend/Holes/Colormap are supported.
 * Displacement is not enabled. Mesh Tesselation level must be set to 0.
 * All terrain normal calculations take place in vertex().
 *
 * Control map indices are processed such that each ID only requires reading ONCE.
 * The following features: projection, detiling, and paintable rotation / scale
 * cannot work with this method, without the additional samples required for blending
 * between same ID textures with different values across indices.
 */

// Defined Constants
#define MAX_REGIONS 64 // Match Terrain3DMaterial.max_regions. Set to 64-256 for mobile
#define COLOR_MAP vec4(1.0, 1.0, 1.0, 0.5)
#define DIV_255 0.003921568627450 // 1. / 255.

// Inline Functions
#define DECODE_BLEND(control) float(control >>14u & 0xFFu) * DIV_255
#define DECODE_AUTO(control) bool(control & 0x1u)
#define DECODE_BASE(control) int(control >>27u & 0x1Fu)
#define DECODE_OVER(control) int(control >>22u & 0x1Fu)
#define DECODE_HOLE(control) bool(control >>2u & 0x1u)

#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
    #define fma(a, b, c) ((a) * (b) + (c))
    #define dFdxCoarse(a) dFdx(a)
    #define dFdyCoarse(a) dFdy(a)
#endif

// Private uniforms
group_uniforms private;
uniform vec3 _target_pos = vec3(0.f);
uniform float _mesh_size = 48.f;
uniform uint _background_mode = 1u; // NONE = 0, FLAT = 1, NOISE = 2
uniform uint _mouse_layer = 0x80000000u; // Layer 32
uniform float _vertex_spacing = 1.0;
uniform float _vertex_density = 1.0; // = 1./_vertex_spacing
uniform float _subdiv = 1.0;
uniform float _region_size = 1024.0;
uniform float _region_texel_size = 0.0009765625; // = 1./region_size
uniform int _region_map_size = 32;
uniform int _region_map[1024];
uniform vec2 _region_locations[MAX_REGIONS];
uniform float _texture_normal_depth_array[32];
uniform float _texture_ao_strength_array[32];
uniform float _texture_ao_affect_array[32];
uniform float _texture_roughness_mod_array[32];
uniform float _texture_uv_scale_array[32];
uniform vec4 _texture_color_array[32];
uniform highp sampler2DArray _height_maps : repeat_disable;
uniform highp sampler2DArray _control_maps : repeat_disable;
uniform highp sampler2DArray _color_maps : source_color, filter_linear_mipmap, repeat_disable;
uniform highp sampler2DArray _texture_array_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform highp sampler2DArray _texture_array_normal : hint_normal, filter_linear_mipmap, repeat_enable;
group_uniforms;

// Public uniforms
group_uniforms general_uniforms;
uniform float ground_level : hint_range(-1000., 1000.) = 0.0;
uniform float region_blend : hint_range(.001, 1., 0.001) = 0.25;
uniform bool flat_terrain_normals = false;
uniform bool textures_enabled = true;
uniform float blend_sharpness : hint_range(0, 1) = 0.5;
group_uniforms;

group_uniforms auto_shader;
uniform float auto_slope : hint_range(0, 10) = 1.0;
uniform float auto_height_reduction : hint_range(0, 1) = 0.1;
uniform int auto_base_texture : hint_range(0, 31) = 0;
uniform int auto_overlay_texture : hint_range(0, 31) = 1;
group_uniforms;

group_uniforms macro_variation;
uniform bool macro_variation_enabled = true;
uniform vec3 macro_variation1 : source_color = vec3(1.);
uniform vec3 macro_variation2 : source_color = vec3(1.);
uniform float macro_variation_slope : hint_range(0., 1.)  = 0.333;
uniform highp sampler2D noise_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform float noise1_scale : hint_range(0.001, 1.) = 0.04; // Used for macro variation 1. Scaled up 10x
uniform float noise1_angle : hint_range(0, 6.283) = 0.;
uniform vec2 noise1_offset = vec2(0.5);
uniform float noise2_scale : hint_range(0.001, 1.) = 0.076; // Used for macro variation 2. Scaled up 10x
group_uniforms;

// Varyings & Types
varying vec3 v_vertex;
varying float v_vertex_xz_dist;
varying vec3 v_normal;
varying vec3 v_camera_pos;
varying mat3 TBN;

////////////////////////
// Vertex
////////////////////////

// Takes in world space XZ (UV) coordinates
// Returns ivec3 with:
// XY: (0 to _region_size - 1) coordinates within a region
// Z: layer index used for texturearrays, -1 if not in a region
ivec3 get_index_coord(const vec2 uv) {
	vec2 r_uv = round(uv);
	ivec2 pos = ivec2(floor(r_uv * _region_texel_size)) + (_region_map_size / 2);
	int bounds = int(uint(pos.x | pos.y) < uint(_region_map_size));
	int map_val = _region_map[pos.y * _region_map_size + pos.x];
	int raw_index = map_val - 1;
	// Real regions limited by max_regions
	int is_region = bounds * int(raw_index >= 0) * int(raw_index < MAX_REGIONS);
	// Editor dummies are negative; keep them != -1 so the shader still sees a region
	int is_dummy = bounds * int(map_val < 0);
	int layer_index = is_region * raw_index
	               + is_dummy * (map_val - 1)
	               - (1 - is_region - is_dummy);
	return ivec3(ivec2(mod(r_uv, _region_size)), layer_index);
}

// Takes in descaled (world_space / region_size) world to region space XZ (UV2) coordinates, returns vec3 with:
// XY: (0. to 1.) coordinates within a region
// Z: layer index used for texturearrays, -1 if not in a region
vec3 get_index_uv(const vec2 uv2) {
	ivec2 pos = ivec2(floor(uv2)) + (_region_map_size / 2);
	int bounds = int(uint(pos.x | pos.y) < uint(_region_map_size));
	int map_val = _region_map[pos.y * _region_map_size + pos.x];
	int raw_index = map_val - 1;
	int is_region = bounds * int(raw_index >= 0) * int(raw_index < MAX_REGIONS);
	int is_dummy = bounds * int(map_val < 0);
	int layer_index = is_region * raw_index
	               + is_dummy * (map_val - 1)
	               - (1 - is_region - is_dummy);
	return vec3(uv2 - _region_locations[layer_index], float(layer_index));
}

// Takes in world space XZ (UV) and returns if the coordinate should be part of the NONE background.
bool is_none_bg(const vec2 uv) {
	ivec4 regions = ivec4(
		get_index_coord(uv - vec2(0.5, 0.0)).z,
		get_index_coord(uv - vec2(0.0, 0.5)).z,
		get_index_coord(uv + vec2(1.0, 0.0)).z,
		get_index_coord(uv + vec2(0.0, 1.0)).z);
	return any(equal(regions, ivec4(-1)));
}

// Takes in UV2 region space coordinates, returns 1.0 or 0.0 if a region is present or not.
float check_region(const vec2 uv2) {
	ivec2 pos = ivec2(floor(uv2)) + (_region_map_size / 2);
    int bounds = int(uint(pos.x | pos.y) < uint(_region_map_size));
    int raw_index = _region_map[pos.y * _region_map_size + pos.x] - 1;
    int is_valid = bounds * int(raw_index >= 0) * int(raw_index < MAX_REGIONS);
	return float(is_valid);
}

// Takes in UV2 region space coordinates, returns a blend value (0 - 1 range) between empty, and valid regions
float get_region_blend(vec2 uv2) {
	uv2 -= 0.5011; // correct for floating point error
	const vec2 offset = vec2(0.0, 1.0);
	float a = check_region(uv2 + offset.xy);
	float b = check_region(uv2 + offset.yy);
	float c = check_region(uv2 + offset.yx);
	float d = check_region(uv2 + offset.xx);
	vec2 blend_factor = vec2(2.0 + 126.0 * (1.0 - region_blend));
	vec2 f = clamp(fract(uv2), 1e-6, 1.0 - 1e-6);
	vec2 w = 1.0 / (1.0 + exp(blend_factor * log((1.0 - f) / f)));
	float blend = mix(mix(d, c, w.x), mix(a, b, w.x), w.y);
	return (1.0 - blend) * 2.0;
}

float interpolated_height(vec2 pos) {
	const vec2 offsets = vec2(0, 1);
	vec2 index_id = floor(pos);
	ivec3 index[4];
	index[0] = get_index_coord(index_id + offsets.xy);
	index[1] = get_index_coord(index_id + offsets.yy);
	index[2] = get_index_coord(index_id + offsets.yx);
	index[3] = get_index_coord(index_id + offsets.xx);
	float h0 = texelFetch(_height_maps, index[0], 0).r;
	float h1 = texelFetch(_height_maps, index[1], 0).r;
	float h2 = texelFetch(_height_maps, index[2], 0).r;
	float h3 = texelFetch(_height_maps, index[3], 0).r;
	vec2 f = fract(pos);
	vec2 i = 1.0 - f;
	vec4 w = vec4(i.x * f.y, f.x * f.y, f.x * i.y, i.x * i.y);
	float h = h0 * w[0] + h1 * w[1] + h2 * w[2] + h3 * w[3];
	return h;
}

void vertex() {
	// Save Camera Position to varying for access in later functions
	v_camera_pos = MAIN_CAM_INV_VIEW_MATRIX[3].xyz;

	// Get vertex of flat plane in world coordinates and set world UV
	v_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	// Distance from target node to vertex on a flat plane
	v_vertex_xz_dist = length(v_vertex.xz - _target_pos.xz);

	// Geomorph vertex across clipmap LODs, set end and start for linear height interpolate
	float scale = MODEL_MATRIX[0][0];
	float inv_scale = 1.0 / scale;
	float max_xz = max(abs(v_vertex.x - _target_pos.x), abs(v_vertex.z - _target_pos.z));
	float vertex_lerp = smoothstep(0.0, 1.0, (max_xz * inv_scale - _mesh_size - 4.0) / (_mesh_size - 4.0));
	vec2 vertex_fract = fract(VERTEX.xz * 0.5) * 2.0;
	// For LOD0 morph from a regular grid to an alternating grid to align with LOD1+
	vec2 shift = (scale < _vertex_spacing / _subdiv + 1e-6) ? // LOD0 or not
		// Shift from regular to symmetric
		mix(vertex_fract, vec2(vertex_fract.x, -vertex_fract.y),
			round(fract(round(mod(v_vertex.z * inv_scale, 4.0)) *
			round(mod(v_vertex.x * inv_scale, 4.0)) * 0.25))) :
		// Symmetric shift
		vertex_fract * round((fract(v_vertex.xz * 0.25 * inv_scale) - 0.5) * 4.0);
	vec2 start_pos = v_vertex.xz * _vertex_density;
	vec2 end_pos = (v_vertex.xz - shift * scale) * _vertex_density;
	v_vertex.xz -= shift * scale * vertex_lerp;

	// UV coordinates in region space. 0-1 covers 1 region, 1-2 is the next region, etc.
	UV = v_vertex.xz * _vertex_density;

	// UV coordinates in region space + texel offset. Values are 0 to 1 within regions
	UV2 = fma(UV, vec2(_region_texel_size), vec2(0.5 * _region_texel_size));

	// Discard vertices for Holes. 1 lookup
	ivec3 v_region = get_index_coord(start_pos);
	uint control = floatBitsToUint(texelFetch(_control_maps, v_region, 0)).r;
	bool hole = DECODE_HOLE(control);

	// Show holes to all cameras except mouse camera (on exactly 1 layer)
	if ( !(CAMERA_VISIBLE_LAYERS == _mouse_layer) &&
			(hole || (_background_mode == 0u && is_none_bg(UV)))) {
		v_vertex.x = 0. / 0.;
	} else {
		// Set final vertex height, and vertex normal.
		float h, u, v;
		// This branch is static for each of the clipmap segments
		// Interpolated reads only occur where sub-texel values are required.
		if (scale < _vertex_spacing) {
			h = interpolated_height(UV);
			u = interpolated_height(UV + vec2(1, 0));
			v = interpolated_height(UV + vec2(0, 1));
		} else {
			ivec3 coord_a = get_index_coord(start_pos);
			ivec3 coord_b = get_index_coord(end_pos);
			ivec3 coord_ua = get_index_coord(start_pos + vec2(1, 0));
			ivec3 coord_ub = get_index_coord(end_pos + vec2(1, 0));
			ivec3 coord_va = get_index_coord(start_pos + vec2(0, 1));
			ivec3 coord_vb = get_index_coord(end_pos + vec2(0, 1));
			h = mix(texelFetch(_height_maps, coord_a, 0).r, texelFetch(_height_maps, coord_b, 0).r, vertex_lerp);
			u = mix(texelFetch(_height_maps, coord_ua, 0).r, texelFetch(_height_maps, coord_ub, 0).r, vertex_lerp);
			v = mix(texelFetch(_height_maps, coord_va, 0).r, texelFetch(_height_maps, coord_vb, 0).r, vertex_lerp);
		}

		// Apply background ground level and region blend
		vec2 ruv = UV * _region_texel_size;
		h = mix(h, ground_level, smoothstep(0.0, 1.0, get_region_blend(ruv)));
		u = mix(u, ground_level, smoothstep(0.0, 1.0, get_region_blend(ruv + vec2(_region_texel_size, 0.0))));
		v = mix(v, ground_level, smoothstep(0.0, 1.0, get_region_blend(ruv + vec2(0.0, _region_texel_size))));

		v_vertex.y = h;
		v_normal = normalize(vec3(h - u, _vertex_spacing, h - v));
	}

	// Convert model space to view space w/ skip_vertex_transform render mode
	VERTEX = (VIEW_MATRIX * vec4(v_vertex, 1.0)).xyz;

	// Apply terrain normals
	vec3 w_tangent = normalize(cross(v_normal, vec3(0.0, 0.0, 1.0)));
	vec3 w_binormal = normalize(cross(v_normal, w_tangent));
	TBN = mat3(w_tangent, w_binormal, v_normal);

	NORMAL = normalize((VIEW_MATRIX * vec4(v_normal, 0.0)).xyz);
	BINORMAL = normalize((VIEW_MATRIX * vec4(w_binormal, 0.0)).xyz);
	TANGENT = normalize((VIEW_MATRIX * vec4(w_tangent, 0.0)).xyz);
}

////////////////////////
// Fragment
////////////////////////

mat2 rotate_plane(float angle) {
	float c = cos(angle), s = sin(angle);
	return mat2(vec2(c, s), vec2(-s, c));
}

// World surface: four original seamless color maps, one slope/elevation blend.
uniform sampler2D soil_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D sand_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_tex : source_color, filter_linear_mipmap, repeat_enable;

void fragment() {
	vec3 wn = normalize(v_normal);
	vec3 p = v_vertex;
	float steep = smoothstep(0.18, 0.58, 1.0 - abs(wn.y));
	float low = 1.0 - smoothstep(1.0, 8.0, p.y);
	float high = smoothstep(34.0, 85.0, p.y);
	float variation = 0.5 + 0.25*sin(p.x*0.073 + p.z*0.026) + 0.25*sin(p.z*0.119-p.x*0.032);
	float meadow = smoothstep(0.25, 0.65, variation) * (1.0-low) * (1.0-high) * (1.0-steep);
	vec2 world_uv = p.xz;
	vec3 soil = texture(soil_tex, world_uv / 2.6).rgb;
	vec3 grass = texture(grass_tex, world_uv / 3.1).rgb;
	vec3 sand = texture(sand_tex, world_uv / 1.8).rgb;
	vec3 rock = texture(rock_tex, world_uv / 5.0).rgb;
	vec3 base = mix(soil, grass, meadow);
	base = mix(base,sand,low*(1.0-steep));
	base = mix(base,rock,max(steep,high*0.58));
	ALBEDO = base * mix(0.82,1.12,variation);
	ROUGHNESS = 0.88;
	SPECULAR = 0.14;
}
