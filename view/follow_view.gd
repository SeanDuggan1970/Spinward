## In transit: your ship, close, in the real sky. The default transit view.
##
## The ship sits at the origin at true size, in its burn attitude. Its panels track
## the Sun, its dish holds on the destination, and its plume shows while it burns.
## Around it the worlds sit on the sky at their true angular sizes, wearing what is on
## them, and the ports you are leaving or nearing appear as real models while they
## are within a few tens of kilometres.
##
## Drag (either mouse button) to orbit, use the wheel to zoom, or use the arrow keys.
## Leave it alone for a while and the director takes over. It cuts between set-ups
## chosen for the moment:
##   - a chase, a slow orbit, a fly-past, a dolly along the hull
##   - the nearest big world behind the ship, and the same on a long lens, where the
##     world looms
##   - backlit against the Sun, and the drive while it burns
##   - framing the station at either end of the trip
extends Node3D

const V := preload("res://sim/v3.gd")
const Navigation := preload("res://sim/navigation.gd")
const Kit := preload("res://view/flight/kit.gd")
const SkyKit := preload("res://view/flight/sky.gd")
const Models := preload("res://view/flight/models.gd")
const Livery := preload("res://view/flight/livery.gd")
const ShipRig := preload("res://view/flight/ship_rig.gd")
const ProjectSystem := preload("res://sim/systems/project_system.gd")
const ShipStats := preload("res://sim/ship_stats.gd")

const SKY_DISTANCE := 60000.0
## Burning, a thrust direction this far off the present one (radians) is a flip coming:
## start round early for it.
const FLIP_ANGLE := 1.05
## Coasting, start round for the next burn this many real seconds earlier than the turn needs.
const TURN_MARGIN_S := 1.0
## RCS puffs: how long each lasts (real seconds), and the least time between puffs from one quad.
const PUFF_S := 0.45
const PUFF_GAP_S := 0.12
## Hands off this long (real seconds) and the director takes the camera.
const IDLE_S := 8.0
const SHOT_S := 11.0
const FADE_S := 0.35
## Ports this close (metres) are shown as models.
const STATION_RANGE_M := 30000.0
## Ports are drawn for the first and last game seconds of a trip: leaving, backing
## out and pulling away; arriving, closing in to where the approach takes over.
const PORT_WINDOW_S := 1200.0
## Leaving, the ship backs off the port nose-first for this long (game seconds, at x1),
## then turns to point along its first burn and holds there until the drive lights.
const BACKOUT_S := 12.0

var sim
var camera: Camera3D
## "director" or "free", and the director's current set-up.
var mode := "director"
var shot := ""
var shot_label := ""
var shot_clock := 0.0
var _idle := 0.0
var readout: Dictionary = {}

var _sun: DirectionalLight3D
var _sun_disc: MeshInstance3D
var _fill: OmniLight3D
var _bodies: Dictionary = {}
var _dressed: Dictionary = {}
var _ship: Node3D
var _rig: Dictionary = {}
var _plume: Node3D
var _length := 30.0
var _radius := 6.0
## The middle of the ship (model space), what the camera looks at.
var _pivot := Vector3.ZERO
var _nose_z := 0.0
## The nose (view space) and how fast it is swinging (a world vector, rad per second of
## turning: real seconds, or faster above balance.turning.real_time_scale).
var _fwd := Vector3.FORWARD
var _omega := Vector3.ZERO
var _ready_basis := false
## This trip's turn limits (ShipStats.turn_limits) and plume alignment (radians).
var _turn_rate := 0.2
var _turn_accel := 0.1
var _plume_align := 0.35
var _lit := false
var _real_time_scale := 1000.0
## The drive's acceleration this trip (m/s^2).
var _drive_mps2 := 0.03
## This trip's burns: [start game time, end game time, view direction at the start].
var _burns: Array = []
var _puffs: Array = []
var _puff_mat: StandardMaterial3D
var _thrusting := false
var _sun_dir := Vector3.UP
var _stations: Dictionary = {}
## [the way we leave, the way we arrive] (view space), for the trip departed at _corridor_key.
var _corridor := [Vector3.FORWARD, Vector3.FORWARD]
var _corridor_key := -1.0
var _first_burn_t := INF
## Free camera, about the ship's middle: yaw, pitch (radians), distance (metres).
var _yaw := 0.6
var _pitch := 0.25
var _dist := 0.0
var _dragging := false
var _rng := RandomNumberGenerator.new()
var _fade: ColorRect
var _shot_seed := 0.0
var _shine: DirectionalLight3D
var _dust: CPUParticles3D
## What the current set-up looks at and from where (shot-specific state).
var _target_body := ""


