## In transit: the full-screen system map with a transit readout and time controls.
extends Control

const UI := preload("res://view/ui/ui_kit.gd")
const V := preload("res://sim/v3.gd")
const Navigation := preload("res://sim/navigation.gd")
const SystemMap := preload("res://view/system_map.gd")

var sim
var _hud: Label
var _scale_bar: HBoxContainer


func _init(owner_sim) -> void:
	sim = owner_sim
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	var map := SystemMap.new(sim)
	map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map.frame = sim.state.location.get("frame", "earth")
	map.centre_offset = Vector2(120, 10)
	add_child(map)
	var p := UI.panel("Transit")
	p[0].position = Vector2(16, 56)
	p[0].custom_minimum_size = Vector2(380, 0)
	add_child(p[0])
	_hud = UI.label("")
	p[1].add_child(_hud)
	_scale_bar = HBoxContainer.new()
	p[1].add_child(_scale_bar)
	for scale in sim.data.balance["time"]["scales"]:
		_scale_bar.add_child(UI.button("×%d" % int(scale), func(): sim.apply({"type": "set_time_scale", "scale": scale})))
	p[1].add_child(UI.label("[ ] change time compression  ·  P pause  ·  wheel zoom", UI.DIM, 12))
	var legend := UI.panel("Traffic")
	legend[0].set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	legend[0].position = Vector2(-236, 56)
	legend[0].custom_minimum_size = Vector2(220, 0)
	add_child(legend[0])
	for op in SystemMap.FLEET_COLOURS:
		legend[1].add_child(UI.label("●  " + op, SystemMap.FLEET_COLOURS[op], 12))


func _process(_dt: float) -> void:
	var s = sim.state
	var loc: Dictionary = s.location
	if loc.get("status") == "transit":
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
