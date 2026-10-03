## Attract screen. A showcase in the spirit of the original Elite's rotating ships:
## each hull in data/ships.json flies in out of the dark, turns slowly under a work
## light while its caption is shown, then burns away. Behind it, Kibo Ring spins
## against Earth's limb, the skyhook turns, work pods circle and freighters cross
## the sky. View-only: the sim is not ticking while this is up.
##
## Space / Enter starts, L loads the quick save, Esc quits.
extends Node3D

signal start_requested(load_save: bool)

const Kit := preload("res://view/flight/kit.gd")
const Models := preload("res://view/flight/models.gd")
const SetPieces := preload("res://view/flight/set_pieces.gd")
const SkyKit := preload("res://view/flight/sky.gd")
const ShipStats := preload("res://sim/ship_stats.gd")
const UI := preload("res://view/ui/ui_kit.gd")

## Seconds per hero ship: fly in, show, burn away.
const ARRIVE := 3.0
const SHOW := 7.0
const LEAVE := 2.0
const HERO_DISTANCE := 58.0

var data
var has_save := false
var clock := 0.0
var camera: Camera3D
var _hulls: Array = []
var _hero_index := -1
var _hero: Node3D
var _hero_plume: Node3D
var _hero_radius := 5.0
var _station: Dictionary
var _earth: MeshInstance3D
var _set_pieces: Array = []
var _blinkers: Array = []
var _pods: Array = []
var _traffic: Array = []
var _overlay: Control


func _init(catalog, save_exists: bool) -> void:
	data = catalog
	has_save = save_exists
	_hulls = data.ships.keys()


func _ready() -> void:
	add_child(SkyKit.environment())
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.5
	add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, Vector3(0.55, -0.35, -0.75), Vector3.UP)
	# A work light near the camera, so the hero ship reads even on its night side.
	var flood := OmniLight3D.new()
	flood.position = Vector3(-30, 25, 10)
	flood.omni_range = 400.0
	flood.light_energy = 1.4
	flood.light_color = Color("ffe8c8")
	add_child(flood)
	# The Sun sits behind the camera, front-lighting the showcase.
	add_child(Kit.sphere(800.0, Kit.glow(Color("fff6e0"), 6.0), Vector3(-0.55, 0.35, 0.75).normalized() * 60000.0))
	# Earth's limb filling the lower right, the Moon high on the left.
	_earth = Kit.sphere(14000.0, SkyKit.body_material("earth"), Vector3(9500.0, -11800.0, -17000.0))
	(_earth.mesh as SphereMesh).radial_segments = 96
	(_earth.mesh as SphereMesh).rings = 48
	add_child(_earth)
	add_child(Kit.sphere(700.0, SkyKit.body_material("moon"), Vector3(-15000.0, 7000.0, -42000.0)))
	# Kibo Ring at three-quarter view, spinning, corridor lights stepping in.
	_station = Models.station(data.places["kibo_ring"]["station"], data.places["kibo_ring"]["name"])
	var holder := Node3D.new()
	holder.position = Vector3(-230.0, 60.0, -760.0)
	holder.rotation = Vector3(0.12, 0.85, 0.0)
	holder.add_child(_station["node"])
	add_child(holder)
	# The skyhook turns far off to the lower right, clear of the title lettering.
	var hook := Node3D.new()
	hook.position = Vector3(1800.0, -2600.0, -6500.0)
	add_child(hook)
	_set_pieces = SetPieces.build(hook, ["skyhook"], {"earth": Vector3(9500.0, -11800.0, -17000.0).normalized()}, _station)
	for i in 3:
		var pod := Models.work_pod(i == 0)
		holder.add_child(pod)
		_pods.append({"node": pod, "r": 70.0 + 35.0 * i, "z": -20.0 + 30.0 * i, "period": 40.0 + 15.0 * i, "phase": i * 2.1})
	# Freighters crossing the background on loops, drives lit.
	var traffic_hulls := ["lunar_tanker", "drone_freighter", "courier"]
	for i in traffic_hulls.size():
		if not data.ships.has(traffic_hulls[i]):
			continue
		var model := Models.ship(_ship_dict(traffic_hulls[i]), data)
		var node: Node3D = model["node"]
		node.add_child(Kit.sphere(2.0, Kit.glow(Color("ffe0a0"), 4.0), Vector3(0, 3.0, 0)))
		add_child(node)
		_traffic.append({"node": node, "from": Vector3(-1800.0 + 500.0 * i, 140.0 - 120.0 * i, -1300.0 - 500.0 * i),
			"to": Vector3(1900.0, 260.0 - 90.0 * i, -900.0 - 650.0 * i), "period": 70.0 + 25.0 * i, "phase": 0.3 * i})
	camera = Camera3D.new()
	camera.fov = 50.0
	camera.far = 200000.0
	camera.near = 0.5
	add_child(camera)
	camera.make_current()
	_overlay = load("res://view/title_overlay.gd").new(self)
	_overlay.theme = UI.make_theme()
	add_child(_overlay)
	_blinkers = Kit.collect_blinkers(self)
	_next_hero()