func _init(owner_sim) -> void:
	sim = owner_sim
	_rng.randomize()


func _ready() -> void:
	add_child(SkyKit.environment())
	_sun = DirectionalLight3D.new()
	_sun.light_energy = 1.6
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 600.0
	add_child(_sun)
	_sun_disc = Kit.sphere(1.0, Kit.glow(Color("fff6e0"), 6.0))
	add_child(_sun_disc)
	for body in sim.data.bodies:
		if body == "sun":
			continue
		var mesh := SkyKit.body_mesh(sim.data, body, 1.0)
		mesh.visible = false
		add_child(mesh)
		_bodies[body] = mesh
	var model := Models.ship(sim.state.ship, sim.data, Livery.for_ship(sim.data, "", sim.state.ship.get("name", ""), true))
	_ship = model["node"]
	_rig = model["rig"]
	_plume = _ship.find_child("DrivePlume", true, false)
	_length = float(model["length"])
	_radius = float(model["radius"])
	_nose_z = float(model["nose_z"])
	_pivot = Vector3(0, 0, _nose_z + _length * 0.5)
	add_child(_ship)
	_dist = _length * 2.4
	camera = Camera3D.new()
	camera.fov = 50.0
	camera.near = 0.3
	camera.far = SKY_DISTANCE * 6.0
	add_child(camera)
	camera.make_current()
	# A soft work light that rides with the camera, so the design reads on the night side.
	_fill = OmniLight3D.new()
	_fill.light_energy = 0.6
	_fill.light_color = Color("cfd8e6")
	_fill.omni_range = 4000.0
	camera.add_child(_fill)
	var layer := CanvasLayer.new()
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	_shine = SkyKit.shine_light()
	add_child(_shine)
	_dust = SkyKit.dust(_length * 1.5 + 20.0)
	add_child(_dust)
	_update_world(0.0)
	_next_shot()
	_update_camera(0.0)


# --- input: the free camera -------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			_dragging = event.pressed
			if event.pressed:
				_take_over()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_take_over()
			_dist = clampf(_dist * (0.88 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.14), _radius * 1.4 + 3.0, _length * 60.0)
	elif event is InputEventMouseMotion and _dragging:
		_take_over()
		_yaw -= event.relative.x * 0.006
		_pitch = clampf(_pitch + event.relative.y * 0.006, -1.45, 1.45)


## Hand the camera to the pilot, starting from wherever the director had it.
func _take_over() -> void:
	_idle = 0.0
	if mode == "free":
		return
	mode = "free"
	shot_label = ""
	_fade.color.a = 0.0
	var centre := _ship.transform * _pivot
	var off := camera.global_position - centre
	_dist = clampf(off.length(), _radius * 1.4 + 3.0, _length * 60.0)
	_yaw = atan2(off.x, off.z)
	_pitch = asin(clampf(off.y / maxf(off.length(), 1e-3), -1.0, 1.0))
	camera.fov = 50.0


func _process(dt: float) -> void:
	_update_world(dt)
	if mode == "free":
		var keys := Vector2(Input.get_axis("transit_look_right", "transit_look_left"), Input.get_axis("transit_look_down", "transit_look_up"))
		if keys != Vector2.ZERO:
			_idle = 0.0
			_yaw += keys.x * dt * 0.9
			_pitch = clampf(_pitch + keys.y * dt * 0.9, -1.45, 1.45)
		if not _dragging:
			_idle += dt
		if _idle > IDLE_S:
			mode = "director"
			_next_shot()
	else:
		shot_clock += dt
		if shot_clock >= SHOT_S:
			_next_shot()
		var a := 0.0
		if shot_clock < FADE_S:
			a = 1.0 - shot_clock / FADE_S
		elif shot_clock > SHOT_S - FADE_S:
			a = (shot_clock - SHOT_S + FADE_S) / FADE_S
		_fade.color.a = a
	_update_camera(dt)


