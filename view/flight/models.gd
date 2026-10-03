## Builds ship and station models from the same data the sim uses, so fitting a
## new module visibly changes the ship. Ship forward is -Z; station axis is Z with
## its docking port facing +Z.
extends RefCounted

const Kit := preload("res://view/flight/kit.gd")
const Livery := preload("res://view/flight/livery.gd")
const ShipBuilder := preload("res://view/flight/ship_builder.gd")


## Returns {node, nose_z, radius, length}. nose_z is the docking collar's local Z
## (negative = forward). livery: a scheme from view/flight/livery.gd. The layout is in
## view/flight/ship_builder.gd: crew forward, cargo amidships, drives aft.
static func ship(ship_state: Dictionary, data, livery: Dictionary = {}) -> Dictionary:
	if livery.is_empty():
		livery = Livery.for_ship(data, "", ship_state.get("name", ship_state["hull"]))
	return ShipBuilder.build(ship_state, data, livery)


## Returns {node, rotor, port_z, port_radius, hub_radius, hub_length, ring_radius, ring_tube,
## lights, colliders}. colliders: {"cylinders": [[radius, z_min, z_max]], "tori": [[radius, tube]]},
## all about the Z axis. station.type "wheel" is a hub, spokes and ring; "cylinder" is a
## settlement drum with an axial docking nub on its forward cap.
static func station(geom: Dictionary, name: String = "", livery: Dictionary = {}) -> Dictionary:
	var colour: String = geom.get("colour", "offwhite")
	var hull_mat: Material = livery["mats"]["hull"] if not livery.is_empty() else Kit.mat(colour)
	var accent_mat: Material = livery["mats"]["accent"] if not livery.is_empty() else Kit.mat("orange")
	var steel: Material = livery["mats"]["steel"] if not livery.is_empty() else Kit.mat("steel")
	var root := Node3D.new()
	var rotor := Node3D.new()
	root.add_child(rotor)
	var rh := float(geom["hub_radius_m"])
	var lh := float(geom["hub_length_m"])
	var rr := float(geom.get("ring_radius_m", 0.0))
	var rt := float(geom.get("ring_tube_m", 0.0))
	var pr := float(geom.get("port_radius_m", minf(rh * 0.45, 8.0)))
	var colliders := {"cylinders": [], "tori": []}
	var face_z := lh * 0.5
	if geom.get("type", "wheel") == "cylinder":
		# Settlement drum: plain hull with stiffening bands, end-cap rings, radiator fins aft.
		rotor.add_child(Kit.cylinder(rh, lh, hull_mat, Vector3.ZERO, 64))
		for f in [-0.36, -0.12, 0.12, 0.36]:
			rotor.add_child(Kit.torus(rh + 0.6, 1.2, Kit.mat("grey"), Vector3(0, 0, lh * f), 96))
		for side in [1.0, -1.0]:
			rotor.add_child(Kit.torus(rh * 0.7, 2.5, steel, Vector3(0, 0, side * (lh * 0.5 + 0.5)), 72))
			rotor.add_child(Kit.hazard_band(rh + 0.3, 6.0, Vector3(0, 0, side * (lh * 0.5 - 4.0)), 64))
		for i in 8:
			var a := TAU * float(i) / 8.0
			var fin := Kit.box(Vector3(1.0, rh * 0.5, 60.0), Kit.mat("dark"), Vector3(cos(a) * rh * 0.55, sin(a) * rh * 0.55, -lh * 0.5 - 30.0))
			fin.rotation.z = a + PI * 0.5
			rotor.add_child(fin)
		# Running lights along the hull so the drum reads at a distance.
		for i in 12:
			var a := TAU * float(i) / 12.0
			rotor.add_child(Kit.beacon(Color("ffdca0"), Vector3(cos(a) * (rh + 1.0), sin(a) * (rh + 1.0), 0), 1.2))
		# Forward end cap: radial stiffeners, structural rings and lit observation ports,
		# so a 500 m disc reads as engineering rather than a blank plate.
		var cap_z := lh * 0.5 + 0.4
		for i in 16:
			var a := TAU * float(i) / 16.0
			var rib := Kit.box(Vector3(rh * 0.82, 3.0, 2.0), Kit.mat("grey"), Vector3(cos(a) * rh * 0.55, sin(a) * rh * 0.55, cap_z))
			rib.rotation.z = a
			rotor.add_child(rib)
		for f in [0.3, 0.62, 0.93]:
			rotor.add_child(Kit.torus(rh * f, 2.0, Kit.mat("steel"), Vector3(0, 0, cap_z + 0.5), 72))
		for i in 32:
			var a := TAU * (float(i) + 0.5) / 32.0
			rotor.add_child(Kit.box(Vector3(9.0, 4.0, 0.6), Kit.glow(Color("ffdca0"), 1.6), Vector3(cos(a) * rh * 0.78, sin(a) * rh * 0.78, cap_z + 0.6)))
		# Axial docking nub standing off the forward cap.
		rotor.add_child(Kit.cylinder(pr * 1.6, 12.0, Kit.mat("grey"), Vector3(0, 0, lh * 0.5 + 6.0)))
		colliders["cylinders"].append([rh, -lh * 0.5, lh * 0.5])
		colliders["cylinders"].append([pr * 1.6, lh * 0.5, lh * 0.5 + 12.0])
		face_z = lh * 0.5 + 12.0
	else:
		rotor.add_child(Kit.cylinder(rh, lh, hull_mat, Vector3.ZERO, 28))
		# The operator's colours round the hub's waist.
		rotor.add_child(Kit.cylinder(rh + 0.08, lh * 0.12, accent_mat, Vector3(0, 0, lh * 0.1), 28))
		rotor.add_child(Kit.hazard_band(rh + 0.05, 2.5, Vector3(0, 0, lh * 0.5 - 2.0), 24))
		rotor.add_child(Kit.hazard_band(rh + 0.05, 2.5, Vector3(0, 0, -lh * 0.5 + 2.0), 24))
		rotor.add_child(Kit.torus(rr, rt, hull_mat, Vector3.ZERO, 72))
		var spokes := int(geom.get("spokes", 4))
		for i in spokes:
			var a := TAU * float(i) / float(spokes)
			var spoke := Kit.truss(rr - rh - rt * 0.6, 3.0, steel)
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
		# Solar arrays off the back of the hub.
		for side in [1.0, -1.0]:
			rotor.add_child(Kit.box(Vector3(rr * 0.9, 0.2, 10.0), Kit.mat("dark"), Vector3(side * (rh + rr * 0.45), 0, -lh * 0.5 + 6.0)))
		# Port collar on the hub's forward face.
		rotor.add_child(Kit.cylinder(pr, 3.0, Kit.mat("grey"), Vector3(0, 0, lh * 0.5 + 0.5)))
		colliders["cylinders"].append([rh, -lh * 0.5, lh * 0.5 + 2.0])
		colliders["tori"].append([rr, rt])
		face_z = lh * 0.5 + 2.0
	# Docking port plane just in front of the collar face: keyed slot and guide lights,
	# all spinning with the station.
	var port_z := face_z + 0.2
	rotor.add_child(Kit.torus(pr, 0.4, Kit.mat("yellow"), Vector3(0, 0, port_z), 32))
	rotor.add_child(Kit.box(Vector3(pr * 1.55, 0.8, 0.3), Kit.mat("black"), Vector3(0, 0, port_z)))
	rotor.add_child(Kit.box(Vector3(pr * 1.55, 0.25, 0.32), Kit.mat("yellow"), Vector3(0, 0.55, port_z)))
	var lights := []
	for i in 4:
		var a := TAU * float(i) / 4.0
		var l := Kit.beacon(Color("40ff60"), Vector3(cos(a) * pr * 1.38, sin(a) * pr * 1.38, port_z), 0.45)
		rotor.add_child(l)
		lights.append(l)
	# Stencilled name on the docking face, turning with the station.
	if name != "":
		var stencil := Label3D.new()
		stencil.text = name.to_upper()
		stencil.font_size = 96
		stencil.outline_size = 0
		stencil.modulate = Color("1b1d20") if colour == "offwhite" else Color("e6dcc4")
		stencil.pixel_size = (rh * 0.16 if geom.get("type", "wheel") == "cylinder" else rh * 0.3) / 96.0
		stencil.position = Vector3(0, -(rh * 0.42 if geom.get("type", "wheel") == "cylinder" else rh * 0.72), face_z - (11.4 if geom.get("type", "wheel") == "cylinder" else 1.6))
		stencil.double_sided = false
		rotor.add_child(stencil)
	# Approach corridor: fixed "rabbit" lights stepping in toward the port.
	for i in 10:
		for side in [1.0, -1.0]:
			root.add_child(Kit.beacon(Color("f0a030"), Vector3(0, side * pr * 2.0, port_z + 60.0 * float(i + 1)), 0.6, 2.0, 1.0 - float(i) / 10.0))
	return {"node": root, "rotor": rotor, "port_z": port_z, "port_radius": pr, "hub_radius": rh, "hub_length": lh,
		"ring_radius": rr, "ring_tube": rt, "lights": lights, "colliders": colliders, "type": geom.get("type", "wheel")}


