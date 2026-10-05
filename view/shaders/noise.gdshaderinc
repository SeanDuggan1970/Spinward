#ifndef SW_NOISE
#define SW_NOISE
// Shared procedural noise for Spinward's surfaces. Hash-based, so no textures.

float sw_hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

vec3 sw_hash33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

float sw_vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = sw_hash13(i);
	float b = sw_hash13(i + vec3(1.0, 0.0, 0.0));
	float c = sw_hash13(i + vec3(0.0, 1.0, 0.0));
	float d = sw_hash13(i + vec3(1.0, 1.0, 0.0));
	float e = sw_hash13(i + vec3(0.0, 0.0, 1.0));
	float g = sw_hash13(i + vec3(1.0, 0.0, 1.0));
	float h = sw_hash13(i + vec3(0.0, 1.0, 1.0));
	float k = sw_hash13(i + vec3(1.0, 1.0, 1.0));
	return mix(mix(mix(a, b, f.x), mix(c, d, f.x), f.y), mix(mix(e, g, f.x), mix(h, k, f.x), f.y), f.z);
}

float sw_fbm(vec3 p, int octaves) {
	float sum = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 8; i++) {
		if (i >= octaves) {
			break;
		}
		sum += amp * sw_vnoise(p);
		p = p * 2.03 + vec3(1.7, 9.2, 3.1);
		amp *= 0.5;
	}
	return sum;
}
#endif
