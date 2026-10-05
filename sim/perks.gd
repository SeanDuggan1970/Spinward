## What backing a megaproject has earned the player (state.perks), and whether a place
## that opens with a project is open yet. Pure helpers for any system or the view.
##
## state.perks: {place: {free_docking: true, fuel_discount: f, yard_discount: f},
## "_earned": [{project, index}], "_promises": [text]}. Discounts apply only to what
## cannot be resold (fuel into the tanks, shipyard modules, docking), so they can
## never be turned into an arbitrage loop.
extends RefCounted


static func at(state, place: String, kind: String, default = 0.0):
	return state.perks.get(place, {}).get(kind, default)


static func free_docking(state, place: String) -> bool:
	return bool(at(state, place, "free_docking", false))


static func fuel_mult(state, place: String) -> float:
	return 1.0 - float(at(state, place, "fuel_discount", 0.0))


static func yard_mult(state, place: String) -> float:
	return 1.0 - float(at(state, place, "yard_discount", 0.0))


## Places built by a project ("opens_with") are closed until it is finished; places
## with "opens_after_days" open that many days into the game.
static func place_open(state, data, place: String) -> bool:
	var days := float(data.locations.get(place, {}).get("opens_after_days", 0.0))
	if days > 0.0 and state.time_s - float(state.started_t) < days * 86400.0:
		return false
	var builder: String = data.locations.get(place, {}).get("opens_with", "")
	if builder == "":
		return true
	return bool(state.projects.get(builder, {}).get("done", false))
