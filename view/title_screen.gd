## Attract screen: a shot director. It cuts between cinematic set-ups around the
## system, each about 18 seconds, picked at random (never the same twice running):
##   earth_orbit   Kibo Ring against Earth's limb, a ship coming in out of the dark
##   jovian        a chase past Callisto with Jupiter and Io behind
##   saturn        a ship crossing in front of Saturn's rings, Titan hanging off
##   lunar         a low run over the Moon's craters with Earth on the horizon
##   mars          a slow orbit round a ship at Phobos, Mars below
##   belt          weaving between tumbling rocks off Ceres, the Concord Pair beyond
##   enceladus     under Enceladus' south pole, its plumes blazing against the Sun
##   sail          a Lightfoot sail freighter catching sunlight over Earth
## Bodies wear what is on them (plumes, elevators), as the system will be.
## Each shot flies a random hull in a real fleet's livery (the ships you will meet),
## with its caption. View-only: the sim is not ticking while this is up.
##
## Space / Enter starts, L loads the quick save, Esc quits.
extends Node3D

signal start_requested(load_save: bool)

const Kit := preload("res://view/flight/kit.gd")
const Models := preload("res://view/flight/models.gd")
const ShipRig := preload("res://view/flight/ship_rig.gd")
const Livery := preload("res://view/flight/livery.gd")
const SetPieces := preload("res://view/flight/set_pieces.gd")
const SkyKit := preload("res://view/flight/sky.gd")
const ShipStats := preload("res://sim/ship_stats.gd")
const UI := preload("res://view/ui/ui_kit.gd")

const SHOTS := ["earth_orbit", "jovian", "saturn", "lunar", "mars", "belt", "enceladus", "sail"]
const SHOT_S := 18.0
const FADE_S := 0.8

var data
var has_save := false
var camera: Camera3D
## Seconds into the current shot.
var clock := 0.0
## Set to force a shot (captures); otherwise the director picks at random.
var force_shot := ""
var _rng := RandomNumberGenerator.new()
var _shot := ""
var _stage: Node3D
var _hero: Node3D
var _hero_rig: Dictionary = {}
var _hero_plume: Node3D
var _hero_hull := ""
var _hero_len := 30.0
var _where := ""
var _sun_dir := Vector3(-0.55, 0.35, 0.75).normalized()
var _update: Callable
var _spinners: Array = []
## Set-piece animations (SetPieces.animate).
var _anims: Array = []
var _blinkers: Array = []
var _overlay: Control
var _fade: ColorRect


func _init(catalog, save_exists: bool) -> void:
	data = catalog
	has_save = save_exists
	_rng.randomize()


func _ready() -> void:
	add_child(SkyKit.environment())
	camera = Camera3D.new()
	camera.fov = 50.0
	camera.near = 0.5
	camera.far = 2.0e6
	add_child(camera)
	camera.make_current()
	# The fade sits under the overlay, so the title never blinks out with the cut.
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	_overlay = load("res://view/title_overlay.gd").new(self)
	_overlay.theme = UI.make_theme()
	add_child(_overlay)
	next_shot()


func hero_info() -> Dictionary:
	var ship := _ship_dict(_hero_hull)
	return {
		"name": data.ships[_hero_hull]["name"],
		"description": data.ships[_hero_hull].get("description", ""),
		"cargo_t": ShipStats.cargo_capacity_t(ship, data),
		"fuel_t": ShipStats.fuel_capacity_t(ship, data),
		"thrust_n": ShipStats.thrust_n(ship, data),
		"mass_t": ShipStats.dry_mass_t(ship, data),
		"where": _where,
		"showing": clock > 2.5 and clock < SHOT_S - 2.0,
	}


## Cut to a new shot: a random set-up (or `force_shot`) and a random hero.
func next_shot() -> void:
	if _stage:
		_stage.queue_free()
	_stage = Node3D.new()
	add_child(_stage)
	_spinners = []
	_anims = []
	var pool: Array = SHOTS.filter(func(s): return s != _shot)
	_shot = force_shot if force_shot != "" else pool[_rng.randi() % pool.size()]
	clock = 0.0
	_pick_hero("sail_freighter" if _shot == "sail" else "")
	call("_build_" + _shot)
	_blinkers = Kit.collect_blinkers(_stage)


