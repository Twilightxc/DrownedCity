// Horde zombie: vertex animation texture (VAT) on a MultiMesh, no skeleton per zombie (PHASE0 0.7).
// UV.x = the corner's VAT column; INSTANCE_CUSTOM = (row A, row B, blend, unused), written by
// HordeRenderer from each agent's clip and time. Colour as Style 1.5: palette in vertex RGB, baked AO
// in vertex alpha, times the instance tint. Works in Compatibility (texelFetch on half-float textures).
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform highp sampler2D vat_position : filter_nearest, repeat_disable;
uniform highp sampler2D vat_normal : filter_nearest, repeat_disable;
uniform float ao_light_affect : hint_range(0.0, 1.0) = 0.35;
uniform float roughness : hint_range(0.0, 1.0) = 0.95;

void vertex() {
	int column = int(UV.x);
	ivec2 a = ivec2(column, int(INSTANCE_CUSTOM.x));
	ivec2 b = ivec2(column, int(INSTANCE_CUSTOM.y));
	float k = INSTANCE_CUSTOM.z;
	VERTEX = mix(texelFetch(vat_position, a, 0).xyz, texelFetch(vat_position, b, 0).xyz, k);
	NORMAL = normalize(mix(texelFetch(vat_normal, a, 0).xyz, texelFetch(vat_normal, b, 0).xyz, k));
}

void fragment() {
	// The glTF vertex colour arrives here one sRGB decode darker than the palette (dark clothes went
	// black); re-encode so the horde matches the StandardMaterial placeholder it replaces.
	ALBEDO = pow(COLOR.rgb, vec3(1.0 / 2.2));
	AO = COLOR.a;
	AO_LIGHT_AFFECT = ao_light_affect;
	ROUGHNESS = roughness;
	SPECULAR = 0.2;
}
