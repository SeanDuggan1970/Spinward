## Cinematic god's-eye view of a transfer. The camera hangs high above at an angle,
## framing the ship and its destination together, and slowly orbits. Earth and the
## Moon are at true scale; the ship model is exaggerated so it can be seen, and it
## points along its thrust vector with the drive lit while it burns. The planned path
## is drawn ahead (amber) and behind (dim), with other traffic as coloured sparks.
extends Node3D

const V := preload("res://sim/v3.gd")
const Navigation := preload("res://sim/navigation.gd")
const Kit := preload("res://view/flight/kit.gd")
const Models := preload("res://view/flight/models.gd")
const SkyKit := preload("res://view/flight/sky.gd")
const SystemMap := preload("res://view/system_map.gd")
const UI := preload("res://view/ui/ui_kit.gd")

## Metres per scene unit (1,000 km), so the whole Earth-Moon system fits in floats.
const UNIT := 1.0e6
const PATH_SAMPLES := 120
const DAY := 86400.0

var sim
var camera: Camera3D
var frame := "earth"
var _sun: DirectionalLight3D
var _earth: MeshInstance3D
var _moon: MeshInstance3D
var _ship: Node3D
var _ship_len := 26.0
var _plume: Node3D
var _path_ahead: ImmediateMesh
var _path_behind: ImmediateMesh
var _moon_orbit: ImmediateMesh
## Where the destination is going between now and arrival, and the meeting point.
var _dest_track: ImmediateMesh
var _rendezvous: Node3D
var _rendezvous_label: Label3D
var _places: Dictionary = {}
var _npc_dots: Dictionary = {}
var _line_mat: StandardMaterial3D
var _azimuth := 0.0
var _cam_pos := Vector3.ZERO
var _cam_target := Vector3.ZERO
var _cam_ready := false
var _path_key := ""
var _attitude := Basis.IDENTITY
## Live values for the overlay.
var readout: Dictionary = {}


func _init(owner_sim) -> void:
	sim = owner_sim
	frame = sim.state.location.get("frame", "earth")


func _ready() -> void:
	add_child(SkyKit.environment())
	_sun = DirectionalLight3D.new()
	_sun.light_energy = 1.5
	add_child(_sun)
	_earth = Kit.sphere(float(sim.data.bodies["earth"]["radius_m"]) / UNIT, SkyKit.body_material("earth"))
	(_earth.mesh as SphereMesh).radial_segments = 64
	(_earth.mesh as SphereMesh).rings = 32
	add_child(_earth)
	_moon = Kit.sphere(float(sim.data.bodies["moon"]["radius_m"]) / UNIT, SkyKit.body_material("moon"))
	add_child(_moon)
	_line_mat = StandardMaterial3D.new()
	_line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line_mat.vertex_color_use_as_albedo = true
	_line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_path_ahead = _line_node()
	_path_behind = _line_node()
	_moon_orbit = _line_node()
	_dest_track = _line_node()
	# A ring that always faces the camera (the kit torus lies in its holder's XY plane).
	_rendezvous = Node3D.new()
	_rendezvous.add_child(Kit.torus(1.0, 0.12, Kit.glow(UI.AMBER, 3.0)))
	add_child(_rendezvous)
	_rendezvous_label = Label3D.new()
	_rendezvous_label.text = "RENDEZVOUS"
	_rendezvous_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_rendezvous_label.fixed_size = true
	_rendezvous_label.pixel_size = 0.0008
	_rendezvous_label.font_size = 18
	_rendezvous_label.outline_size = 6
	_rendezvous_label.modulate = UI.AMBER
	_rendezvous_label.no_depth_test = true
	add_child(_rendezvous_label)
	for place in sim.data.places:
		var marker := Kit.sphere(1.0, Kit.glow(UI.TEXT, 2.0))
		add_child(marker)
		var label := Label3D.new()
		label.text = sim.data.places[place]["name"]
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.fixed_size = true
		label.pixel_size = 0.0009
		label.font_size = 22
		label.outline_size = 6
		label.modulate = UI.TEXT
		label.no_depth_test = true
		add_child(label)
		_places[place] = {"marker": marker, "label": label}
	var model := Models.ship(sim.state.ship, sim.data)
	_ship = Node3D.new()
	var inner: Node3D = model["node"]
	_ship.add_child(inner)
	_ship_len = float(model["length"])
	_plume = inner.find_child("DrivePlume", true, false)
	# A long exhaust streak so the burn reads from far above.
	var streak := Kit.cone(0.5, 3.0, 60.0, Kit.glow(Color("8fd0ff"), 3.0), Vector3(0, 0, _ship_len * 0.5 + 32.0))
	streak.name = "Streak"
	inner.add_child(streak)
	add_child(_ship)
	camera = Camera3D.new()
	camera.fov = 45.0
	camera.near = 0.05
	camera.far = 20000.0
	add_child(camera)
	camera.make_current()