# --- shared pieces ------------------------------------------------------------------

func _ship_dict(hull: String) -> Dictionary:
	var h: Dictionary = data.ships[hull]
	var ship := {"hull": hull, "modules": h["modules"].duplicate(), "cargo": {}, "fuel_t": 0.0}
	ship["fuel_t"] = ShipStats.fuel_capacity_t(ship, data)
	return ship


## A random hull, in the colours and name of a fleet that flies it (or an independent).
func _pick_hero(hull: String = "") -> void:
	# Sails are hundreds of metres across: they get their own shot, not a chase.
	var hulls: Array = data.ships.keys().filter(func(h): return not data.ships[h]["modules"].values().any(func(m): return data.modules[m].get("sail", false)))
	_hero_hull = hull if hull != "" else hulls[_rng.randi() % hulls.size()]
	var fleets: Array = []
	for id in data.npcs["fleets"]:
		if data.npcs["fleets"][id]["hull"] == _hero_hull:
			fleets.append(data.npcs["fleets"][id])
	var livery: Dictionary
	if fleets.is_empty():
		var names := ["Mabel's Pride", "Long Shot", "Late Bloomer", "Good Enough"]
		livery = Livery.for_ship(data, "Independent", names[_rng.randi() % names.size()])
	else:
		var fleet: Dictionary = fleets[_rng.randi() % fleets.size()]
		var fleet_names: Array = fleet["names"]
		livery = Livery.for_ship(data, fleet["operator"], fleet_names[_rng.randi() % fleet_names.size()])
	var model := Models.ship(_ship_dict(_hero_hull), data, livery)
	_hero = model["node"]
	_hero_rig = model["rig"]
	_hero_len = float(model["length"])
	_hero_plume = _hero.find_child("DrivePlume", true, false)
	_stage.add_child(_hero)


func _light(sun_dir: Vector3, energy: float = 1.5, flood_at: Vector3 = Vector3(-30, 25, 10)) -> void:
	_sun_dir = sun_dir.normalized()
	var sun := DirectionalLight3D.new()
	sun.light_energy = energy
	_stage.add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, -_sun_dir, Vector3.UP if absf(_sun_dir.y) < 0.99 else Vector3.RIGHT)
	_stage.add_child(Kit.sphere(800.0, Kit.glow(Color("fff6e0"), 6.0), _sun_dir * 60000.0))
	# A work light by the camera, so the hero reads even on its night side.
	var flood := OmniLight3D.new()
	flood.position = flood_at
	flood.omni_range = 400.0
	flood.light_energy = 1.2
	flood.light_color = Color("ffe8c8")
	_stage.add_child(flood)


func _body(body: String, radius: float, at: Vector3, day_spin: float = 0.0) -> MeshInstance3D:
	var mesh := SkyKit.body_mesh(data, body, radius)
	(mesh.mesh as SphereMesh).radial_segments = 128
	(mesh.mesh as SphereMesh).rings = 64
	mesh.position = at
	SkyKit.update_body(mesh, _sun_dir, 0.0)
	# The camera works near the origin: dress the body for a viewer there.
	SkyKit.dress_body(mesh, data, body, -at.normalized(), _sun_dir)
	_stage.add_child(mesh)
	if day_spin != 0.0:
		_spinners.append([mesh, day_spin])
	return mesh


## Place the hero, facing along `dir` and rolled to keep its panels on the Sun.
func _fly(pos: Vector3, dir: Vector3, burning: bool, dt: float) -> void:
	_hero.position = pos
	if dir.length() > 1e-4:
		_hero.basis = ShipRig.roll_to_sun(dir, _sun_dir)
	if _hero_plume:
		_hero_plume.visible = burning
	ShipRig.aim(_hero_rig, _hero.basis, _sun_dir, -_hero.position, dt)


# --- the shots ------------------------------------------------------------------------

