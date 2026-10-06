## The Kestrel: a surface transporter built on an open spine, in the spirit of the
## Space: 1999 Eagle (the shape the owner grew up with). It's our own design, not a
## copy. Everything hangs off the spine:
##   - the command module forward: an angular nose with wraparound windows
##   - four leg pods at the corners, each with a lift thruster firing down and a
##     sprung landing leg: an outrigger strut, a telescopic shock absorber, and a
##     ball-jointed footpad
##   - the passenger or cargo pod slung underneath, swappable on the pad
##   - the service module aft: propellant spheres and four main engines
## So it can set down on any airless body that will take its weight.
##
## build() returns the ship model dictionary ship_builder.gd does ({node, nose_z,
## radius, length, rig}) plus "legs" for the landing gear (see compress()) and "lift",
## the lift thrusters' glow (shown while hovering or descending). `scale` shrinks the
## whole craft (the Bramble lander is a small Kestrel).
extends RefCounted

const Kit := preload("res://view/flight/kit.gd")
const Livery := preload("res://view/flight/livery.gd")
const ShipBuilder := preload("res://view/flight/ship_builder.gd")
const HullKit := preload("res://view/flight/hull_kit.gd")
const EXHAUST := "res://view/shaders/exhaust.gdshader"

const LENGTH := 23.0


