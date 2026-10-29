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
const ShipAudio := preload("res://view/audio/ship_audio.gd")
const Livery := preload("res://view/flight/livery.gd")
const Kit := preload("res://view/flight/kit.gd")
const Bindings := preload("res://view/bindings.gd")
const SleepOverlay := preload("res://view/sleep_overlay.gd")
const WakeDigest := preload("res://view/wake_digest.gd")
const SleepSystem := preload("res://sim/systems/sleep_system.gd")
const ShuttleSystem := preload("res://sim/systems/shuttle_system.gd")
const Spin := preload("res://sim/spin.gd")
const COMMS_KEEP := 40

const QUICKSAVE := "user://quicksave.json"

## A scripted shoot (tours, gallery, promo): approaches open in the cockpit with you at
## the controls, as they always were, unless a shot asks for the co-pilot.
## The overheard-chatter slot last heard (Comms.overheard_slot), -1 before the first.
var _heard_slot := -1
var scripted_flight := false
var sim: Sim
var _mode := ""
var _screen: Node
## A 3D scene behind the current screen (on site).
var _backdrop: Node3D
var _top: Label
var _notices: VBoxContainer
var _layer: Control
var _ticker: Label
var _controls: CanvasLayer
## Where you are: the station around you when docked, the wheels on a ribbon.
var _ambience: AudioStreamPlayer
var _cabin: AudioStreamPlayer
var _bar: Control
var _title: Node3D
## Rolling comms log (view-only), shared with the station's Traffic tab.
var comms: Array = []
## Hibernation: the dark screen while asleep, and what came in meanwhile for the digest.
var _sleep_overlay: Control
var _sleep_credits := 0.0
var _asleep_notices: Array = []
var _naming: Control


func _ready() -> void:
	theme = UI.make_theme()
	sim = Sim.new()
	sim.new_game(1)
	Bindings.install(sim.data.controls)
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
		# Fly the trial in another stock hull (e.g. the deep freighter, the biggest
		# ship a bay must take).
		if a.begins_with("--dock-trial="):
			var hull := a.trim_prefix("--dock-trial=")
			sim.state.ship["hull"] = hull
			sim.state.ship["modules"] = sim.data.ships[hull]["modules"].duplicate()
			_dock_trial.call_deferred()
			return
	for a in args:
		if a.begins_with("--art="):
			visible = false
			get_tree().root.add_child.call_deferred(load("res://view/art_gallery.gd").new(sim.data, a.trim_prefix("--art=")))
			return
		if a.begins_with("--title="):
			_title_tour.call_deferred(a.trim_prefix("--title="))
			return
		if a.begins_with("--landing="):
			_landing_tour.call_deferred(a.trim_prefix("--landing="))
			return
		if a.begins_with("--site="):
			_site_tour.call_deferred(a.trim_prefix("--site="))
			return
		if a.begins_with("--voyage="):
			_voyage_tour.call_deferred(a.trim_prefix("--voyage="))
			return
		if a.begins_with("--flyby="):
			_flyby_tour.call_deferred(a.trim_prefix("--flyby="))
			return
		if a.begins_with("--market="):
			_market_shot.call_deferred(a.trim_prefix("--market="))
			return
		if a.begins_with("--corridor="):
			_corridor_shots.call_deferred(a.trim_prefix("--corridor="))
			return
		if a.begins_with("--shipcam="):
			_shipcam_tour.call_deferred(a.trim_prefix("--shipcam="))
			return
		if a.begins_with("--promo-ship="):
			_promo_ship.call_deferred(a.trim_prefix("--promo-ship="), true)
			return
		if a.begins_with("--promo="):
			_promo.call_deferred(a.trim_prefix("--promo="))
			return
		if a.begins_with("--kestrel="):
			_kestrel_tour.call_deferred(a.trim_prefix("--kestrel="))
			return
		if a.begins_with("--crash="):
			_crash_tour.call_deferred(a.trim_prefix("--crash="))
			return
		if a.begins_with("--ride="):
			_ride_tour.call_deferred(a.trim_prefix("--ride="))
			return
		if a.begins_with("--gallery="):
			_gallery.call_deferred(a.trim_prefix("--gallery="))
			return
		if a.begins_with("--tour="):
			_tour.call_deferred(a.trim_prefix("--tour="))
			return
	if _dev_start(args):
		return
	show_title()


## Straight into a new game, skipping the title, for trying a feature without playing
## up to it: --start=<place> docks there (on site at a site), --start=<place>:approach
## puts the ship on its final approach, and --credits=<n> sets the balance.
## Returns false when neither flag is given.
func _dev_start(args: PackedStringArray) -> bool:
	var commands := []
	for a in args:
		if a.begins_with("--start="):
			var parts := a.trim_prefix("--start=").split(":")
			commands.append({"type": "dev_place", "place": parts[0], "approach": parts.size() > 1 and parts[1] == "approach"})
		elif a.begins_with("--credits="):
			commands.append({"type": "dev_credits", "credits": a.trim_prefix("--credits=").to_float()})
	if commands.is_empty():
		return false
	_bar.visible = true
	_ticker.visible = true
	for c in commands:
		var error := sim.apply(c)
		if error != "":
			push_warning("%s: %s (places: %s)" % [c["type"], error, ", ".join(sim.data.locations.keys())])
			notice("%s: %s" % [c["type"], error], UI.HAZARD)
	_mode = ""
	_sync_mode.call_deferred()
	return true


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
	_overhear()
	_sync_mode()
	if sim.asleep() and not is_instance_valid(_sleep_overlay):
		_sleep_overlay = SleepOverlay.new(sim)
		_on_top(_sleep_overlay)
		_hold_screens(true)
	var s = sim.state
	if _ambience and _ambience.playing:
		var duck := ShipAudio.duck_for(s.time_scale)
		_ambience.volume_db = move_toward(_ambience.volume_db, float(_ambience.get_meta("base_db", -12.0)) + duck, delta * 20.0)
		_cabin.volume_db = move_toward(_cabin.volume_db, -24.0 + duck * 0.5, delta * 20.0)
	var where := ""
	match s.location.get("status"):
		"docked":
			where = "Docked at " + sim.data.locations[s.location["place"]]["name"]
		"transit":
			where = "En route to " + sim.data.locations[s.location["to"]]["name"]
		"approach":
			where = "Approaching " + sim.data.locations[s.location["place"]]["name"]
		"on_site":
			where = "On site: " + sim.data.locations[s.location["place"]]["name"]
	_top.text = "SPINWARD   %s UTC   ×%d%s   %s   %s" % [
		s.date_string().replace("T", " ").substr(0, 16), int(s.time_scale), "  PAUSED" if s.paused else "",
		UI.money(s.credits), where]
	_place_overlays()


## A cockpit can ask for the comms log and notices to sit clear of its panel.
func _place_overlays() -> void:
	var slots := {}
	for n in get_tree().get_nodes_in_group("cockpit_overlay_slots"):
		if n.is_visible_in_tree():
			slots = n.overlay_slots()
			if not slots.is_empty():
				break
	var t: Rect2 = slots.get("ticker", Rect2(16, size.y - 62, 760, 54))
	var n: Rect2 = slots.get("notices", Rect2(size.x - 460, size.y - 200, 440, 180))
	if _ticker.position != t.position or _ticker.size != t.size:
		_ticker.position = t.position
		_ticker.size = t.size
	if _notices.position != n.position:
		_notices.position = n.position


