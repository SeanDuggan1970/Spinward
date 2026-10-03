## Gravity-flown transfers: the co-pilot's flight computer.
##
## The ship is integrated under point gravity from Earth and the Moon (RK4, adaptive
## steps that shrink for close lunar passes). Guidance re-plans every few minutes
## with "zero-effort" feedback: it predicts where free fall would take the ship by
## the deadline (an analytic Kepler orbit around Earth, or around the Moon when close
## to it), and thrusts only to remove the predicted miss in position and velocity.
## Gravity does most of the work, so long, patient trips coast and burn little.
##
## Routes are sequences of legs:
##   flyby      aim at a point beside the Moon at a set time; coast hands-off through
##              periapsis so the Moon's gravity bends and slings the path
##   rendezvous arrive at the destination's hand-off point matching its motion
## The result is a list of samples [t, pos, vel, thrust] in the Earth frame, which
## the game replays (no re-integration at play time), plus fuel and miss figures.
##
## Deliberate simplification: departures and arrivals at stations deep in a gravity
## well start/end at a hand-off orbit clear of it; the co-pilot's climb-out inside
## the overhead hours covers the rest (see docs/DESIGN.md).
extends RefCounted

const V := preload("res://sim/v3.gd")
const OM := preload("res://sim/orbit_mech.gd")

const MOON_TABLE_STEP := 600.0
const GUIDE_STEP := 600.0
## During cruise the Lambert solution changes slowly; re-solve this often.
const CRUISE_RESOLVE := 1800.0
const SAMPLE_STEP := 1800.0
const CLOSE_SAMPLE_STEP := 60.0
const CLOSE_SAMPLE_R := 3.0e7
## Within this distance of the Moon, predict free fall around the Moon, not Earth.
const MOON_PREDICT_R := 6.0e7
## Flyby phases by distance from the Moon: trim the periapsis inside APPROACH, then
## hands off inside HANDS_OFF; the leg ends once receding beyond EXIT.
const FLYBY_APPROACH := 6.0e7
const FLYBY_HANDS_OFF := 1.5e7
const FLYBY_EXIT := 4.0e7
## Periapsis trim error that commands full sideways thrust.
const FLYBY_TRIM_SPAN := 2.0e6


## Moon positions (Earth frame) every MOON_TABLE_STEP over [t0, t1], for fast lookup.
static func moon_table(eph, t0: float, t1: float) -> Dictionary:
	var pts := []
	var flat := PackedFloat64Array()
	var n := int(ceil((t1 - t0) / MOON_TABLE_STEP)) + 2
	for k in n:
		var m: Array = eph.relative("moon", "earth", t0 + k * MOON_TABLE_STEP)
		pts.append(m)
		flat.append(m[0])
		flat.append(m[1])
		flat.append(m[2])
	return {"t0": t0, "pts": pts, "flat": flat, "n": n}


static func moon_at(table: Dictionary, t: float) -> Array:
	var pts: Array = table["pts"]
	var f := (t - float(table["t0"])) / MOON_TABLE_STEP
	var i := clampi(int(floor(f)), 0, pts.size() - 2)
	return V.lerp(pts[i], pts[i + 1], clampf(f - i, 0.0, 1.0))


static func moon_vel(table: Dictionary, t: float) -> Array:
	return V.scale(V.sub(moon_at(table, t + 300.0), moon_at(table, t - 300.0)), 1.0 / 600.0)


## Free-fall prediction of (r, v) after dt: around the Moon when near it, else Earth.
static func _predict(r: Array, v: Array, t: float, dt: float, table: Dictionary, mu_e: float, mu_m: float) -> Array:
	var m := moon_at(table, t)
	if V.distance(r, m) < MOON_PREDICT_R * 0.5:
		var mv := moon_vel(table, t)
		var rel := OM.kepler(V.sub(r, m), V.sub(v, mv), dt, mu_m)
		var m1 := moon_at(table, t + dt)
		var mv1 := moon_vel(table, t + dt)
		return [V.add(m1, rel[0]), V.add(mv1, rel[1])]
	return OM.kepler(r, v, dt, mu_e)


