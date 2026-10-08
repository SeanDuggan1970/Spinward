## Megastructure set pieces seen from a station's approach. They are view-only and
## built at true scale (kilometres). They are arranged in the sky beyond the station,
## where an approaching pilot is looking (the approach runs down -Z toward the port),
## and oriented by the real directions to the Sun, Earth and Moon: the Luna Line
## hangs toward the Moon and the power satellites face the Sun.
##
## Features (from data/places.json "features"):
##   skyhook          Kibo Ring's spinning launch tether
##   power_arrays     Clarke Exchange's solar power satellites, beaming to Earth
##   elevator         the Luna Line lunar elevator ribbon through Halo Depot
##   bernal_frame     Island One, a Bernal sphere under construction by The Kernel
##   telescope_array  Farside Array's chain of megatelescope mirrors at L2
##   captured_rock    Trojan Yards' captured near-Earth asteroid, harnessed and mined
##   oneill_pair      the Concord Pair over Ceres: two 32 km O'Neill cylinders, built in stages
##   mind_works       Landauer Deep: the minds' cold core, radiators and a second core going up
##   starshade        Valhalla's flower-shaped starshade, lined up with a distant telescope
##   sail_yard        Clarke Exchange's sail yard, and the Lightfoot sails once it is built
##   stanford_torus   the Tsiolkovsky Wheel going up beside Trojan Yards: a 1.8 km Stanford torus
## Solid ones register colliders on the parent (meta "colliders": {spheres, tori}) so
## a pilot who flies into one hits it.
extends RefCounted

const Kit := preload("res://view/flight/kit.gd")
const ClimberModel := preload("res://view/flight/climber_model.gd")
const SkyKit := preload("res://view/flight/sky.gd")


## Builds the features under `parent`; returns animation entries for animate().
## progress: {feature: 0..1} from megaprojects; set pieces tied to a project grow with it.
static func build(parent: Node3D, features: Array, dirs: Dictionary, station: Dictionary, progress: Dictionary = {}) -> Array:
	var anims := []
	for f in features:
		match f:
			"skyhook":
				anims.append_array(_skyhook(parent, dirs))
			"power_arrays":
				anims.append_array(_power_arrays(parent, dirs))
			"elevator":
				anims.append_array(_elevator(parent, dirs, station, float(progress.get("elevator", 0.0))))
			"bernal_frame":
				anims.append_array(_bernal(parent, dirs, float(progress.get("bernal_frame", 0.0))))
			"kalpana_two":
				anims.append_array(_kalpana_two(parent, station, float(progress.get("kalpana_two", 0.0))))
			"telescope_array":
				anims.append_array(_telescopes(parent, dirs))
			"captured_rock":
				anims.append_array(_captured_rock(parent, station))
			"oneill_pair":
				anims.append_array(_oneill_pair(parent, dirs, float(progress.get("oneill_pair", 0.0))))
			"mind_works":
				anims.append_array(_mind_works(parent, dirs, float(progress.get("mind_works", 0.0))))
			"starshade":
				anims.append_array(_starshade(parent))
			"sail_yard":
				anims.append_array(_sail_yard(parent, dirs, float(progress.get("sail_yard", 0.0))))
			"stanford_torus":
				anims.append_array(_stanford_torus(parent, dirs, float(progress.get("stanford_torus", 0.0))))
	return anims


## Register something solid with the flight scene, if it is listening.
static func _solid_sphere(parent: Node3D, at: Vector3, r: float) -> void:
	if parent.has_meta("colliders"):
		parent.get_meta("colliders")["spheres"].append({"pos": at, "r": r})


## A ring about its node's local Z: `R` to the tube's centre, tube radius `r`.
static func _solid_torus(parent: Node3D, xform: Transform3D, ring_r: float, tube_r: float) -> void:
	if parent.has_meta("colliders"):
		parent.get_meta("colliders")["tori"].append({"xform": xform, "R": ring_r, "r": tube_r})


static func animate(anims: Array, t: float) -> void:
	for a in anims:
		match a["kind"]:
			"spin":
				a["node"].rotation = Vector3(0, 0, t * float(a["rate"]))
			"climbers":
				for i in a["nodes"].size():
					var f := fposmod(float(a["phases"][i]) + t * float(a["speeds"][i]) / float(a["length"]), 1.0)
					a["nodes"][i].position = a["start"] + a["dir"] * float(a["length"]) * f
			"spin_y":
				a["node"].rotation = Vector3(0, t * float(a["rate"]), 0)
			"flicker":
				for n in a["nodes"]:
					n.visible = fposmod(t * 7.3 + float(n.get_meta("seed")), 1.0) < 0.25


# --- helpers ------------------------------------------------------------------

