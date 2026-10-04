// Airless rocky bodies (the Moon, captured asteroids): maria and highlands, and
// craters at six scales from great basins to kilometre pits. Each crater has a bowl,
// a raised rim and, if young, a bright ejecta halo. Layers too small for the pixel
// are skipped, so the cost stays low far away and detail keeps arriving as you close.
// The pattern is a function of direction on the sphere, so it is the same at any
// mesh size in any scene; `stretch` squashes it for lumpy rocks.
shader_type spatial;
render_mode specular_disabled;

#include "res://view/shaders/noise.gdshaderinc"

uniform float radius_km = 1737.0;
uniform float seed = 3.0;
uniform vec3 highland_colour : source_color = vec3(0.53, 0.515, 0.49);
uniform vec3 mare_colour : source_color = vec3(0.27, 0.27, 0.285);
uniform float relief = 1.0;
// Largest crater layer to use, in km spacing; small rocks have no 400 km basins.
uniform float largest_km = 420.0;
// Share of the great basins flooded with dark lava.
uniform float basin_flooding = 0.42;
// Share of mid-sized craters young enough to still show bright rays.
uniform float ray_chance = 0.035;
// Polar ice caps where |latitude sine| exceeds this (0 = none; Mars about 0.9).
uniform float ice_caps = 0.0;
// Crack networks across an icy crust (Europa, Enceladus): 0 none, 1 dense.
uniform float lineae = 0.0;
uniform vec3 lineae_colour : source_color = vec3(0.55, 0.36, 0.25);
// A few very bright salt spots in young craters (Ceres' Occator faculae).
uniform float bright_spots = 0.0;
// Surface grain (regolith, rubble) cells per body radius; shows only close up.
uniform float grain_per_radius = 5200.0;

varying vec3 dir;
varying vec3 obj_normal;

void vertex() {
	dir = VERTEX;
	obj_normal = NORMAL;
}

// One layer of craters, `cells` cells across the unit sphere's radius. Only the 2x2x2
// cells nearest the point can reach it: craters stay within 0.7 cells of their centre.
// bury: how much of an old crater survives here (lava floods them); young craters
// came after the lava and are untouched. Smooth in space, so no crater is cut off.
void craters(vec3 p, float cells, float density, float depth, float footprint, float bury,
		inout vec3 grad, inout float bright) {
	float px = footprint * cells;
	if (px > 0.6) {
		return;
	}
	float fade = 1.0 - smoothstep(0.25, 0.6, px);
	vec3 q = p * cells;
	vec3 base = floor(q - 0.5);
	for (int i = 0; i < 8; i++) {
		vec3 c = base + vec3(float(i & 1), float((i >> 1) & 1), float((i >> 2) & 1));
		vec3 rnd = sw_hash33(c + seed * 17.0);
		if (rnd.z > density) {
			continue;
		}
		vec3 centre = c + 0.25 + 0.5 * sw_hash33(c * 1.7 + seed);
		// Few big, many small: a steep size spread within each layer too.
		float r = 0.07 + 0.28 * rnd.x * rnd.x * rnd.x;
		vec3 off = q - centre;
		float len = length(off);
		float d = len / r;
		if (d > 2.0) {
			continue;
		}
		// Old craters are worn shallow and soft by later impacts; young ones are crisp.
		float age = rnd.y * rnd.y;
		float young = smoothstep(0.8, 0.95, rnd.y);
		float keep = mix(bury, 1.0, young);
		float dep = depth * (0.12 + 1.1 * age) * fade * keep;
		float rim_w = mix(0.38, 0.16, age);
		// Profile slope: a parabolic bowl inside, a sharp rim at d = 1, a gentle
		// ejecta apron outside. Only the slope matters for lighting.
		// The bowl's wall eases into the rim; old craters are slumped and soft-edged.
		float soft = mix(0.55, 0.12, age);
		float dbowl = 2.0 * d * (1.0 - smoothstep(1.0 - soft, 1.0 + soft * 0.3, d));
		float x = (d - 1.0) / rim_w;
		float drim = -2.0 * x / rim_w * exp(-x * x) * 0.4 * rim_w / 0.2;
		// A central peak in the bigger young craters.
		float y = d / 0.22;
		float dpeak = r > 0.2 ? -2.0 * y / 0.22 * exp(-y * y) * 0.25 * age : 0.0;
		drim += dpeak;
		grad += (dbowl + drim) * dep * (off / max(len, 1e-5));
		bright += young * (1.0 - smoothstep(0.9, 2.0, d)) * 0.28 * fade;
		bright -= (1.0 - young) * 0.06 * max(0.0, 1.0 - d) * fade * keep;
	}
}

// Maria: great impact basins, some flooded with lava. Round, overlapping, with
// wandering shores. Returns 0..1 mare cover.
float maria(vec3 p) {
	float cells = 1.6;
	vec3 q = p * cells + (vec3(sw_fbm(p * 3.0 + seed, 4), sw_fbm(p * 3.0 + seed + 4.0, 4), sw_fbm(p * 3.0 + seed + 8.0, 4)) - 0.5) * 0.7;
	vec3 base = floor(q - 0.5);
	float cover = 0.0;
	for (int i = 0; i < 8; i++) {
		vec3 c = base + vec3(float(i & 1), float((i >> 1) & 1), float((i >> 2) & 1));
		vec3 rnd = sw_hash33(c + seed * 5.3);
		if (rnd.z > basin_flooding) {
			continue;
		}
		vec3 centre = c + 0.3 + 0.4 * sw_hash33(c * 2.3 + seed);
		float r = 0.35 + 0.35 * rnd.x;
		cover = max(cover, 1.0 - smoothstep(r * 0.75, r * 1.05, length(q - centre)));
	}
	// Shores break up into bays and islands of highland.
	return cover * smoothstep(0.3, 0.6, sw_fbm(p * 9.0 + seed * 2.0, 5) + cover * 0.3);
}

