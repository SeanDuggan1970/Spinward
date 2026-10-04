// Worlds wrapped in cloud or haze (Venus, Titan): soft, low-contrast bands and a
// glowing limb where sunlight scatters through the upper atmosphere. Local +Y is the
// pole; `spin` turns the cloud deck.
shader_type spatial;
render_mode specular_disabled;

#include "res://view/shaders/noise.gdshaderinc"

uniform vec3 colour_a : source_color = vec3(0.91, 0.84, 0.66);
uniform vec3 colour_b : source_color = vec3(0.79, 0.68, 0.45);
uniform float bands = 3.0;
uniform float turbulence = 0.6;
uniform float spin = 0.0;
uniform float seed = 9.0;
uniform vec3 sun_dir = vec3(1.0, 0.0, 0.0);

varying vec3 dir;
varying vec3 world_normal;

void vertex() {
	dir = VERTEX;
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	vec3 p = normalize(dir);
	float cs = cos(spin);
	float ss = sin(spin);
	vec3 q = vec3(cs * p.x + ss * p.z, p.y, -ss * p.x + cs * p.z);
	float swirl = sw_fbm(q * 2.5 + seed, 5) - 0.5;
	// Chevrons: Venus' cloud deck streams faster at the equator.
	float lat = q.y + swirl * 0.25 * turbulence + abs(q.y) * 0.15 * sin(atan(q.z, q.x) * 2.0);
	float b = 0.5 + 0.5 * sin(lat * bands * 3.14159);
	vec3 col = mix(colour_b, colour_a, b) * (0.92 + 0.12 * sw_fbm(q * 9.0 + seed, 4));
	ALBEDO = col;
	ROUGHNESS = 1.0;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	float day = dot(normalize(world_normal), normalize(sun_dir));
	EMISSION = colour_a * rim * smoothstep(-0.3, 0.4, day) * 0.5;
}
