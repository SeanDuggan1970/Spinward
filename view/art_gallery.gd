## Art check (`--art=<dir>`): planet and moon surfaces under a few sun angles and
## ranges, then one ship from every fleet (and the player's) in its livery, close up.
## View-only; no sim state is touched.
extends Node3D

const Kit := preload("res://view/flight/kit.gd")
const SkyKit := preload("res://view/flight/sky.gd")
const Models := preload("res://view/flight/models.gd")
const Livery := preload("res://view/flight/livery.gd")
const SetPieces := preload("res://view/flight/set_pieces.gd")
const ShipRig := preload("res://view/flight/ship_rig.gd")

## [name, body, sun direction (towards the Sun), camera distance in radii, spin]
const SHOTS := [
	["earth-day", "earth", Vector3(0.2, 0.3, 1.0), 3.2, 0.0],
	["earth-day-2", "earth", Vector3(0.2, 0.3, 1.0), 3.2, 2.1],
	["earth-terminator", "earth", Vector3(1.0, 0.1, 0.25), 3.2, 4.0],
	["earth-night", "earth", Vector3(-0.3, 0.0, -1.0), 2.4, 1.0],
	["earth-limb", "earth", Vector3(0.6, 0.6, 0.4), 1.12, 3.0],
	["moon-full", "moon", Vector3(0.1, 0.1, 1.0), 3.2, 0.0],
	["moon-quarter", "moon", Vector3(1.0, 0.0, 0.1), 3.2, 0.0],
	["moon-low", "moon", Vector3(1.0, 0.25, 0.4), 1.05, 0.0],
	["mars", "mars", Vector3(0.5, 0.3, 1.0), 3.2, 0.0],
	["jupiter", "jupiter", Vector3(0.4, 0.2, 1.0), 3.0, 0.0],
	["saturn", "saturn", Vector3(0.6, 0.45, 1.0), 4.5, 0.0],
	["uranus", "uranus", Vector3(0.3, 0.2, 1.0), 3.2, 0.0],
	["neptune", "neptune", Vector3(0.3, 0.2, 1.0), 3.2, 0.0],
	["venus", "venus", Vector3(0.5, 0.2, 1.0), 3.2, 0.0],
	["titan", "titan", Vector3(0.5, 0.2, 1.0), 3.2, 0.0],
	["io", "io", Vector3(0.5, 0.2, 1.0), 3.2, 0.0],
	["europa", "europa", Vector3(0.5, 0.2, 1.0), 3.2, 0.0],
	["ganymede", "ganymede", Vector3(0.5, 0.2, 1.0), 3.2, 0.0],
	["callisto", "callisto", Vector3(0.5, 0.2, 1.0), 3.2, 0.0],
	["enceladus", "enceladus", Vector3(0.5, 0.2, 1.0), 3.2, 0.0],
	["ceres", "ceres", Vector3(0.5, 0.2, 1.0), 3.2, 0.0],
	["phobos", "phobos", Vector3(0.5, 0.2, 1.0), 3.2, 0.0],
	["pluto", "pluto", Vector3(0.5, 0.2, 1.0), 3.2, 0.0],
	["mercury", "mercury", Vector3(0.5, 0.2, 1.0), 3.2, 0.0],
]

var data
var dir := ""
var _camera: Camera3D
var _sun: DirectionalLight3D
var _bodies := {}


func _init(catalog, out_dir: String) -> void:
	data = catalog
	dir = out_dir


