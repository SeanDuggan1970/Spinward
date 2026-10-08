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
	# A gentle bloom: bright limbs, beacons and exhausts bleed a little, as through a lens.
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_strength = 1.0
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 0.95
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
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
		if key in ["shader", "atmosphere"]:
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
	var pole := pole_basis(float(b["pole_ra_deg"]), float(b["pole_dec_deg"])) if b.has("pole_ra_deg") else Basis.IDENTITY
	# Fast-spinning giants bulge: Saturn is a tenth wider than it is tall.
	mi.basis = pole * Basis.from_scale(Vector3(1.0, float(b.get("flattening", 1.0)), 1.0))
	if look.has("atmosphere"):
		var air: Dictionary = look["atmosphere"]
		var shell := MeshInstance3D.new()
		shell.name = "Atmosphere"
		var ss := SphereMesh.new()
		ss.radius = radius * (1.0 + float(air.get("thickness", 0.02)))
		ss.height = ss.radius * 2.0
		ss.radial_segments = 64
		ss.rings = 32
		shell.mesh = ss
		var am := ShaderMaterial.new()
		am.shader = load("res://view/shaders/atmosphere.gdshader")
		am.set_shader_parameter("colour", Color(String(air.get("colour", "#6aa2ff"))))
		am.set_shader_parameter("strength", float(air.get("strength", 0.8)))
		shell.material_override = am
		shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.add_child(shell)
	if float(look.get("rings", 0.0)) > 0.0:
		var ring := MeshInstance3D.new()
		ring.name = "Rings"
		var plane := PlaneMesh.new()
		plane.size = Vector2(4.7, 4.7)
		ring.mesh = plane
		var rm := ShaderMaterial.new()
		rm.shader = load("res://view/shaders/rings.gdshader")
		ring.material_override = rm
		ring.scale = Vector3.ONE * radius
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.add_child(ring)
		(mi.material_override as ShaderMaterial).set_shader_parameter("ring_shadow", 1.0)
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
	var rings := mesh.get_node_or_null("Rings") as MeshInstance3D
	if rings:
		(rings.material_override as ShaderMaterial).set_shader_parameter("sun_dir", sun_dir)
	var air := mesh.get_node_or_null("Atmosphere") as MeshInstance3D
	if air:
		(air.material_override as ShaderMaterial).set_shader_parameter("sun_dir", sun_dir)
	var day := float(m.get_meta("day_s", 86164.1))
	if day != 0.0:
		# The phase is arbitrary (no real geography to line up).
		m.set_shader_parameter("spin", fposmod(t / day, 1.0) * TAU)


## How far away a body is, for the aerial-perspective veil: none within a thousand
## km, rising with the log of distance to about a third by a tenth of an AU.
static func set_distance(mesh: MeshInstance3D, metres: float) -> void:
	var m := mesh.material_override as ShaderMaterial
	if m:
		m.set_shader_parameter("veil", clampf((log(maxf(metres, 1.0)) / log(10.0) - 6.0) / 4.0, 0.0, 1.0) * 0.38)


## Light thrown back by the biggest world in view onto whatever is near the camera:
## {dir (from the camera toward the world), colour, energy}. Its lit fraction as seen
## from here sets how much; a giant filling the sky lights you warmly from that side.
static func planetshine(data, seen: Array, sun_dir: Vector3) -> Dictionary:
	var best := {}
	var best_ang := 0.0
	for entry in seen:
		var ang := float(entry[2])
		if ang > best_ang:
			best_ang = ang
			best = {"body": entry[0], "dir": entry[1]}
	if best.is_empty() or best_ang < deg_to_rad(0.5):
		return {}
	var look: Dictionary = data.bodies[best["body"]].get("look", {})
	var colour := Color(String(look.get("colour_a", look.get("highland_colour", "#c8c4bc"))))
	var dir: Vector3 = best["dir"]
	var lit := 0.5 + 0.5 * sun_dir.dot(-dir)
	var size := clampf(best_ang / deg_to_rad(20.0), 0.0, 1.0)
	return {"dir": dir, "colour": colour, "energy": 0.55 * pow(size, 0.8) * lit}


