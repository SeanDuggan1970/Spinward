## The Warrant of Fitness over time (sim/fitness.gd): warns as it runs down, says so when it
## lapses, and gives a ship that has none (an old save, a new hull) its starting one.
## Inspections and refits are shipyard commands (shipyard_system.gd).
extends "res://sim/systems/system.gd"

const Fitness := preload("res://sim/fitness.gd")


func tick(_game_dt: float) -> void:
	var s = sim().state
	var data = sim().data
	if s.ship.is_empty():
		return
	if not s.ship.has("wof"):
		# An old save: grandfather the ship with a fresh certificate.
		s.ship["wof"] = {"valid_until_t": s.time_s + float(data.ship_economy["start"]["wof_days"]) * 86400.0, "result": "pass", "issues": [], "inspected_t": s.time_s}
	var st := Fitness.status(s, data)
	var last: String = String(s.ship.get("wof_seen", st["state"]))
	if st["state"] != last:
		s.ship["wof_seen"] = st["state"]
		if st["state"] == "expiring":
			sim().emit("wof_expiring", {"days_left": st["days_left"]})
		elif st["state"] in ["expired", "failed", "voided"]:
			sim().emit("wof_lapsed", {"state": st["state"]})
	s.ship["wof_seen"] = st["state"]
