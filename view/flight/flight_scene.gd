## Local flight bubble around a station: fly the approach and dock, or call the tug.
##
## Frame: station-centred, non-rotating; the station's rotor spins about +Z and its
## docking port faces +Z. Ship forward is -Z. Physics is integrated here in the view:
## it is a skill moment whose only effect on the sim is the "dock" command it sends.
## Earth, Moon and Sun are placed in their real directions from the station.
extends Node3D

const Kit := preload("res://view/flight/kit.gd")
const Models := preload("res://view/flight/models.gd")
const Livery := preload("res://view/flight/livery.gd")
const ShipRig := preload("res://view/flight/ship_rig.gd")
const UI := preload("res://view/ui/ui_kit.gd")
const V := preload("res://sim/v3.gd")
const SystemMap := preload("res://view/system_map.gd")
const SetPieces := preload("res://view/flight/set_pieces.gd")
const SkyKit := preload("res://view/flight/sky.gd")
const Autopilot := preload("res://view/flight/autopilot.gd")
const ShipStats := preload("res://sim/ship_stats.gd")
const Navigation := preload("res://sim/navigation.gd")
const ProjectSystem := preload("res://sim/systems/project_system.gd")
const DamageSystem := preload("res://sim/systems/damage_system.gd")
const ShipAudio := preload("res://view/audio/ship_audio.gd")
const FlightDeck := preload("res://view/flight/flight_deck.gd")

const ASSIST_MODES := ["full", "assisted", "manual"]
const SKY_DISTANCE := 60000.0
## NPC traffic is shown on the lanes for this long either side of docking (game seconds).
const LANE_WINDOW := 3.0 * 3600.0
const LANE_LENGTH := 15000.0
const BERTH_ANGLES := [PI * 0.5, -PI * 0.5, PI * 0.25, PI * 0.75, -PI * 0.25, -PI * 0.75]
## The pilot sits looking a little down over the instrument panel, so the ship's nose
## axis (the HUD boresight) is above the middle of the view, in the middle of the
## windscreen.
const SEAT_PITCH_DEG := 10.0

var sim
var place_id: String
var tune_flight: Dictionary
var tune_dock: Dictionary

var ship_node: Node3D
var station: Dictionary
var camera: Camera3D
var hud: Control
## The flight deck around the pilot's eye (cockpit view only).
var deck: Node3D
var _deck_mount: Node3D
## The pilot's head, swaying a little against the deck under thrust (eye space, m).
var _head := Vector3.ZERO
var _last_vel := Vector3.ZERO
## The controls as last flown (for the annunciators).
var controls_now: Dictionary = {}

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
var refusals := 0
## Docking computer engaged (K), if the ship has one fitted.
var computer := false
var message := ""
var message_colour := Color.WHITE
var message_until := 0.0
var clock := 0.0
var docked := false
var _drive_plume: Node3D
## The player ship's panels and dish (ship_rig.gd).
var _rig: Dictionary = {}
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

## When set, flight reads these instead of the keyboard (tests, scripted pilots,
## later gamepads): {thrust: Vector3 (local, -Z forward), stick: Vector3 (pitch, yaw,
## roll), boost: bool, brake: bool}.
var control_override: Dictionary = {}

## Live readouts for the HUD.
var readout := {}

## The ship's sounds, heard from the crew section.
var audio: ShipAudio
var _last_ang := Vector3.ZERO
## Drifting rocks on this approach: [{node, r, vel, spin, mass_t}].
var _rocks: Array = []
## Fixed obstacles from the set pieces: spheres [{pos, r}] and rings [{xform, R, r}].
var _obstacles: Dictionary = {"spheres": [], "tori": []}
## Short-lived effects: sparks, venting, the wreck [{node, until, vel, spin, grow}].
var _fx: Array = []
var _shake := 0.0
var _last_hit := -10.0
var _warned_until := 0.0
var ship_length := 30.0
## The keel has gone: the wreck plays out and the lifeboat takes over.
var wrecked := false
var _wreck_cam := Vector3.ZERO


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
	station = Models.station(geom, sim.data.places[place_id]["name"], Livery.for_station(sim.data, place_id))
	add_child(station["node"])
	var model := Models.ship(sim.state.ship, sim.data, Livery.for_ship(sim.data, "", sim.state.ship.get("name", ""), true))
	ship_node = model["node"]
	nose_z = model["nose_z"]
	ship_radius = model["radius"]
	ship_length = float(model.get("length", 30.0))
	_drive_plume = ship_node.find_child("DrivePlume", true, false)
	_rig = model["rig"]
	add_child(ship_node)
	audio = ShipAudio.new()
	ship_node.add_child(audio)
	audio.setup(model)
	# Start where the transit view's final approach leaves us (Navigation.add_approach):
	# on the docking axis at the hand-over point, nose to the port, rolled to the Sun as
	# in transit, still closing at the hand-over speed.
	ship_node.position = Vector3(0, 0, float(station["port_z"]) + Navigation.handover_m(sim.data, geom) - nose_z)
	ship_node.basis = ShipRig.roll_to_sun(Vector3.FORWARD, body_dirs["sun"])
	velocity = Vector3(0, 0, -float(sim.data.balance["approach"]["handover_speed_mps"]))
	spin_angle = fposmod(float(sim.state.time_s) * spin_rate, TAU)
	camera = Camera3D.new()
	# Far enough for an elevator's counterweight beyond its planet on the sky shell.
	camera.far = SKY_DISTANCE * 6.0
	camera.near = 0.2
	camera.fov = 65.0
	add_child(camera)
	camera.make_current()
	_deck_mount = Node3D.new()
	add_child(_deck_mount)
	deck = FlightDeck.new()
	_deck_mount.add_child(deck)
	_update_camera(1.0)
	var progress := {}
	for id in sim.data.projects:
		progress[sim.data.projects[id].get("feature", id)] = ProjectSystem.progress(sim.state, sim.data, id)
	set_meta("colliders", _obstacles)
	_set_pieces = SetPieces.build(self, sim.data.places[place_id].get("features", []), body_dirs, station, progress)
	_spawn_hazards()
	_spawn_work_craft()
	_sync_traffic()
	hud = load("res://view/flight/flight_hud.gd").new(self)
	hud.theme = UI.make_theme()
	add_child(hud)
	flash("On the corridor to %s, closing at %.0f m/s. Match the spin and bring her in." % [sim.data.places[place_id]["name"], -velocity.z], UI.AMBER, 6.0)


