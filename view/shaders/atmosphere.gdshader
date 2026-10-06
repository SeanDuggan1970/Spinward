// An atmosphere seen from space: a shell a little larger than the world, glowing
// where the line of sight grazes it (the limb), on the sunlit side, reddening towards
// the terminator. It gives a world a sense of depth and scale that a hard edge doesn't:
// the eye reads a hazy limb as something very big and far away.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled, fog_disabled, cull_back;

uniform vec3 colour : source_color = vec3(0.42, 0.62, 1.0);
uniform float strength = 0.8;
// World direction towards the Sun (SkyKit.update_body keeps it current).
uniform vec3 sun_dir = vec3(1.0, 0.0, 0.0);

varying vec3 world_normal;

void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(world_normal);
	vec3 v = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	float graze = 1.0 - clamp(dot(n, v), 0.0, 1.0);
	float limb = pow(graze, 3.5);
	float day = dot(n, normalize(sun_dir));
	float lit = smoothstep(-0.25, 0.45, day);
	// Light through the terminator is filtered warm, as at sunset.
	vec3 dusk = vec3(1.0, 0.55, 0.3) * smoothstep(-0.3, 0.05, day) * (1.0 - smoothstep(0.05, 0.4, day));
	// Forward scattering: brighter on the limb facing the Sun from behind.
	float behind = pow(max(dot(-v, normalize(sun_dir)), 0.0), 6.0);
	ALBEDO = (colour * lit + dusk * 0.6) * limb * strength * (1.0 + behind * 2.0);
}
