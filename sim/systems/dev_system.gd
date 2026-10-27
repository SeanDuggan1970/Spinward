## Developer shortcuts for trying a feature without playing up to it (view/main.gd
## --start and --credits). Never used by the game itself: a normal game only reaches
## these commands from the command line.
extends "res://sim/systems/system.gd"


func setup(owner) -> void:
	super.setup(owner)
	owner.register("dev_place", _place)
	owner.register("dev_credits", _credits)


## {place, approach: bool}: put the ship at a place, docked (on site at a site), or on
## its final approach when approach is set.
func _place(command: Dictionary) -> String:
	var s = sim().state
	var place: String = command.get("place", "")
	if not sim().data.locations.has(place):
		return "unknown place: " + place
	if sim().data.sites.has(place):
		s.location = {"status": "on_site", "place": place}
	elif bool(command.get("approach", false)):
		if sim().data.places[place].has("foot_of"):
			return "no approach to %s: it is reached by elevator" % place
		s.location = {"status": "approach", "place": place}
	else:
		s.location = {"status": "docked", "place": place}
	return ""


## {credits}: set the balance.
func _credits(command: Dictionary) -> String:
	sim().state.credits = float(command.get("credits", 0.0))
	return ""
