## Flying down to the surface by shuttle (data/places.json "shuttle" on the up-port).
##
## Down: from the port to one of the bases it serves (its "stops", each a place that is
## "foot_of" the port), your hold in the shuttle's cargo bay and your ship left docked
## above. Up: back to the port and your ship. Ships cannot land at a base
## (Perks.place_open), so the shuttle is the way in, as a ribbon is to its town. A base
## built by a project ("opens_with") takes nobody until it is finished. The fare is a
## seat plus so much a tonne for what you carry, and the shuttle lifts at most "max_t";
## the way back never turns anyone away for want of the fare (see blocked).
extends "res://sim/systems/system.gd"

const ShipStats := preload("res://sim/ship_stats.gd")


func setup(owner) -> void:
	super.setup(owner)
	owner.register("take_shuttle", _fly)


func tick(_game_dt: float) -> void:
	var s = sim().state
	if s.location.get("status") == "shuttle" and s.time_s >= float(s.location["arrive_t"]):
		var to: String = s.location["to"]
		var down: bool = s.location["down"]
		s.time_scale = float(sim().data.balance["time"]["arrival_scale"])
		s.location = {"status": "docked", "place": to}
		sim().emit("shuttle_arrived", {"place": to, "down": down})


## The port whose shuttle serves `place` (the port itself if it has one), or "".
static func port_of(data, place: String) -> String:
	var p: Dictionary = data.places.get(place, {})
	if p.has("shuttle"):
		return place
	var port: String = p.get("foot_of", "")
	if port != "" and data.places[port].get("shuttle", {}).get("stops", {}).has(place):
		return port
	return ""


## Every flight from where you are docked: [{port, line (the shuttle: name, body, max_t),
## stop (that base's hours, fare, fare_per_t, via), to, down}]. From the port, one down to
## each base; from a base, one back up. Empty if no shuttle calls here.
static func flights_here(data, place: String) -> Array:
	var port := port_of(data, place)
	if port == "":
		return []
	var line: Dictionary = data.places[port]["shuttle"]
	if port == place:
		var out := []
		for base in line["stops"]:
			out.append({"port": port, "line": line, "stop": line["stops"][base], "to": base, "down": true})
		return out
	return [{"port": port, "line": line, "stop": line["stops"][place], "to": port, "down": false}]


## The flight from here to `to` ("" for the first: the first base, or back up).
static func flight_to(data, place: String, to: String = "") -> Dictionary:
	for f in flights_here(data, place):
		if to == "" or f["to"] == to:
			return f
	return {}


static func fare(data, state, place: String, to: String = "") -> float:
	var f := flight_to(data, place, to)
	if f.is_empty():
		return 0.0
	return float(f["stop"]["fare"]) + float(f["stop"]["fare_per_t"]) * ShipStats.cargo_t(state.ship)


## Why you can't fly from here to `to` now, or "" if you can.
static func blocked(data, state, place: String, to: String = "") -> String:
	var f := flight_to(data, place, to)
	if f.is_empty():
		return "no shuttle calls here" if flights_here(data, place).is_empty() else "the shuttle doesn't go there"
	var base: String = f["to"] if f["down"] else place
	var builder: String = data.places[base].get("opens_with", "")
	if f["down"] and builder != "" and not state.projects.get(builder, {}).get("done", false):
		return "%s is still being built" % data.places[base]["name"]
	var max_t := float(f["line"].get("max_t", 0.0))
	if f["down"] and max_t > 0.0 and ShipStats.cargo_t(state.ship) > max_t + 1e-6:
		return "the shuttle lifts at most %d t" % int(max_t)
	# Only the way down needs the fare in hand: a pilot who lands with less than the
	# fare back would be stuck on the surface, so the flight up goes on credit instead,
	# as emergency fuel does. Nor is anyone left below for carrying too much.
	if f["down"] and state.credits < fare(data, state, place, to):
		return "the fare is %d cr" % int(ceil(fare(data, state, place, to)))
	return ""


## {to?}: fly from here to `to` (default: the first base from the port, back up from a base).
func _fly(command: Dictionary) -> String:
	var s = sim().state
	var data = sim().data
	if s.location.get("status") != "docked":
		return "not docked"
	var place: String = s.location["place"]
	var to: String = command.get("to", "")
	var why := blocked(data, s, place, to)
	if why != "":
		return why
	var f := flight_to(data, place, to)
	var paid := fare(data, s, place, to)
	s.credits -= paid
	var hours := float(f["stop"]["hours"])
	s.location = {"status": "shuttle", "from": place, "to": f["to"], "line": f["port"], "down": f["down"],
		"depart_t": s.time_s, "arrive_t": s.time_s + hours * 3600.0}
	sim().emit("shuttle_departed", {"from": place, "to": f["to"], "line": f["port"], "fare": paid, "hours": hours, "down": f["down"]})
	return ""
