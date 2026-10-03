## The view from the cockpit in transit. The camera sits at the ship's real position
## on its transfer, so Earth, Moon and Sun appear in their true directions and at
## their true apparent sizes: under time compression the Moon swells ahead and Earth
## shrinks behind. The ship accelerates nose-first toward the destination, flips at
## the midpoint and brakes tail-first, so the pilot's view swings round to look back
## the way they came.
extends Node3D

const V := preload("res://sim/v3.gd")
const Navigation := preload("res://sim/navigation.gd")
const Kit := preload("res://view/flight/kit.gd")
const SkyKit := preload("res://view/flight/sky.gd")

const SKY_DISTANCE := 60000.0
## How fast the ship turns to its burn attitude, in radians per real second.
const TURN_RATE := 0.9
const LOOK_RATE := 1.2
const WIDE_FOV := 72.0
const TELESCOPE_FOV := 6.0

var sim
var camera: Camera3D
var _sun: DirectionalLight3D
var _sun_disc: MeshInstance3D
var _bodies: Dictionary = {}
var _basis := Basis.IDENTITY
var _ready_basis := false
## Free look (arrow keys) relative to the burn attitude, and the telescope toggle (Z).
var look_yaw := 0.0
var look_pitch := 0.0
var telescope := false
## Live values for the overlay.
var readout: Dictionary = {}


func _init(owner_sim) -> void:
	sim = owner_sim


func _ready() -> void:
	add_child(SkyKit.environment())
	_sun = DirectionalLight3D.new()
	_sun.light_energy = 1.6
	add_child(_sun)
	_sun_disc = Kit.sphere(1.0, Kit.glow(Color("fff6e0"), 6.0))
	add_child(_sun_disc)
	for body in ["earth", "moon"]:
		var mesh := Kit.sphere(1.0, SkyKit.body_material(body))
		(mesh.mesh as SphereMesh).radial_segments = 64
		(mesh.mesh as SphereMesh).rings = 32
		add_child(mesh)
		_bodies[body] = mesh
	camera = Camera3D.new()
	camera.fov = 72.0
	camera.near = 1.0
	camera.far = SKY_DISTANCE * 3.0
	add_child(camera)
	camera.make_current()
	_update(0.0)


func _process(dt: float) -> void:
	_update(dt)


func _update(dt: float) -> void:
	var s = sim.state
	var loc: Dictionary = s.location
	if loc.get("status") != "transit":
		return
	var eph = sim.ephemeris
	var t: float = s.time_s
	var frame: String = loc["frame"]
	var ship: Array = V.add(eph.position(frame, t), Navigation.transit_position(loc, t))
	for body in _bodies:
		var p: Array = eph.position(body, t)
		var d := V.distance(p, ship)
		var r := float(sim.data.bodies[body]["radius_m"])
		var node: MeshInstance3D = _bodies[body]
		node.position = SkyKit.dir_between(p, ship) * SKY_DISTANCE
		node.scale = Vector3.ONE * SKY_DISTANCE * minf(r / d, 0.97)
	var sun_dir := SkyKit.dir_between(eph.position("sun", t), ship)
	_sun.look_at_from_position(Vector3.ZERO, -sun_dir, Vector3.UP if absf(sun_dir.y) < 0.99 else Vector3.RIGHT)
	_sun_disc.position = sun_dir * SKY_DISTANCE
	_sun_disc.scale = Vector3.ONE * SKY_DISTANCE * 0.0047 * 3.0

	# Burn attitude: nose to the destination while accelerating, tail to it while braking.
	var dest: Array = eph.position(loc["to"], t)
	var dest_dir := SkyKit.dir_between(dest, ship)
	# The ship flies its planned track toward the intercept point, not at where the
	# destination is right now (the Moon moves about 13 degrees a day).
	var track_dir := SkyKit.dir_between(loc["to_pos"], loc["from_pos"])
	var duration := float(loc["arrive_t"]) - float(loc["depart_t"])
	var burn := float(loc["burn_s"])
	var start := float(loc["depart_t"]) + (duration - burn) * 0.5
	var into_burn := clampf(t - start, 0.0, burn)
	var braking := into_burn > burn * 0.5
	var forward := -track_dir if braking else track_dir
	var want := Basis.looking_at(forward, Vector3.UP if absf(forward.y) < 0.98 else Vector3.RIGHT)
	if not _ready_basis:
		_basis = want
		_ready_basis = true
	else:
		var from := _basis.get_rotation_quaternion()
		var to := want.get_rotation_quaternion()
		var angle := from.angle_to(to)
		var step := minf(1.0, TURN_RATE * dt / maxf(angle, 1e-6))
		_basis = Basis(from.slerp(to, step))
	if dt > 0.0:
		look_yaw += (float(Input.is_physical_key_pressed(KEY_LEFT)) - float(Input.is_physical_key_pressed(KEY_RIGHT))) * LOOK_RATE * dt * (0.1 if telescope else 1.0)
		look_pitch = clampf(look_pitch + (float(Input.is_physical_key_pressed(KEY_UP)) - float(Input.is_physical_key_pressed(KEY_DOWN))) * LOOK_RATE * dt * (0.1 if telescope else 1.0), -1.4, 1.4)
	var look := Basis(Vector3.UP, look_yaw) * Basis(Vector3.RIGHT, look_pitch)
	camera.transform = Transform3D(_basis * look, Vector3.ZERO)
	camera.fov = lerpf(camera.fov, TELESCOPE_FOV if telescope else WIDE_FOV, clampf(dt * 6.0, 0.0, 1.0)) if dt > 0.0 else camera.fov

	# Brachistochrone kinematics: a = 4d / burn^2; speed rises, then falls.
	var dist := float(loc["distance_m"])
	var accel := 4.0 * dist / (burn * burn) if burn > 0.0 else 0.0
	var speed := accel * (into_burn if not braking else burn - into_burn)
	var flipping := Basis.looking_at(forward, Vector3.UP if absf(forward.y) < 0.98 else Vector3.RIGHT).get_rotation_quaternion().angle_to(_basis.get_rotation_quaternion()) > 0.15
	readout = {
		"phase": "FLIP" if flipping else ("BRAKING" if braking else ("ACCELERATING" if into_burn > 0.0 and into_burn < burn else "COASTING")),
		"speed": speed,
		"accel": accel,
		"remaining": V.distance(ship, dest),
		"eta": float(loc["arrive_t"]) - t,
		"dest_dir": dest_dir,
		"origin_dir": SkyKit.dir_between(eph.position(loc["from"], t), ship),
		"earth_dir": SkyKit.dir_between(eph.position("earth", t), ship),
		"moon_dir": SkyKit.dir_between(eph.position("moon", t), ship),
		"earth_km": V.distance(eph.position("earth", t), ship) / 1000.0,
		"moon_km": V.distance(eph.position("moon", t), ship) / 1000.0,
	}


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_Z:
			telescope = not telescope
		KEY_C:
			look_yaw = 0.0
			look_pitch = 0.0
