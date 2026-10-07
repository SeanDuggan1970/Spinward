## The big habitats the megaprojects build, as station models (Models.station calls
## these for station.type "bernal" and "pair"):
##
## - bernal: Island One, O'Neill's first design. A sphere half a kilometre across that
##   turns for gravity at its equator, lit through window rings round both poles. A
##   docking hub stands off the forward pole; aft, a spindle carries the stacked farm
##   rings, and a despun mast holds the radiators and arrays.
## - pair: an O'Neill pair (Concord). Two long cylinders side by side, turning opposite
##   ways so the pair has no net spin and can be pointed. Each has three strips of land
##   and three of window, and a mirror hinged off its stern beside each window to throw
##   sunlight in. A frame joins the two sterns. Ships dock on the lead cylinder's axis.
##
## Each builder dresses `rotor` (and `still`, the despun parts) and returns
## {face_z, colliders: {cylinders, tori}, stencil: {px, y, z}}. Collider cylinders may
## carry an x, y offset ([r, z0, z1, x, y]) and tori a z ([R, r, z]).
extends RefCounted

const Kit := preload("res://view/flight/kit.gd")
const HullKit := preload("res://view/flight/hull_kit.gd")
const StationDetail := preload("res://view/flight/station_detail.gd")
const CounterSpin := preload("res://view/flight/counter_spin.gd")


## Window glass the size of a county: glossy and mostly clear, so the land shows through.
static func _land_glass() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.05, 0.08, 0.1, 0.42)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.metallic = 0.5
	m.roughness = 0.04
	return m


## The land inside, in daylight from the mirrors: fields, woods, water and towns.
const LAND := ["4f6b35", "5d7a3a", "6e7d45", "8a8a52", "3f5a3a", "35505e", "9a958a", "566f3c"]


static func _land(i: int) -> StandardMaterial3D:
	var c := Color(LAND[i % LAND.size()])
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 0.55
	return m


## A mirror a few hundred metres wide: satin enough that the sun catches it.
static func _mirror() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("cfd6dc")
	m.metallic = 0.85
	m.roughness = 0.2
	return m


## A node on a sphere of radius r at latitude `lat` (from the equator, +Z north) and
## longitude `lon`: +Y out of the surface, X running east.
static func _on_sphere(r: float, lat: float, lon: float, lift: float = 0.0) -> Node3D:
	var out := Vector3(cos(lat) * cos(lon), cos(lat) * sin(lon), sin(lat))
	var east := Vector3(-sin(lon), cos(lon), 0.0)
	var n := Node3D.new()
	n.position = out * (r + lift)
	n.basis = Basis(east, out, east.cross(out))
	return n


# --- Island One --------------------------------------------------------------------