func _handle_events() -> void:
	var refresh := false
	for e in sim.take_events():
		var d: Dictionary = e["data"]
		match e["type"]:
			"traffic_hold":
				var place_name: String = sim.data.places[d["place"]]["name"]
				var who := preload("res://view/flight/pattern.gd").describe(sim, d["place"], d["ahead"]) if not (d["ahead"] as Dictionary).is_empty() else "traffic"
				var going := "in" if d["ahead"].get("kind", "in") == "in" else "out"
				var line := ("%s Control: hold in your cradle, %d s. %s is cleared %s first." % [place_name, int(ceil(float(d["hold_s"]))), who.substr(0, 1).to_upper() + who.substr(1), going]) if d["control"] == "tower" \
					else ("%s traffic: %s called it first, coming %s. Holding in the cradle, %d s." % [place_name, who, going, int(ceil(float(d["hold_s"])))])
				_radio_line(line)
				notice(line, UI.AMBER)
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
				# The Spaceline carries the story; private projects get a quiet word.
				var project: Dictionary = sim.data.projects[d["project"]]
				if project.has("invite"):
					notice("%s is finished. The system just got a little bigger." % project["name"], UI.AMBER)
				refresh = true
			"news":
				var item: Dictionary = d["item"]
				var line := "SPACELINE  %s" % item["headline"]
				notice(line + ("  (see Projects)" if item.has("project") and item["kind"] == "project" else ""), UI.AMBER)
				comms.append("%s  %s" % [_clock(e["time_s"]), line])
				if comms.size() > COMMS_KEEP:
					comms.pop_front()
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
			"slept":
				_sleep_credits = sim.state.credits
				_asleep_notices.clear()
			"woke":
				_wake_up(d)
				refresh = true
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
			"impact":
				var bits := ["Impact at %.1f m/s: %s %s" % [d["speed"], d["module"], "wrecked" if d["amount"] >= 1.0 else "damaged (%d%%)" % int(round(d["amount"] * 100.0))]]
				if d["fuel_lost"] > 0.01:
					bits.append("%.2f t propellant vented" % d["fuel_lost"])
				var lost := 0.0
				for g in d["spilled"]:
					lost += float(d["spilled"][g])
				if lost > 0.01:
					bits.append("%.1f t cargo spilled" % lost)
				bits.append("keel %d%%" % int(round(d["integrity"] * 100.0)))
				notice(". ".join(bits) + ".", UI.WARN)
			"ship_lost":
				var cover := "Insurance (%s) pays %s, less the %s excess." % [sim.data.ship_economy["insurance"]["plans"][d["cover"]]["name"], UI.money(float(d["payout"])), UI.money(float(d["excess"]))] if d["cover"] != "" else "No working cover (%s): the Commons lends you a hull, %s on the books." % [d["reason"], UI.money(float(d["loan"]))]
				notice("The keel has failed. Abandon ship! The lifeboat is away; %s's tug is on its way. %s" % [sim.data.places[d["place"]]["name"], cover], UI.WARN)
			"rescued":
				notice("The tug brought the lifeboat into %s. There is a second-hand Mule waiting for you." % sim.data.places[d["place"]]["name"], UI.AMBER)
				refresh = true
			"wof_issued":
				notice("Warrant of Fitness issued: good for %d days." % int(sim.data.ship_economy["wof"]["valid_days"]), UI.GOOD)
				refresh = true
			"wof_failed":
				notice("Failed inspection. To fix: " + "; ".join(d["issues"]), UI.WARN)
				refresh = true
			"wof_expiring":
				notice("Your Warrant of Fitness runs out in %d days: get an inspection at a shipyard." % int(d["days_left"]), UI.AMBER)
			"wof_lapsed":
				notice("Your Warrant of Fitness is no longer valid: some ports charge extra, passenger jobs are refused and your insurance is void.", UI.WARN)
			"insurance_lapsed":
				notice("Your insurance has lapsed: renew it at any port.", UI.WARN)
			"insurance_void":
				notice("Your insurance is void without a valid Warrant of Fitness.", UI.WARN)
			"unfit_surcharge":
				notice("Traffic control charged %s extra: no valid Warrant of Fitness." % UI.money(-float(d["credits"])), UI.AMBER)
			"passengers_refused":
				notice("Traffic control would not clear your passengers without a Warrant of Fitness: they were put ashore.", UI.WARN)
			"module_fault":
				notice("Fault: %s on the %s (%d%% down) until it is serviced." % [d["text"], d["module"], int(round(float(d["loss"]) * 100.0))], UI.AMBER)
			"condition_low":
				notice("The %s is badly worn (%d%%): it wants servicing." % [d["module"], int(round(float(d["condition"]) * 100.0))], UI.AMBER)
			"yard_bill":
				refresh = true
			"repaired":
				notice(("Repaired at the yard for %s." if d["full"] else "Patched up for %s: a yard will do the rest.") % UI.money(-float(d["credits"])), UI.GOOD)
				refresh = true
			"elevator_departed":
				var line: Dictionary = sim.data.places[d["line"]]["elevator"]
				notice("On %s for %s: %s. Fare %s." % [line["name"], sim.data.places[d["to"]]["name"], UI.duration(float(d["hours"]) * 3600.0), UI.money(float(d["fare"]))], UI.AMBER)
			"shuttle_departed":
				var shuttle: Dictionary = sim.data.places[d["line"]]["shuttle"]
				notice("On %s %s %s: %s. Fare %s." % [shuttle["name"], ShuttleSystem.heading(sim.data, d["line"], d["down"]), sim.data.places[d["to"]]["name"], UI.duration(float(d["hours"]) * 3600.0), UI.money(float(d["fare"]))], UI.AMBER)
			"pod_fitted":
				notice("Fitted a %s to the lander." % String(sim.data.pods["pods"][d["pod"]]["name"]).to_lower(), UI.GOOD)
				refresh = true
			"pod_dropped":
				notice("Pod set down: a %s%s. It'll be here when you come back." % [String(sim.data.pods["pods"][d["pod"]]["name"]).to_lower(), (" with %.1f t aboard" % float(d["cargo_t"])) if float(d["cargo_t"]) > 0.0 else ((" with %.1f t of propellant" % float(d["fuel_t"])) if float(d["fuel_t"]) > 0.0 else "")], UI.AMBER)
				refresh = true
			"pod_picked_up":
				notice("Picked up the %s." % String(sim.data.pods["pods"][d["pod"]]["name"]).to_lower(), UI.GOOD)
				refresh = true
			"badge_earned":
				notice("Badge: %s. %s" % [d["name"], d["text"]], UI.GOOD)
				comms.append("%s  BADGE  %s: %s" % [_clock(e["time_s"]), d["name"], d["text"]])
				refresh = true
			"dark_running":
				notice(("Running dark: transponder and lights off. Burns still show for millions of km." if d["on"] else "Transponder and lights back on."), UI.AMBER if d["on"] else UI.DIM)
			"transponder_on":
				notice("Transponder on for the approach: ports don't dock a dark ship.", UI.DIM)
			"dark_running_fined":
				notice("%s saw us running dark in its control zone: fined %s, and %s won't forget it." % [sim.data.places[d["place"]]["name"], UI.money(-float(d["credits"])), d["operator"] if d["operator"] != "" else "they"], UI.WARN)
				refresh = true
			"seen":
				if bool(sim.state.detection.get("dark", false)):
					notice("%s has us on its sensors (%s)." % [sim.data.places[d["place"]]["name"], d["by"]], UI.WARN)
			"unseen":
				if bool(sim.state.detection.get("dark", false)) and sim.state.detection.get("seen_by", []).is_empty():
					notice("No port can see us now.", UI.GOOD)
			"panels_stowed":
				notice("Panels folding in: less to see, no solar power, and the radiators can't shed heat.", UI.AMBER)
			"panels_deployed":
				notice("Panels out for the burn: the radiators carry the drive's heat." if d["burn"] else "Panels unfolding.", UI.DIM)
			"satellite_released":
				notice(("%s is away, drifting clear and unfolding its panels. Nobody saw a thing." if d["covert"] else "%s is away near %s: panels unfolding, and it's calling home.") % ([String(d["name"]).capitalize()] if d["covert"] else [String(d["name"]).capitalize(), sim.data.locations[d["place"]]["name"]]), UI.GOOD)
				refresh = true
			"device_planted":
				notice("The device is away on a long, slow drift toward %s. In a week it will be listening." % sim.data.locations[d["place"]]["name"], UI.GOOD)
				refresh = true
			"covert_watched":
				notice("%s has us on its sensors with the job aboard. Get out of their sight." % d["watcher"], UI.WARN)
			"covert_lost_them":
				notice("No port can see us, and nobody knows our plan: %s has lost us." % d["watcher"], UI.GOOD)
			"covert_caught":
				notice("Caught: %s. Job lost, fined %s, and %s will remember.%s" % [d["how"], UI.money(-float(d["credits"])), d["watcher"], "  The ship is impounded until you pay the release fee." if d["impound"] else ""], UI.WARN)
				refresh = true
			"impound_paid":
				notice("Release fee paid (%s). She's yours again." % UI.money(-float(d["credits"])), UI.AMBER)
				refresh = true
			"ship_bought":
				notice("Bought the %s, a %s, for %s." % [d["ship"], sim.data.ships[d["hull"]]["name"].to_lower(), UI.money(-float(d["credits"]))], UI.GOOD)
				refresh = true
			"ship_switched":
				notice("You have the %s now. The %s waits in her berth at %s." % [d["ship"], d["from"], sim.data.places[d["place"]]["name"]], UI.GOOD)
				refresh = true
			"ship_sold":
				notice("Sold the %s for %s." % [d["ship"], UI.money(float(d["credits"]))], UI.AMBER)
				refresh = true
			"berth_rent":
				refresh = true
			"berth_unpaid":
				notice("Couldn't pay the %s's berth at %s: %s owed (%d month%s behind). The yard will sell her if it goes on." % [d["ship"], sim.data.places[d["place"]]["name"], UI.money(float(d["owed"])), int(d["months"]), "" if int(d["months"]) == 1 else "s"], UI.WARN)
			"ship_seized":
				notice("%s sold the %s for the berth rent owed (%s). They sent on the rest: %s." % [sim.data.places[d["place"]]["name"], d["ship"], UI.money(float(d["owed"])), UI.money(float(d["credits"]))], UI.WARN)
				refresh = true
			"unfiled_departure":
				if float(d["credits"]) < 0.0:
					notice("Left %s without filing a plan. Traffic control fined us %s%s." % [sim.data.places[d["place"]]["name"], UI.money(-float(d["credits"])), " and they're keeping count" if int(d["times"]) > 1 else ""], UI.WARN)
				else:
					notice("Away without a flight plan. Nobody knows where we're bound.", UI.AMBER)
			"hull_coated":
				notice("Hull coated, low-observable, for %s. She reflects a tenth of the light she did." % UI.money(-float(d["credits"])), UI.GOOD)
				refresh = true
			"round_bought":
				notice("A round for %d at %s: %s. Glasses go up." % [int(d["patrons"]), d["bar"], UI.money(-float(d["credits"]))], UI.AMBER)
				refresh = true
			"elevator_arrived":
				play_sfx("dock_clunk", -8.0)
				if d["down"]:
					notice("At %s. Your ship waits at %s." % [sim.data.places[d["place"]]["name"], sim.data.places[sim.data.home_port(d["place"])]["name"]], UI.GOOD)
				else:
					notice("Back at %s, and back aboard." % sim.data.places[d["place"]]["name"], UI.GOOD)
				refresh = true
			"shuttle_arrived":
				play_sfx("dock_clunk", -8.0)
				if d["down"]:
					notice("%s %s. Your ship waits at %s." % ["At" if ShuttleSystem.is_hop(sim.data, sim.data.places[d["place"]]["foot_of"]) else "Down at", sim.data.places[d["place"]]["name"], sim.data.places[sim.data.home_port(d["place"])]["name"]], UI.GOOD)
				elif sim.data.home_port(d["place"]) != d["place"]:
					notice("Back at %s. Your ship waits at %s." % [sim.data.places[d["place"]]["name"], sim.data.places[sim.data.home_port(d["place"])]["name"]], UI.GOOD)
				else:
					notice("Back at %s, and back aboard." % sim.data.places[d["place"]]["name"], UI.GOOD)
				refresh = true
			"npc_commissioned", "project_announced":
				# Reported by the Spaceline ("news").
				refresh = true
			"project_invite":
				var pi: Dictionary = sim.data.projects[d["project"]]
				notice("A private message from %s: you are invited to back %s. See Projects." % [d["operator"], pi["name"]], UI.AMBER)
				refresh = true
			"perk_earned":
				notice("Backer's reward from %s: %s." % [sim.data.projects[d["project"]]["name"], d["text"]], UI.GOOD)
				refresh = true
			"contract_accepted":
				notice("Job taken: %s due at %s. Pays %s." % ["collection" if d["pickup"] != "" else "delivery", sim.data.locations[d["to"]]["name"], UI.money(float(d["reward"]))], UI.AMBER)
				refresh = true
			"contract_collected":
				notice("Collected the consignment at %s." % sim.data.locations[d["place"]]["name"], UI.GOOD)
				refresh = true
			"contract_no_room":
				notice("Can't collect: %s." % d["reason"], UI.WARN)
			"contract_delivered":
				if String(d.get("role", "")) != "":
					# Work done in person: what happened, in a line.
					var lines: Array = sim.data.contracts["kinds"]["errand"]["roles"][d["role"]]["done"]
					notice(String(lines[absi(hash(str(d["id"]))) % lines.size()]), UI.TEXT)
				if d["on_time"]:
					notice("%s on time: %s paid. %s will remember that." % ["Done" if String(d.get("role", "")) != "" else "Delivered", UI.money(float(d["credits"])), d["client"]], UI.GOOD)
				else:
					notice("%s late: %s paid, and %s noticed." % ["Done" if String(d.get("role", "")) != "" else "Delivered", UI.money(float(d["credits"])), d["client"]], UI.WARN)
				refresh = true
			"contract_failed":
				notice("A job has failed: far too late. %s will not forget it." % d["client"], UI.WARN)
				refresh = true
			"contract_abandoned":
				notice("Job abandoned. %s is disappointed." % d["client"], UI.WARN)
				refresh = true
			"contract_approach":
				notice("Someone at %s is asking for you by name. See Contracts." % sim.data.places[d["place"]]["name"], UI.AMBER)
				refresh = true
			"favour_granted":
				notice(d["text"], UI.GOOD)
				refresh = true
			"kindness":
				notice(d["text"], UI.GOOD)
				comms.append("%s  %s" % [_clock(e["time_s"]), d["text"]])
				if comms.size() > COMMS_KEEP:
					comms.pop_front()
				refresh = true
			"voucher_expired":
				notice("A voucher from %s has expired." % d["operator"], UI.WARN)
				refresh = true
			"voucher_used":
				notice("Repair voucher used at %s: %s of work done, %s left." % [sim.data.places[d["place"]]["name"], UI.money(float(d["spent"])), UI.money(float(d["left"]))], UI.GOOD)
				refresh = true
			"hitchhiker_asks":
				notice("Someone at %s is looking for a ride (%s). See Contracts." % [sim.data.places[d["place"]]["name"], d["trade"]], UI.AMBER)
				refresh = true
			"hitchhiker_boarded", "hitchhiker_line", "hitchhiker_helped", "hitchhiker_left":
				var hline: String = d["text"]
				if e["type"] == "hitchhiker_left":
					hline += "  (%s%s%s)" % ["fare %s" % UI.money(float(d["fare"])) if float(d["fare"]) > 0.0 else "no fare", ", fitted a tune: %s" % sim.data.favours["tunes"][d["tune"]]["name"] if d["tune"] != "" else "",
						", goodwill with %s" % sim.data.places[d["place"]].get("operator", "the port") if float(d.get("goodwill", 0.0)) > 0.0 else ""]
				notice(hline, UI.GOOD if e["type"] != "hitchhiker_line" else UI.TEXT)
				comms.append("%s  %s" % [_clock(e["time_s"]), hline])
				if comms.size() > COMMS_KEEP:
					comms.pop_front()
				refresh = true
			"reputation_tier":
				notice("%s now counts you as %s." % [d["operator"], String(d["tier"]).to_lower()], UI.GOOD if d["up"] else UI.WARN)
			"module_installed":
				notice("Fitted %s" % sim.data.modules[d["module"]]["name"], UI.GOOD)
				refresh = true
			"departed":
				_ask_copilot_name()
				notice("Departed for %s%s" % [sim.data.locations[d["to"]]["name"], (" via %s" % d["route"]) if d.has("route") else ""] + ("  (your navigator trimmed %.2f t)" % float(d["fuel_trimmed_t"]) if float(d.get("fuel_trimmed_t", 0.0)) > 0.005 else ""), UI.AMBER)
				if SleepSystem.plan(sim.state, sim.data)["why"] == "":
					notice("The pod's ready if you want to sleep through it: %s." % Bindings.hint_of("transit_sleep"), UI.DIM)
			"descent_begins":
				var lines: Array = sim.data.npcs["chatter"]["copilot_descent"]
				var minutes := int(float(d["corridor_in_s"]) / 60.0)
				var line: String = String(lines[absi(hash(str(e["time_s"]))) % lines.size()]).format({"port": sim.data.places[d["place"]]["name"],
					"body": sim.data.bodies[d["body"]]["name"], "in": "%d h %02d min" % [minutes / 60, minutes % 60]})
				notice(line, UI.AMBER)
				comms.append("%s  %s" % [_clock(e["time_s"]), line])
			"periapsis_near", "periapsis":
				var line := Comms.copilot(sim, "copilot_near" if e["type"] == "periapsis_near" else "copilot_pass", float(d["alt"]), float(d.get("in_s", 0.0)))
				notice(line, UI.AMBER)
				comms.append("%s  %s" % [_clock(e["time_s"]), line])
			"core_found":
				notice("Hermes-7's memory core is aboard.", UI.AMBER)
				_ask_copilot_name()
			"core_sold":
				notice(String(d["text"]), UI.GOOD)
				refresh = true
			"copilot_named":
				notice("'%s it is.'" % d["name"], UI.GOOD)
			"story":
				notice("A message from %s. See Contracts." % d["from"], UI.AMBER)
				comms.append("%s  PRIVATE  from %s" % [_clock(e["time_s"]), d["from"]])
				refresh = true
			"berg_arrived":
				if float(d["tonnes"]) > 0.5:
					var line := "%s has parked a %s t berg from %s off %s: %.0f t of %s on the market." % [String(d["tug"]).left(1).to_upper() + String(d["tug"]).substr(1), UI.thousands(float(d["berg_t"])), d["from"], sim.data.places[d["place"]]["name"], float(d["tonnes"]), String(sim.data.goods[d["good"]]["name"]).to_lower()]
					notice(line, UI.AMBER)
					comms.append("%s  %s" % [_clock(e["time_s"]), line])
					refresh = true
			"arrived_site":
				notice("On site at %s. See what there is to do." % sim.data.sites[d["place"]]["name"], UI.AMBER)
			"site_work_started":
				notice("Work begins: %s of it. Speed up time; the crew will call." % UI.duration(float(d["days"]) * 86400.0), UI.AMBER)
				refresh = true
			"site_work_done":
				var got := []
				for good in d["got"]:
					got.append("%.1f t %s" % [d["got"][good], String(sim.data.goods[good]["name"]).to_lower()])
				var line := "Done at %s%s. %s" % [sim.data.sites[d["site"]]["name"], " (it went badly)" if d["went_wrong"] else "", sim.data.sites[d["site"]]["activities"][d["activity"]].get("text", "")]
				if not got.is_empty():
					line += " Aboard: " + ", ".join(got) + "."
				if float(d["credits"]) > 0.0:
					line += " Paid %s." % UI.money(float(d["credits"]))
				if float(d["lost_t"]) > 0.05:
					line += " %.1f t left behind: no room." % d["lost_t"]
				if float(d.get("dust_wear", 0.0)) > 0.001:
					line += " The dust took %d%% off every module's condition." % int(ceil(float(d["dust_wear"]) * 100.0))
				notice(line, UI.WARN if d["went_wrong"] else UI.GOOD)
				comms.append("%s  %s" % [_clock(e["time_s"]), line])
				refresh = true
			"arrived":
				notice("Arrived at %s. Take her in, or press T for the tug." % sim.data.places[d["place"]]["name"], UI.AMBER)
			"docked":
				if d.get("on_credit", false):
					notice("The tug brought you in on credit. You owe %s; sell cargo to clear it." % UI.money(-sim.state.credits), UI.WARN)
				else:
					notice("Docked at %s%s" % [sim.data.places[d["place"]]["name"], "  (hand-flown, no fee)" if d["manual"] else ""], UI.GOOD)
				var geom: Dictionary = sim.data.places[d["place"]].get("station", {})
				if not geom.is_empty():
					notice("Local gravity: %s on the %s; %s at your berth." % [Spin.describe(Spin.living_g(geom)), "ring" if geom.get("type", "wheel") in ["wheel", "stanford"] else "hull", Spin.describe(Spin.g_at(geom, Spin.cradle_radius(sim.data, 8.0)))], UI.AMBER)
				play_sfx("dock_clunk", -2.0)
	# Asleep, the port screen waits under the dark: it is rebuilt once on waking.
	if refresh and not sim.asleep() and is_instance_valid(_screen) and _screen is StationScreen:
		_screen.refresh()


