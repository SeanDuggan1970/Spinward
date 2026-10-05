## Departure, transit under time compression, arrival and docking.
extends "res://sim/systems/system.gd"

const Navigation := preload("res://sim/navigation.gd")
const V := preload("res://sim/v3.gd")
const RoutePlanner := preload("res://sim/route_planner.gd")
const Perks := preload("res://sim/perks.gd")

const PERI_WARN_S := 2.0 * 3600.0
const PERI_CLOSE_S := 600.0
## A plotted route stays valid this long (game seconds) before it must be re-plotted.
const PLAN_VALID_S := 3600.0


func setup(owner) -> void:
	super.setup(owner)
	owner.register("depart", _depart)
	owner.register("dock", _dock)


func start_game() -> void:
	sim().state.location = {"status": "docked", "place": sim().data.balance["start"]["place"]}


func tick(_game_dt: float) -> void:
	var s = sim().state
	_flyby_moments(s)
	if s.location.get("status") == "transit" and s.time_s >= float(s.location["arrive_t"]):
		var place: String = s.location["to"]
		s.stats["trips"] += 1
		s.time_scale = float(sim().data.balance["time"]["arrival_scale"])
		if sim().data.sites.has(place):
			# No port, no docking: you match orbit and you are there.
			s.location = {"status": "on_site", "place": place}
			sim().emit("arrived_site", {"place": place})
		else:
			s.location = {"status": "approach", "place": place}
			sim().emit("arrived", {"place": place})


## Flyby drama: slow time for the run-in to periapsis, then for the pass itself,
## and give the pilot their time compression back afterwards.
func _flyby_moments(s) -> void:
	var loc: Dictionary = s.location
	if loc.get("status") != "transit" or float(loc.get("peri_t", -1.0)) < 0.0:
		return
	var peri := float(loc["peri_t"])
	# Catch up through every stage passed this tick (a long tick may cross several).
	for _i in 4:
		var stage := int(loc.get("peri_stage", 0))
		if stage == 0 and s.time_s >= peri - PERI_WARN_S:
			loc["peri_stage"] = 1
			loc["peri_prev_scale"] = s.time_scale
			s.time_scale = minf(s.time_scale, 100.0)
			sim().emit("periapsis_near", {"alt": loc["peri_alt"], "in_s": peri - s.time_s})
		elif stage == 1 and s.time_s >= peri - PERI_CLOSE_S:
			loc["peri_stage"] = 2
			s.time_scale = minf(s.time_scale, 10.0)
		elif stage == 2 and s.time_s >= peri:
			loc["peri_stage"] = 3
			sim().emit("periapsis", {"alt": loc["peri_alt"]})
		elif stage == 3 and s.time_s >= peri + PERI_CLOSE_S:
			loc["peri_stage"] = 4
			s.time_scale = maxf(s.time_scale, float(loc.get("peri_prev_scale", s.time_scale)))
		else:
			break


func _depart(command: Dictionary) -> String:
	var s = sim().state
	if not s.location.get("status") in ["docked", "on_site"]:
		return "not docked"
	if not s.sites.get("work", {}).is_empty():
		return "still at work here"
	var to: String = command.get("to", "")
	if not sim().data.locations.has(to):
		return "unknown destination"
	if sim().data.sites.has(to) and not to in s.sites.get("known", []):
		return "you don't know where that is"
	var here: String = s.location["place"]
	if sim().data.places.get(here, {}).has("foot_of"):
		return "your ship is up at %s: ride the ribbon back first" % sim().data.places[sim().data.places[here]["foot_of"]]["name"]
	if sim().data.locations[to].has("foot_of"):
		return "ships can't land at %s: ride the elevator down from %s" % [sim().data.locations[to]["name"], sim().data.places[sim().data.locations[to]["foot_of"]]["name"]]
	if not Perks.place_open(s, sim().data, to):
		return "%s is not open yet" % sim().data.locations[to]["name"]
	if command.has("route"):
		return _depart_route(here, to, String(command["route"]), float(command.get("plan_t", s.time_s)))
	var route := Navigation.plan(s.ship, sim().data, sim().ephemeris, here, to, s.time_s)
	if not route["ok"]:
		return route["reason"]
	s.ship["fuel_t"] = maxf(0.0, float(s.ship["fuel_t"]) - float(route["fuel_t"]))
	s.location = {
		"status": "transit", "from": here, "to": to, "frame": route["frame"],
		"depart_t": s.time_s, "arrive_t": route["arrive_t"], "burn_s": route["burn_s"],
		"from_pos": route["from_pos"], "to_pos": route["to_pos"], "distance_m": route["distance_m"],
		"from_vel": route["from_vel"], "to_vel": route["to_vel"],
		"from_rot": route.get("from_rot"), "to_rot": route.get("to_rot"), "rot_axis": route.get("rot_axis"), "rot_angle": route.get("rot_angle", 0.0),
		"samples": route.get("samples"),
	}
	sim().emit("departed", {"from": here, "to": to, "arrive_t": route["arrive_t"], "fuel_t": route["fuel_t"]})
	return ""