# --- the world around the ship -------------------------------------------------------

func _update_world(dt: float) -> void:
	var s = sim.state
	var loc: Dictionary = s.location
	if loc.get("status") != "transit":
		return
	var eph = sim.ephemeris
	var t: float = s.time_s
	var frame: String = loc["frame"]
	var here: Array = V.add(eph.position(frame, t), Navigation.transit_position(loc, t))
	_sun_dir = SkyKit.dir_between(eph.position("sun", t), here)
	_sun.look_at_from_position(Vector3.ZERO, -_sun_dir, Vector3.UP if absf(_sun_dir.y) < 0.99 else Vector3.RIGHT)
	var au := V.length(V.sub(here, eph.position("sun", t))) / 1.495978707e11
	_sun_disc.position = _sun_dir * SKY_DISTANCE * 3.0
	_sun_disc.scale = Vector3.ONE * SKY_DISTANCE * 3.0 * 0.0047 * 3.0 / maxf(au, 0.3)
	_sun.light_energy = 1.6 * clampf(1.0 / sqrt(au), 0.45, 1.6)
	SkyKit.set_eclipse(_sun_dir)
	var seen: Array = SkyKit.visible_bodies(sim.data, eph, here, t)
	for body in _bodies:
		_bodies[body].visible = false
	var built := {}
	for id in sim.data.projects:
		built[id] = ProjectSystem.progress(s, sim.data, id) if s.projects.get(id, {}).get("revealed", false) else 0.0
	for k in seen.size():
		var body: String = seen[k][0]
		var node: MeshInstance3D = _bodies[body]
		var shell := SKY_DISTANCE * (0.55 + 0.45 * float(k) / float(maxi(1, seen.size() - 1)))
		node.visible = true
		node.position = (seen[k][1] as Vector3) * shell
		node.scale = Vector3.ONE * shell * sin(float(seen[k][2]))
		SkyKit.update_body(node, _sun_dir, t)
		SkyKit.set_distance(node, float(seen[k][3]))
		if not _dressed.has(body):
			_dressed[body] = true
			SkyKit.dress_body(node, sim.data, body, -(seen[k][1] as Vector3), _sun_dir, built)
		# In a world's shadow, the ship goes dark too.
		var along := node.position.dot(_sun_dir)
		var r_sky := shell * sin(float(seen[k][2]))
		if along > 0.0 and (node.position - _sun_dir * along).length() < r_sky:
			SkyKit.set_eclipse(_sun_dir, node.position, r_sky)
	readout["seen"] = seen
	SkyKit.aim_shine(_shine, SkyKit.planetshine(sim.data, seen, _sun_dir))
	# The ports at each end, for the first and last minutes of the trip
	# (PORT_WINDOW_S). Leaving, the port sits off the nose with its docking face to us
	# and falls away as we back out, turn and go. Arriving, it lies ahead and we close
	# on it, slowing, to the point where the approach takes over (the flight scene's
	# spawn distance), so the hand-over picks up where this leaves off. Each corridor
	# runs along the trip's own first or last leg: we leave and arrive the way the
	# path goes.
	#
	# Arriving on a trip with a final approach (Navigation.add_approach), the port is
	# where the sim puts it relative to us, its docking face along +Z as the flight
	# scene builds it, and the hand-over point matches the flight scene's start.
	_corridors(loc)
	var elapsed := t - float(loc["depart_t"])
	var left := float(loc["arrive_t"]) - t
	var app: Array = Navigation.approach_state(loc, t)
	for place in [loc["from"], loc["to"]]:
		if not sim.data.places.has(place) or not sim.data.places[place].has("station"):
			continue
		var leaving: bool = place == loc["from"]
		var tau := elapsed if leaving else left
		var near := tau >= 0.0 and tau < PORT_WINDOW_S
		var on_approach: bool = not leaving and app[3] != ""
		var from_port := Vector3.ZERO
		if on_approach:
			var rel: Array = app[0]
			from_port = Vector3(rel[0], rel[2], -rel[1])
			near = from_port.length() < STATION_RANGE_M
		if near and not _stations.has(place):
			var geom: Dictionary = sim.data.places[place]["station"]
			var st := Models.station(geom, sim.data.places[place]["name"], Livery.for_station(sim.data, place))
			# The approach corridor's lights are for pilots coming in, not for the camera.
			for c in st["node"].get_children():
				if c is MeshInstance3D:
					c.visible = false
			add_child(st["node"])
			_stations[place] = {"model": st, "rate": float(geom["spin_rpm"]) * TAU / 60.0}
		if _stations.has(place):
			var entry: Dictionary = _stations[place]
			var st: Dictionary = entry["model"]
			# From the port toward the ship: along the way we leave, or back along the
			# way we came in.
			var d: Vector3 = _corridor[0] if leaving else -_corridor[1]
			var at := -d * (_port_gap(place, tau, leaving) + float(st["port_z"]))
			var facing := Basis.looking_at(-d, Vector3.UP if absf(d.y) < 0.98 else Vector3.RIGHT)
			if on_approach:
				# The sim's hand-over point sits hub_length / 2 + handover_m from the centre;
				# the flight scene's ship origin sits port_z + handover_m - nose_z from it.
				var geom: Dictionary = sim.data.places[place]["station"]
				at = -from_port + Vector3(0, 0, float(geom["hub_length_m"]) * 0.5 - float(st["port_z"]) + _nose_z)
				facing = Basis.IDENTITY
			st["node"].visible = near
			st["node"].position = at
			st["node"].basis = facing
			st["rotor"].rotation.z = fposmod(t * float(entry["rate"]), TAU)
			entry["dist"] = at.length() if near else INF
	# Attitude: along the thrust while burning (from toward the target round to braking
	# against it); coasting, hold it. The ship turns with inertia (ShipRig.turn_step),
	# so it starts round early enough to be lined up when the drive lights, and swings
	# through a flip half a turn before the thrust does.
	var thrust: Array = _drive_accel(loc, t)
	_thrusting = V.length(thrust) > 1e-6
	var thrust_dir := _view_dir(thrust)
	# Game seconds per second of turning: turns play out in real time up to
	# _real_time_scale, faster above it so the ship keeps up with a voyage's thrust.
	var speedup := maxf(1.0, float(s.time_scale) / _real_time_scale)
	var scale := maxf(1.0, float(s.time_scale)) / speedup
	var forward := _fwd
	var next := _next_burn(t)
	# Backing off the port, nose to it; then round to the next burn's direction once it
	# is due within the time a turn takes; coming in on the last stretch, nose to the port.
	if elapsed < BACKOUT_S:
		forward = -_corridor[0]
	elif _thrusting:
		forward = thrust_dir
		var lead := ShipRig.turn_time(PI, _turn_rate, _turn_accel) * 0.5 * scale
		# Look ahead only within this burn: the thrust at its very end can be anything.
		var t_ahead := minf(t + lead, _burn_end(t) - 2.0)
		var ahead := _view_dir(_drive_accel(loc, t_ahead)) if t_ahead > t else Vector3.ZERO
		if ahead != Vector3.ZERO and ahead.angle_to(thrust_dir) > FLIP_ANGLE:
			forward = ahead
	elif next >= 0 and (t < _first_burn_t or float(_burns[next][0]) - t <= (ShipRig.turn_time(_fwd.angle_to(_burns[next][2]), _turn_rate, _turn_accel) + TURN_MARGIN_S) * scale):
		forward = _burns[next][2]
	elif app[3] in ["corridor", "hold"]:
		# On the docking corridor, nose to the port, braking on the thrusters.
		forward = Vector3.FORWARD
	elif left < PORT_WINDOW_S and app[3] == "":
		forward = _corridor[1]
	var omega_was := _omega
	if not _ready_basis:
		_fwd = forward
		_omega = Vector3.ZERO
		_ready_basis = true
	elif dt > 0.0 and not s.paused:
		var step := ShipRig.turn_step(_fwd, _omega, forward, _turn_rate, _turn_accel, dt * speedup)
		_fwd = step[0]
		_omega = step[1]
	_ship.basis = ShipRig.roll_to_sun(_fwd, _sun_dir)
	if dt > 0.0:
		_rcs_puffs((_omega - omega_was) / (dt * speedup), dt)
	# The drive lights once the nose is round to the thrust, and stays lit until it
	# falls well behind (twice as far), so it doesn't flicker under high compression.
	var off := _fwd.angle_to(thrust_dir) if _thrusting else PI
	_lit = _thrusting and off < _plume_align * (2.0 if _lit else 1.0)
	if _plume:
		_plume.visible = _lit
	var dest_dir := SkyKit.dir_between(eph.position(loc["to"], t), here)
	ShipRig.set_fold(_rig, ShipRig.transit_fold(loc, t))
	ShipRig.aim(_rig, _ship.basis, _sun_dir, dest_dir * 1.0e6, dt)
	var v_now: Array = Navigation.transit_velocity(loc, t)
	readout["speed"] = V.length(v_now)
	readout["accel"] = V.length(thrust)
	readout["eta"] = float(loc["arrive_t"]) - t
	readout["remaining"] = V.distance(here, eph.position(loc["to"], t))
	readout["dest_dir"] = dest_dir
	readout["phase"] = ("TURNING" if _omega.length() > 0.02 else "COASTING") if not _thrusting else ("TURNING" if not _lit else ("ACCELERATING" if V.dot(V.normalized(thrust), V.normalized(v_now)) > 0.3 else ("BRAKING" if V.dot(V.normalized(thrust), V.normalized(v_now)) < -0.3 else "BURNING ACROSS")))
	if app[3] in ["corridor", "hold"] or app[3] == "swing" and not _thrusting:
		readout["phase"] = "ON APPROACH"