## Fly a route. legs: [{kind, t, pos, vel?}] in time order (absolute times).
## Returns {samples, dv, miss_r, miss_v, min_moon_alt, peri_t}.
## The integration loop is written with plain floats (no per-step allocations):
## a 3-day trip is a few thousand RK4 steps and costs tens of milliseconds.
static func fly(t0: float, r0: Array, v0: Array, legs: Array, accel: float, table: Dictionary,
		mu_e: float, mu_m: float, moon_radius: float) -> Dictionary:
	var flat: PackedFloat64Array = table["flat"]
	var tab_t0: float = table["t0"]
	var tab_n: int = table["n"]
	var x: float = r0[0]
	var y: float = r0[1]
	var z: float = r0[2]
	var vx: float = v0[0]
	var vy: float = v0[1]
	var vz: float = v0[2]
	var ax := 0.0
	var ay := 0.0
	var az := 0.0
	var t := t0
	var next_guide := t0
	var next_sample := t0
	var last_solve := -INF
	## The reference free-fall orbit from the last Lambert solve: [t, r, v].
	var ref := []
	var samples := []
	var dv := 0.0
	var min_alt := INF
	var peri_t := -1.0
	var leg_i := 0
	var t_end := float(legs[-1]["t"])
	while t < t_end - 1e-6 and leg_i < legs.size():
		var leg: Dictionary = legs[leg_i]
		var leg_t := float(leg["t"])
		# Moon position and velocity now (linear interpolation in the packed table).
		var f := (t - tab_t0) / MOON_TABLE_STEP
		var i := clampi(int(f), 0, tab_n - 2)
		var u := clampf(f - i, 0.0, 1.0)
		var j := i * 3
		var mx := flat[j] + (flat[j + 3] - flat[j]) * u
		var my := flat[j + 1] + (flat[j + 4] - flat[j + 1]) * u
		var mz := flat[j + 2] + (flat[j + 5] - flat[j + 2]) * u
		var mvx := (flat[j + 3] - flat[j]) / MOON_TABLE_STEP
		var mvy := (flat[j + 4] - flat[j + 1]) / MOON_TABLE_STEP
		var mvz := (flat[j + 5] - flat[j + 2]) / MOON_TABLE_STEP
		var dmx := x - mx
		var dmy := y - my
		var dmz := z - mz
		var d_moon := sqrt(dmx * dmx + dmy * dmy + dmz * dmz)
		if d_moon - moon_radius < min_alt:
			min_alt = d_moon - moon_radius
			peri_t = t
		if t >= next_sample:
			samples.append([t, [x, y, z], [vx, vy, vz], [ax, ay, az]])
			# Dense samples near the Moon so a low pass replays smoothly.
			next_sample = t + (CLOSE_SAMPLE_STEP if d_moon < CLOSE_SAMPLE_R else SAMPLE_STEP)
		if t >= next_guide:
			next_guide = t + GUIDE_STEP
			var cmd: Array
			if ref.is_empty() or t - last_solve >= CRUISE_RESOLVE or leg.get("terminal", false) or leg["kind"] == "flyby" and d_moon < FLYBY_APPROACH:
				var g := _guide([x, y, z], [vx, vy, vz], t, leg, accel, table, mu_e, mu_m)
				cmd = g[0]
				ref = g[1]
				last_solve = t
			else:
				# Between re-solves, follow the reference orbit: where it says our velocity
				# should be by now (an analytic Kepler step), and steer toward that.
				var on_ref := OM.kepler(ref[1], ref[2], t - float(ref[0]), mu_e)
				cmd = _steer(V.sub(on_ref[1], [vx, vy, vz]), accel)
			ax = cmd[0]
			ay = cmd[1]
			az = cmd[2]
		# Adaptive step: about 1% of the time to cross the distance to the Moon or Earth.
		var rvx := vx - mvx
		var rvy := vy - mvy
		var rvz := vz - mvz
		var speed_m := maxf(sqrt(rvx * rvx + rvy * rvy + rvz * rvz), 100.0)
		var rn := sqrt(x * x + y * y + z * z)
		var speed_e := maxf(sqrt(vx * vx + vy * vy + vz * vz), 100.0)
		var dt := minf(clampf(0.01 * d_moon / speed_m, 2.0, 120.0), clampf(0.01 * rn / speed_e, 2.0, 120.0))
		if leg_t - t > 1e-6:
			dt = minf(dt, leg_t - t)
		if next_guide - t > 1e-6:
			dt = minf(dt, next_guide - t)
		# RK4 with Earth at the origin and the Moon moving linearly across the step.
		var k := _rk4_fast(x, y, z, vx, vy, vz, t, dt, ax, ay, az, flat, tab_t0, tab_n, mu_e, mu_m)
		x = k[0]
		y = k[1]
		z = k[2]
		vx = k[3]
		vy = k[4]
		vz = k[5]
		t += dt
		dv += sqrt(ax * ax + ay * ay + az * az) * dt
		if t >= leg_t - 1e-6 or leg.get("done", false):
			leg_i += 1
			next_guide = t
	samples.append([t, [x, y, z], [vx, vy, vz], [0.0, 0.0, 0.0]])
	var goal: Dictionary = legs[-1]
	var gp: Array = goal["pos"]
	var gv: Array = goal.get("vel", [vx, vy, vz])
	return {"samples": samples, "dv": dv,
		"miss_r": sqrt((x - gp[0]) ** 2 + (y - gp[1]) ** 2 + (z - gp[2]) ** 2),
		"miss_v": sqrt((vx - gv[0]) ** 2 + (vy - gv[1]) ** 2 + (vz - gv[2]) ** 2),
		"min_moon_alt": min_alt, "peri_t": peri_t}