## {manual: true} after the player flies the approach; otherwise the co-pilot (or a
## station tug) brings the ship in for a fee.
func _dock(command: Dictionary) -> String:
	var s = sim().state
	if s.location.get("status") != "approach":
		return "not on approach"
	var manual := bool(command.get("manual", false))
	var on_credit := false
	if not manual:
		# The tug always comes; if you cannot pay, the fee goes on your account
		# (credits go negative) so a pilot can never be stuck outside a port.
		var fee := 0.0 if Perks.free_docking(s, s.location["place"]) else float(sim().data.balance["docking"]["auto_dock_fee"])
		on_credit = s.credits < fee
		s.credits -= fee
	s.stats["manual_docks" if manual else "auto_docks"] += 1
	var place: String = s.location["place"]
	s.location = {"status": "docked", "place": place}
	sim().emit("docked", {"place": place, "manual": manual, "on_credit": on_credit})
	return ""



## Depart on a planned route (express, economy, flyby...). Uses the options the view
## had planned if they match this exact moment, ship and destination; otherwise
## plans them now (deterministic, so replays and saves agree).
func _depart_route(here: String, to: String, route_id: String, plan_t: float) -> String:
	var s = sim().state
	var data = sim().data
	var eph = sim().ephemeris
	if s.time_s - plan_t > PLAN_VALID_S or plan_t > s.time_s + 1.0:
		return "that route plan is out of date: plot again"
	var key: String = sim().route_key(to, plan_t)
	var options: Array = sim().route_cache.get(key, [])
	if options.is_empty():
		options = plan_for(s.ship, data, eph, here, to, plan_t)
		sim().store_route_options(key, options)
	var opt := {}
	for o in options:
		if o["id"] == route_id:
			opt = o
	if opt.is_empty():
		return "no such route"
	if opt["samples"] == null:
		return _depart({"type": "depart", "to": to})
	if not opt["affordable"]:
		return "not enough propellant: need %.2f t, have %.2f t" % [opt["fuel_t"], s.ship["fuel_t"]]
	if not opt.get("life_ok", true):
		return "not enough life support for a trip that long"
	var samples: Array = opt["samples"]
	s.ship["fuel_t"] = maxf(0.0, float(s.ship["fuel_t"]) - float(opt["fuel_t"]))
	var arrive := float(opt["arrive_t"])
	var frame: String = opt.get("frame", "earth")
	s.location = {
		"status": "transit", "from": here, "to": to, "frame": frame,
		"depart_t": s.time_s, "arrive_t": arrive,
		"burn_s": float(samples[-1][0]) - float(samples[0][0]),
		"from_pos": eph.relative(here, frame, s.time_s), "to_pos": eph.relative(to, frame, arrive),
		"distance_m": V.distance(samples[0][1], samples[-1][1]),
		"samples": samples, "route": route_id, "route_label": opt["label"],
		"peri_t": float(opt["peri_t"]) if opt["kind"] == "flyby" else -1.0,
		"peri_alt": float(opt["peri_alt"]), "peri_stage": 0,
	}
	sim().emit("departed", {"from": here, "to": to, "arrive_t": arrive, "fuel_t": opt["fuel_t"], "route": opt["label"]})
	return ""



## The full route-options computation for a trip planned at time t (pure and
## deterministic; the view runs the same thing on a worker thread).
static func plan_for(ship: Dictionary, data, eph, here: String, to: String, t: float) -> Array:
	var quick := Navigation.plan(ship, data, eph, here, to, t)
	var job := RoutePlanner.prepare(ship, data, eph, here, to, t)
	job["hop"] = RoutePlanner.is_orbital_hop(data, eph, here, to, t)
	return RoutePlanner.options_or_quick(job, quick)