func _build_environment() -> void:
	add_child(SkyKit.environment())
	var eph = sim.ephemeris
	var t: float = sim.state.time_s
	var here: Array = eph.position(place_id, t)
	var sun := DirectionalLight3D.new()
	var sun_dir := _dir_to(eph.position("sun", t), here)
	body_dirs["sun"] = sun_dir
	# Sunlight fades with distance, gently: eyes and cameras adapt.
	var au := V.length(V.sub(here, eph.position("sun", t))) / 1.495978707e11
	sun.light_energy = 1.6 * clampf(1.0 / sqrt(au), 0.45, 1.6)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 800.0
	add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, -sun_dir, Vector3.UP if absf(sun_dir.y) < 0.99 else Vector3.RIGHT)
	add_child(Kit.sphere(SKY_DISTANCE * 0.0047 * 3.0 / maxf(au, 0.3), Kit.glow(Color("fff6e0"), 6.0), sun_dir * SKY_DISTANCE))
	for body in ["earth", "moon"]:
		body_dirs[body] = _dir_to(eph.position(body, t), here)
	# Every world big enough to see, true to its angular size. Nearer ones sit nearer
	# on the sky shell, so a moon passes in front of its planet, never behind.
	var seen: Array = SkyKit.visible_bodies(sim.data, eph, here, t)
	SkyKit.set_eclipse(sun_dir)
	var shine := SkyKit.shine_light()
	add_child(shine)
	SkyKit.aim_shine(shine, SkyKit.planetshine(sim.data, seen, sun_dir))
	var built := {}
	for id in sim.data.projects:
		# Once a build is announced its first hardware is on station.
		var announced: bool = sim.state.projects.get(id, {}).get("revealed", false)
		built[id] = maxf(ProjectSystem.progress(sim.state, sim.data, id), 0.03) if announced else 0.0
	for k in seen.size():
		var body: String = seen[k][0]
		var dir: Vector3 = seen[k][1]
		body_dirs[body] = dir
		var shell := SKY_DISTANCE * (0.55 + 0.45 * float(k) / float(maxi(1, seen.size() - 1)))
		# True angular size: a sphere of radius d*sin(a) at distance d subtends a.
		var mesh := SkyKit.body_mesh(sim.data, body, shell * sin(float(seen[k][2])))
		mesh.position = dir * shell
		SkyKit.update_body(mesh, sun_dir, t)
		SkyKit.set_distance(mesh, float(seen[k][3]))
		SkyKit.dress_body(mesh, sim.data, body, -dir, sun_dir, built)
		add_child(mesh)
		# Its planet's shadow, placed at this body's own sky scale.
		var parent: String = sim.data.bodies[body].get("parent", "sun")
		if parent != "sun" and sim.data.bodies.has(parent):
			var sky_k := shell / float(seen[k][3])
			var rel := _dir_to(eph.position(parent, t), eph.position(body, t)) * V.length(V.sub(eph.position(parent, t), eph.position(body, t)))
			SkyKit.set_occluder(mesh, mesh.position + rel * sky_k, float(sim.data.bodies[parent]["radius_m"]) * sky_k)
		# Ships and the station are at the origin, so a body's sky copy shades them
		# exactly when the real one does.
		var to_body := mesh.position
		var along := to_body.dot(sun_dir)
		var r_sky := (mesh.mesh as SphereMesh).radius
		if along > 0.0 and (to_body - sun_dir * along).length() < r_sky * 1.05:
			SkyKit.set_eclipse(sun_dir, mesh.position, r_sky)


