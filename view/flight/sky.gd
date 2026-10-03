## Shared space backdrop: the starfield, lighting environment and placeholder
## planet materials, used by the docking scene and the transit cockpit. Nothing is
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


static func body_material(body: String) -> StandardMaterial3D:
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


## Direction between two 64-bit sim positions as a Godot vector, ecliptic north up.
static func dir_between(to: Array, from: Array) -> Vector3:
	var d := [to[0] - from[0], to[1] - from[1], to[2] - from[2]]
	return Vector3(d[0], d[2], -d[1]).normalized()
