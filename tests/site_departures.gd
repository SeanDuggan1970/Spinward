## Regression: exploration sites must offer a way back to a port, including after
## recovering Hermes-7's recorder and after loading an on-site save.
extends SceneTree

const Sim := preload("res://sim/sim.gd")
const SaveIO := preload("res://sim/save_io.gd")
const StationScreen := preload("res://view/station_screen.gd")
const UI := preload("res://view/ui/ui_kit.gd")

var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	var sim := Sim.new()
	sim.new_game(42)
	sim.state.sites["known"].append("hermes_probe")
	sim.state.location = {"status": "on_site", "place": "hermes_probe"}
	check(sim.apply({"type": "site_work", "activity": "salvage"}) == "", "Investigate Hermes-7")
	sim.advance_game_time(86400.0)
	check(sim.state.sites["work"].is_empty() and "salvage" in sim.state.sites["worked"].get("hermes_probe", []), "Hermes-7 investigation completes")
	sim.load_state(SaveIO.from_text(SaveIO.to_text(sim.state)))
	var screen := StationScreen.new(sim)
	screen.theme = UI.make_theme()
	root.add_child(screen)
	await process_frame
	var departures := screen._tabs.get_node_or_null("Departures")
	check(departures != null, "Loaded Hermes-7 save has a Departures tab")
	if departures:
		check(not departures.find_children("*", "Button", true, false).is_empty(), "Hermes-7 offers return route plotting")
		var labels := departures.find_children("*", "Label", true, false)
		check(labels.any(func(label): return label.text == "Farside Array"), "Farside Array is a return destination")
		# Use the same plotting and departure callbacks as the UI, rather than jumping
		# the ship directly back to port as the story's sim-only tests do.
		screen._plot("hermes_probe", "farside_array")
		while not screen._plotting.is_empty():
			await process_frame
		var options: Array = sim.route_cache.get(sim.route_key("farside_array", screen._plan_t("farside_array")), [])
		var available := options.filter(func(option): return option["affordable"])
		check(not available.is_empty(), "A return route from Hermes-7 is affordable")
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--shots="):
				screen._tab_index = 1
				screen.refresh()
				for _i in 3:
					await process_frame
				var dir := arg.trim_prefix("--shots=")
				DirAccess.make_dir_recursive_absolute(dir)
				root.get_texture().get_image().save_png(dir + "/hermes-return-routes.png")
		if not available.is_empty():
			screen._depart("farside_array", available[0]["id"])
			check(sim.state.location.get("status") == "transit" and sim.state.location.get("to") == "farside_array", "Depart Hermes-7 for Farside Array through the UI")
	# The same screen is used for every site. Damage must not break its ship panel
	# or offer repairs that the sim only accepts while docked at a port.
	sim.state.ship["damage"] = {"keel": 0.6}
	for site in sim.data.sites:
		sim.state.location = {"status": "on_site", "place": site}
		screen.refresh()
		var tab := screen._tabs.get_node_or_null("Departures")
		check(tab != null and tab.find_children("*", "Button", true, false).any(func(button): return button.text == "Plot routes"), "%s offers return route plotting with a damaged ship" % site)
		check(not screen._side.find_children("*", "Button", true, false).any(func(button): return button.text.begins_with("Patch up") or button.text.begins_with("Repair")), "%s does not offer unavailable port repairs" % site)
	# Towns and counterweights still require riding back to the ship, not flying out.
	for place in sim.data.places:
		if not sim.data.places[place].has("foot_of"):
			continue
		sim.state.location = {"status": "docked", "place": place}
		screen.refresh()
		var tab := screen._tabs.get_node("Departures")
		check(not tab.find_children("*", "Button", true, false).any(func(button): return button.text == "Plot routes"), "%s still requires an elevator ride back" % place)
	screen.free()
	print("%d checks, %d failures (site departures)" % [checks, failures])
	quit(1 if failures > 0 else 0)
