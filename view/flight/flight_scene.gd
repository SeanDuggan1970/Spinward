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
const SystemMap := preload("res://view/system_map.gd")
const SetPieces := preload("res://view/flight/set_pieces.gd")
const ProjectSystem := preload("res://sim/systems/project_system.gd")

const ASSIST_MODES := ["full", "assisted", "manual"]
const SKY_DISTANCE := 60000.0
## NPC traffic is shown on the lanes for this long either side of docking (game seconds).
const LANE_WINDOW := 3.0 * 3600.0
const LANE_LENGTH := 15000.0
const BERTH_ANGLES := [PI * 0.5, -PI * 0.5, PI * 0.25, PI * 0.75, -PI * 0.25, -PI * 0.75]

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
## "cockpit" (first person, the default) or "chase".
var view_mode := "cockpit"
var _scanner_index := 1
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
var _blinkers: Array = []
## NPC id -> {node, mode: "berth"|"inbound"|"outbound"}
var _traffic: Dictionary = {}
var _traffic_check := 0.0
## NPC id -> berth index, stable while the ship stays moored.
var _berths: Dictionary = {}
## Cosmetic station work craft: [{node, radius, z, period, phase, tilt}]
var _work_craft: Array = []

## Directions to the Sun, Earth and Moon from this station (Godot frame).
var body_dirs: Dictionary = {}
## Megastructure set pieces (view-only), animated each frame.
var _set_pieces: Array = []

## Live readouts for the HUD.
var readout := {}


func _init(owner_sim) -> void:
	sim = owner_sim
	place_id = sim.state.location["place"]
	tune_flight = sim.data.balance["flight"]
	tune_dock = sim.data.balance["docking"]
	assist = tune_flight["assist_default"]
	view_mode = tune_flight.get("default_view", "cockpit")
	_scanner_index = int(tune_flight.get("scanner_default_index", 1))


func _ready() -> void:
	var geom: Dictionary = sim.data.places[place_id]["station"]
	spin_rate = float(geom["spin_rpm"]) * TAU / 60.0
	_build_environment()
	station = Models.station(geom, sim.data.places[place_id]["name"])
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
		float(station["port_z"]) + maxf(float(tune_dock["spawn_distance_m"]), float(station["hub_radius"]) * 3.0) - nose_z)
	ship_node.rotation = Vector3(0.05, -0.08, 0.6)
	spin_angle = fposmod(float(sim.state.time_s) * spin_rate, TAU)
	camera = Camera3D.new()
	camera.far = SKY_DISTANCE * 3.0
	camera.near = 0.2
	camera.fov = 65.0
	add_child(camera)
	camera.make_current()
	_update_camera(1.0)
	var progress := {}
	for id in sim.data.projects:
		progress[sim.data.projects[id].get("feature", id)] = ProjectSystem.progress(sim.state, sim.data, id)
	_set_pieces = SetPieces.build(self, sim.data.places[place_id].get("features", []), body_dirs, station, progress)
	_spawn_work_craft()
	_sync_traffic()
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
	body_dirs["sun"] = sun_dir
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
		body_dirs[body] = dir
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
			view_mode = "chase" if view_mode == "cockpit" else "cockpit"
		KEY_G:
			_scanner_index = (_scanner_index + 1) % tune_flight["scanner_ranges_m"].size()
			flash("Scanner range %s" % UI.km(scanner_range()) if scanner_range() >= 1000.0 else "Scanner range %d m" % int(scanner_range()), UI.AMBER, 1.5)
		KEY_H:
			hud.show_keys = not hud.show_keys
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
	Kit.update_blinkers(_blinkers, clock)
	_traffic_check -= dt
	if _traffic_check <= 0.0:
		_traffic_check = 1.0
		_sync_traffic()
	_move_traffic()
	_move_work_craft()
	SetPieces.animate(_set_pieces, clock)
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
	var colliders: Dictionary = station["colliders"]
	for probe in probes:
		var p: Vector3 = probe[0]
		var r: float = probe[1]
		var normal := Vector3.ZERO
		var depth := 0.0
		var rxy := Vector2(p.x, p.y).length()
		var radial := Vector3(p.x, p.y, 0.0).normalized() if rxy > 1e-4 else Vector3.RIGHT
		# Axial cylinders (hub, drum, docking nub); docking is checked before we get here.
		for c in colliders["cylinders"]:
			var cr: float = c[0]
			var z0: float = c[1]
			var z1: float = c[2]
			if p.z > z0 - r and p.z < z1 + r and rxy < cr + r:
				var into_side := cr + r - rxy
				var into_front := z1 + r - p.z
				var into_back := p.z - (z0 - r)
				var d := minf(into_side, minf(into_front, into_back))
				if d > depth:
					depth = d
					normal = radial if d == into_side else (Vector3(0, 0, 1) if d == into_front else Vector3(0, 0, -1))
		# Rings.
		for torus in colliders["tori"]:
			var q := Vector2(rxy - float(torus[0]), p.z)
			var reach := float(torus[1]) + r
			if q.length() < reach and reach - q.length() > depth:
				var qn := q.normalized() if q.length() > 1e-4 else Vector2.RIGHT
				normal = (radial * qn.x + Vector3(0, 0, qn.y)).normalized()
				depth = reach - q.length()
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


