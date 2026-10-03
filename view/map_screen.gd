## In transit: a top-down orbital map of the trip frame (Earth for cislunar trips),
## drawn from real positions, with the ship riding its transfer under time compression.
## Mouse wheel zooms.
extends Control

const UI := preload("res://view/ui/ui_kit.gd")
const V := preload("res://sim/v3.gd")
const Navigation := preload("res://sim/navigation.gd")

const DAY := 86400.0

var sim
var _zoom := 1.0
var _hud: Label
var _scale_bar: HBoxContainer
var _font: Font


func _init(owner_sim) -> void:
	sim = owner_sim
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	_font = UI.make_theme().default_font
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


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = minf(_zoom * 1.2, 40.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = maxf(_zoom / 1.2, 0.5)


func _process(_dt: float) -> void:
	var s = sim.state
	var loc: Dictionary = s.location
	if loc.get("status") == "transit":
		var left: float = float(loc["arrive_t"]) - s.time_s
		var pos := Navigation.transit_position(loc, s.time_s)
		var remaining := V.distance(pos, loc["to_pos"])
		_hud.text = "%s  →  %s\nArrive in %s  (%s)\nRemaining %s\nTime ×%d%s" % [
			sim.data.places[loc["from"]]["name"], sim.data.places[loc["to"]]["name"],
			UI.duration(left), _date(float(loc["arrive_t"])), UI.km(remaining), int(s.time_scale), "   PAUSED" if s.paused else ""]
	for i in _scale_bar.get_child_count():
		var b: Button = _scale_bar.get_child(i)
		b.modulate = UI.AMBER if float(sim.data.balance["time"]["scales"][i]) == s.time_scale else Color.WHITE
	queue_redraw()


func _date(t: float) -> String:
	return Time.get_datetime_string_from_unix_time(int(t + 946728000.0)).replace("T", " ").substr(0, 16)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UI.BG)
	var s = sim.state
	var frame: String = s.location.get("frame", "earth")
	var eph = sim.ephemeris
	var t: float = s.time_s
	var centre := size * 0.5 + Vector2(120, 10)
	var radius_m := 4.8e8 / _zoom
	var px := (minf(size.x, size.y) * 0.46) / radius_m
	var to_screen := func(p: Array) -> Vector2:
		return centre + Vector2(p[0], -p[1]) * px

	# Faint range rings every 100,000 km.
	for r in range(1, 6):
		draw_arc(centre, r * 1.0e8 * px, 0.0, TAU, 96, Color(UI.PANEL_EDGE, 0.35), 1.0)
	# The Moon's path over the next month.
	var path := PackedVector2Array()
	for i in 121:
		path.append(to_screen.call(eph.relative("moon", frame, t + i * 0.25 * DAY)))
	draw_polyline(path, Color(UI.DIM, 0.5), 1.0)
	# Bodies.
	for body in ["earth", "moon"]:
		var at: Vector2 = to_screen.call(eph.relative(body, frame, t))
		var r := maxf(float(sim.data.bodies[body]["radius_m"]) * px, 4.0)
		draw_circle(at, r, Color("3b6ea8") if body == "earth" else Color("9a978f"))
		draw_string(_font, at + Vector2(r + 4, -r), sim.data.bodies[body]["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.DIM)
	# Places.
	var dest: String = s.location.get("to", "")
	for place in sim.data.places:
		var at: Vector2 = to_screen.call(eph.relative(place, frame, t))
		var col := UI.AMBER if place == dest else UI.TEXT
		draw_rect(Rect2(at - Vector2(3, 3), Vector2(6, 6)), col)
		draw_string(_font, at + Vector2(6, 14), sim.data.places[place]["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
	# The ship and its transfer.
	if s.location.get("status") == "transit":
		var a: Vector2 = to_screen.call(s.location["from_pos"])
		var b: Vector2 = to_screen.call(s.location["to_pos"])
		draw_dashed_line(a, b, Color(UI.AMBER, 0.6), 1.5, 8.0)
		var ship: Vector2 = to_screen.call(Navigation.transit_position(s.location, t))
		var dir := (b - a).normalized()
		var side := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([ship + dir * 9, ship - dir * 6 + side * 5, ship - dir * 6 - side * 5]), UI.GOOD)
		var tau := (t - float(s.location["depart_t"])) / (float(s.location["arrive_t"]) - float(s.location["depart_t"]))
		draw_string(_font, ship + Vector2(10, -8), "BRAKING" if tau > 0.5 else "ACCELERATING", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI.GOOD)
