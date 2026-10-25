// Style 1.5 surface: flat palette colour from vertex RGB, baked AO from vertex alpha,
// wet stain + algae band measured from the global water level (matches tools/blender/scene_v15_web.py).
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

global uniform float water_level;

uniform vec3 wet_tint : source_color = vec3(0.243, 0.290, 0.227);
uniform vec3 algae_color : source_color = vec3(0.302, 0.416, 0.235);
uniform float wet_height = 2.4;
uniform float wet_amount : hint_range(0.0, 1.0) = 0.7;
uniform float algae_height = 0.7;
uniform float algae_amount : hint_range(0.0, 1.0) = 0.6;
uniform float ao_light_affect : hint_range(0.0, 1.0) = 0.35;
uniform float roughness : hint_range(0.0, 1.0) = 0.9;

varying float world_y;

void vertex() {
	world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	float h = world_y - water_level;
	vec3 albedo = COLOR.rgb;
	albedo = mix(albedo, albedo * wet_tint, (1.0 - smoothstep(0.3, wet_height, h)) * wet_amount);
	albedo = mix(albedo, algae_color, (1.0 - smoothstep(0.0, algae_height, h)) * algae_amount);
	ALBEDO = albedo;
	AO = COLOR.a;
	AO_LIGHT_AFFECT = ao_light_affect;
	ROUGHNESS = roughness;
	SPECULAR = 0.3;
}
