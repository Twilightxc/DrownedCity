// Horde zombie: vertex animation texture (VAT) on a MultiMesh, no skeleton per zombie (PHASE0 0.7).
// UV.x = the corner's VAT column, UV.y = its body part; INSTANCE_CUSTOM = (row A, row B, blend, hidden
// parts bitmask), written by HordeRenderer / CorpseLayer from each agent's clip and time. A hidden part
// collapses to one point (zero-area triangles): dismembered corpses and severed limbs reuse the mesh.
// Colour as Style 1.5: palette in vertex RGB, baked AO
// in vertex alpha, times the instance tint. Works in Compatibility (texelFetch on half-float textures).
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform highp sampler2D vat_position : filter_nearest, repeat_disable;
uniform highp sampler2D vat_normal : filter_nearest, repeat_disable;
uniform float ao_light_affect : hint_range(0.0, 1.0) = 0.35;
uniform float roughness : hint_range(0.0, 1.0) = 0.95;
uniform vec3 burn_color : source_color = vec3(1.0, 0.42, 0.08);
uniform float burn_energy = 2.2;

// INSTANCE_CUSTOM.w bit 11 (above the 11 part bits) = burning: emissive flicker, darker albedo.
// Bits 12..15 = a spot fire's part index + 1: only that part flickers (frag blasts).
varying float v_burn;
varying vec3 v_world;
// Dark rooms inside buildings (0.8 part 2), same texture as interior_cutaway; fire still glows in the dark.
global uniform sampler2D interior_light;
global uniform vec4 interior_light_rect;
global uniform float interior_light_on;
global uniform vec3 cut_origin;  // the player's position + floor y (interior_cutaway)
varying float v_seed;

void vertex() {
	int flags = int(INSTANCE_CUSTOM.w);
	int spot = (flags >> 12) & 15;
	// Every vertex of a part shares its UV.y, so the varying is constant across the part.
	v_burn = max(float((flags >> 11) & 1), (spot != 0 && spot - 1 == int(UV.y)) ? 1.0 : 0.0);
	v_seed = MODEL_MATRIX[3].x * 1.7 + MODEL_MATRIX[3].z * 2.3;
	int column = int(UV.x);
	ivec2 a = ivec2(column, int(INSTANCE_CUSTOM.x));
	ivec2 b = ivec2(column, int(INSTANCE_CUSTOM.y));
	float k = INSTANCE_CUSTOM.z;
	VERTEX = mix(texelFetch(vat_position, a, 0).xyz, texelFetch(vat_position, b, 0).xyz, k);
	NORMAL = normalize(mix(texelFetch(vat_normal, a, 0).xyz, texelFetch(vat_normal, b, 0).xyz, k));
	if (((flags >> int(UV.y)) & 1) != 0) {
		VERTEX = vec3(0.0);
	}
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// The glTF vertex colour arrives here one sRGB decode darker than the palette (dark clothes went
	// black); re-encode so the horde matches the StandardMaterial placeholder it replaces.
	ALBEDO = pow(COLOR.rgb, vec3(1.0 / 2.2));
	if (interior_light_on > 0.5 && v_world.y > cut_origin.y - 0.3) {
		ALBEDO *= texture(interior_light, (v_world.xz - interior_light_rect.xy) / interior_light_rect.zw).r;
	}
	AO = COLOR.a;
	AO_LIGHT_AFFECT = ao_light_affect;
	ROUGHNESS = roughness;
	SPECULAR = 0.2;
	if (v_burn > 0.5) {
		float flicker = 0.55 + 0.45 * sin(TIME * 17.0 + v_seed) * sin(TIME * 6.3 + v_seed * 0.7);
		ALBEDO *= 0.45;
		EMISSION = burn_color * burn_energy * flicker;
	}
}
