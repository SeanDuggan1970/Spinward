## A docking bay you fly into (roadmap step 3): a lit tunnel, its doors at the mouth,
## opening into a docking hall with cradles round its wall. You fly in along the axis
## to the port on the hall's back wall; captured, the ship is drawn down to a cradle,
## off the axis, where it is serviced and loaded while other ships lie in the others.
##
## Local frame as the station's: the docking axis is +Z. The hall runs from z_back (the
## old docking face, where the port is) to z_hall, the tunnel from there to z_mouth.
## Sizes come from balance.bays; each station picks its door ("iris", "clamshell" or
## "sliding") in its geometry (data/places.json station.door).
##
## The doors are view state: FlightScene opens them when traffic control clears the
## ship in and closes them once it is inside. Until they are open they are solid.
extends RefCounted

const Kit := preload("res://view/flight/kit.gd")

const LAMP := Color("ffe2b0")
## The bay's interior is drawn on this render layer, which the Sun and planetshine
## lights leave out (shade_interior): inside, only its own lamps light it, so no
## sunlight leaks through the walls.
const INTERIOR_LAYER := 2
## Depth of an iris's housing flange at the mouth.
const IRIS_FLANGE_M := 3.0


## Builds the bay on `rotor` (it spins with the station). r: tunnel radius; outer: the
## module's outer radius; z_back; depth: the tunnel's; hall: balance.bays.hall (empty for
## a tunnel alone). Returns the bay record the flight scene keeps: {r, outer, z_back,
## z_hall, z_mouth, door, open, leaves: [...], hall_r, z_mid, cradles: [angle]}.
static func build(rotor: Node3D, r: float, outer: float, z_back: float, depth: float, door: String, mats: Dictionary, hall: Dictionary = {}) -> Dictionary:
	var hall_r := float(hall.get("radius_m", r))
	var hall_len := float(hall.get("length_m", 0.0))
	var z_hall := z_back + hall_len
	var z_mouth := z_hall + depth
	var hull: Material = mats["hull"]
	# The shell: outer wall, the front face round the mouth, a lip, and the tunnel.
	# A closed shell, so it reads solid from any side: the back face (where it meets
	# the hub; on a habitat it stands proud of the docking nub), the outer wall, the
	# front face round the mouth and the lip.
	var strips := [
		PackedVector2Array([Vector2(r, z_back), Vector2(outer, z_back)]),
		PackedVector2Array([Vector2(outer, z_back), Vector2(outer, z_mouth)]),
		PackedVector2Array([Vector2(outer, z_mouth), Vector2(r + 1.2, z_mouth)]),
		PackedVector2Array([Vector2(r + 1.2, z_mouth), Vector2(r + 1.2, z_mouth + 0.8), Vector2(r, z_mouth + 0.8)]),
	]
	rotor.add_child(Kit.lathe(strips, hull, 64))
	# The tunnel itself is lined in pale steel, so the lamps light it; then the hall: its
	# front wall round the tunnel, its long wall and its back wall round the port.
	var lining := [PackedVector2Array([Vector2(r, z_mouth + 0.8), Vector2(r, z_hall)])]
	if hall_len > 0.0:
		lining.append(PackedVector2Array([Vector2(r, z_hall), Vector2(hall_r, z_hall)]))
		lining.append(PackedVector2Array([Vector2(hall_r, z_hall), Vector2(hall_r, z_back)]))
	rotor.add_child(_inside(Kit.lathe(lining, Kit.mat("offwhite"), 96)))
	var back := [PackedVector2Array([Vector2(hall_r, z_back), Vector2(0.01, z_back)])]
	rotor.add_child(_inside(Kit.lathe(back, mats["dark"], 64)))
	rotor.add_child(Kit.hazard_band(r + 0.6, 0.6, Vector3(0, 0, z_mouth + 0.85), 32))
	# Inside: rings of lamps down the tunnel and guide stripes along the floor-less walls.
	var lamp := Kit.glow(LAMP, 1.3)
	var rings := maxi(2, int(depth / 14.0))
	for k in rings:
		var z := z_hall + depth * (float(k) + 0.5) / float(rings)
		rotor.add_child(_inside(Kit.torus(r - 0.2, 0.1, lamp, Vector3(0, 0, z), 48)))
	for k in 4:
		var a := TAU * float(k) / 4.0 + PI * 0.25
		var stripe := Kit.box(Vector3(0.5, 0.06, depth - 2.0), Kit.mat("yellow"), Vector3(cos(a), sin(a), 0.0) * (r - 0.05) + Vector3(0, 0, z_hall + depth * 0.5))
		stripe.rotation.z = a + PI * 0.5
		rotor.add_child(_inside(stripe))
	# Light inside the tunnel (a few lights, not one per ring).
	var lights := []
	for k in 2:
		var l := OmniLight3D.new()
		l.light_color = LAMP
		l.light_energy = 1.6
		l.omni_range = maxf(r * 2.2, depth * 0.7)
		l.position = Vector3(0, 0, z_hall + depth * (float(k) + 0.5) / 2.0)
		rotor.add_child(l)
		lights.append(l)
	var cradles := []
	if hall_len > 0.0:
		cradles = _hall(rotor, hall_r, z_back, z_hall, int(hall.get("cradles", 8)), lamp, lights, mats)
	# Approach lights either side of the mouth: green to port, red to starboard.
	for i in 3:
		var y := (float(i) - 1.0) * r * 0.45
		rotor.add_child(Kit.beacon(Color("39ff6a"), Vector3(-(r + (outer - r) * 0.5), y, z_mouth + 0.3), 0.6, 1.6, float(i) * 0.15))
		rotor.add_child(Kit.beacon(Color("ff3a2a"), Vector3(r + (outer - r) * 0.5, y, z_mouth + 0.3), 0.6, 1.6, float(i) * 0.15))
	var bay := {"r": r, "outer": outer, "z_back": z_back, "z_hall": z_hall, "z_mouth": z_mouth, "depth": depth, "door": door, "open": 0.0, "leaves": [], "lights": lights,
		"hall_r": hall_r, "z_mid": z_back + hall_len * 0.5, "cradles": cradles}
	var doors := Node3D.new()
	doors.name = "BayDoors"
	doors.set_meta("no_merge", true)
	rotor.add_child(doors)
	bay["node"] = doors
	_doors(bay, doors, mats)
	# Warning lamps that turn while the doors move, just outside the door tracks (the
	# station's name is painted on the face below them: view/flight/models.gd).
	var warn := []
	for s in [-1.0, 1.0]:
		var w := Kit.beacon(Color("ffb030"), Vector3(0, s * (r + 3.0), z_mouth + 0.3), 0.7)
		w.set_meta("no_merge", true)
		w.visible = false
		rotor.add_child(w)
		warn.append(w)
	bay["warn"] = warn
	set_open(bay, 0.0)
	return bay


