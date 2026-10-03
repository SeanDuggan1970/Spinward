## The cockpit: window pillars, an instrument dashboard, and the classic Elite-style
## 3D scanner. The scanner is an ellipse for the ship's horizontal plane (forward is
## up the screen); each contact sits at its bearing and range on the plane, with a
## stalk rising or dropping to show how far above or below the ship it is.
## A compass dot gives the port's direction: solid when ahead, hollow when behind.
extends Control

const UI := preload("res://view/ui/ui_kit.gd")
const ShipStats := preload("res://sim/ship_stats.gd")

const DASH_H := 220.0
const SCANNER_RX := 200.0
const SCANNER_RY := 74.0
const PANEL := Color("23272b")
const PANEL_DARK := Color("16191c")
const PILLAR := Color("1b1e21")
const SCANNER_LINE := Color(0.95, 0.66, 0.19, 0.55)

var flight
var _font: Font
var _message: Label
var show_keys := true


func _init(owner_flight) -> void:
	flight = owner_flight
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_font = UI.make_theme().default_font
	_message = UI.label("", UI.AMBER, 20)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_message.position.y = 92
	_message.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_message)
	get_tree().create_timer(12.0).timeout.connect(func(): show_keys = false)


func _process(_dt: float) -> void:
	_message.visible = flight.clock < flight.message_until
	_message.text = flight.message
	_message.add_theme_color_override("font_color", flight.message_colour)
	queue_redraw()


func _draw() -> void:
	if flight.readout.is_empty() or flight.view_mode == "beauty":
		return
	var w := size.x
	var h := size.y
	var cockpit: bool = flight.view_mode == "cockpit"
	if cockpit:
		_draw_frame(w, h)
		_draw_crosshair(Vector2(w * 0.5, (h - DASH_H) * 0.5 + 16.0))
	_draw_markers()
	_draw_guidance(w, h)
	_draw_dashboard(w, h)
	if show_keys:
		_draw_keys(w)


# --- Window frame -----------------------------------------------------------

func _draw_frame(w: float, h: float) -> void:
	var top := 32.0
	var dash_top := h - DASH_H
	# Canopy pillars and a header bar: the cockpit of a working hauler, not a fighter.
	draw_colored_polygon(PackedVector2Array([Vector2(0, top), Vector2(90, top), Vector2(190, dash_top), Vector2(0, dash_top)]), PILLAR)
	draw_colored_polygon(PackedVector2Array([Vector2(w, top), Vector2(w - 90, top), Vector2(w - 190, dash_top), Vector2(w, dash_top)]), PILLAR)
	draw_rect(Rect2(0, top, w, 14), PILLAR)
	draw_line(Vector2(90, top + 14), Vector2(190, dash_top), Color("2e3338"), 3.0)
	draw_line(Vector2(w - 90, top + 14), Vector2(w - 190, dash_top), Color("2e3338"), 3.0)
	draw_line(Vector2(90, top + 14), Vector2(w - 90, top + 14), Color("2e3338"), 3.0)
	for y in range(int(top + 60), int(dash_top - 20), 70):
		var f := (y - top) / (dash_top - top)
		_rivet(Vector2(lerpf(45.0, 95.0, f), y))
		_rivet(Vector2(w - lerpf(45.0, 95.0, f), y))


func _rivet(p: Vector2) -> void:
	draw_circle(p, 3.0, Color("3a4046"))
	draw_circle(p + Vector2(-0.8, -0.8), 1.2, Color("5a6168"))


func _draw_crosshair(c: Vector2) -> void:
	var col := Color(UI.AMBER, 0.85)
	for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		draw_line(c + d * 8.0, c + d * 22.0, col, 2.0)


# --- Projected markers (port box, velocity vector) --------------------------

