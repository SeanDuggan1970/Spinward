## Base for sim systems. A system registers command handlers in setup() and
## advances its part of the state in tick(). It holds the sim weakly, because the
## sim owns its systems and a strong back-reference would never be freed.
extends RefCounted

var _sim: WeakRef


func setup(owner) -> void:
	_sim = weakref(owner)


func sim():
	return _sim.get_ref()


func tick(_real_dt: float) -> void:
	pass
