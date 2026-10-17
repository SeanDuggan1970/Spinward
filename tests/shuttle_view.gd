## The shuttle flight view: down to every Mars base and back up, the shuttle and the
## chase camera stay above the ground, the plasma shows only in entry, and the
## departures screen offers each flight.
extends SceneTree

const Sim := preload("res://sim/sim.gd")
const ShuttleView := preload("res://view/shuttle_view.gd")
const StationScreen := preload("res://view/station_screen.gd")

var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	var sim := Sim.new()
	sim.new_game(42)
	for id in sim.state.projects:
		sim.state.projects[id]["done"] = true
	sim.state.credits = 1.0e6
	var bases: Array = sim.data.places["ares_ring"]["shuttle"]["stops"].keys()
	sim.state.location = {"status": "docked", "place": "ares_ring"}
	var screen = StationScreen.new(sim, [])
	root.add_child(screen)
	await process_frame
	var text := _all_text(screen._departures_tab("ares_ring"))
	for base in bases:
		check(text.contains(String(sim.data.places[base]["name"]).to_upper()), "Ares Ring's departures offer the flight to %s" % base)
	screen.free()
	for base in bases:
		for leg in [base, "ares_ring"]:
			if leg == base:
				sim.state.location = {"status": "docked", "place": "ares_ring"}
			var err: String = sim.apply({"type": "take_shuttle", "to": leg})
			check(err == "", "The shuttle flies to %s (%s)" % [leg, err])
			if err != "":
				continue
			var view = ShuttleView.new(sim)
			root.add_child(view)
			# Look keys aside (no bindings here), drive it by hand.
			view.set_process(false)
			await process_frame
			var loc: Dictionary = sim.state.location
			var radius := float(sim.data.bodies["mars"]["radius_m"])
			var centre := Vector3(0, -radius, 0)
			var low := INF
			var cam_low := INF
			var hot_ok := true
			for k in 401:
				sim.state.time_s = lerpf(float(loc["depart_t"]), float(loc["arrive_t"]), float(k) / 400.0)
				view._update()
				low = minf(low, (view._shuttle.position - centre).length() - radius)
				cam_low = minf(cam_low, (view.camera.global_position - centre).length() - radius)
				var p: Dictionary = ShuttleView.profile(loc["down"], float(loc["depart_t"]), float(loc["arrive_t"]), sim.state.time_s, view._orbit_m, view._orbit_v)
				if view._plasma.visible and p["phase"] != "Entry":
					hot_ok = false
			var way := "down to %s" % base if leg == base else "up from %s" % base
			check(low > 0.0, "Flying %s, the shuttle stays above the ground (lowest %.1f m)" % [way, low])
			check(cam_low > 0.0, "Flying %s, the camera stays above the ground" % way)
			check(hot_ok, "Flying %s, plasma only in entry" % way)
			view.free()
			sim.advance_game_time(float(loc["arrive_t"]) - sim.state.time_s + 1.0)
			check(sim.state.location == {"status": "docked", "place": leg}, "Arrived at %s" % leg)
	print("%d checks, %d failures (shuttle view)" % [checks, failures])
	quit(1 if failures else 0)


func _all_text(node: Node) -> String:
	var out := ""
	if node is Label:
		out += (node as Label).text + "\n"
	elif node is Button:
		out += (node as Button).text + "\n"
	for c in node.get_children():
		out += _all_text(c)
	return out
