## NPC traffic: fleets of ships that trade from the same markets as the player.
##
## Each NPC is docked (waiting until next_t) or in transit (arriving at next_t).
## Events are processed in time order, at the time they are due, so a long tick
## still lets each NPC make several decisions. Randomness comes from a generator
## whose state lives in GameState, so runs replay identically and saves stay exact.
extends "res://sim/systems/system.gd"

const Navigation := preload("res://sim/navigation.gd")
const Interplanetary := preload("res://sim/interplanetary.gd")
const Perks := preload("res://sim/perks.gd")
const Market := preload("res://sim/market.gd")
const ShipStats := preload("res://sim/ship_stats.gd")
const V := preload("res://sim/v3.gd")

const HOUR := 3600.0
const DAY := 86400.0
const MAX_EVENTS_PER_TICK := 5000

var _rng := RandomNumberGenerator.new()
## The fleet of the NPC departing now (for _sail_plan).
var _sailing: Dictionary = {}


func start_game() -> void:
	var s = sim().state
	var data = sim().data
	_seed_rng()
	s.npcs = []
	_add_missing_ships(s.time_s)
	s.rng_state = _rng.state


## Every ship of every fleet, commissioned on its fleet's schedule ("commission_days",
## from `start`): until then it is fitting out, out of service and out of sight.
## Also fills in ships added to the data after a save was made.
func _add_missing_ships(start: float) -> void:
	var s = sim().state
	var data = sim().data
	var have := {}
	for npc in s.npcs:
		have[npc["id"]] = true
	for fleet_id in data.npcs["fleets"]:
		var fleet: Dictionary = data.npcs["fleets"][fleet_id]
		var names: Array = fleet["names"]
		var schedule: Array = fleet.get("commission_days", [])
		for i in int(fleet["count"]):
			var id := "%s.%d" % [fleet_id, i]
			if have.has(id):
				continue
			var hull: Dictionary = data.ships[fleet["hull"]]
			var ship := {"hull": fleet["hull"], "modules": hull["modules"].duplicate(), "cargo": {}, "fuel_t": 0.0}
			ship["fuel_t"] = ShipStats.fuel_capacity_t(ship, data)
			var leg := i % maxi(1, fleet.get("route", []).size())
			var home: String = fleet["route"][leg]["at"] if fleet.has("route") else fleet["homes"][i % fleet["homes"].size()]
			var active_t := start + (float(schedule[i]) * DAY if i < schedule.size() else 0.0)
			# Fleets a project builds wait for it ("commission_project"); then the schedule
			# counts from the day it finishes.
			var awaits: String = fleet.get("commission_project", "")
			if awaits != "":
				active_t = INF
			s.npcs.append({
				"id": id,
				"fleet": fleet_id,
				"name": names[i % names.size()],
				"ship": ship,
				"location": {"status": "docked", "place": home},
				"next_t": maxf(s.time_s, active_t) + _rng.randf_range(0.0, 24.0) * HOUR,
				"active_t": active_t,
				"commissioned": active_t <= start,
				"awaits": awaits,
				"leg": leg,
				"trips": 0,
			})


## In service (not still fitting out) at time t.
static func in_service(npc: Dictionary, t: float) -> bool:
	return t >= float(npc.get("active_t", -INF))


func tick(_game_dt: float) -> void:
	var s = sim().state
	if s.npcs.is_empty():
		return
	_seed_rng()
	_rng.state = s.rng_state
	if s.npcs.size() < _fleet_size():
		_add_missing_ships(s.time_s)
	for npc in s.npcs:
		var awaits: String = npc.get("awaits", "")
		if awaits != "" and s.projects.get(awaits, {}).get("done", false):
			var fleet := _fleet(npc)
			var schedule: Array = fleet.get("commission_days", [])
			var i := int(String(npc["id"]).get_slice(".", 1))
			npc["active_t"] = s.time_s + (float(schedule[i]) * DAY if i < schedule.size() else 0.0)
			npc["next_t"] = float(npc["active_t"]) + _rng.randf_range(0.0, 24.0) * HOUR
			npc["awaits"] = ""
		if not npc.get("commissioned", true) and s.time_s >= float(npc["active_t"]):
			npc["commissioned"] = true
			sim().emit("npc_commissioned", {"npc": npc["id"], "place": npc["location"]["place"]}, float(npc["active_t"]))
	for _i in MAX_EVENTS_PER_TICK:
		var due: Dictionary = {}
		for npc in s.npcs:
			if float(npc["next_t"]) <= s.time_s and (due.is_empty() or float(npc["next_t"]) < float(due["next_t"])):
				due = npc
		if due.is_empty():
			break
		if due["location"]["status"] == "transit":
			_arrive(due, float(due["next_t"]))
		else:
			_depart(due, float(due["next_t"]))
	s.rng_state = _rng.state
	for npc in s.npcs:
		var fb = npc.get("flyby")
		if fb is Dictionary and not fb["done"] and npc["location"]["status"] == "transit" and s.time_s >= float(fb["t"]):
			fb["done"] = true
			sim().emit("npc_flyby", {"npc": npc["id"], "alt": fb["alt"]}, float(fb["t"]))