func _line_node() -> ImmediateMesh:
	var im := ImmediateMesh.new()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	mi.material_override = _line_mat
	add_child(mi)
	return im


## Sim 64-bit position (trip frame, metres) to scene units, ecliptic north up.
func _p(a: Array) -> Vector3:
	return Vector3(a[0], a[2], -a[1]) / UNIT


func _d(a: Array) -> Vector3:
	return Vector3(a[0], a[2], -a[1])


func _process(dt: float) -> void:
	var s = sim.state
	var loc: Dictionary = s.location
	if loc.get("status") != "transit":
		return
	var eph = sim.ephemeris
	var t: float = s.time_s
	frame = loc["frame"]
	_earth.position = _p(eph.relative("earth", frame, t))
	_earth.rotation.y = t / DAY * TAU
	_moon.position = _p(eph.relative("moon", frame, t))
	var sun_dir := SkyKit.dir_between(eph.position("sun", t), eph.position(frame, t))
	_sun.look_at_from_position(Vector3.ZERO, -sun_dir, Vector3.UP if absf(sun_dir.y) < 0.99 else Vector3.RIGHT)

	var ship_pos := _p(Navigation.transit_position(loc, t))
	var dest_pos := _p(eph.relative(loc["to"], frame, t))
	var meet := _p(Navigation.transit_position(loc, float(loc["arrive_t"])))
	var moon_pos := _moon.position
	var near_moon := ship_pos.distance_to(moon_pos) < 60.0 and float(loc.get("peri_t", -1.0)) > 0.0
	# During a lunar pass, frame the ship and the Moon tight; otherwise the whole trip.
	var cam_dist := _frame_camera(ship_pos, moon_pos, moon_pos, dt) if near_moon else _frame_camera(ship_pos, dest_pos, meet, dt)
	# The destination's own track to the meeting point, and the meeting point itself.
	_dest_track.clear_surfaces()
	var track := Navigation.track_id(sim.data, loc["to"], frame)
	if track != "":
		_dest_track.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for k in 25:
			_dest_track.surface_set_color(Color(UI.AMBER, 0.45))
			_dest_track.surface_add_vertex(_p(eph.relative(track, frame, lerpf(t, float(loc["arrive_t"]), float(k) / 24.0))))
		_dest_track.surface_end()
	_rendezvous.position = meet
	_rendezvous.scale = Vector3.ONE * cam_dist * 0.012
	_rendezvous.look_at(camera.global_position, Vector3.UP)
	_rendezvous_label.position = meet - Vector3(0, cam_dist * 0.025, 0)

	# Paths: the whole planned transfer, split at the ship, and the Moon's orbit.
	var key := "%s%s%s" % [loc["depart_t"], loc["arrive_t"], loc["to"]]
	if key != _path_key:
		_path_key = key
		_draw_moon_orbit(t)
	_draw_path(loc, t)

	# Markers scale with the view so they stay legible at any zoom.
	for place in _places:
		var at := _p(eph.relative(place, frame, t))
		var m: Dictionary = _places[place]
		m["marker"].position = at
		m["marker"].scale = Vector3.ONE * cam_dist * (0.006 if place == loc["to"] else 0.004)
		m["label"].position = at + Vector3(0, cam_dist * 0.02, 0)
		m["label"].modulate = UI.AMBER if place == loc["to"] else Color(UI.TEXT, 0.8)
	_update_npcs(t, cam_dist)

	# The ship, exaggerated, nose along the thrust vector.
	var accel := _d(Navigation.transit_accel(loc, t))
	var vel := _d(Navigation.transit_velocity(loc, t))
	var thrusting := accel.length() > 1e-5
	var face := accel.normalized() if thrusting else (vel.normalized() if vel.length() > 1.0 else Vector3.FORWARD)
	var want := Basis.looking_at(face, Vector3.UP if absf(face.y) < 0.98 else Vector3.RIGHT)
	_attitude = want if not _cam_ready else Basis(_attitude.get_rotation_quaternion().slerp(want.get_rotation_quaternion(), clampf(dt * 3.0, 0.0, 1.0)))
	var ship_scale := cam_dist * 0.045 / _ship_len
	_ship.transform = Transform3D(_attitude.scaled(Vector3.ONE * ship_scale), ship_pos)
	if _plume:
		_plume.visible = thrusting
	_ship.find_child("Streak", true, false).visible = thrusting
	var into := V.dot(V.normalized(Navigation.transit_accel(loc, t)), V.normalized(Navigation.transit_velocity(loc, t)))
	readout = {
		"phase": "COASTING" if not thrusting else ("BURNING AHEAD" if into > 0.3 else ("BRAKING" if into < -0.3 else "BURNING ACROSS")),
		"speed": vel.length(), "accel": accel.length(),
		"remaining": V.distance(Navigation.transit_position(loc, t), eph.relative(loc["to"], frame, t)),
		"eta": float(loc["arrive_t"]) - t,
		"moon_alt": V.distance(Navigation.transit_position(loc, t), eph.relative("moon", frame, t)) - float(sim.data.bodies["moon"]["radius_m"]),
		"route": loc.get("route_label", ""),
	}
	_cam_ready = true


