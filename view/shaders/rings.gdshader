// Planetary rings on a flat quad in the planet's equatorial plane (local units are
// planet radii; the planet sits at the local origin). Lit the way a layer of icy
// particles is:
//  - Seen from the sunlit face, a thick ring reflects strongly (Lommel-Seeliger:
//    brightness goes as mu0 / (mu0 + mu)) and a thin one barely at all.
//  - Seen from the unlit face, the thin rings glow with light scattered through them
//    and the dense B ring goes dark.
//  - Each point blocks 1 - exp(-tau / mu) of what is behind it, so the C ring is a
//    veil the planet shows through.
//  - The planet's shadow falls across the rings. (A flattened planet is a scaled
//    node, and the ring is its child, so in the ring's space the planet is round.)
// The radial structure is in rings.gdshaderinc.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled, fog_disabled;

#include "res://view/shaders/rings.gdshaderinc"

// World direction towards the Sun (SkyKit.update_body keeps it current).
uniform vec3 sun_dir = vec3(1.0, 0.0, 0.0);
uniform float light = 1.0;
uniform float inner = 1.11;
uniform float outer = 2.33;

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
	float tau = sw_ring_tau(r, px);
	if (tau < 0.0005) {
		discard;
	}
	mat3 to_local = inverse(mat3(MODEL_MATRIX));
	vec3 s = normalize(to_local * normalize(sun_dir));
	vec3 cam = (inverse(MODEL_MATRIX) * INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 p = vec3(flat_pos.x, 0.0, flat_pos.y);
	vec3 v = normalize(cam - p);
	float mu0 = max(abs(s.y), 0.02);
	float mu = max(abs(v.y), 0.02);
	vec3 albedo = sw_ring_colour(r);
	float through_view = 1.0 - exp(-tau / mu);
	float bright;
	if (sign(s.y) == sign(v.y)) {
		bright = mu0 / (mu0 + mu) * (1.0 - exp(-tau * (1.0 / mu0 + 1.0 / mu)));
	} else {
		// Light that got through to our side: thin rings glow, thick ones are dark.
		bright = mu0 / max(abs(mu0 - mu), 0.05) * abs(exp(-tau / mu0) - exp(-tau / mu)) * 0.8;
	}
	// The planet's shadow: does the ray towards the Sun meet the planet?
	float b = dot(p, s);
	float miss = sqrt(max(dot(p, p) - b * b, 0.0));
	float shade = b < 0.0 ? smoothstep(0.985, 1.015, miss) : 1.0;
	// What the ring sends us, then unpremultiplied for the mix blend.
	vec3 col = albedo * (bright * 1.9 * light * shade + 0.012 * through_view);
	float alpha = clamp(through_view, 0.0, 1.0);
	ALBEDO = clamp(col / max(alpha, 1e-3), 0.0, 4.0);
	ALPHA = alpha;
}