## Out of the pod: the dark lifts and the digest says what changed.
func _wake_up(woke: Dictionary) -> void:
	if is_instance_valid(_sleep_overlay):
		_sleep_overlay.queue_free()
	_sleep_overlay = null
	_hold_screens(false)
	var digest := WakeDigest.new(sim, woke, _sleep_credits, _asleep_notices.duplicate())
	_asleep_notices.clear()
	# The world waits while you read.
	var was_paused: bool = sim.state.paused
	sim.apply({"type": "set_paused", "paused": true})
	digest.closed.connect(func():
		if not was_paused:
			sim.apply({"type": "set_paused", "paused": false}))
	_on_top(digest)
	_fade_in(1.2)


## The first time the co-pilot speaks up in a game, it asks for a name. The game holds
## while you think of one.
func _ask_copilot_name() -> void:
	# Scripted runs (smoke, tours, trials) never stop to ask.
	if String(sim.state.story.get("copilot", "")) != "" or sim.asleep() or is_instance_valid(_naming) or not OS.get_cmdline_user_args().is_empty():
		return
	_naming = load("res://view/copilot_name.gd").new(sim)
	var was_paused: bool = sim.state.paused
	sim.apply({"type": "set_paused", "paused": true})
	_naming.closed.connect(func():
		if not was_paused:
			sim.apply({"type": "set_paused", "paused": false}))
	_on_top(_naming)