## The trip's corridors, once per trip: [the way we leave, the way we arrive], as
## directions of travel in view space, from where the path first moves and where it
## last does (a quick plan sits still at the port before its burn).
func _corridors(loc: Dictionary) -> void:
	var key := float(loc["depart_t"])
	if key == _corridor_key:
		return
	_corridor_key = key
	var t0 := key
	var t1 := float(loc["arrive_t"])
	var span := clampf((t1 - t0) * 0.01, 120.0, 21600.0)
	# Measured from the ports themselves (the ship rides along with a port while it
	# waits on it), so each corridor is the way we pull away from it or come in to it.
	var eph = sim.ephemeris
	var frame: String = loc["frame"]
	var out := Vector3.ZERO
	var inward := Vector3.ZERO
	for k in range(1, 100):
		var ta := minf(t0 + span * float(k), t1)
		var a := V.sub(Navigation.transit_position(loc, ta), eph.relative(loc["from"], frame, ta))
		if out == Vector3.ZERO and V.length(a) > 2000.0:
			out = Vector3(a[0], a[2], -a[1]).normalized()
		var tb := maxf(t1 - span * float(k), t0)
		var b := V.sub(eph.relative(loc["to"], frame, tb), Navigation.transit_position(loc, tb))
		if inward == Vector3.ZERO and V.length(b) > 2000.0:
			inward = Vector3(b[0], b[2], -b[1]).normalized()
		if out != Vector3.ZERO and inward != Vector3.ZERO:
			break
	_corridor = [out if out != Vector3.ZERO else Vector3.FORWARD, inward if inward != Vector3.ZERO else Vector3.FORWARD]
	# Every burn (when the drive lights and goes out, and which way it first points),
	# so the ship can be lined up before each one.
	_burns = []
	var on := -1.0
	var was := false
	for k in 401:
		var tk := lerpf(t0, t1, float(k) / 400.0)
		var lit := V.length(_drive_accel(loc, tk)) > 1e-6
		if lit != was:
			var edge := t0 if k == 0 else _edge(loc, lerpf(t0, t1, float(k - 1) / 400.0), tk, lit)
			if lit:
				on = edge
			else:
				_burns.append([on, edge])
		was = lit
	if was:
		_burns.append([on, t1])
	for b in _burns:
		b.append(_view_dir(_drive_accel(loc, minf(float(b[0]) + 1.0, float(b[1])))))
	_first_burn_t = float(_burns[0][0]) if not _burns.is_empty() else INF
	var limits: Array = ShipStats.turn_limits(sim.state.ship, sim.data)
	_turn_rate = float(limits[0])
	_drive_mps2 = ShipStats.accel_mps2(sim.state.ship, sim.data)
	_turn_accel = float(limits[1])
	_plume_align = deg_to_rad(float(sim.data.balance["turning"]["plume_align_deg"]))
	_real_time_scale = maxf(1.0, float(sim.data.balance["turning"]["real_time_scale"]))