func _ready() -> void:
	add_child(SkyKit.environment())
	_sun = DirectionalLight3D.new()
	_sun.light_energy = 1.6
	add_child(_sun)
	for shot in SHOTS:
		var body: String = shot[1]
		if _bodies.has(body):
			continue
		var mesh := SkyKit.body_mesh(data, body, 1.0)
		(mesh.mesh as SphereMesh).radial_segments = 128
		(mesh.mesh as SphereMesh).rings = 64
		add_child(mesh)
		_bodies[body] = mesh
	_camera = Camera3D.new()
	_camera.fov = 50.0
	_camera.near = 0.001
	add_child(_camera)
	_camera.make_current()
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	for shot in SHOTS:
		var sun_dir: Vector3 = (shot[2] as Vector3).normalized()
		for body in _bodies:
			_bodies[body].visible = body == shot[1]
		var mesh: MeshInstance3D = _bodies[shot[1]]
		SkyKit.update_body(mesh, sun_dir, 0.0)
		(mesh.material_override as ShaderMaterial).set_shader_parameter("spin", shot[4])
		_sun.look_at_from_position(Vector3.ZERO, -sun_dir, Vector3.UP)
		var d: float = shot[3]
		if d < 1.5:
			# Skimming: camera just above the surface, looking along it.
			_camera.look_at_from_position(Vector3(0.0, 0.0, d), Vector3(0.0, 0.85, 0.3), Vector3.UP)
		else:
			_camera.look_at_from_position(Vector3(0.0, 0.0, d), Vector3.ZERO, Vector3.UP)
		for _i in 8:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, shot[0]])
		print("SHOT ", shot[0])
	await _ships()
	get_tree().quit()


func _ships() -> void:
	for body in _bodies:
		_bodies[body].visible = false
	var sun_dir := Vector3(0.6, 0.5, 0.6).normalized()
	_sun.look_at_from_position(Vector3.ZERO, -sun_dir, Vector3.UP)
	_camera.near = 0.1
	var rock := SetPieces.rock(190.0, Vector3(1.45, 0.95, 1.1), 2058)
	add_child(rock)
	for shot in [["rock", 700.0], ["rock-close", 330.0]]:
		_camera.look_at_from_position(Vector3(shot[1] * 0.7, shot[1] * 0.2, shot[1] * 0.7), Vector3.ZERO, Vector3.UP)
		for _i in 6:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, shot[0]])
	rock.queue_free()
	var lineup := [["player", data.balance["start"]["ship"], "", "Second Wind", true]]
	lineup.append(["refit-outer", "mule", "", "Long Way Round", true, {"cargo.0": "tank_l", "cargo.1": "hab_extended", "tank.0": "tank_l", "drive.0": "pathfinder_mk3", "radiator.0": "radiator_array", "radiator.1": "radiator_array"}])
	lineup.append(["refit-prospector", "mule", "", "Dirt Under the Nails", true, {"cargo.0": "lander_bay", "cargo.1": "mining_rig", "tank.0": "tank_l"}])
	for id in data.npcs["fleets"]:
		var f: Dictionary = data.npcs["fleets"][id]
		lineup.append([id, f["hull"], f["operator"], f["names"][0], false])
	for entry in lineup:
		var hull: Dictionary = data.ships[entry[1]]
		var ship := {"hull": entry[1], "modules": hull["modules"].duplicate(), "cargo": {}, "fuel_t": 0.0, "name": entry[3]}
		if entry.size() > 5:
			ship["modules"].merge(entry[5], true)
		var model := Models.ship(ship, data, Livery.for_ship(data, entry[2], entry[3], entry[4]))
		var node: Node3D = model["node"]
		add_child(node)
		var plume := node.find_child("DrivePlume", true, false)
		if plume:
			plume.visible = false
		# Rolled to the Sun as in transit: wings square on, radiators edge-on, dish
		# on a target up and ahead.
		node.basis = ShipRig.roll_to_sun(Vector3.FORWARD, sun_dir)
		ShipRig.aim(model["rig"], node.basis, sun_dir, Vector3(0.5, 0.4, -1.0), -1.0)
		var half: float = float(model["length"]) * 0.5
		var views := {
			"": [Vector3(half * 1.7, half * 0.6, -half * 0.5), Vector3(0, 0, -half * 0.05)],
			"-nose": [Vector3(10.0, 4.0, -half - 9.0), Vector3(0, 0, -half + 5.0)],
			"-drive": [Vector3(-11.0, 5.0, half + 6.0), Vector3(0, 0, half - 6.0)],
		}
		for v in views:
			_camera.look_at_from_position(views[v][0], views[v][1], Vector3.UP)
			for _i in 4:
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png("%s/ship-%s%s.png" % [dir, entry[0], v])
		print("SHOT ship %s  %.0f m long, %.0f m radius" % [entry[0], model["length"], model["radius"]])
		node.queue_free()
