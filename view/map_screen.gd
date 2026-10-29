## In transit, four views cycled with M: your ship in the real sky with a free or
## directed camera (default), the god's-eye orbit view, the cockpit, and the flat
## system map. Time compression works in all of them.
extends Control

const UI := preload("res://view/ui/ui_kit.gd")
const V := preload("res://sim/v3.gd")
const Navigation := preload("res://sim/navigation.gd")
const SystemMap := preload("res://view/system_map.gd")
const TransitView := preload("res://view/transit_view.gd")
const TransitHud := preload("res://view/transit_hud.gd")
const OrbitView := preload("res://view/orbit_view.gd")
const OrbitHud := preload("res://view/orbit_hud.gd")
const FollowView := preload("res://view/follow_view.gd")
const FollowHud := preload("res://view/follow_hud.gd")
const VIEWS := ["ship", "orbit", "cockpit", "map"]
const TransitAudio := preload("res://view/audio/transit_audio.gd")
const ShipAudio := preload("res://view/audio/ship_audio.gd")
const DepartureCalls := preload("res://view/flight/departure_calls.gd")

## The co-pilot says something (talking the ship out of port).
signal copilot(text: String)

var sim
var view_name := "orbit"
var _map: Control
var _panel: Control
var _legend: Control
var _hud: Label
var _scale_bar: HBoxContainer
var _details: Control
## The transit panel folded down to its first line and the time buttons.
var _folded := false
var _view: Node3D
var _overlay: Control


func _init(owner_sim) -> void:
	sim = owner_sim
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS


func _ready() -> void:
	_map = SystemMap.new(sim)
	_map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map.frame = sim.state.location.get("frame", "earth")
	_map.centre_offset = Vector2(120, 10)
	add_child(_map)
	var p := UI.panel("Transit")
	_panel = p[0]
	_panel.position = Vector2(16, 56)
	# Narrow and wrapped, so it keeps to the map's corner.
	_panel.custom_minimum_size = Vector2(330, 0)
	_panel.size = Vector2(330, 0)
	add_child(_panel)
	_hud = UI.label("", UI.TEXT, 13)
	_hud.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hud.custom_minimum_size = Vector2(310, 0)
	p[1].add_child(_hud)
	_scale_bar = HBoxContainer.new()
	_scale_bar.add_theme_constant_override("separation", 2)
	p[1].add_child(_scale_bar)
	for scale in sim.data.balance["time"]["scales"]:
		var b := UI.button("×" + _short(float(scale)), func(): sim.apply({"type": "set_time_scale", "scale": scale}))
		b.add_theme_font_size_override("font_size", 12)
		_scale_bar.add_child(b)
	var fold := UI.button("–", func(): pass)
	fold.add_theme_font_size_override("font_size", 12)
	fold.tooltip_text = "Fold the panel away"
	fold.pressed.connect(func():
		_folded = not _folded
		_details.visible = not _folded
		fold.text = "+" if _folded else "–"
		fold.tooltip_text = "Show the details" if _folded else "Fold the panel away"
		_panel.reset_size())
	_scale_bar.add_child(fold)
	_details = UI.label("[ ] time compression  ·  P pause  ·  M next view\ndrag to pan  ·  double-click to centre  ·  wheel zoom", UI.DIM, 11)
	p[1].add_child(_details)
	var legend := UI.panel("Traffic")
	_legend = legend[0]
	_legend.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_legend.position = Vector2(-236, 56)
	_legend.custom_minimum_size = Vector2(220, 0)
	add_child(_legend)
	for op in SystemMap.FLEET_COLOURS:
		legend[1].add_child(UI.label("o  " + op, SystemMap.FLEET_COLOURS[op], 12))
	set_view(sim.data.balance["flight"].get("transit_view", "ship"))
	add_child(TransitAudio.new(sim))
	var calls := DepartureCalls.new(sim)
	calls.said.connect(func(text: String): copilot.emit(text))
	add_child(calls)


func set_view(name: String) -> void:
	view_name = name
	# The ship and orbit views look at the ship from outside, in vacuum: silent there.
	ShipAudio.set_outside(sim.data, name in ["ship", "orbit"])
	var flat := name == "map"
	_map.visible = flat
	_panel.visible = flat
	_legend.visible = flat
	if _view != null:
		_view.queue_free()
		_overlay.queue_free()
		_view = null
		_overlay = null
	match name:
		"ship":
			_view = FollowView.new(sim)
			_overlay = FollowHud.new(sim, _view)
		"cockpit":
			_view = TransitView.new(sim)
			_overlay = TransitHud.new(sim, _view)
		"orbit":
			_view = OrbitView.new(sim)
			_overlay = OrbitHud.new(sim, _view)
	if _view != null:
		add_child(_view)
		_overlay.theme = UI.make_theme()
		add_child(_overlay)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("transit_view"):
		set_view(VIEWS[(VIEWS.find(view_name) + 1) % VIEWS.size()])


func _process(_dt: float) -> void:
	var s = sim.state
	var loc: Dictionary = s.location
	if loc.get("status") == "transit" and _panel.visible:
		var left: float = float(loc["arrive_t"]) - s.time_s
		var pos := Navigation.transit_position(loc, s.time_s)
		var flying := 0
		for npc in s.npcs:
			if npc["location"]["status"] == "transit":
				flying += 1
		var head := "%s  to  %s\nArrive in %s  (%s)%s" % [
			sim.data.locations[loc["from"]]["name"], sim.data.locations[loc["to"]]["name"],
			UI.duration(left), _date(float(loc["arrive_t"])), "   PAUSED" if s.paused else ""]
		_hud.text = head if _folded else "%s\nRemaining %s  ·  %d other ships under way\n%s" % [
			head, UI.km(V.distance(pos, loc["to_pos"])), flying, UI.signature(sim)]
		for i in sim.data.balance["time"]["scales"].size():
			var b: Button = _scale_bar.get_child(i)
			b.modulate = UI.AMBER if float(sim.data.balance["time"]["scales"][i]) == s.time_scale else Color.WHITE


## A time scale as a button: 1000 -> "1k", 1000000 -> "1M".
static func _short(x: float) -> String:
	if x >= 1.0e6:
		return "%dM" % int(x / 1.0e6)
	if x >= 1.0e3:
		return "%dk" % int(x / 1.0e3)
	return "%d" % int(x)


func _date(t: float) -> String:
	return Time.get_datetime_string_from_unix_time(int(t + 946728000.0)).replace("T", " ").substr(0, 16)


func _exit_tree() -> void:
	ShipAudio.set_outside(sim.data, false)