## Kibo Ring against Earth's limb; the ship comes in out of the dark, turns, burns away.
func _build_earth_orbit() -> void:
	_where = "Low Earth orbit  ·  Kibo Ring"
	_light(Vector3(-0.55, 0.35, 0.75))
	_body("earth", 14000.0, Vector3(9500.0, -11800.0, -17000.0), 0.004)
	_body("moon", 700.0, Vector3(-15000.0, 7000.0, -42000.0))
	var station := Models.station(data.places["kibo_ring"]["station"], data.places["kibo_ring"]["name"], Livery.for_station(data, "kibo_ring"))
	var holder := Node3D.new()
	holder.position = Vector3(-230.0, 60.0, -760.0)
	holder.rotation = Vector3(0.12, 0.85, 0.0)
	holder.add_child(station["node"])
	_stage.add_child(holder)
	var rotor: Node3D = station["rotor"]
	var rate := float(data.places["kibo_ring"]["station"]["spin_rpm"]) * TAU / 60.0
	_update = func(dt: float) -> void:
		rotor.rotation.z += rate * dt
		var d := 58.0
		var pos: Vector3
		var dir := Vector3(sin(clock * 0.45 + PI * 0.75), 0.0, cos(clock * 0.45 + PI * 0.75))
		var burning := false
		if clock < 3.0:
			var e := 1.0 - pow(1.0 - clock / 3.0, 3.0)
			pos = Vector3(lerpf(160.0, 0.0, e), lerpf(40.0, 0.0, e), lerpf(-1400.0, -d, e))
			burning = clock < 2.5
		elif clock < SHOT_S - 3.0:
			pos = Vector3(0, sin(clock * 0.8) * 0.6, -d)
		else:
			var f := (clock - SHOT_S + 3.0) / 3.0
			pos = Vector3(f * f * 900.0, f * f * 120.0, -d - f * f * 1600.0)
			dir = Vector3(0.5, 0.06, -0.86)
			burning = true
		_fly(pos, dir, burning, dt)
		camera.position = Vector3(sin(clock * 0.13) * 1.5, 4.0 + sin(clock * 0.21) * 0.8, 0.0)
		camera.look_at(Vector3(sin(clock * 0.07) * 4.0, 0.0, -d), Vector3.UP)


## A chase past Callisto: the camera rides behind and above the ship as it curves
## round the moon, Jupiter and its belts filling the back of the shot.
func _build_jovian() -> void:
	_where = "Callisto  ·  the Jovian system"
	_light(Vector3(0.8, 0.3, 0.4), 1.3)
	var jupiter := _body("jupiter", 60000.0, Vector3(-90000.0, 15000.0, -260000.0), 0.02)
	_body("io", 1600.0, Vector3(30000.0, 6000.0, -150000.0))
	_body("europa", 1300.0, Vector3(-45000.0, -9000.0, -120000.0))
	var callisto := _body("callisto", 2400.0, Vector3(0.0, -1800.0, -5200.0))
	var centre := callisto.position
	_update = func(dt: float) -> void:
		var a := lerpf(-0.9, 0.5, clock / SHOT_S)
		var r := 3600.0
		var pos := centre + Vector3(sin(a) * r, 1800.0 + 260.0 * sin(clock * 0.2), cos(a) * r)
		var tangent := Vector3(cos(a), 0.0, -sin(a))
		_fly(pos, tangent, clock < 6.0 or clock > 13.0, dt)
		# Ride on the far side of the ship from Jupiter, so the giant fills the back of the shot.
		var away := (pos - jupiter.position).normalized()
		var side := away.cross(Vector3.UP).normalized()
		camera.position = pos + away * _hero_len * 2.6 + Vector3(0, _hero_len * 0.5, 0) + side * _hero_len * sin(clock * 0.15) * 0.8
		camera.look_at(pos.lerp(jupiter.position, 0.004), Vector3.UP)


