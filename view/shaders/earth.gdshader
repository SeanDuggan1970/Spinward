// Earth: oceans with sun glint, continents with latitude biomes, polar ice, drifting
// cloud, city lights on the night side and a thin blue limb. Procedural and seamless;
// `spin` turns the planet (radians) and `sun_dir` (world space) lights the cities.
shader_type spatial;
render_mode shadows_disabled;

#include "res://view/shaders/noise.gdshaderinc"

uniform float seed = 7.0;
uniform float spin = 0.0;
uniform vec3 sun_dir = vec3(1.0, 0.0, 0.0);
uniform float land_level = 0.53;
uniform float cloud_cover = 0.5;

varying vec3 dir;
varying vec3 world_normal;

// Earth's axis is tilted 23.4 degrees from ecliptic north (Godot +Y here).
const float TILT = 0.4091;

vec3 to_body(vec3 v) {
	float ct = cos(TILT);
	float st = sin(TILT);
	v = vec3(v.x, ct * v.y - st * v.z, st * v.y + ct * v.z);
	float cs = cos(spin);
	float ss = sin(spin);
	return vec3(cs * v.x + ss * v.z, v.y, -ss * v.x + cs * v.z);
}

void vertex() {
	dir = VERTEX;
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	vec3 p = to_body(normalize(dir));
	float footprint = length(fwidth(p));
	int oct = footprint < 0.002 ? 8 : 6;
	float lat = abs(p.y);
	// Continents: warped fbm so coastlines wander.
	vec3 warp = vec3(sw_fbm(p * 2.0 + seed, 4), sw_fbm(p * 2.0 + seed + 5.2, 4), sw_fbm(p * 2.0 + seed + 9.7, 4));
	float h = sw_fbm(p * 1.7 + warp * 1.4 + seed, oct);
	float land = smoothstep(land_level - 0.004, land_level + 0.004, h);
	float elev = clamp((h - land_level) / 0.2, 0.0, 1.0);
	// Biomes by latitude, broken up by noise.
	float wobble = (sw_fbm(p * 6.0 + seed * 2.0, 4) - 0.5) * 0.25;
	float l = lat + wobble;
	vec3 tropic = vec3(0.10, 0.22, 0.07);
	vec3 desert = vec3(0.55, 0.45, 0.30);
	vec3 temperate = vec3(0.20, 0.27, 0.12);
	vec3 boreal = vec3(0.13, 0.18, 0.11);
	vec3 tundra = vec3(0.40, 0.38, 0.33);
	vec3 ground = tropic;
	float dry = smoothstep(0.45, 0.6, sw_fbm(p * 3.0 + seed * 6.0, 4));
	ground = mix(ground, desert, dry * smoothstep(0.16, 0.26, l) * (1.0 - smoothstep(0.42, 0.52, l)));
	ground = mix(ground, temperate, smoothstep(0.45, 0.55, l));
	ground = mix(ground, boreal, smoothstep(0.62, 0.7, l));
	ground = mix(ground, tundra, smoothstep(0.76, 0.84, l));
	ground = mix(ground, vec3(0.42, 0.38, 0.34), smoothstep(0.45, 0.8, elev));
	ground *= 0.9 + 0.2 * sw_fbm(p * 40.0 + seed, 4);
	// Ocean: deep blue, paler over the shelves.
	vec3 ocean = mix(vec3(0.02, 0.07, 0.18), vec3(0.05, 0.20, 0.30), smoothstep(land_level - 0.06, land_level, h));
	vec3 albedo = mix(ocean, ground, land);
	float ice = smoothstep(0.86, 0.9, lat + wobble * 0.5 + (land > 0.5 ? 0.04 : 0.0) + elev * 0.1);
	albedo = mix(albedo, vec3(0.88, 0.9, 0.93), ice);
	// Clouds: banded by latitude, drifting slowly.
	vec3 cp = p + vec3(TIME * 0.0015, 0.0, 0.0);
	float cw = sw_fbm(cp * 3.0 + seed * 4.0, 4);
	float cl = sw_fbm(cp * vec3(4.0, 9.0, 4.0) + cw * 2.0, oct - 1);
	float band = 0.75 + 0.25 * cos(lat * 9.0);
	float cloud = smoothstep(1.0 - cloud_cover, 1.05 - cloud_cover * 0.6, cl * band + 0.12);
	albedo = mix(albedo, vec3(0.93), cloud * 0.92);
	ALBEDO = albedo;
	float water = (1.0 - land) * (1.0 - ice) * (1.0 - cloud);
	ROUGHNESS = mix(0.95, 0.42, water);
	SPECULAR = mix(0.2, 0.45, water);
	// Night side: city lights on inhabited land, hidden by cloud.
	vec3 nw = normalize(world_normal);
	float day = dot(nw, normalize(sun_dir));
	float night = smoothstep(0.05, -0.15, day);
	// Settled regions, busiest along coasts, then towns as fine clusters within them.
	float coast = 1.0 - smoothstep(0.0, 0.05, h - land_level);
	float region = smoothstep(0.42, 0.62, sw_fbm(p * 8.0 + seed * 9.0, 4) + coast * 0.15)
		* (1.0 - smoothstep(0.65, 0.8, lat)) * (1.0 - smoothstep(0.3, 0.7, elev)) * (1.0 - dry * 0.7);
	// Towns at two scales: clusters visible from afar, then specks of light close up.
	float towns = 0.12;
	float fp = footprint * 70.0;
	if (fp < 0.6) {
		float clusters = smoothstep(0.58, 0.82, sw_vnoise(p * 70.0 + seed));
		float fine = 0.45;
		if (footprint * 400.0 < 0.6) {
			fine = mix(smoothstep(0.55, 0.85, sw_vnoise(p * 400.0 + seed * 2.0)), 0.45, smoothstep(0.25, 0.6, footprint * 400.0));
		}
		towns = mix(clusters * (0.35 + fine * 1.4), 0.12, smoothstep(0.25, 0.6, fp));
	}
	float city = land * region * towns * (1.0 - cloud * 0.85) * (1.0 - ice);
	// Seen edge-on through more air, the lights dim and redden.
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 lights = mix(vec3(0.8, 0.4, 0.2), vec3(1.0, 0.7, 0.36), facing) * city * night * 1.8 * smoothstep(0.0, 0.35, facing);
	// The atmosphere: a blue rim where the limb faces the sun.
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	vec3 air = vec3(0.30, 0.55, 1.0) * rim * smoothstep(-0.25, 0.3, day) * 1.2;
	EMISSION = lights + air;
}