## Direction from `from` to `to` (sim 64-bit ecliptic) as a Godot vector, ecliptic north up.
func _dir_to(to: Array, from: Array) -> Vector3:
	var d := V.normalized(V.sub(to, from))
	return Vector3(d[0], d[2], -d[1]).normalized()


func flash(text: String, colour: Color = Color.WHITE, seconds: float = 3.0) -> void:
	message = text
	message_colour = colour
	message_until = clock + seconds


func _unhandled_input(event: InputEvent) -> void:
	if docked or event.is_echo() or not event.is_pressed():
		return
	if event.is_action_pressed("flight_assist"):
		assist = ASSIST_MODES[(ASSIST_MODES.find(assist) + 1) % ASSIST_MODES.size()]
		flash("Assist: %s" % assist.to_upper(), UI.AMBER)
	elif event.is_action_pressed("flight_spin_match"):
		spin_match = not spin_match
		flash("Spin match %s" % ("ON" if spin_match else "OFF"), UI.AMBER)
	elif event.is_action_pressed("flight_view"):
		view_mode = "chase" if view_mode == "cockpit" else "cockpit"
	elif event.is_action_pressed("flight_scanner"):
		_scanner_index = (_scanner_index + 1) % tune_flight["scanner_ranges_m"].size()
		flash("Scanner range %s" % UI.km(scanner_range()) if scanner_range() >= 1000.0 else "Scanner range %d m" % int(scanner_range()), UI.AMBER, 1.5)
	elif event.is_action_pressed("flight_keys"):
		hud.show_keys = not hud.show_keys
	elif event.is_action_pressed("flight_tug"):
		_request_tug()
	elif event.is_action_pressed("flight_computer"):
		if ShipStats.has_docking_computer(sim.state.ship, sim.data):
			computer = not computer
			flash("Docking computer %s" % ("engaged: hands off" if computer else "off: you have control"), UI.AMBER)
		else:
			flash("No docking computer fitted (shipyards sell them)", UI.DIM)


func _request_tug() -> void:
	var err: String = sim.apply({"type": "dock", "manual": false})
	if err != "":
		flash(err, UI.WARN)
	else:
		docked = true


func _physics_process(dt: float) -> void:
	if docked or sim.state.paused:
		return
	if wrecked:
		clock += dt
		_move_rocks(dt)
		camera.global_position = _wreck_cam
		camera.look_at(ship_node.position, Vector3.UP)
		deck.visible = false
		return
	clock += dt
	spin_angle = fposmod(spin_angle + spin_rate * dt, TAU)
	station["rotor"].rotation.z = spin_angle
	_traffic_check -= dt
	if _traffic_check <= 0.0:
		_traffic_check = 1.0
		_sync_traffic()
	_move_traffic(dt)
	_move_work_craft()
	SetPieces.animate(_set_pieces, clock)
	# Docking: the pilot owns the roll, so the panels do what one hinge can; the dish
	# holds on the station's traffic control.
	ShipRig.aim(_rig, ship_node.global_basis, body_dirs["sun"], -ship_node.global_position, dt)
	_move_rocks(dt)
	_fly(dt)
	var c := read_controls()
	var push: Vector3 = c["thrust"]
	audio.update(dt, {"thrust": (1.0 if c["boost"] else 0.45) if push.z < 0.0 else 0.0,
		"move": Vector3(push.x, push.y, maxf(push.z, 0.0)) + (Vector3(0, 0, 1) if c["brake"] and velocity.length() > 0.05 else Vector3.ZERO),
		"spin": c["stick"] + (ang_vel - _last_ang) * 4.0 if assist != "manual" else c["stick"], "turn": ang_vel.length(),
		"time_scale": sim.state.time_scale})
	_last_ang = ang_vel
	_collide()
	_collide_world()
	if wrecked:
		return
	var ahead := _time_to_rock()
	readout["rock_s"] = ahead
	if ahead < 6.0 and clock > _warned_until:
		_warned_until = clock + 3.0
		flash("PROXIMITY  ·  rock on your course, %.1f s" % ahead, UI.WARN, 2.0)
		audio.beep()
	_check_docking()
	# The head lags the ship's acceleration: lean back under thrust, sideways in a strafe.
	if dt > 0.0:
		var accel := ship_node.global_transform.basis.inverse() * (velocity - _last_vel) / dt
		_last_vel = velocity
		var want := -accel * 0.004
		if want.length() > 0.03:
			want = want.normalized() * 0.03
		_head = _head.lerp(want, clampf(dt * 5.0, 0.0, 1.0))
	_update_camera(dt)
	if _shake > 0.0:
		var jolt := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.25
		# The deck shakes with the ship; the head a touch more.
		_deck_mount.global_position += jolt
		camera.global_position += jolt * (1.15 if view_mode == "cockpit" else 1.0)