## Over everything, cockpit HUDs included; the layer goes when the control does.
func _on_top(c: Control) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	layer.add_child(c)
	c.tree_exited.connect(layer.queue_free)


## Asleep, the screen under the dark neither draws nor runs: the machine's time goes on
## the years going by.
func _hold_screens(hold: bool) -> void:
	for n in [_screen, _backdrop]:
		if is_instance_valid(n):
			n.process_mode = Node.PROCESS_MODE_DISABLED if hold else Node.PROCESS_MODE_INHERIT
			n.visible = not hold


## Hand the controls over for a descent, then back to the site screen with the result.
func _start_landing(site: String, activity: String) -> void:
	var lander: Node3D = load("res://view/lander_scene.gd").new(sim, site)
	_screen.visible = false
	_layer.add_child(lander)
	lander.finished.connect(func(landed: bool):
		lander.queue_free()
		if is_instance_valid(_backdrop):
			_backdrop.camera.make_current()
		_screen.visible = true
		sim.apply({"type": "site_work", "activity": activity, "hand_flown": true, "landed": landed})
		_handle_events()
		(_screen as StationScreen).refresh())


func _tip_by_id(id: int) -> Dictionary:
	for tip in sim.state.tips:
		if int(tip["id"]) == id:
			return tip
	return {}


func _clock(t: float) -> String:
	return Time.get_datetime_string_from_unix_time(int(t + 946728000.0)).substr(11, 5)


func notice(text: String, colour: Color = UI.TEXT) -> void:
	# Asleep, nobody reads the board: it waits for the digest.
	if sim.asleep():
		_asleep_notices.append([text, colour])
		if _asleep_notices.size() > 200:
			_asleep_notices.pop_front()
		return
	var l := UI.label(text, colour, 14)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_notices.add_child(l)
	while _notices.get_child_count() > 6:
		_notices.get_child(0).free()
	# Bound to the label itself, so the connection dies with it if it is pushed out first.
	get_tree().create_timer(7.0).timeout.connect(l.queue_free)


## The controls page over whatever is showing; the game holds still while it is up.
func show_controls() -> void:
	if is_instance_valid(_controls):
		return
	_controls = load("res://view/controls_page.gd").new(Bindings.current)
	_controls.was_paused = sim.state.paused
	if not _title:
		sim.apply({"type": "set_paused", "paused": true})
	_controls.closed.connect(func():
		if not _title and not _controls.was_paused:
			sim.apply({"type": "set_paused", "paused": false}))
	add_child(_controls)


## Ambience for where you are, and one-shots that outlive a scene (a docking clunk
## as the station screen comes up).
func _sound_for(mode: String) -> void:
	if _ambience == null:
		_ambience = AudioStreamPlayer.new()
		add_child(_ambience)
		_cabin = AudioStreamPlayer.new()
		_cabin.stream = load("res://assets/audio/cabin_loop.wav")
		add_child(_cabin)
	if not ShipAudio.audible():
		return
	var sound := ""
	var db := -12.0
	match mode:
		"docked":
			sound = "station_loop"
		"on_site":
			sound = "pump_loop"
			db = -20.0
		"elevator":
			sound = "climber_loop"
			db = -9.0
		"shuttle":
			sound = "drive_loop"
			db = -16.0
	if sound == "":
		_ambience.stop()
	elif _ambience.stream == null or _ambience.stream.resource_path != "res://assets/audio/%s.wav" % sound or not _ambience.playing:
		_ambience.stream = load("res://assets/audio/%s.wav" % sound)
		_ambience.set_meta("base_db", db)
		_ambience.volume_db = db
		_ambience.play()
	# Inside a pressurised room (station, town, climber cab), the air moves.
	if mode in ["docked", "on_site", "elevator", "shuttle"]:
		if not _cabin.playing:
			_cabin.volume_db = -24.0
			_cabin.play()
	else:
		_cabin.stop()


## Quit, but stop every sound first and let a frame pass: a sound still playing at
## quit leaves its playback behind.
func _quit(code: int = 0) -> void:
	for p in get_tree().root.find_children("*", "AudioStreamPlayer", true, false) + get_tree().root.find_children("*", "AudioStreamPlayer3D", true, false):
		p.stop()
		p.stream = null
	if is_instance_valid(_screen):
		_screen.queue_free()
	await get_tree().process_frame
	get_tree().quit(code)


func play_sfx(sound: String, db: float = -4.0) -> void:
	if not ShipAudio.audible():
		return
	var p := AudioStreamPlayer.new()
	p.stream = load("res://assets/audio/%s.wav" % sound)
	p.volume_db = db
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func _sync_mode() -> void:
	var mode: String = sim.state.location.get("status", "docked")
	if mode == _mode:
		return
	if mode == "lifeboat" and _screen is FlightScene:
		# Keep watching the wreck until the tug brings the lifeboat in.
		_mode = mode
		return
	_mode = mode
	_sound_for(mode)
	preload("res://view/flight/sky.gd").set_eclipse(Vector3.UP)
	if _screen:
		_screen.queue_free()
	if _backdrop:
		_backdrop.queue_free()
		_backdrop = null
	match mode:
		"docked":
			_screen = StationScreen.new(sim, comms)
			_layer.add_child(_screen)
		"on_site":
			# The site in 3D behind, the site screen (station screen in site mode) on top.
			_backdrop = load("res://view/site_view.gd").new(sim)
			_layer.add_child(_backdrop)
			_screen = StationScreen.new(sim, comms)
			_screen.landing_requested.connect(_start_landing)
			_layer.add_child(_screen)
		"transit":
			_screen = MapScreen.new(sim)
			_screen.copilot.connect(func(text: String):
				notice(text, UI.AMBER)
				_radio_line(text))
			_layer.add_child(_screen)
			_fade_in(0.5)
		"approach", "lifeboat":
			# 3D renders in the root viewport underneath all 2D; its HUD sits in this layer.
			_screen = FlightScene.new(sim)
			if scripted_flight:
				_screen.computer = false
				_screen.view_mode = "cockpit"
			_screen.radio.connect(_radio_line)
			_layer.add_child(_screen)
			_fade_in(0.7)
		"elevator":
			_screen = load("res://view/climber_view.gd").new(sim)
			_layer.add_child(_screen)
		"shuttle":
			_screen = load("res://view/shuttle_view.gd").new(sim)
			_layer.add_child(_screen)


## A line heard on the radio (traffic control, other pilots), into the comms log.
## Crews talking out on the lanes, a line every few game hours (Comms.overheard), never
## while asleep: the sleep digest is for news, not gossip.
func _overhear() -> void:
	var slot := Comms.overheard_slot(sim, sim.state.time_s)
	if slot == _heard_slot:
		return
	var first := _heard_slot == -1
	_heard_slot = slot
	if first or sim.asleep() or sim.state.paused:
		return
	var text := Comms.overheard(sim, sim.state.time_s)
	if text != "":
		_radio_line(text)


func _radio_line(text: String) -> void:
	comms.append("%s  %s" % [_clock(sim.state.time_s), text])
	if comms.size() > COMMS_KEEP:
		comms.pop_front()
	_ticker.text = "\n".join(comms.slice(maxi(0, comms.size() - 3)))


## Come up from black over `seconds`: the hand-over from one view to the next reads as
## a cut in a film, not a jump.
func _fade_in(seconds: float) -> void:
	var r := ColorRect.new()
	r.color = Color.BLACK
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(r)
	var tw := r.create_tween()
	tw.tween_property(r, "color:a", 0.0, seconds)
	tw.tween_callback(r.queue_free)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("controls_page"):
		show_controls()
		return
	if _title or event.is_echo():
		return
	if event.is_action_pressed("pause"):
		sim.apply({"type": "set_paused", "paused": not sim.state.paused})
	elif _time_step(event) != 0:
		var scales: Array = sim.data.balance["time"]["scales"]
		var i := scales.find(sim.state.time_scale) + _time_step(event)
		sim.apply({"type": "set_time_scale", "scale": scales[clampi(i, 0, scales.size() - 1)]})
	elif _mode == "transit" and event.is_action_pressed("transit_dark"):
		sim.apply({"type": "dark_running"})
	elif _mode == "transit" and event.is_action_pressed("transit_sleep"):
		sim.apply({"type": "wake"} if sim.asleep() else {"type": "sleep"})
	elif _mode == "transit" and event.is_action_pressed("transit_stow"):
		sim.apply({"type": "stow_panels"})
	elif _mode == "transit" and event.is_action_pressed("transit_release"):
		_release_payload()
	elif event.is_action_pressed("sound"):
		var muted := not AudioServer.is_bus_mute(0)
		AudioServer.set_bus_mute(0, muted)
		notice("Sound off." if muted else "Sound on.", UI.DIM)
	elif event.is_action_pressed("quick_save"):
		notice("Saved." if SaveIO.save(sim.state, QUICKSAVE) == OK else "Save failed.", UI.GOOD)
	elif event.is_action_pressed("quick_load"):
		var loaded := SaveIO.load_file(QUICKSAVE)
		if loaded:
			sim.load_state(loaded)
			_mode = ""
			notice("Loaded quick save.", UI.GOOD)
		else:
			notice("No quick save to load.", UI.WARN)


