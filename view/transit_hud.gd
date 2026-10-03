## Cockpit overlay for transit: canopy frame, dashboard with burn readouts, a small
## nav plot in the centre bezel, and markers on the destination, origin, Earth and Moon.
extends Control

const UI := preload("res://view/ui/ui_kit.gd")
const SystemMap := preload("res://view/system_map.gd")

const DASH_H := 220.0
const PANEL := Color("23272b")
const PILLAR := Color("1b1e21")

var sim
var view
var _font: Font
var _plot: Control


func _init(owner_sim, transit_view) -> void:
	sim = owner_sim
	view = transit_view
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_font = UI.make_theme().default_font
	_plot = SystemMap.new(sim)
	_plot.show_npc_labels = false
	_plot.frame = sim.state.location.get("frame", "earth")
	add_child(_plot)


func _process(_dt: float) -> void:
	var w := size.x
	_plot.position = Vector2(w * 0.5 - 170.0, size.y - DASH_H + 22.0)
	_plot.size = Vector2(340.0, DASH_H - 34.0)
	queue_redraw()


func _draw() -> void:
	var r: Dictionary = view.readout
	# The screen lingers a frame after arrival; draw nothing once we are off the transfer.
	if r.is_empty() or sim.state.location.get("status") != "transit":
		return
	var w := size.x
	var h := size.y
	var top := 32.0
	var dash_top := h - DASH_H
	_markers(r, dash_top)
	# Canopy.
	draw_colored_polygon(PackedVector2Array([Vector2(0, top), Vector2(90, top), Vector2(190, dash_top), Vector2(0, dash_top)]), PILLAR)
	draw_colored_polygon(PackedVector2Array([Vector2(w, top), Vector2(w - 90, top), Vector2(w - 190, dash_top), Vector2(w, dash_top)]), PILLAR)
	draw_rect(Rect2(0, top, w, 14), PILLAR)
	# Dashboard.
	draw_rect(Rect2(0, dash_top, w, DASH_H), PANEL)
	draw_rect(Rect2(0, dash_top, w, 10), UI.HAZARD)
	for i in int(w / 28.0) + 2:
		draw_colored_polygon(PackedVector2Array([Vector2(i * 28, dash_top), Vector2(i * 28 + 12, dash_top), Vector2(i * 28 + 2, dash_top + 10), Vector2(i * 28 - 10, dash_top + 10)]), UI.BG)
	draw_rect(Rect2(w * 0.5 - 178.0, dash_top + 16.0, 356.0, DASH_H - 22.0), Color("2e3338"))
	var x := 24.0
	var y := dash_top + 40.0
	var phase_col := UI.AMBER if r["phase"] == "FLIP" else UI.GOOD
	draw_string(_font, Vector2(x, y), r["phase"], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, phase_col)
	y += 30.0
	for row in [
		["VELOCITY", "%.2f km/s" % (r["speed"] / 1000.0)],
		["THRUST", "%.2f milli-g" % (r["accel"] / 9.80665 * 1000.0)],
		["TO GO", UI.km(r["remaining"])],
		["ARRIVE", UI.duration(r["eta"])],
		["TIME", "x%d%s" % [int(sim.state.time_scale), "  PAUSED" if sim.state.paused else ""]],
	]:
		draw_string(_font, Vector2(x, y), row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.DIM)
		draw_string(_font, Vector2(x + 100, y), row[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UI.TEXT)
		y += 22.0
	var rx := w * 0.5 + 200.0
	var ry := dash_top + 40.0
	draw_string(_font, Vector2(rx, ry), "EARTH  %s" % UI.km(r["earth_km"] * 1000.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("7fb0e0"))
	draw_string(_font, Vector2(rx, ry + 22), "MOON   %s" % UI.km(r["moon_km"] * 1000.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("c9c4b6"))
	draw_string(_font, Vector2(rx, ry + 58), "[ ] time compression", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.DIM)
	draw_string(_font, Vector2(rx, ry + 78), "M map    P pause", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.DIM)
	draw_string(_font, Vector2(rx, ry + 98), "Arrows look  C centre  Z telescope%s" % ("  (ON)" if view.telescope else ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.AMBER if view.telescope else UI.DIM)
	draw_string(_font, Vector2(rx, ry + 128), "Co-pilot has the burn.", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.DIM)


func _markers(r: Dictionary, dash_top: float) -> void:
	var cam: Camera3D = view.camera
	var loc: Dictionary = sim.state.location
	var marks := [
		[r["dest_dir"], sim.data.places[loc["to"]]["name"].to_upper(), UI.AMBER, true],
		[r["origin_dir"], "FROM " + sim.data.places[loc["from"]]["name"], UI.DIM, false],
		[r["earth_dir"], "EARTH", Color("7fb0e0"), false],
		[r["moon_dir"], "MOON", Color("c9c4b6"), false],
	]
	for m in marks:
		var p: Vector3 = m[0] * 1000.0
		if cam.is_position_behind(p):
			continue
		var at := cam.unproject_position(p)
		if at.y > dash_top - 10.0 or at.y < 40.0:
			continue
		if m[3]:
			draw_rect(Rect2(at - Vector2(12, 12), Vector2(24, 24)), m[2], false, 2.0)
			draw_string(_font, at + Vector2(16, -4), "%s  %s" % [m[1], UI.km(r["remaining"])], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, m[2])
		else:
			draw_line(at + Vector2(-6, 0), at + Vector2(6, 0), m[2], 1.0)
			draw_line(at + Vector2(0, -6), at + Vector2(0, 6), m[2], 1.0)
			draw_string(_font, at + Vector2(10, -6), m[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, m[2])