## Saturn's rings, tilted, Titan off to one side: the ship crosses in front of them,
## the camera panning to keep it in frame.
func _build_saturn() -> void:
	_where = "Titan  ·  Saturn"
	_light(Vector3(0.6, 0.45, 0.65), 1.2)
	var saturn := _body("saturn", 40000.0, Vector3(30000.0, -14000.0, -200000.0), 0.02)
	saturn.basis = Basis(Vector3.RIGHT, 0.42) * Basis(Vector3.FORWARD, 0.25)
	_body("titan", 2600.0, Vector3(-26000.0, 9000.0, -90000.0))
	_body("enceladus", 300.0, Vector3(9000.0, -2500.0, -60000.0))
	_update = func(dt: float) -> void:
		var f := clock / SHOT_S
		var pos := Vector3(lerpf(260.0, -320.0, f), 14.0 + 10.0 * sin(f * PI), lerpf(-180.0, -240.0, f))
		_fly(pos, Vector3(-1.0, 0.02, -0.1), true, dt)
		camera.position = Vector3(0.0, 8.0, 0.0)
		camera.look_at(pos.lerp(Vector3(0, -20, -400), 0.25), Vector3.UP)


## A low run over the Moon's craters; Earth hangs on the horizon ahead.
func _build_lunar() -> void:
	_where = "A low pass  ·  the Moon"
	_light(Vector3(0.9, 0.18, -0.2), 1.6)
	var moon := _body("moon", 220000.0, Vector3(0.0, -220000.0 - 900.0, 0.0))
	# Fine enough that the horizon a few km off stays round.
	(moon.mesh as SphereMesh).radial_segments = 1024
	(moon.mesh as SphereMesh).rings = 512
	_body("earth", 5200.0, Vector3(-9000.0, 5200.0, -120000.0), 0.004)
	_update = func(dt: float) -> void:
		# Turn the Moon beneath us rather than fly a ship tens of km: same view, safer floats.
		moon.rotation.x += dt * 0.0016
		var pos := Vector3(sin(clock * 0.3) * 6.0, sin(clock * 0.45) * 2.0, -60.0)
		_fly(pos, Vector3(0.0, -0.02, -1.0), clock > 9.0, dt)
		camera.position = Vector3(18.0 + sin(clock * 0.1) * 4.0, 9.0, 4.0)
		camera.look_at(pos + Vector3(0, 0, -30), Vector3.UP)


## Holding station off Phobos with Mars filling the lower sky; the camera circles.
func _build_mars() -> void:
	_where = "Phobos  ·  Mars"
	_light(Vector3(-0.4, 0.5, 0.75), 1.4)
	var mars := _body("mars", 50000.0, Vector3(-20000.0, -62000.0, -60000.0), 0.01)
	var phobos := SetPieces.rock(160.0, Vector3(1.3, 0.95, 1.05), 401, {"highland_colour": Color("6e625a"), "mare_colour": Color("574d47")})
	phobos.position = Vector3(220.0, -40.0, -420.0)
	_stage.add_child(phobos)
	_update = func(dt: float) -> void:
		phobos.rotation.y += dt * 0.01
		var pos := Vector3(0, sin(clock * 0.5) * 0.8, -40.0)
		_fly(pos, Vector3(-0.3, 0.0, -1.0), false, dt)
		# Above and behind, Mars below and beyond the ship, the camera easing round.
		var away := (pos - mars.position).normalized().rotated(Vector3.UP, sin(clock * 0.12) * 0.5)
		camera.position = pos + away * _hero_len * 2.0
		camera.look_at(pos.lerp(mars.position, 0.0012), Vector3.UP)


