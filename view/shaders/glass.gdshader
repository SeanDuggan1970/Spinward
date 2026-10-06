// Window glass of the 2060s: synthetic sapphire faced over aluminium oxynitride (the
// transparent ceramic), tough enough for a micrometeoroid and clear from ultraviolet
// to infrared. Three things make it read as a window rather than a painted patch:
//   - Fresnel reflection: nearly black looking straight in, mirror-bright at a
//     grazing angle, with the Sun's glint from the scene light.
//   - The cabin behind it: a plane `depth` metres back, parallaxed with the view, with
//     ceiling lamps and the clutter of a lived-in compartment. It is seen best looking
//     straight in, and hidden by the window's reveal at a slant.
//   - coating: a gold sun film, as on flight-deck glass that faces the Sun all day.
// In a planet's shadow the glint goes, and the lit cabin carries the window.
shader_type spatial;
render_mode specular_schlick_ggx;

#include "res://view/shaders/noise.gdshaderinc"
#include "res://view/shaders/eclipse.gdshaderinc"

uniform float warmth = 0.45;
uniform float coating = 0.0;
uniform vec3 interior : source_color = vec3(1.0, 0.8, 0.55);
uniform float depth = 0.7;

global uniform vec4 sw_occluder;
global uniform vec3 sw_sun;

varying vec3 obj_pos;
varying vec3 obj_normal;
varying vec3 world_pos;

void vertex() {
	obj_pos = VERTEX;
	obj_normal = NORMAL;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 n = normalize(obj_normal);
	vec3 v_world = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	vec3 v = normalize(inverse(mat3(MODEL_MATRIX)) * v_world);
	float facing = clamp(dot(n, v), 0.0, 1.0);
	float fres = 0.04 + 0.96 * pow(1.0 - facing, 5.0);
	// The cabin: where the line of sight meets a plane `depth` behind the glass.
	vec3 t = normalize(cross(n, abs(n.y) < 0.9 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0)));
	vec3 b = cross(n, t);
	vec3 q = obj_pos - v * (depth / max(facing, 0.15));
	vec2 c = vec2(dot(q, t), dot(q, b));
	vec2 cell = floor(c / 1.2);
	vec2 fc = fract(c / 1.2) - 0.5;
	float lamp = 1.0 - smoothstep(0.0, 0.38, length(fc * vec2(1.0, 1.7)));
	float px = length(fwidth(c));
	float clutter = smoothstep(0.38, 0.62, sw_vnoise(vec3(c * 2.4, sw_hash13(vec3(cell, 1.0)) * 9.0)));
	clutter = mix(clutter, 0.5, smoothstep(0.04, 0.25, px));
	vec3 cabin = interior * warmth * (0.5 + 1.4 * lamp * lamp) * mix(1.0, 0.35, clutter);
	cabin *= smoothstep(0.08, 0.5, facing) * (1.0 - fres);
	// What it reflects: the black sky, with a faint lift toward the ship's "up" so the
	// pane never reads as a hole; a gold film warms and strengthens it.
	vec3 n_world = normalize((MODEL_MATRIX * vec4(n, 0.0)).xyz);
	vec3 r = reflect(-v_world, n_world);
	vec3 sky = vec3(0.03, 0.035, 0.045) + vec3(0.09, 0.11, 0.14) * smoothstep(-0.4, 1.0, r.y);
	vec3 gold = vec3(0.95, 0.72, 0.32);
	vec3 refl = sky * mix(vec3(1.0), gold * 1.6, coating) * (fres + coating * 0.3);
	float lit = sw_sunlit(world_pos, normalize(sw_sun), sw_occluder);
	ALBEDO = mix(vec3(0.01, 0.014, 0.02), gold * 0.1, coating);
	ROUGHNESS = 0.05;
	METALLIC = coating * 0.6;
	SPECULAR = (0.5 + coating * 0.3) * lit;
	EMISSION = cabin + refl;
}
