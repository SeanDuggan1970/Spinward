## Proves a speed-up changed nothing: runs a fixed scripted game (new_game(42), a trade,
## a departure, days of advance_game_time, a service, a refit, an overhaul, player route
## plans) and prints a hash of state.to_dict() and the event list after each stage.
## Run it before and after a change and diff the "DET" lines:
##   godot --headless --path . --script res://tools/determinism_hash.gd | grep DET
extends SceneTree
const Sim := preload("res://sim/sim.gd")
const Condition := preload("res://sim/condition.gd")
func _h(sim, label: String) -> void:
	var d: Dictionary = sim.state.to_dict()
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(var_to_bytes(d))
	var ev: Array = sim.take_events()
	ctx.update(var_to_bytes(ev))
	print("DET %s %s npcs=%d ev=%d" % [label, ctx.finish().hex_encode().substr(0, 20), d["npcs"].size(), ev.size()])
func _initialize() -> void:
	var sim := Sim.new()
	sim.new_game(42)
	_h(sim, "new")
	sim.state.credits = 3.0e6
	print("DET buy ", sim.apply({"type": "buy", "good": "electronics", "tonnes": 1}))
	sim.advance_game_time(3600.0 * 5)
	print("DET dep ", sim.apply({"type": "depart", "to": "clarke_exchange"}))
	sim.advance_game_time(3600.0 * 5)
	_h(sim, "transit")
	sim.advance_game_time(3 * 86400.0)
	_h(sim, "d3")
	sim.state.location = {"status": "docked", "place": "kibo_ring"}
	sim.advance_game_time(60.0)
	Condition.set_condition(sim.state.ship, "drive.0", 0.3)
	print("DET svc ", sim.apply({"type": "service", "slot": "drive.0"}))
	print("DET refit ", sim.apply({"type": "install_module", "slot": "tank.0", "module": "tank_l"}))
	print("DET ovh ", sim.apply({"type": "overhaul", "slot": "radiator.0"}))
	_h(sim, "refit")
	sim.apply({"type": "set_time_scale", "scale": 1.0})
	print("DET dep2 ", sim.apply({"type": "depart", "to": "halo_depot"}))
	sim.advance_game_time(40 * 86400.0)
	_h(sim, "d40")
	sim.advance_game_time(200 * 86400.0)
	_h(sim, "d240")
	# Player-ship plans, local and interplanetary, for every pair from two ports.
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	var Nav := preload("res://sim/navigation.gd")
	var sh: Dictionary = sim.state.ship.duplicate(true)
	sh["fuel_t"] = 100.0
	for a in ["kibo_ring", "trojan_yards", "valhalla_station"]:
		for b in sim.data.places:
			if a == b:
				continue
			ctx.update(var_to_bytes(Nav.plan(sh, sim.data, sim.ephemeris, a, b, sim.state.time_s)))
	print("DET plans ", ctx.finish().hex_encode().substr(0, 20))
	sim.advance_game_time(400 * 86400.0)
	_h(sim, "d640")
	quit()
