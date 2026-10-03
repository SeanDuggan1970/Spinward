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
extends RefCounted

const Kit := preload("res://view/flight/kit.gd")


## Builds the features under `parent`; returns animation entries for animate().
static func build(parent: Node3D, features: Array, dirs: Dictionary, station: Dictionary) -> Array:
	var anims := []
	for f in features:
		match f:
			"skyhook":
				anims.append_array(_skyhook(parent, dirs))
			"power_arrays":
				anims.append_array(_power_arrays(parent, dirs))
			"elevator":
				anims.append_array(_elevator(parent, dirs, station))
			"bernal_frame":
				anims.append_array(_bernal(parent, dirs))
			"telescope_array":
				anims.append_array(_telescopes(parent, dirs))
	return anims


static func animate(anims: Array, t: float) -> void:
	for a in anims:
		match a["kind"]:
			"spin":
				a["node"].rotation = Vector3(0, 0, t * float(a["rate"]))
			"climbers":
				for i in a["nodes"].size():
					var f := fposmod(float(a["phases"][i]) + t * float(a["speeds"][i]) / float(a["length"]), 1.0)
					a["nodes"][i].position = a["start"] + a["dir"] * float(a["length"]) * f
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

static func _elevator(parent: Node3D, dirs: Dictionary, station: Dictionary) -> Array:
	var moon: Vector3 = dirs.get("moon", Vector3(0, 0, -1))
	var earth: Vector3 = dirs.get("earth", -moon)
	var anchor := Vector3(-(float(station["hub_radius"]) + 450.0), 120.0, -350.0)
	# Anchor platform: the elevator's L1 head station, tied to the depot by a cargo truss.
	parent.add_child(Kit.box(Vector3(90.0, 40.0, 90.0), Kit.mat("orange"), anchor))
	parent.add_child(Kit.beacon(Color("ff3a2a"), anchor + Vector3(0, 30, 0), 4.0, 1.5, 0.0))
	var tie := _facing(-anchor, anchor * 0.5)
	tie.add_child(Kit.box(Vector3(6.0, 6.0, anchor.length()), Kit.mat("steel")))
	parent.add_child(tie)
	var ribbon := _lit(Color("d6cfbd"), 0.35, 0.4, 0.45)
	var moonward := 60000.0
	var earthward := 18000.0
	var down := _facing(moon, anchor + moon * moonward * 0.5)
	down.add_child(Kit.box(Vector3(4.0, 0.3, moonward), ribbon))
	parent.add_child(down)
	var up := _facing(earth, anchor + earth * earthward * 0.5)
	up.add_child(Kit.box(Vector3(4.0, 0.3, earthward), ribbon))
	parent.add_child(up)
	# Counterweight past L1 on the Earth side: spent climbers and slag, lit for traffic.
	var cw := anchor + earth * earthward
	parent.add_child(Kit.box(Vector3(260.0, 180.0, 260.0), Kit.mat("rust"), cw))
	parent.add_child(Kit.beacon(Color("ff3a2a"), cw + Vector3(0, 120, 0), 18.0, 2.0, 0.3))
	# Marker lights every 2 km recede toward the Moon like a runway into the dark.
	for i in range(1, 31):
		parent.add_child(Kit.beacon(Color("f0a030"), anchor + moon * (2000.0 * i), 3.0 + i * 0.6, 3.0, float(i) * 0.033))
	# Climbers riding the ribbon, cargo up, empties down.
	var climbers := []
	var speeds := []
	var phases := []
	for i in 4:
		var c := Node3D.new()
		c.add_child(Kit.box(Vector3(16.0, 10.0, 22.0), Kit.mat("yellow")))
		c.add_child(Kit.beacon(Color.WHITE, Vector3(0, 8, 0), 3.0, 1.0, float(i) * 0.25))
		c.add_child(Kit.sphere(5.0, Kit.glow(Color("fff0c0"), 3.0), Vector3(0, -8, 0)))
		parent.add_child(c)
		climbers.append(c)
		speeds.append(-120.0 if i % 2 == 0 else 160.0)
		phases.append(float(i) / 4.0)
	return [{"kind": "climbers", "nodes": climbers, "start": anchor, "dir": moon, "length": moonward, "speeds": speeds, "phases": phases}]


# --- Island One, a Bernal sphere under construction -------------------------------

static func _bernal(parent: Node3D, dirs: Dictionary) -> Array:
	var centre := Vector3(1700.0, 500.0, -2600.0)
	var radius := 250.0
	var frame := _lit(Color("9aa0a6"), 0.3, 0.6, 0.5)
	var root := Node3D.new()
	root.position = centre
	parent.add_child(root)
	# Meridians: a full cage of girders, the skeleton of a sphere 500 m across.
	# Kit tori lie in the XY plane (axis Z), so each one already passes through the
	# poles on Y; turning a holder about Y fans them out into meridians.
	for k in 8:
		var holder := Node3D.new()
		holder.rotation.y = PI * float(k) / 8.0
		holder.add_child(Kit.torus(radius, 2.2, frame, Vector3.ZERO, 64))
		root.add_child(holder)
	for lat in [-0.66, -0.33, 0.0, 0.33, 0.66]:
		var r := radius * sqrt(1.0 - lat * lat)
		var ring := Kit.torus(r, 1.8, frame, Vector3(0, lat * radius, 0), 64)
		ring.rotation = Vector3.ZERO  # native TorusMesh axis is Y: a horizontal latitude ring
		root.add_child(ring)
	# The lower third is already skinned: pressure panels going on one by one.
	var skin := _lit(Color("d9d4c7"), 0.12, 0.2, 0.8)
	var sparks := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 1977
	for i in 160:
		var lat := rng.randf_range(-1.0, -0.35)
		var lon := rng.randf() * TAU
		var p := Vector3(cos(lon) * sqrt(1.0 - lat * lat), lat, sin(lon) * sqrt(1.0 - lat * lat)) * radius
		var panel := _facing(-p, p)
		panel.add_child(Kit.box(Vector3(46.0, 46.0, 1.2), skin))
		root.add_child(panel)
	# Welding sparks and construction drones working the open frame.
	for i in 24:
		var lat := rng.randf_range(-0.4, 0.6)
		var lon := rng.randf() * TAU
		var p := Vector3(cos(lon) * sqrt(1.0 - lat * lat), lat, sin(lon) * sqrt(1.0 - lat * lat)) * radius
		var spark := Kit.sphere(2.5, Kit.glow(Color("cfe8ff"), 6.0), p)
		spark.set_meta("seed", rng.randf())
		root.add_child(spark)
		sparks.append(spark)
	# Polar docking hubs and the zero-g industrial spindle.
	var spindle := Kit.cylinder(30.0, 600.0, Kit.mat("grey"), Vector3.ZERO, 24)
	spindle.rotation = Vector3.ZERO  # along Y, pole to pole
	root.add_child(spindle)
	for s in [1.0, -1.0]:
		root.add_child(Kit.beacon(Color("40ff60"), Vector3(0, s * (radius + 40.0), 0), 6.0, 2.0, 0.0))
	return [{"kind": "flicker", "nodes": sparks}]


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
