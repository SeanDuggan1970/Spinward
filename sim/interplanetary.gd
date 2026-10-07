## Interplanetary trips: anything whose common frame is the Sun.
##
## A voyage has three parts:
##   climb-out   a low-thrust spiral from the departure station to free flight
##               around the Sun. Spiralling out of a circular orbit costs about the
##               orbit's speed in delta-v (Edelbaum), so leaving low Earth orbit
##               costs ~7.7 km/s and days of thrust, while the Earth-Moon Lagrange
##               stations, already ~1 km/s from free, are the cheap way out.
##   transfer    Sun-centred flight from the departure world to the destination
##               world, planned by scanning trip times with Lambert's problem and
##               flown by helio_flight.gd.
##   capture     the same spiral in reverse into the destination's well.
## Fast trips cost delta-v steeply; the drive's thrust sets how fast is possible, its
## exhaust velocity what that costs in propellant (rocket equation, at departure
## mass), and the crew's life support how long a voyage may last.
##
## Planning is split like route_planner.gd: prepare() gathers positions on the main
## thread (the ephemeris is not thread-safe); run() flies on plain data.
extends RefCounted

const V := preload("res://sim/v3.gd")
const OM := preload("res://sim/orbit_mech.gd")
const HF := preload("res://sim/helio_flight.gd")
const ShipStats := preload("res://sim/ship_stats.gd")

const DAY := 86400.0
## Trip times scanned, as multiples of the gravity-free brachistochrone estimate.
const SCAN_FROM := 0.5
const SCAN_TO := 8.0
const SCAN_STEPS := 48
## A thrust arc may take at most this share of the transfer.
const MAX_BURN_FRACTION := 0.5
## Economy trades time for fuel up to this multiple of the Express trip time.
const ECONOMY_TIME_MULT := 2.5
## Beyond this distance (deep space, the Oort cloud) trips are not flown by guidance:
## braking takes most of the voyage and the terminal law cannot converge, so the
## free-fall estimate (quick) is the route.
const DEEP_SPACE_M := 30.0 * 1.495978707e11
## A transfer counts as arriving when it ends this close (capture covers the rest).
const ARRIVE_MISS_R := 2.0e8
const ARRIVE_MISS_V := 500.0


## How close a path may come to a body: its radius plus the atmosphere drawn on it
## (look.atmosphere.thickness), and never less than CLEAR_MIN_M above the ground.
const CLEAR_MIN_M := 20.0e3
## Climb-out and capture spirals: samples along each, and the hand-off radius as a
## multiple of the station's own orbit and of the world's radius.
const SPIRAL_SAMPLES := 32
## A quick plan's free-fall path is sampled every 1/40 of the trip, closer where it swings
## fast about the Sun: at most this many radians a step, and at most this many steps.
const STEP_TURN := 0.05
const MAX_CONIC_SAMPLES := 400
## A path bent clear of the Sun rides this multiple of its clearance.
const SUN_BEND := 1.05
const HANDOFF_ORBITS := 2.5
const HANDOFF_RADII := 25.0


static func clearance(data, body: String) -> float:
	var b: Dictionary = data.bodies[body]
	var r := float(b["radius_m"])
	var atm: Dictionary = b.get("look", {}).get("atmosphere", {})
	return maxf(r * (1.0 + float(atm.get("thickness", 0.0))), r + CLEAR_MIN_M)


static func is_interplanetary(data, from_place: String, to_place: String) -> bool:
	return _frame(data, from_place, to_place) == "sun"


## The lowest body both places hang from (same rule as Navigation.frame_body; kept
## here so the two scripts do not preload each other).
static func _frame(data, a: String, b: String) -> String:
	var chain_b := _chain(data, b)
	for body in _chain(data, a):
		if body in chain_b:
			return body
	return "sun"


static func _chain(data, place: String) -> Array:
	var loc: Dictionary = data.locations[place]["location"]
	var body: String = loc["parent"] if loc["type"] in ["orbit", "surface"] else loc["system"][0]
	var chain := []
	while body != "":
		chain.append(body)
		body = data.bodies[body].get("parent", "")
	return chain