## The docking hall: cradles round the wall (each a pair of saddles with clamp arms, a
## gantry over it and its number), lamp bars between them, and the hall's own lights.
## Returns the cradles' angles; cradle 0, at the bottom of the hall, is kept for the
## pilot.
static func _hall(rotor: Node3D, hall_r: float, z0: float, z1: float, count: int, lamp: Material, lights: Array, mats: Dictionary) -> Array:
	var angles := []
	var mid := (z0 + z1) * 0.5
	var length := z1 - z0
	var steel: Material = Kit.mat("steel")
	var yellow: Material = Kit.mat("yellow")
	for i in count:
		var a := -PI * 0.5 + TAU * float(i) / float(count)
		angles.append(a)
		var holder := Node3D.new()
		holder.rotation.z = a
		# Two saddles and their clamp arms, reaching in from the wall.
		for dz in [-length * 0.22, length * 0.22]:
			holder.add_child(_inside(Kit.box(Vector3(5.0, 9.0, 3.0), steel, Vector3(hall_r - 2.5, 0, mid + dz))))
			for side in [-1.0, 1.0]:
				var arm := Kit.box(Vector3(9.0, 1.2, 1.2), yellow, Vector3(hall_r - 6.5, side * 5.0, mid + dz))
				arm.rotation.z = side * 0.5
				holder.add_child(_inside(arm))
		# The gantry along the cradle and a service walkway.
		holder.add_child(_inside(Kit.box(Vector3(1.6, 1.6, length * 0.8), mats["dark"], Vector3(hall_r - 0.8, 7.5, mid))))
		holder.add_child(_inside(Kit.box(Vector3(1.6, 1.6, length * 0.8), mats["dark"], Vector3(hall_r - 0.8, -7.5, mid))))
		holder.add_child(_inside(Kit.box(Vector3(0.3, 2.4, length * 0.7), yellow, Vector3(hall_r - 0.2, 0, mid))))
		# Between this cradle and the next, a bar of lamps the length of the hall.
		var bar := Node3D.new()
		bar.rotation.z = PI / float(count)
		bar.add_child(_inside(Kit.box(Vector3(0.4, 1.0, length * 0.9), lamp, Vector3(hall_r - 0.3, 0, mid))))
		holder.add_child(bar)
		# The cradle's number on the wall by it.
		var num := Label3D.new()
		num.text = str(i + 1)
		num.font_size = 128
		num.pixel_size = 0.05
		num.modulate = Color("d8b02a")
		num.position = Vector3(hall_r - 0.4, 0, z1 - 4.0)
		num.rotation = Vector3(0, -PI * 0.5, PI * 0.5)
		num.layers = INTERIOR_LAYER
		num.set_meta("no_merge", true)
		holder.add_child(num)
		rotor.add_child(holder)
	# The hall's lights, down its length near the axis (and the walls catch them).
	for k in 3:
		var l := OmniLight3D.new()
		l.light_color = LAMP
		l.light_energy = 2.2
		l.omni_range = hall_r * 2.4
		l.omni_attenuation = 0.8
		l.position = Vector3(0, 0, z0 + length * (float(k) + 0.5) / 3.0)
		rotor.add_child(l)
		lights.append(l)
	return angles