## Release the first satellite or device that can go in here and now (or say why not).
func _release_payload() -> void:
	var jobs: Array = sim.state.contracts.get("active", []).filter(func(j): return j.get("release", false) or j.get("plant", false))
	if jobs.is_empty():
		notice("Nothing aboard to release.", UI.DIM)
		return
	for job in jobs:
		if sim.apply({"type": "release_satellite" if job.get("release", false) else "plant_device", "id": job["id"]}) == "":
			return


## -1 to slow time down, +1 to speed it up, 0 if this is not a time key. Transit and elevator
## add gamepad bumpers of their own, because in flight the bumpers roll the ship.
func _time_step(event: InputEvent) -> int:
	var slower := ["time_slower"]
	var faster := ["time_faster"]
	if _mode == "transit":
		slower.append("transit_time_slower")
		faster.append("transit_time_faster")
	elif _mode in ["elevator", "shuttle"]:
		slower.append("climber_time_slower")
		faster.append("climber_time_faster")
	for n in faster:
		if event.is_action_pressed(n):
			return 1
	for n in slower:
		if event.is_action_pressed(n):
			return -1
	return 0


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
	# Flown by hand here: the co-pilot's own flying is the docking trial's to prove.
	flight.computer = false
	# The bay is ours (traffic control is tested in tests/traffic_view.gd; the clock
	# doesn't run here).
	if not flight.tc.is_empty():
		flight.tc["cleared"] = true
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
	# Keys read as full pushes and a half-pulled trigger as half, through the same actions.
	Input.action_press("flight_forward", 0.5)
	Input.action_press("flight_pitch_up")
	var pushed: Dictionary = flight.read_controls()
	Input.action_release("flight_forward")
	Input.action_release("flight_pitch_up")
	var analog: bool = is_equal_approx(pushed["thrust"].z, -0.5) and pushed["stick"].x == 1.0 and flight.read_controls()["thrust"] == Vector3.ZERO
	print("SMOKE flight analog=%s" % analog)
	ok = ok and analog
	_sync_mode()
	await get_tree().process_frame
	ok = ok and _screen is StationScreen
	# The controls page builds, rebinds, swaps, refuses and resets, all against a scratch file.
	var page = load("res://view/controls_page.gd").new(Bindings.current)
	page.settings_path = "user://smoke_settings.cfg"
	add_child(page)
	await get_tree().process_frame
	var pressed := func(code: int) -> InputEventKey:
		var e := InputEventKey.new()
		e.physical_keycode = code
		e.pressed = true
		return e
	page._begin("flight_boost", "key")
	page._input(pressed.call(KEY_B))
	var b = Bindings.current
	var rebound: bool = b.specs("flight_boost", "key") == ["key:B"] and InputMap.action_has_event("flight_boost", Bindings.event_for("key:B"))
	page._begin("flight_forward", "key")
	page._input(pressed.call(KEY_A))
	rebound = rebound and b.specs("flight_strafe_left", "key") == ["key:W"]
	page._begin("flight_forward", "key")
	page._input(pressed.call(KEY_ESCAPE))
	rebound = rebound and b.specs("flight_forward", "key") == ["key:A"]
	page._on_reset()
	page._on_reset()
	rebound = rebound and not b.has_changes() and InputMap.action_has_event("flight_boost", Bindings.event_for("key:Shift"))
	print("SMOKE controls page rebound=%s" % rebound)
	ok = ok and rebound
	page.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://smoke_settings.cfg"))
	print("SMOKE_OK " if ok else "SMOKE_FAIL ", sim.state.date_string())
	_quit(0 if ok else 1)


## Headless: fly the autopilot from the real approach spawn at every station, using
## only player controls, and report how long docking takes. Proves approaches are
## flyable and measures how forgiving the tolerances are.
func _dock_trial() -> void:
	var all_ok := true
	for place in sim.data.places:
		if sim.data.places[place].has("foot_of"):
			continue
		sim.state.location = {"status": "approach", "place": place}
		_mode = ""
		_sync_mode()
		await get_tree().physics_frame
		var flight: FlightScene = _screen
		var steps := 0
		var limit := 60 * 900
		var held := 0
		while not flight.docked and steps < limit:
			flight.control_override = Autopilot.controls(flight)
			# The world runs on at x1, so the port's traffic moves (sim/traffic.gd).
			sim.tick(1.0 / 60.0)
			flight._physics_process(1.0 / 60.0)
			if not flight.cleared():
				held += 1
			steps += 1
		var ok := flight.docked
		all_ok = all_ok and ok
		ok = ok and flight.hits == 0
		all_ok = all_ok and ok
		print("DOCK_TRIAL %-16s docked=%s time=%5.0f s held=%4.0f s refusals=%d contacts=%d hits=%d bay=%s traffic=%s" % [place, flight.docked, steps / 60.0, held / 60.0, flight.refusals, flight.bumps, flight.hits, flight.bay_doors, flight.tc.get("control", "-")])
		sim.state.location = {"status": "docked", "place": place}
	# Once more at a return visit's time compression, the co-pilot flying as in play:
	# local flight must keep pace with the clock and still dock clean.
	var scale := float(sim.data.balance["time"]["return_arrival_scale"])
	for place in ["kibo_ring", "halo_depot"]:
		sim.state.location = {"status": "approach", "place": place}
		sim.state.time_scale = scale
		_mode = ""
		_sync_mode()
		await get_tree().physics_frame
		var flight: FlightScene = _screen
		flight.computer = true
		var t0 := sim.state.time_s
		var frames := 0
		while not flight.docked and frames < 60 * 900:
			sim.tick(1.0 / 60.0)
			flight._physics_process(1.0 / 60.0)
			frames += 1
		var ok := flight.docked and flight.hits == 0 and absf((sim.state.time_s - t0) - flight.clock) < 2.0
		all_ok = all_ok and ok
		print("DOCK_TRIAL %-16s x%d docked=%s real=%4.0f s game=%5.0f s flown=%5.0f s refusals=%d contacts=%d hits=%d" % [place, int(scale), flight.docked, frames / 60.0, sim.state.time_s - t0, flight.clock, flight.refusals, flight.bumps, flight.hits])
		sim.state.location = {"status": "docked", "place": place}
		sim.state.time_scale = 1.0
	print("DOCK_TRIAL_OK" if all_ok else "DOCK_TRIAL_FAIL")
	_quit(0 if all_ok else 1)


## Windowed screenshot tour for visual checks: station, map, flight.
func _tour(dir: String) -> void:
	scripted_flight = true
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
	_shot(dir + "/2a-contracts.png")
	if _screen is StationScreen:
		_screen._tab_index = 3
		_screen.refresh()
	for _i in 5:
		await get_tree().process_frame
	_shot(dir + "/2b-traffic.png")
	if _screen is StationScreen:
		_screen._tab_index = 4
		_screen.refresh()
	for _i in 5:
		await get_tree().process_frame
	_shot(dir + "/2c-projects.png")
	if _screen is StationScreen:
		_screen._tab_index = 5
		_screen.refresh()
	for _i in 5:
		await get_tree().process_frame
	_shot(dir + "/2d-spaceline.png")
	sim.apply({"type": "buy_tip", "broker": "maisie_tran"})
	sim.apply({"type": "buy_tip", "broker": "maisie_tran"})
	_handle_events()
	if _screen is StationScreen:
		_screen._tab_index = 6
		_screen.refresh()
	for _i in 5:
		await get_tree().process_frame
	_shot(dir + "/2d-tips.png")
	if _screen is StationScreen:
		_screen._tab_index = 7
		_screen.refresh()
	for _i in 5:
		await get_tree().process_frame
	_shot(dir + "/2f-shipyard.png")
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
		# Look about the cabin first: aft to the hatch, then out of the side window.
		for look in [["3f-transit-cabin-aft", 2.7, -0.25], ["3g-transit-cabin-side", 1.35, -0.2]]:
			tv.look_yaw = look[1]
			tv.look_pitch = look[2]
			for _i in 10:
				await get_tree().process_frame
			_shot("%s/%s.png" % [dir, look[0]])
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
	# Turn about in the cabin, as a drag with the mouse would.
	flight._looking = true
	flight._look = Vector2(-2.5, -0.2)
	for _i in 10:
		await get_tree().process_frame
	_shot(dir + "/5b-flight-cabin.png")
	flight._looking = false
	flight._look = Vector2.ZERO
	flight.view_mode = "chase"
	for _i in 10:
		await get_tree().process_frame
	_shot(dir + "/6-flight-chase.png")
	# Traffic: a local ship ahead of us in the pattern, going in through the doors
	# while we hold (sim/traffic.gd).
	var place: String = sim.state.location["place"]
	var lead := {}
	for m in preload("res://sim/traffic.gd").movements(sim.state, sim.data, place, sim.state.time_s + 600.0, sim.state.time_s + 86400.0):
		if m.has("local") and m["kind"] == "in":
			lead = m
			break
	if not lead.is_empty():
		sim.state.time_s = float(lead["t"]) - 20.0
		sim.state.location = {"status": "approach", "place": place}
		_mode = ""
		_sync_mode()
		await get_tree().physics_frame
		var held: FlightScene = _screen
		sim.state.time_s = float(lead["t"]) + 30.0
		held.ship_node.position = Vector3(6, 4, float(held.station["bay"]["z_mouth"]) + 250.0 - held.nose_z)
		held.ship_node.rotation = Vector3.ZERO
		held.view_mode = "chase"
		for _i in 20:
			await get_tree().process_frame
		_shot(dir + "/6b-flight-traffic.png")
		held.view_mode = "cockpit"
		for _i in 10:
			await get_tree().process_frame
		_shot(dir + "/6c-flight-traffic-cockpit.png")
		# The co-pilot flying, from outside: the director's cameras on the approach,
		# then from inside the bay as she comes in.
		held.computer = true
		held.view_mode = "outside"
		held.shot = ""
		for _i in 20:
			await get_tree().process_frame
		_shot(dir + "/6d-flight-outside.png")
		held.ship_node.position = Vector3(0, 0, float(held.station["bay"]["z_mouth"]) + 30.0 - held.nose_z)
		held.tc["cleared"] = true
		held.shot = ""
		for _i in 20:
			await get_tree().process_frame
		_shot(dir + "/6e-flight-into-bay.png")
	_quit()


