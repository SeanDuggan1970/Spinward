// Ice and sulphur plumes (Enceladus' tiger stripes, Io's Pele): a soft additive glow
// on an open cone, thinning with height (jets) or gathering in a canopy (umbrellas).
// Plume grains scatter forward, so a plume between you and the Sun blazes and one
// lit from behind you is barely there: as the Cassini pictures showed.
// The cone is a CylinderMesh of height 2 (local y from -1 at the vent to +1 at the top).
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

#include "res://view/shaders/noise.gdshaderinc"

uniform vec3 colour : source_color = vec3(0.9, 0.95, 1.0);
uniform float brightness = 1.0;
// World direction from the plume towards the Sun.
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
// 0 a jet (densest at the vent), 1 an umbrella (densest in its canopy).
uniform float umbrella = 0.0;
uniform float seed = 0.0;

varying vec3 local;
varying vec3 world_pos;

void vertex() {
	local = VERTEX;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float h = clamp((local.y + 1.0) * 0.5, 0.0, 1.0);
	// Soft edges: a cone seen edge-on fades out, so it reads as a volume, not a shell.
	float face = abs(dot(normalize(NORMAL), normalize(VIEW)));
	face = face * face * face;
	vec2 around = normalize(local.xz + vec2(1e-5));
	float n = sw_fbm(vec3(around * 3.0 + seed, h * 5.0 - TIME * 0.04 + seed), 4);
	float jet = pow(1.0 - h, 2.2) * smoothstep(0.0, 0.05, h);
	float canopy = smoothstep(0.15, 0.92, h) * (1.0 - smoothstep(0.92, 1.0, h));
	float density = mix(jet, canopy, umbrella) * face * smoothstep(0.25, 0.85, n) * 1.6;
	vec3 cam = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 look = normalize(world_pos - cam);
	float phase = 0.2 + 2.4 * pow(max(dot(look, normalize(sun_dir)), 0.0), 4.0);
	ALBEDO = colour * density * brightness * phase;
}