## A piece of the interior: on the interior layer, kept out of the merge (which would
## put it back on the default layer).
static func _inside(mi: MeshInstance3D) -> MeshInstance3D:
	mi.layers = INTERIOR_LAYER
	mi.set_meta("no_merge", true)
	return mi


## A light from outside (the Sun, planetshine) leaves bay interiors alone.
## Also the cockpit cabin's layer (flight_deck.gd CABIN_LAYER, 4): it has its own sun.
static func shade_interior(light: Light3D) -> void:
	light.light_cull_mask &= ~(INTERIOR_LAYER | 4)


## The doors, built shut; set_open moves them.
static func _doors(bay: Dictionary, holder: Node3D, mats: Dictionary) -> void:
	var r: float = bay["r"]
	var z: float = bay["z_mouth"] + 1.3
	var leaf_mat: Material = Kit.mat("grey")
	var leaves: Array = bay["leaves"]
	match bay["door"]:
		"iris":
			# Overlapping blades just behind the bay's face, each on a pivot at the rim.
			# Shut, they swing in across the mouth; open, each lies along the rim inside
			# the wall, out of sight behind the face.
			var blades := 12
			var width := r * 0.45
			var length := r * 1.05
			# The housing: a flange at the mouth, wide enough to hide the open blades.
			var reach := Vector2(r + 0.4 + width, length).length() + 1.0
			if reach > float(bay["outer"]):
				var z1: float = bay["z_mouth"]
				var flange := [
					PackedVector2Array([Vector2(reach, z1 - IRIS_FLANGE_M), Vector2(reach, z1)]),
					PackedVector2Array([Vector2(reach, z1), Vector2(float(bay["outer"]) - 0.1, z1)]),
					PackedVector2Array([Vector2(float(bay["outer"]) - 0.1, z1 - IRIS_FLANGE_M), Vector2(reach, z1 - IRIS_FLANGE_M)]),
				]
				holder.add_child(Kit.lathe(flange, mats["hull"], 64))
				holder.add_child(Kit.hazard_band(reach - 0.6, 0.5, Vector3(0, 0, z1 + 0.05), 40))
				bay["flange"] = reach
			for i in blades:
				var a := TAU * float(i) / float(blades)
				var pivot := Node3D.new()
				pivot.position = Vector3(cos(a), sin(a), 0.0) * (r + 0.4) + Vector3(0, 0, bay["z_mouth"] - 0.4 - float(i % 2) * 0.3)
				pivot.set_meta("base", a)
				pivot.add_child(Kit.box(Vector3(width, length, 0.25), Kit.mat("yellow") if i % 2 == 0 else leaf_mat, Vector3(width * 0.5, length * 0.5, 0)))
				holder.add_child(pivot)
				leaves.append(pivot)
		"clamshell":
			# Two leaves hinged top and bottom, folding outward like a hangar's.
			for side in [-1.0, 1.0]:
				var hinge := Node3D.new()
				hinge.position = Vector3(0, side * (r + 0.4), z)
				hinge.set_meta("side", side)
				hinge.add_child(Kit.box(Vector3(2.0 * r + 1.2, r + 0.4, 0.7), leaf_mat, Vector3(0, -side * (r + 0.4) * 0.5, 0)))
				for k in 4:
					hinge.add_child(Kit.box(Vector3(2.0 * r + 1.2, 0.35, 0.3), Kit.mat("yellow") if k % 2 == 0 else mats["dark"], Vector3(0, -side * (1.6 + float(k) * r * 0.22), 0.45)))
				for x in [-r * 0.6, 0.0, r * 0.6]:
					hinge.add_child(Kit.cylinder(0.7, 2.0, Kit.mat("steel"), Vector3(x, 0, 0)))
				holder.add_child(hinge)
				leaves.append(hinge)
		_:
			# Two leaves running apart in tracks across the face.
			for y in [r + 1.4, -(r + 1.4)]:
				holder.add_child(Kit.box(Vector3(4.0 * r + 4.0, 1.4, 1.2), mats["dark"], Vector3(0, y, z - 0.4)))
			for side in [-1.0, 1.0]:
				var leaf := Node3D.new()
				leaf.set_meta("side", side)
				leaf.add_child(Kit.box(Vector3(r + 0.4, 2.0 * r + 1.6, 0.8), leaf_mat, Vector3(0, 0, z + 0.3)))
				for k in 4:
					leaf.add_child(Kit.box(Vector3(0.45, 2.0 * r + 1.6, 0.25), Kit.mat("yellow") if k % 2 == 0 else mats["dark"], Vector3(-side * (r * 0.5 - 0.5 - float(k) * 0.7), 0, z + 0.8)))
				holder.add_child(leaf)
				leaves.append(leaf)