## The spiral out of (or into) a place's gravity wells: {dv, body}, where body is the
## world whose solar orbit the transfer starts (ends) on.
static func well(data, eph, place: String, t: float) -> Dictionary:
	var loc: Dictionary = data.locations[place]["location"]
	var dv := 0.0
	var body: String
	if loc["type"] == "orbit" and loc["parent"] == "sun":
		# Free space around the Sun (a deep-space site): nothing to climb out of.
		return {"dv": 0.0, "body": place}
	if loc["type"] == "orbit":
		body = loc["parent"]
		dv += sqrt(float(data.bodies[body]["gm"]) / float(loc["elements"]["a_m"]))
	elif loc["type"] == "surface":
		# A town on the ground (reached by elevator): as deep in the well as it gets.
		body = loc["parent"]
		dv += sqrt(float(data.bodies[body]["gm"]) / float(data.bodies[body]["radius_m"]))
	elif loc["system"][0] == "sun":
		# A Sun-planet Lagrange point (the Trojans): already in free solar orbit,
		# moving with the planet. Nothing to climb out of.
		return {"dv": 0.0, "body": place}
	else:
		# A Lagrange station co-moves with the secondary: it is that far from free.
		body = loc["system"][0]
		var secondary: String = loc["system"][1]
		dv += sqrt(float(data.bodies[body]["gm"]) / V.distance(eph.position(secondary, t), eph.position(body, t)))
	while data.bodies[body].get("parent", "sun") != "sun":
		var parent: String = data.bodies[body]["parent"]
		dv += sqrt(float(data.bodies[parent]["gm"]) / V.distance(eph.position(body, t), eph.position(parent, t)))
		body = parent
	return {"dv": dv, "body": body}


## Gather everything a planning run needs (main thread). Scans trip times with
## Lambert's problem and keeps the Express (fastest affordable) and Economy (least
## propellant within ECONOMY_TIME_MULT of Express) candidates for flying.
static func prepare(ship: Dictionary, data, eph, from_place: String, to_place: String, t: float) -> Dictionary:
	var accel := ShipStats.accel_mps2(ship, data)
	var ve := ShipStats.exhaust_velocity(ship, data)
	var mass := ShipStats.total_mass_t(ship, data)
	var fuel := float(ship.get("fuel_t", 0.0))
	var life_days := ShipStats.life_support_days(ship, data)
	var overhead := float(data.balance["travel"]["overhead_hours"]) * 3600.0
	var job := {"helio": true, "t": t, "from": from_place, "to": to_place, "accel": accel, "ve": ve, "mass_t": mass,
		"fuel_t": fuel, "life_days": life_days, "overhead": overhead, "mu": float(data.bodies["sun"]["gm"]),
		"candidates": [], "scan": []}
	if accel <= 0.0 or ve <= 0.0:
		job["reason"] = "no working drive"
		return job
	var w_out := well(data, eph, from_place, t)
	var w_in := well(data, eph, to_place, t)
	var out_s := float(w_out["dv"]) / accel
	var in_s := float(w_in["dv"]) / accel
	var t1 := t + overhead * 0.5 + out_s
	var a_body: String = w_out["body"]
	var b_body: String = w_in["body"]
	job.merge({"well_out": w_out, "well_in": w_in, "out_s": out_s, "in_s": in_s, "t1": t1}, true)
	var r_a: Array = eph.position(a_body, t1)
	var v_a: Array = eph.velocity(a_body, t1)
	job["r_a"] = r_a
	job["v_a"] = v_a
	var d0 := V.distance(r_a, eph.position(b_body, t1))
	job["deep"] = d0 > DEEP_SPACE_M
	if job["deep"]:
		_deep_candidates(job, d0, eph, b_body)
	var brach := 2.0 * sqrt(d0 / accel)
	for k in (0 if job["deep"] else SCAN_STEPS):
		var tof := brach * SCAN_FROM * pow(SCAN_TO / SCAN_FROM, float(k) / float(SCAN_STEPS - 1))
		var r_b: Array = eph.position(b_body, t1 + tof)
		var v_b: Array = eph.velocity(b_body, t1 + tof)
		var sol := OM.lambert(r_a, r_b, tof, job["mu"], V.cross(r_a, v_a))
		if sol.is_empty():
			continue
		var dv_imp := V.length(V.sub(sol[0], v_a)) + V.length(V.sub(v_b, sol[1]))
		var burn_frac := dv_imp / (accel * tof)
		if burn_frac > MAX_BURN_FRACTION:
			continue
		# Finite burns cost more than impulses: at the brachistochrone limit twice as much.
		var dv_eff := dv_imp / (1.0 - burn_frac)
		var dv_total := dv_eff + float(w_out["dv"]) + float(w_in["dv"])
		var fuel_t := mass * (1.0 - exp(-dv_total / ve))
		var duration := overhead + out_s + tof + in_s
		job["scan"].append({"tof": tof, "dv": dv_total, "fuel_t": fuel_t, "duration_s": duration,
			"r_a": r_a, "v_a": v_a, "r_b": r_b, "v_b": v_b})
	# Express: the fastest few that the tanks and the larder allow, tried in order until
	# one actually arrives when flown (finite thrust can't always match the estimate).
	# Economy: the cheapest few within ECONOMY_TIME_MULT of the fastest.
	var ok: Array = job["scan"].filter(func(c): return c["fuel_t"] <= fuel + 1e-9 and c["duration_s"] <= life_days * DAY)
	if ok.is_empty():
		# Nothing this ship can fly: offer the cheapest, flagged, so the pilot sees what it takes.
		var cheapest: Array = job["scan"].duplicate()
		cheapest.sort_custom(func(a, b): return a["fuel_t"] < b["fuel_t"])
		if not cheapest.is_empty():
			job["candidates"].append(["economy", cheapest.slice(0, 3)])
		return job
	var fastest := ok.duplicate()
	fastest.sort_custom(func(a, b): return a["duration_s"] < b["duration_s"])
	job["candidates"].append(["express", fastest.slice(0, 10)])
	var limit := float(fastest[0]["duration_s"]) * ECONOMY_TIME_MULT
	var cheap: Array = ok.filter(func(c): return c["duration_s"] <= limit)
	cheap.sort_custom(func(a, b): return a["fuel_t"] < b["fuel_t"])
	if not cheap.is_empty() and cheap[0] != fastest[0]:
		job["candidates"].append(["economy", cheap.slice(0, 4)])
	return job