func _fleet_size() -> int:
	var n := 0
	for fleet_id in sim().data.npcs["fleets"]:
		n += int(sim().data.npcs["fleets"][fleet_id]["count"])
	return n


func _moon_anchored(place: String) -> bool:
	var loc: Dictionary = sim().data.places[place]["location"]
	return loc["type"] == "orbit" and loc["parent"] == "moon"


## Seed first, then restore the saved state: a freshly loaded game must continue the
## exact sequence the saved one would have produced.
func _seed_rng() -> void:
	_rng.seed = hash(sim().state.seed) ^ 0x5EED


func _fleet(npc: Dictionary) -> Dictionary:
	return sim().data.npcs["fleets"][npc["fleet"]]


func _dwell(npc: Dictionary) -> float:
	var r: Array = _fleet(npc)["dwell_hours"]
	return _rng.randf_range(float(r[0]), float(r[1])) * HOUR


## What an NPC may take from a market without stripping it bare for everyone else.
func _available(place: String, good: String) -> float:
	var reserve := float(sim().data.npcs["reserve_fraction"]) * Market.target(sim().data, place, good)
	return maxf(0.0, Market.stock(sim().state, place, good) - reserve)


func _arrive(npc: Dictionary, t: float) -> void:
	var s = sim().state
	var place: String = npc["location"]["to"]
	var sold := {}
	for good in npc["ship"]["cargo"]:
		var tonnes := float(npc["ship"]["cargo"][good])
		if Market.trades(sim().data, place, good):
			s.markets[place][good] += tonnes
			sold[good] = tonnes
	npc["ship"]["cargo"] = {}
	npc["location"] = {"status": "docked", "place": place}
	npc["trips"] += 1
	# Top up from the local propellant stock where there is one.
	var data = sim().data
	if "refuel" in data.places[place].get("services", []):
		var need := ShipStats.fuel_capacity_t(npc["ship"], data) - float(npc["ship"]["fuel_t"])
		var take := minf(need, _available(place, "propellant"))
		s.markets[place]["propellant"] -= take
		npc["ship"]["fuel_t"] += take
	npc["next_t"] = t + _dwell(npc)
	sim().emit("npc_arrived", {"npc": npc["id"], "place": place, "sold": sold}, t)


