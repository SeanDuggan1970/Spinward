## The shuttle flight view: down to every base of every shuttle line (the Mars bases,
## the hop across the Moon) and back up. The shuttle and the chase camera stay above
## the ground, the plasma shows only in entry and only where there is air, and the
## departures screen offers each flight. The lunar hop flies a real ballistic arc.
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
	# Every shuttle line in the data: Ares Ring's to the Mars bases, and the hopper
	# across the Moon from Line Foot.
	var ports: Array = sim.data.places.keys().filter(func(p): return sim.data.places[p].has("shuttle"))
	check(ports.has("ares_ring") and ports.has("line_foot"), "Ares Ring and Line Foot run shuttles")
	for port in ports:
		await _fly_line(sim, port)
	_hop_physics(sim)
	print("%d checks, %d failures (shuttle view)" % [checks, failures])
	quit(1 if failures else 0)


func _fly_line(sim: Sim, port: String) -> void:
	var line: Dictionary = sim.data.places[port]["shuttle"]
	var bases: Array = line["stops"].keys()
	var body: String = line["body"]
	var air: bool = sim.data.bodies[body].get("look", {}).has("atmosphere")
	sim.state.location = {"status": "docked", "place": port}
	var screen = StationScreen.new(sim, [])
	root.add_child(screen)
	await process_frame
	var tab: Control = screen._departures_tab(port)
	var text := _all_text(tab)
	tab.free()
	for base in bases:
		check(text.contains(String(sim.data.places[base]["name"]).to_upper()), "%s's departures offer the flight to %s" % [port, base])
	screen.free()
	for base in bases:
		for leg in [base, port]:
			if leg == base:
				sim.state.location = {"status": "docked", "place": port}
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
			var radius := float(sim.data.bodies[body]["radius_m"])
			var centre := Vector3(0, -radius, 0)
			var low := INF
			var cam_low := INF
			var hot_ok := true
			var lit := false
			for k in 401:
				sim.state.time_s = lerpf(float(loc["depart_t"]), float(loc["arrive_t"]), float(k) / 400.0)
				view._update()
				low = minf(low, (view._shuttle.position - centre).length() - radius)
				cam_low = minf(cam_low, (view.camera.global_position - centre).length() - radius)
				var p: Dictionary = ShuttleView.profile(loc["down"], float(loc["depart_t"]), float(loc["arrive_t"]), sim.state.time_s, view._orbit_m, view._orbit_v, air)
				# Plasma needs air: in entry on a world with it, never on one without.
				if view._plasma.visible and (not air or p["phase"] != "Entry"):
					hot_ok = false
				for jet in view._retros:
					lit = lit or jet.visible
			var way := "%s %s" % ["down to" if leg == base else "up from", base]
			check(low > 0.0, "Flying %s, the shuttle stays above the ground (lowest %.1f m)" % [way, low])
			check(cam_low > 0.0, "Flying %s, the camera stays above the ground" % way)
			check(hot_ok, "Flying %s, plasma only in entry, and only where there is air" % way)
			check(lit, "Flying %s, the engines fire" % way)
			check(air == (view._engine == null), "Flying %s, a winged shuttle where there is air, a lander where there isn't" % way)
			view.free()
			sim.advance_game_time(float(loc["arrive_t"]) - sim.state.time_s + 1.0)
			check(sim.state.location == {"status": "docked", "place": leg}, "Arrived at %s" % leg)


## The hop across the Moon follows a real ballistic arc: the minimum-energy launch for
## its range, half an hour's coast, its apex mid-flight, and on the ground at each end.
func _hop_physics(sim: Sim) -> void:
	var moon: Dictionary = sim.data.bodies["moon"]
	var hop := ShuttleView.hop_geometry(float(moon["gm"]), float(moon["radius_m"]), deg_to_rad(57.89))
	check(absf(float(hop["v0"]) - 1357.0) < 5.0, "A 1,755 km lunar hop launches at about 1,357 m/s (%.0f)" % float(hop["v0"]))
	check(absf(float(hop["tof"]) / 60.0 - 31.2) < 0.3, "and coasts for about 31 minutes (%.1f)" % (float(hop["tof"]) / 60.0))
	check(absf(float(hop["apex_m"]) / 1000.0 - 312.0) < 3.0, "through an apex about 312 km up (%.0f)" % (float(hop["apex_m"]) / 1000.0))
	var tof: float = hop["tof"]
	var mid := ShuttleView.hop_at(hop, tof * 0.5)
	check(absf(float(mid["h"]) - float(hop["apex_m"])) < 500.0, "Halfway through the hop it is at the apex")
	check(absf(float(mid["travelled"]) - float(hop["angle"]) * float(moon["radius_m"]) * 0.5) < 2000.0, "and halfway along the ground")
	check(float(ShuttleView.hop_at(hop, 0.0)["h"]) < 1.0 and float(ShuttleView.hop_at(hop, tof)["h"]) < 1.0, "It lifts off from and lands on the ground")
	var rising := true
	var last := -1.0
	for k in 50:
		var h := float(ShuttleView.hop_at(hop, tof * 0.5 * float(k) / 49.0)["h"])
		rising = rising and h >= last - 1e-6
		last = h
	check(rising, "It climbs all the way to the apex")


func _all_text(node: Node) -> String:
	var out := ""
	if node is Label:
		out += (node as Label).text + "\n"
	elif node is Button:
		out += (node as Button).text + "\n"
	for c in node.get_children():
		out += _all_text(c)
	return out
