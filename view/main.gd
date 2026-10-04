## Game shell: owns the sim, ticks it, and shows the screen that matches where the
## ship is (docked → station, transit → map, approach → flight). Screens only send
## commands; this shell turns sim events into on-screen notices.
##
## Opens on the attract screen (view/title_screen.gd); the sim does not tick until
## the player starts. Keys: P pause, [ ] time compression, F5 quick save, F9 quick load.
## Command line (after --): --smoke runs an end-to-end headless check;
## --tour=<dir> captures one screenshot per screen (needs a window); --gallery=<dir>
## every approach; --flyby=<dir> a low lunar pass; --art=<dir> planet surfaces and ship liveries.
extends Control

const Sim := preload("res://sim/sim.gd")
const SaveIO := preload("res://sim/save_io.gd")
const UI := preload("res://view/ui/ui_kit.gd")
const StationScreen := preload("res://view/station_screen.gd")
const MapScreen := preload("res://view/map_screen.gd")
const FlightScene := preload("res://view/flight/flight_scene.gd")
const Comms := preload("res://view/comms.gd")
const TitleScreen := preload("res://view/title_screen.gd")
const TipsText := preload("res://view/tips_text.gd")
const Autopilot := preload("res://view/flight/autopilot.gd")
const COMMS_KEEP := 40

const QUICKSAVE := "user://quicksave.json"

var sim: Sim
var _mode := ""
var _screen: Node
var _top: Label
var _notices: VBoxContainer
var _layer: Control
var _ticker: Label
var _bar: Control
var _title: Node3D
## Rolling comms log (view-only), shared with the station's Traffic tab.
var comms: Array = []


func _ready() -> void:
	theme = UI.make_theme()
	sim = Sim.new()
	sim.new_game(1)
	_layer = Control.new()
	_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_layer)
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UI.box(Color("101215"), UI.HAZARD, 0, 8))
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	add_child(bar)
	_bar = bar
	_top = UI.label("")
	bar.add_child(_top)
	_ticker = UI.label("", UI.DIM, 12)
	_ticker.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_ticker.position = Vector2(16, -62)
	_ticker.size = Vector2(760, 54)
	_ticker.clip_text = true
	_ticker.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_ticker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ticker)
	_notices = VBoxContainer.new()
	_notices.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_notices.position = Vector2(-460, -200)
	_notices.custom_minimum_size = Vector2(440, 180)
	_notices.alignment = BoxContainer.ALIGNMENT_END
	_notices.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_notices)
	var args := OS.get_cmdline_user_args()
	if "--smoke" in args:
		_smoke.call_deferred()
		return
	if "--dock-trial" in args:
		_dock_trial.call_deferred()
		return
	for a in args:
		if a.begins_with("--art="):
			visible = false
			get_tree().root.add_child.call_deferred(load("res://view/art_gallery.gd").new(sim.data, a.trim_prefix("--art=")))
			return
		if a.begins_with("--voyage="):
			_voyage_tour.call_deferred(a.trim_prefix("--voyage="))
			return
		if a.begins_with("--flyby="):
			_flyby_tour.call_deferred(a.trim_prefix("--flyby="))
			return
		if a.begins_with("--gallery="):
			_gallery.call_deferred(a.trim_prefix("--gallery="))
			return
		if a.begins_with("--tour="):
			_tour.call_deferred(a.trim_prefix("--tour="))
			return
	show_title()


## The attract screen. The game shell's own UI is hidden and the sim is held.
func show_title() -> void:
	_title = TitleScreen.new(sim.data, FileAccess.file_exists(QUICKSAVE))
	_title.start_requested.connect(_on_start)
	_bar.visible = false
	_ticker.visible = false
	_layer.add_child(_title)


func _on_start(load_save: bool) -> void:
	if load_save:
		var loaded := SaveIO.load_file(QUICKSAVE)
		if loaded:
			sim.load_state(loaded)
	_title.queue_free()
	_title = null
	_bar.visible = true
	_ticker.visible = true
	_mode = ""
	_sync_mode()
	if load_save:
		notice("Loaded quick save.", UI.GOOD)


