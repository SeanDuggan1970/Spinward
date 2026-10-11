## The paused station UI can retry a pickup after a sale, including old site saves.
extends SceneTree

const Sim := preload("res://sim/sim.gd")
const ShipStats := preload("res://sim/ship_stats.gd")
const SaveIO := preload("res://sim/save_io.gd")
const StationScreen := preload("res://view/station_screen.gd")
const UI := preload("res://view/ui/ui_kit.gd")

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
	var sim := Sim.new()
	sim.new_game(42)
	var s = sim.state
	var offer := {"id": 9601, "kind": "pickup", "client": "Terran Compact", "issued_at": "kibo_ring", "pickup": "clarke_exchange", "to": "kernel_l5",
		"item": "replacement parts", "mass_t": 1.0, "passengers": 0, "reward": 2000.0, "window_s": 30.0 * 86400.0, "expires_t": 1.0e20, "min_rep": 0.0, "rep": 2.0, "channel": "board", "hidden": false}
	s.contracts["board"]["kibo_ring"] = [offer]
	sim.apply({"type": "accept_contract", "id": 9601})
	s.ship["cargo"]["electronics"] = ShipStats.cargo_capacity_t(s.ship, sim.data)
	s.location = {"status": "approach", "place": "clarke_exchange"}
	sim.apply({"type": "dock"})
	sim.advance_game_time(1.0)
	s.paused = true
	var screen := StationScreen.new(sim)
	screen.theme = UI.make_theme()
	root.add_child(screen)
	screen._tab_index = 2
	screen.refresh()
	await process_frame
	var collect := collect_button(screen)
	check(collect != null and collect.disabled and collect.tooltip_text.begins_with("no room"), "A blocked pickup has a disabled Collect button with the reason")
	await capture("pickup-blocked")
	var sell_one: Button = null
	for button in screen._tabs.find_children("*", "Button", true, false):
		if button.text == "Sell 1" and not button.disabled:
			sell_one = button
			break
	check(sell_one != null, "The market offers Sell 1 for cargo aboard")
	if sell_one != null:
		sell_one.pressed.emit()
	check(is_equal_approx(float(s.ship["cargo"]["electronics"]), ShipStats.cargo_capacity_t(s.ship, sim.data) - 1.0), "Sell 1 frees exactly one tonne for the pickup")
	await process_frame
	collect = collect_button(screen)
	check(collect != null and not collect.disabled, "Selling cargo enables collection while paused")
	await capture("pickup-ready")
	if collect != null and not collect.disabled:
		collect.pressed.emit()
	check(s.contracts["active"][0]["state"] == "carried" and is_equal_approx(float(s.ship["parcels_t"]), 1.0), "The actual Collect button loads the consignment")
	check(collect_button(screen) == null, "The collection action disappears after boarding")
	await capture("pickup-collected")
	screen.free()
	# A previously blocked on-site save exposes the action on its site tab.
	s.contracts["active"][0]["state"] = "collect"
	s.contracts["active"][0]["pickup"] = "hermes_probe"
	s.ship["parcels_t"] = 0.0
	s.location = {"status": "on_site", "place": "hermes_probe"}
	s.contracts["last_site"] = "hermes_probe"
	sim.load_state(SaveIO.from_text(SaveIO.to_text(s)))
	sim.state.paused = true
	screen = StationScreen.new(sim)
	screen.theme = UI.make_theme()
	root.add_child(screen)
	await process_frame
	collect = collect_button(screen)
	check(collect != null and not collect.disabled and collect.is_visible_in_tree(), "An existing on-site save exposes Collect on the site tab")
	await capture("site-pickup-ready")
	if collect != null and not collect.disabled:
		collect.pressed.emit()
	check(sim.state.contracts["active"][0]["state"] == "carried", "Site pickups can be retried through the UI")
	screen.free()
	print("%d checks, %d failures (contract pickup view)" % [checks, failures])
	quit(1 if failures else 0)


func collect_button(screen) -> Button:
	for button in screen._tabs.find_children("*", "Button", true, false):
		if button.text == "Collect":
			return button
	return null


func capture(name: String) -> void:
	if shots == "":
		return
	DirAccess.make_dir_recursive_absolute(shots)
	await process_frame
	await process_frame
	# Hidden Windows viewports may skip redraws when the UI is otherwise idle.
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(shots + "/" + name + ".png")
	await process_frame