## Windowed: every attract-screen shot, captured mid-shot.
func _title_tour(dir: String) -> void:
	scripted_flight = true
	DirAccess.make_dir_recursive_absolute(dir)
	show_title()
	for shot in TitleScreen.SHOTS:
		_title.force_shot = shot
		_title.next_shot()
		for _i in 2:
			await get_tree().process_frame
		_title.clock = TitleScreen.SHOT_S * 0.45
		for _i in 30:
			await get_tree().process_frame
		_shot("%s/%s.png" % [dir, shot])
	_quit()


## Windowed: a descent onto Eros and Psyche on autopilot, captured on the way down.
func _landing_tour(dir: String) -> void:
	scripted_flight = true
	DirAccess.make_dir_recursive_absolute(dir)
	for _i in 3:
		await get_tree().process_frame
	_bar.visible = false
	if _screen:
		_screen.visible = false
	for site in ["eros_survey", "psyche_deep_claim"]:
		var lander: Node3D = load("res://view/lander_scene.gd").new(sim, site)
		lander.autopilot = true
		_layer.add_child(lander)
		for _i in 240:
			await get_tree().physics_frame
		_shot("%s/%s-descent.png" % [dir, site])
		while not lander.done:
			await get_tree().physics_frame
		for _i in 30:
			await get_tree().process_frame
		_shot("%s/%s-down.png" % [dir, site])
		print("LANDING %s landed=%s fuel=%.0f" % [site, lander.landed, lander.fuel])
		lander.queue_free()
	_quit()


## Windowed: on site at the derelict Ishikawa Maru and at Eros, before and during work.
func _site_tour(dir: String) -> void:
	scripted_flight = true
	DirAccess.make_dir_recursive_absolute(dir)
	var s = sim.state
	s.ship["modules"]["avionics.0"] = "survey_pod"
	s.ship["modules"]["cargo.1"] = "lander_bay"
	for site in ["ishikawa_maru", "eros_survey", "the_lacuna"]:
		s.location = {"status": "on_site", "place": site}
		_sync_mode()
		for _i in 60:
			await get_tree().process_frame
		_shot("%s/%s.png" % [dir, site])
		var act: String = sim.data.sites[site]["activities"].keys()[0]
		sim.apply({"type": "site_work", "activity": act})
		sim.advance_game_time(0.4 * float(sim.data.sites[site]["activities"][act]["days"]) * 86400.0)
		_handle_events()
		(_screen as StationScreen).refresh()
		for _i in 20:
			await get_tree().process_frame
		_shot("%s/%s-working.png" % [dir, site])
		sim.advance_game_time(float(sim.data.sites[site]["activities"][act]["days"]) * 86400.0)
		_handle_events()
		_mode = ""
	_quit()


## Windowed: refit for the long haul (tanks in the cargo bays), plot Halo Depot to Ares
## Ring, depart on the Express route, and capture the orbit view, map and cockpit at
## the start, middle and end of the voyage, then the approach to Mars.
func _voyage_tour(dir: String) -> void:
	scripted_flight = true
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
		_quit(1)
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
	_quit()


## Windowed: plot Kibo Ring to Farside, take the lowest lunar flyby, and capture the
## run-in, the pass in the orbit view and from the cockpit, and the map.
func _flyby_tour(dir: String) -> void:
	scripted_flight = true
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
		_quit(1)
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
	_quit()


## Windowed: an approach at every place, cockpit and wide shots, to check set pieces.
func _gallery(dir: String) -> void:
	scripted_flight = true
	DirAccess.make_dir_recursive_absolute(dir)
	sim.advance_game_time(12.0 * 3600.0)
	# --only=a,b limits the shoot to those ports.
	var only: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = Array(a.trim_prefix("--only=").split(","))
	var ports: Array = sim.data.places.keys().filter(func(p): return (only.is_empty() or p in only) and not sim.data.places[p].has("foot_of"))
	for place in ports:
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
	# The same approaches with every megaproject half built, then finished.
	for pass_name in ["building", "finished"]:
		for id in sim.data.projects:
			var n: int = sim.data.projects[id]["stages"].size()
			sim.state.projects[id]["revealed"] = true
			sim.state.projects[id]["done"] = pass_name == "finished"
			sim.state.projects[id]["stage"] = n if pass_name == "finished" else n / 2
			sim.state.projects[id]["delivered"] = {}
		for id in sim.data.projects:
			var place: String = sim.data.projects[id]["place"]
			if not place in ports:
				continue
			sim.state.location = {"status": "approach", "place": place}
			_mode = ""
			_sync_mode()
			(_screen as FlightScene).hud.show_keys = false
			(_screen as FlightScene).view_mode = "beauty"
			for _i in 60:
				await get_tree().process_frame
			_shot("%s/%s-%s.png" % [dir, place, pass_name])
	_quit()


## Windowed: the ship view in transit, Kibo Ring to Halo Depot. Every director set-up
## at the moment it suits (leaving the port, burning, coasting, nearing the Moon), and
## the free camera.
## The market with cargo aboard (`--market=<dir>`): one load bought here (sold back
## at a loss, red) and one bought cheap elsewhere (at a profit, green).
func _market_shot(dir: String) -> void:
	scripted_flight = true
	DirAccess.make_dir_recursive_absolute(dir)
	_notices.visible = false
	sim.state.location = {"status": "docked", "place": "kibo_ring"}
	sim.apply({"type": "buy", "good": sim.data.places["kibo_ring"]["market"].keys()[0], "tonnes": 4.0})
	var other: String = sim.data.places["kibo_ring"]["market"].keys()[1]
	sim.state.ship["cargo"][other] = 3.0
	sim.state.ship["cargo_paid"][other] = 30.0
	_mode = ""
	_sync_mode()
	for _i in 12:
		await get_tree().process_frame
	_shot(dir + "/market.png")
	# The controls page (F1) over the station, and the Departures tab scrolled down.
	show_controls()
	for _i in 12:
		await get_tree().process_frame
	_shot(dir + "/controls.png")
	if is_instance_valid(_controls):
		_controls.queue_free()
	for _i in 4:
		await get_tree().process_frame
	if _screen is StationScreen:
		var st: StationScreen = _screen
		st._tabs.current_tab = 1
		for _i in 6:
			await get_tree().process_frame
		var scroll := st._tabs.get_child(1) as ScrollContainer
		if scroll:
			scroll.scroll_vertical = 400
			for _i in 4:
				await get_tree().process_frame
			print("SCROLL before refresh: ", scroll.scroll_vertical)
			st.refresh()
			for _i in 3:
				await get_tree().process_frame
			var again := st._tabs.get_child(1) as ScrollContainer
			print("SCROLL after refresh: ", again.scroll_vertical)
			_shot(dir + "/departures-after-refresh.png")
		# The ship builder with a refit planned: berths in a bay, a bigger tank.
		var builder := preload("res://view/ship_builder_screen.gd").new(sim)
		st.add_child(builder)
		for _i in 4:
			await get_tree().process_frame
		builder.plan = {"cargo.1": "passenger_berths", "tank.0": "tank_m"}
		builder.extra = {"service_all": "service", "inspect": true}
		builder.selected = "cargo.1"
		builder._refresh()
		for _i in 20:
			await get_tree().process_frame
		_shot(dir + "/ship-builder.png")
	_quit()


## Leaving and arriving in the ship view (`--corridor=<dir>`): Kibo Ring to Halo
## Depot, the chase and station shots at moments through the departure and the
## arrival, then the approach scene that takes over.
func _corridor_shots(dir: String) -> void:
	scripted_flight = true
	DirAccess.make_dir_recursive_absolute(dir)
	_notices.visible = false
	sim.state.location = {"status": "docked", "place": "kibo_ring"}
	_mode = ""
	_sync_mode()
	if sim.apply({"type": "depart", "to": "halo_depot"}) != "":
		_quit()
		return
	_handle_events()
	_sync_mode()
	var loc: Dictionary = sim.state.location
	var t0 := float(loc["depart_t"])
	var t1 := float(loc["arrive_t"])
	sim.state.paused = true
	var moments := [["leave-005", t0 + 5.0], ["leave-040", t0 + 40.0], ["leave-200", t0 + 200.0], ["leave-700", t0 + 700.0],
		["arrive-900", t1 - 900.0], ["arrive-300", t1 - 300.0], ["arrive-060", t1 - 60.0], ["arrive-005", t1 - 5.0]]
	for m in moments:
		sim.state.time_s = float(m[1])
		var map: MapScreen = _screen
		map.set_view("ship")
		for _i in 12:
			await get_tree().process_frame
		var view = map._view
		for shot in ["chase", "station"]:
			view.mode = "director"
			view.shot = shot
			view.shot_label = shot.to_upper()
			view.shot_clock = view.SHOT_S * 0.5
			for _i in 8:
				await get_tree().process_frame
			_shot("%s/%s-%s.png" % [dir, m[0], shot])
		print("CORRIDOR %s scale=%d" % [m[0], int(sim.state.time_scale)])
	sim.state.paused = false
	sim.state.time_s = t1 + 1.0
	for _i in 40:
		await get_tree().process_frame
	_shot("%s/zz-approach.png" % dir)
	_quit()