func _draw_markers() -> void:
	var cam: Camera3D = flight.camera
	var r: Dictionary = flight.readout
	var port := Vector3(0, 0, flight.station["port_z"])
	var dash_top := size.y - DASH_H
	if not cam.is_position_behind(port):
		var at := cam.unproject_position(port)
		if at.y < dash_top:
			var colour := UI.GOOD if _all_ok() else UI.AMBER
			draw_rect(Rect2(at - Vector2(14, 14), Vector2(28, 28)), colour, false, 2.0)
			draw_string(_font, at + Vector2(18, -6), "PORT %.0f m" % r["range"], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, colour)
	var v: Vector3 = flight.velocity
	if v.length() > 0.05:
		var ahead: Vector3 = flight.ship_node.position + v.normalized() * 200.0
		if not cam.is_position_behind(ahead):
			var p := cam.unproject_position(ahead)
			if p.y < dash_top:
				draw_arc(p, 7.0, 0.0, TAU, 20, UI.GOOD, 1.5)
				for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, -1)]:
					draw_line(p + d * 7.0, p + d * 13.0, UI.GOOD, 1.5)


## The co-pilot's next instruction, on a strip just above the dashboard.
func _draw_guidance(w: float, h: float) -> void:
	var g: Dictionary = flight.guidance()
	if g.is_empty():
		return
	var text: String = g["text"]
	var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	var y := h - DASH_H - 22.0
	draw_rect(Rect2(w * 0.5 - tw * 0.5 - 12, y - 18, tw + 24, 26), Color(0.06, 0.07, 0.08, 0.8))
	draw_string(_font, Vector2(w * 0.5 - tw * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UI.GOOD if text.begins_with("Good") else UI.AMBER)


func _all_ok() -> bool:
	var r: Dictionary = flight.readout
	return r["ok_speed"] and r["ok_align"] and r["ok_roll"]


# --- Dashboard ---------------------------------------------------------------

func _draw_dashboard(w: float, h: float) -> void:
	var top := h - DASH_H
	draw_rect(Rect2(0, top, w, DASH_H), PANEL)
	# Hazard-striped coaming along the top edge of the panel.
	draw_rect(Rect2(0, top, w, 10), UI.HAZARD)
	for i in int(w / 28.0) + 2:
		draw_colored_polygon(PackedVector2Array([Vector2(i * 28, top), Vector2(i * 28 + 12, top), Vector2(i * 28 + 2, top + 10), Vector2(i * 28 - 10, top + 10)]), UI.BG)
	var centre := Vector2(w * 0.5, top + DASH_H * 0.5)
	_draw_scanner(centre)
	_draw_left_panel(Rect2(24, top + 22, centre.x - SCANNER_RX - 60, DASH_H - 34))
	_draw_right_panel(Rect2(centre.x + SCANNER_RX + 36, top + 22, w - centre.x - SCANNER_RX - 60, DASH_H - 34))


func _draw_scanner(c: Vector2) -> void:
	var rx := SCANNER_RX
	var ry := SCANNER_RY
	# Bezel and glass.
	draw_colored_polygon(_ellipse(c, rx + 14, ry + 14, 72), Color("2e3338"))
	draw_colored_polygon(_ellipse(c, rx + 4, ry + 4, 72), PANEL_DARK)
	draw_colored_polygon(_ellipse(c, rx, ry, 72), Color("0d1410"))
	# Range rings, cross lines and the forward field-of-view wedge.
	for f in [1.0, 0.66, 0.33]:
		draw_polyline(_ellipse(c, rx * f, ry * f, 72, true), SCANNER_LINE, 1.0)
	draw_line(c - Vector2(rx, 0), c + Vector2(rx, 0), Color(SCANNER_LINE, 0.35), 1.0)
	draw_line(c - Vector2(0, ry), c + Vector2(0, ry), Color(SCANNER_LINE, 0.35), 1.0)
	draw_line(c, c + Vector2(-rx * 0.62, -ry * 0.78), Color(SCANNER_LINE, 0.35), 1.0)
	draw_line(c, c + Vector2(rx * 0.62, -ry * 0.78), Color(SCANNER_LINE, 0.35), 1.0)
	var range_m: float = flight.scanner_range()
	var basis: Basis = flight.ship_node.global_transform.basis
	var origin: Vector3 = flight.ship_node.global_position
	var contacts: Array = flight.contacts()
	# Draw far-below first so nearer, higher stalks sit on top.
	contacts.sort_custom(func(a, b): return (basis.inverse() * (a["pos"] - origin)).y < (basis.inverse() * (b["pos"] - origin)).y)
	for contact in contacts:
		var local: Vector3 = basis.inverse() * (contact["pos"] - origin)
		if local.length() > range_m:
			continue
		# Square-root radial scale: close contacts spread out, far ones stay on the glass.
		var d := local.length()
		var k := sqrt(d / range_m) / maxf(d / range_m, 1e-6) / range_m
		# Plane position: x right, -z forward (up the screen). Height becomes the stalk.
		var plane := c + Vector2(local.x * k * rx, local.z * k * ry)
		var tip := plane - Vector2(0, local.y * k * ry * 1.6)
		var col: Color = contact["colour"]
		draw_line(plane, tip, col, 1.5)
		var s := 5.0 if contact["kind"] == "station" else 3.0
		draw_rect(Rect2(tip - Vector2(s, s * 0.6), Vector2(s * 2, s * 1.2)), col)
	# Own ship at the centre.
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -6), c + Vector2(4, 4), c + Vector2(-4, 4)]), UI.TEXT)
	var label := "SCANNER  %s" % (("%d m" % int(range_m)) if range_m < 1000.0 else ("%d km" % int(range_m / 1000.0)))
	draw_string(_font, c + Vector2(-rx - 6, ry + 24), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI.DIM)
	draw_string(_font, c + Vector2(rx - 50, ry + 24), "G range", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI.DIM)