func scanner_range() -> float:
	return float(tune_flight["scanner_ranges_m"][_scanner_index])


## Everything the scanner can see: {pos (world), colour, kind}.
func contacts() -> Array:
	var out := [{"pos": Vector3.ZERO, "colour": UI.GOOD, "kind": "station"}]
	for id in _traffic:
		var entry: Dictionary = _traffic[id]
		if is_instance_valid(entry["ship"]):
			out.append({"pos": entry["ship"].global_position, "colour": SystemMap.fleet_colour(sim, entry["npc"]), "kind": "ship"})
	for w in _work_craft:
		out.append({"pos": w["node"].global_position, "colour": UI.HAZARD, "kind": "pod"})
	return out


func _update_camera(dt: float) -> void:
	var t := ship_node.global_transform
	ship_node.visible = view_mode != "cockpit"
	if view_mode == "beauty":
		# Gallery/screenshot camera: pulled far back and up to take in the set pieces.
		camera.fov = 70.0
		camera.global_position = t * Vector3(0, 500.0, 2600.0)
		camera.look_at(Vector3(0, 0, -400.0), Vector3.UP)
		return
	if view_mode == "cockpit":
		# Pilot's eye just behind the command pod's front window.
		camera.fov = 72.0
		camera.global_transform = Transform3D(t.basis, t * Vector3(0, 0.4, nose_z + 1.2))
		return
	camera.fov = 65.0
	var want := t * Vector3(0, 8.0, 40.0)
	camera.global_position = camera.global_position.lerp(want, clampf(dt * 4.0, 0.0, 1.0)) if dt < 1.0 else want
	camera.look_at(t * Vector3(0, 2.0, -30.0), t.basis.y)


## Other ships here: moored at berths on the hub, or flying the lanes in and out.
func _sync_traffic() -> void:
	var t: float = sim.state.time_s
	var wanted := {}
	# Moored ships keep the berth they were given; newcomers take the first free one.
	var docked_here := {}
	for npc in sim.state.npcs:
		if npc["location"]["status"] == "docked" and npc["location"]["place"] == place_id:
			docked_here[npc["id"]] = true
	for id in _berths.keys():
		if not docked_here.has(id):
			_berths.erase(id)
	for id in docked_here:
		if not _berths.has(id):
			var used: Array = _berths.values()
			for i in BERTH_ANGLES.size():
				if not i in used:
					_berths[id] = i
					break
	for npc in sim.state.npcs:
		var loc: Dictionary = npc["location"]
		var mode := ""
		if _berths.has(npc["id"]):
			mode = "berth"
		elif loc["status"] == "transit" and loc["to"] == place_id and float(loc["arrive_t"]) - t < LANE_WINDOW:
			mode = "inbound"
		elif loc["status"] == "transit" and loc["from"] == place_id and t - float(loc["depart_t"]) < LANE_WINDOW:
			mode = "outbound"
		if mode != "":
			wanted[npc["id"]] = {"npc": npc, "mode": mode, "berth": _berths.get(npc["id"], -1)}
	var changed := false
	for id in _traffic.keys():
		if not wanted.has(id) or wanted[id]["mode"] != _traffic[id]["mode"]:
			_traffic[id]["node"].queue_free()
			_traffic.erase(id)
			changed = true
	for id in wanted:
		if _traffic.has(id):
			continue
		var w: Dictionary = wanted[id]
		var model := Models.ship(w["npc"]["ship"], sim.data)
		var node: Node3D = model["node"]
		if w["mode"] == "berth":
			# Moored alongside the hub's forward half on a short arm, spinning with the station.
			var a: float = BERTH_ANGLES[w["berth"]]
			var r: float = station["hub_radius"] + model["radius"] + 6.0
			var holder := Node3D.new()
			holder.rotation.z = a
			node.position = Vector3(r, 0, station["hub_length"] * 0.5 - model["length"] * 0.5 - 2.0)
			node.rotation = Vector3(0, PI, PI * 0.5)
			holder.add_child(node)
			holder.add_child(Kit.box(Vector3(model["radius"] + 6.0, 0.6, 0.6), Kit.mat("steel"), Vector3(station["hub_radius"] + (model["radius"] + 6.0) * 0.5, 0, node.position.z)))
			station["rotor"].add_child(holder)
			_traffic[id] = {"node": holder, "ship": node, "mode": "berth", "npc": w["npc"]}
		else:
			# A bright running light so distant traffic reads as a moving star.
			node.add_child(Kit.sphere(2.5, Kit.glow(Color("ffe0a0"), 4.0), Vector3(0, 3.0, 0)))
			add_child(node)
			_traffic[id] = {"node": node, "ship": node, "mode": w["mode"], "npc": w["npc"]}
		changed = true
	if changed or _blinkers.is_empty():
		_blinkers = Kit.collect_blinkers(self)
	_move_traffic()


