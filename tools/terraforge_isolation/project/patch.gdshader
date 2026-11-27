shader_type spatial;
uniform sampler2D heights : filter_nearest, repeat_disable;
uniform bool displace;
uniform vec2 atlas_first;
varying float rock;

void vertex() {
    if (displace) {
        ivec2 p = ivec2(round(MODEL_MATRIX[3].xz + VERTEX.xz - atlas_first));
        VERTEX.y = texelFetch(heights, p, 0).r;
        float dx = texelFetch(heights, p + ivec2(1,0), 0).r - texelFetch(heights, p - ivec2(1,0), 0).r;
        float dz = texelFetch(heights, p + ivec2(0,1), 0).r - texelFetch(heights, p - ivec2(0,1), 0).r;
        NORMAL = normalize(vec3(-0.5 * dx, 1.0, -0.5 * dz));
    }
    rock = clamp((1.0 - NORMAL.y) * 3.0, 0.0, 1.0);
}

void fragment() {
    ALBEDO = mix(vec3(0.27,0.39,0.22), vec3(0.48,0.46,0.41), rock);
    ROUGHNESS = 0.95;
}