## Deep space: the Sun's pull is negligible against these speeds, so the plan is the
## textbook one: accelerate, coast, decelerate along the line. Express spends all
## the propellant but a tenth (a brachistochrone if there is enough); Economy half of
## it, coasting longer.
static func _deep_candidates(job: Dictionary, d: float, eph, b_body: String) -> void:
	var accel := float(job["accel"])
	var ve := float(job["ve"])
	var mass := float(job["mass_t"])
	var fuel := float(job["fuel_t"])
	var t1 := float(job["t1"])
	for share in [0.9, 0.5]:
		# Delta-v from the propellant spent (rocket equation), less the wells.
		var dv_total := ve * log(mass / maxf(mass - fuel * share, 1e-3))
		var dv := dv_total - float(job["well_out"]["dv"]) - float(job["well_in"]["dv"])
		if dv <= 0.0:
			continue
		var tof: float
		if dv >= 2.0 * sqrt(d * accel):
			tof = 2.0 * sqrt(d / accel)
			dv = accel * tof
		else:
			var v := dv * 0.5
			tof = 2.0 * v / accel + (d - v * v / accel) / v
		var duration := float(job["overhead"]) + float(job["out_s"]) + tof + float(job["in_s"])
		var total := dv + float(job["well_out"]["dv"]) + float(job["well_in"]["dv"])
		job["scan"].append({"tof": tof, "dv": total, "fuel_t": mass * (1.0 - exp(-total / ve)), "duration_s": duration, "deep": true,
			"r_a": job["r_a"], "v_a": job["v_a"], "r_b": eph.position(b_body, t1 + tof), "v_b": eph.velocity(b_body, t1 + tof)})