## Doors at `open` (0 shut, 1 open).
static func set_open(bay: Dictionary, open: float) -> void:
	open = clampf(open, 0.0, 1.0)
	var moving := absf(open - float(bay.get("open", -1.0))) > 1e-4 and open > 0.0 and open < 1.0
	bay["open"] = open
	var r: float = bay["r"]
	var e := open * open * (3.0 - 2.0 * open)
	for leaf in bay["leaves"]:
		var n: Node3D = leaf
		match bay["door"]:
			"iris":
				# Open: the blade's length runs along the rim, its width out into the wall.
				# Shut: turned in so its length crosses the mouth.
				n.rotation.z = float(n.get_meta("base")) + (1.0 - e) * (PI * 0.5 - 0.3)
			"clamshell":
				n.rotation.x = -float(n.get_meta("side")) * e * deg_to_rad(105.0)
			_:
				n.position.x = float(n.get_meta("side")) * (r * 0.5 + 0.2 + e * (r + 1.2))
	for w in bay.get("warn", []):
		(w as Node3D).visible = moving


## The doors are out of the way.
static func is_open(bay: Dictionary) -> bool:
	return float(bay.get("open", 0.0)) >= 0.999


## Contact of a sphere (centre p, radius rad, station frame) with the bay: [depth,
## normal], depth 0 if none. Inside the tunnel the walls and back wall hold it (and
## the doors, once shut); outside, the module is solid, the mouth open only when the
## doors are.
static func contact(bay: Dictionary, p: Vector3, rad: float) -> Array:
	var r: float = bay["r"]
	var outer: float = bay["outer"]
	var z0: float = bay["z_back"]
	var z1: float = bay["z_mouth"]
	var rxy := Vector2(p.x, p.y).length()
	var radial := Vector3(p.x, p.y, 0.0).normalized() if rxy > 1e-4 else Vector3.RIGHT
	# An iris's housing flange widens the module at the mouth.
	if p.z > z1 - IRIS_FLANGE_M - rad:
		outer = maxf(outer, float(bay.get("flange", outer)))
	if p.z > z1 + rad or p.z < z0 - rad or rxy > outer + rad:
		return [0.0, Vector3.ZERO]
	var open := is_open(bay)
	# In the hall: its long wall, its back wall, and its front wall round the tunnel.
	var hall_r := float(bay.get("hall_r", r))
	var zh := float(bay.get("z_hall", z0))
	if zh > z0 and rxy < hall_r and p.z > z0 and p.z < zh:
		var best := [0.0, Vector3.ZERO]
		var wall := rxy + rad - hall_r
		if wall > 0.0:
			best = [wall, -radial]
		var back := z0 + rad - p.z
		if back > float(best[0]):
			best = [back, Vector3(0, 0, 1)]
		if rxy + rad > r:
			var front := p.z + rad - zh
			if front > float(best[0]):
				best = [front, Vector3(0, 0, -1)]
		return best
	var has_hall := zh > z0
	z0 = zh
	var inside := rxy < r and p.z < z1 and p.z > z0
	if inside:
		var best := [0.0, Vector3.ZERO]
		var wall := rxy + rad - r
		if wall > 0.0:
			best = [wall, -radial]
		# A tunnel alone ends at its back wall; with a hall, it opens into it.
		var back := z0 + rad - p.z
		if not has_hall and back > float(best[0]):
			best = [back, Vector3(0, 0, 1)]
		if not open:
			var front := p.z + rad - z1
			if front > float(best[0]):
				best = [front, Vector3(0, 0, -1)]
		return best
	if open and rxy < r:
		# In front of the open mouth: only the rim can be touched.
		if rxy + rad > r and p.z - rad < z1:
			var into_rim := rxy + rad - r
			var into_face := z1 + rad - p.z
			return [into_face, Vector3(0, 0, 1)] if into_face < into_rim else [into_rim, -radial]
		return [0.0, Vector3.ZERO]
	# The solid module (or the shut doors across the mouth).
	var into_side := outer + rad - rxy
	var into_front := z1 + rad - p.z
	var d := minf(into_side, into_front)
	return [d, radial if d == into_side else Vector3(0, 0, 1)]