## The moment the drive lights (lit) or goes out between ta and tb, to a second or so.
func _edge(loc: Dictionary, ta: float, tb: float, lit: bool) -> float:
	for _i in 30:
		if tb - ta < 1.0:
			break
		var tm := (ta + tb) * 0.5
		if (V.length(_drive_accel(loc, tm)) > 1e-6) == lit:
			tb = tm
		else:
			ta = tm
	return tb


## What the main drive pushes (the trip's thrust), but none on the docking corridor,
## holding off the port, or for a swing gentler than a third of the drive: there
## the thrusters do the work.
func _drive_accel(loc: Dictionary, t: float) -> Array:
	var app: Array = Navigation.approach_state(loc, t)
	if app[3] in ["corridor", "hold"] or app[3] == "swing" and V.length(app[2]) < _drive_mps2 / 3.0:
		return [0.0, 0.0, 0.0]
	return Navigation.transit_accel(loc, t)


## A sim vector (heliocentric axes) as a view direction; zero stays zero.
func _view_dir(a: Array) -> Vector3:
	return Vector3(a[0], a[2], -a[1]).normalized()


## The burn under way at t, or the next to come; -1 if none is left.
func _next_burn(t: float) -> int:
	for k in _burns.size():
		if t < float(_burns[k][1]):
			return k
	return -1