## A pair of actions as one axis, -1 to 1: a key is all or nothing, a stick or trigger is analog
## (its deadzone is set in data/controls.json).
func _input_axis(pos: String, neg: String) -> float:
	return Input.get_action_strength(pos) - Input.get_action_strength(neg)


func read_controls() -> Dictionary:
	if not control_override.is_empty():
		return control_override
	if computer:
		return Autopilot.controls(self)
	return {
		# Translation: forward/back, strafe, up/down. Rotation: pitch, yaw, roll.
		"thrust": Vector3(_input_axis("flight_strafe_right", "flight_strafe_left"), _input_axis("flight_up", "flight_down"), _input_axis("flight_back", "flight_forward")),
		"stick": Vector3(_input_axis("flight_pitch_up", "flight_pitch_down"), _input_axis("flight_yaw_left", "flight_yaw_right"), _input_axis("flight_roll_left", "flight_roll_right")),
		"boost": Input.is_action_pressed("flight_boost"),
		"brake": Input.is_action_pressed("flight_brake"),
	}


func _fly(dt: float) -> void:
	var basis := ship_node.global_transform.basis
	var controls := read_controls()
	controls_now = controls
	var boost := float(tune_flight["boost_mult"]) if controls["boost"] else 1.0
	var accel := float(tune_flight["rcs_accel_mps2"]) * boost
	var thrust: Vector3 = controls["thrust"]
	var braking: bool = controls["brake"] or (assist == "full" and thrust == Vector3.ZERO)
	if thrust != Vector3.ZERO:
		# Full push is a unit vector (keys on two axes still make one); a half-pushed stick is half.
		velocity += basis * thrust.normalized() * minf(thrust.length(), 1.0) * accel * dt
	elif braking:
		velocity = velocity.move_toward(Vector3.ZERO, accel * dt)
	if _drive_plume:
		_drive_plume.visible = thrust.z < 0.0
	var turn := deg_to_rad(float(tune_flight["turn_rate_dps"]))
	var turn_accel := deg_to_rad(float(tune_flight["turn_accel_dps2"]))
	var stick: Vector3 = controls["stick"]
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
			# The twin of a pair stands off the axis.
			if c.size() > 3:
				var off := Vector2(p.x - float(c[3]), p.y - float(c[4]))
				var orxy := off.length()
				if p.z > z0 - r and p.z < z1 + r and orxy < cr + r:
					var o_side := cr + r - orxy
					var o_d := minf(o_side, minf(z1 + r - p.z, p.z - (z0 - r)))
					if o_d > depth:
						depth = o_d
						normal = Vector3(off.x, off.y, 0.0).normalized() if o_d == o_side and orxy > 1e-4 else (Vector3(0, 0, 1) if o_d == z1 + r - p.z else Vector3(0, 0, -1))
				continue
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
			var q := Vector2(rxy - float(torus[0]), p.z - (float(torus[2]) if torus.size() > 2 else 0.0))
			var reach := float(torus[1]) + r
			if q.length() < reach and reach - q.length() > depth:
				var qn := q.normalized() if q.length() > 1e-4 else Vector2.RIGHT
				normal = (radial * qn.x + Vector3(0, 0, qn.y)).normalized()
				depth = reach - q.length()
		if depth > 0.0:
			_bounce(normal, depth)


func _bounce(normal: Vector3, depth: float, harmless: bool = false) -> void:
	ship_node.position += normal * depth
	var vn := velocity.dot(normal)
	if vn < 0.0:
		velocity -= normal * vn * (1.0 + float(tune_flight["bump_restitution"]))
		ang_vel *= 0.5
		if harmless:
			bumps += 1
			flash("CONTACT  %.1f m/s" % -vn, UI.WARN, 2.0)
			audio.impact(-vn, Vector3(0, 0, nose_z))
		else:
			_hit(-vn, 1.0, ship_node.position - normal * ship_radius)


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
	refusals += 1
	flash("Capture refused: " + ", ".join(reasons), UI.WARN, 3.0)
	_bounce(Vector3(0, 0, 1), 0.5, true)


func scanner_range() -> float:
	return float(tune_flight["scanner_ranges_m"][_scanner_index])


## Everything the scanner can see: {pos (world), colour, kind}.
func contacts() -> Array:
	var out := [{"pos": Vector3.ZERO, "colour": UI.GOOD, "kind": "station"}]
	for id in _traffic:
		var entry: Dictionary = _traffic[id]
		if is_instance_valid(entry["ship"]):
			out.append({"pos": entry["ship"].global_position, "colour": SystemMap.fleet_colour(sim, entry["npc"]), "kind": "ship", "r": float(entry.get("radius", 15.0))})
	for w in _work_craft:
		out.append({"pos": w["node"].global_position, "colour": UI.HAZARD, "kind": "pod"})
	for rock in _rocks:
		out.append({"pos": rock["node"].global_position, "colour": UI.DIM, "kind": "rock", "r": float(rock["r"]), "vel": rock["vel"]})
	return out