func _depart(npc: Dictionary, t: float) -> void:
	var here: String = npc["location"]["place"]
	var choice: Dictionary
	match _fleet(npc)["behaviour"]:
		"trader":
			choice = _choose_trade(npc, here, t)
		_:
			choice = _choose_leg(npc, here)
	var plan := {}
	if not choice.is_empty():
		var loaded: Dictionary = npc["ship"].duplicate(true)
		for good in choice["buy"]:
			loaded["cargo"][good] = choice["buy"][good]
		_sailing = _fleet(npc)
		if _sailing.get("elevator", false):
			plan = _climb_plan(here, choice["to"], t)
		elif _sailing.get("sail", false):
			plan = _sail_plan(here, choice["to"], t)
		else:
			plan = Navigation.plan(loaded, sim().data, sim().ephemeris, here, choice["to"], t)
		if not plan["ok"] and plan.get("reason", "").begins_with("not enough propellant"):
			# Fleet tankers and company accounts keep their own ships fuelled; never strand an NPC.
			npc["ship"]["fuel_t"] = ShipStats.fuel_capacity_t(npc["ship"], sim().data)
			loaded["fuel_t"] = npc["ship"]["fuel_t"]
			plan = Navigation.plan(loaded, sim().data, sim().ephemeris, here, choice["to"], t)
	if plan.is_empty() or not plan["ok"]:
		npc["next_t"] = t + 6.0 * HOUR
		return
	var s = sim().state
	for good in choice["buy"]:
		s.markets[here][good] -= float(choice["buy"][good])
		npc["ship"]["cargo"][good] = float(choice["buy"][good])
	npc["ship"]["fuel_t"] = maxf(0.0, float(npc["ship"]["fuel_t"]) - float(plan["fuel_t"]))
	npc["location"] = {
		"status": "transit", "from": here, "to": choice["to"], "frame": plan["frame"],
		"depart_t": t, "arrive_t": plan["arrive_t"], "burn_s": plan["burn_s"],
		"from_pos": plan["from_pos"], "to_pos": plan["to_pos"], "distance_m": plan["distance_m"],
		"from_vel": plan["from_vel"], "to_vel": plan["to_vel"],
		"from_rot": plan.get("from_rot"), "to_rot": plan.get("to_rot"), "rot_axis": plan.get("rot_axis"), "rot_angle": plan.get("rot_angle", 0.0),
		"samples": plan.get("samples"), "around": plan.get("around"), "around_r": plan.get("around_r", 0.0), "avoid": plan.get("avoid"),
	}
	if plan.get("samples") == null:
		# Riding along with the ports either side of the burn (Navigation.port_tracks).
		var span := float(plan["arrive_t"]) - t
		var start := t + (span - float(plan["burn_s"])) * 0.5
		var tracks := Navigation.port_tracks(sim().ephemeris, here, choice["to"], plan["frame"], t, start, start + float(plan["burn_s"]), float(plan["arrive_t"]))
		npc["location"]["pre_track"] = tracks[0]
		npc["location"]["post_track"] = tracks[1]
	npc["next_t"] = plan["arrive_t"]
	npc.erase("flyby")
	var fleet := _fleet(npc)
	if float(fleet.get("flyby_chance", 0.0)) > 0.0 and not _moon_anchored(here) and not _moon_anchored(choice["to"]):
		if _rng.randf() < float(fleet["flyby_chance"]):
			var alt_range: Array = fleet.get("flyby_alt_km", [100, 300])
			npc["flyby"] = {"alt": _rng.randf_range(float(alt_range[0]), float(alt_range[1])),
				"t": t + (float(plan["arrive_t"]) - t) * 0.45, "done": false}
			sim().emit("npc_flyby_plan", {"npc": npc["id"], "from": here, "to": choice["to"], "alt": npc["flyby"]["alt"]}, t)
	sim().emit("npc_departed", {"npc": npc["id"], "from": here, "to": choice["to"], "cargo": npc["ship"]["cargo"].duplicate(), "arrive_t": plan["arrive_t"]}, t)


## A sail voyage: no propellant, months long. Sunlight (and Clarke's beams at the
## start) push the sail round a slow spiral, so the path sweeps prograde about as far
## as orbits between the two radii would carry it, landing where the destination will
## be. A view-side path, Sun-centred, in the shape Navigation.plan returns.
func _sail_plan(here: String, to: String, t: float) -> Dictionary:
	var eph = sim().ephemeris
	var days: Array = _sailing.get("sail_days", [180, 220])
	var tof := _rng.randf_range(float(days[0]), float(days[1])) * DAY
	var a: Array = V.sub(eph.position(here, t), eph.position("sun", t))
	var b: Array = V.sub(eph.position(to, t + tof), eph.position("sun", t + tof))
	var ra := sqrt(a[0] * a[0] + a[1] * a[1])
	var rb := sqrt(b[0] * b[0] + b[1] * b[1])
	var tha := atan2(a[1], a[0])
	var mu := float(sim().data.bodies["sun"]["gm"])
	var natural := tof * 0.5 * (sqrt(mu / pow(ra, 3)) + sqrt(mu / pow(rb, 3)))
	var sweep := fposmod(atan2(b[1], b[0]) - tha, TAU)
	sweep += TAU * round((natural - sweep) / TAU)
	if sweep < 0.5:
		sweep += TAU
	var samples := []
	for k in 61:
		var f := float(k) / 60.0
		var shape := f * f * (3.0 - 2.0 * f)
		var r := lerpf(ra, rb, shape)
		var th := tha + sweep * f
		var dr := (rb - ra) * 6.0 * f * (1.0 - f) / tof
		var dth := sweep / tof
		var sun: Array = eph.position("sun", t + tof * f)
		samples.append([t + tof * f,
			V.add(sun, [r * cos(th), r * sin(th), lerpf(a[2], b[2], f)]),
			[dr * cos(th) - r * sin(th) * dth, dr * sin(th) + r * cos(th) * dth, (b[2] - a[2]) / tof],
			[0.0, 0.0, 0.0]])
	return {"ok": true, "frame": "sun", "fuel_t": 0.0, "arrive_t": t + tof, "burn_s": 0.0, "duration_s": tof,
		"from_pos": eph.position(here, t), "to_pos": eph.position(to, t + tof), "distance_m": V.distance(a, b),
		"from_vel": [0.0, 0.0, 0.0], "to_vel": [0.0, 0.0, 0.0], "samples": samples}


