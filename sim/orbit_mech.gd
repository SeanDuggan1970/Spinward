## Orbital mechanics for gravity-flown transfers: analytic two-body (Kepler)
## propagation with universal variables, and point-mass gravity from Earth and the
## Moon. Plain 64-bit floats throughout; vectors are [x, y, z] Arrays (see v3.gd).
extends RefCounted

const V := preload("res://sim/v3.gd")


## Stumpff functions C(z), S(z).
static func _stumpff(z: float) -> Array:
	if z > 1e-8:
		var s := sqrt(z)
		return [(1.0 - cos(s)) / z, (s - sin(s)) / (s * s * s)]
	if z < -1e-8:
		var s := sqrt(-z)
		return [(cosh(s) - 1.0) / (-z), (sinh(s) - s) / (s * s * s)]
	return [0.5 - z / 24.0, 1.0 / 6.0 - z / 120.0]


## Two-body propagation of (r0, v0) by dt seconds around a body with gravity mu.
## Returns [r, v]. Works for every orbit type (universal variable, Newton solve).
static func kepler(r0: Array, v0: Array, dt: float, mu: float) -> Array:
	if absf(dt) < 1e-9:
		return [r0.duplicate(), v0.duplicate()]
	var r0n := V.length(r0)
	var v0n2 := V.dot(v0, v0)
	var rv := V.dot(r0, v0)
	var alpha := 2.0 / r0n - v0n2 / mu
	var sqmu := sqrt(mu)
	var x := sqmu * absf(alpha) * dt if alpha > 1e-12 else sqmu * dt / r0n
	for _i in 40:
		var z := alpha * x * x
		var c: float
		var s: float
		if z > 1e-8:
			var sz := sqrt(z)
			c = (1.0 - cos(sz)) / z
			s = (sz - sin(sz)) / (sz * sz * sz)
		elif z < -1e-8:
			var sz := sqrt(-z)
			c = (cosh(sz) - 1.0) / (-z)
			s = (sinh(sz) - sz) / (sz * sz * sz)
		else:
			c = 0.5 - z / 24.0
			s = 1.0 / 6.0 - z / 120.0
		var x2 := x * x
		var r := x2 * c + rv / sqmu * x * (1.0 - z * s) + r0n * (1.0 - z * c)
		var f := rv / sqmu * x2 * c + (1.0 - alpha * r0n) * x2 * x * s + r0n * x - sqmu * dt
		var step := f / r
		x -= step
		if absf(step) < 1e-9 * maxf(1.0, absf(x)):
			break
	var z := alpha * x * x
	var cs := _stumpff(z)
	var c: float = cs[0]
	var s: float = cs[1]
	var x2 := x * x
	var f_ := 1.0 - x2 / r0n * c
	var g_ := dt - x2 * x / sqmu * s
	var r := V.add(V.scale(r0, f_), V.scale(v0, g_))
	var rn := V.length(r)
	var fdot := sqmu / (rn * r0n) * (z * s - 1.0) * x
	var gdot := 1.0 - x2 / rn * c
	return [r, V.add(V.scale(r0, fdot), V.scale(v0, gdot))]


## Gravity acceleration at r from Earth (at the origin) and the Moon at m.
static func gravity(r: Array, m: Array, mu_e: float, mu_m: float) -> Array:
	var r2 := V.dot(r, r)
	var re := -mu_e / (r2 * sqrt(r2))
	var d := V.sub(r, m)
	var d2 := V.dot(d, d)
	var rm := -mu_m / (d2 * sqrt(d2))
	return V.add(V.scale(r, re), V.scale(d, rm))


## Circular orbit speed at radius r.
static func circular_speed(mu: float, r: float) -> float:
	return sqrt(mu / r)


## The Stumpff pair C(z), S(z) of _stumpff, and Lambert's y(z), without allocating an
## array (this is the inner loop of every interplanetary plan).
static func _lambert_y(z: float, r1n: float, r2n: float, A: float) -> float:
	var c: float
	var s_: float
	if z > 1e-8:
		var s := sqrt(z)
		c = (1.0 - cos(s)) / z
		s_ = (s - sin(s)) / (s * s * s)
	elif z < -1e-8:
		var s := sqrt(-z)
		c = (cosh(s) - 1.0) / (-z)
		s_ = (sinh(s) - s) / (s * s * s)
	else:
		c = 0.5 - z / 24.0
		s_ = 1.0 / 6.0 - z / 120.0
	return r1n + r2n + A * (z * s_ - 1.0) / sqrt(c)


## The root function of Lambert's time equation at z (-INF where y < 0).
static func _lambert_f(z: float, r1n: float, r2n: float, A: float, sqmu_dt: float) -> float:
	var c: float
	var s_: float
	if z > 1e-8:
		var s := sqrt(z)
		c = (1.0 - cos(s)) / z
		s_ = (s - sin(s)) / (s * s * s)
	elif z < -1e-8:
		var s := sqrt(-z)
		c = (cosh(s) - 1.0) / (-z)
		s_ = (sinh(s) - s) / (s * s * s)
	else:
		c = 0.5 - z / 24.0
		s_ = 1.0 / 6.0 - z / 120.0
	var y := r1n + r2n + A * (z * s_ - 1.0) / sqrt(c)
	if y < 0.0:
		return -INF
	return pow(y / c, 1.5) * s_ + A * sqrt(y) - sqmu_dt


## Lambert's problem (single revolution, universal variables): the velocities that
## carry a body from r1 to r2 in dt seconds of free fall around mu. `normal` picks
## the sense of motion (prograde about it). Returns [v1, v2], or [] if unsolvable.
static func lambert(r1: Array, r2: Array, dt: float, mu: float, normal: Array) -> Array:
	var r1n := V.length(r1)
	var r2n := V.length(r2)
	var cos_dth := clampf(V.dot(r1, r2) / (r1n * r2n), -1.0, 1.0)
	var dth := acos(cos_dth)
	if V.dot(V.cross(r1, r2), normal) < 0.0:
		dth = TAU - dth
	if absf(sin(dth)) < 1e-9 or dt <= 0.0:
		return []
	var A := sin(dth) * sqrt(r1n * r2n / (1.0 - cos_dth))
	var sqmu := sqrt(mu)
	var sqmu_dt := sqmu * dt
	var lo := -4.0 * PI * PI
	var hi := 4.0 * PI * PI - 1e-6
	# Raise the lower bound until y > 0 (the bracket's feasible region).
	for _i in 200:
		if _lambert_y(lo, r1n, r2n, A) > 0.0:
			break
		lo += 0.1
	if _lambert_f(hi, r1n, r2n, A, sqmu_dt) < 0.0:
		return []
	var lo_tested := false
	for _i in 80:
		var mid := 0.5 * (lo + hi)
		# Once the bracket is a single step wide, mid is one of its ends, whose sign is
		# already known (hi was checked above, lo was set on a negative f): nothing more
		# can change, so the remaining passes are skipped. Same result, fewer solves.
		if mid == hi or (lo_tested and mid == lo):
			break
		if _lambert_f(mid, r1n, r2n, A, sqmu_dt) < 0.0:
			lo = mid
			lo_tested = true
		else:
			hi = mid
	var z := 0.5 * (lo + hi)
	var y := _lambert_y(z, r1n, r2n, A)
	var f := 1.0 - y / r1n
	var g := A * sqrt(y / mu)
	var gdot := 1.0 - y / r2n
	var v1 := V.scale(V.sub(r2, V.scale(r1, f)), 1.0 / g)
	var v2 := V.scale(V.sub(V.scale(r2, gdot), r1), 1.0 / g)
	return [v1, v2]
