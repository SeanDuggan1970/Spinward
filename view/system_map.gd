## Top-down orbital map from real positions: bodies, orbits, places, NPC traffic and
## (in transit) the player's transfer. Two scales by the trip's frame: the Earth-Moon
## system, or the Sun's domain out to Saturn and beyond, with AU rings.
## Mouse wheel zooms. Used full-screen in transit and as a panel at stations.
extends Control

const UI := preload("res://view/ui/ui_kit.gd")
const Navigation := preload("res://sim/navigation.gd")
const V := preload("res://sim/v3.gd")

const DAY := 86400.0
const FLEET_COLOURS := {
	"Luna Cooperative": Color("d2702c"), "The Commons": Color("7fb8d8"), "Terran Compact": Color("d9d4c7"),
	"Kernel Settlers": Color("b8d27f"), "Independent": Color("c9a24a"), "Kalpana Settlement Trust": Color("e0a0c8"),
}

var sim
var frame := "earth"
var centre_offset := Vector2.ZERO
var show_npc_labels := true
var zoom := 1.0
var _font: Font


func _init(owner_sim) -> void:
	sim = owner_sim
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	_font = UI.make_theme().default_font


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = minf(zoom * 1.2, 400.0 if frame == "sun" else 40.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = maxf(zoom / 1.2, 0.5)


func _process(_dt: float) -> void:
	queue_redraw()


static func fleet_colour(sim_, npc: Dictionary) -> Color:
	return FLEET_COLOURS.get(sim_.data.npcs["fleets"][npc["fleet"]]["operator"], UI.DIM)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UI.BG)
	var s = sim.state
	var eph = sim.ephemeris
	var t: float = s.time_s
	var centre := size * 0.5 + centre_offset
	var solar := frame == "sun"
	var radius_m := (_solar_reach(t) if solar else 4.8e8) / zoom
	var px := (minf(size.x, size.y) * 0.46) / radius_m
	var origin: Array = eph.position(frame, t)
	var to_screen := func(p: Array) -> Vector2:
		return centre + Vector2(p[0], -p[1]) * px
	var highlight: String = s.location.get("to", s.location.get("place", ""))
	var origin_place: String = s.location.get("from", "")

	if solar:
		_draw_solar(t, px, centre, to_screen)
	else:
		for r in range(1, 6):
			draw_arc(centre, r * 1.0e8 * px, 0.0, TAU, 96, Color(UI.PANEL_EDGE, 0.35), 1.0)
		var path := PackedVector2Array()
		for i in 121:
			path.append(to_screen.call(eph.relative("moon", frame, t + i * 0.25 * DAY)))
		draw_polyline(path, Color(UI.DIM, 0.5), 1.0)
		for body in ["earth", "moon"]:
			var at: Vector2 = to_screen.call(eph.relative(body, frame, t))
			var r := maxf(float(sim.data.bodies[body]["radius_m"]) * px, 4.0)
			draw_circle(at, r, Color("3b6ea8") if body == "earth" else Color("9a978f"))
			draw_string(_font, at + Vector2(r + 4, -r), sim.data.bodies[body]["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.DIM)

	for place in sim.data.places:
		if not preload("res://sim/perks.gd").place_open(s, sim.data, place):
			continue
		# Each map shows its own neighbourhood: cislunar ports on the Earth map; at
		# solar scale only the trip's ends (the rest sit on their worlds).
		if not solar and V.length(eph.relative(place, frame, t)) > 2.0e9:
			continue
		if solar and place != highlight and place != origin_place:
			continue
		var at: Vector2 = to_screen.call(eph.relative(place, frame, t))
		var col := UI.AMBER if place == highlight else UI.TEXT
		draw_rect(Rect2(at - Vector2(3, 3), Vector2(6, 6)), col)
		draw_string(_font, at + Vector2(6, 14), sim.data.places[place]["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)

	# NPC traffic: a dot per ship in flight, with a faint trace of the path still ahead.
	for npc in s.npcs:
		if npc["location"]["status"] != "transit" or npc["location"].get("frame", "earth") != frame:
			continue
		var loc: Dictionary = npc["location"]
		var p: Vector2 = to_screen.call(Navigation.transit_position(loc, t))
		var col := fleet_colour(sim, npc)
		var trace := _path_points(loc, t, float(loc["arrive_t"]), 12, to_screen)
		if trace.size() >= 2:
			draw_polyline(trace, Color(col, 0.15), 1.0)
		draw_circle(p, 2.5, col)
		if show_npc_labels and zoom >= 1.0:
			draw_string(_font, p + Vector2(5, -4), npc["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(col, 0.75))

	if s.location.get("status") == "transit":
		var loc: Dictionary = s.location
		# The planned path curves to match the destination's motion: dim behind, amber ahead.
		var behind := _path_points(loc, float(loc["depart_t"]), t, 40, to_screen)
		var ahead := _path_points(loc, t, float(loc["arrive_t"]), 60, to_screen)
		if behind.size() >= 2:
			draw_polyline(behind, Color(UI.DIM, 0.6), 1.5)
		if ahead.size() >= 2:
			draw_polyline(ahead, Color(UI.AMBER, 0.8), 1.5)
		# Where the destination goes between now and arrival, and the meeting point.
		var track_body := Navigation.track_id(sim.data, loc["to"], frame)
		if track_body != "":
			var track := PackedVector2Array()
			for k in 25:
				track.append(to_screen.call(eph.relative(track_body, frame, lerpf(t, float(loc["arrive_t"]), float(k) / 24.0))))
			draw_polyline(track, Color(UI.AMBER, 0.3), 1.0)
		var meet: Vector2 = to_screen.call(Navigation.transit_position(loc, float(loc["arrive_t"])))
		draw_arc(meet, 7.0, 0.0, TAU, 20, UI.AMBER, 1.5)
		draw_string(_font, meet + Vector2(9, 14), "RENDEZVOUS", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI.AMBER)
		var ship: Vector2 = to_screen.call(Navigation.transit_position(loc, t))
		# The ship points along its thrust (the drive pushes along the nose).
		var a: Array = Navigation.transit_accel(loc, t)
		var v: Array = Navigation.transit_velocity(loc, t)
		var face := Vector2(a[0], -a[1]) if V.length(a) > 1e-6 else Vector2(v[0], -v[1])
		var dir := face.normalized() if face.length() > 1e-9 else Vector2.RIGHT
		var side := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([ship + dir * 9, ship - dir * 6 + side * 5, ship - dir * 6 - side * 5]), UI.GOOD)
		if V.length(a) > 1e-6:
			draw_line(ship - dir * 6, ship - dir * 16, Color("8fd0ff"), 2.0)
		var into := V.dot(V.normalized(a), V.normalized(v)) if V.length(a) > 1e-6 else 0.0
		var phase := "COASTING" if V.length(a) <= 1e-6 else ("ACCELERATING" if into > 0.3 else ("BRAKING" if into < -0.3 else "BURNING ACROSS"))
		draw_string(_font, ship + Vector2(10, -8), phase, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI.GOOD)


## How far out the solar map reaches before zooming: the trip's ends with a margin
## (or the inner system).
func _solar_reach(t: float) -> float:
	var loc: Dictionary = sim.state.location
	var reach := 3.0e11
	for key in ["from", "to", "place"]:
		if loc.has(key) and sim.data.places.has(loc[key]):
			reach = maxf(reach, V.length(sim.ephemeris.position(loc[key], t)) * 1.25)
	return reach


## The Sun's domain: AU rings, the Sun, orbits and the worlds on them.
func _draw_solar(t: float, px: float, centre: Vector2, to_screen: Callable) -> void:
	var au := 1.495978707e11
	for r: float in [1.0, 2.0, 5.0, 10.0, 20.0, 30.0, 50.0]:
		var rp: float = float(r) * au * px
		if rp > 6.0 and rp < maxf(size.x, size.y) * 1.5:
			draw_arc(centre, rp, 0.0, TAU, 128, Color(UI.PANEL_EDGE, 0.3), 1.0)
			draw_string(_font, centre + Vector2(rp + 3, -3), "%d AU" % int(r), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(UI.DIM, 0.6))
	draw_circle(centre, 5.0, Color("fff2c0"))
	var eph = sim.ephemeris
	for body in sim.data.bodies:
		var b: Dictionary = sim.data.bodies[body]
		if b.get("parent", "") != "sun":
			continue
		var kind: String = b.get("kind", "")
		var period := float(b["elements"].get("period_days", 365.25)) * DAY
		var orbit := PackedVector2Array()
		for k in 97:
			orbit.append(to_screen.call(eph.position(body, t + period * float(k) / 96.0)))
		var major := kind == "planet" or kind == "dwarf"
		draw_polyline(orbit, Color(0.3, 0.55, 1.0, 0.3 if major else 0.12), 1.0)
		var at: Vector2 = to_screen.call(eph.position(body, t))
		var col: Color = {"planet": Color("c9c4b6"), "dwarf": Color("a8a39b")}.get(kind, Color(UI.DIM, 0.8))
		draw_circle(at, 4.0 if kind == "planet" else 2.5, col)
		if major or zoom >= 6.0:
			draw_string(_font, at + Vector2(6, -6), b["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12 if major else 10, Color(col, 0.9))


func _path_points(loc: Dictionary, t0: float, t1: float, n: int, to_screen: Callable) -> PackedVector2Array:
	var pts := PackedVector2Array()
	if t1 <= t0:
		return pts
	for k in n + 1:
		pts.append(to_screen.call(Navigation.transit_position(loc, lerpf(t0, t1, float(k) / float(n)))))
	return pts
