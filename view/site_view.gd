## The view on site: the worlds in the sky from where you are (true angular sizes),
## and for a derelict, the wreck itself tumbling slowly a few hundred metres off.
## View-only; the site screen (station_screen.gd in site mode) sits on top.
extends Node3D

const V := preload("res://sim/v3.gd")
const Kit := preload("res://view/flight/kit.gd")
const SkyKit := preload("res://view/flight/sky.gd")
const Models := preload("res://view/flight/models.gd")
const Livery := preload("res://view/flight/livery.gd")

const SKY_DISTANCE := 60000.0

var sim
var site := ""
var camera: Camera3D
var _wreck: Node3D
var _clock := 0.0
## Camera basis: aimed so the site's world sits low and right, clear of the panels.
var _view := Basis.IDENTITY


func _init(owner_sim) -> void:
	sim = owner_sim
	site = sim.state.location.get("place", "")


func _ready() -> void:
	add_child(SkyKit.environment())
	var eph = sim.ephemeris
	var t: float = sim.state.time_s
	var here: Array = eph.position(site, t)
	var sun_dir := SkyKit.dir_between(eph.position("sun", t), here)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.6
	add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, -sun_dir, Vector3.UP if absf(sun_dir.y) < 0.99 else Vector3.RIGHT)
	var au := V.length(V.sub(here, eph.position("sun", t))) / 1.495978707e11
	add_child(Kit.sphere(SKY_DISTANCE * 0.0047 * 3.0 / maxf(au, 0.3), Kit.glow(Color("fff6e0"), 6.0), sun_dir * SKY_DISTANCE))
	var seen: Array = SkyKit.visible_bodies(sim.data, eph, here, t)
	var focus: Vector3 = (seen[0][1] as Vector3) if not seen.is_empty() else sun_dir
	var up := Vector3.UP if absf(focus.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var left := up.cross(focus).normalized()
	_view = Basis.looking_at((focus + up * 0.35 + left * 0.5).normalized(), up)
	for k in seen.size():
		var shell := SKY_DISTANCE * (0.55 + 0.45 * float(k) / float(maxi(1, seen.size() - 1)))
		var mesh := SkyKit.body_mesh(sim.data, seen[k][0], shell * minf(tan(float(seen[k][2])), 0.97))
		mesh.position = (seen[k][1] as Vector3) * shell
		SkyKit.update_body(mesh, sun_dir, t)
		add_child(mesh)
	if sim.data.sites[site].get("kind", "") == "derelict":
		# Any old hull will do for a wreck: dark, battered, no lights.
		var ship := {"hull": "mule", "modules": sim.data.ships["mule"]["modules"].duplicate(), "cargo": {}, "fuel_t": 0.0, "name": sim.data.sites[site]["name"].trim_prefix("Derelict: ")}
		var livery := Livery.for_ship(sim.data, "Luna Cooperative", ship["name"])
		livery["wear"] = 1.0
		livery["mats"] = Livery._materials(livery)
		var model := Models.ship(ship, sim.data, livery)
		_wreck = model["node"]
		var plume := _wreck.find_child("DrivePlume", true, false)
		if plume:
			plume.visible = false
		_wreck.position = _view * Vector3(34.0, -12.0, -70.0)
		add_child(_wreck)
	if sim.data.sites[site].get("kind", "") == "anomaly":
		# Perfectly black, and the starlight bends round its edge.
		var hole := StandardMaterial3D.new()
		hole.albedo_color = Color.BLACK
		hole.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var centre := _view * Vector3(400.0, -110.0, -900.0)
		add_child(Kit.sphere(120.0, hole, centre))
		var ring := Kit.torus(123.0, 2.2, Kit.glow(Color("dfe8ff"), 2.5), Vector3.ZERO, 96)
		var holder := Node3D.new()
		holder.position = centre
		holder.look_at_from_position(centre, Vector3.ZERO, Vector3.UP)
		holder.add_child(ring)
		add_child(holder)
	camera = Camera3D.new()
	camera.fov = 60.0
	camera.far = SKY_DISTANCE * 3.0
	add_child(camera)
	camera.make_current()


func _process(dt: float) -> void:
	_clock += dt
	if _wreck:
		_wreck.rotation = Vector3(_clock * 0.03, _clock * 0.05, _clock * 0.02)
	# A slow drift, as if holding station by hand.
	camera.basis = _view * Basis(Vector3.UP, sin(_clock * 0.05) * 0.02)
	camera.position = _view * Vector3(sin(_clock * 0.07) * 2.0, cos(_clock * 0.05), 0.0)
