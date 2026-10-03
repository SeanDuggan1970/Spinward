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


## Procedural surface for a body: view/shaders/earth.gdshader for Earth, and the
## cratered airless-body shader for everything else, tuned from data/bodies.json
## "look" when present.
static func body_material(body: String, look: Dictionary = {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	if body == "earth":
		m.shader = load("res://view/shaders/earth.gdshader")
	else:
		m.shader = load("res://view/shaders/moon.gdshader")
	for key in look:
		var v = look[key]
		m.set_shader_parameter(key, Color(v) if v is String else v)
	return m


## Keep a body's lighting and rotation current: the Sun's direction (world space,
## from the body towards the Sun) for Earth's night side, and its spin at game time t.
static func update_body(mesh: MeshInstance3D, sun_dir: Vector3, t: float) -> void:
	var m := mesh.material_override as ShaderMaterial
	if m == null:
		return
	m.set_shader_parameter("sun_dir", sun_dir)
	# Sidereal day; the phase is arbitrary (no real geography to line up).
	m.set_shader_parameter("spin", fposmod(t / 86164.1, 1.0) * TAU)


## Direction between two 64-bit sim positions as a Godot vector, ecliptic north up.
static func dir_between(to: Array, from: Array) -> Vector3:
	var d := [to[0] - from[0], to[1] - from[1], to[2] - from[2]]
	return Vector3(d[0], d[2], -d[1]).normalized()
