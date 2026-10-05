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
	var t1 := float(job["t1"])
	var tof := float(pick["tof"])
	var samples := []
	if pick.get("deep", false):
		# Out along the line, thrusting, coasting, braking.
		var line := V.sub(pick["r_b"], pick["r_a"])
		for k in 41:
			var f := float(k) / 40.0
			var shape := f * f * (3.0 - 2.0 * f)
			samples.append([t1 + tof * f, V.add(pick["r_a"], V.scale(line, shape)), V.scale(line, 6.0 * f * (1.0 - f) / tof), [0.0, 0.0, 0.0]])
	else:
		var sol := OM.lambert(pick["r_a"], pick["r_b"], tof, job["mu"], V.cross(pick["r_a"], pick["v_a"]))
		for k in 41:
			var dt := tof * float(k) / 40.0
			var st := OM.kepler(pick["r_a"], sol[0], dt, job["mu"])
			samples.append([t1 + dt, st[0], st[1], [0.0, 0.0, 0.0]])
	var arrive := t + float(pick["duration_s"])
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