## Fly the candidates (worker-safe). Options in the same shape as route_planner.gd's.
static func run(job: Dictionary) -> Array:
	var opts := []
	if job.get("deep", false):
		return opts
	for entry in job.get("candidates", []):
		var kind: String = entry[0]
		var c: Dictionary = {}
		var res: Dictionary = {}
		var t1 := float(job["t1"])
		for cand in entry[1]:
			c = cand
			res = HF.fly(t1, c["r_a"], c["v_a"], t1 + float(c["tof"]), c["r_b"], c["v_b"], float(job["accel"]), float(job["mu"]))
			if float(res["miss_r"]) < ARRIVE_MISS_R and float(res["miss_v"]) < ARRIVE_MISS_V:
				break
			res = {}
		if res.is_empty():
			continue
		if kind == "economy" and not opts.is_empty() and absf(float(opts[0]["duration_s"]) - float(c["duration_s"])) < DAY:
			continue
		var dv := float(res["dv"]) + float(job["well_out"]["dv"]) + float(job["well_in"]["dv"])
		var fuel := float(job["mass_t"]) * (1.0 - exp(-dv / float(job["ve"])))
		var arrive := float(job["t"]) + float(c["duration_s"])
		var days := (arrive - float(job["t"])) / DAY
		var life_ok := days <= float(job["life_days"])
		opts.append({
			"id": kind, "kind": kind, "label": kind.capitalize(), "dv": dv, "fuel_t": fuel,
			"affordable": fuel <= float(job["fuel_t"]) + 1e-9 and life_ok, "life_ok": life_ok,
			"duration_s": arrive - float(job["t"]), "arrive_t": arrive, "start_t": t1,
			"samples": res["samples"], "frame": "sun", "peri_alt": INF, "peri_t": -1.0,
			"miss_r": res["miss_r"], "miss_v": res["miss_v"], "out_s": job["out_s"], "in_s": job["in_s"],
			"well_dv": float(job["well_out"]["dv"]) + float(job["well_in"]["dv"]),
		})
	return opts


## The path a voyage actually flies, from a transfer's Sun-centred samples, which run
## from the departure world's centre to the destination world's (the patched-conic
## shortcut). Added round them:
##   - the climb-out: a spiral from the station, in the sense it orbits, out to a
##     hand-off point clear of the world, along the direction the transfer leaves in
##   - the capture: the same in reverse, down to the station at arrival
##   - near each end, the transfer eased onto the hand-off point. The offset lies
##     along the direction of travel, so it can only carry the path further out.
## Times, distances and propellant are unchanged; only the shape of the path is.
## accel thrusts the spirals (prograde out, retrograde in).
static func dress(samples: Array, data, eph, from_place: String, to_place: String, t_dep: float, t_arr: float, accel: float) -> Array:
	samples = _clean(samples)
	if samples.size() < 2:
		return samples
	samples = _bend_from_sun(samples, clearance(data, "sun"))
	var out := []
	# Velocities where the spirals meet the transfer, so the path joins smoothly.
	var join_out = null
	var join_in = null
	var first: Array = samples[0]
	var last: Array = samples[-1]
	var t1 := float(first[0])
	var t2 := float(last[0])
	var a_body: String = well(data, eph, from_place, t_dep)["body"]
	var b_body: String = well(data, eph, to_place, t_arr)["body"]
	var e_out := [0.0, 0.0, 0.0]
	var e_in := [0.0, 0.0, 0.0]
	var tau_out := 1.0
	var tau_in := 1.0
	var tof := maxf(t2 - t1, 1.0)
	if data.bodies.has(a_body) and t1 > t_dep:
		var v_inf := V.sub(first[2], eph.velocity(a_body, t1))
		var s0 := V.sub(eph.position(from_place, t_dep), eph.position(a_body, t_dep))
		var r_hand := maxf(V.length(s0) * HANDOFF_ORBITS, float(data.bodies[a_body]["radius_m"]) * HANDOFF_RADII)
		e_out = V.scale(V.normalized(v_inf if V.length(v_inf) > 1.0 else s0), r_hand)
		tau_out = clampf(4.0 * r_hand / maxf(V.length(v_inf), 500.0), tof * 0.02, tof * 0.3)
		var orbit_v := V.sub(eph.velocity(from_place, t_dep), eph.velocity(a_body, t_dep))
		var climb := _spiral(eph, a_body, s0, e_out, orbit_v, t_dep, t1, accel, false)
		join_out = climb[-1][2]
		out.append_array(climb.slice(0, -1))
	var capture := []
	if data.bodies.has(b_body) and t_arr > t2:
		var v_inf_in := V.sub(last[2], eph.velocity(b_body, t2))
		var s1 := V.sub(eph.position(to_place, t_arr), eph.position(b_body, t_arr))
		var r_hand_in := maxf(V.length(s1) * HANDOFF_ORBITS, float(data.bodies[b_body]["radius_m"]) * HANDOFF_RADII)
		e_in = V.scale(V.normalized(V.scale(v_inf_in, -1.0) if V.length(v_inf_in) > 1.0 else s1), r_hand_in)
		tau_in = clampf(4.0 * r_hand_in / maxf(V.length(v_inf_in), 500.0), tof * 0.02, tof * 0.3)
		var orbit_v_in := V.sub(eph.velocity(to_place, t_arr), eph.velocity(b_body, t_arr))
		capture = _spiral(eph, b_body, s1, e_in, orbit_v_in, t_arr, t2, accel, true)
		capture.reverse()
		join_in = capture[0][2]
	# The transfer, with extra samples where it eases off and onto the hand-offs.
	var times := []
	for smp in samples:
		times.append(float(smp[0]))
	for k in range(1, 9):
		times.append(t1 + tau_out * float(k) / 8.0)
		times.append(t2 - tau_in * float(k) / 8.0)
	times = times.filter(func(x): return x >= t1 and x <= t2)
	times.sort()
	var loc := {"samples": samples, "depart_t": t1, "arrive_t": t2, "from_pos": first[1], "to_pos": last[1]}
	var prev := -INF
	for tv in times:
		var t := float(tv)
		if t - prev < 1.0:
			continue
		prev = t
		var pos := _replay(loc, t, false)
		var vel := _replay(loc, t, true)
		var x_out := (t - t1) / tau_out
		if x_out < 1.0:
			pos = V.add(pos, V.scale(e_out, 1.0 - x_out * x_out * (3.0 - 2.0 * x_out)))
			vel = V.add(vel, V.scale(e_out, -6.0 * x_out * (1.0 - x_out) / tau_out))
		var x_in := (t2 - t) / tau_in
		if x_in < 1.0:
			pos = V.add(pos, V.scale(e_in, 1.0 - x_in * x_in * (3.0 - 2.0 * x_in)))
			vel = V.add(vel, V.scale(e_in, 6.0 * x_in * (1.0 - x_in) / tau_in))
		if t <= t1 + 0.5 and join_out != null:
			vel = join_out
		if t >= t2 - 0.5 and join_in != null:
			vel = join_in
		var thrust: Array = samples[_seg_index(samples, t)][3]
		out.append([t, pos, vel, thrust])
	if not capture.is_empty():
		out.append_array(capture.slice(1))
	return out


