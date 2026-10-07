## The transit cockpit, in the same flight deck as the approach: markers in the
## windscreen on the destination, origin, Earth and Moon; the glareshield annunciators
## with the co-pilot's running commentary on the burn; and three displays:
##   BURN     phase, velocity, thrust, to go, ETA, and the velocity profile of the whole
##            transfer with the turnover marked and where we are on it
##   NAV      the trip seen from above: the track flown and to come, Earth, Moon, origin
##            and destination, with ranges and one-way light time to Earth
##   SYSTEMS  shared with the approach cockpit
## Through the telescope (Z) the deck is out of the picture and a sight reticle shows.
extends Control

const UI := preload("res://view/ui/ui_kit.gd")
const Bindings := preload("res://view/bindings.gd")
const AV := preload("res://view/ui/avionics.gd")
const Pages := preload("res://view/ui/cockpit_pages.gd")
const V := preload("res://sim/v3.gd")
const Navigation := preload("res://sim/navigation.gd")
const ShipStats := preload("res://sim/ship_stats.gd")

const HUD_COL := Color("9cf2b4")
const EARTH_COL := Color("7fb0e0")
const MOON_COL := Color("c9c4b6")
const C_MPS := 299792458.0
const PROFILE_N := 64

var sim
var view
var _font: Font
var _g := AV.new()
var _slots := {}
## The transfer, sampled once per trip: {key, t: [], speed: [], path: [], flip_t, peak}.
var _trip := {}


func _init(owner_sim, transit_view) -> void:
	sim = owner_sim
	view = transit_view
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("cockpit_overlay_slots")


func _ready() -> void:
	_font = UI.make_theme().default_font


func _process(_dt: float) -> void:
	queue_redraw()


func overlay_slots() -> Dictionary:
	return _slots


func _draw() -> void:
	var r: Dictionary = view.readout
	# The screen lingers a frame after arrival; draw nothing once we are off the transfer.
	if r.is_empty() or sim.state.location.get("status") != "transit":
		_slots = {}
		return
	_sample_trip()
	var w := size.x
	var h := size.y
	var deck = view.deck
	if not deck.visible:
		_draw_telescope(r)
		_slots = {"ticker": Rect2(16, h - 62, 760, 54), "notices": Rect2(w - 460, h - 200, 440, 180)}
		return
	var cam: Camera3D = view.camera
	var quads: Dictionary = deck.quads(cam)
	var sill: PackedVector2Array = deck.sill(cam)
	var wb: float = h * (0.5 - deck.SILL_NY * 0.5)
	var px: float = w * (0.5 - deck.PILLAR_BOTTOM_NX * 0.5)
	_slots = {"ticker": Rect2(px + 28, wb - 66, minf(640.0, w * 0.42), 54), "notices": Rect2(w - px - 28 - 440, wb - 196, 440, 180)}
	_markers(r, sill)
	var canvas: Dictionary = deck.canvas
	if quads.has("left") and _g.begin(self, _font, quads["left"], canvas["left"]):
		_page_burn(_g, r)
	if quads.has("centre") and _g.begin(self, _font, quads["centre"], canvas["centre"]):
		_page_nav(_g, r)
	if quads.has("right") and _g.begin(self, _font, quads["right"], canvas["right"]):
		Pages.systems(_g, sim, [[Bindings.key_of("transit_view"), "VIEW", AV.GREY], [Bindings.key_of("pause"), "PAUSE", AV.GREY], [Bindings.key_of("controls_page"), "KEYS", AV.GREY]])
	if quads.has("annunciator") and _g.begin(self, _font, quads["annunciator"], canvas["annunciator"]):
		_annunciators(_g, r)


# --- Windscreen markers ---------------------------------------------------------------------

func _in_window(p: Vector2, sill: PackedVector2Array) -> bool:
	if p.y < 34.0 or p.x < 0.0 or p.x > size.x:
		return false
	if sill.size() < 2:
		return true
	var a := sill[0]
	var b := sill[1]
	var f := 0.0 if absf(b.x - a.x) < 1e-3 else clampf((p.x - a.x) / (b.x - a.x), 0.0, 1.0)
	return p.y < lerpf(a.y, b.y, f) - 6.0


