## Gravity route planning: hand-off points clear of gravity wells, and the
## co-pilot's route options (express, economy, lunar flybys) flown by
## gravity_flight.gd. Pure functions of their inputs, so results are deterministic.
extends RefCounted

const V := preload("res://sim/v3.gd")
const OM := preload("res://sim/orbit_mech.gd")
const GF := preload("res://sim/gravity_flight.gd")
const Navigation := preload("res://sim/navigation.gd")
const ShipStats := preload("res://sim/ship_stats.gd")
const Interplanetary := preload("res://sim/interplanetary.gd")

## Trip lengths tried, as multiples of the quick (gravity-free) estimate.
const DURATION_STEPS := [0.9, 1.15, 1.45, 1.8, 2.3, 2.9]
## Flyby periapsis altitudes offered (m): a comfortable pass, a low sweep, a hot pass.
const FLYBY_ALTITUDES := [500.0e3, 100.0e3, 30.0e3]
const FLYBY_FRACTIONS := [0.35, 0.5]
## A plan counts as arriving when it ends this close (the co-pilot's capture covers the rest).
const ARRIVE_MISS_R := 3.0e5
const ARRIVE_MISS_V := 60.0
const CRASH_ALT := 5.0e3

## Stations orbiting Earth below this radius hand off on a circular orbit here.
const EARTH_HANDOFF_R := 5.0e7
## Stations orbiting the Moon hand off on a circular orbit of this radius around it.
const MOON_HANDOFF_R := 2.5e7


## Where the gravity-flown part of a trip starts or ends for a place, in the Earth
## frame: [position, velocity]. Lagrange stations hand off at the station itself.
static func hand_off(data, eph, place: String, t: float) -> Array:
	var loc: Dictionary = data.places[place]["location"]
	if loc["type"] == "orbit":
		var parent: String = loc["parent"]
		var mu := float(data.bodies[parent]["gm"])
		var centre: Array = eph.relative(parent, "earth", t)
		var centre_v: Array = [0.0, 0.0, 0.0] if parent == "earth" else V.sub(eph.velocity(parent, t), eph.velocity("earth", t))
		var rel: Array = V.sub(eph.relative(place, "earth", t), centre)
		var rel_v: Array = V.sub(V.sub(eph.velocity(place, t), eph.velocity("earth", t)), centre_v)
		var radius := EARTH_HANDOFF_R if parent == "earth" else MOON_HANDOFF_R
		if V.length(rel) < radius:
			# The climb-out (inside the overhead hours) delivers the ship to a circular
			# hand-off orbit in the Moon's orbital plane, where every cislunar
			# destination lies, above the station's position and moving prograde.
			var moon_r: Array = eph.relative("moon", "earth", t)
			var moon_v: Array = V.sub(eph.velocity("moon", t), eph.velocity("earth", t))
			var normal := V.normalized(V.cross(moon_r, moon_v))
			var flat := V.sub(rel, V.scale(normal, V.dot(rel, normal)))
			var out := V.normalized(flat) if V.length(flat) > 1.0 else V.normalized(moon_r)
			var tangent := V.normalized(V.cross(normal, out))
			return [V.add(centre, V.scale(out, radius)), V.add(centre_v, V.scale(tangent, OM.circular_speed(mu, radius)))]
	return [eph.relative(place, "earth", t), V.sub(eph.velocity(place, t), eph.velocity("earth", t))]



