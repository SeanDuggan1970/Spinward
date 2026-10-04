## Shared space backdrop: the starfield, lighting environment and the procedural
## planet and moon surfaces (view/shaders/), used by every 3D scene. Nothing is
## cached in static variables: GPU textures held past renderer shutdown leak at exit.
extends RefCounted



static func starfield() -> ImageTexture:
	var img := Image.create(2048, 1024, false, Image.FORMAT_RGB8)
	img.fill(Color("020306"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 2061
	for i in 5000:
		var b := pow(rng.randf(), 6.0)
		var c := Color(0.55 + b * 0.45, 0.55 + b * 0.45, 0.6 + b * 0.4) * (0.25 + b * 0.75)
		img.set_pixel(rng.randi_range(0, 2047), rng.randi_range(0, 1023), c)
	return ImageTexture.create_from_image(img)


static func environment() -> WorldEnvironment:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := PanoramaSkyMaterial.new()
	sky_mat.panorama = starfield()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("2a3340")
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	return we


const SHADERS := {
	"earth": "res://view/shaders/earth.gdshader",
	"rock": "res://view/shaders/moon.gdshader",
	"gas": "res://view/shaders/gas.gdshader",
	"clouds": "res://view/shaders/clouds.gdshader",
}
## Day lengths (s) for spinning cloud decks; rock and ice worlds keep still.
const DAY_S := {"earth": 86164.1, "jupiter": 35730.0, "saturn": 38018.0, "uranus": -62064.0, "neptune": 57996.0, "venus": -20997360.0, "titan": 1377648.0}


## Procedural surface for a body, picked by data/bodies.json "look.shader": Earth's
## own shader, the cratered rock shader (also icy moons and asteroids), banded gas
## giants, or cloud-wrapped worlds. Look keys become shader uniforms; "*_colour"
## strings are colours. `radius_m` (when known) scales craters to the body.
static func body_material(body: String, look: Dictionary = {}, radius_m: float = 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	var kind: String = "earth" if body == "earth" else String(look.get("shader", "rock"))
	m.shader = load(SHADERS.get(kind, SHADERS["rock"]))
	if kind == "rock" and radius_m > 0.0:
		var km := radius_m / 1000.0
		m.set_shader_parameter("radius_km", km)
		# A small body has no 400 km basins: its biggest craters are a fraction of it.
		m.set_shader_parameter("largest_km", minf(420.0, km * 0.6))
		m.set_shader_parameter("grain_per_radius", maxf(400.0, km * 3.0))
	for key in look:
		if key == "shader":
			continue
		var v = look[key]
		m.set_shader_parameter(key, Color(v) if v is String else v)
	m.set_meta("day_s", DAY_S.get(body, 0.0))
	return m


## A body's mesh at `radius` (scene units): its surface, turned so local +Y is its
## pole, with rings if it has them.
static func body_mesh(data, body: String, radius: float) -> MeshInstance3D:
	var b: Dictionary = data.bodies[body]
	var look: Dictionary = b.get("look", {})
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 64
	sphere.rings = 32
	mi.mesh = sphere
	mi.material_override = body_material(body, look, float(b.get("radius_m", 0.0)))
	if b.has("pole_ra_deg"):
		mi.basis = pole_basis(float(b["pole_ra_deg"]), float(b["pole_dec_deg"]))
	if float(look.get("rings", 0.0)) > 0.0:
		var ring := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(4.6, 4.6)
		ring.mesh = plane
		var rm := ShaderMaterial.new()
		rm.shader = load("res://view/shaders/rings.gdshader")
		ring.material_override = rm
		ring.scale = Vector3.ONE * radius
		mi.add_child(ring)
	return mi


## A basis whose +Y is the pole at ICRF RA/Dec, in Godot's ecliptic-north-up frame.
static func pole_basis(ra_deg: float, dec_deg: float) -> Basis:
	var ra := deg_to_rad(ra_deg)
	var dec := deg_to_rad(dec_deg)
	var eq := [cos(dec) * cos(ra), cos(dec) * sin(ra), sin(dec)]
	var ec := preload("res://sim/ephemeris.gd").equatorial_to_ecliptic(eq)
	var y := Vector3(ec[0], ec[2], -ec[1]).normalized()
	var x := y.cross(Vector3.FORWARD).normalized() if absf(y.dot(Vector3.FORWARD)) < 0.99 else y.cross(Vector3.RIGHT).normalized()
	return Basis(x, y, x.cross(y).normalized()).orthonormalized()


## Keep a body's lighting and rotation current: the Sun's direction (world space,
## from the body towards the Sun) for night sides and limbs, and its spin at time t.
static func update_body(mesh: MeshInstance3D, sun_dir: Vector3, t: float) -> void:
	var m := mesh.material_override as ShaderMaterial
	if m == null:
		return
	m.set_shader_parameter("sun_dir", sun_dir)
	var day := float(m.get_meta("day_s", 86164.1))
	if day != 0.0:
		# The phase is arbitrary (no real geography to line up).
		m.set_shader_parameter("spin", fposmod(t / day, 1.0) * TAU)


## Bodies worth drawing from `here` (sim position): anything at least `min_deg`
## across. [[body, direction (Godot), angular radius (rad), distance (m)], ...],
## nearest first.
static func visible_bodies(data, eph, here: Array, t: float, min_deg: float = 0.02) -> Array:
	var out := []
	for body in data.bodies:
		if body == "sun":
			continue
		var p: Array = eph.position(body, t)
		var d: float = sqrt(pow(p[0] - here[0], 2) + pow(p[1] - here[1], 2) + pow(p[2] - here[2], 2))
		var ang := asin(clampf(float(data.bodies[body]["radius_m"]) / maxf(d, 1.0), 0.0, 1.0))
		if rad_to_deg(ang) * 2.0 >= min_deg:
			out.append([body, dir_between(p, here), ang, d])
	out.sort_custom(func(a, b): return a[3] < b[3])
	return out


## Direction between two 64-bit sim positions as a Godot vector, ecliptic north up.
static func dir_between(to: Array, from: Array) -> Vector3:
	var d := [to[0] - from[0], to[1] - from[1], to[2] - from[2]]
	return Vector3(d[0], d[2], -d[1]).normalized()