## Samples with no NaNs: a point with a bad position is dropped, a bad velocity is
## rebuilt from its neighbours (the conic propagator can fail on its last step).
static func _clean(samples: Array) -> Array:
	var good := samples.filter(func(smp): return not (is_nan(float(smp[1][0])) or is_nan(float(smp[1][1])) or is_nan(float(smp[1][2]))))
	for i in good.size():
		var v: Array = good[i][2]
		if is_nan(float(v[0])) or is_nan(float(v[1])) or is_nan(float(v[2])):
			var a: Array = good[maxi(i - 1, 0)]
			var b: Array = good[mini(i + 1, good.size() - 1)]
			var dt := float(b[0]) - float(a[0])
			good[i] = [good[i][0], good[i][1], V.scale(V.sub(b[1], a[1]), 1.0 / dt) if absf(dt) > 1e-3 else [0.0, 0.0, 0.0], good[i][3]]
	return good


## A spiral round `body` from offset `s0` (at t_from) to offset `e` (at t_to): radius
## growing (or shrinking) geometrically, turning in the sense of `orbit_v` plus one
## extra turn, so it never comes closer than the nearer end. Samples run t_from to
## t_to, excluding t_to (that is the transfer's first sample). With `inward` the same
## spiral is built from the station outward and the caller reverses it, with the thrust
## turned retrograde. Returns SPIRAL_SAMPLES + 1 samples, the last at t_to.
static func _spiral(eph, body: String, s0: Array, e: Array, orbit_v: Array, t_from: float, t_to: float, accel: float, inward: bool) -> Array:
	var r0 := maxf(V.length(s0), 1.0)
	var r1 := maxf(V.length(e), 1.0)
	var n0 := V.normalized(s0)
	var n1 := V.normalized(e)
	var axis := V.cross(s0, orbit_v)
	if V.length(axis) < 1e-6:
		axis = V.cross(n0, n1)
	if V.length(axis) < 1e-6:
		axis = [0.0, 0.0, 1.0]
	axis = V.normalized(axis)
	# Built from the station outward; a capture is flown the other way in time, so it
	# turns the other way here to arrive moving with the station.
	if inward:
		axis = V.scale(axis, -1.0)
	# Work in the station's orbital plane: the hand-off direction projected into it,
	# then tilted out of it over the last part of the spiral.
	var n1p := V.sub(n1, V.scale(axis, V.dot(n1, axis)))
	if V.length(n1p) < 1e-6:
		n1p = V.cross(axis, n0)
	n1p = V.normalized(n1p)
	var ang := atan2(V.dot(V.cross(n0, n1p), axis), V.dot(n0, n1p))
	if ang < 0.0:
		ang += TAU
	ang += TAU
	var pts := []
	for k in SPIRAL_SAMPLES:
		var f := float(k) / float(SPIRAL_SAMPLES)
		var t := lerpf(t_from, t_to, f)
		var dir := V.rotate(n0, axis, ang * f)
		# The last quarter leans from the orbital plane onto the hand-off direction.
		var lean := clampf((f - 0.75) / 0.25, 0.0, 1.0)
		dir = V.normalized(V.lerp(dir, n1, lean * lean * (3.0 - 2.0 * lean) * f))
		var r := r0 * pow(r1 / r0, f)
		pts.append([t, V.add(eph.position(body, t), V.scale(dir, r))])
	pts.append([t_to, V.add(eph.position(body, t_to), e)])
	var out := []
	for k in SPIRAL_SAMPLES + 1:
		var a: Array = pts[maxi(k - 1, 0)]
		var b: Array = pts[mini(k + 1, SPIRAL_SAMPLES)]
		var dt := float(b[0]) - float(a[0])
		var vel := V.scale(V.sub(b[1], a[1]), 1.0 / (dt if absf(dt) > 1e-3 else 1e-3))
		var rel_v := V.sub(vel, eph.velocity(body, float(pts[k][0])))
		var thrust := V.scale(V.normalized(rel_v), accel * (-1.0 if inward else 1.0))
		out.append([pts[k][0], pts[k][1], vel, thrust])
	return out