func _update_camera(dt: float) -> void:
	var t := ship_node.global_transform
	ship_node.visible = view_mode != "cockpit"
	deck.visible = view_mode == "cockpit"
	if view_mode == "beauty":
		# Gallery/screenshot camera: pulled far back and up to take in the set pieces.
		camera.fov = 70.0
		camera.global_position = t * Vector3(0, 500.0, 2600.0)
		camera.look_at(Vector3(0, 0, -400.0), Vector3.UP)
		return
	if view_mode == "cockpit":
		# Pilot's eye just behind the command pod's front window.
		camera.fov = FlightDeck.FOV
		var eye := Transform3D(t.basis * Basis(Vector3.RIGHT, -deg_to_rad(SEAT_PITCH_DEG)), t * Vector3(0, 0.4, nose_z + 1.2))
		_deck_mount.global_transform = eye
		camera.global_transform = eye * Transform3D(Basis.IDENTITY, _head)
		var vp := get_viewport().get_visible_rect().size
		deck.fit(vp.x / maxf(vp.y, 1.0))
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
		# Sails are 600 m across: they moor out at the sail park, not at a berth.
		if sim.data.npcs["fleets"][npc["fleet"]].get("sail", false) or sim.data.npcs["fleets"][npc["fleet"]].get("elevator", false):
			continue
		if npc["location"]["status"] == "docked" and npc["location"]["place"] == place_id and preload("res://sim/systems/npc_system.gd").in_service(npc, t):
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
		if sim.data.npcs["fleets"][npc["fleet"]].get("sail", false) or sim.data.npcs["fleets"][npc["fleet"]].get("elevator", false):
			continue
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
		var npc: Dictionary = w["npc"]
		var operator: String = sim.data.npcs["fleets"][npc["fleet"]]["operator"]
		var model := Models.ship(npc["ship"], sim.data, Livery.for_ship(sim.data, operator, npc["name"]))
		var node: Node3D = model["node"]
		if w["mode"] == "berth":
			# Moored alongside the hub's forward half on a short arm, spinning with the station.
			var a: float = BERTH_ANGLES[w["berth"]]
			var r: float = station["hub_radius"] + model["radius"] + 6.0
			var holder := Node3D.new()
			holder.rotation.z = a
			node.position = Vector3(r, 0, station["hub_length"] * 0.5 - model["length"] * 0.5 - 2.0)
			node.rotation = Vector3(0, PI, PI * 0.5)
			# Moored: drives cold.
			var plume := node.find_child("DrivePlume", true, false)
			if plume:
				plume.visible = false
			holder.add_child(node)
			holder.add_child(Kit.box(Vector3(model["radius"] + 6.0, 0.6, 0.6), Kit.mat("steel"), Vector3(station["hub_radius"] + (model["radius"] + 6.0) * 0.5, 0, node.position.z)))
			station["rotor"].add_child(holder)
			_traffic[id] = {"node": holder, "ship": node, "mode": "berth", "npc": w["npc"], "rig": model["rig"], "radius": float(model["radius"])}
		else:
			# A bright running light so distant traffic reads as a moving star.
			node.add_child(Kit.sphere(2.5, Kit.glow(Color("ffe0a0"), 4.0), Vector3(0, 3.0, 0)))
			add_child(node)
			# Outbound, the dish swings to wherever the ship is bound.
			var bound: String = npc["location"].get("to", place_id)
			var dest_dir := _dir_to(sim.ephemeris.position(bound, sim.state.time_s), sim.ephemeris.position(place_id, sim.state.time_s)) if bound != place_id else Vector3.FORWARD
			_traffic[id] = {"node": node, "ship": node, "mode": w["mode"], "npc": w["npc"], "rig": model["rig"], "dest_dir": dest_dir, "radius": float(model["radius"])}
		changed = true
	_move_traffic(0.0)


## Lane traffic flies in and out; everyone keeps panels on the Sun and dish on target.
func _move_traffic(dt: float) -> void:
	var t: float = sim.state.time_s
	var sun: Vector3 = body_dirs["sun"]
	for id in _traffic:
		var entry: Dictionary = _traffic[id]
		if entry["mode"] == "berth":
			# Moored: talking home to Earth while the panels ride the station's spin.
			ShipRig.aim(entry["rig"], entry["ship"].global_basis, sun, body_dirs["earth"], dt)
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
		# In the lanes ships still roll freely, keeping the Sun in their panels' plane.
		var target: Vector3
		if entry["mode"] == "inbound":
			f = clampf((float(loc["arrive_t"]) - t) / LANE_WINDOW, 0.0, 1.0)
			node.basis = ShipRig.roll_to_sun(Vector3.FORWARD, sun)
		else:
			f = clampf((t - float(loc["depart_t"])) / LANE_WINDOW, 0.0, 1.0)
			node.basis = ShipRig.roll_to_sun(Vector3.BACK, sun)
		node.position = offset + Vector3(0, 0, z0 + span * f)
		target = -node.position if entry["mode"] == "inbound" else entry.get("dest_dir", Vector3.BACK)
		ShipRig.aim(entry["rig"], node.basis, sun, target, dt)


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