## A planetshine light (see planetshine()) for a scene; update it each frame or once.
static func shine_light() -> DirectionalLight3D:
	var l := DirectionalLight3D.new()
	l.name = "Planetshine"
	l.shadow_enabled = false
	l.light_energy = 0.0
	return l


static func aim_shine(light: DirectionalLight3D, shine: Dictionary) -> void:
	if shine.is_empty():
		light.light_energy = 0.0
		return
	var dir: Vector3 = shine["dir"]
	light.light_color = shine["colour"]
	light.light_energy = float(shine["energy"])
	light.look_at_from_position(Vector3.ZERO, -dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT)


## Sunlit dust drifting by the camera: a few hundred motes in a box that moves with
## it, so near and far read apart when the view turns.
static func dust(extent: float = 40.0) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 220
	p.lifetime = 14.0
	p.preprocess = 14.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3.ONE * extent
	p.direction = Vector3(0.3, 0.1, 1.0)
	p.spread = 180.0
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.3
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.4
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 0.06)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(0.9, 0.86, 0.78, 0.5)
	m.vertex_color_use_as_albedo = false
	q.material = m
	p.mesh = q
	# Fade in and out over each mote's life, so none pops.
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.add_point(0.2, Color(1, 1, 1, 1))
	fade.add_point(0.8, Color(1, 1, 1, 1))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	return p


## The shadow one body casts on another: `occluder_at` and `radius` in the scene
## where `mesh` is drawn (bodies on the sky shell each have their own scale).
static func set_occluder(mesh: MeshInstance3D, occluder_at: Vector3, radius: float) -> void:
	var m := mesh.material_override as ShaderMaterial
	if m:
		m.set_shader_parameter("occluder", Vector4(occluder_at.x, occluder_at.y, occluder_at.z, radius))


## Ships and stations in this scene: the Sun's direction and the body whose shadow
## they can be in (radius 0 for none). Every 3D scene sets it, or clears it.
static func set_eclipse(sun_dir: Vector3, occluder_at: Vector3 = Vector3.ZERO, radius: float = 0.0) -> void:
	RenderingServer.global_shader_parameter_set("sw_sun", sun_dir.normalized())
	RenderingServer.global_shader_parameter_set("sw_occluder", Vector4(occluder_at.x, occluder_at.y, occluder_at.z, radius))


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


# --- What is on a body: plumes and elevators ------------------------------------------

## Dress a body's mesh (from body_mesh) with what data/bodies.json puts on it: plumes
## (Enceladus' tiger stripes, Io's Pele, Triton's geysers) and structures (space
## elevators). Sizes are true to the body. `to_viewer` is the world direction from the
## body towards the camera, so "limb" sites stand where they show best, against
## space; `sun_dir` (world, towards the Sun) lights the plumes; `progress`
## {project: 0..1} grows structures still being built (absent means finished).
static func dress_body(mesh: MeshInstance3D, data, body: String, to_viewer: Vector3, sun_dir: Vector3, progress: Dictionary = {}, hint: Vector3 = Vector3.UP) -> void:
	var b: Dictionary = data.bodies[body]
	if not (b.has("plumes") or b.has("structures")):
		return
	var radius := (mesh.mesh as SphereMesh).radius
	var view_local := (mesh.basis.inverse() * to_viewer).normalized()
	var hint_local := (mesh.basis.inverse() * hint).normalized()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(body)
	for spec in b.get("plumes", []):
		_plume(mesh, spec, radius, view_local, hint_local, sun_dir, rng)
	for spec in b.get("structures", []):
		var p := float(progress.get(spec.get("project", ""), 1.0)) if spec.has("project") else 1.0
		if p <= 0.0:
			continue
		match spec.get("kind", ""):
			"elevator":
				_elevator(mesh, spec, radius, view_local, hint_local, p, rng)
			"orbital_ring":
				_orbital_ring(mesh, spec, radius, p)


