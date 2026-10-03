## Builds ship and station models from the same data the sim uses, so fitting a
## new module visibly changes the ship. Ship forward is -Z; station axis is Z with
## its docking port facing +Z.
extends RefCounted

const Kit := preload("res://view/flight/kit.gd")


## Returns {node, nose_z, radius}. nose_z is the docking collar's local Z (negative = forward).
static func ship(ship_state: Dictionary, data) -> Dictionary:
	var root := Node3D.new()
	var spine: Dictionary = data.modules[data.ships[ship_state["hull"]]["spine"]]
	var length := float(spine["look"]["length_m"])
	var width := 1.4
	root.add_child(Kit.truss(length, width, Kit.mat("steel")))
	var mods: Dictionary = ship_state["modules"]
	# Fixed stations along the spine, front to back.
	var z := -length * 0.5
	var nose_z := z
	var radius := 4.0
	for kind in ["command", "cargo", "tank", "drive"]:
		var slots := []
		for slot in mods:
			if slot.begins_with(kind + "."):
				slots.append(slot)
		slots.sort()
		for slot in slots:
			var m: Dictionary = data.modules[mods[slot]]
			var size: Vector3 = Vector3(m["look"]["size_m"][0], m["look"]["size_m"][1], m["look"]["size_m"][2])
			var part := _module_part(m, size)
			if kind == "command":
				part.position.z = z - size.z * 0.5 + 1.0
				nose_z = part.position.z - size.z * 0.5
				# Docking collar and a pair of floodlights on the nose.
				root.add_child(Kit.torus(0.9, 0.18, Kit.mat("yellow"), Vector3(0, 0, nose_z - 0.1), 20))
				root.add_child(Kit.beacon(Color("fff4d6"), Vector3(1.6, 1.4, nose_z + 0.3), 0.18))
				root.add_child(Kit.beacon(Color("fff4d6"), Vector3(-1.6, 1.4, nose_z + 0.3), 0.18))
				z = part.position.z + size.z * 0.5 + 0.6
			elif kind == "drive":
				part.position.z = length * 0.5 + size.z * 0.5 - 1.0
			else:
				part.position.z = z + size.z * 0.5
				z += size.z + 0.5
			radius = maxf(radius, maxf(size.x, size.y) * 0.6)
			root.add_child(part)
	# Radiators hang off the sides of the spine's rear half.
	var r_index := 0
	var r_slots := []
	for slot in mods:
		if slot.begins_with("radiator."):
			r_slots.append(slot)
	r_slots.sort()
	for slot in r_slots:
		var m: Dictionary = data.modules[mods[slot]]
		var size := Vector3(m["look"]["size_m"][0], m["look"]["size_m"][1], m["look"]["size_m"][2])
		var side := 1.0 if r_index % 2 == 0 else -1.0
		var panel := Kit.box(Vector3(size.y, size.x, size.z), Kit.mat("dark"), Vector3(side * (width * 0.5 + size.y * 0.5 + 0.3), 0, length * 0.15))
		root.add_child(panel)
		root.add_child(Kit.box(Vector3(0.6, 0.15, 0.15), Kit.mat("steel"), Vector3(side * (width * 0.5 + 0.3), 0, length * 0.15)))
		radius = maxf(radius, width * 0.5 + size.y + 0.3)
		r_index += 1
	# Navigation lights: red port, green starboard, white strobe aft.
	root.add_child(Kit.beacon(Color("ff3a2a"), Vector3(-width, 0, 0), 0.2, 1.4, 0.0))
	root.add_child(Kit.beacon(Color("3aff5a"), Vector3(width, 0, 0), 0.2, 1.4, 0.0))
	root.add_child(Kit.beacon(Color.WHITE, Vector3(0, width, length * 0.5), 0.2, 1.0, 0.5))
	return {"node": root, "nose_z": nose_z, "radius": radius, "length": length}


static func _module_part(m: Dictionary, size: Vector3) -> Node3D:
	var look: Dictionary = m["look"]
	var colour: String = look.get("colour", "grey")
	match look["shape"]:
		"cage":
			var n := Kit.truss(size.z, size.x, Kit.mat(colour))
			n.add_child(Kit.box(size * 0.8, Kit.mat("rust")))
			return n
		"sphere":
			var n := Node3D.new()
			n.add_child(Kit.sphere(size.x * 0.5, Kit.mat("foil")))
			n.add_child(Kit.torus(size.x * 0.5, 0.08, Kit.mat("steel"), Vector3.ZERO, 32))
			return n
		"cylinder":
			var n := Node3D.new()
			n.add_child(Kit.cylinder(size.x * 0.5, size.z, Kit.mat("foil")))
			n.add_child(Kit.hazard_band(size.x * 0.5 + 0.02, 0.4, Vector3(0, 0, size.z * 0.4), 12))
			return n
		"drive":
			var n := Node3D.new()
			n.add_child(Kit.cylinder(size.x * 0.35, size.z * 0.5, Kit.mat("grey"), Vector3(0, 0, -size.z * 0.2)))
			n.add_child(Kit.cone(size.x * 0.25, size.x * 0.5, size.z * 0.5, Kit.mat("dark"), Vector3(0, 0, size.z * 0.3)))
			var plume := Kit.sphere(size.x * 0.22, Kit.glow(Color("8fd0ff"), 4.0), Vector3(0, 0, size.z * 0.55))
			plume.name = "DrivePlume"
			n.add_child(plume)
			return n
		_:
			var n := Node3D.new()
			n.add_child(Kit.box(size, Kit.mat(colour)))
			# Stencilled edge strip and a couple of handrails: it is a working pod.
			n.add_child(Kit.box(Vector3(size.x + 0.04, 0.3, 0.3), Kit.mat("yellow"), Vector3(0, size.y * 0.5 - 0.15, -size.z * 0.5 + 0.15)))
			n.add_child(Kit.box(Vector3(0.08, 0.08, size.z * 0.7), Kit.mat("orange"), Vector3(size.x * 0.5 + 0.12, 0, 0)))
			n.add_child(Kit.box(Vector3(0.08, 0.08, size.z * 0.7), Kit.mat("orange"), Vector3(-size.x * 0.5 - 0.12, 0, 0)))
			if m["kind"] == "command":
				n.add_child(Kit.box(Vector3(size.x * 0.6, size.y * 0.25, 0.1), Kit.glow(Color("ffd890"), 1.2), Vector3(0, size.y * 0.15, -size.z * 0.5 - 0.02)))
			return n