func _process(delta: float) -> void:
	if _title:
		return
	sim.tick(delta)
	_handle_events()
	_sync_mode()
	var s = sim.state
	var where := ""
	match s.location.get("status"):
		"docked":
			where = "Docked at " + sim.data.places[s.location["place"]]["name"]
		"transit":
			where = "En route to " + sim.data.places[s.location["to"]]["name"]
		"approach":
			where = "Approaching " + sim.data.places[s.location["place"]]["name"]
	_top.text = "SPINWARD   %s UTC   ×%d%s   %s   %s" % [
		s.date_string().replace("T", " ").substr(0, 16), int(s.time_scale), "  PAUSED" if s.paused else "",
		UI.money(s.credits), where]


func _handle_events() -> void:
	var refresh := false
	for e in sim.take_events():
		var d: Dictionary = e["data"]
		match e["type"]:
			"npc_departed", "npc_arrived", "npc_flyby_plan", "npc_flyby":
				var text := Comms.line(sim, e)
				if text != "":
					comms.append("%s  %s" % [_clock(e["time_s"]), text])
					if comms.size() > COMMS_KEEP:
						comms.pop_front()
					_ticker.text = "\n".join(comms.slice(maxi(0, comms.size() - 3)))
				var here: String = sim.state.location.get("place", "")
				refresh = refresh or here in [d.get("place"), d.get("from"), d.get("to")]
			"project_stage":
				var project: Dictionary = sim.data.projects[d["project"]]
				var place_name: String = sim.data.places[project["place"]]["name"]
				var share: float = d["player_share"]
				var line := "%s: %s, %s complete." % [place_name, project["name"], String(d["name"]).to_lower()]
				if share >= 0.05:
					line += " You hauled %d%% of it. Thank you." % int(round(share * 100.0))
				notice(line, UI.GOOD)
				comms.append("%s  %s" % [_clock(e["time_s"]), line])
				refresh = true
			"project_complete":
				var project: Dictionary = sim.data.projects[d["project"]]
				notice("%s is finished. The system just got a little bigger." % project["name"], UI.AMBER)
				comms.append("%s  NEWS  %s is complete." % [_clock(e["time_s"]), project["name"]])
				refresh = true
			"tip_bought":
				var tip := _tip_by_id(int(d["tip"]))
				if not tip.is_empty():
					notice("%s: %s" % [sim.data.brokers[d["broker"]]["name"], TipsText.line(sim, tip)], UI.AMBER)
				refresh = true
			"tip_verified":
				var name: String = sim.data.brokers[d["broker"]]["name"]
				notice("%s's tip %s (board says %d cr/t)." % [name, "held up" if d["held"] else "was wrong", int(d["actual"])], UI.GOOD if d["held"] else UI.WARN)
				refresh = true
			"rejected":
				notice(d["reason"].capitalize(), UI.WARN)
			"traded":
				var good: String = sim.data.goods[d["good"]]["name"]
				if d["credits"] < 0.0:
					notice("Bought %.1f t %s for %s" % [d["tonnes"], good, UI.money(-d["credits"])])
				else:
					notice("Sold %.1f t %s for %s  (profit %s)" % [d["tonnes"], good, UI.money(d["credits"]), UI.money(d["profit"])], UI.GOOD if d["profit"] >= 0.0 else UI.WARN)
				refresh = true
			"refuelled":
				if d.get("on_credit", false):
					notice("Tanker drone delivered %.2f t on credit. You owe %s." % [d["tonnes"], UI.money(-sim.state.credits)], UI.WARN)
				else:
					notice("Took on %.2f t propellant for %s" % [d["tonnes"], UI.money(-d["credits"])])
				refresh = true
			"module_installed":
				notice("Fitted %s" % sim.data.modules[d["module"]]["name"], UI.GOOD)
				refresh = true
			"departed":
				notice("Departed for %s%s" % [sim.data.places[d["to"]]["name"], (" via %s" % d["route"]) if d.has("route") else ""], UI.AMBER)
			"periapsis_near", "periapsis":
				var line := Comms.copilot(sim, "copilot_near" if e["type"] == "periapsis_near" else "copilot_pass", float(d["alt"]), float(d.get("in_s", 0.0)))
				notice(line, UI.AMBER)
				comms.append("%s  %s" % [_clock(e["time_s"]), line])
			"arrived":
				notice("Arrived at %s. Take her in, or press T for the tug." % sim.data.places[d["place"]]["name"], UI.AMBER)
			"docked":
				if d.get("on_credit", false):
					notice("The tug brought you in on credit. You owe %s; sell cargo to clear it." % UI.money(-sim.state.credits), UI.WARN)
				else:
					notice("Docked at %s%s" % [sim.data.places[d["place"]]["name"], "  (hand-flown, no fee)" if d["manual"] else ""], UI.GOOD)
	if refresh and _screen is StationScreen:
		_screen.refresh()