static func _mat(colour: Color, metallic: float = 0.2, rough: float = 0.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.metallic = metallic
	m.roughness = rough
	return m


## Self-lit material so huge structures read against black space even on their night side.
static func _lit(colour: Color, glow_energy: float, metallic: float = 0.3, rough: float = 0.5) -> StandardMaterial3D:
	var m := _mat(colour, metallic, rough)
	m.emission_enabled = true
	m.emission = colour
	m.emission_energy_multiplier = glow_energy
	return m


static func _haze(colour: Color, alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(colour, alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## A node whose local -Z points along `forward` (and +Y as close to `up` as possible).
static func _facing(forward: Vector3, at: Vector3, up: Vector3 = Vector3.UP) -> Node3D:
	var n := Node3D.new()
	var u := up if absf(forward.normalized().dot(up.normalized())) < 0.98 else Vector3.RIGHT
	n.transform = Transform3D(Basis.looking_at(forward, u), at)
	return n


static func _side(dirs: Dictionary) -> Vector3:
	# A direction across the sky that is neither toward Earth nor the station axis.
	var e: Vector3 = dirs.get("earth", Vector3.DOWN)
	var s := e.cross(Vector3(0, 0, 1))
	return (s if s.length() > 0.1 else e.cross(Vector3.UP)).normalized()


# --- Kibo skyhook ---------------------------------------------------------------

static func _skyhook(parent: Node3D, dirs: Dictionary) -> Array:
	var earth: Vector3 = dirs.get("earth", Vector3.DOWN)
	var side := _side(dirs)
	# The tether turns in the plane containing Earth, so each end dips toward the
	# atmosphere to catch payloads lofted by suborbital launchers.
	var axis := earth.cross(side).normalized()
	var pivot := _facing(axis, Vector3(2200.0, 1100.0, -4800.0))
	parent.add_child(pivot)
	var rotor := Node3D.new()
	pivot.add_child(rotor)
	var length := 6000.0
	rotor.add_child(Kit.box(Vector3(length, 14.0, 14.0), _lit(Color("c9c4b6"), 0.45, 0.5, 0.4)))
	# Central facility: momentum bank, power and a docking spine.
	rotor.add_child(Kit.cylinder(45.0, 140.0, Kit.mat("offwhite"), Vector3.ZERO, 24))
	for s in [1.0, -1.0]:
		rotor.add_child(Kit.box(Vector3(30.0, 260.0, 2.0), _mat(Color("1c2a48"), 0.3, 0.35), Vector3(0, s * 160.0, 0)))
		# Grapple heads at each tip, lit like a lighthouse.
		var head := Vector3(s * length * 0.5, 0, 0)
		rotor.add_child(Kit.box(Vector3(120.0, 60.0, 60.0), _lit(Color("d2702c"), 0.4), head))
		rotor.add_child(Kit.beacon(Color("ff3a2a"), head + Vector3(0, 22, 0), 7.0, 1.6, 0.0 if s > 0 else 0.5))
		rotor.add_child(Kit.beacon(Color.WHITE, head + Vector3(s * 35.0, 0, 0), 5.0, 0.9, 0.25))
		# A payload pod riding one end.
		if s > 0:
			rotor.add_child(Kit.box(Vector3(18.0, 12.0, 12.0), Kit.mat("yellow"), head + Vector3(-50.0, -24.0, 0)))
	for i in range(-5, 6):
		if i != 0:
			rotor.add_child(Kit.beacon(Color("f0a030"), Vector3(i * length * 0.09, 4.0, 0), 2.5))
	return [{"kind": "spin", "node": rotor, "rate": TAU / 300.0}]


# --- Clarke power-beaming belt --------------------------------------------------

static func _power_arrays(parent: Node3D, dirs: Dictionary) -> Array:
	var sun: Vector3 = dirs.get("sun", Vector3.UP)
	var earth: Vector3 = dirs.get("earth", Vector3.DOWN)
	var side := _side(dirs)
	var solar := _lit(Color("22345c"), 0.35, 0.35, 0.3)
	var frame := _lit(Color("8c9196"), 0.2, 0.6, 0.5)
	var beam := _haze(Color("ffd0e0"), 0.07)
	var spots := [Vector3(-3200.0, 1500.0, -5000.0), Vector3(3800.0, -900.0, -8500.0), Vector3(200.0, 3600.0, -13000.0)]
	for at in spots:
		# Each satellite: a sun-facing kilometre-wide array on a truss frame, with a
		# transmitter dish on the Earth-facing side and a faint beam toward the rectennas.
		var sat := _facing(-sun, at)
		parent.add_child(sat)
		sat.add_child(Kit.box(Vector3(1400.0, 700.0, 2.0), solar))
		for k in range(-3, 4):
			sat.add_child(Kit.box(Vector3(6.0, 700.0, 4.0), frame, Vector3(k * 200.0, 0, 1.0)))
		sat.add_child(Kit.box(Vector3(1400.0, 6.0, 4.0), frame, Vector3(0, 0, 1.0)))
		for c in [Vector3(700, 350, 0), Vector3(-700, 350, 0), Vector3(700, -350, 0), Vector3(-700, -350, 0)]:
			sat.add_child(Kit.beacon(Color("ff3a2a"), c, 8.0, 2.2, randf()))
		var tx := _facing(earth, at + earth * 120.0)
		parent.add_child(tx)
		tx.add_child(Kit.cone(70.0, 10.0, 40.0, Kit.mat("offwhite"), Vector3(0, 0, -20.0)))
		var ray := Kit.cone(70.0, 220.0, 6000.0, beam, Vector3(0, 0, -3040.0))
		tx.add_child(ray)
	return []


# --- The Luna Line lunar elevator -----------------------------------------------

static func _elevator(parent: Node3D, dirs: Dictionary, station: Dictionary, second: float = 0.0) -> Array:
	var moon: Vector3 = dirs.get("moon", Vector3(0, 0, -1))
	var earth: Vector3 = dirs.get("earth", -moon)
	var anchor := Vector3(-(float(station["hub_radius"]) + 450.0), 120.0, -350.0)
	# The anchor: a vertical station threaded on the ribbon (after Obayashi's modular
	# synchronous station), stacked modules along the line with a wide solar array,
	# tied to the depot by a cargo truss.
	var st := _facing(moon, anchor)
	for k in 5:
		var z := -60.0 + 30.0 * float(k)
		st.add_child(Kit.cylinder(14.0 if k % 2 == 0 else 11.0, 26.0, Kit.mat("orange" if k % 2 == 0 else "offwhite"), Vector3(0, 0, z), 28))
		st.add_child(Kit.torus(14.5, 0.8, Kit.mat("steel"), Vector3(0, 0, z + 13.0), 32))
	for side in [-1.0, 1.0]:
		st.add_child(Kit.box(Vector3(46.0, 2.0, 2.0), Kit.mat("steel"), Vector3(side * 37.0, 0, 0)))
		st.add_child(Kit.box(Vector3(60.0, 0.6, 34.0), Kit.paint(Color("1d2b4a"), {"finish": 1, "metallic": 0.35, "roughness": 0.3}), Vector3(side * 88.0, 0, 0)))
	st.add_child(Kit.beacon(Color("ff3a2a"), Vector3(0, 16.0, 0), 4.0, 1.5, 0.0))
	parent.add_child(st)
	var tie := _facing(-anchor, anchor * 0.5)
	tie.add_child(Kit.box(Vector3(6.0, 6.0, anchor.length()), Kit.mat("steel")))
	parent.add_child(tie)
	# The ribbon both ways: widest at the anchor, where it carries the most, between two
	# guard strands near the station. Toward Earth it runs on 26,000 km to Ballast Point,
	# far beyond sight.
	var ribbon := _lit(Color("d6cfbd"), 0.35, 0.4, 0.45)
	var reach := 60000.0
	var wide := 8000.0
	for dir in [moon, earth]:
		var d: Vector3 = dir
		var near := _facing(d, anchor + d * (75.0 + wide * 0.5))
		near.add_child(Kit.box(Vector3(5.0, 0.3, wide), ribbon))
		for side in [-1.0, 1.0]:
			near.add_child(Kit.box(Vector3(0.6, 0.6, wide), Kit.mat("steel"), Vector3(side * 6.0, 0, 0)))
		parent.add_child(near)
		var far := _facing(d, anchor + d * (75.0 + wide + (reach - wide) * 0.5))
		far.add_child(Kit.box(Vector3(3.0, 0.3, reach - wide), ribbon))
		parent.add_child(far)
	# Marker lights every 2 km recede toward the Moon like a runway into the dark.
	for i in range(1, 31):
		parent.add_child(Kit.beacon(Color("f0a030"), anchor + moon * (2000.0 * i), 3.0 + i * 0.6, 3.0, float(i) * 0.033))
	# Climbers in pairs, one up and one down passing together, so the swing each
	# gives the ribbon cancels: cargo up, empties down.
	var climbers := []
	var speeds := []
	var phases := []
	for i in 4:
		var c: Node3D = ClimberModel.build("beam", "yellow", 1.0)["node"]
		c.basis = _along(moon)
		parent.add_child(c)
		climbers.append(c)
		speeds.append(-150.0 if i % 2 == 0 else 150.0)
		phases.append(0.2 + 0.5 * float(i >> 1))
	var anims := [{"kind": "climbers", "nodes": climbers, "start": anchor + moon * 75.0, "dir": moon, "length": reach, "speeds": speeds, "phases": phases}]
	# Luna Line 2: a second ribbon being let down toward the Moon, 80 m alongside.
	if second > 0.0:
		var offset := moon.cross(Vector3.UP).normalized() * 80.0 if absf(moon.dot(Vector3.UP)) < 0.98 else Vector3(80, 0, 0)
		var anchor2 := anchor + offset
		var reach2 := reach * clampf(second * 2.0, 0.05, 1.0)
		var r2 := _facing(moon, anchor2 + moon * reach2 * 0.5)
		r2.add_child(Kit.box(Vector3(4.0, 0.3, reach2), ribbon))
		parent.add_child(r2)
		# The spool tip stays lit while the ribbon is still being let down.
		if second < 0.5:
			parent.add_child(Kit.beacon(Color("40ff60"), anchor2 + moon * reach2, 10.0, 1.2, 0.0))
		elif second >= 1.0:
			var climbers2 := []
			for i in 2:
				var c: Node3D = ClimberModel.build("beam", "orange", 1.0)["node"]
				c.basis = _along(moon)
				parent.add_child(c)
				climbers2.append(c)
			anims.append({"kind": "climbers", "nodes": climbers2, "start": anchor2, "dir": moon, "length": reach, "speeds": [140.0, -140.0], "phases": [0.6, 0.6]})
	return anims


## A climber's basis on a ribbon laid by _facing(dir, ...): +Y along `dir`, its thin
## axis (X) on the tape's thin axis, its width axis (Z) across the tape.
static func _along(dir: Vector3) -> Basis:
	var f := _facing(dir, Vector3.ZERO)
	var fb := f.transform.basis
	f.free()
	return Basis(fb.y, -fb.z, -fb.x)


# --- Island One, a Bernal sphere under construction -------------------------------

static func _bernal(parent: Node3D, dirs: Dictionary, p: float = 0.0) -> Array:
	# Stages (project island_one): frame closed -> hull skinned -> air, water and soil ->
	# spin-up. p runs 0..1 across all four, and what you see follows the build.
	var centre := Vector3(1700.0, 500.0, -2600.0)
	var radius := 250.0
	var frame := _lit(Color("9aa0a6"), 0.3, 0.6, 0.5)
	var root := Node3D.new()
	root.position = centre
	parent.add_child(root)
	_solid_sphere(parent, centre, radius)
	var frame_f := clampf(0.4 + p / 0.25 * 0.6, 0.4, 1.0)
	var skin_f := clampf((p - 0.25) / 0.25, 0.0, 1.0)
	var alive := p >= 0.5
	var done := p >= 1.0
	# Meridians close as the frame stage completes. Kit tori lie in the XY plane
	# (axis Z), so each passes through the poles on Y; turning a holder about Y fans
	# them out into meridians.
	for k in int(ceil(8.0 * frame_f)):
		var holder := Node3D.new()
		holder.rotation.y = PI * float(k) / 8.0
		holder.add_child(Kit.torus(radius, 2.2, frame, Vector3.ZERO, 64))
		root.add_child(holder)
	for lat in [-0.66, -0.33, 0.0, 0.33, 0.66]:
		var r := radius * sqrt(1.0 - lat * lat)
		var ring := Kit.torus(r, 1.8, frame, Vector3(0, lat * radius, 0), 64)
		ring.rotation = Vector3.ZERO  # native TorusMesh axis is Y: a horizontal latitude ring
		root.add_child(ring)
	# Pressure panels go on from the south pole upward as the hull stage advances.
	var skin := _lit(Color("d9d4c7"), 0.12, 0.2, 0.8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1977
	var panels := []
	for i in 420:
		panels.append([rng.randf_range(-1.0, 1.0), rng.randf() * TAU])
	panels.sort_custom(func(a, b): return a[0] < b[0])
	for i in 40 + int(380.0 * skin_f):
		var lat: float = panels[i][0]
		var lon: float = panels[i][1]
		var at := Vector3(cos(lon) * sqrt(1.0 - lat * lat), lat, sin(lon) * sqrt(1.0 - lat * lat)) * radius
		var panel := _facing(-at, at)
		panel.add_child(Kit.box(Vector3(44.0, 44.0, 1.2), skin))
		root.add_child(panel)
	# Once air, water and soil are going in, the interior glows through the gaps.
	if alive:
		root.add_child(Kit.sphere(radius * 0.93, _lit(Color("6f8f4a"), 0.9 if done else 0.4, 0.0, 1.0)))
	# Welding sparks while anything is still being built.
	var sparks := []
	if not done:
		for i in 28:
			var lat := rng.randf_range(-0.6, 0.9)
			var lon := rng.randf() * TAU
			var at := Vector3(cos(lon) * sqrt(1.0 - lat * lat), lat, sin(lon) * sqrt(1.0 - lat * lat)) * radius
			var spark := Kit.sphere(2.5, Kit.glow(Color("cfe8ff"), 6.0), at)
			spark.set_meta("seed", rng.randf())
			root.add_child(spark)
			sparks.append(spark)
	# Polar docking hubs and the zero-g industrial spindle.
	var spindle := Kit.cylinder(30.0, 600.0, Kit.mat("grey"), Vector3.ZERO, 24)
	spindle.rotation = Vector3.ZERO  # along Y, pole to pole
	root.add_child(spindle)
	for sgn in [1.0, -1.0]:
		root.add_child(Kit.beacon(Color("40ff60"), Vector3(0, sgn * (radius + 40.0), 0), 6.0, 2.0, 0.0))
	var anims := [{"kind": "flicker", "nodes": sparks}]
	if done:
		# Spun up: about 1.9 rpm gives a full gee at the equator of a 250 m sphere.
		anims.append({"kind": "spin_y", "node": root, "rate": TAU * 1.9 / 60.0})
	return anims


# --- Kalpana Two, a counter-rotating sister drum ------------------------------------

static func _kalpana_two(parent: Node3D, station: Dictionary, p: float) -> Array:
	var rh: float = station["hub_radius"]
	var lh: float = station["hub_length"]
	# Alongside Kalpana One, joined by a truss; counter-rotating pairs cancel each other's spin.
	var root := Node3D.new()
	root.position = Vector3(rh * 2.0 + 260.0, 0, -lh * 0.2)
	parent.add_child(root)
	var join := Kit.truss(260.0, 24.0, Kit.mat("steel"), Vector3(-rh - 130.0, 0, 0))
	join.rotation = Vector3(0, PI * 0.5, 0)
	root.add_child(join)
	var rotor := Node3D.new()
	root.add_child(rotor)
	var frame := _lit(Color("9aa0a6"), 0.3, 0.6, 0.5)
	var rings := int(ceil(9.0 * clampf(0.2 + p / 0.33 * 0.8, 0.2, 1.0)))
	for i in rings:
		rotor.add_child(Kit.torus(rh, 3.0, frame, Vector3(0, 0, -lh * 0.5 + lh * float(i) / 8.0), 72))
	var built_len := lh * float(maxi(rings - 1, 1)) / 8.0
	for i in 12:
		var a := TAU * float(i) / 12.0
		rotor.add_child(Kit.box(Vector3(3.0, 3.0, built_len), frame, Vector3(cos(a) * rh, sin(a) * rh, -lh * 0.5 + built_len * 0.5)))
	var hull_f := clampf((p - 0.33) / 0.33, 0.0, 1.0)
	if hull_f > 0.0:
		var hull_len := lh * hull_f
		rotor.add_child(Kit.cylinder(rh - 1.0, hull_len, _lit(Color("d9d4c7"), 0.1, 0.2, 0.8), Vector3(0, 0, -lh * 0.5 + hull_len * 0.5), 64))
	var anims := []
	if p >= 1.0:
		for i in 12:
			var a := TAU * float(i) / 12.0
			rotor.add_child(Kit.beacon(Color("ffdca0"), Vector3(cos(a) * (rh + 1.0), sin(a) * (rh + 1.0), 0), 1.2))
		anims.append({"kind": "spin", "node": rotor, "rate": -TAU * 1.89 / 60.0})
	else:
		var sparks := []
		var rng := RandomNumberGenerator.new()
		rng.seed = 2207
		for i in 20:
			var a := rng.randf() * TAU
			var spark := Kit.sphere(2.0, Kit.glow(Color("cfe8ff"), 6.0), Vector3(cos(a) * rh, sin(a) * rh, rng.randf_range(-lh * 0.5, lh * 0.5)))
			spark.set_meta("seed", rng.randf())
			rotor.add_child(spark)
			sparks.append(spark)
		anims.append({"kind": "flicker", "nodes": sparks})
	return anims


# --- Farside megatelescope array ----------------------------------------------------

static func _telescopes(parent: Node3D, dirs: Dictionary) -> Array:
	var earth: Vector3 = dirs.get("earth", Vector3(0, 0, 1))
	var side := _side(dirs)
	var mirror := _lit(Color("c9a24a"), 0.3, 0.95, 0.15)
	var frame := Kit.mat("steel")
	for i in 7:
		var at := Vector3(-7000.0 + 2300.0 * float(i), 1200.0 + 700.0 * sin(float(i)), -7000.0 - 900.0 * float(i % 3))
		# Each mirror faces away from Earth, into the radio-quiet dark behind the Moon.
		var t := _facing(-earth, at)
		parent.add_child(t)
		var dish := Kit.cylinder(320.0, 4.0, mirror, Vector3.ZERO, 6)
		t.add_child(dish)
		t.add_child(Kit.truss(420.0, 20.0, frame, Vector3(0, 0, 210.0)))
		t.add_child(Kit.box(Vector3(50.0, 50.0, 30.0), Kit.mat("dark"), Vector3(0, 0, -420.0)))
		for k in 6:
			var a := TAU * float(k) / 6.0
			t.add_child(Kit.beacon(Color("ff3a2a"), Vector3(cos(a) * 320.0, sin(a) * 320.0, 0), 9.0, 2.4, float(i) * 0.14))
	return []


# --- A captured asteroid --------------------------------------------------------

## A lumpy rock: a sphere pushed in and out by noise, then stretched. Cratered by the
## airless-body shader at rock scale, in carbonaceous near-black.
static func rock(radius: float, stretch: Vector3, seed: int, look: Dictionary = {}) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 96
	sphere.rings = 48
	var arrays := sphere.get_mesh_arrays()
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = 1.0
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in verts.size():
		var d := verts[i].normalized()
		var h := 1.0 + 0.22 * noise.get_noise_3dv(d * 1.1) + 0.07 * noise.get_noise_3dv(d * 3.7 + Vector3(5, 1, 3)) + 0.025 * noise.get_noise_3dv(d * 11.0 + Vector3(2, 7, 1))
		verts[i] = d * h * radius * stretch
	arrays[Mesh.ARRAY_VERTEX] = verts
	# Without UVs and normals the seam's duplicate vertices merge, so the rebuilt
	# normals are smooth all round.
	arrays[Mesh.ARRAY_NORMAL] = null
	arrays[Mesh.ARRAY_TANGENT] = null
	arrays[Mesh.ARRAY_TEX_UV] = null
	var st := SurfaceTool.new()
	st.create_from_arrays(arrays)
	st.index()
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var params := {"radius_km": 60.0, "largest_km": 40.0, "basin_flooding": 0.0, "ray_chance": 0.0, "relief": 1.3, "grain_per_radius": 900.0,
		"highland_colour": Color("4d4943"), "mare_colour": Color("3a3733"), "seed": float(seed)}
	params.merge(look, true)
	mi.material_override = SkyKit.body_material("rock", params)
	return mi


static func _captured_rock(parent: Node3D, station: Dictionary) -> Array:
	# 2058 QT, a 400 m rubble-pile caught from a near-Earth orbit and towed to L4:
	# despun inside a harness of cable bands, with a mining head chewing at one end
	# and a conveyor truss feeding the foundry.
	var centre := Vector3(-float(station["ring_radius"]) - 900.0, 160.0, -1500.0)
	var radius := 190.0
	var body := rock(radius, Vector3(1.45, 0.95, 1.1), 2058)
	body.position = centre
	_solid_sphere(parent, centre, radius * 1.15)
	body.rotation = Vector3(0.3, 0.7, 0.2)
	parent.add_child(body)
	var steel := Kit.mat("steel")
	for i in 3:
		var band := Kit.torus(radius * 1.12, 2.5, steel, centre, 96)
		band.rotation = Vector3(PI * 0.5, float(i) * PI / 3.0, 0.0)
		band.scale = Vector3(1.3, 1.0, 1.0)
		parent.add_child(band)
	# Mining head on the station-facing end, under work lights that flicker as it bites.
	var head_at := centre + (Vector3.ZERO - centre).normalized() * radius * 1.35
	var head := _facing(centre - head_at, head_at)
	head.add_child(Kit.box(Vector3(40.0, 30.0, 50.0), Kit.mat("yellow")))
	head.add_child(Kit.box(Vector3(60.0, 6.0, 6.0), Kit.mat("black"), Vector3(0, 18.0, -10.0)))
	var flicker := []
	for k in 4:
		var l := Kit.sphere(3.0, Kit.glow(Color("fff0c0"), 4.0), Vector3(-18.0 + 12.0 * k, -16.0, -26.0))
		l.set_meta("seed", float(k) * 0.37)
		head.add_child(l)
		flicker.append(l)
	parent.add_child(head)
	var feed := _facing(-head_at, head_at * 0.5)
	feed.add_child(Kit.truss(head_at.length() - float(station["ring_radius"]), 8.0, steel))
	parent.add_child(feed)
	for k in 6:
		parent.add_child(Kit.beacon(Color("ff3a2a"), centre + Vector3(cos(k * 1.05) * radius * 1.5, sin(k * 1.7) * radius * 0.9, sin(k * 1.05) * radius * 1.2), 4.0, 2.2, float(k) * 0.17))
	return [{"kind": "flicker", "nodes": flicker}]


# --- The Concord Pair: O'Neill cylinders over Ceres ------------------------------------

## Two cylinders 8 km across and 32 km long, axes on the Sun, turning against each other
## so the pair holds steady. Each has three land strips and three long windows, with a
## mirror outside each window hinged at the far end to throw sunlight in. Stages
## (project concord_pair): spines and caps -> hull and windows -> mirrors and spin-up ->
## air, soil and settlers (the windows light up).
static func _oneill_pair(parent: Node3D, dirs: Dictionary, p: float, distance: float = 120000.0, at: Vector3 = Vector3.ZERO) -> Array:
	var sun: Vector3 = dirs.get("sun", Vector3.UP)
	# Out where the pilot looks, but well clear of Ceres on the sky.
	var avoid: Vector3 = dirs.get("ceres", Vector3.DOWN).normalized()
	var d := Vector3(0, 0, -1)
	var clear := deg_to_rad(72.0)
	if d.angle_to(avoid) < clear:
		var axis := avoid.cross(d)
		if axis.length() < 1e-3:
			axis = Vector3.UP
		d = avoid.rotated(axis.normalized(), clear)
	var root := _facing(sun, at if at != Vector3.ZERO else d * distance)
	parent.add_child(root)
	var r := 4000.0
	var length := 32000.0
	var chord := 2.0 * r * sin(PI / 12.0)
	var frame_f := clampf(0.15 + p / 0.25 * 0.85, 0.15, 1.0)
	var hull_f := clampf((p - 0.25) / 0.25, 0.0, 1.0)
	var mirror_f := clampf((p - 0.5) / 0.25, 0.0, 1.0)
	var spun := p >= 0.75
	var done := p >= 1.0
	var frame := _lit(Color("9aa0a6"), 0.25, 0.6, 0.5)
	var skin := _lit(Color("d9d4c7"), 0.12, 0.2, 0.8)
	var glass := _lit(Color("6f9a8a") if spun else Color("1a2430"), 0.9 if done else (0.35 if spun else 0.1), 0.3, 0.1)
	var mirror := _lit(Color("aebfd4"), 0.6, 0.95, 0.08)
	var anims := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 1974
	for k in 2:
		var rotor := Node3D.new()
		rotor.position = Vector3((-1.0 if k == 0 else 1.0) * 6200.0, 0, 0)
		root.add_child(rotor)
		var hoops := int(ceil(17.0 * frame_f))
		for i in hoops:
			rotor.add_child(Kit.torus(r, 40.0, frame, Vector3(0, 0, length * 0.5 - length * float(i) / 16.0), 96))
		var built := length * float(maxi(hoops - 1, 1)) / 16.0
		for j in 6:
			var a := TAU * float(j) / 6.0
			rotor.add_child(Kit.box(Vector3(60.0, 60.0, built), frame, Vector3(cos(a) * r, sin(a) * r, length * 0.5 - built * 0.5)))
		if frame_f >= 1.0:
			for z in [-length * 0.5, length * 0.5]:
				rotor.add_child(Kit.cylinder(r, 80.0, skin, Vector3(0, 0, z), 64))
		# Sunward docking spindle.
		rotor.add_child(Kit.cylinder(300.0, 1600.0, Kit.mat("grey"), Vector3(0, 0, -length * 0.5 - 800.0), 24))
		rotor.add_child(Kit.beacon(Color("40ff60"), Vector3(0, 0, -length * 0.5 - 1650.0), 40.0, 2.0, float(k) * 0.5))
		# Hull: twelve panels round, land and window strips in pairs, skinned from the far end.
		if hull_f > 0.0:
			var hull_len := length * hull_f
			for j in 12:
				var a := TAU * (float(j) + 0.5) / 12.0
				var panel := Node3D.new()
				panel.rotation.z = a - PI * 0.5
				panel.position = Vector3(cos(a), sin(a), 0) * r * cos(PI / 12.0) + Vector3(0, 0, length * 0.5 - hull_len * 0.5)
				panel.add_child(Kit.box(Vector3(chord, 30.0, hull_len), glass if (j / 2) % 2 == 1 else skin))
				rotor.add_child(panel)
		# Mirrors, one outside each window, hinged at the far end and opened sunward.
		if mirror_f > 0.0:
			for j in 3:
				var a := TAU * (float(j) * 4.0 + 3.0) / 12.0
				var hinge := Node3D.new()
				hinge.rotation.z = a - PI * 0.5
				hinge.position = Vector3(cos(a), sin(a), 0) * (r + 60.0) + Vector3(0, 0, length * 0.5)
				var pivot := Node3D.new()
				pivot.rotation.x = deg_to_rad(28.0) * mirror_f
				var reach := length * mirror_f
				pivot.add_child(Kit.box(Vector3(chord * 2.0, 20.0, reach), mirror, Vector3(0, 0, -reach * 0.5)))
				hinge.add_child(pivot)
				rotor.add_child(hinge)
		if spun:
			# About 0.47 rpm gives a full gee at 4 km; the pair turn opposite ways.
			anims.append({"kind": "spin", "node": rotor, "rate": (1.0 if k == 0 else -1.0) * sqrt(9.81 / r)})
		if not done:
			var sparks := []
			for i in 24:
				var a := rng.randf() * TAU
				var spark := Kit.sphere(30.0, Kit.glow(Color("cfe8ff"), 6.0), Vector3(cos(a) * r, sin(a) * r, length * 0.5 - built * rng.randf()))
				spark.set_meta("seed", rng.randf())
				rotor.add_child(spark)
				sparks.append(spark)
			anims.append({"kind": "flicker", "nodes": sparks})
	return anims


# --- Landauer Deep: built by minds, for minds -----------------------------------------

## A core kept in permanent shade behind a sun-facing collector, with kilometres of
## radiator vanes edge-on to the Sun, glowing a dull red as they dump the heat of
## thinking. Beside it the second core goes up (project second_core), built by a swarm
## of construction drones: frame, then shell, then its own vanes, then it wakes.
static func _mind_works(parent: Node3D, dirs: Dictionary, p: float) -> Array:
	var sun: Vector3 = dirs.get("sun", Vector3.UP)
	var centre := Vector3(-3800.0, 900.0, -7600.0)
	var root := _facing(sun, centre)
	parent.add_child(root)
	var collector := _lit(Color("141c30"), 0.12, 0.35, 0.3)
	var vane := _lit(Color("7a2a18"), 0.9, 0.2, 0.7)
	var ring := _lit(Color("9aa0a6"), 0.3, 0.6, 0.5)
	var steel := Kit.mat("steel")
	var anims := []
	for c in 2:
		var stage := 1.0 if c == 0 else p
		if c == 1 and stage <= 0.0:
			continue
		var frame_f := 1.0 if c == 0 else clampf(stage * 3.0, 0.15, 1.0)
		var shell_f := 1.0 if c == 0 else clampf((stage - 1.0 / 3.0) * 3.0, 0.0, 1.0)
		var vanes_f := 1.0 if c == 0 else clampf((stage - 2.0 / 3.0) * 3.0, 0.0, 1.0)
		var awake := c == 0 or stage >= 1.0
		var core := Node3D.new()
		core.position = Vector3.ZERO if c == 0 else Vector3(3200.0, 0, 400.0)
		root.add_child(core)
		# The collector shades the core and powers it.
		if c == 0 or shell_f > 0.0:
			core.add_child(Kit.cylinder(1200.0, 6.0, collector, Vector3(0, 0, -1700.0), 48))
			core.add_child(Kit.torus(1200.0, 14.0, ring, Vector3(0, 0, -1696.0), 96))
			for j in 6:
				var spoke := Node3D.new()
				spoke.rotation.z = TAU * float(j) / 6.0
				spoke.add_child(Kit.box(Vector3(1200.0, 10.0, 10.0), ring, Vector3(600.0, 0, -1694.0)))
				core.add_child(spoke)
			core.add_child(Kit.truss(1500.0, 40.0, steel, Vector3(0, 0, -900.0)))
		for i in int(ceil(9.0 * frame_f)):
			core.add_child(Kit.torus(170.0, 6.0, ring, Vector3(0, 0, -450.0 + 112.5 * float(i)), 32))
		if shell_f > 0.0:
			core.add_child(Kit.cylinder(160.0, 900.0 * shell_f, Kit.mat("black"), Vector3(0, 0, 450.0 - 450.0 * shell_f), 32))
		for j in int(round(8.0 * vanes_f)):
			var holder := Node3D.new()
			holder.rotation.z = TAU * float(j) / 8.0
			holder.add_child(Kit.box(Vector3(2600.0, 4.0, 700.0), vane, Vector3(160.0 + 1300.0, 0, 120.0)))
			core.add_child(holder)
		if awake:
			for j in 6:
				var a := TAU * float(j) / 6.0
				core.add_child(Kit.beacon(Color("7fb3d5"), Vector3(cos(a) * 165.0, sin(a) * 165.0, 460.0), 8.0, 4.0, float(j) / 6.0))
		else:
			# The construction swarm, seen as sparks of work.
			var rng := RandomNumberGenerator.new()
			rng.seed = 2207
			var drones := []
			for i in 40:
				var a := rng.randf() * TAU
				var spark := Kit.sphere(7.0, Kit.glow(Color("cfe8ff"), 6.0), Vector3(cos(a) * rng.randf_range(170.0, 600.0), sin(a) * rng.randf_range(170.0, 600.0), rng.randf_range(-500.0, 500.0)))
				spark.set_meta("seed", rng.randf())
				core.add_child(spark)
				drones.append(spark)
			anims.append({"kind": "flicker", "nodes": drones})
	# They talk to the inner system by laser, very quietly.
	var earth: Vector3 = dirs.get("earth", Vector3(0, 0, 1))
	var beam := _facing(earth, centre + earth * 3000.0)
	beam.add_child(Kit.cylinder(2.0, 6000.0, _haze(Color("70ff90"), 0.25)))
	parent.add_child(beam)
	return anims


# --- Valhalla's starshade -------------------------------------------------------------

## A flower-shaped shade a hundred metres across, flown in formation with a telescope
## fifty thousand kilometres away so that a star's glare falls in its shadow and its
## planets don't. The petals' shape is what keeps the shadow's edge dark.
static func _starshade(parent: Node3D) -> Array:
	var target := Vector3(0.35, 0.45, -0.82).normalized()
	var root := _facing(target, Vector3(2600.0, -700.0, -3200.0))
	parent.add_child(root)
	var film := _lit(Color("2a2c30"), 0.25, 0.4, 0.4)
	root.add_child(Kit.cylinder(30.0, 1.0, film, Vector3.ZERO, 40))
	for i in 20:
		var petal := Node3D.new()
		petal.rotation.z = TAU * float(i) / 20.0
		var blade := Kit.cone(0.4, 9.0, 22.0, film, Vector3.ZERO, 4)
		blade.rotation = Vector3(0, PI * 0.5, 0)
		blade.position = Vector3(41.0, 0, 0)
		blade.scale = Vector3(1.0, 0.05, 1.0)
		petal.add_child(blade)
		root.add_child(petal)
	root.add_child(Kit.box(Vector3(8.0, 8.0, 6.0), Kit.mat("foil"), Vector3(0, 0, 4.0)))
	for k in 4:
		var a := TAU * float(k) / 4.0
		root.add_child(Kit.beacon(Color("ff3a2a"), Vector3(cos(a) * 52.0, sin(a) * 52.0, 0), 1.2, 2.0, float(k) * 0.25))
	return []


# --- Clarke's sail yard ---------------------------------------------------------------

## A yard rolling out solar-sail freighters (project lightfoot_sails): film unrolls
## onto a cross of booms while it is built; once finished, a Lightfoot sail stands
## beside the yard, 600 m square and silver, with a power beam pushing on it.
static func _sail_yard(parent: Node3D, dirs: Dictionary, p: float) -> Array:
	var sun: Vector3 = dirs.get("sun", Vector3.UP)
	var at := Vector3(-2600.0, -1400.0, -6500.0)
	var yard := Node3D.new()
	yard.position = at
	parent.add_child(yard)
	var steel := Kit.mat("steel")
	yard.add_child(Kit.truss(900.0, 30.0, steel))
	for i in 5:
		yard.add_child(Kit.cylinder(18.0, 60.0, Kit.mat("foil"), Vector3(0, 30.0, -360.0 + 180.0 * float(i)), 16))
	yard.add_child(Kit.beacon(Color("ff3a2a"), Vector3(0, 0, -470.0), 4.0, 2.0, 0.0))
	yard.add_child(Kit.beacon(Color("ff3a2a"), Vector3(0, 0, 470.0), 4.0, 2.0, 0.5))
	var film := _lit(Color("d9dde2"), 0.35, 0.95, 0.12)
	var span := 600.0
	var sail_at := at + Vector3(900.0, 500.0, -400.0)
	# Turned between the Sun and the approach, so a pilot coming in sees its face lit.
	var facing := (sun * 0.6 + (-sail_at).normalized() * 0.8).normalized()
	var sail := _facing(facing, sail_at)
	parent.add_child(sail)
	var built := clampf(p, 0.0, 1.0)
	# Booms out to the corners first, then the film unrolls down them.
	var boom_f := clampf(0.3 + built * 1.4, 0.3, 1.0)
	for k in 4:
		var boom := Node3D.new()
		boom.rotation.z = TAU * float(k) / 4.0 + PI * 0.25
		boom.add_child(Kit.box(Vector3(span * 0.707 * boom_f, 3.0, 3.0), steel, Vector3(span * 0.354 * boom_f, 0, 0)))
		sail.add_child(boom)
	var film_f := 1.0 if p >= 1.0 else clampf((built - 0.5) * 2.0, 0.0, 1.0)
	if film_f > 0.0:
		sail.add_child(Kit.box(Vector3(span, span * film_f, 0.3), film, Vector3(0, -span * 0.5 * (1.0 - film_f), 0)))
	sail.add_child(Kit.box(Vector3(12.0, 12.0, 16.0), Kit.mat("dark"), Vector3(0, 0, 9.0)))
	var anims := []
	if p >= 1.0:
		# Clarke's beam on the sail: a faint pink column from the yard.
		var beam := _facing(sail_at - at, at + (sail_at - at) * 0.5)
		beam.add_child(Kit.cone(260.0, 30.0, (sail_at - at).length(), _haze(Color("ffd0e0"), 0.06), Vector3.ZERO))
		parent.add_child(beam)
	else:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1610
		var sparks := []
		for i in 16:
			var spark := Kit.sphere(4.0, Kit.glow(Color("cfe8ff"), 6.0), Vector3(rng.randf_range(-span, span) * 0.4, rng.randf_range(-span, span) * 0.4, 0))
			spark.set_meta("seed", rng.randf())
			sail.add_child(spark)
			sparks.append(spark)
		anims.append({"kind": "flicker", "nodes": sparks})
	return anims


# --- The Tsiolkovsky Wheel: a Stanford torus going up at L4 -----------------------------

## The 1975 NASA-Stanford design: a ring 1.8 km across with a 130 m tube, six spokes
## to a central hub, turning once a minute for a gee at the rim, and a great mirror
## held still over the hub to send sunlight in. Seen from Trojan Yards, 12 km off.
## Stages (project tsiolkovsky_wheel): hub and spokes -> the ring tube in sections ->
## regolith shielding (it darkens) -> mirrors, air and people (lit, and turning).
static func _stanford_torus(parent: Node3D, dirs: Dictionary, p: float) -> Array:
	var sun: Vector3 = dirs.get("sun", Vector3.UP)
	var centre := Vector3(-6000.0, 1600.0, -10500.0)
	var root := _facing(sun, centre)
	parent.add_child(root)
	var rotor := Node3D.new()
	root.add_child(rotor)
	var ring_r := 900.0
	var tube := 65.0
	var frame := _lit(Color("9aa0a6"), 0.3, 0.6, 0.5)
	var skin := _lit(Color("d9d4c7") if p < 0.5 else Color("8f877c"), 0.15, 0.2, 0.8)
	var hub_f := clampf(p / 0.25, 0.25, 1.0)
	var tube_f := clampf((p - 0.25) / 0.25, 0.0, 1.0)
	var alive := p >= 0.75
	var done := p >= 1.0
	rotor.add_child(Kit.cylinder(60.0, 240.0 * hub_f, frame, Vector3.ZERO, 32))
	for i in 6:
		var a := TAU * float(i) / 6.0
		var holder := Node3D.new()
		holder.rotation.z = a
		var reach := (ring_r - 60.0) * hub_f
		var spoke := Kit.cylinder(12.0, reach, frame, Vector3(60.0 + reach * 0.5, 0, 0), 12)
		spoke.rotation = Vector3(0, 0, PI * 0.5)
		holder.add_child(spoke)
		rotor.add_child(holder)
	# The ring frame closes first; the tube goes on section by section.
	rotor.add_child(Kit.torus(ring_r, 6.0, frame, Vector3.ZERO, 192))
	var sections := 48
	for i in int(round(float(sections) * tube_f)):
		var a := TAU * (float(i) + 0.5) / float(sections)
		var seg := Kit.cylinder(tube, 2.0 * ring_r * sin(PI / float(sections)) * 1.02, skin, Vector3.ZERO, 20)
		var holder := Node3D.new()
		holder.rotation.z = a
		seg.position = Vector3(ring_r, 0, 0)
		seg.rotation = Vector3.ZERO
		holder.add_child(seg)
		rotor.add_child(holder)
	if alive:
		# Windows along the tube's sunward face, lit from the valley floors inside.
		var glow := Kit.glow(Color("cfe4c0") if done else Color("8fa080"), 1.2 if done else 0.5)
		for i in 96:
			var a := TAU * float(i) / 96.0
			rotor.add_child(Kit.box(Vector3(40.0, 40.0, 4.0), glow, Vector3(cos(a) * ring_r, sin(a) * ring_r, -tube * 0.95)))
		# The mirror over the hub, held still at 45 degrees to bring sunlight in.
		var mirror := Node3D.new()
		mirror.position = Vector3(0, 0, -700.0)
		mirror.rotation = Vector3(PI * 0.25, 0, 0)
		mirror.add_child(Kit.cylinder(450.0, 3.0, _lit(Color("b8c4d0"), 0.5, 0.95, 0.08), Vector3.ZERO, 48))
		root.add_child(mirror)
	var anims := []
	if done:
		anims.append({"kind": "spin", "node": rotor, "rate": TAU / 60.0})
	else:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1975
		var sparks := []
		for i in 30:
			var a := rng.randf() * TAU
			var spark := Kit.sphere(10.0, Kit.glow(Color("cfe8ff"), 6.0), Vector3(cos(a) * ring_r, sin(a) * ring_r, rng.randf_range(-tube, tube)))
			spark.set_meta("seed", rng.randf())
			rotor.add_child(spark)
			sparks.append(spark)
		anims.append({"kind": "flicker", "nodes": sparks})
	if tube_f > 0.0:
		_solid_torus(parent, root.transform, ring_r, tube)
	_solid_sphere(parent, centre, 70.0)
	return anims