## Replay of a sampled path (Hermite between samples), the same rule
## Navigation uses, here so dress() can resample it.
static func _replay(loc: Dictionary, t: float, velocity: bool) -> Array:
	var samples: Array = loc["samples"]
	var i := _seg_index(samples, t)
	var a: Array = samples[i]
	var b: Array = samples[mini(i + 1, samples.size() - 1)]
	var T := maxf(float(b[0]) - float(a[0]), 1e-6)
	var s := clampf((t - float(a[0])) / T, 0.0, 1.0)
	var s2 := s * s
	var s3 := s2 * s
	if velocity:
		var v := V.scale(a[1], (6.0 * s2 - 6.0 * s) / T)
		v = V.add(v, V.scale(a[2], 3.0 * s2 - 4.0 * s + 1.0))
		v = V.add(v, V.scale(b[1], (-6.0 * s2 + 6.0 * s) / T))
		return V.add(v, V.scale(b[2], 3.0 * s2 - 2.0 * s))
	var p := V.scale(a[1], 2.0 * s3 - 3.0 * s2 + 1.0)
	p = V.add(p, V.scale(a[2], (s3 - 2.0 * s2 + s) * T))
	p = V.add(p, V.scale(b[1], -2.0 * s3 + 3.0 * s2))
	return V.add(p, V.scale(b[2], (s3 - s2) * T))


static func _seg_index(samples: Array, t: float) -> int:
	var lo := 0
	var hi := samples.size() - 1
	while hi - lo > 1:
		var mid := (lo + hi) >> 1
		if float(samples[mid][0]) <= t:
			lo = mid
		else:
			hi = mid
	return lo


## The free-fall path of a candidate transfer, n + 1 samples [t, pos, vel, thrust].
static func _conic_samples(pick: Dictionary, job: Dictionary, n: int) -> Array:
	var t1 := float(job["t1"])
	var tof := float(pick["tof"])
	var samples := []
	if pick.get("deep", false):
		# Out along the line, thrusting, coasting, braking.
		var line := V.sub(pick["r_b"], pick["r_a"])
		for k in n + 1:
			var f := float(k) / float(n)
			var shape := f * f * (3.0 - 2.0 * f)
			samples.append([t1 + tof * f, V.add(pick["r_a"], V.scale(line, shape)), V.scale(line, 6.0 * f * (1.0 - f) / tof), [0.0, 0.0, 0.0]])
	else:
		var sol := OM.lambert(pick["r_a"], pick["r_b"], tof, job["mu"], V.cross(pick["r_a"], pick["v_a"]))
		# Even steps of tof / n, but never wider than STEP_TURN radians of swing about the
		# Sun (r / v is how long that takes): a pass close to the Sun is fast, and a Hermite
		# curve through samples a few days apart would cut straight through it.
		var dt := 0.0
		var step_max := tof / float(n)
		var count := 0
		while true:
			var st := OM.kepler(pick["r_a"], sol[0], dt, job["mu"])
			samples.append([t1 + dt, st[0], st[1], [0.0, 0.0, 0.0]])
			if dt >= tof or count >= MAX_CONIC_SAMPLES:
				break
			count += 1
			var step := minf(step_max, STEP_TURN * V.length(st[0]) / maxf(V.length(st[1]), 1.0))
			dt = minf(dt + maxf(step, tof * 1e-5), tof)
		samples[-1][0] = t1 + tof
	return samples