## A station work pod: a one-person cab with a manipulator arm and floodlight,
## the space equivalent of a forklift. Tugs are the same thing with a push frame.
static func work_pod(tug: bool) -> Node3D:
	var root := Node3D.new()
	var body := Vector3(3.2, 2.6, 4.0) if tug else Vector3(2.2, 2.0, 2.6)
	root.add_child(Kit.box(body, Kit.mat("orange" if tug else "yellow")))
	root.add_child(Kit.box(Vector3(body.x * 0.7, body.y * 0.35, 0.1), Kit.glow(Color("ffd890"), 1.2), Vector3(0, body.y * 0.15, -body.z * 0.5 - 0.02)))
	if tug:
		root.add_child(Kit.box(Vector3(body.x + 1.6, 0.3, 0.3), Kit.mat("black"), Vector3(0, -body.y * 0.3, -body.z * 0.5 - 0.6)))
		root.add_child(Kit.box(Vector3(body.x + 1.6, 0.3, 0.3), Kit.mat("yellow"), Vector3(0, body.y * 0.3, -body.z * 0.5 - 0.6)))
	else:
		root.add_child(Kit.box(Vector3(0.25, 0.25, 2.4), Kit.mat("steel"), Vector3(0.7, -0.6, -2.2)))
		root.add_child(Kit.box(Vector3(0.6, 0.6, 0.4), Kit.mat("black"), Vector3(0.7, -0.6, -3.4)))
	root.add_child(Kit.beacon(Color("f0a030"), Vector3(0, body.y * 0.5 + 0.2, 0), 0.22, 1.2, randf()))
	root.add_child(Kit.beacon(Color("ff3a2a"), Vector3(-body.x * 0.5, 0, 0), 0.15, 1.6, 0.0))
	root.add_child(Kit.beacon(Color("3aff5a"), Vector3(body.x * 0.5, 0, 0), 0.15, 1.6, 0.0))
	return root