func _shipcam_tour(dir: String) -> void:
	scripted_flight = true
	DirAccess.make_dir_recursive_absolute(dir)
	_notices.visible = false
	sim.state.location = {"status": "docked", "place": "kibo_ring"}
	_mode = ""
	_sync_mode()
	var err: String = sim.apply({"type": "depart", "to": "halo_depot"})
	if err != "":
		print("SHIPCAM_FAIL ", err)
		_quit()
		return
	_handle_events()
	_sync_mode()
	var loc: Dictionary = sim.state.location
	var t0 := float(loc["depart_t"])
	var t1 := float(loc["arrive_t"])
	var moments := [["leaving", t0 + 120.0, ["station", "chase", "plume", "rim"]],
		["burning", t0 + 3600.0 * 3.0, ["orbit", "flyby", "dolly", "plume", "world", "longlens"]],
		["coasting", lerpf(t0, t1, 0.5), ["chase", "world", "longlens", "rim"]],
		["arriving", t1 - 3600.0 * 2.0, ["world", "longlens", "orbit"]]]
	for m in moments:
		sim.state.time_s = float(m[1])
		var map: MapScreen = _screen
		map.set_view("ship")
		for _i in 10:
			await get_tree().process_frame
		var view = map._view
		for shot in m[2]:
			view.mode = "director"
			view._target_body = view._hero_body()
			if shot in ["world", "longlens"] and view._target_body == "":
				continue
			if shot == "station" and view._nearest_station() == "":
				continue
			view.shot = shot
			view.shot_label = shot.to_upper()
			view.shot_clock = view.SHOT_S * 0.5
			for _i in 6:
				await get_tree().process_frame
			_shot("%s/%s-%s.png" % [dir, m[0], shot])
	# Real mouse input: a drag and some wheel clicks hand the camera to the pilot.
	var view = (_screen as MapScreen)._view
	var centre := get_viewport().get_visible_rect().size * 0.5
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = centre
	Input.parse_input_event(press)
	await get_tree().process_frame
	var yaw0: float = view._yaw
	var drag := InputEventMouseMotion.new()
	drag.position = centre + Vector2(120, 40)
	drag.relative = Vector2(120, 40)
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(drag)
	await get_tree().process_frame
	var release := press.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	var dist0: float = view._dist
	for _k in 3:
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_UP
		wheel.pressed = true
		wheel.position = centre
		Input.parse_input_event(wheel)
		await get_tree().process_frame
	print("SHIPCAM_INPUT mode=%s yaw_moved=%s zoomed_in=%s" % [view.mode, absf(view._yaw - yaw0) > 0.1, view._dist < dist0])
	# The free camera, pulled in close and turned.
	view._take_over()
	view._yaw = 2.2
	view._pitch = 0.35
	view._dist = view._length * 1.3
	for _i in 6:
		await get_tree().process_frame
	_shot("%s/free-close.png" % dir)
	view._dist = view._length * 12.0
	for _i in 6:
		await get_tree().process_frame
	_shot("%s/free-far.png" % dir)
	_quit()


## Windowed: stills for the game's store page. Every title set-up without its
## overlay (two moments each), then gameplay: cockpit approaches, a ribbon ride, the
## station screen, the map in transit and a rock strike. Notices are hidden.
func _promo(dir: String) -> void:
	scripted_flight = true
	DirAccess.make_dir_recursive_absolute(dir)
	_notices.visible = false
	show_title()
	_title._overlay.visible = false
	for shot in TitleScreen.SHOTS:
		for moment in [0.35, 0.7]:
			_title.force_shot = shot
			_title.next_shot()
			for _i in 2:
				await get_tree().process_frame
			_title.clock = TitleScreen.SHOT_S * moment
			for _i in 40:
				await get_tree().process_frame
			_shot("%s/cine-%s-%d.png" % [dir, shot, int(moment * 100.0)])
	# The controls page, over a title shot.
	_title.force_shot = "saturn"
	_title.next_shot()
	show_controls()
	for _i in 30:
		await get_tree().process_frame
	_shot("%s/controls.png" % dir)
	_controls.queue_free()
	_title.queue_free()
	_title = null
	_bar.visible = true
	_ticker.visible = true
	# The finished system: every build complete, so the sky is full.
	for id in sim.data.projects:
		sim.state.projects[id]["revealed"] = true
		sim.state.projects[id]["done"] = true
		sim.state.projects[id]["stage"] = sim.data.projects[id]["stages"].size()
	sim.advance_game_time(12.0 * 3600.0)
	_handle_events()
	for place in ["kibo_ring", "tsiolkovsky_wheel", "kernel_l5", "piazzi_station", "landauer_deep", "halo_depot"]:
		sim.state.location = {"status": "approach", "place": place}
		_mode = ""
		_sync_mode()
		for _i in 60:
			await get_tree().process_frame
		(_screen as FlightScene).hud.show_keys = false
		for _i in 3:
			await get_tree().process_frame
		_shot("%s/play-cockpit-%s.png" % [dir, place])
		(_screen as FlightScene).view_mode = "chase"
		for _i in 30:
			await get_tree().process_frame
		_shot("%s/play-chase-%s.png" % [dir, place])
	# Down the Luna Line.
	sim.state.location = {"status": "docked", "place": "halo_depot"}
	sim.state.credits = 20000.0
	_mode = ""
	_sync_mode()
	sim.apply({"type": "ride_elevator"})
	_handle_events()
	_sync_mode()
	var loc: Dictionary = sim.state.location
	sim.state.time_s = lerpf(float(loc["depart_t"]), float(loc["arrive_t"]), 0.96)
	for _i in 30:
		await get_tree().process_frame
	_shot("%s/play-ride-luna-line.png" % dir)
	sim.advance_game_time(float(loc["arrive_t"]) - sim.state.time_s + 1.0)
	_handle_events()
	# The station screen and the news, back up at Kibo after some days of traffic.
	sim.state.location = {"status": "docked", "place": "kibo_ring"}
	_mode = ""
	_sync_mode()
	sim.advance_game_time(2.0 * 86400.0)
	_handle_events()
	for tab in [[0, "market"], [4, "projects"], [5, "spaceline"]]:
		if _screen is StationScreen:
			_screen._tab_index = tab[0]
			_screen.refresh()
		for _i in 6:
			await get_tree().process_frame
		_shot("%s/play-station-%s.png" % [dir, tab[1]])
	# Plotted and under way: the map.
	if _screen is StationScreen:
		_screen._tab_index = 1
		_screen.refresh()
		_screen._plot("kibo_ring", "halo_depot")
		while not (_screen as StationScreen)._plotting.is_empty():
			await get_tree().process_frame
		for _i in 5:
			await get_tree().process_frame
		_shot("%s/play-routes.png" % dir)
	sim.apply({"type": "depart", "to": "halo_depot"})
	_handle_events()
	_sync_mode()
	sim.advance_game_time(20.0 * 3600.0)
	(_screen as MapScreen).set_view("map")
	for _i in 30:
		await get_tree().process_frame
	_shot("%s/play-map.png" % dir)
	# Under way, from the flight deck: the burn and the trip on the glass.
	(_screen as MapScreen).set_view("cockpit")
	for _i in 30:
		await get_tree().process_frame
	_shot("%s/play-transit-cockpit.png" % dir)
	await _promo_ship(dir, false)
	_quit()


## Store-page stills from the ship view: Kibo Ring to Halo Depot, then a deep
## freighter across Saturn's system from Titan to Enceladus. The director's set-ups
## without the overlay, and one with it.
func _promo_ship(dir: String, quit_after: bool) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	_notices.visible = false
	var trips := [
		["kibo_ring", "halo_depot", "", [[0.002, ["station", "plume"]], [0.25, ["dolly", "world"]], [0.93, ["world", "longlens", "orbit"]]]],
		["huygens_port", "plume_watch", "deep_freighter", [[0.003, ["station", "chase"]], [0.3, ["world", "longlens", "rim", "flyby"]], [0.6, ["world", "dolly", "orbit"]], [0.95, ["world", "longlens"]]]],
	]
	for trip in trips:
		if trip[2] != "":
			var hull: Dictionary = sim.data.ships[trip[2]]
			sim.state.ship["hull"] = trip[2]
			sim.state.ship["modules"] = hull["modules"].duplicate()
			sim.state.ship["damage"] = {}
			sim.state.ship["fuel_t"] = preload("res://sim/ship_stats.gd").fuel_capacity_t(sim.state.ship, sim.data)
		sim.state.ship["cargo"] = {}
		sim.state.location = {"status": "docked", "place": trip[0]}
		_mode = ""
		_sync_mode()
		var err: String = sim.apply({"type": "depart", "to": trip[1]})
		if err != "":
			print("PROMO_SHIP_FAIL %s -> %s: %s" % [trip[0], trip[1], err])
			continue
		_handle_events()
		_sync_mode()
		var loc: Dictionary = sim.state.location
		for moment in trip[3]:
			sim.state.time_s = lerpf(float(loc["depart_t"]), float(loc["arrive_t"]), float(moment[0]))
			var map: MapScreen = _screen
			map.set_view("ship")
			for _i in 10:
				await get_tree().process_frame
			var view = map._view
			for shot in moment[1]:
				view.mode = "director"
				view._target_body = view._hero_body()
				if shot in ["world", "longlens"] and view._target_body == "":
					continue
				if shot == "longlens" and view._angular(view._target_body) > deg_to_rad(18.0):
					continue
				if shot == "station" and view._nearest_station() == "":
					continue
				view.shot = shot
				view.shot_label = shot.to_upper()
				view.shot_clock = view.SHOT_S * 0.5
				view._fade.color.a = 0.0
				map._overlay.visible = false
				_bar.visible = false
				_ticker.visible = false
				for _i in 8:
					await get_tree().process_frame
				_shot("%s/ship-%s-%s-%d-%s.png" % [dir, trip[0], trip[1], int(float(moment[0]) * 100.0), shot])
		# One with the overlay, as you would play it.
		var map2: MapScreen = _screen
		map2._overlay.visible = true
		_bar.visible = true
		_ticker.visible = true
		for _i in 8:
			await get_tree().process_frame
		_shot("%s/ship-hud-%s-%s.png" % [dir, trip[0], trip[1]])
	if quit_after:
		_quit()