## Samples bent clear of the Sun: a point inside the clearance is pushed radially out
## to SUN_BEND x the clearance, and its velocity is rebuilt from its neighbours so the
## path stays smooth. A transfer's times and propellant are untouched (the arc is the
## shape of the path, as with Navigation's runs round a body); only samples that would
## pass through the Sun move.
static func _bend_from_sun(samples: Array, clear: float) -> Array:
	var target := clear * SUN_BEND
	var lifted := []
	var out := []
	for i in samples.size():
		var smp: Array = samples[i]
		var p: Array = smp[1]
		var d := V.length(p)
		if d < target and d > 1.0:
			p = V.scale(p, target / d)
			lifted.append(i)
		out.append([smp[0], p, smp[2], smp[3]])
	if lifted.is_empty():
		return samples
	var touched := {}
	for i in lifted:
		for j in range(maxi(i - 1, 0), mini(i + 2, out.size())):
			touched[j] = true
	for j in touched:
		var a: Array = out[maxi(j - 1, 0)]
		var b: Array = out[mini(j + 1, out.size() - 1)]
		var dt := float(b[0]) - float(a[0])
		if absf(dt) > 1e-3:
			out[j] = [out[j][0], out[j][1], V.scale(V.sub(b[1], a[1]), 1.0 / dt), out[j][3]]
	return out


## Quick estimate for boards and NPCs (no flight): the fastest affordable candidate,
## or the cheapest if none is. In Navigation.plan's shape, with a free-fall conic path.
static func quick(ship: Dictionary, data, eph, from_place: String, to_place: String, t: float) -> Dictionary:
	var job := prepare(ship, data, eph, from_place, to_place, t)
	var result := {"ok": false, "reason": job.get("reason", ""), "frame": "sun"}
	var pick := {}
	for c in job.get("candidates", []):
		if pick.is_empty() and not c[1].is_empty():
			pick = c[1][0]
	if pick.is_empty():
		if result["reason"] == "":
			result["reason"] = "beyond this ship: no transfer it can fly"
		return result
	# The fastest candidate keeps its time and propellant; dress() bends its path clear
	# of the Sun if the arc would pass through it.
	var samples := _conic_samples(pick, job, 40)
	var tof := float(pick["tof"])
	var arrive := t + float(pick["duration_s"])
	samples = dress(samples, data, eph, from_place, to_place, t, arrive, float(job["accel"]))
	var fuel_t := float(pick["fuel_t"])
	var dest_refuels: bool = "refuel" in data.locations[to_place].get("services", [])
	var days := (arrive - t) / DAY
	result.merge({
		"distance_m": V.distance(pick["r_a"], pick["r_b"]), "burn_s": tof, "duration_s": arrive - t, "fuel_t": fuel_t,
		"arrive_t": arrive, "from_pos": eph.position(from_place, t), "to_pos": eph.position(to_place, arrive),
		"from_vel": [0.0, 0.0, 0.0], "to_vel": [0.0, 0.0, 0.0], "samples": samples, "throttle": 1.0,
		"fuel_after_t": float(ship.get("fuel_t", 0.0)) - fuel_t, "dest_refuels": dest_refuels,
		"strand_risk": not dest_refuels and float(ship.get("fuel_t", 0.0)) - fuel_t < fuel_t,
		"life_days_needed": days,
	}, true)
	if fuel_t > float(ship.get("fuel_t", 0.0)) + 1e-9:
		result["reason"] = "not enough propellant: need %.1f t, have %.1f t" % [fuel_t, ship["fuel_t"]]
	elif days > float(job["life_days"]):
		result["reason"] = "life support: the trip takes %d days, the crew can be supplied for %d" % [ceili(days), int(job["life_days"])]
	else:
		result["ok"] = true
	return result