func _ellipse(c: Vector2, rx: float, ry: float, n: int, closed: bool = false) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in (n + 1 if closed else n):
		var a := TAU * float(i) / float(n)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


func _draw_left_panel(rect: Rect2) -> void:
	var r: Dictionary = flight.readout
	var d: Dictionary = flight.tune_dock
	var x := rect.position.x
	var y := rect.position.y + 14
	var rows := [
		["RANGE", "%.1f m" % r["range"], r["range"] < 50.0],
		["CLOSING", "%.2f m/s" % r["closing"], r["closing"] > 0.0 and r["ok_speed"]],
		["SPEED", "%.2f / %.1f" % [r["speed"], d["max_speed_mps"]], r["ok_speed"]],
		["ALIGN", "%.1f° / %d°" % [r["align"], int(d["max_angle_deg"])], r["ok_align"]],
		["ROLL KEY", "%.1f° / %d°" % [rad_to_deg(r["roll_err"]), int(d["max_roll_error_deg"])], r["ok_roll"]],
		["LATERAL", "%.1f m" % r["lateral"], r["lateral"] < 3.0],
	]
	for row in rows:
		_lamp(Vector2(x + 6, y - 4), row[2])
		draw_string(_font, Vector2(x + 18, y), row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.DIM)
		draw_string(_font, Vector2(x + 100, y), row[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UI.GOOD if row[2] else UI.TEXT)
		y += 24
	# Speed bar against the capture limit.
	var bar := Rect2(x, y, minf(rect.size.x - 10, 260), 10)
	draw_rect(bar, PANEL_DARK)
	var limit := float(d["max_speed_mps"])
	var frac := clampf(float(r["speed"]) / (limit * 4.0), 0.0, 1.0)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), UI.GOOD if r["ok_speed"] else UI.WARN)
	draw_line(bar.position + Vector2(bar.size.x * 0.25, -3), bar.position + Vector2(bar.size.x * 0.25, 13), UI.TEXT, 1.0)


func _draw_right_panel(rect: Rect2) -> void:
	var r: Dictionary = flight.readout
	var x := rect.position.x
	var y := rect.position.y + 14
	var cc := Vector2(x + 44, y + 40)
	if r["range"] < 400.0:
		_draw_axis_display(cc)
	else:
		_draw_compass(cc, x, y)
	_draw_right_lamps(x, y)