func _move_work_craft() -> void:
	for w in _work_craft:
		var a: float = w["phase"] + TAU * clock / float(w["period"])
		var node: Node3D = w["node"]
		var pos := Vector3(cos(a) * w["radius"], sin(a) * w["radius"], w["z"] + sin(a * 2.0) * w["bob"])
		var ahead := Vector3(cos(a + 0.05) * w["radius"], sin(a + 0.05) * w["radius"], pos.z)
		node.position = pos
		node.look_at(ahead, Vector3(0, 0, 1))


## The closing speed the co-pilot advises at this distance from the port: quick far
## out, slowing to under the capture limit for the last 25 m.
func advised_closing(along: float) -> float:
	var limit := float(tune_dock["max_speed_mps"])
	return clampf(along * 0.02, limit * 0.5, 6.0) if along > 25.0 else limit * 0.6


## The co-pilot's next instruction for a manual approach, and the axis offset in the
## ship's own frame (x right, y up), for the HUD's axis display.
func guidance() -> Dictionary:
	if readout.is_empty():
		return {}
	var basis := ship_node.global_transform.basis
	var nose := _nose()
	var along := nose.z - float(station["port_z"])
	var offset_world := Vector3(-nose.x, -nose.y, 0.0)
	var offset_local := basis.inverse() * offset_world
	var limit := float(tune_dock["max_speed_mps"])
	var advised := advised_closing(along)
	var text := ""
	if computer:
		text = "Docking computer has control."
	elif readout["align"] > float(tune_dock["max_angle_deg"]):
		text = "Turn to face straight down the station's axis (nose along the amber lights)."
	elif Vector2(nose.x, nose.y).length() > maxf(1.5, along * 0.08):
		var parts := []
		if absf(offset_local.x) > 0.5:
			parts.append("right (D)" if offset_local.x > 0.0 else "left (A)")
		if absf(offset_local.y) > 0.5:
			parts.append("up (R)" if offset_local.y > 0.0 else "down (F)")
		text = "Strafe %s onto the axis: %.0f m off." % [" and ".join(parts), Vector2(nose.x, nose.y).length()]
	elif readout["speed"] > advised * 1.3:
		text = "Too fast for this range. Brake (S or X) to about %.1f m/s." % advised
	elif readout["closing"] < advised * 0.5 and along > 6.0:
		text = "On the axis. Close in: aim for %.1f m/s (W)." % advised
	else:
		text = "Good. Hold it there. Capture under %.1f m/s." % limit
	return {"text": text, "offset_local": offset_local, "advised": advised, "along": along}


# --- Collisions: rocks, ships, structures, damage and the wreck ------------------------

## Drifting rocks on this approach (data/places.json "hazards"), deterministic per port:
## mostly small, a few big, the corridor in to the port kept clear.
func _spawn_hazards() -> void:
	var hz: Dictionary = sim.data.places[place_id].get("hazards", {})
	if hz.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(place_id + "rocks")
	var looks := {
		"metal": {"highland_colour": Color("6e6a64"), "mare_colour": Color("4e4b47")},
		"ice": {"highland_colour": Color("d8dee4"), "mare_colour": Color("aab6c2")},
		"rubble": {},
	}
	var look: Dictionary = looks.get(hz.get("look", "rubble"), {})
	var sizes: Array = hz["radius_m"]
	var field: Array = hz["field_m"]
	for i in int(hz["rocks"]):
		var r := lerpf(float(sizes[0]), float(sizes[1]), pow(rng.randf(), 2.5))
		var pos := Vector3.ZERO
		for _try in 30:
			pos = Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)).normalized() * rng.randf_range(float(field[0]), float(field[1]))
			if not (pos.z > -200.0 and Vector2(pos.x, pos.y).length() < 160.0 + r):
				break
		var stretch := Vector3(rng.randf_range(1.0, 1.6), rng.randf_range(0.7, 1.1), 1.0)
		var node := SetPieces.rock(r, stretch, 3000 + i, look)
		node.position = pos
		node.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, 0.0)
		add_child(node)
		var drift := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)).normalized() * float(hz.get("drift_mps", 0.05)) * rng.randf()
		_rocks.append({"node": node, "r": r * (stretch.x + stretch.y + stretch.z) / 3.0, "vel": drift,
			"spin": Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * 0.05,
			"mass_t": 2.4 * 4.18879 * r * r * r})


