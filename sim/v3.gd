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
	return sqrt(a[0] * a[0] + a[1] * a[1] + a[2] * a[2])


static func distance(a: Array, b: Array) -> float:
	var x: float = a[0] - b[0]
	var y: float = a[1] - b[1]
	var z: float = a[2] - b[2]
	return sqrt(x * x + y * y + z * z)


static func normalized(a: Array) -> Array:
	var l: float = sqrt(a[0] * a[0] + a[1] * a[1] + a[2] * a[2])
	if l > 0.0:
		var k: float = 1.0 / l
		return [a[0] * k, a[1] * k, a[2] * k]
	return [0.0, 0.0, 0.0]


static func lerp(a: Array, b: Array, t: float) -> Array:
	return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t]


## Rotate a about unit axis k by angle (Rodrigues).
static func rotate(a: Array, k: Array, angle: float) -> Array:
	var c := cos(angle)
	var s := sin(angle)
	var cx: float = k[1] * a[2] - k[2] * a[1]
	var cy: float = k[2] * a[0] - k[0] * a[2]
	var cz: float = k[0] * a[1] - k[1] * a[0]
	var d: float = (k[0] * a[0] + k[1] * a[1] + k[2] * a[2]) * (1.0 - c)
	return [a[0] * c + cx * s + k[0] * d, a[1] * c + cy * s + k[1] * d, a[2] * c + cz * s + k[2] * d]


## Single-precision offset from origin, for rendering near origin only.
static func to_local(a: Array, origin: Array, unit: float = 1.0) -> Vector3:
	return Vector3((a[0] - origin[0]) / unit, (a[1] - origin[1]) / unit, (a[2] - origin[2]) / unit)
