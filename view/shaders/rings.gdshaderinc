#ifndef SW_RINGS
#define SW_RINGS
// Saturn's rings by radius (in Saturn radii, 60,268 km), after Cassini's
// occultation profiles: optical depth (how much light the particles block, seen
// face-on) and colour. Shared by the rings and by the planet, which they shadow.
//
//   D ring   1.110 - 1.236   all but invisible
//   C ring   1.239 - 1.527   faint, grey-brown, translucent, with dense plateaus
//   B ring   1.527 - 1.951   the bright, opaque one; densest across its middle
//   Cassini division 1.951 - 2.025, the Huygens gap at its inner edge
//   A ring   2.025 - 2.267   moderately dense, a little greyer; Encke gap at 2.214,
//                            Keeler gap at 2.265
//   F ring   2.324           a thin bright thread

#include "res://view/shaders/noise.gdshaderinc"

float sw_band(float r, float a, float b, float soft) {
	return smoothstep(a - soft, a + soft, r) * (1.0 - smoothstep(b - soft, b + soft, r));
}

float sw_gap(float r, float centre, float half_width) {
	return smoothstep(half_width * 0.6, half_width * 1.4, abs(r - centre));
}

// Normal optical depth at radius r. `px` is the screen footprint in radii: fine
// ringlets fade to their average before they would shimmer.
float sw_ring_tau(float r, float px) {
	float fine = mix(sw_vnoise(vec3(r * 900.0, 1.0, 0.0)), 0.5, smoothstep(0.0004, 0.002, px));
	float mid = mix(sw_vnoise(vec3(r * 160.0, 2.0, 0.0)), 0.5, smoothstep(0.002, 0.01, px));
	float broad = sw_vnoise(vec3(r * 28.0, 3.0, 0.0));
	float tau = 0.0;
	tau += 0.004 * sw_band(r, 1.11, 1.236, 0.004);
	// C ring: thin, with its plateaus.
	float c = 0.07 + 0.05 * broad;
	c += 0.3 * sw_band(r, 1.37, 1.39, 0.002) + 0.3 * sw_band(r, 1.425, 1.44, 0.002) + 0.25 * sw_band(r, 1.49, 1.50, 0.002);
	tau += c * sw_band(r, 1.239, 1.527, 0.002);
	// B ring: ~1 at its inner edge, 2-5 through the middle, falling back at the edge.
	float b = mix(1.0, 3.5, smoothstep(1.56, 1.66, r)) * (1.0 - 0.45 * smoothstep(1.88, 1.95, r));
	b *= 0.75 + 0.5 * broad;
	tau += b * sw_band(r, 1.527, 1.951, 0.0015);
	// Cassini division: mostly empty, faint ringlets, the Huygens gap clean.
	tau += (0.08 + 0.05 * mid) * sw_band(r, 1.951, 2.025, 0.002) * sw_gap(r, 1.955, 0.004);
	// A ring, with the Encke and Keeler gaps.
	float a = (0.55 + 0.2 * broad) * (1.0 - 0.25 * smoothstep(2.15, 2.25, r));
	tau += a * sw_band(r, 2.025, 2.267, 0.0015) * sw_gap(r, 2.2145, 0.0028) * sw_gap(r, 2.2647, 0.0004);
	// The F ring.
	tau += 0.35 * sw_band(r, 2.3235, 2.3245, 0.0006);
	// Ringlets everywhere, finer than the bands.
	return tau * (0.65 + 0.45 * mid + 0.25 * (fine - 0.5));
}

// Particle colour by region: the B ring a pale butterscotch, the A ring greyer, the
// C ring and Cassini division darker and browner.
vec3 sw_ring_colour(float r) {
	vec3 c_ring = vec3(0.47, 0.43, 0.38);
	vec3 b_ring = vec3(0.84, 0.76, 0.63);
	vec3 cassini = vec3(0.50, 0.46, 0.41);
	vec3 a_ring = vec3(0.74, 0.70, 0.64);
	vec3 col = mix(c_ring, b_ring, smoothstep(1.52, 1.60, r));
	col = mix(col, cassini, smoothstep(1.945, 1.955, r));
	col = mix(col, a_ring, smoothstep(2.02, 2.03, r));
	// A faint salmon cast through the middle B ring.
	col = mix(col, vec3(0.86, 0.72, 0.58), sw_band(r, 1.66, 1.88, 0.05) * 0.35);
	return col;
}
#endif
