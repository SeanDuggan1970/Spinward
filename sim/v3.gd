## 64-bit vector helpers. Godot's Vector3 is single precision in stock builds, which
## loses about 10 km at 1 AU, so sim positions are plain Arrays [x, y, z] of 64-bit
## floats in metres. Convert to Vector3 only relative to a nearby origin, for display.
extends RefCounted


static func make(x: float, y: float, z: float) -> Array:
	return [x, y, z]


static func add(a: Array, b: Array) -> Array:
	return [a[0] + b[0], a[1] + b[1], a[2] + b[2]]


static func sub(a: Array, b: Array) -> Array:
	return [a[0] - b[0], a[1] - b[1], a[2] - b[2]]


static func scale(a: Array, s: float) -> Array:
	return [a[0] * s, a[1] * s, a[2] * s]


static func dot(a: Array, b: Array) -> float:
	return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


static func cross(a: Array, b: Array) -> Array:
	return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]


static func length(a: Array) -> float:
	return sqrt(dot(a, a))


static func distance(a: Array, b: Array) -> float:
	return length(sub(a, b))


static func normalized(a: Array) -> Array:
	var l := length(a)
	return scale(a, 1.0 / l) if l > 0.0 else [0.0, 0.0, 0.0]


static func lerp(a: Array, b: Array, t: float) -> Array:
	return add(a, scale(sub(b, a), t))


## Rotate a about unit axis k by angle (Rodrigues).
static func rotate(a: Array, k: Array, angle: float) -> Array:
	var c := cos(angle)
	var s := sin(angle)
	return add(add(scale(a, c), scale(cross(k, a), s)), scale(k, dot(k, a) * (1.0 - c)))


## Single-precision offset from origin, for rendering near origin only.
static func to_local(a: Array, origin: Array, unit: float = 1.0) -> Vector3:
	return Vector3((a[0] - origin[0]) / unit, (a[1] - origin[1]) / unit, (a[2] - origin[2]) / unit)
