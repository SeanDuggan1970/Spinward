## Departure, transit under time compression, arrival and docking.
extends "res://sim/systems/system.gd"

const Navigation := preload("res://sim/navigation.gd")


func setup(owner) -> void:
	super.setup(owner)
	owner.register("depart", _depart)
	owner.register("dock", _dock)


func start_game() -> void:
	sim().state.location = {"status": "docked", "place": sim().data.balance["start"]["place"]}


func tick(_game_dt: float) -> void:
	var s = sim().state
	if s.location.get("status") == "transit" and s.time_s >= float(s.location["arrive_t"]):
		var place: String = s.location["to"]
		s.location = {"status": "approach", "place": place}
		s.stats["trips"] += 1
		s.time_scale = float(sim().data.balance["time"]["arrival_scale"])
		sim().emit("arrived", {"place": place})


func _depart(command: Dictionary) -> String:
	var s = sim().state
	if s.location.get("status") != "docked":
		return "not docked"
	var to: String = command.get("to", "")
	if not sim().data.places.has(to):
		return "unknown destination"
	var here: String = s.location["place"]
	var route := Navigation.plan(s.ship, sim().data, sim().ephemeris, here, to, s.time_s)
	if not route["ok"]:
		return route["reason"]
	s.ship["fuel_t"] = maxf(0.0, float(s.ship["fuel_t"]) - float(route["fuel_t"]))
	s.location = {
		"status": "transit", "from": here, "to": to, "frame": route["frame"],
		"depart_t": s.time_s, "arrive_t": route["arrive_t"], "burn_s": route["burn_s"],
		"from_pos": route["from_pos"], "to_pos": route["to_pos"], "distance_m": route["distance_m"],
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
	if not manual:
		var fee := float(sim().data.balance["docking"]["auto_dock_fee"])
		if s.credits < fee:
			return "cannot afford the %d credit docking fee" % int(fee)
		s.credits -= fee
	s.stats["manual_docks" if manual else "auto_docks"] += 1
	var place: String = s.location["place"]
	s.location = {"status": "docked", "place": place}
	sim().emit("docked", {"place": place, "manual": manual})
	return ""
