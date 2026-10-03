## NPC traffic: fleets of ships that trade from the same markets as the player.
##
## Each NPC is docked (waiting until next_t) or in transit (arriving at next_t).
## Events are processed in time order, at the time they are due, so a long tick
## still lets each NPC make several decisions. Randomness comes from a generator
## whose state lives in GameState, so runs replay identically and saves stay exact.
extends "res://sim/systems/system.gd"

const Navigation := preload("res://sim/navigation.gd")
const Market := preload("res://sim/market.gd")
const ShipStats := preload("res://sim/ship_stats.gd")

const HOUR := 3600.0
const MAX_EVENTS_PER_TICK := 5000

var _rng := RandomNumberGenerator.new()


func start_game() -> void:
	var s = sim().state
	var data = sim().data
	_seed_rng()
	s.npcs = []
	for fleet_id in data.npcs["fleets"]:
		var fleet: Dictionary = data.npcs["fleets"][fleet_id]
		var names: Array = fleet["names"]
		for i in int(fleet["count"]):
			var hull: Dictionary = data.ships[fleet["hull"]]
			var ship := {"hull": fleet["hull"], "modules": hull["modules"].duplicate(), "cargo": {}, "fuel_t": 0.0}
			ship["fuel_t"] = ShipStats.fuel_capacity_t(ship, data)
			var leg := i % maxi(1, fleet.get("route", []).size())
			var home: String = fleet["route"][leg]["at"] if fleet.has("route") else fleet["homes"][i % fleet["homes"].size()]
			s.npcs.append({
				"id": "%s.%d" % [fleet_id, i],
				"fleet": fleet_id,
				"name": names[i % names.size()],
				"ship": ship,
				"location": {"status": "docked", "place": home},
				"next_t": s.time_s + _rng.randf_range(0.0, 24.0) * HOUR,
				"leg": leg,
				"trips": 0,
			})
	s.rng_state = _rng.state


func tick(_game_dt: float) -> void:
	var s = sim().state
	if s.npcs.is_empty():
		return
	_seed_rng()
	_rng.state = s.rng_state
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
	}
	npc["next_t"] = plan["arrive_t"]
	sim().emit("npc_departed", {"npc": npc["id"], "from": here, "to": choice["to"], "cargo": npc["ship"]["cargo"].duplicate(), "arrive_t": plan["arrive_t"]}, t)


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
	for to in data.places:
		if to == here:
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