## Returns {node, rotor, port_z, hub_radius, hub_length, ring_radius, ring_tube, lights}.
static func station(geom: Dictionary) -> Dictionary:
	var root := Node3D.new()
	var rotor := Node3D.new()
	root.add_child(rotor)
	var rh := float(geom["hub_radius_m"])
	var lh := float(geom["hub_length_m"])
	var rr := float(geom["ring_radius_m"])
	var rt := float(geom["ring_tube_m"])
	var colour: String = geom.get("colour", "offwhite")
	rotor.add_child(Kit.cylinder(rh, lh, Kit.mat(colour), Vector3.ZERO, 28))
	rotor.add_child(Kit.hazard_band(rh + 0.05, 2.5, Vector3(0, 0, lh * 0.5 - 2.0), 24))
	rotor.add_child(Kit.hazard_band(rh + 0.05, 2.5, Vector3(0, 0, -lh * 0.5 + 2.0), 24))
	rotor.add_child(Kit.torus(rr, rt, Kit.mat(colour), Vector3.ZERO, 72))
	var spokes := int(geom.get("spokes", 4))
	for i in spokes:
		var a := TAU * float(i) / float(spokes)
		var spoke := Kit.truss(rr - rh - rt * 0.6, 3.0, Kit.mat("steel"))
		spoke.rotation = Vector3(0, PI * 0.5, 0)
		var holder := Node3D.new()
		holder.rotation = Vector3(0, 0, a)
		spoke.position = Vector3((rr + rh) * 0.5, 0, 0)
		holder.add_child(spoke)
		rotor.add_child(holder)
		# Lit windows along the ring between spokes.
		for w in 6:
			var wa := a + TAU / float(spokes) * (float(w) + 1.0) / 7.0
			rotor.add_child(Kit.box(Vector3(1.4, 0.6, 0.2), Kit.glow(Color("ffdca0"), 1.0), Vector3(cos(wa) * (rr + rt * 0.98), sin(wa) * (rr + rt * 0.98), 0)))
	# Docking port: collar on the hub's forward face, with a keyed slot that spins with the station.
	# Collar face sits at lh/2 + 2; the port plane (key slot, guide lights) just in front of it.
	var port_z := lh * 0.5 + 2.2
	rotor.add_child(Kit.cylinder(rh * 0.45, 3.0, Kit.mat("grey"), Vector3(0, 0, lh * 0.5 + 0.5)))
	rotor.add_child(Kit.torus(rh * 0.45, 0.4, Kit.mat("yellow"), Vector3(0, 0, port_z), 32))
	rotor.add_child(Kit.box(Vector3(rh * 0.7, 0.8, 0.3), Kit.mat("black"), Vector3(0, 0, port_z)))
	rotor.add_child(Kit.box(Vector3(rh * 0.7, 0.25, 0.32), Kit.mat("yellow"), Vector3(0, 0.55, port_z)))
	var lights := []
	for i in 4:
		var a := TAU * float(i) / 4.0
		var l := Kit.beacon(Color("40ff60"), Vector3(cos(a) * rh * 0.62, sin(a) * rh * 0.62, port_z), 0.45)
		rotor.add_child(l)
		lights.append(l)
	# Solar arrays and a radiator block off the back of the hub.
	for side in [1.0, -1.0]:
		rotor.add_child(Kit.box(Vector3(rr * 0.9, 0.2, 10.0), Kit.mat("dark"), Vector3(side * (rh + rr * 0.45), 0, -lh * 0.5 + 6.0)))
	# Approach corridor: fixed "rabbit" lights stepping in toward the port.
	for i in 10:
		root.add_child(Kit.beacon(Color("f0a030"), Vector3(0, -rh * 0.9, port_z + 60.0 * float(i + 1)), 0.6, 2.0, 1.0 - float(i) / 10.0))
		root.add_child(Kit.beacon(Color("f0a030"), Vector3(0, rh * 0.9, port_z + 60.0 * float(i + 1)), 0.6, 2.0, 1.0 - float(i) / 10.0))
	return {"node": root, "rotor": rotor, "port_z": port_z, "hub_radius": rh, "hub_length": lh, "ring_radius": rr, "ring_tube": rt, "lights": lights}