## A climb up or down a ribbon between a port and its foot town: straight, steady,
## as long as the line's ride, in the body's frame.
func _climb_plan(here: String, to: String, t: float) -> Dictionary:
	var data = sim().data
	var anchor: String = here if data.places[here].has("elevator") else data.places[here]["foot_of"]
	var line: Dictionary = data.places[anchor]["elevator"]
	var body: String = line["body"]
	var eph = sim().ephemeris
	var dur := float(line["hours"]) * 3600.0 * _rng.randf_range(1.0, 1.15)
	var a: Array = eph.relative(here, body, t)
	var b: Array = eph.relative(to, body, t + dur)
	var vel := V.scale(V.sub(b, a), 1.0 / dur)
	var samples := []
	for k in 11:
		var f := float(k) / 10.0
		samples.append([t + dur * f, V.lerp(a, b, f), vel, [0.0, 0.0, 0.0]])
	return {"ok": true, "frame": body, "fuel_t": 0.0, "arrive_t": t + dur, "burn_s": 0.0, "duration_s": dur,
		"from_pos": a, "to_pos": b, "distance_m": V.distance(a, b),
		"from_vel": [0.0, 0.0, 0.0], "to_vel": [0.0, 0.0, 0.0], "samples": samples}


## Route and shuttle fleets fly fixed legs. They work like supply contracts: they
## carry the listed goods only up to what the destination is short of, so they
## smooth shortages instead of dumping gluts that would invite backwards trades.
func _choose_leg(npc: Dictionary, here: String) -> Dictionary:
	var fleet := _fleet(npc)
	var route: Array = fleet["route"]
	var leg: Dictionary = route[int(npc["leg"]) % route.size()]
	if leg["at"] != here:
		# Off our route (for example after a save edit): head back to its first stop.
		return {"to": route[0]["at"], "buy": {}} if route[0]["at"] != here else {"to": route[0]["to"], "buy": {}}
	npc["leg"] = (int(npc["leg"]) + 1) % route.size()
	var buy := {}
	var goods: Array = leg.get("buy", [])
	if not goods.is_empty():
		var space := ShipStats.cargo_capacity_t(npc["ship"], sim().data) * float(fleet.get("fill", 1.0))
		for good in goods:
			if Market.trades(sim().data, leg["to"], good):
				var shortfall := Market.target(sim().data, leg["to"], good) - Market.stock(sim().state, leg["to"], good)
				var t := minf(minf(space / goods.size(), _available(here, good)), shortfall)
				if t >= 0.1:
					buy[good] = t
	return {"to": leg["to"], "buy": buy}


## Traders look at every route and good, then pick one of the few best (people and
## minds are not perfectly greedy, which keeps them from all piling onto one route).
func _choose_trade(npc: Dictionary, here: String, t: float) -> Dictionary:
	var data = sim().data
	var s = sim().state
	var capacity := ShipStats.cargo_capacity_t(npc["ship"], data)
	var options := []
	var long_haul: bool = _fleet(npc).get("interplanetary", false)
	for to in data.places:
		if to == here:
			continue
		# Traders keep to their own planet's neighbourhood unless the fleet runs long hauls.
		if not long_haul and Interplanetary.is_interplanetary(data, here, to):
			continue
		if not Perks.place_open(s, data, to):
			continue
		var plan := Navigation.plan(npc["ship"], data, sim().ephemeris, here, to, t)
		if not plan.get("ok", false) or plan["strand_risk"]:
			continue
		for good in data.places[here]["market"]:
			if not Market.trades(data, to, good):
				continue
			var tonnes := minf(capacity, _available(here, good))
			if tonnes < 0.5:
				continue
			var margin := Market.sell_price(s, data, to, good, tonnes) - Market.buy_price(s, data, here, good, tonnes)
			if margin < float(data.goods[good]["base_price"]) * float(data.npcs["trader_min_margin"]):
				continue
			options.append({"to": to, "buy": {good: tonnes}, "rate": margin * tonnes / float(plan["duration_s"])})
	if options.is_empty():
		var places: Array = data.places.keys()
		places.erase(here)
		return {"to": places[_rng.randi_range(0, places.size() - 1)], "buy": {}}
	options.sort_custom(func(a, b): return a["rate"] > b["rate"])
	var pool := mini(int(data.npcs["trader_choice_pool"]), options.size())
	return options[_rng.randi_range(0, pool - 1)]
