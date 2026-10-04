## Overlay for the god's-eye orbit view: burn phase and readouts, and the view keys.
extends Control

const UI := preload("res://view/ui/ui_kit.gd")

var sim
var view
var _font: Font


func _init(owner_sim, orbit_view) -> void:
	sim = owner_sim
	view = orbit_view
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_font = UI.make_theme().default_font


func _process(_dt: float) -> void:
	queue_redraw()


func _draw() -> void:
	var r: Dictionary = view.readout
	var loc: Dictionary = sim.state.location
	if r.is_empty() or loc.get("status") != "transit":
		return
	var x := 24.0
	var y := 74.0
	draw_rect(Rect2(12, 50, 330, 256), Color(0.07, 0.08, 0.09, 0.8))
	draw_rect(Rect2(12, 50, 330, 3), UI.HAZARD)
	draw_string(_font, Vector2(x, y), "%s  to  %s" % [sim.data.places[loc["from"]]["name"], sim.data.places[loc["to"]]["name"]], HORIZONTAL_ALIGNMENT_LEFT, 310, 14, UI.TEXT)
	if r.get("route", "") != "":
		draw_string(_font, Vector2(x + 200, y + 28), r["route"], HORIZONTAL_ALIGNMENT_LEFT, 120, 11, UI.DIM)
	y += 28
	draw_string(_font, Vector2(x, y), r["phase"], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UI.AMBER if r["phase"] != "COASTING" else UI.DIM)
	y += 26
	for row in [
		["VELOCITY", "%.2f km/s" % (r["speed"] / 1000.0)],
		["THRUST", "%.2f milli-g" % (r["accel"] / 9.80665 * 1000.0)],
		["TO GO", UI.km(r["remaining"])],
		["ARRIVE", UI.duration(r["eta"])],
		["MOON ALT", UI.km(r["moon_alt"]) if r["moon_alt"] < 6.0e7 else "—"],
		["COMMS", "%.3f s light time" % float(r.get("light_s", 0.0))],
		["LEAD", "%.2f arcsec point-ahead" % (rad_to_deg(float(r.get("point_ahead", 0.0))) * 3600.0)],
		["TIME", "x%d%s" % [int(sim.state.time_scale), "  PAUSED" if sim.state.paused else ""]],
	]:
		draw_string(_font, Vector2(x, y), row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.DIM)
		draw_string(_font, Vector2(x + 96, y), row[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UI.TEXT)
		y += 20
	var h := size.y
	draw_string(_font, Vector2(16, h - 82), "M  next view (orbit · cockpit · map)    [ ]  time compression    P  pause", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.DIM)
	draw_string(_font, Vector2(size.x - 330, 70), "Earth and Moon to scale · ship enlarged to be seen", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(UI.DIM, 0.8))