## A point on the unit sphere (mesh-local, +Y the pole) for a site: lat/lon in degrees,
## or lon "limb": just on the near side of the limb as seen from the viewer, on the
## side nearer `hint_local`.
static func _site(spec: Dictionary, view_local: Vector3, hint_local: Vector3, near_side: float = 0.12) -> Vector3:
	var lat := deg_to_rad(float(spec.get("lat", 0.0)))
	var l = spec.get("lon", 0.0)
	if l is String and l == "limb":
		var a := cos(lat) * Vector2(view_local.x, view_local.z).length()
		var best := Vector3(cos(lat), sin(lat), 0.0)
		if a > 1e-4:
			var c := clampf((near_side - sin(lat) * view_local.y) / a, -1.0, 1.0)
			var best_dot := -INF
			for sgn in [1.0, -1.0]:
				var lon: float = atan2(view_local.z, view_local.x) + acos(c) * sgn
				var p := Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon))
				if p.dot(hint_local) > best_dot:
					best_dot = p.dot(hint_local)
					best = p
		return best
	var lon := deg_to_rad(float(l))
	return Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon))


## A basis whose +Y is `up`.
static func _up_basis(up: Vector3) -> Basis:
	var y := up.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT).normalized()
	return Basis(x, y, x.cross(y).normalized())


## `dir` tilted by `angle` towards a random side.
static func _tilt(dir: Vector3, angle: float, rng: RandomNumberGenerator) -> Vector3:
	var side := _up_basis(dir).x.rotated(dir.normalized(), rng.randf() * TAU)
	return dir.rotated(side, angle).normalized()


