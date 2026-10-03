## In transit: the cockpit view out of the window (default) or the full system map.
## M toggles between them; time compression works in both.
extends Control

const UI := preload("res://view/ui/ui_kit.gd")
const V := preload("res://sim/v3.gd")
const Navigation := preload("res://sim/navigation.gd")
const SystemMap := preload("res://view/system_map.gd")
const TransitView := preload("res://view/transit_view.gd")
const TransitHud := preload("res://view/transit_hud.gd")

var sim
var cockpit := true
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
	p[1].add_child(UI.label("[ ] time compression  ·  P pause  ·  M cockpit  ·  wheel zoom", UI.DIM, 12))
	var legend := UI.panel("Traffic")
	_legend = legend[0]
	_legend.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_legend.position = Vector2(-236, 56)
	_legend.custom_minimum_size = Vector2(220, 0)
	add_child(_legend)
	for op in SystemMap.FLEET_COLOURS:
		legend[1].add_child(UI.label("●  " + op, SystemMap.FLEET_COLOURS[op], 12))
	_set_mode(sim.data.balance["flight"].get("default_view", "cockpit") == "cockpit")


func _set_mode(want_cockpit: bool) -> void:
	cockpit = want_cockpit
	_map.visible = not cockpit
	_panel.visible = not cockpit
	_legend.visible = not cockpit
	if cockpit and _view == null:
		_view = TransitView.new(sim)
		add_child(_view)
		_overlay = TransitHud.new(sim, _view)
		_overlay.theme = UI.make_theme()
		add_child(_overlay)
	elif not cockpit and _view != null:
		_view.queue_free()
		_overlay.queue_free()
		_view = null
		_overlay = null


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		_set_mode(not cockpit)


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