// Bright rays thrown out by a few young craters, visible from far off.
float rays(vec3 p) {
	float cells = radius_km / 320.0;
	vec3 q = p * cells;
	vec3 cell = floor(q);
	float b = 0.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			for (int z = -1; z <= 1; z++) {
				vec3 c = cell + vec3(float(x), float(y), float(z));
				vec3 rnd = sw_hash33(c + seed * 11.0);
				if (rnd.z > ray_chance) {
					continue;
				}
				vec3 off = q - (c + 0.5);
				float d = length(off);
				if (d > 1.4) {
					continue;
				}
				float streak = sw_vnoise(off / max(d, 1e-4) * 26.0 + c * 7.0);
				streak = pow(streak, 4.0) * 2.0;
				float fall = 1.0 - smoothstep(0.0, 1.4, d);
				b += (streak * fall * fall + (1.0 - smoothstep(0.02, 0.1, d)) * 0.8) * (0.5 + rnd.x);
			}
		}
	}
	return b;
}

void fragment() {
	vec3 p = normalize(dir);
	float footprint = length(fwidth(p));
	float mare = basin_flooding > 0.0 ? maria(p) : 0.0;
	float tone = sw_fbm(p * 7.0 + seed * 3.0, 5);
	vec3 albedo = mix(highland_colour, mare_colour, mare) * (0.78 + 0.44 * tone);
	vec3 grad = vec3(0.0);
	float bright = 0.0;
	// Maria are younger lava: most older craters lie buried under it.
	float bury = mix(1.0, 0.2, mare);
	float spacing[6] = float[](420.0, 130.0, 40.0, 13.0, 4.0, 1.3);
	float density[6] = float[](0.6, 0.85, 0.85, 0.8, 0.8, 0.85);
	for (int i = 0; i < 6; i++) {
		if (spacing[i] <= largest_km) {
			craters(p, radius_km / spacing[i], density[i], 0.22, footprint, i < 4 ? bury : mix(1.0, 0.6, mare), grad, bright);
		}
	}
	// Rolling ground between the craters, from noise slopes at three scales.
	for (int k = 0; k < 3; k++) {
		float f = radius_km / (60.0 / pow(4.0, float(k)));
		if (footprint * f < 0.5) {
			vec3 q = p * f + seed;
			float e = 0.15;
			float n0 = sw_vnoise(q);
			vec3 hg = vec3(sw_vnoise(q + vec3(e, 0.0, 0.0)), sw_vnoise(q + vec3(0.0, e, 0.0)), sw_vnoise(q + vec3(0.0, 0.0, e))) - n0;
			grad += hg / e * 0.07 * mix(1.0, 0.4, mare) * (1.0 - smoothstep(0.25, 0.5, footprint * f));
		}
	}
	// Grain when close: two octaves, each faded out before it can shimmer.
	for (int k = 0; k < 2; k++) {
		float gf = grain_per_radius * (k == 0 ? 0.25 : 1.0);
		float near = 1.0 - smoothstep(0.15, 0.6, footprint * gf);
		if (near > 0.0) {
			albedo *= 1.0 + (sw_fbm(p * gf + float(k) * 17.0, 2) - 0.5) * 0.14 * near;
		}
	}
	if (ray_chance > 0.0) {
		bright += rays(p) * 0.4;
	}
	if (lineae > 0.0) {
		// Ridged noise makes long, branching cracks; reddish salts stain them.
		float n1 = 1.0 - abs(sw_fbm(p * 4.0 + seed * 1.3, 4) * 2.0 - 1.0);
		float n2 = 1.0 - abs(sw_fbm(p * 11.0 + seed * 2.1, 3) * 2.0 - 1.0);
		float crack = smoothstep(0.978, 0.996, n1) + 0.6 * smoothstep(0.982, 0.997, n2);
		albedo = mix(albedo, lineae_colour, clamp(crack, 0.0, 1.0) * lineae * 0.75);
	}
	if (bright_spots > 0.0) {
		vec3 c = normalize(vec3(0.42, 0.33, 0.85));
		float spot = 1.0 - smoothstep(0.004, 0.012, length(p - c));
		bright += spot * 2.5 * bright_spots;
	}
	if (ice_caps > 0.0) {
		float cap = smoothstep(ice_caps, ice_caps + 0.03, abs(p.y) + (sw_fbm(p * 8.0 + seed, 4) - 0.5) * 0.06);
		albedo = mix(albedo, vec3(0.92, 0.92, 0.95), cap);
	}
	ALBEDO = clamp(albedo * (1.0 + bright), 0.0, 1.0);
	ROUGHNESS = 1.0;
	vec3 g = grad - p * dot(grad, p);
	vec3 n_obj = normalize(normalize(obj_normal) - g * relief);
	NORMAL = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(n_obj, 0.0)).xyz);
}