func _markers(r: Dictionary, sill: PackedVector2Array) -> void:
	var cam: Camera3D = view.camera
	var loc: Dictionary = sim.state.location
	var marks := [
		[r["dest_dir"], sim.data.locations[loc["to"]]["name"].to_upper(), AV.AMBER, true],
		[r["origin_dir"], "FROM " + sim.data.locations[loc["from"]]["name"], AV.GREY, false],
		[r["earth_dir"], "EARTH", EARTH_COL, false],
		[r["moon_dir"], "MOON", MOON_COL, false],
	]
	for m in marks:
		var p: Vector3 = m[0] * 1000.0
		if cam.is_position_behind(p):
			continue
		var at := cam.unproject_position(p)
		if not _in_window(at, sill):
			continue
		if m[3]:
			for k in 4:
				var dx := 1.0 if k % 2 == 0 else -1.0
				var dy := 1.0 if k < 2 else -1.0
				var corner := at + Vector2(dx, dy) * 12.0
				draw_line(corner, corner - Vector2(dx * 7, 0), m[2], 2.0, true)
				draw_line(corner, corner - Vector2(0, dy * 7), m[2], 2.0, true)
			draw_string(_font, at + Vector2(17, -4), m[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, m[2])
			draw_string(_font, at + Vector2(17, 11), "%s  %s" % [UI.km(r["remaining"]), _hm(r["eta"])], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(m[2], 0.8))
		else:
			draw_line(at + Vector2(-6, 0), at + Vector2(6, 0), m[2], 1.0)
			draw_line(at + Vector2(0, -6), at + Vector2(0, 6), m[2], 1.0)
			draw_string(_font, at + Vector2(10, -6), m[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, m[2])
	# Boresight: the ship's thrust axis.
	var nose: Vector3 = -view._mount.global_transform.basis.z * 1000.0
	if not cam.is_position_behind(nose):
		var c := cam.unproject_position(nose)
		if _in_window(c, sill):
			draw_polyline(PackedVector2Array([c + Vector2(-26, 0), c + Vector2(-11, 0), c + Vector2(-5.5, 7), c, c + Vector2(5.5, 7), c + Vector2(11, 0), c + Vector2(26, 0)]), Color(HUD_COL, 0.8), 1.5, true)


func _draw_telescope(r: Dictionary) -> void:
	var c := size * 0.5
	var col := Color(HUD_COL, 0.55)
	var R := size.y * 0.38
	draw_arc(c, R, 0, TAU, 96, col, 1.0, true)
	for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		draw_line(c + d * 14.0, c + d * R, Color(col, 0.6), 1.0)
		for i in range(1, 6):
			var p: Vector2 = c + d * (R * i / 6.0)
			var n: Vector2 = d.orthogonal() * (6.0 if i % 2 == 0 else 3.0)
			draw_line(p - n, p + n, col, 1.0)
	_markers(r, PackedVector2Array())
	var text := "TELESCOPE  ×%d   %s to close   %s to slew   %s to centre" % [int(round(view.WIDE_FOV / view.TELESCOPE_FOV)), Bindings.hint_of("transit_telescope"), Bindings.key_of("transit_look_left") + " " + Bindings.key_of("transit_look_right"), Bindings.hint_of("transit_centre")]
	draw_string(_font, Vector2(c.x - 260, size.y - 80), text, HORIZONTAL_ALIGNMENT_LEFT, 520, 13, col)


# --- The trip ------------------------------------------------------------------------------

func _sample_trip() -> void:
	var loc: Dictionary = sim.state.location
	var key := "%s>%s@%d" % [loc["from"], loc["to"], int(loc["depart_t"])]
	if _trip.get("key", "") == key:
		return
	var t0 := float(loc["depart_t"])
	var t1 := float(loc["arrive_t"])
	var ts := []
	var speeds := []
	var path := []
	var peak := 0.0
	var flip_t := -1.0
	var last_into := 1.0
	for i in PROFILE_N + 1:
		var t := lerpf(t0, t1, float(i) / PROFILE_N)
		var v := Navigation.transit_velocity(loc, t)
		var a := Navigation.transit_accel(loc, t)
		var sp := V.length(v)
		ts.append(t)
		speeds.append(sp)
		path.append(Navigation.transit_position(loc, t))
		peak = maxf(peak, sp)
		if V.length(a) > 1e-9 and sp > 1e-6:
			var into := V.dot(V.normalized(a), V.normalized(v))
			if last_into > 0.0 and into < 0.0 and flip_t < 0.0:
				flip_t = t
			last_into = into
	_trip = {"key": key, "t": ts, "speed": speeds, "path": path, "flip_t": flip_t, "peak": peak}


func _hm(s: float) -> String:
	if s >= 2.0 * 86400.0:
		return "%.1f d" % (s / 86400.0)
	return "%d h %02d min" % [int(s / 3600.0), int(fmod(s, 3600.0) / 60.0)]


func _phase_col(phase: String) -> Color:
	match phase:
		"TURNING":
			return AV.AMBER
		"COASTING":
			return AV.WHITE
	return AV.GREEN


# --- BURN ------------------------------------------------------------------------------------

func _page_burn(g, r: Dictionary) -> void:
	var W: float = g.size.x
	var loc: Dictionary = sim.state.location
	var s = sim.state
	g.glass()
	g.title("BURN", r["phase"], _phase_col(r["phase"]))
	var y := 38.0
	var arrive := Time.get_datetime_string_from_unix_time(int(float(loc["arrive_t"]) + 946728000.0)).substr(5, 11).replace("T", " ")
	for row in [
		["VEL", "%.2f km/s" % (r["speed"] / 1000.0), AV.WHITE],
		["THR", "%.2f mg" % (r["accel"] / 9.80665 * 1000.0), AV.GREEN if r["accel"] > 1e-6 else AV.GREY],
		["TOGO", UI.km(r["remaining"]), AV.WHITE],
		["ETA", _hm(r["eta"]), AV.WHITE],
		["ARR", arrive, AV.CYAN],
	]:
		g.row(Vector2(8, y), row[0], row[1], row[2], 36.0)
		y += 17.0
	# Velocity across the whole transfer: flown in white, to come in cyan, turnover marked.
	var cr := Rect2(W * 0.47, 28, W * 0.53 - 10, 96)
	g.rect(cr, Color("0a1112"))
	var ts: Array = _trip["t"]
	var sp: Array = _trip["speed"]
	var peak: float = maxf(float(_trip["peak"]), 1.0)
	var t0: float = ts[0]
	var t1: float = ts[ts.size() - 1]
	var now: float = s.time_s
	var to_xy := func(t: float, v: float) -> Vector2:
		return Vector2(cr.position.x + cr.size.x * clampf((t - t0) / maxf(t1 - t0, 1.0), 0.0, 1.0), cr.end.y - 4.0 - (cr.size.y - 14.0) * v / peak)
	var flown := PackedVector2Array()
	var ahead := PackedVector2Array()
	for i in ts.size():
		var p: Vector2 = to_xy.call(ts[i], sp[i])
		if float(ts[i]) <= now:
			flown.append(p)
		else:
			if ahead.is_empty() and not flown.is_empty():
				ahead.append(flown[flown.size() - 1])
			ahead.append(p)
	g.polyline(ahead, AV.CYAN, 1.5)
	g.polyline(flown, AV.WHITE, 1.5)
	var flip_t: float = _trip["flip_t"]
	if flip_t > 0.0:
		var fx: float = to_xy.call(flip_t, 0.0).x
		g.dashed(Vector2(fx, cr.position.y + 2), Vector2(fx, cr.end.y), Color(AV.AMBER, 0.7), 1.0, 4.0)
		g.text(Vector2(fx + 3, cr.position.y + 11), "TURN", 9, AV.AMBER)
	var nx: float = to_xy.call(now, 0.0).x
	g.line(Vector2(nx, cr.position.y), Vector2(nx, cr.end.y), Color(AV.WHITE, 0.5), 1.0)
	g.circle(to_xy.call(now, r["speed"]), 3.5, AV.WHITE, true, 1.0, 12)
	g.text(Vector2(cr.position.x + 2, cr.position.y + 10), "%.1f km/s" % (peak / 1000.0), 9, AV.GREY)
	g.text(Vector2(cr.position.x, cr.end.y + 10), "DEP", 9, AV.GREY)
	g.text(Vector2(cr.end.x, cr.end.y + 10), "ARR", 9, AV.GREY, 1)
	g.rect(cr, AV.FAINT, false, 1.0)
	var ts_now := int(s.time_scale)
	g.soft_keys([["[", "SLOWER", AV.GREY], ["]", "FASTER", AV.GREY], ["", "×%d" % ts_now if not s.paused else "PAUSED", AV.AMBER if s.paused else AV.CYAN], ["P", "PAUSE", AV.GREY], ["M", "MAP", AV.GREY]])


# --- NAV -----------------------------------------------------------------------------------

func _page_nav(g, r: Dictionary) -> void:
	var W: float = g.size.x
	var H: float = g.size.y
	var loc: Dictionary = sim.state.location
	var eph = sim.ephemeris
	var t: float = sim.state.time_s
	var frame: String = loc["frame"]
	var fp: Array = eph.position(frame, t)
	g.glass()
	g.title("NAV", "%s FRAME" % String(sim.data.bodies.get(frame, {}).get("name", frame)).to_upper())
	var rel := func(id: String) -> Array:
		return V.sub(eph.position(id, t), fp)
	var ship := Navigation.transit_position(loc, t)
	var pts := {"ship": ship, "dest": rel.call(loc["to"]), "from": rel.call(loc["from"]), "frame": [0.0, 0.0, 0.0]}
	if frame != "moon" and sim.data.bodies.has("moon") and frame == "earth":
		pts["moon"] = rel.call("moon")
	var path: Array = _trip["path"]
	# Fit everything into the plot, north (ecliptic +y) up.
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in path + pts.values():
		var q := Vector2(float(p[0]), -float(p[1]))
		lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
		hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
	var plot := Rect2(10, 24, W - 20, H - 54)
	var span := maxf((hi - lo).x / plot.size.x, (hi - lo).y / plot.size.y) * 1.12
	span = maxf(span, 1.0)
	var mid := (lo + hi) * 0.5
	var to_xy := func(p: Array) -> Vector2:
		return plot.get_center() + (Vector2(float(p[0]), -float(p[1])) - mid) / span
	# Range rings round the frame body.
	var fc: Vector2 = to_xy.call([0.0, 0.0, 0.0])
	var ring := _nice(plot.size.y * 0.5 * span)
	for k in [1.0, 2.0]:
		g.clipped(g.ellipse_points(fc, ring * k / span, ring * k / span, 96), plot, Color(AV.FAINT, 0.7), 1.0)
	if pts.has("moon"):
		var md := V.length(pts["moon"]) / span
		g.clipped(g.ellipse_points(fc, md, md, 120), plot, Color(MOON_COL, 0.18), 1.0)
	# The track: flown in grey, to come in cyan.
	var flown := PackedVector2Array()
	var ahead := PackedVector2Array()
	var ts: Array = _trip["t"]
	for i in path.size():
		var p: Vector2 = to_xy.call(path[i])
		if float(ts[i]) <= t:
			flown.append(p)
		else:
			ahead.append(p)
	var sp: Vector2 = to_xy.call(ship)
	flown.append(sp)
	ahead.insert(0, sp)
	g.polyline(flown, Color(AV.WHITE, 0.45), 1.0)
	g.polyline(ahead, AV.CYAN, 1.5)
	# Bodies and places.
	if frame == "earth" or frame == "sun":
		g.circle(fc, 4.5, EARTH_COL if frame == "earth" else Color("ffe9a0"), true, 1.0, 16)
		g.text(fc + Vector2(7, 12), "EARTH" if frame == "earth" else "SUN", 9, EARTH_COL if frame == "earth" else AV.AMBER)
	if pts.has("moon"):
		var mp: Vector2 = to_xy.call(pts["moon"])
		g.circle(mp, 3.5, MOON_COL, true, 1.0, 14)
		g.text(mp + Vector2(6, 11), "MOON", 9, MOON_COL)
	var op: Vector2 = to_xy.call(pts["from"])
	g.rect(Rect2(op - Vector2(3, 3), Vector2(6, 6)), AV.GREY, false, 1.0)
	var dp: Vector2 = to_xy.call(pts["dest"])
	g.rect(Rect2(dp - Vector2(5, 5), Vector2(10, 10)), AV.AMBER, false, 1.5)
	g.text(dp + Vector2(8, -6), String(sim.data.locations[loc["to"]]["name"]).to_upper(), 10, AV.AMBER)
	# Own ship, pointing along its velocity.
	var v := Navigation.transit_velocity(loc, t)
	var dir := Vector2(float(v[0]), -float(v[1]))
	dir = dir.normalized() if dir.length() > 1e-6 else Vector2(0, -1)
	var n := dir.orthogonal()
	g.poly(PackedVector2Array([sp + dir * 7.0, sp - dir * 4.0 + n * 4.0, sp - dir * 4.0 - n * 4.0]), AV.WHITE)
	# Ranges and the one-way light time home.
	var lt: float = r["earth_km"] * 1000.0 / C_MPS
	g.text(Vector2(8, H - 26), "EARTH %s  LT %.2f s" % [UI.km(r["earth_km"] * 1000.0), lt], 11, EARTH_COL)
	g.text(Vector2(W - 8, H - 26), "MOON %s" % UI.km(r["moon_km"] * 1000.0), 11, MOON_COL, 1)
	g.text(Vector2(W - 8, 34), "RING %s" % UI.km(ring), 9, AV.GREY, 1)
	g.soft_keys([["M", "MAP", AV.GREY], ["Z", "SCOPE", AV.CYAN if view.telescope else AV.GREY], ["C", "CENTRE", AV.GREY], ["←→", "LOOK", AV.GREY], []])


## A round number near x (1, 2 or 5 times a power of ten).
func _nice(x: float) -> float:
	var p := pow(10.0, floor(log(maxf(x, 1.0)) / log(10.0)))
	for m in [5.0, 2.0, 1.0]:
		if m * p <= x:
			return m * p
	return p


# --- Annunciators -------------------------------------------------------------------------

func _annunciators(g, r: Dictionary) -> void:
	var s = sim.state
	var loc: Dictionary = s.location
	var alerts := Pages.ship_alerts(sim)
	var ls := ShipStats.life_support_days(s.ship, sim.data)
	var eta: float = r["eta"]
	var ls_level := 0
	if ls != INF:
		ls_level = 2 if ls * 86400.0 < eta else (1 if ls * 86400.0 < eta * 2.0 else 0)
	var phase: String = r["phase"]
	var peri := float(loc.get("peri_t", -1.0))
	var left := [
		["HULL", alerts["HULL"]], ["FUEL LOW", alerts["FUEL LOW"]], ["HEAT", alerts["HEAT"]],
		["DRIVE", alerts["DRIVE"]], ["LIFE SUP", ls_level], ["POWER", alerts["POWER"]],
	]
	var right := [
		["BURN", AV.GREEN if phase in ["ACCELERATING", "BRAKING", "BURNING ACROSS"] else 0],
		["TURNOVER", AV.AMBER if phase == "TURNING" else 0],
		["COAST", AV.WHITE if phase == "COASTING" else 0],
		["FLYBY", AV.CYAN if peri > 0.0 and absf(s.time_s - peri) < 3600.0 else 0],
		["TELESCOPE", AV.CYAN if view.telescope else 0],
		["PAUSE", AV.AMBER if s.paused else 0],
	]
	var dest: String = sim.data.locations[loc["to"]]["name"]
	var text := ""
	var flip_t: float = _trip.get("flip_t", -1.0)
	match phase:
		"TURNING":
			text = "Turning the ship round. The drive points along our track for the braking burn."
		"BRAKING":
			text = "Braking for %s. Arrival in %s." % [dest, _hm(eta)]
		"COASTING":
			text = "Coasting. %s in %s." % [dest, _hm(eta)]
		_:
			if flip_t > s.time_s:
				text = "Co-pilot has the burn. Turnover in %s, then we brake for %s." % [_hm(flip_t - s.time_s), dest]
			else:
				text = "Co-pilot has the burn for %s. Arrival in %s." % [dest, _hm(eta)]
	Pages.annunciators(g, left, right, text, AV.GREEN if phase != "TURNING" else AV.AMBER, Pages.clock(sim), float(Time.get_ticks_msec()) / 1000.0)