static func _glow(colour: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.emission_enabled = true
	m.emission = colour
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


static func _ball(radius: float, material: Material, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 12
	s.rings = 6
	mi.mesh = s
	mi.material_override = material
	mi.position = at
	return mi


static func _plume(mesh: MeshInstance3D, spec: Dictionary, radius: float, view_local: Vector3, hint_local: Vector3, sun_dir: Vector3, rng: RandomNumberGenerator) -> void:
	var kind: String = spec.get("kind", "jets")
	var centre := _site(spec, view_local, hint_local)
	var height := float(spec.get("height_r", 0.2)) * radius
	var width := float(spec.get("width_r", 0.05)) * radius
	var colour := Color(String(spec.get("colour", "#e4f0ff")))
	if kind == "geyser":
		# Triton's: dark columns a few km tall, then blown sideways into long streaks.
		var dark := StandardMaterial3D.new()
		dark.albedo_color = Color(colour, 0.55)
		dark.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dark.cull_mode = BaseMaterial3D.CULL_DISABLED
		var streak := dark.duplicate() as StandardMaterial3D
		streak.albedo_color = Color(colour, 0.28)
		for i in int(spec.get("jets", 1)):
			var at := _tilt(centre, rng.randf() * deg_to_rad(float(spec.get("spread_deg", 0.0))), rng)
			var holder := Node3D.new()
			holder.position = at * radius
			holder.basis = _up_basis(at)
			var col := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = width
			cm.bottom_radius = width * 0.6
			cm.height = height
			col.mesh = cm
			col.material_override = dark
			col.position = Vector3(0, height * 0.5, 0)
			holder.add_child(col)
			var trail := MeshInstance3D.new()
			var tm := BoxMesh.new()
			var length := float(spec.get("trail_r", 0.1)) * radius * rng.randf_range(0.6, 1.0)
			tm.size = Vector3(length, height * 0.35, width * 3.0)
			trail.mesh = tm
			trail.material_override = streak
			trail.position = Vector3(length * 0.5, height * 0.9, 0)
			holder.add_child(trail)
			mesh.add_child(holder)
		return
	var mat := ShaderMaterial.new()
	mat.shader = load("res://view/shaders/plume.gdshader")
	mat.set_shader_parameter("colour", colour)
	mat.set_shader_parameter("sun_dir", sun_dir)
	mat.set_shader_parameter("umbrella", 1.0 if kind == "umbrella" else 0.0)
	mat.set_shader_parameter("seed", rng.randf() * 50.0)
	var jets := int(spec.get("jets", 1)) if kind == "jets" else 1
	# Many jets overlap; each carries a share of the plume's light.
	mat.set_shader_parameter("brightness", float(spec.get("brightness", 1.0)) * (0.5 if jets == 1 else clampf(1.2 / sqrt(float(jets)), 0.1, 0.5)))
	for i in jets:
		var at := centre
		if spec.has("spread_deg"):
			at = _tilt(centre, sqrt(rng.randf()) * deg_to_rad(float(spec["spread_deg"])), rng)
		var up := _tilt(at, rng.randf() * deg_to_rad(9.0), rng) if kind == "jets" else at
		var h := height * (rng.randf_range(0.55, 1.0) if jets > 1 else 1.0)
		var holder := Node3D.new()
		holder.position = at * radius * 0.995
		holder.basis = _up_basis(up)
		var cone := CylinderMesh.new()
		cone.top_radius = 1.0
		cone.bottom_radius = 0.12 if kind == "umbrella" else 0.18
		cone.height = 2.0
		cone.cap_top = false
		cone.cap_bottom = false
		cone.radial_segments = 24
		cone.rings = 6
		var mi := MeshInstance3D.new()
		mi.mesh = cone
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.scale = Vector3(width, h * 0.5, width)
		mi.position = Vector3(0, h * 0.5, 0)
		holder.add_child(mi)
		mesh.add_child(holder)


## A space elevator: a ribbon up from the equator through the synchronous anchor to a
## counterweight. Still being built (p < 1), it is let down from the anchor while the
## counterweight climbs out, and the spool tip is lit; finished, climbers ride it.
static func _elevator(mesh: MeshInstance3D, spec: Dictionary, radius: float, view_local: Vector3, hint_local: Vector3, p: float, rng: RandomNumberGenerator) -> void:
	var at := _site({"lat": 0.0, "lon": spec.get("lon", "limb")}, view_local, hint_local, 0.2)
	var top := float(spec.get("top_r", 3.0))
	var cw := float(spec.get("counter_r", top * 1.4))
	var low := 1.0
	var high := cw
	if p < 1.0:
		low = top - (top - 1.0) * clampf((p - 1.0 / 3.0) * 3.0, 0.0, 1.0)
		high = top + (cw - top) * clampf(p * 1.5, 0.08, 1.0)
	var holder := Node3D.new()
	holder.basis = _up_basis(at)
	mesh.add_child(holder)
	var ribbon := StandardMaterial3D.new()
	ribbon.albedo_color = Color("d8d2c4")
	ribbon.emission_enabled = true
	ribbon.emission = Color("d8d2c4")
	ribbon.emission_energy_multiplier = 0.6
	# A real ribbon is a metre wide; drawn at least a pixel or so wide from where it is
	# seen, tapered as the real ones are: widest at the anchor, where it carries most.
	var w := maxf(radius * 0.0025, mesh.position.length() * 0.0022)
	var widths := {1.0: w * 0.35, top: w * 0.8, cw: w * 0.5}
	var spans := []
	if low < top:
		spans.append([low, minf(top, high)])
	if high > top:
		spans.append([maxf(top, low), high])
	for sp in spans:
		var a := float(sp[0])
		var b := float(sp[1])
		var seg := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.radial_segments = 6
		cm.rings = 1
		cm.height = radius * (b - a)
		cm.bottom_radius = _ribbon_width(widths, a, top, cw) * 0.5
		cm.top_radius = _ribbon_width(widths, b, top, cw) * 0.5
		seg.mesh = cm
		seg.material_override = ribbon
		seg.position = Vector3(0, radius * (a + b) * 0.5, 0)
		holder.add_child(seg)
	# The anchor: a stacked station threaded on the ribbon, its modules lit.
	var block := radius * 0.012
	for k in 3:
		var mod := MeshInstance3D.new()
		var mm := CylinderMesh.new()
		mm.top_radius = block * (1.0 if k != 1 else 0.75)
		mm.bottom_radius = mm.top_radius
		mm.height = block * 1.6
		mm.radial_segments = 10
		mod.mesh = mm
		mod.material_override = _glow(Color("f0a030") if k != 1 else Color("e8e0d0"), 1.6)
		mod.position = Vector3(0, radius * top + block * 1.7 * float(k - 1), 0)
		holder.add_child(mod)
	# The counterweight: a lumpy mass of rock and slag, with a warning light.
	var lump := radius * 0.018
	for k in 3:
		var off := Vector3(lump * 0.6 * float(k - 1), lump * (0.3 if k == 1 else -0.2), lump * (0.4 if k == 2 else -0.3))
		holder.add_child(_ball(lump * (1.0 if k == 1 else 0.7), _glow(Color("c8c0b0"), 0.8), Vector3(0, radius * high, 0) + off))
	if p >= 1.0:
		holder.add_child(_ball(lump * 0.25, _glow(Color("ff3a2a"), 3.0), Vector3(0, radius * high + lump * 1.3, 0)))
	if p < 1.0 and low > 1.0:
		holder.add_child(_ball(radius * 0.012, _glow(Color("40ff60"), 4.0), Vector3(0, radius * low, 0)))
	if p >= 1.0:
		for i in int(spec.get("climbers", 3)):
			holder.add_child(_ball(radius * 0.008, _glow(Color("fff0c0"), 4.0), Vector3(0, radius * lerpf(1.05, top, rng.randf()), 0)))
		holder.add_child(_ball(radius * 0.01, _glow(Color("ff3a2a"), 3.0), Vector3(0, radius * 1.002, 0)))


## The ribbon's drawn width at x body radii out: from the foot's to the anchor's, then
## to the tip's.
static func _ribbon_width(widths: Dictionary, x: float, top: float, cw: float) -> float:
	if x <= top:
		return lerpf(float(widths[1.0]), float(widths[top]), clampf((x - 1.0) / maxf(top - 1.0, 1e-6), 0.0, 1.0))
	return lerpf(float(widths[top]), float(widths[cw]), clampf((x - top) / maxf(cw - top, 1e-6), 0.0, 1.0))


## An orbital ring round the equator: a bright thread at radius_r, built in arcs
## (the first arc, then closed), then tethers let down to the ground with lit stations
## where they land. Drawn at least a pixel or so thick from where it is seen.
static func _orbital_ring(mesh: MeshInstance3D, spec: Dictionary, radius: float, p: float) -> void:
	var rr := float(spec.get("radius_r", 1.05)) * radius
	# Tens of metres thick, but drawn a pixel or so wide from wherever it is seen: from
	# afar that is the body's distance; skimming the surface, the ring's own.
	var seen_from := maxf(absf(mesh.position.length() - rr), rr * 0.02)
	var w := maxf(radius * 0.00006, seen_from * 0.0035)
	var mat := _glow(Color("e8e2d2"), 1.1)
	var arc := clampf(p * 2.0, 0.08, 1.0) if p < 2.0 / 3.0 else 1.0
	var pieces := 180
	for i in int(ceil(float(pieces) * arc)):
		var a := TAU * (float(i) + 0.5) / float(pieces)
		var seg := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(w, w, 2.0 * rr * sin(PI / float(pieces)) * 1.05)
		seg.mesh = bm
		seg.material_override = mat
		seg.position = Vector3(cos(a), 0.0, sin(a)) * rr
		seg.basis = Basis(Vector3.UP, -a)
		mesh.add_child(seg)
	if arc < 1.0:
		var tip := TAU * arc
		mesh.add_child(_ball(w * 3.0, _glow(Color("40ff60"), 4.0), Vector3(cos(tip), 0.0, sin(tip)) * rr))
	if p >= 2.0 / 3.0:
		var tethers := int(spec.get("tethers", 12))
		var down := clampf((p - 2.0 / 3.0) * 3.0, 0.0, 1.0)
		for k in tethers:
			var a := TAU * float(k) / float(tethers)
			var d := Vector3(cos(a), 0.0, sin(a))
			var length := (rr - radius) * down
			var tether := MeshInstance3D.new()
			var tm := BoxMesh.new()
			tm.size = Vector3(w * 0.6, length, w * 0.6)
			tether.mesh = tm
			tether.material_override = mat
			tether.position = d * (rr - length * 0.5)
			tether.basis = _up_basis(d)
			mesh.add_child(tether)
			mesh.add_child(_ball(w * 1.6, _glow(Color("ffdca0"), 3.0), d * rr))
			if down >= 1.0:
				mesh.add_child(_ball(w * 2.0, _glow(Color("ffdca0"), 2.0), d * radius * 1.001))