## Windowed: the Kestrel standing on the Moon, from all round and close in on a leg.
func _kestrel_tour(dir: String) -> void:
	scripted_flight = true
	DirAccess.make_dir_recursive_absolute(dir)
	sim.state.paused = true
	_sync_mode()
	_layer.visible = false
	_bar.visible = false
	_ticker.visible = false
	_notices.visible = false
	var stage := Node3D.new()
	add_child(stage)
	stage.add_child(preload("res://view/flight/sky.gd").environment())
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	sun.shadow_normal_bias = 3.0
	sun.shadow_bias = 0.2
	stage.add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, Vector3(0.55, -0.5, 0.65), Vector3.UP)
	# A patch of regolith (a flat plane takes shadows cleanly; the whole Moon doesn't).
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(3000, 3000)
	ground.mesh = plane
	ground.material_override = Kit.paint(Color("8a8780"), {"wear": 0.6, "mismatch": 0.2, "panel_m": 40.0, "roughness": 1.0})
	stage.add_child(ground)
	var Kestrel = load("res://view/flight/kestrel.gd")
	var model: Dictionary = Kestrel.build(Livery.for_ship(sim.data, "Terran Compact", "Sinus Medii"))
	var craft: Node3D = model["node"]
	craft.position = Vector3(0, -float(model["foot_y"]), 0)
	stage.add_child(craft)
	var cam := Camera3D.new()
	cam.fov = 45.0
	cam.near = 0.2
	cam.far = 4.0e6
	stage.add_child(cam)
	cam.make_current()
	var views := [["front-quarter", Vector3(-16, 6, -22), Vector3(0, 1.5, -2)], ["side", Vector3(-30, 4, 0), Vector3(0, 1.0, 0)],
		["rear-quarter", Vector3(18, 7, 20), Vector3(0, 1.5, 3)], ["low", Vector3(-9, 0.6, -14), Vector3(0, 1.5, 0)],
		["above", Vector3(-10, 26, -12), Vector3(0, 0, 0)], ["leg", Vector3(-7.5, 0.4, -9.0), Vector3(-4.6, -1.0, -4.6)]]
	for v in views:
		cam.position = v[1]
		cam.look_at(v[2], Vector3.UP)
		for _i in 8:
			await get_tree().process_frame
		_shot("%s/kestrel-%s.png" % [dir, v[0]])
	# Landing: legs compressed, lift thrusters lit.
	Kestrel.compress(model["legs"], [0.35, 0.35, 0.35, 0.35])
	model["lift"].visible = true
	cam.position = Vector3(-16, 2, -16)
	cam.look_at(Vector3(0, 1.0, 0), Vector3.UP)
	for _i in 8:
		await get_tree().process_frame
	_shot("%s/kestrel-landing.png" % dir)
	_quit()


## Windowed: at Psyche Claims, nudge into a rock at 5 m/s (damage, sparks), then hit
## the station at 16 m/s (the wreck and the lifeboat), shooting each.
func _crash_tour(dir: String) -> void:
	scripted_flight = true
	DirAccess.make_dir_recursive_absolute(dir)
	sim.state.location = {"status": "approach", "place": "psyche_claims"}
	_mode = ""
	_sync_mode()
	for _i in 10:
		await get_tree().process_frame
	var flight: FlightScene = _screen
	flight.view_mode = "chase"
	var rock: Dictionary = flight._rocks[0]
	for r in flight._rocks:
		if float(r["r"]) > 6.0 and float(r["r"]) < 20.0:
			rock = r
			break
	# Line up a few radii off the rock, nose on, and drift in.
	var at: Vector3 = rock["node"].position
	var toward := Vector3(0.3, 0.2, 1.0).normalized()
	flight.ship_node.position = at + toward * (float(rock["r"]) + flight.ship_radius + 14.0)
	flight.ship_node.look_at(at, Vector3.UP)
	flight.velocity = -toward * 5.0
	rock["vel"] = Vector3.ZERO
	for _i in 200:
		await get_tree().physics_frame
		if flight.bumps > 0:
			break
	for _i in 4:
		await get_tree().process_frame
	_shot("%s/1-rock-impact.png" % dir)
	for _i in 40:
		await get_tree().process_frame
	_shot("%s/2-after.png" % dir)
	# The same moment from the flight deck: the damage on the SYSTEMS display.
	flight.view_mode = "cockpit"
	for _i in 6:
		await get_tree().process_frame
	_shot("%s/2b-after-cockpit.png" % dir)
	flight.view_mode = "chase"
	# Into the station's ring, hard.
	var rr: float = flight.station["ring_radius"]
	flight.ship_node.position = Vector3(rr, 0, 60.0)
	flight.ship_node.look_at(Vector3(rr, 0, 0), Vector3.UP)
	flight.velocity = Vector3(0, 0, -16.0)
	flight.ang_vel = Vector3.ZERO
	for _i in 300:
		await get_tree().physics_frame
		if flight.wrecked:
			break
	for _i in 12:
		await get_tree().process_frame
	_shot("%s/3-wreck.png" % dir)
	for _i in 90:
		await get_tree().process_frame
	_shot("%s/4-wreck-later.png" % dir)
	print("CRASH wrecked=%s status=%s" % [flight.wrecked, sim.state.location.get("status", "?")])
	_quit()


## Windowed: ride each elevator down (and fly every shuttle to each of its bases and
## back: the Mars shuttle, the Moon's hopper from Line Foot),
## shooting the cab view on the way and the town at
## the bottom, then ride back up.
func _ride_tour(dir: String) -> void:
	scripted_flight = true
	DirAccess.make_dir_recursive_absolute(dir)
	for id in sim.data.projects:
		sim.state.projects[id]["done"] = true
	sim.state.credits = 100000.0
	for anchor in ["halo_depot", "piazzi_station", "ares_ring"]:
		sim.state.location = {"status": "docked", "place": anchor}
		_mode = ""
		_sync_mode()
		for _i in 5:
			await get_tree().process_frame
		if _screen is StationScreen:
			_screen._tab_index = 1
			_screen.refresh()
		for _i in 5:
			await get_tree().process_frame
		_shot("%s/%s-departures.png" % [dir, anchor])
		var err: String = sim.apply({"type": "ride_elevator"})
		if err != "":
			print("RIDE_FAIL %s: %s" % [anchor, err])
			continue
		_handle_events()
		_sync_mode()
		var loc: Dictionary = sim.state.location
		for f in [0.02, 0.5, 0.97]:
			sim.state.time_s = lerpf(float(loc["depart_t"]), float(loc["arrive_t"]), f)
			for _i in 20:
				await get_tree().process_frame
			_shot("%s/%s-%02d.png" % [dir, anchor, int(f * 100.0)])
		sim.advance_game_time(float(loc["arrive_t"]) - sim.state.time_s + 1.0)
		_handle_events()
		_sync_mode()
		for _i in 10:
			await get_tree().process_frame
		_shot("%s/%s-foot.png" % [dir, anchor])
		if _screen is StationScreen:
			_screen._tab_index = 1
			_screen.refresh()
		for _i in 5:
			await get_tree().process_frame
		_shot("%s/%s-foot-departures.png" % [dir, anchor])
		print("RIDE_OK %s -> %s (%s)" % [anchor, sim.state.location.get("place", "?"), sim.state.location.get("status", "?")])
	# Then every shuttle to each of its bases and back.
	var lines: Array = sim.data.places.keys().filter(func(p): return sim.data.places[p].has("shuttle"))
	for port in lines:
		for base in sim.data.places[port]["shuttle"]["stops"]:
			for leg in [base, port]:
				if leg == base:
					sim.state.location = {"status": "docked", "place": port}
				var err: String = sim.apply({"type": "take_shuttle", "to": leg})
				if err != "":
					print("SHUTTLE_FAIL %s: %s" % [leg, err])
					break
				_handle_events()
				_sync_mode()
				var loc: Dictionary = sim.state.location
				# A hop flies only the end of its hour, so a frame at 0.55 catches it in the air.
				for f in [0.03, 0.4, 0.55, 0.75, 0.97]:
					sim.state.time_s = lerpf(float(loc["depart_t"]), float(loc["arrive_t"]), f)
					for _i in 20:
						await get_tree().process_frame
					_shot("%s/shuttle-%s-%s-%02d.png" % [dir, base, "down" if leg == base else "up", int(f * 100.0)])
				sim.advance_game_time(float(loc["arrive_t"]) - sim.state.time_s + 1.0)
				_handle_events()
				_sync_mode()
				for _i in 10:
					await get_tree().process_frame
				if leg == base:
					_shot("%s/shuttle-%s.png" % [dir, base])
			print("SHUTTLE_OK %s (%s)" % [base, sim.state.location.get("place", "?")])
	_quit()


func _shot(path: String) -> void:
	get_viewport().get_texture().get_image().save_png(path)
	print("SHOT %s  (%d fps)" % [path, Engine.get_frames_per_second()])