static func build(livery: Dictionary, scale: float = 1.0, payload: String = "passenger") -> Dictionary:
	var mats: Dictionary = livery["mats"]
	var hull: Material = mats["hull"]
	var accent: Material = mats["accent"]
	var steel: Material = mats["steel"]
	var dark: Material = mats["dark"]
	var root := Node3D.new()
	var frame := Node3D.new()
	frame.scale = Vector3.ONE * scale
	root.add_child(frame)
	var rig := {"arrays": [], "dish": {}, "rcs": []}
	var spine_y := 1.1
	var spine_from := -7.2
	var spine_to := 8.4

	# --- the spine: an open box truss, the craft's backbone -----------------------
	var w := 0.8
	for x in [-w, w]:
		for y in [-w * 0.6, w * 0.6]:
			frame.add_child(_rod(Vector3(x, spine_y + y, spine_from), Vector3(x, spine_y + y, spine_to), 0.07, steel))
	var bays := 12
	for i in bays + 1:
		var z := lerpf(spine_from, spine_to, float(i) / float(bays))
		frame.add_child(Kit.box(Vector3(w * 2.0 + 0.1, 0.08, 0.08), steel, Vector3(0, spine_y + w * 0.6, z)))
		frame.add_child(Kit.box(Vector3(w * 2.0 + 0.1, 0.08, 0.08), steel, Vector3(0, spine_y - w * 0.6, z)))
		frame.add_child(Kit.box(Vector3(0.08, w * 1.2, 0.08), steel, Vector3(-w, spine_y, z)))
		frame.add_child(Kit.box(Vector3(0.08, w * 1.2, 0.08), steel, Vector3(w, spine_y, z)))
		if i < bays:
			var z2 := lerpf(spine_from, spine_to, float(i + 1) / float(bays))
			var s := 1.0 if i % 2 == 0 else -1.0
			frame.add_child(_rod(Vector3(-w, spine_y - w * 0.6 * s, z), Vector3(-w, spine_y + w * 0.6 * s, z2), 0.04, steel))
			frame.add_child(_rod(Vector3(w, spine_y + w * 0.6 * s, z), Vector3(w, spine_y - w * 0.6 * s, z2), 0.04, steel))
	# Service ducts and cable runs along the spine.
	frame.add_child(_rod(Vector3(0.35, spine_y + 0.2, spine_from), Vector3(0.35, spine_y + 0.2, spine_to), 0.09, mats["foil"]))
	frame.add_child(_rod(Vector3(-0.3, spine_y - 0.25, spine_from), Vector3(-0.3, spine_y - 0.25, spine_to), 0.06, accent))

	# --- the command module: an angular nose, a cabin, a hatch on top -------------
	var cab := Node3D.new()
	cab.position = Vector3(0, spine_y, -9.2)
	frame.add_child(cab)
	# Octagonal cabin barrel, then the faceted nose.
	cab.add_child(_prism(1.45, 2.6, 8, hull, Vector3(0, 0, 0.6)))
	var nose := _frustum(1.45, 0.55, 1.9, 8, hull, Vector3(0, -0.12, -1.55))
	cab.add_child(nose)
	# The wraparound windows across the nose's upper facets: framed, bolted glass
	# (HullKit.window), the flight deck lit behind it.
	# One pane on each upper facet of the nose (the octagon's facets are centred at
	# 22.5 + 45k degrees), set into the slope, plus a forward pair low on the tip.
	var r_back := 1.45
	var r_front := 0.55
	var nose_len := 1.9
	var tip_z := -1.55 - nose_len * 0.5
	var slope := (r_back - r_front) / nose_len
	for k in 8:
		var a := deg_to_rad(22.5 + 45.0 * float(k))
		if sin(a) < 0.0:
			continue
		var out := Vector3(cos(a), sin(a), 0.0)
		var z := -1.9
		var r_face := lerpf(r_front, r_back, (z - tip_z) / nose_len) * cos(PI / 8.0)
		var normal := (out - Vector3(0, 0, slope)).normalized()
		var at := out * (r_face + 0.03) + Vector3(0, -0.12, z)
		var holder := Node3D.new()
		cab.add_child(holder)
		holder.look_at_from_position(at, at - normal, Vector3(0, 0, 1))
		var pane := HullKit.window(2.0 * r_face * tan(PI / 8.0) * 0.72, 0.5, mats, dark, 0.6, 0.25)
		pane.basis = Basis(Vector3.RIGHT, PI * 0.5)
		holder.add_child(pane)
	cab.add_child(Kit.box(Vector3(2.2, 0.12, 0.12), dark, Vector3(0, 0.98, -0.85)))
	# Hatch and docking collar on top, a neck back to the spine, aerials.
	cab.add_child(Kit.cylinder(0.55, 0.35, steel, Vector3(0, 1.55, 0.7), 16))
	cab.get_child(-1).basis = Basis.IDENTITY
	cab.add_child(Kit.torus(0.55, 0.06, Kit.mat("yellow"), Vector3(0, 1.73, 0.7), 24))
	cab.get_child(-1).basis = Basis.IDENTITY
	cab.add_child(Kit.cylinder(0.75, 1.4, dark, Vector3(0, 0, 2.4), 12))
	cab.add_child(_rod(Vector3(0.9, 0.9, 0.4), Vector3(1.3, 2.0, 1.2), 0.03, steel))
	cab.add_child(_rod(Vector3(-0.9, 0.9, 0.9), Vector3(-1.1, 1.8, 1.6), 0.03, steel))
	# A stripe in the operator's colours round the cabin.
	cab.add_child(_prism(1.47, 0.35, 8, accent, Vector3(0, 0, 1.55)))
	for side in [-1.0, 1.0]:
		frame.add_child(_rcs(Vector3(side * 1.45, spine_y + 0.4, -8.6), Vector3(side, 0.2, 0), mats, rig))
	frame.add_child(Kit.beacon(Color("ff3a2a"), Vector3(-1.5, spine_y, -8.0), 0.14, 1.4, 0.0))
	frame.add_child(Kit.beacon(Color("3aff5a"), Vector3(1.5, spine_y, -8.0), 0.14, 1.4, 0.0))
	# Steerable high-gain dish on a short mast behind the cabin.
	var az := Node3D.new()
	az.position = Vector3(0, spine_y + w * 0.6 + 0.9, -6.2)
	az.set_meta("no_merge", true)
	frame.add_child(_rod(Vector3(0, spine_y + w * 0.6, -6.2), az.position, 0.06, steel))
	az.add_child(Kit.box(Vector3(0.3, 0.22, 0.3), dark))
	var el := Node3D.new()
	el.position = Vector3(0, 0.2, 0)
	az.add_child(el)
	var reflector := HullKit.reflector(0.55, mats)
	reflector.position.z = 0.16
	el.add_child(reflector)
	frame.add_child(az)
	rig["dish"] = {"az": az, "el": el}

	# --- the leg pods: lift thrusters, landing gear --------------------------------
	var legs := []
	var bell_mat: Material = Livery.paint(livery, Color("4a3d32"), {"finish": 1, "metallic": 0.7, "roughness": 0.45})
	var lift := Node3D.new()
	lift.name = "LiftPlume"
	lift.visible = false
	frame.add_child(lift)
	for zi in [-4.6, 4.6]:
		for side in [-1.0, 1.0]:
			var pod := Node3D.new()
			pod.position = Vector3(side * 2.75, spine_y - 0.15, zi)
			frame.add_child(pod)
			# Boxy pod frame, with the lift thruster's bell under it.
			pod.add_child(Kit.box(Vector3(1.9, 1.3, 2.4), hull))
			pod.add_child(Kit.box(Vector3(1.95, 0.25, 2.45), accent, Vector3(0, 0.45, 0)))
			for c in [Vector3(1, 1, 1), Vector3(-1, 1, 1), Vector3(1, -1, 1), Vector3(-1, -1, 1), Vector3(1, 1, -1), Vector3(-1, 1, -1), Vector3(1, -1, -1), Vector3(-1, -1, -1)]:
				pod.add_child(Kit.box(Vector3(0.12, 0.12, 0.12), steel, c * Vector3(0.97, 0.67, 1.22)))
			# Throat at the pod's belly, opening straight down (+Z turned to -Y).
			var down := Basis(Vector3.RIGHT, PI * 0.5)
			var bell := ShipBuilder.small_bell(0.14, 0.42, 0.62, bell_mat, dark)
			bell.position = Vector3(0, -0.68, 0)
			bell.basis = down
			pod.add_child(bell)
			var lift_jet := _jet(0.14, 0.42, 0.62, 5.0, 0.16, float(legs.size()))
			lift_jet.position = pod.position + Vector3(0, -0.68, 0)
			lift_jet.basis = down
			lift.add_child(lift_jet)
			# Outriggers back to the spine.
			for dz in [-0.9, 0.9]:
				frame.add_child(_rod(Vector3(side * 0.85, spine_y + 0.3, zi + dz * 0.6), pod.position + Vector3(-side * 0.95, 0.35, dz), 0.07, steel))
				frame.add_child(_rod(Vector3(side * 0.85, spine_y - 0.4, zi + dz * 0.3), pod.position + Vector3(-side * 0.95, -0.4, dz), 0.06, steel))
			pod.add_child(_rcs(Vector3(side * 0.98, 0.0, -1.0 if zi < 0 else 1.0), Vector3(side, 0, 0), mats, rig))
			# The leg: from the pod's outboard lower corner, out and down to the pad.
			var hip := pod.position + Vector3(side * 0.9, -0.55, 0.0)
			var foot := pod.position + Vector3(side * 2.7, -3.1, 0.0)
			var leg := _leg(hip, foot, side, steel, dark, mats)
			frame.add_child(leg["node"])
			legs.append(leg)

	# --- the payload pod slung beneath the spine ------------------------------------
	var pay := Node3D.new()
	pay.position = Vector3(0, spine_y - 1.85, 0.0)
	frame.add_child(pay)
	pay.add_child(Kit.box(Vector3(2.7, 2.1, 9.4), hull))
	pay.add_child(Kit.box(Vector3(2.75, 0.3, 9.45), accent, Vector3(0, -0.75, 0)))
	for z in [-4.4, -1.5, 1.5, 4.4]:
		pay.add_child(Kit.box(Vector3(2.8, 2.18, 0.12), steel, Vector3(0, 0, z)))
	if payload == "passenger":
		# Windows down both sides, a door each side, a ramp at the back.
		for side in [-1.0, 1.0]:
			for k in 8:
				pay.add_child(Kit.box(Vector3(0.05, 0.35, 0.55), Kit.glow(Color("ffdca0"), 0.6), Vector3(side * 1.36, 0.35, -3.9 + 1.1 * float(k))))
			pay.add_child(Kit.box(Vector3(0.06, 1.5, 1.0), dark, Vector3(side * 1.36, -0.1, 2.9)))
	else:
		for side in [-1.0, 1.0]:
			for k in 3:
				pay.add_child(Kit.box(Vector3(0.05, 1.6, 2.4), Kit.mat("grey"), Vector3(side * 1.36, 0, -3.0 + 3.0 * float(k))))
	pay.add_child(Kit.box(Vector3(2.4, 1.8, 0.08), dark, Vector3(0, -0.05, 4.73)))
	# Clamps to the spine.
	for z in [-3.6, 0.0, 3.6]:
		for x in [-0.6, 0.6]:
			frame.add_child(_rod(Vector3(x, spine_y - w * 0.6, z), Vector3(x * 1.4, spine_y - 0.8, z), 0.08, steel))

	# --- the service module: propellant spheres and the main engines ----------------
	var aft := Node3D.new()
	aft.position = Vector3(0, spine_y, 9.6)
	frame.add_child(aft)
	aft.add_child(Kit.box(Vector3(3.0, 2.4, 2.4), hull))
	aft.add_child(Kit.box(Vector3(3.05, 0.3, 2.45), accent, Vector3(0, 0.75, 0)))
	for c in [Vector3(-1.6, 0.9, -1.4), Vector3(1.6, 0.9, -1.4), Vector3(-1.6, -0.9, -1.4), Vector3(1.6, -0.9, -1.4)]:
		aft.add_child(Kit.sphere(0.62, mats["foil"], c))
		aft.add_child(Kit.torus(0.62, 0.04, steel, c, 24))
	aft.add_child(Kit.cylinder(1.35, 0.25, steel, Vector3(0, 0, 1.3), 24))
	var plume := Node3D.new()
	plume.name = "DrivePlume"
	plume.visible = false
	var k := 0
	for c in [Vector3(-0.62, 0.55, 0), Vector3(0.62, 0.55, 0), Vector3(-0.62, -0.55, 0), Vector3(0.62, -0.55, 0)]:
		# Each chamber: a short barrel, then a hollow bell opening aft, its jet behind it.
		aft.add_child(Kit.cylinder(0.25, 0.5, dark, c + Vector3(0, 0, 1.55), 12))
		var bell := ShipBuilder.small_bell(0.18, 0.5, 1.1, bell_mat, dark)
		bell.position = c + Vector3(0, 0, 1.8)
		aft.add_child(bell)
		var jet := _jet(0.18, 0.5, 1.1, 9.0, 0.12, 10.0 + float(k))
		jet.position = c + Vector3(0, 0, 1.8)
		plume.add_child(jet)
		k += 1
	aft.add_child(plume)
	for side in [-1.0, 1.0]:
		aft.add_child(_rcs(Vector3(side * 1.55, 0, 0.9), Vector3(side, 0, 0.3), mats, rig))
	frame.add_child(Kit.beacon(Color.WHITE, Vector3(0, spine_y + 1.4, 10.6), 0.14, 1.0, 0.5))
	# A pair of radiator fins on the service module, edge-on to the spine.
	for side in [-1.0, 1.0]:
		aft.add_child(Kit.box(Vector3(0.05, 0.9, 1.4), Livery.paint(livery, Kit.COLOURS["dark"], {"finish": 1, "mismatch": 0.0, "panel_m": 0.3}), Vector3(side * 1.2, 1.65, 0.2)))

	Kit.merge_static(root)
	var s := scale
	return {"node": root, "nose_z": -11.3 * s, "radius": 5.0 * s, "length": LENGTH * s, "rig": rig, "legs": legs, "lift": lift,
		"foot_y": (spine_y - 0.15 - 3.1 - 0.12 - 0.07) * s}


