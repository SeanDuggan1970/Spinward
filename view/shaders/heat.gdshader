// Hot metal while the drive burns: a thin skin laid just off the bell's wall that adds
// a dull blackbody glow, orange where it runs hottest and fading through red to
// nothing. It hangs under the ship's DrivePlume, so it shows only while firing.
// UV.y is the drive's z in metres (Kit.lathe), t runs 0 at the throat to 1 at the lip.
shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled, fog_disabled;

#include "res://view/shaders/noise.gdshaderinc"

uniform float z_throat = 0.0;
uniform float z_exit = 3.0;
// The glow rises from `rise` to its peak at `peak`, then dies away by `end` (t units).
uniform float rise = -0.1;
uniform float peak = 0.0;
uniform float end = 0.5;
uniform float brightness = 1.0;
uniform float seed = 0.0;

void fragment() {
	float t = (UV.y - z_throat) / max(z_exit - z_throat, 1e-3);
	float h = smoothstep(rise, peak, t) * (1.0 - smoothstep(peak, end, t));
	// Hot spots where the wall runs a little thinner, and a slow shimmer.
	h *= 0.8 + 0.4 * sw_vnoise(vec3(UV.x * 24.0, t * 6.0, seed + TIME * 0.3));
	h = clamp(h * brightness, 0.0, 1.5);
	vec3 col = mix(vec3(0.35, 0.04, 0.01), vec3(0.95, 0.38, 0.08), smoothstep(0.3, 1.0, h));
	col = mix(col, vec3(1.0, 0.72, 0.4), smoothstep(1.0, 1.5, h));
	ALBEDO = col * h;
}
