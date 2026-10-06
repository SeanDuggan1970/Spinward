// A fusion drive's exhaust: plasma leaving a magnetic nozzle in vacuum. No shock
// diamonds (those need air); just a faint, very hot jet, brightest where it is
// squeezed through the throat and thinning as it widens, so it fades over a dozen
// bell lengths. Hydrogen and helium lines give it its colour: pale blue-white in the
// dense core, violet as it thins.
//
// The mesh is only a bound (the lathe in object space, throat at z = 0, aft is +Z).
// Its far side is drawn (cull_front), and each fragment integrates the jet's glow
// along the view ray from where it enters the bound to that far side, so the plume
// reads as a volume from the side, from behind and looking straight up the nozzle.
// The drive uses two bounds that meet at the exit plane: one just inside the bell,
// so the bell's walls hide what they should, and one aft of it.
shader_type spatial;
render_mode unshaded, blend_add, cull_front, depth_draw_never, shadows_disabled, fog_disabled;

#include "res://view/shaders/noise.gdshaderinc"

// Throat radius, bell exit radius and bell length (throat to lip), metres.
uniform float rt = 0.4;
uniform float re = 2.0;
uniform float lb = 3.2;
// Spread of the free jet (tan of its half-angle) and the length over which it cools.
uniform float spread = 0.14;
uniform float fade = 12.0;
// The slab of z this bound covers, its radius at each end, and how far before z_to
// the glow fades out (0: it doesn't; the bell's bound hands over to the free jet's).
uniform float z_from = 0.0;
uniform float z_to = 3.2;
uniform float r_from = 2.0;
uniform float r_bound = 2.0;
uniform float end_fade = 0.0;
uniform float brightness = 1.0;
uniform vec3 core : source_color = vec3(0.78, 0.86, 1.0);
uniform vec3 body : source_color = vec3(0.46, 0.42, 1.0);
uniform vec3 tail : source_color = vec3(0.52, 0.3, 0.92);
uniform float seed = 0.0;

varying vec3 local;
varying vec3 cam_local;

void vertex() {
	local = VERTEX;
	cam_local = (inverse(MODEL_MATRIX) * vec4((INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz, 1.0)).xyz;
}

// The jet's width at z: through the bell it follows the field out from the throat,
// then it runs free in a narrow cone.
float jet_w(float z) {
	float inside = mix(rt * 0.8, re * 0.55, pow(clamp(z / lb, 0.0, 1.0), 0.6));
	return z < lb ? inside : re * 0.55 + (z - lb) * spread;
}

void fragment() {
	vec3 ro = cam_local;
	vec3 rd = normalize(local - cam_local);
	float t_far = length(local - cam_local);
	// Enter the bound: the slab of z, then the cylinder r < r_bound.
	float t_near = 0.0;
	if (abs(rd.z) > 1e-5) {
		float t0 = (z_from - ro.z) / rd.z;
		float t1 = (z_to - ro.z) / rd.z;
		t_near = max(t_near, min(t0, t1));
	} else if (ro.z < z_from || ro.z > z_to) {
		discard;
	}
	float a = dot(rd.xy, rd.xy);
	if (a > 1e-8) {
		float b = dot(ro.xy, rd.xy);
		float c = dot(ro.xy, ro.xy) - r_bound * r_bound;
		float disc = b * b - a * c;
		if (disc > 0.0) {
			t_near = max(t_near, (-b - sqrt(disc)) / a);
		}
	}
	t_near = min(t_near, t_far);
	// Then clip to where the ray can meet the jet at all (within two widths of the
	// axis; the jet only widens aft, so the wider end of the interval bounds it).
	// Most rays through the bound miss the jet by metres: they cost nothing, and the
	// samples go where the glow is.
	if (a > 1e-8) {
		float tc = -dot(ro.xy, rd.xy) / a;
		vec2 off = ro.xy + rd.xy * tc;
		float dc2 = dot(off, off);
		for (int k = 0; k < 2; k++) {
			float wb = 2.0 * jet_w(max(max(ro.z + rd.z * t_near, ro.z + rd.z * t_far), 0.0));
			float span2 = wb * wb - dc2;
			if (span2 <= 0.0) {
				discard;
			}
			float h = sqrt(span2 / a);
			t_near = max(t_near, tc - h);
			t_far = min(t_far, tc + h);
		}
		if (t_far <= t_near) {
			discard;
		}
	}
	// Few samples: the web build is single-threaded. The jet is smooth and the
	// samples are jittered, so a dozen is plenty.
	const int STEPS = 12;
	float dt = (t_far - t_near) / float(STEPS);
	// Jitter the samples per pixel so the steps never band.
	// (interleaved gradient noise: an even grain the eye reads as smooth).
	float jitter = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
	vec3 glow = vec3(0.0);
	float flicker = 0.94 + 0.06 * sin(TIME * 41.0 + seed * 7.0) * sin(TIME * 17.3 + seed);
	for (int i = 0; i < STEPS; i++) {
		vec3 p = ro + rd * (t_near + (float(i) + jitter) * dt);
		float z = p.z;
		if (z < -rt * 2.0) {
			continue;
		}
		float w = jet_w(max(z, 0.0));
		float q = length(p.xy) / w;
		// Exactly nothing at the bound, round the side and at the far end, so its
		// outline never shows from any angle.
		float r_edge = mix(r_from, r_bound, clamp((z - z_from) / max(z_to - z_from, 1e-3), 0.0, 1.0));
		float edge = 1.0 - smoothstep(0.6, 1.0, length(p.xy) / r_edge);
		if (end_fade > 0.0) {
			edge *= 1.0 - smoothstep(z_to - end_fade, z_to, z);
		}
		if (q > 2.0 || edge <= 0.0) {
			continue;  // past the jet's soft edge: nothing to add, skip the noise
		}
		// Flux is conserved, so density goes as 1/width^2; it glows less as it cools.
		// (A little gentler than that, so the free jet carries: a liberty for the eye.)
		// It lights up just past the throat, where the field takes hold, so the throat
		// lip never cuts a hard edge across the brightest part.
		float dens = pow(rt / w, 1.7) * exp(-z / fade) * smoothstep(-rt * 0.4, rt * 0.6, z) * edge;
		// Both Gaussians reach exactly zero at q = 2.
		float shape = max(exp(-3.0 * q * q) - exp(-12.0), 0.0);
		float filament = max(exp(-9.0 * q * q) - exp(-36.0), 0.0);
		// Faint turbulent striations streaming aft.
		vec2 around = p.xy / w;
		float n = sw_vnoise(vec3(around * 2.2 + seed, z / (w * 1.5) - TIME * 3.0));
		float d = dens * (shape * (0.6 + 0.8 * n) + filament * 1.2);
		vec3 col = mix(tail, body, smoothstep(0.004, 0.05, dens));
		col = mix(col, core, smoothstep(0.08, 0.6, dens * (shape + filament)));
		glow += col * d * dt;
	}
	glow *= brightness * flicker / max(rt, 0.05);
	ALBEDO = vec3(1.0) - exp(-glow);
}
