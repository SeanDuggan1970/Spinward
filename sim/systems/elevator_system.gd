## Riding the space elevators (data/places.json "elevator" on the anchor port).
##
## Down: from the port to the town at the foot ("foot_of" the port), your cargo in a
## climber container and your ship left docked above. Up: back to the port and your
## ship. Out: past the anchor to the line's counterweight (its "counterweight" leg),
## where nobody goes but to have been; In: back to the anchor. Ships cannot fly to a
## foot or a counterweight (Perks.place_open), so the ribbon is the only way in. A
## line still being built ("project") takes no passengers. The fare is a seat plus so
## much a tonne for whatever is in your hold; the way back never turns anyone away for
## want of it (see blocked).
extends "res://sim/systems/system.gd"

const ShipStats := preload("res://sim/ship_stats.gd")


func setup(owner) -> void:
	super.setup(owner)
	owner.register("ride_elevator", _ride)


func tick(_game_dt: float) -> void:
	var s = sim().state
	if s.location.get("status") == "elevator" and s.time_s >= float(s.location["arrive_t"]):
		var to: String = s.location["to"]
		var down: bool = s.location["down"]
		var dir: String = s.location.get("dir", "down" if down else "up")
		s.time_scale = float(sim().data.balance["time"]["arrival_scale"])
		s.location = {"status": "docked", "place": to}
		sim().emit("elevator_arrived", {"place": to, "down": down, "dir": dir})


## Every ride from where you are docked: [{anchor, line (the leg: name, body, km, hours,
## fare, fare_per_t, via), to, dir, down}], dir "down" (to the foot), "out" (to the
## counterweight), "up" or "in" (back to the anchor); down: away from your ship. Empty
## if no ribbon here.
static func rides_here(data, place: String) -> Array:
	var p: Dictionary = data.places.get(place, {})
	if p.has("elevator"):
		var line: Dictionary = p["elevator"]
		var out := [{"anchor": place, "line": line, "to": line["foot"], "dir": "down", "down": true}]
		if line.has("counterweight"):
			out.append({"anchor": place, "line": _leg(line), "to": line["counterweight"]["place"], "dir": "out", "down": true})
		return out
	var anchor: String = p.get("foot_of", "")
	if anchor == "":
		return []
	var line: Dictionary = data.places[anchor]["elevator"]
	if p.get("counterweight", false):
		return [{"anchor": anchor, "line": _leg(line), "to": anchor, "dir": "in", "down": false}]
	return [{"anchor": anchor, "line": line, "to": anchor, "dir": "up", "down": false}]


## The counterweight leg as a line of its own (the line's name and body, the leg's numbers).
static func _leg(line: Dictionary) -> Dictionary:
	var leg: Dictionary = line["counterweight"].duplicate()
	leg["name"] = line["name"]
	leg["body"] = line["body"]
	if line.has("project"):
		leg["project"] = line["project"]
	return leg


## The ride from here to `to` ("" for the first: down, or back up/in).
static func ride_to(data, place: String, to: String = "") -> Dictionary:
	for r in rides_here(data, place):
		if to == "" or r["to"] == to:
			return r
	return {}


## The first ride from here (down from an anchor, back from a foot or counterweight).
static func line_here(data, place: String) -> Dictionary:
	return ride_to(data, place)


static func fare(data, state, place: String, to: String = "") -> float:
	var here := ride_to(data, place, to)
	if here.is_empty():
		return 0.0
	return float(here["line"]["fare"]) + float(here["line"]["fare_per_t"]) * ShipStats.cargo_t(state.ship)


## Why you can't ride from here to `to` now, or "" if you can.
static func blocked(data, state, place: String, to: String = "") -> String:
	var here := ride_to(data, place, to)
	if here.is_empty():
		return "there is no elevator here" if rides_here(data, place).is_empty() else "the ribbon doesn't go there"
	var line: Dictionary = here["line"]
	if line.has("project") and not state.projects.get(line["project"], {}).get("done", false):
		return "%s is still being built" % line["name"]
	# Only the way out from the anchor needs the fare in hand. Little at a foot or a
	# counterweight earns money, so a pilot who arrives with less than the fare would be
	# stuck there for good; the ride back goes on credit instead, as emergency fuel does.
	if here["dir"] in ["down", "out"] and state.credits < fare(data, state, place, to):
		return "the fare is %d cr" % int(ceil(fare(data, state, place, to)))
	return ""


## {to?}: ride from here to `to` (default: down from an anchor, back from the far end).
func _ride(command: Dictionary) -> String:
	var s = sim().state
	var data = sim().data
	if s.location.get("status") != "docked":
		return "not docked"
	var place: String = s.location["place"]
	var to: String = command.get("to", "")
	var why := blocked(data, s, place, to)
	if why != "":
		return why
	var here := ride_to(data, place, to)
	var paid := fare(data, s, place, to)
	s.credits -= paid
	var hours := float(here["line"]["hours"])
	s.location = {"status": "elevator", "from": place, "to": here["to"], "line": here["anchor"], "down": here["down"], "dir": here["dir"],
		"depart_t": s.time_s, "arrive_t": s.time_s + hours * 3600.0}
	sim().emit("elevator_departed", {"from": place, "to": here["to"], "line": here["anchor"], "fare": paid, "hours": hours, "dir": here["dir"]})
	return ""
