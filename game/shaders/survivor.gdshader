// Survivors (PHASE1 1.8): the Style 1.5 surface (vertex shade + baked AO in alpha, same light response) with
// per-survivor colours. UV.x is the face's tint channel (tools/blender/body_survivor.py): 0 = the vertex colour as it
// is, 1 skin, 2 hair, 3 top, 4 bottom, 5 shoes; the vertex colour's red is then a shade (1 = the colour itself).
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 skin : source_color = vec3(0.83, 0.61, 0.45);
uniform vec3 hair : source_color = vec3(0.23, 0.16, 0.12);
uniform vec3 top : source_color = vec3(0.79, 0.4, 0.18);
uniform vec3 bottom : source_color = vec3(0.31, 0.38, 0.47);
uniform vec3 shoes : source_color = vec3(0.24, 0.19, 0.15);
uniform float ao_light_affect : hint_range(0.0, 1.0) = 0.35;
uniform float roughness : hint_range(0.0, 1.0) = 0.85;

void fragment() {
	int ch = int(UV.x);
	vec3 albedo = COLOR.rgb;
	if (ch == 1) {
		albedo = skin * COLOR.r;
	} else if (ch == 2) {
		albedo = hair * COLOR.r;
	} else if (ch == 3) {
		albedo = top * COLOR.r;
	} else if (ch == 4) {
		albedo = bottom * COLOR.r;
	} else if (ch == 5) {
		albedo = shoes * COLOR.r;
	}
	ALBEDO = albedo;
	AO = COLOR.a;
	AO_LIGHT_AFFECT = ao_light_affect;
	ROUGHNESS = roughness;
	SPECULAR = ch == 1 ? 0.35 : 0.25;
}