## Everything a planning run needs, gathered on the main thread (the ephemeris is not
## thread-safe), so run() can execute on a worker thread on plain data.
static func prepare(ship: Dictionary, data, eph, from_place: String, to_place: String, t: float) -> Dictionary:
	if Interplanetary.is_interplanetary(data, from_place, to_place):
		return Interplanetary.prepare(ship, data, eph, from_place, to_place, t)
	var quick: Dictionary = Navigation.plan(ship, data, eph, from_place, to_place, t)
	var overhead := float(data.balance["travel"]["overhead_hours"]) * 3600.0
	var start := t + overhead * 0.5
	var base: float = quick.get("burn_s", 3.0 * 86400.0)
	var arrivals := []
	for k in DURATION_STEPS:
		var tf: float = start + base * float(k)
		var h := hand_off(data, eph, to_place, tf)
		arrivals.append({"tf": tf, "pos": h[0], "vel": h[1]})
	var t_end: float = start + base * float(DURATION_STEPS[-1]) + 86400.0
	var h0 := hand_off(data, eph, from_place, start)
	var moon_anchored := _moon_anchored(data, from_place) or _moon_anchored(data, to_place)
	return {
		"from": from_place, "to": to_place, "t": t, "start": start, "overhead": overhead,
		"r0": h0[0], "v0": h0[1], "arrivals": arrivals,
		"table": GF.moon_table(eph, start - 3600.0, t_end),
		"accel": ShipStats.accel_mps2(ship, data), "ve": ShipStats.exhaust_velocity(ship, data),
		"mass_t": ShipStats.total_mass_t(ship, data), "fuel_t": float(ship.get("fuel_t", 0.0)),
		"mu_e": float(data.bodies["earth"]["gm"]), "mu_m": float(data.bodies["moon"]["gm"]),
		"moon_radius": float(data.bodies["moon"]["radius_m"]),
		"flybys": not moon_anchored,
	}


static func _moon_anchored(data, place: String) -> bool:
	var loc: Dictionary = data.places[place]["location"]
	return loc["type"] == "orbit" and loc["parent"] == "moon"


## Fly the candidate routes. Pure: safe on a worker thread. Returns route options
## [{id, kind, label, duration_s, arrive_t, dv, fuel_t, affordable, samples, peri_alt, ...}].
static func run(job: Dictionary) -> Array:
	if job.get("helio", false):
		return Interplanetary.run(job)
	var direct := []
	for arr in job["arrivals"]:
		var legs := [{"kind": "rendezvous", "t": arr["tf"], "pos": arr["pos"], "vel": arr["vel"]}]
		var res := GF.fly(job["start"], job["r0"], job["v0"], legs, job["accel"], job["table"], job["mu_e"], job["mu_m"], job["moon_radius"])
		if _arrives(res):
			direct.append(_option(job, "direct", res, arr["tf"], -1.0))
	var options := []
	if direct.is_empty():
		return options
	var express: Dictionary = direct[0]
	var economy: Dictionary = direct[0]
	for o in direct:
		if o["dv"] < economy["dv"]:
			economy = o
	express["id"] = "express"
	express["label"] = "Express"
	options.append(express)
	if economy != express:
		economy["id"] = "economy"
		economy["label"] = "Economy"
		options.append(economy)
	if job["flybys"]:
		var tf: float = float(economy["arrive_t"]) - float(job["overhead"]) * 0.5
		var arr := {}
		for a in job["arrivals"]:
			if absf(float(a["tf"]) - tf) < 1.0:
				arr = a
		for alt in FLYBY_ALTITUDES:
			var best := {}
			for frac in FLYBY_FRACTIONS:
				var t1: float = float(job["start"]) + (tf - float(job["start"])) * float(frac)
				for side in _flyby_sides(job, t1, arr):
					var legs := [
						{"kind": "flyby", "t": tf - 3600.0, "t_peri": t1, "rp": float(job["moon_radius"]) + float(alt), "side": side},
						{"kind": "rendezvous", "t": tf, "pos": arr["pos"], "vel": arr["vel"]},
					]
					var res := GF.fly(job["start"], job["r0"], job["v0"], legs, job["accel"], job["table"], job["mu_e"], job["mu_m"], job["moon_radius"])
					if _arrives(res) and res["min_moon_alt"] < float(alt) * 1.5 + 50.0e3 and (best.is_empty() or res["dv"] < best["dv"]):
						best = _option(job, "flyby", res, tf, float(alt))
			if not best.is_empty():
				best["id"] = "flyby_%d" % int(float(alt) / 1000.0)
				best["label"] = "Lunar flyby, %d km" % int(round(float(best["peri_alt"]) / 1000.0))
				best["saving"] = 1.0 - float(best["dv"]) / float(economy["dv"])
				options.append(best)
	return options