## A chamber's exhaust: the free jet from the lip aft, on the drives' exhaust shader
## (view/shaders/exhaust.gdshader), throat at the origin, opening toward +Z. Short-burn
## chambers burn paler and bluer than the fusion drives' violet.
static func _jet(rt: float, re: float, lb: float, length: float, spread: float, seed: float) -> MeshInstance3D:
	var mat := ShaderMaterial.new()
	mat.shader = load(EXHAUST)
	var w_end := re * 0.55 + length * spread
	for kv in [["rt", rt], ["re", re], ["lb", lb], ["spread", spread], ["fade", lb * 6.0], ["seed", seed], ["brightness", 1.4],
			["z_from", lb], ["z_to", lb + length], ["r_from", re * 0.97], ["r_bound", w_end * 1.8], ["end_fade", length * 0.35],
			["core", Color(0.92, 0.94, 1.0)], ["body", Color(0.55, 0.66, 1.0)], ["tail", Color(0.45, 0.55, 0.95)]]:
		mat.set_shader_parameter(kv[0], kv[1])
	var free := PackedVector2Array([Vector2(0.0, lb), Vector2(re * 0.97, lb), Vector2(w_end * 1.8, lb + length), Vector2(0.0, lb + length)])
	var vol := Kit.lathe([free], mat, 24)
	vol.set_meta("brightness", 1.4)
	vol.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return vol


