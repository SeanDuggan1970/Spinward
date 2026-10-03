## Game clock, pause and time compression.
extends "res://sim/systems/system.gd"


func setup(owner) -> void:
	super.setup(owner)
	owner.register("set_time_scale", _set_time_scale)
	owner.register("set_paused", _set_paused)


func tick(real_dt: float) -> void:
	sim().state.time_s += real_dt * sim().state.time_scale


func _set_time_scale(command: Dictionary) -> String:
	var steps: Array = sim().data.balance["time"]["scales"]
	var scale := float(command.get("scale", 1.0))
	if not steps.has(scale):
		return "time scale not allowed: %s" % scale
	sim().state.time_scale = scale
	sim().emit("time_scale_changed", {"scale": scale})
	return ""


func _set_paused(command: Dictionary) -> String:
	sim().state.paused = bool(command.get("paused", true))
	sim().emit("paused_changed", {"paused": sim().state.paused})
	return ""
