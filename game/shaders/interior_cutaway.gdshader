// Building interior pieces (PHASE0 0.8): Style 1.5 colour (palette in vertex RGB, baked AO in alpha) plus
// the cutaway. While the player is inside, every wall of the player's storey drops to waist height: each
// fragment of that storey's pieces (storey_floor = the player's floor) higher than cut_height above it is
// discarded, on every side (J, 2026-10-29: cutting only the camera's side left far walls hiding the zombies
// behind them). Storeys above are untouched, so they still shade the interior. Back faces exposed by the cut draw as a dark cap,
// so walls read as solid. Rooms out of sight stay dark through the interior_light texture.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

global uniform float cut_on;
global uniform vec3 cut_origin;  // player position: xz + floor y
global uniform float cut_height;
// Dark rooms (0.8 part 2): one texel per cell of the player's storey, 0 = black .. 1 = lit (InteriorLighting).
global uniform sampler2D interior_light;
global uniform vec4 interior_light_rect;  // origin x, z; size x, z (m)
global uniform float interior_light_on;

uniform vec3 cap_color : source_color = vec3(0.16, 0.14, 0.13);
uniform float storey_floor = -1000.0;  // floor height of the storey this piece belongs to (InteriorBuilder)
uniform float ao_light_affect : hint_range(0.0, 1.0) = 0.35;
uniform float roughness : hint_range(0.0, 1.0) = 0.9;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (cut_on > 0.5) {
		float above = world_pos.y - (cut_origin.y + cut_height);
		if (above > 0.0 && abs(storey_floor - cut_origin.y) < 0.01) {
			discard;
		}
	}
	// Same re-encode as horde_vat: the glTF vertex colour reaches COLOR one sRGB decode too dark.
	ALBEDO = FRONT_FACING ? pow(COLOR.rgb, vec3(1.0 / 2.2)) : cap_color;
	// Only the player's storey: the outside faces of the storeys below must not turn black.
	if (interior_light_on > 0.5 && world_pos.y > cut_origin.y - 0.3) {
		ALBEDO *= texture(interior_light, (world_pos.xz - interior_light_rect.xy) / interior_light_rect.zw).r;
	}
	AO = FRONT_FACING ? COLOR.a : 1.0;
	AO_LIGHT_AFFECT = ao_light_affect;
	ROUGHNESS = roughness;
	SPECULAR = 0.25;
}
