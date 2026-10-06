// The glow round a working light: a quad turned to face the camera, a hot core and a
// soft bloom, with thin spikes on strobes. It never shrinks below `min_px` on screen,
// so a ship's lights read as points of light a long way off, the way real navigation
// lights do. It is pulled toward the camera by its own radius, so the hull it is
// mounted on doesn't cut it in half; behind the hull, the depth test hides it.
// The node's scale is the lamp's brightness (lamp.gd), 0 to 1.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 colour : source_color = vec3(1.0);
uniform float energy = 2.5;
// World radius of the glow (m) and its smallest size on screen (pixels).
uniform float radius = 0.6;
uniform float min_px = 4.0;
uniform float spikes = 0.0;

varying vec2 uv;
varying float bright;

void vertex() {
	uv = VERTEX.xy * 2.0;
	bright = length(MODEL_MATRIX[0].xyz);
	vec4 centre = VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0);
	float dist = max(-centre.z, 0.01);
	float px = 2.0 * dist / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);
	float size = max(radius, min_px * px) * mix(0.55, 1.0, bright);
	centre.z += min(size, dist * 0.5);
	POSITION = PROJECTION_MATRIX * vec4(centre.xyz + vec3(VERTEX.xy * 2.0 * size, 0.0), 1.0);
}

void fragment() {
	float r = length(uv);
	float core = exp(-r * r * 30.0);
	float bloom = exp(-r * r * 5.0) * 0.16;
	float spike = spikes * (exp(-abs(uv.y) * 60.0) + exp(-abs(uv.x) * 60.0)) * (1.0 - r) * 0.5;
	float a = (core + bloom + spike) * (1.0 - smoothstep(0.75, 1.0, r)) * bright;
	ALBEDO = colour * energy * a;
}
