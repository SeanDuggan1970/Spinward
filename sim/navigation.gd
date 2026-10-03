## Route planning: the co-pilot's job. Constant-thrust "flip at midpoint" transfer
## at the ship's current mass, aimed where the target will be on arrival.
## Positions are taken relative to the trip's frame body (the lowest common parent
## body, e.g. Earth for cislunar trips), which is close to inertial over a few days.
extends RefCounted

const V := preload("res://sim/v3.gd")
const ShipStats := preload("res://sim/ship_stats.gd")


## The chain of bodies a place hangs from, nearest first.
static func body_chain(data, place: String) -> Array:
	var loc: Dictionary = data.places[place]["location"]
	var body: String = loc["parent"] if loc["type"] == "orbit" else loc["system"][0]
	var chain := []
	while body != "":
		chain.append(body)
		body = data.bodies[body].get("parent", "")
	return chain


static func frame_body(data, a: String, b: String) -> String:
	var chain_b := body_chain(data, b)
	for body in body_chain(data, a):
		if body in chain_b:
			return body
	return "sun"


## Returns {ok, reason, distance_m, duration_s, burn_s, fuel_t, arrive_t, from_pos, to_pos, frame}.
static func plan(state, data, eph, from_place: String, to_place: String, t: float) -> Dictionary:
	var result := {"ok": false, "reason": ""}
	if from_place == to_place:
		result["reason"] = "already here"
		return result
	var accel := ShipStats.accel_mps2(state.ship, data)
	var ve := ShipStats.exhaust_velocity(state.ship, data)
	if accel <= 0.0 or ve <= 0.0:
		result["reason"] = "no working drive"
		return result
	var travel: Dictionary = data.balance["travel"]
	var overhead := float(travel["overhead_hours"]) * 3600.0
	var frame := frame_body(data, from_place, to_place)
	var from_pos: Array = eph.relative(from_place, frame, t)
	var to_pos: Array = eph.relative(to_place, frame, t)
	var distance := V.distance(from_pos, to_pos)
	var burn := 0.0
	for _i in int(travel["intercept_iterations"]):
		burn = 2.0 * sqrt(distance / accel)
		to_pos = eph.relative(to_place, frame, t + burn + overhead)
		distance = V.distance(from_pos, to_pos)
	burn = 2.0 * sqrt(distance / accel)
	var fuel_t := ShipStats.thrust_n(state.ship, data) / ve * burn / 1000.0
	result.merge({
		"distance_m": distance, "burn_s": burn, "duration_s": burn + overhead, "fuel_t": fuel_t,
		"arrive_t": t + burn + overhead, "from_pos": from_pos, "to_pos": to_pos, "frame": frame,
	}, true)
	if fuel_t > float(state.ship.get("fuel_t", 0.0)) + 1e-9:
		result["reason"] = "not enough propellant: need %.2f t, have %.2f t" % [fuel_t, state.ship["fuel_t"]]
		return result
	result["ok"] = true
	return result


## Ship position in the trip frame during transit, following the accelerate/flip/brake profile.
static func transit_position(location: Dictionary, t: float) -> Array:
	var duration := float(location["arrive_t"]) - float(location["depart_t"])
	var burn := float(location["burn_s"])
	var start := float(location["depart_t"]) + (duration - burn) * 0.5
	var tau := clampf((t - start) / burn, 0.0, 1.0) if burn > 0.0 else 1.0
	var s := 2.0 * tau * tau if tau < 0.5 else 1.0 - 2.0 * (1.0 - tau) * (1.0 - tau)
	return V.lerp(location["from_pos"], location["to_pos"], s)