static func _rk4_fast(x: float, y: float, z: float, vx: float, vy: float, vz: float, t: float, dt: float,
		tx: float, ty: float, tz: float, flat: PackedFloat64Array, tab_t0: float, tab_n: int, mu_e: float, mu_m: float) -> Array:
	var px := x
	var py := y
	var pz := z
	var qx := vx
	var qy := vy
	var qz := vz
	var sx := 0.0
	var sy := 0.0
	var sz := 0.0
	var svx := 0.0
	var svy := 0.0
	var svz := 0.0
	for st in 4:
		var ts := t + (0.0 if st == 0 else (dt if st == 3 else dt * 0.5))
		var f := (ts - tab_t0) / MOON_TABLE_STEP
		var i := clampi(int(f), 0, tab_n - 2)
		var u := clampf(f - i, 0.0, 1.0)
		var j := i * 3
		var mx := flat[j] + (flat[j + 3] - flat[j]) * u
		var my := flat[j + 1] + (flat[j + 4] - flat[j + 1]) * u
		var mz := flat[j + 2] + (flat[j + 5] - flat[j + 2]) * u
		var r2 := px * px + py * py + pz * pz
		var fe := -mu_e / (r2 * sqrt(r2))
		var dx := px - mx
		var dy := py - my
		var dz := pz - mz
		var d2 := dx * dx + dy * dy + dz * dz
		var fm := -mu_m / (d2 * sqrt(d2))
		var gx := fe * px + fm * dx + tx
		var gy := fe * py + fm * dy + ty
		var gz := fe * pz + fm * dz + tz
		var w := 1.0 if st == 0 or st == 3 else 2.0
		sx += w * qx
		sy += w * qy
		sz += w * qz
		svx += w * gx
		svy += w * gy
		svz += w * gz
		if st < 3:
			var h := dt * (0.5 if st < 2 else 1.0)
			px = x + qx * h
			py = y + qy * h
			pz = z + qz * h
			qx = vx + gx * h
			qy = vy + gy * h
			qz = vz + gz * h
	return [x + sx * dt / 6.0, y + sy * dt / 6.0, z + sz * dt / 6.0, vx + svx * dt / 6.0, vy + svy * dt / 6.0, vz + svz * dt / 6.0]


## Returns [thrust, reference] where reference is [t, r, v] of the free-fall orbit
## being steered onto (empty when not cruising).
static func _guide(r: Array, v: Array, t: float, leg: Dictionary, accel: float, table: Dictionary, mu_e: float, mu_m: float) -> Array:
	var none := [0.0, 0.0, 0.0]
	if leg["kind"] == "flyby":
		return _guide_flyby(r, v, t, leg, accel, table, mu_e, mu_m)
	var tgo := float(leg["t"]) - t
	if leg["kind"] == "coast" or tgo < 60.0:
		return [none, []]
	var pred := _predict(r, v, t, tgo, table, mu_e, mu_m)
	if leg["kind"] == "rendezvous":
		# Terminal phase (latched): match the destination's motion as we arrive.
		var brake_s := V.length(V.sub(leg["vel"], pred[1])) / accel
		if leg.get("terminal", false) or tgo < brake_s * 2.0 + 6.0 * 3600.0 or V.distance(r, moon_at(table, t)) < MOON_PREDICT_R * 0.5:
			leg["terminal"] = true
			var zem := V.sub(leg["pos"], pred[0])
			var zev := V.sub(leg["vel"], pred[1])
			return [_clamp(V.sub(V.scale(zem, 6.0 / (tgo * tgo)), V.scale(zev, 2.0 / tgo)), accel), []]
	# Cruise: steer onto the free-fall orbit that reaches the aim point on time
	# (Lambert around Earth), then coast; feedback absorbs the Moon's pull.
	var sol := OM.lambert(r, leg["pos"], tgo, mu_e, V.cross(r, v))
	if sol.is_empty():
		return [_clamp(V.scale(V.sub(leg["pos"], pred[0]), 3.0 / (tgo * tgo)), accel), []]
	return [_steer(V.sub(sol[0], v), accel), [t, r.duplicate(), sol[0]]]


