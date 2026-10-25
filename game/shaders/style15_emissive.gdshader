// Lit windows / fires: vertex colour as albedo and emission; bright enough to trigger glow.
shader_type spatial;
render_mode cull_back, unshaded;

uniform float energy = 3.0;

void fragment() {
	ALBEDO = COLOR.rgb * energy;
}
