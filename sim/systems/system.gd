## Base for sim systems. A system registers command handlers in setup(), sets up
## its part of a fresh game in start_game(), and advances its state in tick().
## It holds the sim weakly, because the sim owns its systems and a strong
## back-reference would never be freed.
extends RefCounted

var _sim: WeakRef


func setup(owner) -> void:
	_sim = weakref(owner)


func sim():
	return _sim.get_ref()


func start_game() -> void:
	pass


## game_dt is game seconds, already scaled by time compression.
func tick(_game_dt: float) -> void:
	pass
