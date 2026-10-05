## Overlay for the ship view in transit: a caption (the ship, the trip, the burn),
## the set-up the director has chosen, and how to take the camera.
extends Control

const UI := preload("res://view/ui/ui_kit.gd")

var sim
var view
var _font: Font


func _init(owner_sim, follow_view) -> void:
	sim = owner_sim
	view = follow_view
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
	var ship: Dictionary = sim.state.ship
	var x := 24.0
	var y := 72.0
	draw_string(_font, Vector2(x, y), String(ship.get("name", "")).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UI.AMBER)
	y += 22
	draw_string(_font, Vector2(x, y), String(sim.data.ships[ship["hull"]]["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.DIM)
	y += 26
	draw_string(_font, Vector2(x, y), "%s  to  %s" % [sim.data.locations[loc["from"]]["name"], sim.data.locations[loc["to"]]["name"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UI.TEXT)
	y += 22
	draw_string(_font, Vector2(x, y), "%s   ·   %.2f km/s   ·   %s to go   ·   arrive in %s" % [r.get("phase", ""), float(r.get("speed", 0.0)) / 1000.0, UI.km(float(r.get("remaining", 0.0))), UI.duration(float(r.get("eta", 0.0)))],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.AMBER if r.get("phase", "") != "COASTING" else UI.DIM)
	y += 20
	draw_string(_font, Vector2(x, y), "Time ×%d%s" % [int(sim.state.time_scale), "   PAUSED" if sim.state.paused else ""], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.DIM)
	var h := size.y
	var w := size.x
	if view.mode == "director":
		var label := "DIRECTOR  ·  " + String(view.shot_label)
		var lw := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(_font, Vector2(w - lw - 24, 72), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(UI.TEXT, 0.7))
		draw_string(_font, Vector2(16, h - 82), "Drag or wheel to take the camera    M  next view    [ ]  time compression    P  pause", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.DIM)
	else:
		draw_string(_font, Vector2(w - 220, 72), "FREE CAMERA", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(UI.TEXT, 0.7))
		draw_string(_font, Vector2(16, h - 82), "Drag  orbit    Wheel  zoom    Arrows  orbit    leave it a few seconds for the director    M  next view", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.DIM)
