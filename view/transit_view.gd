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
const FlightDeck := preload("res://view/flight/flight_deck.gd")

const SKY_DISTANCE := 60000.0
## How fast the ship turns to its burn attitude, in radians per real second.
const TURN_RATE := 0.9
const LOOK_RATE := 1.2
const WIDE_FOV := 72.0
const TELESCOPE_FOV := 6.0
## The flight deck is built at the approach scale (eye to panel about 0.7 m); here it
## is scaled up about the eye, which looks identical but keeps it past the near plane.
const DECK_SCALE := 1.8

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
## The flight deck, fixed to the ship: free look turns the pilot's head inside it.
var deck: Node3D
var _mount: Node3D


func _init(owner_sim) -> void:
	sim = owner_sim


func _ready() -> void:
	add_child(SkyKit.environment())
	_sun = DirectionalLight3D.new()
	_sun.light_energy = 1.6
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
	camera = Camera3D.new()
	camera.fov = 72.0
	camera.near = 1.0
	camera.far = SKY_DISTANCE * 3.0
	add_child(camera)
	camera.make_current()
	_mount = Node3D.new()
	add_child(_mount)
	deck = FlightDeck.new()
	deck.scale = Vector3.ONE * DECK_SCALE
	_mount.add_child(deck)
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
	# Worlds big enough to see, true to angular size; nearer ones nearer on the shell.
	var seen: Array = SkyKit.visible_bodies(sim.data, eph, ship, t)
	for body in _bodies:
		_bodies[body].visible = false
	for k in seen.size():
		var node: MeshInstance3D = _bodies[seen[k][0]]
		var shell := SKY_DISTANCE * (0.55 + 0.45 * float(k) / float(maxi(1, seen.size() - 1)))
		node.visible = true
		node.position = (seen[k][1] as Vector3) * shell
		node.scale = Vector3.ONE * shell * minf(tan(float(seen[k][2])), 0.97)
	var sun_dir := SkyKit.dir_between(eph.position("sun", t), ship)
	_sun.look_at_from_position(Vector3.ZERO, -sun_dir, Vector3.UP if absf(sun_dir.y) < 0.99 else Vector3.RIGHT)
	_sun_disc.position = sun_dir * SKY_DISTANCE
	for k in seen.size():
		SkyKit.update_body(_bodies[seen[k][0]], sun_dir, t)
	var au := V.length(V.sub(ship, eph.position("sun", t))) / 1.495978707e11
	_sun_disc.scale = Vector3.ONE * SKY_DISTANCE * 0.0047 * 3.0 / maxf(au, 0.3)
	_sun.light_energy = 1.6 * clampf(1.0 / sqrt(au), 0.45, 1.6)

	# Attitude: the main drive pushes along the nose, so face along the thrust vector
	# (which swings smoothly from toward the target to braking against it). Coasting,
	# hold the last attitude.
	var dest: Array = eph.position(loc["to"], t)
	var dest_dir := SkyKit.dir_between(dest, ship)
	var thrust: Array = Navigation.transit_accel(loc, t)
	var thrusting := V.length(thrust) > 1e-6
	var forward := Vector3(thrust[0], thrust[2], -thrust[1]).normalized() if thrusting else -_basis.z
	var want := Basis.looking_at(forward, Vector3.UP if absf(forward.y) < 0.98 else Vector3.RIGHT)
	# The lunar pass: look along our motion over the Moon, pitched down toward it,
	# with the lunar horizon level, so the surface sweeps past below.
	var peri := float(loc.get("peri_t", -1.0))
	if peri > 0.0 and absf(t - peri) < 1800.0:
		var moon_p: Array = eph.position("moon", t)
		var down := SkyKit.dir_between(moon_p, ship)
		var v_rel: Array = V.sub(Navigation.transit_velocity(loc, t), V.sub(eph.velocity("moon", t), eph.velocity(frame, t)))
		var along := Vector3(v_rel[0], v_rel[2], -v_rel[1]).normalized()
		along = (along - down * along.dot(down)).normalized()
		if along.length() > 0.5:
			forward = (along * cos(deg_to_rad(40.0)) + down * sin(deg_to_rad(40.0))).normalized()
			want = Basis.looking_at(forward, -down)
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
	_mount.transform = Transform3D(_basis, Vector3.ZERO)
	# Through the telescope the deck is out of the picture.
	deck.visible = camera.fov > WIDE_FOV * 0.8
	var vp := get_viewport().get_visible_rect().size
	deck.fit(vp.x / maxf(vp.y, 1.0))

	var v_now: Array = Navigation.transit_velocity(loc, t)
	var speed := V.length(v_now)
	var accel := V.length(thrust)
	var into := V.dot(V.normalized(thrust), V.normalized(v_now)) if thrusting else 0.0
	var flipping := want.get_rotation_quaternion().angle_to(_basis.get_rotation_quaternion()) > 0.15
	readout = {
		"phase": "TURNING" if flipping else ("COASTING" if not thrusting else ("ACCELERATING" if into > 0.3 else ("BRAKING" if into < -0.3 else "BURNING ACROSS"))),
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
