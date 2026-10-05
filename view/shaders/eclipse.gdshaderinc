#ifndef SW_ECLIPSE
#define SW_ECLIPSE
// Eclipses: how much sunlight reaches a point when a body may stand in the way.
// Ships and stations read the scene's main occluder from the global sw_occluder
// (xyz its centre in world space, w its radius; w = 0 for none) and the Sun's
// direction from sw_sun; sky bodies carry their own (each sits on the sky at its
// own scale), as a per-material uniform. The edge is a penumbra that widens with
// distance behind the occluder, as the Sun's disc would make it.

// Fraction of the Sun visible from `p`: 1 in sunlight, ~0 deep in the shadow.
float sw_sunlit(vec3 p, vec3 sun, vec4 occ) {
	if (occ.w <= 0.0) {
		return 1.0;
	}
	vec3 d = occ.xyz - p;
	float along = dot(d, sun);
	if (along <= 0.0) {
		return 1.0;
	}
	float miss = length(d - sun * along);
	float pen = occ.w * 0.01 + along * 0.0015;
	return smoothstep(occ.w - pen, occ.w + pen, miss);
}
#endif
