// Flood water (WebGL2-safe): murky teal tinted lighter near buildings, two scrolling normal
// layers, and a foam ring along building footprints. "Near" comes from a signed-distance test
// against up to 16 footprint boxes instead of the depth buffer, so it costs no extra pass.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 deep_color : source_color = vec3(0.09, 0.20, 0.22);
uniform vec3 shallow_color : source_color = vec3(0.15, 0.29, 0.27);
uniform vec3 foam_color : source_color = vec3(0.78, 0.82, 0.77);
uniform sampler2D normal_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_b : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec2 scroll_a = vec2(0.020, 0.012);
uniform vec2 scroll_b = vec2(-0.015, 0.018);
uniform float tiling_a = 0.06;  // texture repeats per metre
uniform float tiling_b = 0.11;
uniform float normal_depth : hint_range(0.0, 2.0) = 0.5;
uniform float shallow_width = 6.0;  // metres
uniform float foam_width = 1.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.2;
uniform float specular : hint_range(0.0, 1.0) = 0.3;

uniform vec4 footprints[16];  // xy = centre (world x, z), zw = half extents
uniform int footprint_count = 0;

varying vec3 world_pos;

float box_distance(vec2 p, vec2 c, vec2 half_extents) {
	vec2 d = abs(p - c) - half_extents;
	return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float dist = 1.0e4;
	for (int i = 0; i < 16; i++) {
		if (i >= footprint_count) {
			break;
		}
		dist = min(dist, box_distance(p, footprints[i].xy, footprints[i].zw));
	}

	vec3 na = texture(normal_a, p * tiling_a + TIME * scroll_a).rgb;
	vec3 nb = texture(normal_b, p * tiling_b + TIME * scroll_b).rgb;
	NORMAL_MAP = normalize(mix(na, nb, 0.5) * 2.0 - 1.0) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = normal_depth;

	float shallow = 1.0 - smoothstep(0.0, shallow_width, dist);
	float ripple = (na.x + nb.y) * 0.5;  // reuse the normal maps as breakup noise
	float foam = (1.0 - smoothstep(0.0, foam_width, dist + (ripple - 0.5) * 0.8)) * smoothstep(0.38, 0.55, ripple);

	vec3 albedo = mix(deep_color, shallow_color, shallow * 0.7);
	ALBEDO = mix(albedo, foam_color, foam);
	ROUGHNESS = mix(roughness, 0.9, foam);
	SPECULAR = specular;
}
