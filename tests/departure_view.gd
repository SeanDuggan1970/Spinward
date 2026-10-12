## Regression for the actual station departure view and its game-time panel rig.
extends SceneTree

const Sim := preload("res://sim/sim.gd")
const FollowView := preload("res://view/follow_view.gd")
const ShipRig := preload("res://view/flight/ship_rig.gd")
const SaveIO := preload("res://sim/save_io.gd")
const Navigation := preload("res://sim/navigation.gd")
const V := preload("res://sim/v3.gd")
const Traffic := preload("res://sim/traffic.gd")
const Pattern := preload("res://view/flight/pattern.gd")

var checks := 0
var failures := 0
var shots := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.trim_prefix("--shots=")
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	for place in ["kibo_ring", "kalpana_two"]:
		var sim := Sim.new()
		sim.new_game(42)
		sim.state.location = {"status": "docked", "place": place}
		check(sim.apply({"type": "depart", "to": "halo_depot"}) == "", "Depart " + place)
		var view := FollowView.new(sim)
		root.add_child(view)
		view.set_process(false)
		var t0: float = sim.state.location["depart_t"]
		var exit = view._departure
		var st: Dictionary = view._stations[place]["model"]
		check(exit.fits_bay and exit.clear_after_s > exit.opening_s, place + " waits for its bay doors and hull clearance")
		check(exit.lift(0.0) > 10.0 and is_zero_approx(exit.lift(exit.opening_s)), place + " starts in a cradle off the axis and is lifted to it while the doors open")
		for elapsed in [1.0, exit.opening_s + 1.0, exit.clear_after_s - 0.1]:
			sim.state.time_s = t0 + elapsed
			view._update_world(1.0 / 60.0)
			var local_ship: Transform3D = (st["node"] as Node3D).global_transform.affine_inverse() * view._ship.global_transform
			# In its cradle at first, off the axis; lifted to the centre line before it moves.
			check(absf(Vector2(local_ship.origin.x, local_ship.origin.y).length() - exit.lift(elapsed)) < 0.01, place + " is where the lift puts it (%.2f m off the axis, %.2f expected)" % [Vector2(local_ship.origin.x, local_ship.origin.y).length(), exit.lift(elapsed)])
			if elapsed >= exit.opening_s:
				check(Vector2(local_ship.origin.x, local_ship.origin.y).length() < 0.001, place + " is on the centre line before it backs out")
			check(view._ship.global_basis.x.dot((st["rotor"] as Node3D).global_basis.x) > 0.99999 and view._ship.global_basis.y.dot((st["rotor"] as Node3D).global_basis.y) > 0.99999, place + " matches the station spin, including negative RPM")
			check(is_equal_approx(float(view._rig["fold"]), 1.0) and not view._lit, place + " keeps panels in and the main drive off inside the exit corridor")
			if elapsed < exit.opening_s:
				check(is_equal_approx(exit.gap(elapsed), exit.start_gap), place + " holds position while doors open")
		check(exit.opening_s >= float(sim.data.balance["undock"]["doors_at_s"]) + float(sim.data.balance["bays"]["door_s"]), place + " waits for fully open doors before backing out")
		await capture(view, place + "-backing-out")
		sim.state.time_s = t0 + exit.clear_after_s
		view._update_world(1.0 / 60.0)
		var origin := (st["node"] as Node3D).to_local(view._ship.global_position)
		var envelope: float = view._length * 0.5 + view._radius
		check(origin.z - envelope > float(st["bay"]["z_mouth"]) + 3.0, place + " actual hull and panel turning envelope clears the bay before manoeuvring")
		check(is_equal_approx(float(st["bay"]["open"]), 1.0), place + " actual bay doors stay fully open until clear")
		sim.state.time_s = t0 + exit.clear_after_s + float(sim.data.balance["undock"]["roll_stop_s"]) * 0.5
		view._update_world(1.0 / 60.0)
		check(not view._lit and view._ship.basis.z.dot((view._undock["facing"] as Basis).z) > 0.99999, place + " preserves roll braking on the axis before turning for the burn")
		sim.state.time_s = t0 + exit.clear_after_s + 12.5
		view._update_world(1.0 / 60.0)
		check(is_equal_approx(float(view._rig["fold"]), 0.5), place + " panels half deployed after 12.5 game seconds")
		await capture(view, place + "-unfolding")
		sim.state.time_scale = 1000000.0
		sim.state.time_s = t0 + exit.clear_after_s + 3600.0
		view._update_world(1.0 / 60.0)
		check(is_zero_approx(float(view._rig["fold"])), place + " fast-forward finishes deployment in game time")
		await capture(view, place + "-deployed")
		sim.load_state(SaveIO.from_text(SaveIO.to_text(sim.state)))
		view.free()
		view = FollowView.new(sim)
		root.add_child(view)
		view.set_process(false)
		check(is_zero_approx(float(view._rig["fold"])), place + " a loaded trip starts with panels already deployed")
		view.free()
	var sim := Sim.new()
	sim.new_game(42)
	sim.state.location = {"status": "on_site", "place": "hermes_probe"}
	check(sim.apply({"type": "depart", "to": "farside_array"}) == "", "Depart Hermes-7")
	var view := FollowView.new(sim)
	root.add_child(view)
	view.set_process(false)
	check(not view._departure.station and is_zero_approx(float(view._rig["fold"])), "A site departure starts with deployed panels")
	check(view._stations.is_empty() or not view._stations.has("hermes_probe"), "A site departure has no bay exit")
	await capture(view, "hermes-deployed")
	view.free()
	sim.state.ship["stowed"] = true
	view = FollowView.new(sim)
	root.add_child(view)
	view.set_process(false)
	sim.state.time_s += 7200.0
	view._update_world(1.0 / 60.0)
	check(is_equal_approx(float(view._rig["fold"]), 1.0), "Manual stealth stow survives departure and elapsed game time")
	await capture(view, "hermes-stealth-stowed")
	sim.state.ship.erase("stowed")
	view._update_world(1.0 / 60.0)
	view._update_world(30.0)
	check(is_equal_approx(float(view._rig["fold"]), 1.0), "Paused game time does not advance panel motors")
	sim.state.time_s += 12.5
	view._update_world(1.0 / 60.0)
	check(is_equal_approx(float(view._rig["fold"]), 0.5), "Manual deployment also uses game seconds")
	sim.state.time_s += 3600.0
	view._update_world(1.0 / 60.0)
	check(is_zero_approx(float(view._rig["fold"])), "Manual deployment completes after fast-forward")
	# Preserve the pilot's chosen exception: the sim may deploy for engine cooling.
	var loc: Dictionary = sim.state.location
	var checked_cooling := false
	for i in range(1, 100):
		var t := lerpf(float(loc["depart_t"]), float(loc["arrive_t"]), float(i) / 100.0)
		if V.length(Navigation.transit_accel(loc, t)) <= 1e-6:
			continue
		sim.state.time_s = t
		sim.state.ship["stowed"] = true
		sim.advance_game_time(1.0)
		checked_cooling = not bool(sim.state.ship.get("stowed", false))
		break
	check(checked_cooling, "The co-pilot still deploys stealth panels for main-engine cooling")
	view.free()
	_held_for_traffic()
	print("%d checks, %d failures (departure view)" % [checks, failures])
	quit(1 if failures else 0)