func _tip_by_id(id: int) -> Dictionary:
	for tip in sim.state.tips:
		if int(tip["id"]) == id:
			return tip
	return {}


func _clock(t: float) -> String:
	return Time.get_datetime_string_from_unix_time(int(t + 946728000.0)).substr(11, 5)


func notice(text: String, colour: Color = UI.TEXT) -> void:
	var l := UI.label(text, colour, 14)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_notices.add_child(l)
	while _notices.get_child_count() > 6:
		_notices.get_child(0).free()
	get_tree().create_timer(7.0).timeout.connect(func(): if is_instance_valid(l): l.queue_free())


func _sync_mode() -> void:
	var mode: String = sim.state.location.get("status", "docked")
	if mode == _mode:
		return
	_mode = mode
	if _screen:
		_screen.queue_free()
	match mode:
		"docked":
			_screen = StationScreen.new(sim, comms)
			_layer.add_child(_screen)
		"transit":
			_screen = MapScreen.new(sim)
			_layer.add_child(_screen)
		"approach":
			# 3D renders in the root viewport underneath all 2D; its HUD sits in this layer.
			_screen = FlightScene.new(sim)
			_layer.add_child(_screen)


func _unhandled_input(event: InputEvent) -> void:
	if _title or not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_P:
			sim.apply({"type": "set_paused", "paused": not sim.state.paused})
		KEY_BRACKETRIGHT, KEY_BRACKETLEFT:
			var scales: Array = sim.data.balance["time"]["scales"]
			var i := scales.find(sim.state.time_scale) + (1 if event.keycode == KEY_BRACKETRIGHT else -1)
			sim.apply({"type": "set_time_scale", "scale": scales[clampi(i, 0, scales.size() - 1)]})
		KEY_F5:
			notice("Saved." if SaveIO.save(sim.state, QUICKSAVE) == OK else "Save failed.", UI.GOOD)
		KEY_F9:
			var loaded := SaveIO.load_file(QUICKSAVE)
			if loaded:
				sim.load_state(loaded)
				_mode = ""
				notice("Loaded quick save.", UI.GOOD)
			else:
				notice("No quick save to load.", UI.WARN)


