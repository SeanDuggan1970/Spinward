## Approach instruments: range, closing speed, alignment and roll key, each lit green
## when inside the docking tolerances. Draws a box on the port and the velocity vector.
extends Control

const UI := preload("res://view/ui/ui_kit.gd")

var flight
var _readouts: Label
var _keys: Label
var _message: Label
var _font: Font


func _init(owner_flight) -> void:
	flight = owner_flight
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_font = UI.make_theme().default_font
	var p := UI.panel("Approach")
	p[0].position = Vector2(16, 56)
	p[0].custom_minimum_size = Vector2(300, 0)
	add_child(p[0])
	_readouts = Label.new()
	_readouts.add_theme_font_size_override("font_size", 14)
	p[1].add_child(_readouts)
	_keys = UI.label("W/S thrust  A/D strafe  R/F up/down\nShift boost  X brake\nArrows pitch/yaw  Q/E roll\nZ assist  V spin match  C camera\nT call the tug (%d cr)  P pause" % int(flight.tune_dock["auto_dock_fee"]), UI.DIM, 12)
	p[1].add_child(_keys)
	_message = UI.label("", UI.AMBER, 20)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_message.position.y = 110
	_message.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_message)


func _process(_dt: float) -> void:
	var r: Dictionary = flight.readout
	if r.is_empty():
		return
	var lines := PackedStringArray()
	var d: Dictionary = flight.tune_dock
	lines.append("RANGE     %8.1f m" % r["range"])
	lines.append("LATERAL   %8.1f m" % r["lateral"])
	lines.append("CLOSING   %8.2f m/s" % r["closing"])
	lines.append("SPEED     %8.2f m/s   limit %.1f" % [r["speed"], d["max_speed_mps"]])
	lines.append("ALIGN     %8.1f°     limit %d°" % [r["align"], int(d["max_angle_deg"])])
	lines.append("ROLL KEY  %8.1f°     limit %d°" % [rad_to_deg(r["roll_err"]), int(d["max_roll_error_deg"])])
	lines.append("")
	lines.append("ASSIST    %s" % String(r["assist"]).to_upper())
	lines.append("SPIN MATCH %s" % ("ON" if r["spin_match"] and r["assist"] != "manual" else "OFF"))
	lines.append("CONTACTS  %d" % flight.bumps)
	_readouts.text = "\n".join(lines)
	var all_ok: bool = r["ok_speed"] and r["ok_align"] and r["ok_roll"]
	_readouts.add_theme_color_override("font_color", UI.GOOD if all_ok else UI.TEXT)
	_message.visible = flight.clock < flight.message_until
	_message.text = flight.message
	_message.add_theme_color_override("font_color", flight.message_colour)
	queue_redraw()


func _draw() -> void:
	var cam: Camera3D = flight.camera
	if cam == null or flight.readout.is_empty():
		return
	var port := Vector3(0, 0, flight.station["port_z"])
	if not cam.is_position_behind(port):
		var at := cam.unproject_position(port)
		var r: Dictionary = flight.readout
		var colour := UI.GOOD if r["ok_speed"] and r["ok_align"] and r["ok_roll"] else UI.AMBER
		draw_rect(Rect2(at - Vector2(14, 14), Vector2(28, 28)), colour, false, 2.0)
		draw_string(_font, at + Vector2(18, -6), "PORT %.0f m" % r["range"], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, colour)
	var v: Vector3 = flight.velocity
	if v.length() > 0.05:
		var ahead: Vector3 = flight.ship_node.position + v.normalized() * 200.0
		if not cam.is_position_behind(ahead):
			var p := cam.unproject_position(ahead)
			draw_circle(p, 6.0, Color(UI.GOOD, 0.0))
			draw_arc(p, 7.0, 0.0, TAU, 20, UI.GOOD, 1.5)
			draw_line(p + Vector2(-12, 0), p + Vector2(-7, 0), UI.GOOD, 1.5)
			draw_line(p + Vector2(7, 0), p + Vector2(12, 0), UI.GOOD, 1.5)
			draw_line(p + Vector2(0, -12), p + Vector2(0, -7), UI.GOOD, 1.5)

