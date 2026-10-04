## Interplanetary transfers flown under the Sun's gravity: the co-pilot's flight
## computer for the long haul. Same guidance idea as gravity_flight.gd, at Sun scale:
## steer onto the free-fall (Lambert) arc that reaches the target on time, coast
## while it holds, and in the terminal phase null the predicted miss in position and
## velocity (ZEM/ZEV) to arrive matching the target world's motion. Step sizes scale
## with the trip, so a nine-month voyage costs about as much to fly as a weekend.
## Planets' own gravity along the way is ignored; the climb-out and capture spirals
## at either end (interplanetary.gd) cover each world's well.
## Pure function of its inputs: safe on a worker thread.
extends RefCounted

const V := preload("res://sim/v3.gd")
const OM := preload("res://sim/orbit_mech.gd")

## Guidance runs this many times over a trip, within the bounds below (seconds).
const GUIDES_PER_TRIP := 400.0
const GUIDE_MIN := 600.0
const GUIDE_MAX := 43200.0
const SAMPLES_PER_TRIP := 240.0
## Start the terminal (braking) phase this many braking-times out, so the
## rendezvous law has room before the drive saturates.
const BRAKE_MARGIN := 4.0


## Fly from (r0, v0) at t0 to (r_goal, v_goal) at t1 with thrust up to `accel`.
## Returns {samples: [[t, pos, vel, thrust]], dv, miss_r, miss_v}.
static func fly(t0: float, r0: Array, v0: Array, t1: float, r_goal: Array, v_goal: Array, accel: float, mu: float) -> Dictionary:
	var span := t1 - t0
	var guide_step := clampf(span / GUIDES_PER_TRIP, GUIDE_MIN, GUIDE_MAX)
	var sample_step := maxf(guide_step, span / SAMPLES_PER_TRIP)
	var r: Array = r0.duplicate()
	var v: Array = v0.duplicate()
	var thrust := [0.0, 0.0, 0.0]
	var t := t0
	var next_guide := t0
	var next_sample := t0
	var terminal := false
	var dv := 0.0
	var samples := []
	while t < t1 - 1e-6:
		if t >= next_sample:
			samples.append([t, r.duplicate(), v.duplicate(), thrust.duplicate()])
			next_sample = t + sample_step
		if t >= next_guide:
			next_guide = t + guide_step
			var g := _guide(r, v, t1 - t, r_goal, v_goal, accel, mu, guide_step, terminal)
			thrust = g[0]
			terminal = g[1]
		var speed := maxf(V.length(v), 1.0)
		var dt := clampf(0.003 * V.length(r) / speed, 60.0, guide_step)
		dt = minf(dt, minf(next_guide - t, t1 - t))
		if dt <= 1e-6:
			dt = minf(guide_step, t1 - t)
		var k := _rk4(r, v, dt, thrust, mu)
		r = k[0]
		v = k[1]
		t += dt
		dv += V.length(thrust) * dt
	samples.append([t, r.duplicate(), v.duplicate(), [0.0, 0.0, 0.0]])
	return {"samples": samples, "dv": dv, "miss_r": V.distance(r, r_goal), "miss_v": V.distance(v, v_goal)}


static func _guide(r: Array, v: Array, tgo: float, r_goal: Array, v_goal: Array, accel: float, mu: float, guide_step: float, terminal: bool) -> Array:
	var none := [0.0, 0.0, 0.0]
	if tgo < 60.0:
		return [none, terminal]
	var pred := OM.kepler(r, v, tgo, mu)
	var brake_s := V.length(V.sub(v_goal, pred[1])) / accel
	if terminal or tgo < brake_s * BRAKE_MARGIN + guide_step * 4.0:
		var zem := V.sub(r_goal, pred[0])
		var zev := V.sub(v_goal, pred[1])
		return [_clamp(V.sub(V.scale(zem, 6.0 / (tgo * tgo)), V.scale(zev, 2.0 / tgo)), accel), true]
	var sol := OM.lambert(r, r_goal, tgo, mu, V.cross(r, v))
	if sol.is_empty():
		return [_clamp(V.scale(V.sub(r_goal, pred[0]), 3.0 / (tgo * tgo)), accel), false]
	var need := V.sub(sol[0], v)
	var n := V.length(need)
	if n > accel * guide_step:
		return [V.scale(need, accel / n), false]
	return [V.scale(need, 1.0 / guide_step), false]


static func _rk4(r: Array, v: Array, dt: float, thrust: Array, mu: float) -> Array:
	var a1 := _acc(r, thrust, mu)
	var r2 := V.add(r, V.scale(v, dt * 0.5))
	var v2 := V.add(v, V.scale(a1, dt * 0.5))
	var a2 := _acc(r2, thrust, mu)
	var r3 := V.add(r, V.scale(v2, dt * 0.5))
	var v3 := V.add(v, V.scale(a2, dt * 0.5))
	var a3 := _acc(r3, thrust, mu)
	var r4 := V.add(r, V.scale(v3, dt))
	var v4 := V.add(v, V.scale(a3, dt))
	var a4 := _acc(r4, thrust, mu)
	var dr := V.scale(V.add(V.add(v, V.scale(v2, 2.0)), V.add(V.scale(v3, 2.0), v4)), dt / 6.0)
	var dvv := V.scale(V.add(V.add(a1, V.scale(a2, 2.0)), V.add(V.scale(a3, 2.0), a4)), dt / 6.0)
	return [V.add(r, dr), V.add(v, dvv)]


static func _acc(r: Array, thrust: Array, mu: float) -> Array:
	var d := V.length(r)
	return V.add(V.scale(r, -mu / (d * d * d)), thrust)


static func _clamp(a: Array, accel: float) -> Array:
	var n := V.length(a)
	return V.scale(a, accel / n) if n > accel else a