## Headless end-to-end check: every screen builds and the full loop runs.
func _smoke() -> void:
	_sync_mode()
	await get_tree().process_frame
	var ok := _screen is StationScreen
	ok = ok and sim.apply({"type": "buy", "good": "food", "tonnes": 5}) == ""
	ok = ok and sim.apply({"type": "depart", "to": "halo_depot"}) == ""
	_sync_mode()
	await get_tree().process_frame
	ok = ok and _screen is MapScreen
	sim.advance_game_time(float(sim.state.location["arrive_t"]) - sim.state.time_s + 1.0)
	_sync_mode()
	await get_tree().physics_frame
	await get_tree().physics_frame
	ok = ok and _screen is FlightScene and not (_screen as FlightScene).readout.is_empty()
	# Hands-off approach: aligned, creeping in at 0.8 m/s, co-pilot spin match on.
	# Proves the docking rules can be met by real flight, not just by the command.
	var flight: FlightScene = _screen
	# First too fast: the port must refuse capture.
	flight.ship_node.position = Vector3(0.0, 0.0, flight.station["port_z"] + 20.0 - flight.nose_z)
	flight.ship_node.rotation = Vector3.ZERO
	flight.velocity = Vector3(0, 0, -4.0)
	for _i in 60 * 10:
		flight._physics_process(1.0 / 60.0)
	ok = ok and not flight.docked and sim.state.location["status"] == "approach"
	print("SMOKE fast approach refused=%s contacts=%d" % [not flight.docked, flight.bumps])
	flight.bumps = 0
	flight.ship_node.position = Vector3(1.0, -0.5, flight.station["port_z"] + 30.0 - flight.nose_z)
	flight.ship_node.rotation = Vector3(0.0, 0.0, 1.0)
	flight.velocity = Vector3(0, 0, -0.8)
	for _i in 60 * 90:
		if flight.docked:
			break
		flight._physics_process(1.0 / 60.0)
	ok = ok and flight.docked and sim.state.stats["manual_docks"] == 1
	print("SMOKE flight docked=%s contacts=%d" % [flight.docked, flight.bumps])
	_sync_mode()
	await get_tree().process_frame
	ok = ok and _screen is StationScreen
	print("SMOKE_OK " if ok else "SMOKE_FAIL ", sim.state.date_string())
	get_tree().quit(0 if ok else 1)


## Headless: fly the autopilot from the real approach spawn at every station, using
## only player controls, and report how long docking takes. Proves approaches are
## flyable and measures how forgiving the tolerances are.
func _dock_trial() -> void:
	var all_ok := true
	for place in sim.data.places:
		sim.state.location = {"status": "approach", "place": place}
		_mode = ""
		_sync_mode()
		await get_tree().physics_frame
		var flight: FlightScene = _screen
		var steps := 0
		var limit := 60 * 900
		while not flight.docked and steps < limit:
			flight.control_override = Autopilot.controls(flight)
			flight._physics_process(1.0 / 60.0)
			steps += 1
		var ok := flight.docked
		all_ok = all_ok and ok
		print("DOCK_TRIAL %-16s docked=%s time=%5.0f s refusals=%d contacts=%d" % [place, ok, steps / 60.0, flight.refusals, flight.bumps])
		sim.state.location = {"status": "docked", "place": place}
	print("DOCK_TRIAL_OK" if all_ok else "DOCK_TRIAL_FAIL")
	get_tree().quit(0 if all_ok else 1)


