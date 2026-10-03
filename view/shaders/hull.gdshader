// Workaday hull finish: painted plate in panels with dark seams, the odd replacement
// panel in a not-quite-matching shade or bare primer, grime gathered in streaks and
// along seams, and chipped paint showing metal at the edges. Coordinates are object
// space in metres (projected along the dominant axis), so the pattern rides with the
// part and keeps its scale whatever the part's size. finish: 0 paint, 1 bare metal,
// 2 crinkled foil blanket, 3 corrugated container steel (painted).
shader_type spatial;

#include "res://view/shaders/noise.gdshaderinc"

uniform vec3 paint : source_color = vec3(0.85, 0.83, 0.78);
uniform vec3 patch_colour : source_color = vec3(0.55, 0.57, 0.58);
uniform int finish = 0;
uniform float panel_m = 1.6;
uniform float wear = 0.4;
uniform float mismatch = 0.12;
uniform float seed = 0.0;
uniform float roughness = 0.8;
uniform float metallic = 0.0;
// How panels wrap the part: 0 box faces, 1 round a cylinder's Y axis, 2 a sphere.
uniform int mapping = 0;

varying vec3 obj_pos;
varying vec3 obj_normal;

void vertex() {
	obj_pos = VERTEX;
	obj_normal = NORMAL;
}

// Lay the panel grid on the part: wrapped round cylinders and spheres, otherwise
// projected onto the face the surface mostly points along.
vec2 face_uv(vec3 p, vec3 n, out float axis) {
	vec3 a = abs(n);
	if (mapping == 1 && a.y < 0.9) {
		axis = 3.0;
		return vec2(atan(p.z, p.x) * length(p.xz), p.y);
	}
	if (mapping == 2) {
		float r = max(length(p), 1e-4);
		axis = 3.0;
		return vec2(atan(p.z, p.x) * r, asin(clamp(p.y / r, -1.0, 1.0)) * r);
	}
	if (a.x >= a.y && a.x >= a.z) {
		axis = 0.0;
		return p.zy;
	} else if (a.y >= a.z) {
		axis = 1.0;
		return p.xz;
	}
	axis = 2.0;
	return p.xy;
}

void fragment() {
	vec3 n = normalize(obj_normal);
	float axis;
	vec2 uv = face_uv(obj_pos, n, axis) + seed * 13.7;
	float px = length(fwidth(uv));
	vec3 base = paint;
	float rough = roughness;
	float metal = metallic;
	vec3 nb = vec3(0.0);
	if (finish == 2) {
		// Multi-layer insulation: crinkled, catching light in facets.
		vec3 q = obj_pos * 2.2 + seed;
		float e = 0.2;
		float c0 = sw_fbm(q, 4);
		nb = vec3(sw_fbm(q + vec3(e, 0.0, 0.0), 4), sw_fbm(q + vec3(0.0, e, 0.0), 4), sw_fbm(q + vec3(0.0, 0.0, e), 4)) - c0;
		nb = nb / e * 0.35 * (1.0 - smoothstep(0.1, 0.4, px));
		base *= 0.82 + 0.36 * mix(sw_vnoise(obj_pos * 0.7 + seed), 0.5, smoothstep(0.6, 2.0, px));
		// Taped seams between blankets.
		vec2 g = abs(fract(uv / (panel_m * 1.6)) - 0.5);
		float tape = smoothstep(0.47, 0.48, max(g.x, g.y)) * (1.0 - smoothstep(0.02, 0.06, px / (panel_m * 1.6)));
		base = mix(base, base * 0.6, tape);
		rough = 0.3 + 0.25 * c0;
		metal = 0.85;
	} else {
		// Plates on a grid, twice as long as tall; a few split in two where a
		// repair went in. Containers are long corrugated sheets.
		vec2 plate = finish == 3 ? vec2(2.4, 2.6) : vec2(panel_m * 2.0, panel_m);
		vec2 cell_uv = uv / plate;
		vec2 cell = floor(cell_uv);
		vec2 f = fract(cell_uv);
		if (finish != 3 && sw_hash13(vec3(cell, seed + 3.0)) < 0.25) {
			cell.x += f.x < 0.5 ? 0.0 : 0.5;
			f.x = fract(f.x * 2.0);
			plate.x *= 0.5;
		}
		vec3 h = sw_hash33(vec3(cell, axis * 7.0 + seed));
		// Per-panel shade, and the odd replacement in another colour or bare primer.
		// Far off, where panels shrink below a few pixels, blend to the average.
		float detail = 1.0 - smoothstep(0.15, 0.5, px / panel_m);
		base *= mix(0.99, 0.95 + 0.08 * h.x, detail);
		if (finish == 0 || finish == 3) {
			vec3 patched = mix(base, patch_colour, h.z < 0.5 ? 1.0 : 0.6);
			base = mix(base, h.y < mismatch ? patched : base, detail);
			base = mix(base, mix(base, patch_colour, 0.8), mismatch * (1.0 - detail));
		}
		if (finish == 1) {
			base *= 0.9 + 0.2 * sw_vnoise(obj_pos * 3.0 + seed);
		}
		// Seams: dark lines that fade out before they alias.
		vec2 edge = min(f, 1.0 - f) * plate;
		float d_edge = min(edge.x, edge.y);
		float seam_fade = 1.0 - smoothstep(0.015, 0.06, px);
		float seam = (1.0 - smoothstep(0.008, 0.022, d_edge)) * seam_fade;
		base *= 1.0 - 0.35 * seam;
		if (finish == 3) {
			// Ribs across the sheet: tilt the normal along the face's first axis.
			float rib = cos(uv.x * 6.2832 / 0.28);
			vec3 t = axis == 0.0 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
			nb = -t * rib * 0.35 * (1.0 - smoothstep(0.02, 0.07, px));
		}
		// Grime: soot and dust streaked along the ship, darkest near the seams.
		float streak = mix(sw_fbm(vec3(obj_pos.x * 1.5, obj_pos.y * 1.5, obj_pos.z * 0.12) + seed, 4), 0.5, smoothstep(0.3, 1.0, px));
		float grime = wear * smoothstep(0.35, 0.8, streak + (1.0 - smoothstep(0.0, 0.3, d_edge)) * 0.25);
		base = mix(base, base * vec3(0.45, 0.42, 0.38), grime * 0.75);
		rough = mix(rough, 0.95, grime);
		// Chipped paint near panel edges shows the metal underneath.
		if (finish == 0 || finish == 3) {
			float chip_n = sw_vnoise(obj_pos * 9.0 + seed * 3.0);
			float chip = smoothstep(0.78 - wear * 0.2, 0.8 - wear * 0.2, chip_n) * (1.0 - smoothstep(0.05, 0.25, d_edge)) * wear;
			chip *= 1.0 - smoothstep(0.03, 0.1, px);
			base = mix(base, vec3(0.55, 0.56, 0.56), chip);
			metal = mix(metal, 0.7, chip);
			rough = mix(rough, 0.45, chip);
		}
	}
	ALBEDO = base;
	ROUGHNESS = rough;
	METALLIC = metal;
	if (finish >= 2) {
		vec3 nn = normalize(n - (nb - n * dot(nb, n)));
		NORMAL = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(nn, 0.0)).xyz);
	}
}