static func _arrives(res: Dictionary) -> bool:
	return res["miss_r"] < ARRIVE_MISS_R and res["miss_v"] < ARRIVE_MISS_V and res["min_moon_alt"] > CRASH_ALT


## The two candidate sides of the Moon to pass, by B-plane geometry: the Moon bends
## the path toward itself, so offset opposite to the turn wanted (and try the other).
static func _flyby_sides(job: Dictionary, t1: float, arr: Dictionary) -> Array:
	var table: Dictionary = job["table"]
	var m := GF.moon_at(table, t1)
	var mv := GF.moon_vel(table, t1)
	var lin := OM.lambert(job["r0"], m, t1 - float(job["start"]), job["mu_e"], V.cross(job["r0"], job["v0"]))
	var lout := OM.lambert(m, arr["pos"], float(arr["tf"]) - t1, job["mu_e"], V.cross(m, mv))
	if lin.is_empty() or lout.is_empty():
		return []
	var vin := V.normalized(V.sub(lin[1], mv))
	var vout := V.sub(lout[0], mv)
	var turn := V.sub(vout, V.scale(vin, V.dot(vout, vin)))
	if V.length(turn) < 1e-6:
		return []
	var side := V.scale(V.normalized(turn), -1.0)
	return [side, V.scale(side, -1.0)]


static func _option(job: Dictionary, kind: String, res: Dictionary, tf: float, alt: float) -> Dictionary:
	var dv: float = res["dv"]
	var fuel := float(job["mass_t"]) * (1.0 - exp(-dv / float(job["ve"])))
	var arrive := tf + float(job["overhead"]) * 0.5
	return {
		"id": kind, "kind": kind, "label": kind, "dv": dv, "fuel_t": fuel,
		"affordable": fuel <= float(job["fuel_t"]) + 1e-9,
		"duration_s": arrive - float(job["t"]), "arrive_t": arrive, "start_t": job["start"],
		"samples": res["samples"], "peri_alt": res["min_moon_alt"], "peri_t": res["peri_t"],
		"miss_r": res["miss_r"],
	}


## Both ends inside Earth's climb-out zone (e.g. low orbit to GEO): no free flight
## to plan; the quick plan is the route.
static func is_orbital_hop(data, eph, a: String, b: String, t: float) -> bool:
	for place in [a, b]:
		var loc: Dictionary = data.places[place]["location"]
		if loc["type"] != "orbit" or loc["parent"] != "earth" or V.length(eph.relative(place, "earth", t)) >= EARTH_HANDOFF_R:
			return false
	return true


## Blocking convenience: prepare and run in one go.
static func plan_options(ship: Dictionary, data, eph, from_place: String, to_place: String, t: float) -> Array:
	return run(prepare(ship, data, eph, from_place, to_place, t))


## Route options for a trip: gravity-flown options where possible, else the quick
## plan as a single "Direct" option (always available, so travel never dead-ends).
static func options_or_quick(job: Dictionary, quick: Dictionary) -> Array:
	var opts: Array = run(job) if not job.get("hop", false) else []
	if opts.is_empty() and quick.get("ok", false):
		opts = [{"id": "quick", "kind": "quick", "label": "Orbital hop" if job.get("hop", false) else "Direct",
			"dv": 0.0, "fuel_t": quick["fuel_t"], "affordable": true, "duration_s": quick["duration_s"],
			"arrive_t": quick["arrive_t"], "samples": null, "peri_alt": INF, "peri_t": -1.0}]
	return opts