## Inside 400 m: where the station's axis is relative to you. Centre the dot to sit
## on the axis; the ring is the capture zone.
func _draw_axis_display(cc: Vector2) -> void:
	var g: Dictionary = flight.guidance()
	draw_circle(cc, 36, PANEL_DARK)
	draw_arc(cc, 36, 0, TAU, 40, SCANNER_LINE, 1.5)
	draw_line(cc - Vector2(36, 0), cc + Vector2(36, 0), Color(SCANNER_LINE, 0.3), 1.0)
	draw_line(cc - Vector2(0, 36), cc + Vector2(0, 36), Color(SCANNER_LINE, 0.3), 1.0)
	var capture: float = float(flight.tune_dock["capture_distance_m"])
	draw_arc(cc, 30.0 * capture / 30.0, 0, TAU, 24, UI.GOOD, 1.0)
	if not g.is_empty():
		var o: Vector3 = g["offset_local"]
		var p := Vector2(o.x, -o.y)
		var pr := clampf(p.length(), 0.0, 30.0)
		var dot := cc + (p.normalized() * pr if p.length() > 1e-3 else Vector2.ZERO)
		draw_circle(dot, 5.0, UI.GOOD if p.length() <= capture else UI.AMBER)
	draw_string(_font, cc + Vector2(-40, 56), "AXIS (30 m)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI.DIM)


func _draw_compass(cc: Vector2, x: float, y: float) -> void:
	draw_circle(cc, 36, PANEL_DARK)
	draw_arc(cc, 36, 0, TAU, 40, SCANNER_LINE, 1.5)
	draw_line(cc - Vector2(36, 0), cc + Vector2(36, 0), Color(SCANNER_LINE, 0.3), 1.0)
	draw_line(cc - Vector2(0, 36), cc + Vector2(0, 36), Color(SCANNER_LINE, 0.3), 1.0)
	var to_port: Vector3 = flight.ship_node.global_transform.basis.inverse() * (Vector3(0, 0, flight.station["port_z"]) - flight.ship_node.global_position)
	var dir := to_port.normalized()
	var dot := cc + Vector2(dir.x, -dir.y) * 30.0
	if dir.z < 0.0:
		draw_circle(dot, 5.0, UI.GOOD)
	else:
		draw_arc(dot, 5.0, 0, TAU, 16, UI.WARN, 2.0)
	draw_string(_font, Vector2(x + 4, y + 96), "COMPASS · PORT", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI.DIM)


func _draw_right_lamps(x: float, y: float) -> void:
	var r: Dictionary = flight.readout
	# Mode lamps.
	var lx := x + 110
	var ly := y + 4
	var lamps := [
		["ASSIST " + String(r["assist"]).to_upper(), r["assist"] != "manual"],
		["SPIN MATCH", r["spin_match"] and r["assist"] != "manual"],
		["CAPTURE READY", _all_ok()],
		["CONTACTS %d" % flight.bumps, flight.bumps == 0],
	]
	for l in lamps:
		_lamp(Vector2(lx, ly - 4), l[1])
		draw_string(_font, Vector2(lx + 12, ly), l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.TEXT if l[1] else UI.DIM)
		ly += 22
	var ship: Dictionary = flight.sim.state.ship
	draw_string(_font, Vector2(lx, ly + 8), "FUEL %.2f t   %s" % [ship["fuel_t"], UI.money(flight.sim.state.credits)], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.DIM)
	draw_string(_font, Vector2(lx, ly + 28), "C view  H keys  T tug%s" % ("  K computer" if ShipStats.has_docking_computer(ship, flight.sim.data) else ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI.DIM)


func _lamp(at: Vector2, on: bool) -> void:
	draw_circle(at, 5.0, Color("101214"))
	draw_circle(at, 3.6, UI.GOOD if on else Color("4a2a24"))


func _draw_keys(w: float) -> void:
	var lines := ["W/S thrust   A/D strafe   R/F up/down   Shift boost   X brake",
		"Arrows pitch/yaw   Q/E roll   Z assist   V spin match",
		"G scanner range   C cockpit/chase   K docking computer   P pause",
		"T tug (%d cr, on credit if you are broke)   H hide keys" % int(flight.tune_dock["auto_dock_fee"])]
	var y := 140.0
	for l in lines:
		draw_string(_font, Vector2(w * 0.5 - 300, y), l, HORIZONTAL_ALIGNMENT_LEFT, 600, 13, Color(UI.TEXT, 0.8))
		y += 18
