## The approach cockpit: head-up symbology in the windscreen (boresight, the port box,
## the velocity vector), the glareshield annunciator panel with the co-pilot's message
## window, and three multi-function displays on the instrument panel:
##   APPROACH  range and closing rate against the co-pilot's target profile, the
##             docking-axis display (axis offset, nose alignment, roll key) and the
##             capture envelope
##   SCANNER   the Elite-style 3D scanner: a plane ellipse with range rings, every
##             contact at its bearing and range with a stalk for height above or
##             below, coloured by type, and a closing-contact warning
##   SYSTEMS   propellant, heat, drive, keel, hold, life support and a damage schematic
## In the cockpit view the displays sit in the 3D flight deck (flight_deck.gd); in the
## chase view they become a flat telemetry strip.
extends Control

const UI := preload("res://view/ui/ui_kit.gd")
const Bindings := preload("res://view/bindings.gd")
const AV := preload("res://view/ui/avionics.gd")
const Pages := preload("res://view/ui/cockpit_pages.gd")
const ShipStats := preload("res://sim/ship_stats.gd")
const DamageSystem := preload("res://sim/systems/damage_system.gd")

## Head-up symbology in the windscreen.
const HUD_COL := Color("9cf2b4")
## Scanner contacts closer than this many seconds on our course are flagged.
const THREAT_S := 15.0
const TRAIL_N := 80

var flight
var _font: Font
var _message: Label
var show_keys := true
var _g := AV.new()
## Recent [log10 range, closing] samples for the profile plot.
var _trail: Array = []
var _trail_next := 0.0
var _bumps_seen := 0
var _contact_until := -1.0
var _slots := {}


func _init(owner_flight) -> void:
	flight = owner_flight
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("cockpit_overlay_slots")


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
	if flight.bumps != _bumps_seen:
		_bumps_seen = flight.bumps
		_contact_until = flight.clock + 3.0
	if not flight.readout.is_empty() and flight.clock >= _trail_next:
		_trail_next = flight.clock + 0.25
		_trail.append(Vector2(_log_range(flight.readout["range"]), flight.readout["closing"]))
		if _trail.size() > TRAIL_N:
			_trail.pop_front()
	queue_redraw()


## Where the main screen should put its comms log and notices so they clear the panel.
func overlay_slots() -> Dictionary:
	return _slots


func _cockpit() -> bool:
	return flight.view_mode == "cockpit" and not flight.wrecked and flight.deck != null and flight.deck.visible


func _draw() -> void:
	if flight.readout.is_empty() or flight.view_mode == "beauty":
		_slots = {}
		return
	var w := size.x
	var h := size.y
	var quads: Dictionary
	var canvas: Dictionary
	var sill := PackedVector2Array()
	if _cockpit():
		quads = flight.deck.quads(flight.camera)
		canvas = flight.deck.canvas
		sill = flight.deck.sill(flight.camera)
		var wb: float = h * (0.5 - flight.deck.SILL_NY * 0.5)
		var px: float = w * (0.5 - flight.deck.PILLAR_BOTTOM_NX * 0.5)
		_slots = {"ticker": Rect2(px + 28, wb - 66, minf(640.0, w * 0.42), 54), "notices": Rect2(w - px - 28 - 440, wb - 196, 440, 180)}
	else:
		var flat := Pages.flat_layout(size)
		quads = flat["quads"]
		canvas = flat["canvas"]
		var top: float = flat["top"]
		draw_rect(Rect2(0, top, w, h - top), Color(0.03, 0.04, 0.045, 0.82))
		draw_line(Vector2(0, top), Vector2(w, top), Color(AV.FAINT, 0.9), 1.0)
		sill = PackedVector2Array([Vector2(0, top), Vector2(w, top)])
		_slots = {"ticker": Rect2(16, top - 62, 760, 54), "notices": Rect2(w - 460, top - 196, 440, 180)}
	_draw_markers(sill)
	if quads.has("left") and _g.begin(self, _font, quads["left"], canvas["left"]):
		_page_approach(_g)
	if quads.has("centre") and _g.begin(self, _font, quads["centre"], canvas["centre"]):
		_page_scanner(_g)
	if quads.has("right") and _g.begin(self, _font, quads["right"], canvas["right"]):
		Pages.systems(_g, flight.sim, [[Bindings.key_of("flight_tug"), "TUG %d cr" % int(flight.tune_dock["auto_dock_fee"]), AV.GREY], ["%s %s" % [Bindings.key_of("time_slower"), Bindings.key_of("time_faster")], "TIME", AV.GREY], [Bindings.key_of("pause"), "PAUSE", AV.GREY], [Bindings.key_of("controls_page"), "KEYS", AV.GREY]], flight.wrecked)
	if quads.has("annunciator") and _g.begin(self, _font, quads["annunciator"], canvas["annunciator"]):
		_annunciators(_g)
	if show_keys:
		_draw_keys(w)