func _ship_dict(hull: String) -> Dictionary:
	var h: Dictionary = data.ships[hull]
	var ship := {"hull": hull, "modules": h["modules"].duplicate(), "cargo": {}, "fuel_t": 0.0}
	ship["fuel_t"] = ShipStats.fuel_capacity_t(ship, data)
	return ship


func _next_hero() -> void:
	if _hero:
		_hero.queue_free()
	_hero_index = (_hero_index + 1) % _hulls.size()
	var model := Models.ship(_ship_dict(_hulls[_hero_index]), data)
	_hero = model["node"]
	_hero_radius = model["length"] * 0.5
	_hero_plume = _hero.find_child("DrivePlume", true, false)
	add_child(_hero)
	_blinkers = Kit.collect_blinkers(self)
	clock = 0.0


func hero_info() -> Dictionary:
	var hull: String = _hulls[_hero_index]
	var ship := _ship_dict(hull)
	return {
		"name": data.ships[hull]["name"],
		"description": data.ships[hull].get("description", ""),
		"cargo_t": ShipStats.cargo_capacity_t(ship, data),
		"fuel_t": ShipStats.fuel_capacity_t(ship, data),
		"thrust_n": ShipStats.thrust_n(ship, data),
		"mass_t": ShipStats.dry_mass_t(ship, data),
		"showing": clock > ARRIVE * 0.6 and clock < ARRIVE + SHOW + LEAVE * 0.3,
	}


func _process(dt: float) -> void:
	clock += dt
	var t := Time.get_ticks_msec() / 1000.0
	_station["rotor"].rotation.z = t * float(data.places["kibo_ring"]["station"]["spin_rpm"]) * TAU / 60.0
	_earth.rotation.y = t * 0.004
	SetPieces.animate(_set_pieces, t)
	Kit.update_blinkers(_blinkers, t)
	for p in _pods:
		var a: float = p["phase"] + TAU * t / float(p["period"])
		p["node"].position = Vector3(cos(a) * p["r"], sin(a) * p["r"], p["z"])
		p["node"].look_at(p["node"].global_position + Vector3(-sin(a), cos(a), 0.0), Vector3(0, 0, 1))
	for tr in _traffic:
		var f := fposmod(float(tr["phase"]) + t / float(tr["period"]), 1.0)
		var node: Node3D = tr["node"]
		node.position = tr["from"].lerp(tr["to"], f)
		node.look_at(node.position + (tr["from"] - tr["to"]), Vector3.UP)
	_animate_hero(dt)
	# A slow drift, as if the camera ship is holding station by hand.
	camera.position = Vector3(sin(t * 0.13) * 1.5, 4.0 + sin(t * 0.21) * 0.8, 0.0)
	camera.look_at(Vector3(sin(t * 0.07) * 4.0, 0.0, -HERO_DISTANCE), Vector3.UP)


func _animate_hero(_dt: float) -> void:
	var c := clock
	var spin := c * 0.45
	var pos: Vector3
	if c < ARRIVE:
		# Out of the dark, decelerating hard.
		var f := c / ARRIVE
		var e := 1.0 - pow(1.0 - f, 3.0)
		pos = Vector3(lerpf(160.0, 0.0, e), lerpf(40.0, 0.0, e), lerpf(-1400.0, -HERO_DISTANCE, e))
		if _hero_plume:
			_hero_plume.visible = f < 0.85
	elif c < ARRIVE + SHOW:
		pos = Vector3(0, sin(c * 0.8) * 0.6, -HERO_DISTANCE)
		if _hero_plume:
			_hero_plume.visible = false
	elif c < ARRIVE + SHOW + LEAVE:
		# Light the drive and burn away to the right.
		var f := (c - ARRIVE - SHOW) / LEAVE
		pos = Vector3(f * f * 900.0, f * f * 120.0, -HERO_DISTANCE - f * f * 1600.0)
		if _hero_plume:
			_hero_plume.visible = true
	else:
		_next_hero()
		return
	_hero.position = pos
	_hero.rotation = Vector3(0.25 + sin(c * 0.3) * 0.08, spin + PI * 0.75, sin(c * 0.4) * 0.12)


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
