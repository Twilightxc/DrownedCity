// Building interior pieces (PHASE0 0.8): Style 1.5 colour (palette in vertex RGB, baked AO in alpha) plus
// the cutaway. While the player is inside, every fragment higher than cut_height above the player's floor
// AND on the camera's side of the player is discarded, so the walls between camera and player drop to
// waist height. The cut follows the camera yaw (cut_toward_camera is updated every frame), so it stays
// right after each 90° turn. Back faces exposed by the cut draw as a dark cap, so walls read as solid.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

global uniform float cut_on;
global uniform vec3 cut_origin;  // player position: xz + floor y
global uniform vec2 cut_toward_camera;  // unit, world XZ
global uniform float cut_height;

uniform vec3 cap_color : source_color = vec3(0.16, 0.14, 0.13);
uniform float margin = 0.6;  // m behind the player that is still cut (walls the player stands against)
uniform float ao_light_affect : hint_range(0.0, 1.0) = 0.35;
uniform float roughness : hint_range(0.0, 1.0) = 0.9;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (cut_on > 0.5) {
		float above = world_pos.y - (cut_origin.y + cut_height);
		float toward = dot(world_pos.xz - cut_origin.xz, cut_toward_camera);
		if (above > 0.0 && toward > -margin) {
			discard;
		}
	}
	// Same re-encode as horde_vat: the glTF vertex colour reaches COLOR one sRGB decode too dark.
	ALBEDO = FRONT_FACING ? pow(COLOR.rgb, vec3(1.0 / 2.2)) : cap_color;
	AO = FRONT_FACING ? COLOR.a : 1.0;
	AO_LIGHT_AFFECT = ao_light_affect;
	ROUGHNESS = roughness;
	SPECULAR = 0.25;
}
