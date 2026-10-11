// A thruster plume in vacuum: cold gas, faintly lit, brightest at the nozzle and
// thinning away along its length, soft at its edges (no hard silhouette), fading
// out over its short life (instance uniform fade, 0 fresh to 1 gone).
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.78, 0.85, 0.98, 1.0);
uniform float strength = 1.6;
instance uniform float fade = 0.0;

void fragment() {
	// UV.y runs from the narrow nozzle end (0) to the wide end (1).
	float along = pow(clamp(1.0 - UV.y, 0.0, 1.0), 1.8);
	float edge = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.9);
	float a = strength * along * edge * (1.0 - fade) * (1.0 - fade);
	ALBEDO = tint.rgb * a;
	ALPHA = a;
}
