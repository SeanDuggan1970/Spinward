## Local flight bubble around a station: fly the approach and dock, or call the tug.
##
## Frame: station-centred, non-rotating; the station's rotor spins about +Z and its
## docking port faces +Z. Ship forward is -Z. Physics is integrated here in the view:
## it is a skill moment whose only effect on the sim is the "dock" command it sends.
## Earth, Moon and Sun are placed in their real directions from the station.
extends Node3D

const Kit := preload("res://view/flight/kit.gd")
const Models := preload("res://view/flight/models.gd")
const UI := preload("res://view/ui/ui_kit.gd")
const V := preload("res://sim/v3.gd")

const ASSIST_MODES := ["full", "assisted", "manual"]
const SKY_DISTANCE := 60000.0

var sim
var place_id: String
var tune_flight: Dictionary
var tune_dock: Dictionary

var ship_node: Node3D
var station: Dictionary
var camera: Camera3D
var hud: Control

var velocity := Vector3.ZERO
var ang_vel := Vector3.ZERO  # local, rad/s
var assist := "assisted"
var spin_match := true
var nose_cam := false
var nose_z := -15.0
var ship_radius := 5.0
var spin_rate := 0.0
var spin_angle := 0.0
var bumps := 0
var message := ""
var message_colour := Color.WHITE
var message_until := 0.0
var clock := 0.0
var docked := false
var _drive_plume: Node3D

## Live readouts for the HUD.
var readout := {}


func _init(owner_sim) -> void:
	sim = owner_sim
	place_id = sim.state.location["place"]
	tune_flight = sim.data.balance["flight"]
	tune_dock = sim.data.balance["docking"]
	assist = tune_flight["assist_default"]


func _ready() -> void:
	var geom: Dictionary = sim.data.places[place_id]["station"]
	spin_rate = float(geom["spin_rpm"]) * TAU / 60.0
	_build_environment()
	station = Models.station(geom)
	add_child(station["node"])
	var model := Models.ship(sim.state.ship, sim.data)
	ship_node = model["node"]
	nose_z = model["nose_z"]
	ship_radius = model["radius"]
	_drive_plume = ship_node.find_child("DrivePlume", true, false)
	add_child(ship_node)
	# Start out on the approach axis with a deterministic offset per station.
	var h := hash(place_id)
	var off := float(tune_dock["spawn_offset_m"])
	ship_node.position = Vector3(off * (float(h % 7) / 3.0 - 1.0), off * (float((h / 7) % 5) / 2.0 - 1.0) * 0.5,
		float(station["port_z"]) + float(tune_dock["spawn_distance_m"]) - nose_z)
	ship_node.rotation = Vector3(0.05, -0.08, 0.6)
	spin_angle = fposmod(float(sim.state.time_s) * spin_rate, TAU)
	camera = Camera3D.new()
	camera.far = SKY_DISTANCE * 3.0
	camera.near = 0.2
	camera.fov = 65.0
	add_child(camera)
	camera.make_current()
	_update_camera(1.0)
	hud = load("res://view/flight/flight_hud.gd").new(self)
	hud.theme = UI.make_theme()
	add_child(hud)
	flash("On approach to %s. Line up on the amber corridor lights." % sim.data.places[place_id]["name"], UI.AMBER, 6.0)


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := PanoramaSkyMaterial.new()
	sky_mat.panorama = _starfield()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("2a3340")
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var eph = sim.ephemeris
	var t: float = sim.state.time_s
	var here: Array = eph.position(place_id, t)
	var sun := DirectionalLight3D.new()
	var sun_dir := _dir_to(eph.position("sun", t), here)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 800.0
	add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, -sun_dir, Vector3.UP if absf(sun_dir.y) < 0.99 else Vector3.RIGHT)
	add_child(Kit.sphere(SKY_DISTANCE * 0.0047 * 3.0, Kit.glow(Color("fff6e0"), 6.0), sun_dir * SKY_DISTANCE))
	for body in ["earth", "moon"]:
		var p: Array = eph.position(body, t)
		var d := V.distance(p, here)
		var r := float(sim.data.bodies[body]["radius_m"])
		var dir := _dir_to(p, here)
		var mesh := Kit.sphere(SKY_DISTANCE * minf(r / d, 0.97), _body_material(body), dir * SKY_DISTANCE)
		(mesh.mesh as SphereMesh).radial_segments = 64
		(mesh.mesh as SphereMesh).rings = 32
		add_child(mesh)


## Direction from `from` to `to` (sim 64-bit ecliptic) as a Godot vector, ecliptic north up.
func _dir_to(to: Array, from: Array) -> Vector3:
	var d := V.normalized(V.sub(to, from))
	return Vector3(d[0], d[2], -d[1]).normalized()