# --- Head-up symbology ------------------------------------------------------------------

## Is this screen point in the windscreen (above the sill line)?
func _in_window(p: Vector2, sill: PackedVector2Array) -> bool:
	if p.y < 34.0:
		return false
	if sill.size() < 2:
		return true
	var a := sill[0]
	var b := sill[1]
	var f := 0.0 if absf(b.x - a.x) < 1e-3 else clampf((p.x - a.x) / (b.x - a.x), 0.0, 1.0)
	return p.y < lerpf(a.y, b.y, f) - 6.0


func _draw_markers(sill: PackedVector2Array) -> void:
	var cam: Camera3D = flight.camera
	var r: Dictionary = flight.readout
	var ship: Node3D = flight.ship_node
	var basis: Basis = ship.global_transform.basis
	# Boresight: the ship's nose axis, a gull-wing "waterline" mark.
	var ahead: Vector3 = ship.global_position - basis.z * 1000.0
	if flight.view_mode == "cockpit" and not cam.is_position_behind(ahead):
		var c := cam.unproject_position(ahead)
		if _in_window(c, sill):
			var pts := PackedVector2Array([c + Vector2(-26, 0), c + Vector2(-11, 0), c + Vector2(-5.5, 7), c, c + Vector2(5.5, 7), c + Vector2(11, 0), c + Vector2(26, 0)])
			draw_polyline(pts, Color(HUD_COL, 0.9), 1.5, true)
	# The port: a box, green inside the capture envelope; a chevron at the edge if out of view.
	var port := Vector3(0, 0, flight.station["port_z"])
	var colour := AV.GREEN if _all_ok() else AV.AMBER
	var shown := false
	if not cam.is_position_behind(port):
		var at := cam.unproject_position(port)
		if _in_window(at, sill) and at.x > 20 and at.x < size.x - 20:
			shown = true
			var s := 13.0
			for k in 4:
				var dx := 1.0 if k % 2 == 0 else -1.0
				var dy := 1.0 if k < 2 else -1.0
				var corner := at + Vector2(dx, dy) * s
				draw_line(corner, corner - Vector2(dx * 7, 0), colour, 2.0, true)
				draw_line(corner, corner - Vector2(0, dy * 7), colour, 2.0, true)
			draw_string(_font, at + Vector2(18, -5), "PORT %s" % _range_text(r["range"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, colour)
			draw_string(_font, at + Vector2(18, 10), "%+.1f m/s" % -r["closing"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(colour, 0.8))
	if not shown:
		var local: Vector3 = cam.global_transform.basis.inverse() * (port - cam.global_position)
		var dir := Vector2(local.x, -local.y)
		if dir.length() < 1e-4:
			dir = Vector2(0, 1)
		dir = dir.normalized()
		var centre := Vector2(size.x * 0.5, size.y * 0.33)
		var reach := Vector2(size.x * 0.36, size.y * 0.26)
		var p := centre + Vector2(dir.x * reach.x, dir.y * reach.y)
		var n := dir.orthogonal()
		draw_colored_polygon(PackedVector2Array([p + dir * 12.0, p - dir * 4.0 + n * 9.0, p - dir * 4.0 - n * 9.0]), Color(AV.AMBER, 0.85))
		draw_string(_font, p - dir * 22.0 + Vector2(-20, 4), "PORT", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, AV.AMBER)
	# Velocity vector: where we are drifting.
	var v: Vector3 = flight.velocity
	if v.length() > 0.05:
		var drift: Vector3 = ship.position + v.normalized() * 200.0
		if not cam.is_position_behind(drift):
			var p := cam.unproject_position(drift)
			if _in_window(p, sill):
				draw_arc(p, 6.0, 0.0, TAU, 20, HUD_COL, 1.5, true)
				for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, -1)]:
					draw_line(p + d * 6.0, p + d * 13.0, HUD_COL, 1.5, true)


func _all_ok() -> bool:
	var r: Dictionary = flight.readout
	return r["ok_speed"] and r["ok_align"] and r["ok_roll"]


func _range_text(m: float) -> String:
	return "%.1f m" % m if m < 100.0 else ("%d m" % int(m) if m < 10000.0 else "%.1f km" % (m / 1000.0))


func _log_range(m: float) -> float:
	return log(maxf(m, 1.0)) / log(10.0)


# --- APPROACH ------------------------------------------------------------------------------

func _page_approach(g) -> void:
	var r: Dictionary = flight.readout
	var d: Dictionary = flight.tune_dock
	var gd: Dictionary = flight.guidance()
	var W: float = g.size.x
	var limit := float(d["max_speed_mps"])
	var advised: float = gd.get("advised", limit)
	g.glass()
	g.title("APPROACH", String(flight.sim.data.places[flight.place_id]["name"]).to_upper())
	# Readouts.
	var y := 36.0
	var closing: float = r["closing"]
	var cl_col := AV.WHITE
	if closing < -0.05:
		cl_col = AV.AMBER
	elif closing > advised * 1.3 or not r["ok_speed"] and r["range"] < 50.0:
		cl_col = AV.AMBER
	elif closing > 0.05:
		cl_col = AV.GREEN
	var rows := [
		["RNG", _range_text(r["range"]), AV.GREEN if r["range"] < 50.0 else AV.WHITE],
		["CLS", "%+.2f" % closing, cl_col],
		["TGT", "%.1f" % advised, AV.CYAN],
		["SPD", "%.2f/%.1f" % [r["speed"], limit], AV.GREEN if r["ok_speed"] else AV.AMBER],
		["ALN", "%.1f°/%d" % [r["align"], int(d["max_angle_deg"])], AV.GREEN if r["ok_align"] else AV.AMBER],
		["KEY", "%+.1f°/%d" % [rad_to_deg(r["roll_err"]), int(d["max_roll_error_deg"])], AV.GREEN if r["ok_roll"] else AV.AMBER],
		["LAT", "%.1f m" % r["lateral"], AV.GREEN if r["lateral"] < 3.0 else AV.WHITE],
	]
	for row in rows:
		g.row(Vector2(8, y), row[0], row[1], row[2], 30.0)
		y += 15.5
	# Range / closing-rate chart: the co-pilot's target profile in cyan, the capture
	# limit in amber, our track in white.
	var cr := Rect2(122, 26, W - 122 - 128, 104)
	_profile_chart(g, cr, limit, advised)
	# Docking-axis display.
	_axis_display(g, Vector2(W - 62, 76), 46.0, gd)
	g.soft_keys([["Z", "ASSIST " + _assist_short(r["assist"]), AV.GREEN if r["assist"] != "manual" else AV.AMBER],
		["V", "SPIN " + ("ON" if r["spin_match"] else "OFF"), AV.GREEN if r["spin_match"] else AV.GREY],
		["K", "DOCK " + ("ON" if flight.computer else ("--" if not ShipStats.has_docking_computer(flight.sim.state.ship, flight.sim.data) else "OFF")), AV.GREEN if flight.computer else AV.GREY],
		["X", "BRAKE", AV.GREY], ["S", "BACK", AV.GREY]])


func _assist_short(mode: String) -> String:
	return {"full": "FULL", "assisted": "ASST", "manual": "MAN"}.get(mode, mode.to_upper())


func _profile_chart(g, cr: Rect2, limit: float, advised: float) -> void:
	var lo := 0.0
	var hi := 3.3
	var vmax := 8.0
	var vmin := -1.0
	var to_xy := func(lr: float, v: float) -> Vector2:
		return Vector2(cr.position.x + cr.size.x * (hi - clampf(lr, lo, hi)) / (hi - lo), cr.end.y - cr.size.y * (clampf(v, vmin, vmax) - vmin) / (vmax - vmin))
	g.rect(cr, Color("0a1112"))
	for decade in [1.0, 2.0, 3.0]:
		var x: float = to_xy.call(decade, 0.0).x
		g.line(Vector2(x, cr.position.y), Vector2(x, cr.end.y), AV.FAINT, 1.0)
		g.text(Vector2(x, cr.end.y + 10), ["", "10", "100", "1k"][int(decade)], 9, AV.GREY, 0)
	for v in [2.0, 4.0, 6.0]:
		var yv: float = to_xy.call(0.0, v).y
		g.line(Vector2(cr.position.x, yv), Vector2(cr.end.x, yv), Color(AV.FAINT, 0.6), 1.0)
		g.text(Vector2(cr.position.x - 3, yv + 3), "%d" % int(v), 9, AV.GREY, 1)
	var zero: float = to_xy.call(0.0, 0.0).y
	g.line(Vector2(cr.position.x, zero), Vector2(cr.end.x, zero), AV.GREY, 1.0)
	g.text(Vector2(cr.end.x, cr.end.y + 10), "m", 9, AV.GREY, 1)
	g.text(Vector2(cr.position.x + 2, cr.position.y + 9), "m/s", 9, AV.GREY)
	# Capture limit.
	var ly: float = to_xy.call(0.0, limit).y
	g.dashed(Vector2(cr.position.x, ly), Vector2(cr.end.x, ly), Color(AV.AMBER, 0.8), 1.0, 4.0)
	# Target profile.
	var pts := PackedVector2Array()
	for i in 41:
		var lr := hi * float(i) / 40.0
		pts.append(to_xy.call(lr, flight.advised_closing(pow(10.0, lr))))
	g.polyline(pts, AV.CYAN, 1.5)
	# Our track and now.
	if _trail.size() >= 2:
		var tp := PackedVector2Array()
		for s in _trail:
			tp.append(to_xy.call(s.x, s.y))
		g.polyline(tp, Color(AV.WHITE, 0.4), 1.0)
	var now: Vector2 = to_xy.call(_log_range(flight.readout["range"]), flight.readout["closing"])
	var on_profile: bool = absf(flight.readout["closing"] - advised) < maxf(0.3, advised * 0.3)
	g.circle(now, 3.5, AV.GREEN if on_profile else AV.WHITE, true, 1.0, 12)
	g.rect(cr, AV.FAINT, false, 1.0)


func _axis_display(g, c: Vector2, R: float, gd: Dictionary) -> void:
	var r: Dictionary = flight.readout
	var capture := float(flight.tune_dock["capture_distance_m"])
	var ok_all := _all_ok()
	g.circle(c, R, Color("0a1112"), true, 1.0, 40)
	g.circle(c, R, AV.GREY, false, 1.0, 40)
	g.line(c - Vector2(R, 0), c + Vector2(R, 0), AV.FAINT, 1.0)
	g.line(c - Vector2(0, R), c + Vector2(0, R), AV.FAINT, 1.0)
	# Nose-alignment limit (half scale = the limit) and the capture zone.
	g.circle(c, R * 0.5, Color(AV.GREY, 0.5), false, 1.0, 32)
	var cap_r := R * sqrt(capture / 30.0)
	g.circle(c, cap_r, AV.GREEN if ok_all else Color(AV.GREEN, 0.5), false, 1.0, 24)
	# Roll key: index at the top, the slot's mark rotated by the error.
	var err: float = r["roll_err"]
	g.poly(PackedVector2Array([c + Vector2(0, -R - 1), c + Vector2(-4, -R - 8), c + Vector2(4, -R - 8)]), AV.GREY)
	var a := -PI * 0.5 + err
	var key_col := AV.GREEN if r["ok_roll"] else AV.AMBER
	var tip := c + Vector2(cos(a), sin(a)) * (R - 1.0)
	var base := c + Vector2(cos(a), sin(a)) * (R - 9.0)
	var side := Vector2(-sin(a), cos(a)) * 4.0
	g.poly(PackedVector2Array([tip, base + side, base - side]), key_col)
	# Nose: where the station's axis lies from our nose (diamond, cyan), 30° full scale.
	var basis: Basis = flight.ship_node.global_transform.basis
	var axis_local := basis.inverse() * Vector3(0, 0, -1)
	var nd := Vector2(axis_local.x, -axis_local.y)
	if nd.length() > 1e-4:
		nd = nd.normalized() * R * clampf(float(r["align"]) / 30.0, 0.0, 1.0)
	var nc := c + nd
	var ncol := AV.CYAN if r["ok_align"] else AV.AMBER
	g.polyline(PackedVector2Array([nc + Vector2(0, -5), nc + Vector2(5, 0), nc + Vector2(0, 5), nc + Vector2(-5, 0), nc + Vector2(0, -5)]), ncol, 1.5)
	# Axis offset: where the axis is from us (dot), square-root scale to 30 m.
	if not gd.is_empty():
		var o: Vector3 = gd["offset_local"]
		var p := Vector2(o.x, -o.y)
		var pr := R * sqrt(clampf(p.length(), 0.0, 30.0) / 30.0)
		var dot := c + (p.normalized() * pr if p.length() > 1e-3 else Vector2.ZERO)
		g.circle(dot, 4.0, AV.GREEN if p.length() <= capture else AV.WHITE, true, 1.0, 12)
	# Capture envelope: three chips.
	var chips := [["SPD", r["ok_speed"]], ["ALN", r["ok_align"]], ["KEY", r["ok_roll"]]]
	for i in 3:
		var cr := Rect2(c.x - R + i * (R * 2.0 / 3.0) + 1, c.y + R + 6, R * 2.0 / 3.0 - 2, 12)
		var on: bool = chips[i][1]
		g.rect(cr, Color(AV.GREEN, 0.25) if on else Color(AV.AMBER, 0.12))
		g.text(Vector2(cr.get_center().x, cr.end.y - 2.5), chips[i][0], 9, AV.GREEN if on else AV.AMBER, 0)


# --- SCANNER -------------------------------------------------------------------------------

func _page_scanner(g) -> void:
	var W: float = g.size.x
	var H: float = g.size.y
	var range_m: float = flight.scanner_range()
	var contacts: Array = flight.contacts()
	g.glass()
	g.title("SCANNER", "%d CONTACTS" % (contacts.size() - 1))
	var c := Vector2(W * 0.5, 86.0)
	var rx := W * 0.43
	var ry := 44.0
	g.ellipse(c, rx, ry, Color("08130f"), true, 1.0, 72)
	for f in [1.0, 2.0 / 3.0, 1.0 / 3.0]:
		g.ellipse(c, rx * f, ry * f, Color(AV.GREEN, 0.45 if f == 1.0 else 0.28), false, 1.0, 72)
		# Ring range on the square-root scale.
		g.text(c + Vector2(rx * f + 2, -2), _range_text(range_m * f * f), 9, Color(AV.GREY, 0.9))
	g.line(c - Vector2(rx, 0), c + Vector2(rx, 0), Color(AV.GREEN, 0.18), 1.0)
	g.line(c - Vector2(0, ry), c + Vector2(0, ry), Color(AV.GREEN, 0.18), 1.0)
	# Forward field of view (the windscreen), and bearing ticks every 30°.
	var half := deg_to_rad(36.0)
	for s in [-1.0, 1.0]:
		g.line(c, c + Vector2(sin(half) * s * rx, -cos(half) * ry), Color(AV.GREEN, 0.3), 1.0)
	for i in 12:
		var a := TAU * i / 12.0
		var e := Vector2(sin(a), -cos(a))
		g.line(c + Vector2(e.x * rx, e.y * ry), c + Vector2(e.x * (rx + 5), e.y * (ry + 3)), Color(AV.GREEN, 0.45), 1.0)
	var basis: Basis = flight.ship_node.global_transform.basis
	var inv := basis.inverse()
	var origin: Vector3 = flight.ship_node.global_position
	var vel: Vector3 = flight.velocity
	var items := []
	var worst_t := INF
	for contact in contacts:
		var rel: Vector3 = contact["pos"] - origin
		var local: Vector3 = inv * rel
		var threat := INF
		if contact["kind"] in ["rock", "ship", "pod"]:
			var rv: Vector3 = vel - contact.get("vel", Vector3.ZERO)
			var closing := rel.dot(rv)
			if closing > 0.0:
				var t := closing / maxf(rv.length_squared(), 1e-6)
				if (rel - rv * t).length() < float(contact.get("r", 3.0)) + flight.ship_radius * 1.5 and t < THREAT_S:
					threat = t
					worst_t = minf(worst_t, t)
		items.append([local, contact, threat])
	# Far below first, so nearer, higher stalks draw on top.
	items.sort_custom(func(a, b): return a[0].y < b[0].y)
	for it in items:
		var local: Vector3 = it[0]
		var contact: Dictionary = it[1]
		var dist := local.length()
		if dist > range_m:
			if contact["kind"] == "station":
				# Off scale: a chevron on the rim at its bearing.
				var b := Vector2(local.x, local.z).normalized()
				var p := c + Vector2(b.x * rx, b.y * ry)
				g.poly(PackedVector2Array([p + b * 7.0, p - b * 2.0 + b.orthogonal() * 5.0, p - b * 2.0 - b.orthogonal() * 5.0]), AV.GREEN)
			continue
		# Square-root radial scale: close contacts spread out, far ones stay on the glass.
		var k := sqrt(dist / range_m) / maxf(dist / range_m, 1e-6) / range_m
		var plane := c + Vector2(local.x * k * rx, local.z * k * ry)
		var tip := plane - Vector2(0, local.y * k * ry * 1.4)
		tip.y = clampf(tip.y, 22.0, H - 24.0)
		var col: Color = contact["colour"]
		var threat: float = it[2]
		if threat < INF:
			col = AV.RED if threat < 6.0 else AV.AMBER
		var below: bool = local.y < 0.0
		g.line(plane - Vector2(2.5, 0), plane + Vector2(2.5, 0), Color(col, 0.6), 1.0)
		g.line(plane, tip, Color(col, 0.55 if below else 0.95), 1.0 if below else 1.5)
		match contact["kind"]:
			"station":
				g.rect(Rect2(tip - Vector2(5, 4), Vector2(10, 8)), col)
			"ship":
				g.poly(PackedVector2Array([tip + Vector2(0, -5), tip + Vector2(4, 0), tip + Vector2(0, 5), tip + Vector2(-4, 0)]), col)
			"pod":
				g.poly(PackedVector2Array([tip + Vector2(0, -4), tip + Vector2(4, 3), tip + Vector2(-4, 3)]), col)
			_:
				g.circle(tip, 2.4, col, true, 1.0, 10)
		if threat < INF:
			g.circle(tip, 7.0, col, false, 1.0, 16)
	# Own ship.
	g.poly(PackedVector2Array([c + Vector2(0, -6), c + Vector2(4, 4), c + Vector2(-4, 4)]), AV.WHITE)
	var rock_s: float = flight.readout.get("rock_s", INF)
	var warn_t := minf(worst_t, rock_s)
	if warn_t < THREAT_S and (warn_t >= 6.0 or fmod(flight.clock, 0.6) < 0.4):
		g.text(Vector2(W * 0.5, H - 26), "CLOSING CONTACT  %.1f s" % warn_t, 12, AV.RED if warn_t < 6.0 else AV.AMBER, 0)
	g.soft_keys([["G", "RNG " + _range_text(range_m).replace(".0 km", " km"), AV.CYAN], ["C", "VIEW " + ("CHASE" if flight.view_mode == "cockpit" else "DECK"), AV.GREY],
		[], ["H", "KEYS", AV.GREY], ["T", "TUG", AV.GREY]])


# --- Annunciators ------------------------------------------------------------------------

func _annunciators(g) -> void:
	var r: Dictionary = flight.readout
	var sim = flight.sim
	var alerts := Pages.ship_alerts(sim, flight.wrecked)
	var rock_s: float = r.get("rock_s", INF)
	var ctl: Dictionary = flight.controls_now
	var spin_live: bool = r["spin_match"] and r["assist"] != "manual"
	var left := [
		["PROX", 2 if rock_s < 6.0 else (1 if rock_s < THREAT_S else 0)],
		["HULL", alerts["HULL"]],
		["CONTACT", 1 if flight.clock < _contact_until else 0],
		["FUEL LOW", alerts["FUEL LOW"]],
		["HEAT", alerts["HEAT"]],
		["DRIVE", alerts["DRIVE"]],
	]
	var right := [
		["CAPTURE", AV.GREEN if _all_ok() and r["range"] < 60.0 else 0],
		["SPIN MATCH", (AV.GREEN if r["range"] < 400.0 else AV.CYAN) if spin_live else 0],
		["DOCK COMP", AV.GREEN if flight.computer else 0],
		["ASSIST " + _assist_short(r["assist"]), AV.GREEN if r["assist"] != "manual" else AV.AMBER],
		["BOOST", AV.CYAN if ctl.get("boost", false) else 0],
		["BRAKE", AV.CYAN if ctl.get("brake", false) or (r["assist"] == "full" and ctl.get("thrust", Vector3.ONE) == Vector3.ZERO and r["speed"] > 0.02) else 0],
	]
	var gd: Dictionary = flight.guidance()
	var text: String = gd.get("text", "")
	var col := AV.AMBER
	if flight.wrecked:
		text = "Keel failure. Abandon ship: the lifeboat is away."
		col = AV.RED
	elif flight.computer:
		col = AV.WHITE
	elif text.begins_with("Good"):
		col = AV.GREEN
	Pages.annunciators(g, left, right, text, col, Pages.clock(sim), flight.clock)


func _draw_keys(w: float) -> void:
	var k := Bindings.key_of
	var lines := ["%s/%s thrust   %s/%s strafe   %s/%s up/down   %s boost   %s brake" % [k.call("flight_forward"), k.call("flight_back"), k.call("flight_strafe_left"), k.call("flight_strafe_right"), k.call("flight_up"), k.call("flight_down"), k.call("flight_boost"), k.call("flight_brake")],
		"%s/%s pitch   %s/%s yaw   %s/%s roll   %s assist   %s spin match" % [k.call("flight_pitch_up"), k.call("flight_pitch_down"), k.call("flight_yaw_left"), k.call("flight_yaw_right"), k.call("flight_roll_left"), k.call("flight_roll_right"), k.call("flight_assist"), k.call("flight_spin_match")],
		"%s scanner range   %s cockpit/chase   %s docking computer   %s pause" % [k.call("flight_scanner"), k.call("flight_view"), k.call("flight_computer"), k.call("pause")],
		"%s tug (%d cr, on credit if you are broke)   %s hide keys   %s all controls" % [k.call("flight_tug"), int(flight.tune_dock["auto_dock_fee"]), k.call("flight_keys"), k.call("controls_page")]]
	var y := 140.0
	draw_rect(Rect2(w * 0.5 - 312, y - 16, 624, 18 * lines.size() + 8), Color(0.02, 0.03, 0.035, 0.6))
	for l in lines:
		draw_string(_font, Vector2(w * 0.5 - 300, y), l, HORIZONTAL_ALIGNMENT_LEFT, 600, 13, Color(UI.TEXT, 0.85))
		y += 18