## Windowed screenshot tour for visual checks: station, map, flight.
func _tour(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	show_title()
	for _i in 200:
		await get_tree().process_frame
	_shot(dir + "/0-title.png")
	for _i in 140:
		await get_tree().process_frame
	_shot(dir + "/0b-title.png")
	_on_start(false)
	_sync_mode()
	for _i in 10:
		await get_tree().process_frame
	_shot(dir + "/1-station.png")
	if _screen is StationScreen:
		_screen._tabs.current_tab = 1
	for _i in 5:
		await get_tree().process_frame
	_shot(dir + "/2-departures.png")
	# Plot gravity routes for one destination and capture the choice.
	_screen._plot("kibo_ring", "halo_depot")
	while not (_screen as StationScreen)._plotting.is_empty():
		await get_tree().process_frame
	for _i in 5:
		await get_tree().process_frame
	_shot(dir + "/2-routes.png")
	# Let a few hours pass in port so the comms channel and traffic board fill up.
	sim.advance_game_time(18.0 * 3600.0)
	_handle_events()
	if _screen is StationScreen:
		_screen._tab_index = 2
		_screen.refresh()
	for _i in 5:
		await get_tree().process_frame
	_shot(dir + "/2b-traffic.png")
	if _screen is StationScreen:
		_screen._tab_index = 3
		_screen.refresh()
	for _i in 5:
		await get_tree().process_frame
	_shot(dir + "/2c-projects.png")
	sim.apply({"type": "buy_tip", "broker": "maisie_tran"})
	sim.apply({"type": "buy_tip", "broker": "maisie_tran"})
	_handle_events()
	if _screen is StationScreen:
		_screen._tab_index = 4
		_screen.refresh()
	for _i in 5:
		await get_tree().process_frame
	_shot(dir + "/2d-tips.png")
	if _screen is StationScreen:
		_screen._tab_index = 1
		_screen.refresh()
	for _i in 5:
		await get_tree().process_frame
	_shot(dir + "/2e-departures-intel.png")
	sim.apply({"type": "depart", "to": "shackleton_port"})
	sim.apply({"type": "set_time_scale", "scale": 1000})
	_sync_mode()
	(_screen as MapScreen).set_view("cockpit")
	sim.advance_game_time((float(sim.state.location["arrive_t"]) - sim.state.time_s) * 0.4)
	for _i in 30:
		await get_tree().process_frame
	_shot(dir + "/3-transit-cockpit.png")
	# Past the midpoint the ship flips and brakes; give the turn a few seconds.
	sim.advance_game_time((float(sim.state.location["arrive_t"]) - sim.state.time_s) * 0.4)
	for _i in 300:
		await get_tree().process_frame
	_shot(dir + "/3b-transit-braking.png")
	# Telescope on the Moon: the awe shot.
	var tv = (_screen as MapScreen)._view
	if tv:
		var to_moon: Vector3 = tv.camera.global_transform.basis.inverse() * Vector3(tv.readout["moon_dir"])
		tv.look_yaw = atan2(-to_moon.x, -to_moon.z)
		tv.look_pitch = asin(clampf(to_moon.y, -1.0, 1.0))
		tv.telescope = true
		for _i in 90:
			await get_tree().process_frame
		_shot(dir + "/3d-transit-telescope.png")
	(_screen as MapScreen).set_view("map")
	for _i in 10:
		await get_tree().process_frame
	_shot(dir + "/3c-map.png")
	(_screen as MapScreen).set_view("orbit")
	for _i in 120:
		await get_tree().process_frame
	_shot(dir + "/3e-orbit.png")
	sim.advance_game_time(float(sim.state.location["arrive_t"]) - sim.state.time_s + 1.0)
	_sync_mode()
	for _i in 90:
		await get_tree().process_frame
	_shot(dir + "/4-flight.png")
	var flight: FlightScene = _screen
	print("TRAFFIC shown: ", flight._traffic.size(), " work craft: ", flight._work_craft.size())
	flight.ship_node.position = Vector3(3, 2, flight.station["port_z"] + 70.0 - flight.nose_z)
	flight.ship_node.rotation = Vector3.ZERO
	for _i in 30:
		await get_tree().process_frame
	_shot(dir + "/5-flight-close.png")
	flight.view_mode = "chase"
	for _i in 10:
		await get_tree().process_frame
	_shot(dir + "/6-flight-chase.png")
	get_tree().quit()


## Windowed: refit for the long haul (tanks in the cargo bays), plot Halo Depot to Ares
## Ring, depart on the Express route, and capture the orbit view, map and cockpit at
## the start, middle and end of the voyage, then the approach to Mars.
func _voyage_tour(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	const TravelSys := preload("res://sim/systems/travel_system.gd")
	var s = sim.state
	s.location = {"status": "docked", "place": "halo_depot"}
	for slot in ["cargo.0", "cargo.1", "tank.0"]:
		s.ship["modules"][slot] = "tank_m"
	s.ship["fuel_t"] = 18.0
	var t: float = s.time_s
	var options: Array = TravelSys.plan_for(s.ship, sim.data, sim.ephemeris, "halo_depot", "ares_ring", t)
	sim.store_route_options(sim.route_key("ares_ring", t), options)
	print("VOYAGE options: ", options.map(func(o): return "%s %.0f d %.1f t" % [o["id"], o["duration_s"] / 86400.0, o["fuel_t"]]))
	var err: String = sim.apply({"type": "depart", "to": "ares_ring", "route": options[0]["id"], "plan_t": t})
	if err != "":
		print("VOYAGE depart failed: ", err)
		get_tree().quit(1)
		return
	_sync_mode()
	var loc: Dictionary = s.location
	var span := float(loc["arrive_t"]) - float(loc["depart_t"])
	for stage in [["1-climb", 0.02], ["2-cruise", 0.5], ["3-arrive", 0.97]]:
		sim.advance_game_time(float(loc["depart_t"]) + span * float(stage[1]) - s.time_s)
		for v in ["orbit", "map", "cockpit"]:
			(_screen as MapScreen).set_view(v)
			for _i in 40:
				await get_tree().process_frame
			_shot("%s/%s-%s.png" % [dir, stage[0], v])
	sim.advance_game_time(float(loc["arrive_t"]) - s.time_s + 1.0)
	_sync_mode()
	for _i in 60:
		await get_tree().process_frame
	_shot(dir + "/4-approach.png")
	get_tree().quit()


## Windowed: plot Kibo Ring to Farside, take the lowest lunar flyby, and capture the
## run-in, the pass in the orbit view and from the cockpit, and the map.
func _flyby_tour(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	const TravelSys := preload("res://sim/systems/travel_system.gd")
	var t: float = sim.state.time_s
	var options: Array = TravelSys.plan_for(sim.state.ship, sim.data, sim.ephemeris, "kibo_ring", "farside_array", t)
	sim.store_route_options(sim.route_key("farside_array", t), options)
	var pick := {}
	for o in options:
		if o["kind"] == "flyby" and (pick.is_empty() or float(o["peri_alt"]) < float(pick["peri_alt"])):
			pick = o
	if pick.is_empty():
		print("FLYBY_TOUR no flyby route")
		get_tree().quit(1)
		return
	print("FLYBY_TOUR route %s, periapsis %.0f km" % [pick["label"], float(pick["peri_alt"]) / 1000.0])
	sim.apply({"type": "depart", "to": "farside_array", "route": pick["id"], "plan_t": t})
	sim.apply({"type": "set_time_scale", "scale": 100})
	_sync_mode()
	var peri: float = sim.state.location["peri_t"]
	var shots := [[peri - 3.0 * 3600.0, "orbit", "1-run-in"], [peri - 240.0, "orbit", "2-pass-orbit"], [peri - 60.0, "cockpit", "3-pass-cockpit"], [peri + 1800.0, "map", "4-map"]]
	for shot in shots:
		sim.advance_game_time(float(shot[0]) - sim.state.time_s)
		(_screen as MapScreen).set_view(shot[1])
		for _i in 90:
			await get_tree().process_frame
		_shot("%s/%s.png" % [dir, shot[2]])
	get_tree().quit()


## Windowed: an approach at every place, cockpit and wide shots, to check set pieces.
func _gallery(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	sim.advance_game_time(12.0 * 3600.0)
	for place in sim.data.places:
		sim.state.location = {"status": "approach", "place": place}
		_mode = ""
		_sync_mode()
		for _i in 60:
			await get_tree().process_frame
		(_screen as FlightScene).hud.show_keys = false
		await get_tree().process_frame
		_shot("%s/%s-cockpit.png" % [dir, place])
		(_screen as FlightScene).view_mode = "beauty"
		for _i in 20:
			await get_tree().process_frame
		_shot("%s/%s-wide.png" % [dir, place])
	# The same approaches once every megaproject is finished.
	for id in sim.data.projects:
		sim.state.projects[id]["done"] = true
		sim.state.projects[id]["stage"] = sim.data.projects[id]["stages"].size()
	for id in sim.data.projects:
		var place: String = sim.data.projects[id]["place"]
		sim.state.location = {"status": "approach", "place": place}
		_mode = ""
		_sync_mode()
		(_screen as FlightScene).hud.show_keys = false
		for _i in 60:
			await get_tree().process_frame
		_shot("%s/%s-finished.png" % [dir, place])
	get_tree().quit()


func _shot(path: String) -> void:
	get_viewport().get_texture().get_image().save_png(path)
	print("SHOT %s  (%d fps)" % [path, Engine.get_frames_per_second()])