func capture(view, name: String) -> void:
	if shots == "":
		return
	DirAccess.make_dir_recursive_absolute(shots)
	view.mode = "director"
	view.shot = "station" if view._departure.station else "orbit"
	view.shot_clock = 5.0
	view._update_camera(0.0)
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(shots + "/" + name + ".png")


## Leaving Kibo Ring with a local ship coming in: we wait in the cradle, it goes in
## through the doors, then ours open and we back out.
func _held_for_traffic() -> void:
	var sim := Sim.new()
	sim.new_game(42)
	var t0: float = sim.state.time_s + 3600.0
	var pick := {}
	for m in Traffic.movements(sim.state, sim.data, "kibo_ring", t0, t0 + 86400.0):
		if m.has("local") and m["kind"] == "in":
			pick = m
			break
	check(not pick.is_empty(), "A local ship comes in to Kibo Ring")
	sim.state.time_s = float(pick["t"]) + 10.0
	sim.state.location = {"status": "docked", "place": "kibo_ring"}
	check(sim.apply({"type": "depart", "to": "halo_depot"}) == "", "Depart Kibo Ring with a ship in the bay")
	var hold := float(sim.state.location.get("hold_s", 0.0))
	check(hold >= float(pick["end"]) - sim.state.time_s - 0.01, "Held %.0f s for it" % hold)
	var view := FollowView.new(sim)
	root.add_child(view)
	view.set_process(false)
	var exit = view._departure
	var depart := float(sim.state.location["depart_t"])
	check(is_equal_approx(exit.hold_s, hold) and exit.opening_s >= hold + float(sim.data.balance["bays"]["door_s"]), "The doors wait for the hold")
	check(is_equal_approx(exit.lift(hold), exit.lift(0.0)), "Still in the cradle when the hold ends")
	var saw := false
	var phase := ""
	var e := 0.0
	while e < hold:
		sim.state.time_s = depart + e
		view._update_world(1.0 / 60.0)
		if view._pattern != null and view._pattern.ships.has(Pattern.key(pick)):
			saw = true
		if e > 1.0 and phase == "":
			phase = String(view.readout.get("phase", ""))
		e += 1.0
	check(saw, "The ship we hold for goes past, into the bay")
	check(phase == "HOLDING FOR TRAFFIC", "The panel says why we wait (%s)" % phase)
	view.free()
