## The ship's electrical bus (sim/power.gd): integrates the battery, holds the shed
## level and raises the events the cockpit and co-pilot talk about.
##
## state.power = {charge_kwh, shed, reactor}. A missing charge means a full battery
## (a new ship, or a save from before there was power).
## The "reactor" command lights the reactor on purpose ("on") or leaves it to the
## ship's phase ("auto"): in transit, on approach and while a site job runs it is lit;
## parked far from the Sun it is not, and the battery carries the hotel load.
extends "res://sim/systems/system.gd"

const Power := preload("res://sim/power.gd")
const ShipStats := preload("res://sim/ship_stats.gd")


func setup(owner) -> void:
	super.setup(owner)
	owner.register("reactor", _reactor)


func start_game() -> void:
	sim().state.power = {}


func tick(game_dt: float) -> void:
	var s = sim().state
	var snap: Dictionary = Power.now(s, sim().data, sim().ephemeris)
	var before := int(s.power.get("shed", 0))
	var was_flat := bool(s.power.get("flat", false))
	s.power["charge_kwh"] = Power.charge_after(snap, game_dt)
	s.power["shed"] = int(snap["shed"])
	s.power["flat"] = bool(snap["flat"])
	if int(snap["shed"]) != before:
		sim().emit("power_shed", {"level": int(snap["shed"]), "was": before, "frac": float(snap["frac"])})
	if snap["flat"] and not was_flat:
		sim().emit("power_flat", {})


## {mode: "auto" | "on"}
func _reactor(command: Dictionary) -> String:
	var s = sim().state
	var mode: String = command.get("mode", "")
	if mode not in ["auto", "on"]:
		return "reactor mode must be auto or on"
	if mode == "on" and ShipStats.reactor_kw(s.ship, sim().data) <= 0.0:
		return "no working reactor aboard"
	s.power["reactor"] = mode
	sim().emit("reactor_set", {"mode": mode})
	return ""