## Lunar flyby by B-plane targeting.
##   Far out: steer (Lambert around Earth) for the point offset from where the Moon
##   will be by the impact parameter b that the Moon's pull turns into the chosen
##   periapsis radius: b = rp * sqrt(1 + 2 mu / (rp vinf^2)).
##   Approaching: predict the periapsis from the lunar hyperbola, nudge sideways to
##   trim it. Close in: hands off. Receding and clear: the leg is done.
static func _guide_flyby(r: Array, v: Array, t: float, leg: Dictionary, accel: float, table: Dictionary, mu_e: float, mu_m: float) -> Array:
	var none := [0.0, 0.0, 0.0]
	var m := moon_at(table, t)
	var rel := V.sub(r, m)
	var rel_v := V.sub(v, moon_vel(table, t))
	var dist := V.length(rel)
	var approaching := V.dot(rel, rel_v) < 0.0
	if not approaching:
		if dist > FLYBY_EXIT or leg.get("passed", false) and dist > FLYBY_HANDS_OFF:
			leg["done"] = true
		if dist < FLYBY_APPROACH:
			leg["passed"] = true
		return [none, []]
	if dist < FLYBY_HANDS_OFF:
		return [none, []]  # hands off: let the Moon do it
	var rp := float(leg["rp"])
	if dist < FLYBY_APPROACH:
		# Predicted periapsis of the lunar hyperbola: rp = h^2 / (mu (1 + e)).
		var h := V.cross(rel, rel_v)
		var h2 := V.dot(h, h)
		var energy := V.dot(rel_v, rel_v) * 0.5 - mu_m / dist
		var e := sqrt(maxf(0.0, 1.0 + 2.0 * energy * h2 / (mu_m * mu_m)))
		var rp_pred := h2 / (mu_m * (1.0 + e))
		var err := rp - rp_pred
		# Pushing sideways, away from the Moon across our motion, raises periapsis.
		var vhat := V.normalized(rel_v)
		var away := V.sub(rel, V.scale(vhat, V.dot(rel, vhat)))
		if V.length(away) < 1.0:
			return [none, []]
		return [V.scale(V.normalized(away), accel * clampf(err / FLYBY_TRIM_SPAN, -1.0, 1.0)), []]
	var t_peri := float(leg["t_peri"])
	var tgo := maxf(t_peri - t, 600.0)
	var vinf := float(leg.get("vinf", 1000.0))
	var b := rp * sqrt(1.0 + 2.0 * mu_m / (rp * vinf * vinf))
	var aim := V.add(moon_at(table, t_peri), V.scale(leg["side"], b))
	var sol := OM.lambert(r, aim, tgo, mu_e, V.cross(r, v))
	if sol.is_empty():
		return [_clamp(V.scale(V.sub(aim, _predict(r, v, t, tgo, table, mu_e, mu_m)[0]), 3.0 / (tgo * tgo)), accel), []]
	leg["vinf"] = maxf(200.0, V.length(V.sub(sol[1], moon_vel(table, t_peri))))
	return [_steer(V.sub(sol[0], v), accel), [t, r.duplicate(), sol[0]]]


## Burn toward a velocity change: full thrust while far off, gently once close.
static func _steer(gain: Array, accel: float) -> Array:
	var need := V.length(gain)
	if need > accel * GUIDE_STEP:
		return V.scale(gain, accel / need)
	return V.scale(gain, 1.0 / GUIDE_STEP)


static func _clamp(a: Array, accel: float) -> Array:
	var n := V.length(a)
	return V.scale(a, accel / n) if n > accel else a