## A landing leg: outrigger strut from the hip, a telescopic shock absorber (sleeve
## and piston) down to a ball joint, the footpad, and a drag brace. The piston node
## slides up the sleeve as the leg compresses (compress()).
static func _leg(hip: Vector3, foot: Vector3, side: float, steel: Material, dark: Material, mats: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.set_meta("no_merge", true)
	var knee := hip.lerp(foot, 0.42) + Vector3(side * 0.35, 0.25, 0)
	n.add_child(_rod(hip, knee, 0.12, steel))
	n.add_child(Kit.sphere(0.16, dark, knee))
	# Sleeve from the knee toward the foot; the piston carries the pad.
	var axis := (foot - knee).normalized()
	var sleeve_len := (foot - knee).length() * 0.55
	n.add_child(_rod(knee, knee + axis * sleeve_len, 0.15, mats["hull"]))
	n.add_child(_rod(knee + axis * sleeve_len * 0.9, knee + axis * sleeve_len, 0.17, mats["accent"]))
	var piston := Node3D.new()
	piston.position = knee
	n.add_child(piston)
	var travel := (foot - knee).length()
	piston.add_child(_rod(axis * sleeve_len * 0.5, axis * travel, 0.09, Kit.paint(Color("c9c9c4"), {"finish": 1, "metallic": 0.9, "roughness": 0.2, "wear": 0.05, "mismatch": 0.0})))
	piston.add_child(Kit.sphere(0.14, dark, axis * travel))
	# Footpad: a shallow dish, level with the ground.
	var pad := Kit.cylinder(0.75, 0.14, mats["hull"], axis * travel + Vector3(0, -0.12, 0), 20)
	pad.basis = Basis.IDENTITY
	piston.add_child(pad)
	var rim := Kit.torus(0.75, 0.05, dark, axis * travel + Vector3(0, -0.12, 0), 24)
	rim.basis = Basis.IDENTITY
	piston.add_child(rim)
	# Drag brace from the pod's other corner to the sleeve.
	n.add_child(_rod(hip + Vector3(0, 0.4, 0), knee + axis * sleeve_len * 0.6, 0.06, steel))
	return {"node": n, "piston": piston, "knee": knee, "axis": axis, "travel_max": sleeve_len * 0.45, "compression": 0.0}


## Push each leg in by `metres` (0 = fully extended), clamped to its travel.
static func compress(legs: Array, metres: Array) -> void:
	for i in legs.size():
		var leg: Dictionary = legs[i]
		var c := clampf(float(metres[i] if i < metres.size() else 0.0), 0.0, float(leg["travel_max"]))
		leg["compression"] = c
		(leg["piston"] as Node3D).position = (leg["knee"] as Vector3) - (leg["axis"] as Vector3) * c


static func _rod(a: Vector3, b: Vector3, r: float, material: Material, sides: int = 8) -> MeshInstance3D:
	var d := b - a
	var mi := Kit.cylinder(r, d.length(), material, (a + b) * 0.5, sides)
	var up := Vector3.UP if absf(d.normalized().dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	mi.basis = Basis.looking_at(d.normalized(), up) * Basis(Vector3.RIGHT, -PI * 0.5)
	return mi


## An n-sided prism along Z (radius to the corners, length), flat faces for an
## engineered look rather than a turned one.
static func _prism(r: float, length: float, sides: int, material: Material, at: Vector3) -> MeshInstance3D:
	var mi := Kit.cylinder(r, length, material, at, sides)
	return mi


static func _frustum(r_back: float, r_front: float, length: float, sides: int, material: Material, at: Vector3) -> MeshInstance3D:
	# Kit.cone: r_top at +Z (back toward the cabin), r_bottom at -Z (the nose tip).
	return Kit.cone(r_back, r_front, length, material, at, sides)


static func _rcs(at: Vector3, outward: Vector3, mats: Dictionary, rig: Dictionary) -> Node3D:
	var n := Node3D.new()
	n.position = at
	n.add_child(Kit.box(Vector3(0.32, 0.32, 0.32), mats["dark"]))
	var side := outward.normalized()
	var a := side.cross(Vector3.FORWARD if absf(side.z) < 0.9 else Vector3.UP).normalized()
	for d in [side, a, -a]:
		n.add_child(Kit.box(Vector3(0.11, 0.11, 0.11), Kit.mat("black"), d * 0.22))
	rig["rcs"].append({"node": n, "outward": side})
	return n
