// Planetary rings on a flat quad: ringlets and gaps by radius (in planet radii), lit
// from both faces. inner/outer are the ring system's edges; Saturn's Cassini division
// and Encke gap are cut where they really are.
shader_type spatial;
render_mode cull_disabled, specular_disabled, depth_draw_opaque;

#include "res://view/shaders/noise.gdshaderinc"

uniform float inner = 1.24;
uniform float outer = 2.27;
uniform vec3 colour : source_color = vec3(0.86, 0.78, 0.62);
uniform float opacity = 0.85;

varying vec2 flat_pos;

void vertex() {
	flat_pos = VERTEX.xz;
}

void fragment() {
	float r = length(flat_pos);
	if (r < inner || r > outer) {
		discard;
	}
	float px = fwidth(r);
	// Many ringlets at several scales, faded out before they shimmer.
	float fine = sw_vnoise(vec3(r * 140.0, 0.0, 0.0));
	float mid = sw_vnoise(vec3(r * 30.0, 3.0, 0.0));
	float detail = mix(fine, 0.5, smoothstep(0.002, 0.01, px));
	float density = 0.55 + 0.35 * mid + 0.25 * (detail - 0.5);
	// The C ring is faint, B bright, A in between.
	density *= mix(0.35, 1.0, smoothstep(1.48, 1.55, r));
	density *= mix(1.0, 0.75, smoothstep(2.02, 2.05, r));
	// Gaps: Cassini division and the Encke gap.
	density *= 1.0 - (1.0 - smoothstep(0.0, 0.02, abs(r - 1.99) - 0.035)) * 0.85;
	density *= 1.0 - (1.0 - smoothstep(0.0, 0.004, abs(r - 2.21) - 0.003)) * 0.9;
	density *= smoothstep(inner, inner + 0.02, r) * (1.0 - smoothstep(outer - 0.02, outer, r));
	if (density * opacity < 0.08) {
		discard;
	}
	ALBEDO = colour * (0.8 + 0.4 * mid);
	ROUGHNESS = 1.0;
	// Light both faces (sunlight filters through the ring particles).
	NORMAL = FRONT_FACING ? NORMAL : -NORMAL;
	BACKLIGHT = colour * 0.5;
}
