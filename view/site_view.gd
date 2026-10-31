## The view on site: the worlds in the sky from where you are (true angular sizes),
## and for a derelict, the wreck itself tumbling slowly a hundred metres off in the site screen's window,
## under your floodlights (a cutter sparking on it while you work); for a
## berg in transit, the berg and its pusher, still firing, with the crew's cabin on its
## frame (you have matched its course to be here).
## View-only; the site screen (station_screen.gd in site mode) sits on top.
extends Node3D

const V := preload("res://sim/v3.gd")
const Kit := preload("res://view/flight/kit.gd")
const SkyKit := preload("res://view/flight/sky.gd")
const Models := preload("res://view/flight/models.gd")
const Livery := preload("res://view/flight/livery.gd")
const SetPieces := preload("res://view/flight/set_pieces.gd")
const SatelliteModel := preload("res://view/flight/satellite_model.gd")

const SKY_DISTANCE := 60000.0
## Where the site screen leaves its window onto this view (station_screen.gd
## SITE_WINDOW_RATIO), in normalised screen x: a little right of centre.
const WINDOW_NDC := Vector2(0.24, -0.05)

var sim
var site := ""
var camera: Camera3D
var _wreck: Node3D
## The cutter at work on the wreck (shown while a job runs): a spark and its light.
var _spark: Node3D
var _spark_light: OmniLight3D
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
		_add_wreck()
	if sim.data.sites[site].get("kind", "") == "berg":
		SetPieces._ice_berg(self, _view * Vector3(150.0, -40.0, -520.0), 2.2, false, true, true)
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
	if _spark:
		var work: Dictionary = sim.state.sites.get("work", {})
		_spark.visible = work.get("site", "") == site
		# The cutter flickers, and now and then stops while the net is moved.
		var on := sin(_clock * 0.6) > -0.6
		var flick := 0.55 + 0.45 * sin(_clock * 37.0) * sin(_clock * 23.0 + 1.3)
		_spark_light.light_energy = (3.0 * flick) if on else 0.0
		(_spark.get_child(0) as Node3D).visible = on
	# A slow drift, as if holding station by hand.
	camera.basis = _view * Basis(Vector3.UP, sin(_clock * 0.05) * 0.02)
	camera.position = _view * Vector3(sin(_clock * 0.07) * 2.0, cos(_clock * 0.05), 0.0)


## A derelict a little way off, in the site screen's window: a dead hull, dark and
## battered, or (model "satellite") a small probe with its wings folded, closer in.
## Your ship's floodlights are on it, and while you work a cutter sparks on its hull.
func _add_wreck() -> void:
	var info: Dictionary = sim.data.sites[site]
	var label: String = info["name"].trim_prefix("Derelict: ").trim_prefix("Dead probe: ")
	var distance := 110.0
	var model: Node3D
	if info.get("model", "ship") == "satellite":
		var sat := SatelliteModel.build(label)
		SatelliteModel.unfold(sat, 0.0)
		model = sat["node"]
		distance = 12.0
	else:
		# Any old hull will do for a wreck: dark, battered, no lights.
		var ship := {"hull": "mule", "modules": sim.data.ships["mule"]["modules"].duplicate(), "cargo": {}, "fuel_t": 0.0, "name": label}
		var livery := Livery.for_ship(sim.data, "Luna Cooperative", label)
		livery["wear"] = 1.0
		livery["mats"] = Livery._materials(livery)
		model = Models.ship(ship, sim.data, livery)["node"]
		var plume := model.find_child("DrivePlume", true, false)
		if plume:
			plume.visible = false
	# Held by its middle, so it tumbles about it.
	_wreck = Node3D.new()
	add_child(_wreck)
	_wreck.add_child(model)
	var box := _bounds(model)
	model.position = -box.get_center()
	var size := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(16, 9)
	var half := tan(deg_to_rad(30.0))
	var local := Vector3(WINDOW_NDC.x * half * size.x / maxf(size.y, 1.0), WINDOW_NDC.y * half, -1.0) * distance
	_wreck.position = _view * local
	# The ship's floodlights, from just beside the camera.
	var flood := SpotLight3D.new()
	flood.spot_range = distance * 2.0
	flood.spot_angle = rad_to_deg(atan(box.size.length() * 0.6 / distance)) + 4.0
	flood.light_energy = 3.0
	flood.light_color = Color("fff1d8")
	add_child(flood)
	flood.look_at_from_position(_view * Vector3(1.5, 1.0, 0.0), _wreck.position, _view.y)
	# The cutter (or work light): on top of the hull, where the work is.
	_spark = Node3D.new()
	_spark.position = Vector3(0.0, box.size.y * 0.5, box.size.z * 0.15)
	_spark.add_child(Kit.sphere(maxf(0.08, distance * 0.002), Kit.glow(Color("cfe6ff"), 8.0)))
	_spark_light = OmniLight3D.new()
	_spark_light.light_color = Color("cfe6ff")
	_spark_light.omni_range = maxf(4.0, box.size.length() * 0.3)
	_spark.add_child(_spark_light)
	_spark.visible = false
	_wreck.add_child(_spark)


## The bounds of every mesh under a node, in that node's own frame.
static func _bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var b: AABB = (root.global_transform.affine_inverse() * mi.global_transform) * mi.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box