## When the burn under way at t ends (t itself if none is).
func _burn_end(t: float) -> float:
	var k := _next_burn(t)
	return float(_burns[k][1]) if k >= 0 and t >= float(_burns[k][0]) else t


## Puffs from the RCS quads that would push the way the ship is being swung
## (alpha: angular acceleration, a world vector): as a turn starts and as it stops.
func _rcs_puffs(alpha: Vector3, dt: float) -> void:
	var clock := Time.get_ticks_msec() / 1000.0
	for k in range(_puffs.size() - 1, -1, -1):
		var p: Dictionary = _puffs[k]
		var age := clock - float(p["born"])
		var node: MeshInstance3D = p["node"]
		if age > PUFF_S or not is_instance_valid(node):
			if is_instance_valid(node):
				node.queue_free()
			_puffs.remove_at(k)
			continue
		var u := age / PUFF_S
		node.position += p["vel"] * dt
		node.scale = Vector3.ONE * (0.3 + 2.2 * u) * (1.0 - u * u)
	if alpha.length() < _turn_accel * 0.3:
		return
	if _puff_mat == null:
		_puff_mat = Kit.glow(Color(0.86, 0.9, 0.96), 1.2)
	var local := (_ship.basis.inverse() * alpha).normalized()
	for j in _rig.get("rcs", []):
		var quad: Node3D = j["node"]
		if not is_instance_valid(quad) or clock < float(j.get("puff_next", 0.0)):
			continue
		var out: Vector3 = j["outward"]
		var lever := _ship.to_local(quad.global_position) - _pivot
		# A jet pushes against where it points, so its torque is lever x -out.
		var torque := lever.cross(-out)
		if torque.length() < 1e-3 or torque.normalized().dot(local) < 0.4:
			continue
		j["puff_next"] = clock + PUFF_GAP_S * randf_range(0.8, 1.3)
		var puff := Kit.sphere(0.25, _puff_mat, quad.global_position + _ship.basis * out * 0.4)
		add_child(puff)
		_puffs.append({"node": puff, "born": clock, "vel": _ship.basis * out * randf_range(2.5, 4.0)})