## Off Ceres: rocks tumbling past as the ship threads between them.
func _build_belt() -> void:
	_where = "Off Ceres  ·  the asteroid belt"
	_light(Vector3(0.7, 0.4, 0.5), 1.1)
	var ceres := _body("ceres", 12000.0, Vector3(25000.0, -9000.0, -90000.0))
	# The Concord Pair, finished, turning in the distance.
	_anims = SetPieces._oneill_pair(_stage, {"sun": _sun_dir, "ceres": ceres.position.normalized()}, 1.0, 0.0, Vector3(-120000.0, 6000.0, -250000.0))
	var rocks := []
	for k in 7:
		var rock := SetPieces.rock(_rng.randf_range(12.0, 70.0), Vector3(_rng.randf_range(1.0, 1.6), _rng.randf_range(0.7, 1.1), 1.0), 900 + k)
		rock.position = Vector3(_rng.randf_range(-300.0, 300.0), _rng.randf_range(-90.0, 90.0), -150.0 - 220.0 * k)
		_stage.add_child(rock)
		rocks.append([rock, Vector3(_rng.randf_range(-0.2, 0.2), _rng.randf_range(-0.2, 0.2), _rng.randf_range(-0.2, 0.2))])
	_update = func(dt: float) -> void:
		for r in rocks:
			r[0].rotation += r[1] * dt
		var z := -40.0 - clock * 85.0
		var pos := Vector3(sin(clock * 0.35) * 40.0, sin(clock * 0.22) * 14.0, z)
		var dir := Vector3(cos(clock * 0.35) * 14.0, cos(clock * 0.22) * 3.1, -85.0)
		_fly(pos, dir, true, dt)
		camera.position = pos + Vector3(_hero_len * 0.9, _hero_len * 0.4, _hero_len * 2.0)
		camera.look_at(pos + Vector3(0, 0, -_hero_len), Vector3.UP)


## Under Enceladus' south pole, the Sun just behind the moon: the tiger-stripe plumes
## light up the way they did for Cassini, and the ship slides beneath them.
func _build_enceladus() -> void:
	_where = "Enceladus  ·  the tiger stripes"
	_light(Vector3(0.55, 0.3, -0.8), 1.3, Vector3(30, -10, 40))
	_body("saturn", 30000.0, Vector3(-70000.0, 12000.0, -160000.0), 0.02)
	var moon := _body("enceladus", 2600.0, Vector3(1400.0, 3600.0, -11000.0))
	_update = func(dt: float) -> void:
		var f := clock / SHOT_S
		var pos := Vector3(lerpf(-260.0, 220.0, f), -20.0 + 10.0 * sin(f * PI), -300.0 - 60.0 * f)
		_fly(pos, Vector3(1.0, 0.03, -0.12), clock > 4.0 and clock < 12.0, dt)
		camera.position = Vector3(-30.0 + 20.0 * f, -40.0, 120.0)
		camera.look_at(pos.lerp(moon.position + Vector3(0, -3200.0, 0), 0.08), Vector3.UP)


## A Lightfoot sail freighter over Earth: 600 m of film turning slowly to the Sun.
func _build_sail() -> void:
	_where = "High Earth orbit  ·  a Lightfoot sail"
	_light(Vector3(-0.5, 0.45, 0.6), 1.5, Vector3(-200, 300, 600))
	_body("earth", 40000.0, Vector3(-22000.0, -38000.0, -90000.0), 0.004)
	_body("moon", 900.0, Vector3(30000.0, 9000.0, -120000.0))
	_update = func(dt: float) -> void:
		var f := clock / SHOT_S
		var pos := Vector3(0.0, 0.0, -1400.0)
		# Sail square to the Sun, backing off a little as the camera eases round.
		_hero.position = pos
		_hero.basis = Basis.looking_at(-_sun_dir.rotated(Vector3.UP, 0.4 + 0.15 * f), Vector3.UP)
		if _hero_plume:
			_hero_plume.visible = false
		camera.position = Vector3(380.0 * sin(f * 0.8 - 0.4), 160.0 - 80.0 * f, 300.0 * f)
		camera.look_at(pos, Vector3.UP)


func _process(dt: float) -> void:
	clock += dt
	if clock >= SHOT_S:
		next_shot()
		return
	for s in _spinners:
		var m: ShaderMaterial = s[0].material_override
		m.set_shader_parameter("spin", clock * float(s[1]))
	if _update.is_valid():
		_update.call(dt)
	SetPieces.animate(_anims, clock)
	Kit.update_blinkers(_blinkers, clock)
	# Cut through black: fade up at the start of a shot, down at its end.
	var a := 0.0
	if clock < FADE_S:
		a = 1.0 - clock / FADE_S
	elif clock > SHOT_S - FADE_S:
		a = (clock - SHOT_S + FADE_S) / FADE_S
	_fade.color.a = a


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			start_requested.emit(false)
		KEY_L:
			if has_save:
				start_requested.emit(true)
		KEY_ESCAPE:
			get_tree().quit()
