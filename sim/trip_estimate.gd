## The co-pilot's estimate of a trip, honest about gravity. Navigation.plan is a quick
## gravity-free sum: near Earth and the Moon the routes a ship can really fly
## (RoutePlanner, what "Plot routes" offers) often take two or three times as long, and
## across the system they can take more propellant than the tank holds. This flies the
## routes the planner would offer and reports the fastest one the ship can take, in
## Navigation.plan's shape (plus "route", the option's id).
##
## To stay quick it mirrors the planner without its lunar flybys: it flies the direct
## routes shortest first and stops at the first that arrives if the ship can afford it
## (the express); otherwise it flies them all for the cheapest (the economy). With no
## flown route at all it falls back to the quick plan, as the planner does.
##
## Estimates are worked out at the top of the hour and remembered, so the answer
## depends only on the trip, the ship and the hour, never on what was asked before.
extends RefCounted

const Navigation := preload("res://sim/navigation.gd")
const RoutePlanner := preload("res://sim/route_planner.gd")
const Interplanetary := preload("res://sim/interplanetary.gd")
const GF := preload("res://sim/gravity_flight.gd")
const ShipStats := preload("res://sim/ship_stats.gd")

const BUCKET_S := 3600.0
const KEEP := 512

static var _memo: Dictionary = {}


static func _key(ship: Dictionary, data, from_place: String, to_place: String, t: float) -> String:
	return "%s>%s|%d|%.3f|%.3f|%.5f|%.0f" % [from_place, to_place, int(floor(t / BUCKET_S)), ShipStats.total_mass_t(ship, data),
		float(ship.get("fuel_t", 0.0)), ShipStats.accel_mps2(ship, data), ShipStats.exhaust_velocity(ship, data)]


## The estimate if it has been worked out already this hour, else {}.
static func cached(ship: Dictionary, data, from_place: String, to_place: String, t: float) -> Dictionary:
	var key := _key(ship, data, from_place, to_place, t)
	return _shifted(_memo[key], t) if _memo.has(key) else {}


## The estimate, worked out now if need be (tens to hundreds of milliseconds).
static func trip(ship: Dictionary, data, eph, from_place: String, to_place: String, t: float) -> Dictionary:
	var key := _key(ship, data, from_place, to_place, t)
	if not _memo.has(key):
		if _memo.size() >= KEEP:
			_memo.clear()
		_memo[key] = _work_out(ship, data, eph, from_place, to_place, floor(t / BUCKET_S) * BUCKET_S)
	return _shifted(_memo[key], t)


## Worked out at the top of the hour; asked later in it, the arrival moves on with t.
static func _shifted(plan: Dictionary, t: float) -> Dictionary:
	var out := plan.duplicate()
	if out.has("arrive_t") and out.has("t"):
		out["arrive_t"] = float(out["arrive_t"]) + t - float(out["t"])
	out.erase("t")
	return out


static func _work_out(ship: Dictionary, data, eph, from_place: String, to_place: String, t: float) -> Dictionary:
	var quick: Dictionary = Navigation.plan(ship, data, eph, from_place, to_place, t)
	quick["t"] = t
	if from_place == to_place or not quick.has("duration_s"):
		return quick
	var opts: Array = []
	if Interplanetary.is_interplanetary(data, from_place, to_place):
		opts = RoutePlanner.run(RoutePlanner.prepare(ship, data, eph, from_place, to_place, t))
	elif not RoutePlanner.is_orbital_hop(data, eph, from_place, to_place, t):
		opts = _direct(RoutePlanner.prepare(ship, data, eph, from_place, to_place, t))
	if opts.is_empty():
		# Nothing flown arrives: the planner offers the quick plan itself.
		return quick
	var best := {}
	for o in opts:
		if o["affordable"] and o.get("life_ok", true) and (best.is_empty() or float(o["duration_s"]) < float(best["duration_s"])):
			best = o
	var out := quick.duplicate()
	var have := float(ship.get("fuel_t", 0.0))
	if best.is_empty():
		# Nothing the ship can take: say what the cheapest would need.
		var cheap: Dictionary = opts[0]
		for o in opts:
			if float(o["fuel_t"]) < float(cheap["fuel_t"]):
				cheap = o
		best = cheap
		out["ok"] = false
		if not cheap.get("life_ok", true):
			out["reason"] = "life support: the crew can't be supplied for a trip that long"
		else:
			out["reason"] = "not enough propellant: the cheapest route needs %.2f t, have %.2f t" % [float(cheap["fuel_t"]), have]
	else:
		out["ok"] = true
		out["reason"] = ""
	var fuel := float(best["fuel_t"])
	out.merge({"duration_s": float(best["duration_s"]), "arrive_t": float(best["arrive_t"]), "fuel_t": fuel,
		"fuel_after_t": have - fuel, "route": String(best["id"])}, true)
	out["strand_risk"] = not bool(out.get("dest_refuels", true)) and have - fuel < fuel
	return out


## The planner's direct routes near Earth and the Moon (RoutePlanner.run without the
## flybys): the first that arrives is the express; if the ship can't afford it, the
## one needing least is the economy.
static func _direct(job: Dictionary) -> Array:
	var express := {}
	var economy := {}
	for arr in job["arrivals"]:
		var legs := [{"kind": "rendezvous", "t": arr["tf"], "pos": arr["pos"], "vel": arr["vel"]}]
		var res := GF.fly(job["start"], job["r0"], job["v0"], legs, job["accel"], job["table"], job["mu_e"], job["mu_m"], job["moon_radius"])
		if not RoutePlanner._arrives(res):
			continue
		var o := RoutePlanner._option(job, "direct", res, arr["tf"], -1.0)
		if express.is_empty():
			express = o
			express["id"] = "express"
			if o["affordable"]:
				return [express]
		if economy.is_empty() or float(o["dv"]) < float(economy["dv"]):
			economy = o
	if express.is_empty():
		return []
	if economy == express:
		return [express]
	economy["id"] = "economy"
	return [express, economy]