func _body_material(body: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var noise := FastNoiseLite.new()
	noise.seed = 7 if body == "earth" else 3
	noise.frequency = 0.004 if body == "earth" else 0.01
	noise.fractal_octaves = 5
	var tex := NoiseTexture2D.new()
	tex.width = 1024
	tex.height = 512
	tex.seamless = true
	tex.noise = noise
	var ramp := Gradient.new()
	if body == "earth":
		ramp.offsets = PackedFloat32Array([0.0, 0.52, 0.56, 0.68, 0.8, 1.0])
		ramp.colors = PackedColorArray([Color("10305e"), Color("1d4f8a"), Color("4f6b3a"), Color("7a6a48"), Color("e8ecef"), Color("ffffff")])
	else:
		ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		ramp.colors = PackedColorArray([Color("4a4844"), Color("8d8a83"), Color("bdb9b0")])
	tex.color_ramp = ramp
	m.albedo_texture = tex
	m.roughness = 1.0
	return m


func _starfield() -> ImageTexture:
	var img := Image.create(2048, 1024, false, Image.FORMAT_RGB8)
	img.fill(Color("020306"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 2061
	for i in 5000:
		var b := pow(rng.randf(), 6.0)
		var c := Color(0.55 + b * 0.45, 0.55 + b * 0.45, 0.6 + b * 0.4) * (0.25 + b * 0.75)
		img.set_pixel(rng.randi_range(0, 2047), rng.randi_range(0, 1023), c)
	return ImageTexture.create_from_image(img)


func flash(text: String, colour: Color = Color.WHITE, seconds: float = 3.0) -> void:
	message = text
	message_colour = colour
	message_until = clock + seconds


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo) or docked:
		return
	match event.keycode:
		KEY_Z:
			assist = ASSIST_MODES[(ASSIST_MODES.find(assist) + 1) % ASSIST_MODES.size()]
			flash("Assist: %s" % assist.to_upper(), UI.AMBER)
		KEY_V:
			spin_match = not spin_match
			flash("Spin match %s" % ("ON" if spin_match else "OFF"), UI.AMBER)
		KEY_C:
			nose_cam = not nose_cam
		KEY_T:
			_request_tug()


func _request_tug() -> void:
	var err: String = sim.apply({"type": "dock", "manual": false})
	if err != "":
		flash(err, UI.WARN)
	else:
		docked = true


func _physics_process(dt: float) -> void:
	if docked or sim.state.paused:
		return
	clock += dt
	spin_angle = fposmod(spin_angle + spin_rate * dt, TAU)
	station["rotor"].rotation.z = spin_angle
	Kit.update_blinkers(self, clock)
	_fly(dt)
	_collide()
	_check_docking()
	_update_camera(dt)


func _input_axis(pos: Key, neg: Key) -> float:
	return (1.0 if Input.is_physical_key_pressed(pos) else 0.0) - (1.0 if Input.is_physical_key_pressed(neg) else 0.0)


func _fly(dt: float) -> void:
	var basis := ship_node.global_transform.basis
	var boost := float(tune_flight["boost_mult"]) if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0
	var accel := float(tune_flight["rcs_accel_mps2"]) * boost
	# Translation: W/S forward/back, A/D strafe, R/F up/down.
	var thrust := Vector3(_input_axis(KEY_D, KEY_A), _input_axis(KEY_R, KEY_F), _input_axis(KEY_S, KEY_W))
	var braking := Input.is_physical_key_pressed(KEY_X) or (assist == "full" and thrust == Vector3.ZERO)
	if thrust != Vector3.ZERO:
		velocity += basis * thrust.normalized() * accel * dt
	elif braking:
		velocity = velocity.move_toward(Vector3.ZERO, accel * dt)
	if _drive_plume:
		_drive_plume.visible = thrust.z < 0.0
	# Rotation: arrows pitch/yaw, Q/E roll.
	var turn := deg_to_rad(float(tune_flight["turn_rate_dps"]))
	var turn_accel := deg_to_rad(float(tune_flight["turn_accel_dps2"]))
	var stick := Vector3(_input_axis(KEY_UP, KEY_DOWN), _input_axis(KEY_LEFT, KEY_RIGHT), _input_axis(KEY_Q, KEY_E))
	if assist == "manual":
		ang_vel += stick * turn_accel * dt
	else:
		var target := stick * turn
		if spin_match and readout.get("range", INF) < 400.0 and stick.z == 0.0:
			# Co-pilot holds the port key: roll with the station, nudging out the error.
			var err: float = readout.get("roll_err", 0.0)
			target.z = (spin_rate - 1.5 * err) * signf(basis.z.z)
		ang_vel = ang_vel.move_toward(target, turn_accel * dt)
	if ang_vel.length() > 1e-6:
		ship_node.global_transform.basis = (basis * Basis(ang_vel.normalized(), ang_vel.length() * dt)).orthonormalized()
	ship_node.position += velocity * dt
	_update_readout()


func _nose() -> Vector3:
	return ship_node.global_transform * Vector3(0, 0, nose_z)


func _update_readout() -> void:
	var basis := ship_node.global_transform.basis
	var port := Vector3(0, 0, station["port_z"])
	var nose := _nose()
	var forward := -basis.z
	var right := basis.x
	var ship_angle := atan2(right.y, right.x)
	var err := wrapf(ship_angle - spin_angle, -PI * 0.5, PI * 0.5)
	readout = {
		"range": nose.distance_to(port),
		"lateral": Vector2(nose.x, nose.y).length(),
		"closing": -velocity.z,
		"speed": velocity.length(),
		"align": rad_to_deg(forward.angle_to(Vector3(0, 0, -1))),
		"roll_err": err,
		"assist": assist,
		"spin_match": spin_match,
	}
	var ok_speed: bool = readout["speed"] <= float(tune_dock["max_speed_mps"])
	var ok_align: bool = readout["align"] <= float(tune_dock["max_angle_deg"])
	var ok_roll: bool = absf(rad_to_deg(err)) <= float(tune_dock["max_roll_error_deg"])
	readout["ok_speed"] = ok_speed
	readout["ok_align"] = ok_align
	readout["ok_roll"] = ok_roll
	for l in station["lights"]:
		var m: StandardMaterial3D = l.material_override
		var colour := Color("40ff60") if ok_speed and ok_align and ok_roll else (Color("ffb030") if ok_align else Color("ff3a2a"))
		m.albedo_color = colour
		m.emission = colour


func _collide() -> void:
	var probes := [[ship_node.position, ship_radius], [_nose(), 1.5]]
	var rh: float = station["hub_radius"]
	var lh: float = station["hub_length"]
	var rr: float = station["ring_radius"]
	var rt: float = station["ring_tube"]
	for probe in probes:
		var p: Vector3 = probe[0]
		var r: float = probe[1]
		var normal := Vector3.ZERO
		var depth := 0.0
		var rxy := Vector2(p.x, p.y).length()
		var radial := Vector3(p.x, p.y, 0.0).normalized() if rxy > 1e-4 else Vector3.RIGHT
		# Hub (and its port collar, which docking handles before we get here).
		if absf(p.z) < lh * 0.5 + 3.0 + r and rxy < rh + r:
			var into_side := rh + r - rxy
			var into_end := lh * 0.5 + 3.0 + r - absf(p.z)
			if into_side < into_end:
				normal = radial
				depth = into_side
			else:
				normal = Vector3(0, 0, signf(p.z))
				depth = into_end
		# Ring torus.
		var q := Vector2(rxy - rr, p.z)
		if q.length() < rt + r:
			var qn := q.normalized() if q.length() > 1e-4 else Vector2.RIGHT
			normal = (radial * qn.x + Vector3(0, 0, qn.y)).normalized()
			depth = rt + r - q.length()
		if depth > 0.0:
			_bounce(normal, depth)


func _bounce(normal: Vector3, depth: float) -> void:
	ship_node.position += normal * depth
	var vn := velocity.dot(normal)
	if vn < 0.0:
		velocity -= normal * vn * (1.0 + float(tune_flight["bump_restitution"]))
		ang_vel *= 0.5
		bumps += 1
		flash("CONTACT  %.1f m/s" % -vn, UI.WARN, 2.0)


func _check_docking() -> void:
	if readout.get("range", INF) > float(tune_dock["capture_distance_m"]):
		return
	if readout["ok_speed"] and readout["ok_align"] and readout["ok_roll"]:
		if sim.apply({"type": "dock", "manual": true}) == "":
			docked = true
		return
	var reasons := []
	if not readout["ok_speed"]:
		reasons.append("too fast")
	if not readout["ok_align"]:
		reasons.append("nose off the axis")
	if not readout["ok_roll"]:
		reasons.append("not keyed to the slot")
	flash("Capture refused: " + ", ".join(reasons), UI.WARN, 3.0)
	_bounce(Vector3(0, 0, 1), 0.5)


func _update_camera(dt: float) -> void:
	var t := ship_node.global_transform
	if nose_cam:
		camera.global_transform = Transform3D(t.basis, t * Vector3(0, 1.0, nose_z - 0.5))
		return
	var want := t * Vector3(0, 8.0, 40.0)
	camera.global_position = camera.global_position.lerp(want, clampf(dt * 4.0, 0.0, 1.0)) if dt < 1.0 else want
	camera.look_at(t * Vector3(0, 2.0, -30.0), t.basis.y)
