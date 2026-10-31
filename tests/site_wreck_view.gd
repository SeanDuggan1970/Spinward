## Regression: on site at a derelict, the wreck must be on screen, in the window the
## site screen leaves open (not hidden behind its panels), and show the work going on.
extends SceneTree

const Sim := preload("res://sim/sim.gd")
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
	for site in ["ishikawa_maru", "hermes_probe"]:
		var sim := Sim.new()
		sim.new_game(42)
		if not site in sim.state.sites["known"]:
			sim.state.sites["known"].append(site)
		sim.state.location = {"status": "on_site", "place": site}
		var view: Node3D = load("res://view/site_view.gd").new(sim)
		root.add_child(view)
		var screen := StationScreen.new(sim)
		screen.theme = UI.make_theme()
		root.add_child(screen)
		for _i in 3:
			await process_frame
		var wreck: Node3D = view._wreck
		check(wreck != null, "%s: a wreck is built" % site)
		if wreck == null:
			continue
		var cam: Camera3D = view.camera
		var size := root.get_visible_rect().size
		check(not cam.is_position_behind(wreck.global_position), "%s: the wreck is in front of the camera" % site)
		var at := cam.unproject_position(wreck.global_position)
		# The window: between the tabs (2.2 shares) and the side panel (1 share).
		var tabs_end: float = screen._tabs.get_global_rect().end.x
		var side_start: float = screen._side.get_global_rect().position.x
		check(at.x > tabs_end and at.x < side_start, "%s: the wreck sits in the window (%.0f between %.0f and %.0f)" % [site, at.x, tabs_end, side_start])
		check(at.y > size.y * 0.2 and at.y < size.y * 0.85, "%s: the wreck is at a sensible height (%.0f of %.0f)" % [site, at.y, size.y])
		check(not view._spark.visible, "%s: no work light before work starts" % site)
		check(sim.apply({"type": "site_work", "activity": "salvage"}) == "", "%s: work begins" % site)
		await process_frame
		check(view._spark.visible, "%s: the work shows on the wreck" % site)
		check(String(sim.data.sites[site]["activities"]["salvage"].get("start_text", "")).contains("{copilot}"), "%s: the start text names the co-pilot" % site)
		view.queue_free()
		screen.queue_free()
		await process_frame
	print("%d checks, %d failed" % [checks, failures])
	quit(1 if failures > 0 else 0)