## How far the ship is from a port's docking face tau seconds after leaving it (or
## before reaching it): backing off gently, then pulling away under thrust; coming in,
## the same in reverse, ending where the approach scene starts us.
func _port_gap(place: String, tau: float, leaving: bool) -> float:
	var half := _length * 0.5
	if leaving:
		return half + 2.0 + 1.5 * tau + 0.02 * tau * tau
	var geom: Dictionary = sim.data.places[place]["station"]
	var spawn := maxf(float(sim.data.balance["docking"]["spawn_distance_m"]), float(geom["hub_radius_m"]) * 3.0)
	return half + spawn + 1.0 * tau + 0.02 * tau * tau


# --- the director ----------------------------------------------------------------------

## The most impressive world in view: the destination if it is a decent size, else
## the biggest. "" if nothing is bigger than a pinhead.
func _hero_body() -> String:
	var best := ""
	var best_ang := deg_to_rad(0.15)
	var dest_body := ""
	var loc: Dictionary = sim.state.location
	var dest_loc: Dictionary = sim.data.locations.get(loc.get("to", ""), {}).get("location", {})
	dest_body = String(dest_loc.get("parent", dest_loc.get("system", [""])[0] if dest_loc.has("system") else ""))
	for entry in readout.get("seen", []):
		var ang := float(entry[2])
		if entry[0] == dest_body and ang > deg_to_rad(0.3):
			return entry[0]
		if ang > best_ang:
			best_ang = ang
			best = entry[0]
	return best


## Angular radius of a world as seen now (radians), 0 if out of sight.
func _angular(body: String) -> float:
	for entry in readout.get("seen", []):
		if entry[0] == body:
			return float(entry[2])
	return 0.0


func _nearest_station() -> String:
	var best := ""
	var best_d := INF
	for place in _stations:
		var d := float(_stations[place].get("dist", INF))
		if d < best_d:
			best_d = d
			best = place
	return best


func _next_shot() -> void:
	shot_clock = 0.0
	_shot_seed = _rng.randf()
	var pool := ["chase", "orbit", "flyby", "dolly", "rim"]
	if _thrusting:
		pool += ["plume", "plume"]
	_target_body = _hero_body()
	if _target_body != "":
		pool += ["world", "world"]
		# A long lens wants the whole world behind the ship, not a wall of it.
		if _angular(_target_body) < deg_to_rad(18.0):
			pool += ["longlens"]
	if _nearest_station() != "":
		pool += ["station", "station"]
	pool.erase(shot)
	shot = pool[_rng.randi() % pool.size()]
	shot_label = {"chase": "CHASE", "orbit": "ORBIT", "flyby": "FLY-PAST", "dolly": "ALONG THE HULL", "rim": "INTO THE SUN",
		"plume": "THE DRIVE", "world": String(sim.data.bodies[_target_body]["name"]).to_upper() if _target_body != "" else "",
		"longlens": "LONG LENS  ·  " + (String(sim.data.bodies[_target_body]["name"]).to_upper() if _target_body != "" else ""),
		"station": String(sim.data.places[_nearest_station()]["name"]).to_upper() if _nearest_station() != "" else ""}[shot]