func _move_rocks(dt: float) -> void:
	for rock in _rocks:
		var node: Node3D = rock["node"]
		node.position += rock["vel"] * dt
		node.rotation += rock["spin"] * dt
	for f in _fx.duplicate():
		var node: Node3D = f["node"]
		if not is_instance_valid(node) or clock > float(f["until"]):
			if is_instance_valid(node):
				node.queue_free()
			_fx.erase(f)
			continue
		node.position += f.get("vel", Vector3.ZERO) * dt
		node.rotation += f.get("spin", Vector3.ZERO) * dt
		node.scale *= 1.0 + float(f.get("grow", 0.0)) * dt
	_shake = maxf(0.0, _shake - dt * 1.5)


## Everything solid out here that isn't the station: [{pos, r, vel, mass_t, rock}]. A
## mass of 0 means immovable (structures, and ships and pods on their own business).
func _bodies_nearby(p: Vector3, reach: float) -> Array:
	var out := []
	for rock in _rocks:
		var c: Vector3 = rock["node"].position
		if c.distance_to(p) < float(rock["r"]) + reach:
			out.append({"pos": c, "r": rock["r"], "vel": rock["vel"], "mass_t": rock["mass_t"], "rock": rock})
	for id in _traffic:
		var entry: Dictionary = _traffic[id]
		if is_instance_valid(entry["ship"]):
			var c: Vector3 = entry["ship"].global_position
			var r := float(entry.get("radius", 15.0))
			if c.distance_to(p) < r + reach:
				out.append({"pos": c, "r": r, "vel": Vector3.ZERO, "mass_t": 0.0, "what": "ship"})
	for w in _work_craft:
		var c: Vector3 = w["node"].global_position
		if c.distance_to(p) < 3.0 + reach:
			out.append({"pos": c, "r": 3.0, "vel": Vector3.ZERO, "mass_t": 0.0, "what": "pod"})
	for sp in _obstacles["spheres"]:
		if Vector3(sp["pos"]).distance_to(p) < float(sp["r"]) + reach:
			out.append({"pos": sp["pos"], "r": sp["r"], "vel": Vector3.ZERO, "mass_t": 0.0})
	return out


func _collide_world() -> void:
	var probes := [[ship_node.position, ship_radius], [_nose(), 1.5]]
	for probe in probes:
		var p: Vector3 = probe[0]
		var r: float = probe[1]
		for b in _bodies_nearby(p, r):
			var d: Vector3 = p - b["pos"]
			var dist := d.length()
			var reach: float = float(b["r"]) + r
			if dist < reach:
				var n := d / dist if dist > 1e-4 else Vector3.UP
				_contact(n, reach - dist, b["vel"], float(b["mass_t"]), b["pos"] + n * float(b["r"]), b.get("rock"))
		for torus in _obstacles["tori"]:
			var xf: Transform3D = torus["xform"]
			var q := xf.affine_inverse() * p
			var rxy := Vector2(q.x, q.y).length()
			var radial := Vector3(q.x, q.y, 0.0).normalized() if rxy > 1e-4 else Vector3.RIGHT
			var w := Vector2(rxy - float(torus["R"]), q.z)
			var reach := float(torus["r"]) + r
			if w.length() < reach:
				var wn := w.normalized() if w.length() > 1e-4 else Vector2.RIGHT
				var n := (xf.basis * (radial * wn.x + Vector3(0, 0, wn.y))).normalized()
				_contact(n, reach - w.length(), Vector3.ZERO, 0.0, p - n * r, null)


## Push apart, trade momentum, and take the knock. `other_mass_t` 0 is immovable.
func _contact(normal: Vector3, depth: float, other_vel: Vector3, other_mass_t: float, point: Vector3, rock) -> void:
	ship_node.position += normal * depth
	var vn := (velocity - other_vel).dot(normal)
	if vn >= 0.0:
		return
	var m_ship := ShipStats.total_mass_t(sim.state.ship, sim.data)
	var inv_s := 1.0 / maxf(m_ship, 0.1)
	var inv_o := 0.0 if other_mass_t <= 0.0 else 1.0 / other_mass_t
	var e := float(tune_flight["bump_restitution"])
	var j := -(1.0 + e) * vn / (inv_s + inv_o)
	velocity += normal * j * inv_s
	if rock != null:
		rock["vel"] -= normal * j * inv_o
		rock["spin"] += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * minf(-vn * 0.02, 0.5)
	# A hard knock sets you tumbling.
	ang_vel += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * minf(-vn * 0.04, 1.2)
	_hit(-vn, inv_s / (inv_s + inv_o), point)
	if rock != null and float(rock["r"]) < 10.0 and -vn > 3.0:
		_shatter(rock, normal)


