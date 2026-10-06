// A drive's bell, inside or out. The upper bell is regeneratively cooled: a wall of
// brazed tubes running aft from the throat, heat-tinted straw and blue where it runs
// hottest. Aft of the coolant manifold it is a plain radiation-cooled skirt, darker and
// streaked with deposits. The lathe (Kit.lathe) puts the way round in UV.x and the
// drive's own z, in metres, in UV.y, so the pattern survives merging.
shader_type spatial;

#include "res://view/shaders/noise.gdshaderinc"
#include "res://view/shaders/eclipse.gdshaderinc"

global uniform vec4 sw_occluder;
global uniform vec3 sw_sun;

uniform vec3 paint : source_color = vec3(0.29, 0.25, 0.22);
// The throat's and the lip's z (UV.y), and where along the bell the tubes give way to
// the skirt (0 throat, 1 lip).
uniform float z_throat = 0.0;
uniform float z_exit = 3.0;
uniform float joint = 0.55;
// Tubes round the bell, and the bell's exit circumference in metres (scales the grain).
uniform float tubes = 120.0;
uniform float girth = 12.0;
// The inside runs darker and sootier than the outside.
uniform float inner = 0.0;
uniform float wear = 0.4;
uniform float seed = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = clamp((UV.y - z_throat) / max(z_exit - z_throat, 1e-3), 0.0, 1.0);
	vec2 grain = vec2(UV.x * girth, t * (z_exit - z_throat));
	float px = length(fwidth(grain));
	vec3 base = paint * mix(1.0, 0.55, inner);
	// Bare refractory metal: a little mottling, and deposits streaked aft by the flow.
	base *= 0.88 + 0.24 * sw_vnoise(vec3(grain * 1.7, seed));
	float streak = sw_fbm(vec3(grain.x * 2.5, grain.y * 0.15, seed + 4.0), 3);
	streak = mix(streak, 0.5, smoothstep(0.2, 1.0, px));
	base *= 1.0 - (0.25 + 0.35 * inner) * wear * smoothstep(0.45, 0.75, streak);
	float rough = 0.42 + 0.2 * inner;
	float metal = 0.75;
	if (t < joint) {
		// Tube wall: fine axial ridges that fade out before they alias.
		float n_tubes = tubes;
		float ridge = abs(fract(UV.x * n_tubes) - 0.5) * 2.0;
		float tube_px = fwidth(UV.x * n_tubes);
		float ridges = (1.0 - smoothstep(0.0, 0.5, tube_px));
		base *= 1.0 - 0.28 * ridges * smoothstep(0.55, 1.0, ridge);
		// Heat tint: blued just aft of the throat, then straw, then the metal's own.
		float u = t / joint;
		vec3 blue = vec3(0.32, 0.34, 0.55);
		vec3 straw = vec3(0.78, 0.6, 0.35);
		vec3 tint = mix(blue, straw, smoothstep(0.1, 0.45, u));
		tint = mix(tint, vec3(1.0), smoothstep(0.45, 0.95, u));
		base *= mix(vec3(1.0), tint * 1.3, 0.55 * (1.0 - inner * 0.5));
		rough -= 0.08;
	} else {
		// Radiation-cooled skirt: darker, sooty, in welded rings.
		base *= 0.72;
		float ring = fract((t - joint) / (1.0 - joint) * 3.0);
		float seam = (1.0 - smoothstep(0.0, 0.012, min(ring, 1.0 - ring))) * (1.0 - smoothstep(0.02, 0.08, px));
		base *= 1.0 - 0.3 * seam;
		rough += 0.1;
	}
	ALBEDO = base * mix(0.12, 1.0, sw_sunlit(world_pos, normalize(sw_sun), sw_occluder));
	ROUGHNESS = clamp(rough, 0.0, 1.0);
	METALLIC = metal;
}