func _move_traffic() -> void:
	var t: float = sim.state.time_s
	for id in _traffic:
		var entry: Dictionary = _traffic[id]
		if entry["mode"] == "berth":
			continue
		var loc: Dictionary = entry["npc"]["location"]
		if loc["status"] != "transit":
			continue
		# Lanes run outside the ring, from far out to the back of the station where the
		# freight berths are, well clear of the player's approach axis.
		var lane := absi(hash(id)) % 4
		var lane_r: float = maxf(station["ring_radius"] + station["ring_tube"], station["hub_radius"]) + 60.0
		var a := PI * 0.25 + PI * 0.5 * lane
		var offset := Vector3(cos(a) * lane_r, sin(a) * lane_r, 0.0)
		var z0: float = -station["hub_length"] * 0.5
		var span: float = float(station["port_z"]) + LANE_LENGTH - z0
		var f: float
		var node: Node3D = entry["ship"]
		if entry["mode"] == "inbound":
			f = clampf((float(loc["arrive_t"]) - t) / LANE_WINDOW, 0.0, 1.0)
			node.rotation = Vector3.ZERO
		else:
			f = clampf((t - float(loc["depart_t"])) / LANE_WINDOW, 0.0, 1.0)
			node.rotation = Vector3(0, PI, 0)
		node.position = offset + Vector3(0, 0, z0 + span * f)


## View-only station life: work pods circling the hub and a tug standing off the port.
## Deterministic per station, and never touches the sim.
func _spawn_work_craft() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(place_id + "work")
	var rh: float = station["hub_radius"]
	var lh: float = station["hub_length"]
	var rr: float = station["ring_radius"]
	for i in rng.randi_range(3, 5):
		var tug := i == 0
		var node := Models.work_pod(tug)
		add_child(node)
		_work_craft.append({
			"node": node,
			"radius": (rh + 40.0) if tug else rng.randf_range(rh + 15.0, maxf(rr * 0.75, rh + 90.0)),
			"z": (float(station["port_z"]) + 25.0) if tug else rng.randf_range(-lh * 0.5, lh * 0.5),
			"period": 240.0 if tug else rng.randf_range(150.0, 420.0),
			"phase": rng.randf() * TAU,
			"bob": rng.randf_range(2.0, 8.0),
		})
	_blinkers = Kit.collect_blinkers(self)


func _move_work_craft() -> void:
	for w in _work_craft:
		var a: float = w["phase"] + TAU * clock / float(w["period"])
		var node: Node3D = w["node"]
		var pos := Vector3(cos(a) * w["radius"], sin(a) * w["radius"], w["z"] + sin(a * 2.0) * w["bob"])
		var ahead := Vector3(cos(a + 0.05) * w["radius"], sin(a + 0.05) * w["radius"], pos.z)
		node.position = pos
		node.look_at(ahead, Vector3(0, 0, 1))