## Report an impact to the sim (it decides what broke), and show it.
func _hit(speed: float, share: float, point: Vector3) -> void:
	var safe := float(sim.data.balance["damage"]["safe_mps"])
	if speed <= safe:
		bumps += 1
		flash("CONTACT  %.1f m/s" % speed, UI.WARN, 2.0)
		audio.impact(speed, ship_node.global_transform.affine_inverse() * point)
		return
	if clock - _last_hit < 0.3:
		return
	_last_hit = clock
	var lp := ship_node.global_transform.affine_inverse() * point
	var f := clampf((lp.z - nose_z) / maxf(ship_length, 1.0), 0.0, 1.0)
	var zone := "mid"
	if absf(lp.x) > ship_radius * 0.55 and absf(lp.x) > absf(lp.y):
		zone = "side"
	elif f < 0.25:
		zone = "nose"
	elif f > 0.7:
		zone = "tail"
	sim.apply({"type": "impact", "speed": speed, "share": share, "zone": zone, "seed": int(clock * 1000.0) + bumps})
	audio.impact(speed, lp)
	if DamageSystem.integrity(sim.state.ship) < 0.5:
		audio.alarm(true)
	bumps += 1
	_shake = minf(1.0, speed / 6.0)
	for k in int(clampf(speed * 3.0, 4.0, 24.0)):
		var spark := Kit.sphere(0.12, Kit.glow(Color("ffd890"), 6.0), point)
		add_child(spark)
		_fx.append({"node": spark, "until": clock + randf_range(0.4, 1.4), "vel": Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * speed * 1.5 + velocity})
	if zone == "tail":
		# Venting: a breached tank puffing propellant.
		var vent := Kit.sphere(1.0, Kit.glow(Color(0.85, 0.9, 1.0, 1.0), 1.5), point)
		add_child(vent)
		_fx.append({"node": vent, "until": clock + 3.0, "grow": 1.2, "vel": (point - ship_node.position).normalized() * 3.0 + velocity})
	flash("IMPACT  %.1f m/s   ·   hull %d%%" % [speed, int(round(DamageSystem.integrity(sim.state.ship) * 100.0))], UI.WARN, 3.0)
	if sim.state.location.get("status") == "lifeboat":
		_wreck()


## A small rock hit hard enough breaks up.
func _shatter(rock: Dictionary, normal: Vector3) -> void:
	var node: Node3D = rock["node"]
	var r := float(rock["r"])
	for k in 4:
		var piece := SetPieces.rock(r * 0.45, Vector3(1.2, 0.9, 1.0), 7000 + k + int(r * 100.0))
		piece.position = node.position + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * r * 0.5
		add_child(piece)
		_rocks.append({"node": piece, "r": r * 0.45, "vel": rock["vel"] + (Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) - normal).normalized() * randf_range(0.5, 2.0),
			"spin": Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.6, "mass_t": float(rock["mass_t"]) * 0.09})
	_rocks.erase(rock)
	node.queue_free()


## The keel has gone. A flash, the pieces, and the lifeboat away; the sim brings it in.
func _wreck() -> void:
	if wrecked:
		return
	wrecked = true
	var at := ship_node.position
	var boom := Kit.sphere(ship_radius * 0.5, Kit.glow(Color("fff0c8"), 8.0), at)
	add_child(boom)
	_fx.append({"node": boom, "until": clock + 0.9, "grow": 3.0})
	var fire := Kit.sphere(ship_radius * 0.7, Kit.glow(Color("ff9040"), 3.0), at)
	add_child(fire)
	_fx.append({"node": fire, "until": clock + 2.2, "grow": 1.6})
	for k in 18:
		var piece := Kit.box(Vector3(randf_range(0.5, 3.0), randf_range(0.3, 1.5), randf_range(0.5, 4.0)), Kit.mat(["grey", "dark", "steel", "foil"][k % 4]), at)
		add_child(piece)
		_fx.append({"node": piece, "until": clock + 60.0, "vel": velocity + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(2.0, 12.0),
			"spin": Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2))})
	var pod := Kit.sphere(1.2, Kit.mat("orange"), at)
	pod.add_child(Kit.beacon(Color("ff3a2a"), Vector3(0, 1.3, 0), 0.3, 0.8))
	add_child(pod)
	_fx.append({"node": pod, "until": clock + 600.0, "vel": velocity * 0.5 + (Vector3(0, 0, 1) - at.normalized() * 0.2).normalized() * 4.0})
	audio.wreck(Vector3.ZERO)
	ship_node.visible = false
	_wreck_cam = at + Vector3(0, ship_radius * 4.0, ship_radius * 10.0)
	flash("KEEL FAILURE  ·  ABANDON SHIP  ·  the lifeboat is away", UI.WARN, 20.0)


## Seconds to the nearest rock on our present course, if it is close (INF if none).
func _time_to_rock() -> float:
	var best := INF
	for rock in _rocks:
		var d: Vector3 = rock["node"].position - ship_node.position
		var rel: Vector3 = velocity - rock["vel"]
		var closing := d.dot(rel)
		if closing <= 0.0 or d.length() > 2000.0:
			continue
		var t := closing / maxf(rel.length_squared(), 1e-6)
		var miss := (d - rel * t).length()
		if miss < float(rock["r"]) + ship_radius * 1.5:
			best = minf(best, t)
	return best