static func bernal(rotor: Node3D, still: Node3D, geom: Dictionary, mats: Dictionary, livery: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var r := float(geom["hub_radius_m"])
	var pr := float(geom.get("port_radius_m", 12.0))
	var hull: Material = mats["hull"]
	var steel: Material = mats["steel"]
	var grey: Material = Kit.mat("grey")
	var colliders := {"cylinders": [], "tori": []}
	rotor.add_child(Kit.sphere(r, hull))
	# Structure: latitude belts (a heavy one at the equator, where the people live
	# inside) and meridian ribs pole to pole.
	for deg in [-56.0, -38.0, -19.0, 0.0, 19.0, 38.0, 56.0]:
		var lat := deg_to_rad(deg)
		rotor.add_child(Kit.torus(r * cos(lat) + 0.6, 3.2 if deg == 0.0 else 1.4, grey, Vector3(0, 0, r * sin(lat)), 128))
	for k in 16:
		var lon := TAU * float(k) / 16.0
		var prev := Vector3.ZERO
		for j in 25:
			var lat := deg_to_rad(-60.0 + 120.0 * float(j) / 24.0)
			var p := Vector3(cos(lat) * cos(lon), cos(lat) * sin(lon), sin(lat)) * (r + 0.8)
			if j > 0:
				rotor.add_child(HullKit.bar(prev, p, 1.6, grey))
			prev = p
	# The window rings round each pole: framed panes over the lit land inside.
	for pole in [1.0, -1.0]:
		for band in [62.0, 70.0]:
			var count := 28 if band == 62.0 else 22
			for i in count:
				var at := _on_sphere(r, pole * deg_to_rad(band), TAU * (float(i) + 0.5) / float(count), 0.3)
				var w := TAU * r * cos(deg_to_rad(band)) / float(count) * 0.82
				at.add_child(HullKit.window(w, r * deg_to_rad(6.5), mats, mats["dark"], 1.0, 0.0, 1.4, false))
				rotor.add_child(at)
		rotor.add_child(Kit.torus(r * cos(deg_to_rad(66.0)) + 0.6, 1.8, steel, Vector3(0, 0, pole * r * sin(deg_to_rad(66.0))), 96))
		rotor.add_child(Kit.torus(r * cos(deg_to_rad(74.0)) + 0.6, 1.8, steel, Vector3(0, 0, pole * r * sin(deg_to_rad(74.0))), 96))
	# Running lights round the equator so it reads at a distance.
	for i in 12:
		var a := TAU * float(i) / 12.0
		rotor.add_child(Kit.beacon(Color("ffdca0"), Vector3(cos(a) * (r + 4.0), sin(a) * (r + 4.0), 0), 1.4))
	# Forward: the docking hub on the pole, its face, and a collar for the port.
	var hr := clampf(r * 0.14, pr * 2.2, 60.0)
	var hz := r + 38.0
	rotor.add_child(Kit.cylinder(hr, hz - (r - 20.0), Kit.mat("grey"), Vector3(0, 0, (hz + r - 20.0) * 0.5), 32))
	rotor.add_child(Kit.torus(hr + 0.4, 1.0, steel, Vector3(0, 0, hz - 6.0), 32))
	rotor.add_child(Kit.hazard_band(hr + 0.2, 3.0, Vector3(0, 0, hz - 2.0), 24))
	StationDetail.face(rotor, hr, hz, pr, mats, rng)
	rotor.add_child(Kit.cylinder(pr, 3.0, Kit.mat("grey"), Vector3(0, 0, hz + 0.5)))
	colliders["cylinders"].append([hr, r - 20.0, hz])
	colliders["cylinders"].append([pr, hz, hz + 2.0])
	# Aft: the spindle and the farm rings stacked along it, each with its own spokes
	# and a row of windows round its rim.
	var sr := clampf(r * 0.1, 8.0, 40.0)
	var spindle := r * 1.05
	rotor.add_child(Kit.cylinder(sr, spindle, grey, Vector3(0, 0, -r - spindle * 0.5 + 10.0), 24))
	colliders["cylinders"].append([sr, -r - spindle + 10.0, -r + 10.0])
	var ring_r := r * 0.72
	var tube := r * 0.07
	for k in 4:
		var z := -r - spindle * (0.22 + 0.2 * float(k))
		rotor.add_child(Kit.torus(ring_r, tube, hull, Vector3(0, 0, z), 96))
		colliders["tori"].append([ring_r, tube, z])
		for s in 6:
			var a := TAU * (float(s) + 0.5 * float(k % 2)) / 6.0
			var d := Vector3(cos(a), sin(a), 0.0)
			rotor.add_child(HullKit.bar(d * sr + Vector3(0, 0, z), d * (ring_r - tube * 0.8) + Vector3(0, 0, z), 3.0, steel))
		for i in 48:
			var at := StationDetail._on_drum(TAU * (float(i) + 0.5) / 48.0, ring_r + tube - 0.4, z)
			at.add_child(HullKit.window(TAU * (ring_r + tube) / 48.0 * 0.7, tube * 0.9, mats, mats["dark"], 0.8, 0.0, 0.8, false))
			rotor.add_child(at)
	# The sphere, as slabs for the docking computer (each as wide as its widest edge).
	var slabs := 10
	for k in slabs:
		var z0 := -r + 2.0 * r * float(k) / float(slabs)
		var z1 := z0 + 2.0 * r / float(slabs)
		var edge := 0.0 if (z0 < 0.0 and z1 > 0.0) else minf(absf(z0), absf(z1))
		colliders["cylinders"].append([sqrt(maxf(r * r - edge * edge, 0.0)) + 1.0, z0, z1])
	# Despun beyond the spindle: radiators, arrays and the comm farm.
	StationDetail.despun(still, -r - spindle + 10.0, 160.0, r * 0.9, 7.0, livery, rng)
	return {"face_z": hz + 2.0, "colliders": colliders, "stencil": {"px": hr * 0.3 / 96.0, "y": -hr * 0.72, "z": hz + 0.4}}


# --- An O'Neill pair ----------------------------------------------------------------

## Windows and mirrors on one cylinder (radius rh, length lh) of a pair: three strips
## of window between three of land, a mirror hinged off the stern beside each window
## and opened `open` radians, and stiffening rings along the length.
static func _oneill_dress(rotor: Node3D, rh: float, lh: float, open: float, mats: Dictionary, rng: RandomNumberGenerator) -> void:
	var glass := _land_glass()
	var mirror := _mirror()
	var land := []
	for i in LAND.size():
		land.append(_land(i))
	var steel: Material = mats["steel"]
	var dark: Material = mats["dark"]
	var run := lh * 0.9
	for k in 3:
		var mid := TAU * float(k) / 3.0 + PI / 3.0
		# The window strip: six flat panes round its 60 degrees, with mullions between.
		for j in 6:
			var a := mid - PI / 6.0 + PI / 3.0 * (float(j) + 0.5) / 6.0
			var at := StationDetail._on_drum(a, rh + 0.4, 0.0)
			var pane_w := 2.0 * rh * sin(PI / 36.0)
			at.add_child(Kit.box(Vector3(pane_w, 0.3, run), glass, Vector3(0, 0.45, 0)))
			# The land under it, in plots along the valley.
			var plots := 24
			for f in plots:
				for half in [-0.25, 0.25]:
					var plot: Material = land[rng.randi() % land.size()] if rng.randf() < 0.85 else land[0]
					at.add_child(Kit.box(Vector3(pane_w * 0.5, 0.2, run / float(plots)), plot, Vector3(pane_w * half, 0.05, -run * 0.5 + run * (float(f) + 0.5) / float(plots))))
			rotor.add_child(at)
		for j in 7:
			var a := mid - PI / 6.0 + PI / 3.0 * float(j) / 6.0
			var at := StationDetail._on_drum(a, rh + 1.2, 0.0)
			at.add_child(Kit.box(Vector3(3.0 if j in [0, 6] else 1.5, 1.6, run), dark))
			rotor.add_child(at)
		# The mirror: hinged at the stern on the window's edge, opened out a few degrees,
		# its reflecting face toward the window and a frame on its back.
		var holder := Node3D.new()
		holder.rotation.z = mid
		var hinge := Node3D.new()
		hinge.position = Vector3(rh + 3.0, 0.0, -run * 0.5)
		hinge.rotation.y = open
		var width := rh * 0.98
		hinge.add_child(Kit.box(Vector3(1.2, width, run), mirror, Vector3(0.6, 0.0, run * 0.5)))
		for s in [-1.0, 1.0]:
			hinge.add_child(Kit.box(Vector3(5.0, 4.0, run), steel, Vector3(3.6, s * width * 0.5, run * 0.5)))
		for i in 9:
			hinge.add_child(Kit.box(Vector3(4.0, width, 3.0), steel, Vector3(3.4, 0.0, run * float(i) / 8.0)))
		var pin := Kit.cylinder(4.0, width + 8.0, steel, Vector3.ZERO, 16)
		pin.rotation = Vector3(PI * 0.5, 0.0, 0.0)
		hinge.add_child(pin)
		holder.add_child(hinge)
		rotor.add_child(holder)
	for i in 13:
		rotor.add_child(Kit.torus(rh + 1.4, 1.6, steel, Vector3(0, 0, -run * 0.5 + run * float(i) / 12.0), 128))


static func pair(rotor: Node3D, still: Node3D, root: Node3D, geom: Dictionary, livery: Dictionary, rng: RandomNumberGenerator, drum: Callable) -> Dictionary:
	var rh := float(geom["hub_radius_m"])
	var lh := float(geom["hub_length_m"])
	var mats: Dictionary = livery["mats"]
	var open := deg_to_rad(float(geom.get("mirror_open_deg", 12.0)))
	# Far enough apart that the open mirrors clear each other as they turn.
	var reach := rh + 3.0 + lh * 0.9 * sin(open) + 8.0
	var gap := float(geom.get("twin_offset_m", 2.0 * reach + rh * 0.4))
	var lead: Dictionary = drum.call(rotor, still)
	_oneill_dress(rotor, rh, lh, open, mats, rng)
	# The twin, turning the other way, with its own despun stern.
	var twin_at := Node3D.new()
	twin_at.name = "Twin"
	twin_at.position = Vector3(gap, 0.0, 0.0)
	root.add_child(twin_at)
	var twin := CounterSpin.new()
	twin.lead = rotor
	twin_at.add_child(twin)
	var twin_still := Node3D.new()
	twin_at.add_child(twin_still)
	drum.call(twin, twin_still)
	_oneill_dress(twin, rh, lh, open, mats, rng)
	Kit.merge_static(twin)
	Kit.merge_static(twin_still)
	# The frame between the sterns, held still.
	var frame := Kit.truss(gap, 24.0, mats["steel"], Vector3(gap * 0.5, 0.0, -lh * 0.5 - 70.0))
	frame.rotation = Vector3(0.0, PI * 0.5, 0.0)
	still.add_child(frame)
	for side in [-1.0, 1.0]:
		var brace := Kit.truss(gap * 0.6, 12.0, mats["steel"], Vector3(gap * 0.5, side * rh * 0.5, -lh * 0.5 - 70.0))
		brace.rotation = Vector3(0.0, PI * 0.5, 0.0)
		still.add_child(brace)
	var colliders: Dictionary = lead["colliders"]
	colliders["cylinders"].append([rh, -lh * 0.5, lh * 0.5, gap, 0.0])
	lead["gap"] = gap
	return lead