func _update_camera(dt: float) -> void:
	var centre := _ship.transform * _pivot
	var B := _ship.basis
	var fwd := -B.z
	var up := B.y
	var side := B.x
	var L := _length
	if mode == "free":
		var off := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch)) * _dist
		camera.fov = 50.0
		camera.global_position = centre + off
		camera.look_at(centre, Vector3.UP if absf(off.normalized().y) < 0.99 else Vector3.FORWARD)
		if _dust:
			_dust.global_position = camera.global_position
		return
	var f := clampf(shot_clock / SHOT_S, 0.0, 1.0)
	var sway := sin(shot_clock * 0.4 + _shot_seed * 6.0)
	var at := centre
	var pos := centre + B * Vector3(0, L * 0.4, L * 1.6)
	var fov := 50.0
	var sky_up := up
	match shot:
		"chase":
			# Behind and above, the ship heading into the frame toward where it is going.
			pos = centre + B * Vector3(sway * L * 0.15, L * (0.32 + 0.05 * f), L * (1.55 - 0.15 * f))
			at = centre + fwd * L * 0.9
			fov = 48.0
		"orbit":
			var a := _shot_seed * TAU + shot_clock * 0.09
			pos = centre + (side * cos(a) + fwd * sin(a)) * L * 2.3 + up * L * (0.35 + 0.15 * sin(shot_clock * 0.17))
			fov = 46.0
		"flyby":
			# Parked off to one side ahead; the ship slides past, the camera panning with it.
			var s1 := 1.0 if _shot_seed > 0.5 else -1.0
			pos = centre + fwd * L * lerpf(3.2, -2.4, f) + side * s1 * L * 0.9 + up * L * 0.18
			fov = 42.0
		"dolly":
			# Along the hull from the crew end to the drives, close, looking just ahead.
			var z := lerpf(-0.55, 0.55, f) * L
			var s2 := 1.0 if _shot_seed > 0.5 else -1.0
			pos = centre + B * Vector3(s2 * (_radius * 1.15 + 2.0), _radius * 0.45, z)
			at = centre + B * Vector3(0, 0, z - L * 0.12)
			fov = 55.0
		"rim":
			# Looking toward the Sun past the ship: edges lit, the plume against the glare.
			var away := -_sun_dir
			var cross := away.cross(Vector3.UP if absf(away.y) < 0.95 else Vector3.RIGHT).normalized()
			pos = centre + away * L * (2.4 - 0.3 * f) + cross * L * 0.5 * sway + Vector3.UP * L * 0.2
			fov = 44.0
		"plume":
			# Off the drives, looking forward along the ship over the burning plume.
			var s3 := 1.0 if _shot_seed > 0.5 else -1.0
			pos = centre + B * Vector3(s3 * (_radius * 1.6 + 3.0), -_radius * 0.5, L * (0.75 + 0.1 * f))
			at = centre + B * Vector3(0, 0, -L * 0.15)
			fov = 52.0
		"world", "longlens":
			var node: MeshInstance3D = _bodies.get(_target_body)
			var dir := node.position.normalized() if node and node.visible else fwd
			var cross := dir.cross(Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT).normalized()
			# A world filling the sky: look across its limb instead, a horizon behind the ship.
			var ang := _angular(_target_body)
			if ang > deg_to_rad(18.0):
				var lit := (_sun_dir - dir * _sun_dir.dot(dir))
				var toward := lit.normalized() if lit.length() > 0.05 else cross
				dir = (dir * cos(ang * 0.92) + toward * sin(ang * 0.92)).normalized()
				cross = dir.cross(Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT).normalized()
			if shot == "world":
				# The world behind the ship, the camera easing in.
				pos = centre - dir * L * (2.8 - 0.6 * f) + cross * L * (0.5 + 0.2 * sway) + Vector3.UP * L * 0.25
				at = centre + dir * L * 0.4
				fov = 50.0
			else:
				# Far back on a long lens: the ship small, the world huge behind it.
				pos = centre - dir * L * (22.0 - 4.0 * f) + cross * L * 2.0 + Vector3.UP * L * 0.8
				at = centre
				fov = lerpf(9.0, 7.0, f)
			sky_up = Vector3.UP
		"station":
			var place := _nearest_station()
			var st: Node3D = _stations[place]["model"]["node"] if place != "" else null
			if st:
				# Both in shot: from beyond the ship, the station over its shoulder.
				var to_st := st.position - centre
				var d := to_st.length()
				var dir := to_st / maxf(d, 1.0)
				var cross := dir.cross(Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT).normalized()
				pos = centre - dir * L * 2.6 + cross * L * (0.8 + 0.3 * sway) + Vector3.UP * L * 0.35
				at = centre.lerp(st.position, clampf(L * 3.0 / maxf(d, 1.0), 0.05, 0.4))
				fov = clampf(rad_to_deg(2.0 * atan(float(_stations[place]["model"]["ring_radius"]) * 1.4 / maxf(d, 1.0))), 30.0, 60.0)
			sky_up = Vector3.UP
	camera.fov = fov
	camera.global_position = pos
	if _dust:
		_dust.global_position = pos
	if pos.distance_to(at) > 1e-3:
		camera.look_at(at, sky_up if absf((at - pos).normalized().dot(sky_up)) < 0.98 else Vector3.FORWARD)
