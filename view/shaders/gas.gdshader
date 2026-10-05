// Gas and ice giants: latitude bands that shear and curl at their edges, a long-
// lived storm oval if `storm` > 0, and a soft haze at the limb. The mesh is turned so
// its local +Y is the planet's pole; `spin` turns the cloud tops (radians).
shader_type spatial;
render_mode specular_disabled;

#include "res://view/shaders/noise.gdshaderinc"
#include "res://view/shaders/rings.gdshaderinc"

uniform vec3 colour_a : source_color = vec3(0.91, 0.86, 0.77);
uniform vec3 colour_b : source_color = vec3(0.70, 0.51, 0.35);
uniform vec3 colour_c : source_color = vec3(0.54, 0.35, 0.24);
uniform float bands = 14.0;
uniform float turbulence = 0.7;
uniform float storm = 0.0;
uniform float spin = 0.0;
uniform float seed = 5.0;
// World direction towards the Sun.
uniform vec3 sun_dir = vec3(1.0, 0.0, 0.0);
// 1: the planet has Saturn's rings, and they cast their shadow across it.
uniform float ring_shadow = 0.0;
// Towards the poles the bands fade into this (Saturn's are bluer and greyer).
uniform vec3 polar_colour : source_color = vec3(0.0);
uniform float polar_lat = 0.8;

varying vec3 dir;

void vertex() {
	dir = VERTEX;
}

void fragment() {
	vec3 p = normalize(dir);
	float cs = cos(spin);
	float ss = sin(spin);
	vec3 q = vec3(cs * p.x + ss * p.z, p.y, -ss * p.x + cs * p.z);
	float footprint = length(fwidth(p));
	int oct = footprint < 0.003 ? 6 : 4;
	// Bands by latitude, pushed about by eddies that grow with turbulence.
	vec3 warp = vec3(sw_fbm(q * 3.0 + seed, oct), sw_fbm(q * 3.0 + seed + 7.0, oct), 0.0) - 0.5;
	float lat = q.y + warp.x * 0.08 * turbulence + sin(q.x * 12.0 + q.z * 9.0 + seed) * 0.004 * turbulence;
	// Belts and zones of uneven width and strength: a 1D noise across latitude
	// (two scales), rather than a regular stripe.
	float lb = lat * bands;
	float v = sw_vnoise(vec3(lb, seed, 0.0)) * 0.65 + sw_vnoise(vec3(lb * 2.7, seed + 3.0, 0.0)) * 0.35;
	vec3 col = mix(colour_b, colour_a, smoothstep(0.3, 0.7, v));
	col = mix(col, colour_c, (1.0 - smoothstep(0.12, 0.3, v)) * 0.6);
	// Eddies roll along the belt edges.
	float edge = 1.0 - smoothstep(0.0, 0.08, abs(v - 0.5));
	col = mix(col, mix(colour_a, colour_b, sw_fbm(q * 18.0 + seed, 4)), edge * 0.35 * turbulence);
	// Fine streaks along the flow.
	col *= 0.92 + 0.16 * sw_fbm(vec3(q.x * 2.0, lat * bands * 6.0, q.z * 2.0) + seed, oct);
	// The great storm: an oval vortex in the southern tropics.
	if (storm > 0.0) {
		vec2 c = vec2(atan(q.z, q.x), asin(clamp(q.y, -1.0, 1.0)));
		vec2 d = (c - vec2(1.2, -0.39)) * vec2(1.0, 2.0);
		float r = length(d);
		float swirl = sw_fbm(vec3(d * 12.0, seed), 4);
		float spot = (1.0 - smoothstep(0.10, 0.17, r + swirl * 0.04)) * storm;
		col = mix(col, vec3(0.72, 0.38, 0.26), spot);
		col = mix(col, colour_a, (1.0 - smoothstep(0.0, 0.03, abs(r - 0.18))) * 0.5 * storm);
	}
	if (polar_colour != vec3(0.0)) {
		col = mix(col, polar_colour * (0.9 + 0.2 * v), smoothstep(polar_lat, polar_lat + 0.12, abs(q.y)) * 0.8);
	}
	// The rings' shadow: follow the ray towards the Sun to the ring plane.
	if (ring_shadow > 0.0) {
		vec3 s = normalize(inverse(mat3(MODEL_MATRIX)) * normalize(sun_dir));
		if (abs(s.y) > 1e-4) {
			float t = -p.y / s.y;
			if (t > 0.0) {
				float rr = length((p + s * t).xz);
				float tau = sw_ring_tau(rr, 0.004);
				col *= mix(1.0, 0.04 + 0.96 * exp(-tau / max(abs(s.y), 0.02)), ring_shadow);
			}
		}
	}
	ALBEDO = col;
	ROUGHNESS = 1.0;
	// Haze brightens the limb a little, even on the night side's edge.
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = colour_a * rim * 0.06;
}
