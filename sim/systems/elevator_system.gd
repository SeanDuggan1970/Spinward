## Riding the space elevators (data/places.json "elevator" on the anchor port).
##
## Down: from the port to the town at the foot ("foot_of" the port), your cargo in a
## climber container and your ship left docked above. Up: back to the port and your
## ship. Ships cannot fly to a foot (Perks.place_open), so the ribbon is the only way
## in. A line still being built ("project") takes no passengers. The fare is a seat
## plus so much a tonne for whatever is in your hold; the way up never turns anyone away
## for want of it (see blocked).
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
		s.time_scale = float(sim().data.balance["time"]["arrival_scale"])
		s.location = {"status": "docked", "place": to}
		sim().emit("elevator_arrived", {"place": to, "down": down})


## The anchor port and its line for wherever you are docked, or {} if no ribbon here.
static func line_here(data, place: String) -> Dictionary:
	if data.places.get(place, {}).has("elevator"):
		var line: Dictionary = data.places[place]["elevator"]
		return {"anchor": place, "line": line, "to": line["foot"], "down": true}
	var anchor: String = data.places.get(place, {}).get("foot_of", "")
	if anchor != "":
		return {"anchor": anchor, "line": data.places[anchor]["elevator"], "to": anchor, "down": false}
	return {}


static func fare(data, state, place: String) -> float:
	var here := line_here(data, place)
	if here.is_empty():
		return 0.0
	return float(here["line"]["fare"]) + float(here["line"]["fare_per_t"]) * ShipStats.cargo_t(state.ship)


## Why you can't ride from here now, or "" if you can.
static func blocked(data, state, place: String) -> String:
	var here := line_here(data, place)
	if here.is_empty():
		return "there is no elevator here"
	var line: Dictionary = here["line"]
	if line.has("project") and not state.projects.get(line["project"], {}).get("done", false):
		return "%s is still being built" % line["name"]
	# Only the way down needs the fare in hand. Nothing at the foot earns money, so a pilot
	# who arrives with less than the fare would be stuck there for good; the ride up goes on
	# credit instead, as emergency fuel does.
	if here["down"] and state.credits < fare(data, state, place):
		return "the fare is %d cr" % int(ceil(fare(data, state, place)))
	return ""


func _ride(_command: Dictionary) -> String:
	var s = sim().state
	var data = sim().data
	if s.location.get("status") != "docked":
		return "not docked"
	var place: String = s.location["place"]
	var why := blocked(data, s, place)
	if why != "":
		return why
	var here := line_here(data, place)
	var paid := fare(data, s, place)
	s.credits -= paid
	var hours := float(here["line"]["hours"])
	s.location = {"status": "elevator", "from": place, "to": here["to"], "line": here["anchor"], "down": here["down"],
		"depart_t": s.time_s, "arrive_t": s.time_s + hours * 3600.0}
	sim().emit("elevator_departed", {"from": place, "to": here["to"], "line": here["anchor"], "fare": paid, "hours": hours})
	return ""