## Hang the camera high above and to one side, framing the ship, the destination
## and the point where they will meet.
func _frame_camera(ship_pos: Vector3, dest_pos: Vector3, meet: Vector3, dt: float) -> float:
	var mid := (ship_pos + dest_pos + meet) / 3.0
	var sep := maxf(ship_pos.distance_to(dest_pos), maxf(ship_pos.distance_to(meet), dest_pos.distance_to(meet)))
	var dist := maxf(sep * 1.45, 6.0)
	var chord := (meet - ship_pos)
	chord.y = 0.0
	var side := Vector3.UP.cross(chord.normalized()) if chord.length() > 1e-3 else Vector3.RIGHT
	_azimuth += dt * 0.025
	var dir := (side.rotated(Vector3.UP, sin(_azimuth) * 0.6) * cos(deg_to_rad(52.0)) + Vector3.UP * sin(deg_to_rad(52.0))).normalized()
	var want_pos := mid + dir * dist
	if not _cam_ready:
		_cam_pos = want_pos
		_cam_target = mid
	else:
		var k := clampf(dt * 1.5, 0.0, 1.0)
		_cam_pos = _cam_pos.lerp(want_pos, k)
		_cam_target = _cam_target.lerp(mid, k)
	camera.look_at_from_position(_cam_pos, _cam_target, Vector3.UP)
	return _cam_pos.distance_to(_cam_target)


func _draw_path(loc: Dictionary, t: float) -> void:
	var start := float(loc["depart_t"])
	var end := float(loc["arrive_t"])
	_path_ahead.clear_surfaces()
	_path_behind.clear_surfaces()
	var ahead := PackedVector3Array()
	var behind := PackedVector3Array()
	for k in PATH_SAMPLES + 1:
		var tk := lerpf(start, end, float(k) / PATH_SAMPLES)
		var p := _p(Navigation.transit_position(loc, tk))
		if tk <= t:
			behind.append(p)
		else:
			if ahead.is_empty() and not behind.is_empty():
				ahead.append(behind[-1])
			ahead.append(p)
	for pair in [[behind, _path_behind, Color(UI.DIM, 0.6)], [ahead, _path_ahead, Color(UI.AMBER, 0.95)]]:
		var pts: PackedVector3Array = pair[0]
		if pts.size() < 2:
			continue
		var im: ImmediateMesh = pair[1]
		im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for p in pts:
			im.surface_set_color(pair[2])
			im.surface_add_vertex(p)
		im.surface_end()


func _draw_moon_orbit(t: float) -> void:
	_moon_orbit.clear_surfaces()
	_moon_orbit.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	# One sidereal month, so the line closes without doubling back over itself.
	for k in 110:
		_moon_orbit.surface_set_color(Color(0.3, 0.55, 1.0, 0.6))
		_moon_orbit.surface_add_vertex(_p(sim.ephemeris.relative("moon", frame, t + k * (27.3 / 109.0) * DAY)))
	_moon_orbit.surface_end()


func _update_npcs(t: float, cam_dist: float) -> void:
	var seen := {}
	for npc in sim.state.npcs:
		if npc["location"]["status"] != "transit" or npc["location"].get("frame", "earth") != frame:
			continue
		var id: String = npc["id"]
		seen[id] = true
		if not _npc_dots.has(id):
			var dot := Kit.sphere(1.0, Kit.glow(SystemMap.fleet_colour(sim, npc), 2.5))
			add_child(dot)
			_npc_dots[id] = dot
		_npc_dots[id].position = _p(Navigation.transit_position(npc["location"], t))
		_npc_dots[id].scale = Vector3.ONE * cam_dist * 0.0025
	for id in _npc_dots.keys():
		if not seen.has(id):
			_npc_dots[id].queue_free()
			_npc_dots.erase(id)
