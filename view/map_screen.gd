## In transit, three views cycled with M: the god's-eye orbit view (default), the
## cockpit, and the flat system map. Time compression works in all of them.
extends Control

const UI := preload("res://view/ui/ui_kit.gd")
const V := preload("res://sim/v3.gd")
const Navigation := preload("res://sim/navigation.gd")
const SystemMap := preload("res://view/system_map.gd")
const TransitView := preload("res://view/transit_view.gd")
const TransitHud := preload("res://view/transit_hud.gd")
const OrbitView := preload("res://view/orbit_view.gd")
const OrbitHud := preload("res://view/orbit_hud.gd")
const VIEWS := ["orbit", "cockpit", "map"]

var sim
var view_name := "orbit"
var _map: Control
var _panel: Control
var _legend: Control
var _hud: Label
var _scale_bar: HBoxContainer
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
	_panel.custom_minimum_size = Vector2(380, 0)
	add_child(_panel)
	_hud = UI.label("")
	p[1].add_child(_hud)
	_scale_bar = HBoxContainer.new()
	p[1].add_child(_scale_bar)
	for scale in sim.data.balance["time"]["scales"]:
		_scale_bar.add_child(UI.button("×%d" % int(scale), func(): sim.apply({"type": "set_time_scale", "scale": scale})))
	p[1].add_child(UI.label("[ ] time compression  ·  P pause  ·  M next view  ·  wheel zoom", UI.DIM, 12))
	var legend := UI.panel("Traffic")
	_legend = legend[0]
	_legend.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_legend.position = Vector2(-236, 56)
	_legend.custom_minimum_size = Vector2(220, 0)
	add_child(_legend)
	for op in SystemMap.FLEET_COLOURS:
		legend[1].add_child(UI.label("●  " + op, SystemMap.FLEET_COLOURS[op], 12))
	set_view(sim.data.balance["flight"].get("transit_view", "orbit"))


func set_view(name: String) -> void:
	view_name = name
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
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
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
		_hud.text = "%s  →  %s\nArrive in %s  (%s)\nRemaining %s\nTime ×%d%s\n%d other ships under way" % [
			sim.data.places[loc["from"]]["name"], sim.data.places[loc["to"]]["name"],
			UI.duration(left), _date(float(loc["arrive_t"])), UI.km(V.distance(pos, loc["to_pos"])),
			int(s.time_scale), "   PAUSED" if s.paused else "", flying]
		for i in _scale_bar.get_child_count():
			var b: Button = _scale_bar.get_child(i)
			b.modulate = UI.AMBER if float(sim.data.balance["time"]["scales"][i]) == s.time_scale else Color.WHITE


func _date(t: float) -> String:
	return Time.get_datetime_string_from_unix_time(int(t + 946728000.0)).replace("T", " ").substr(0, 16)
