## The crewed rooms behind a ship's flight deck (modules.json, a command module's look
## "rooms"), nose to tail along +Z, each a pressure can or bay of its own:
##   lounge    galley and lounge: the room with a view, a band of picture windows
##             along its shoulders, the galley's extractor vent underneath
##   quarters  sleeping quarters: a cabin each, a porthole each (some shuttered by
##             whoever's asleep behind it), handrails along the top
##   node      the hub: the EVA airlock to starboard (an outer hatch, a floodlight,
##             handrails), the escape pods docked nose-in to port, ready to go, with
##             their heat shields outward, and external stowage lockers underneath
##   service   an open equipment bay: the battery bank, the ship's computer, and the
##             life support plant (water, air bottles, the CO2 scrubber and recycler,
##             with its own small radiator)
## Built in the ship's materials (ctx, as ship_builder.gd passes it). Returns {node,
## length, radius, anchors}: anchors are the points the ship builder hangs kit on
## ("dish" on the quarters' back, "wings" at the lounge for the housekeeping solar
## wings).
extends RefCounted

const Kit := preload("res://view/flight/kit.gd")
const HullKit := preload("res://view/flight/hull_kit.gd")


static func build(rooms: Array, ctx: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var z := 0.0
	var radius := 0.0
	var anchors := {}
	for room in rooms:
		var r := float(room["radius_m"])
		var l := float(room["length_m"])
		var part: Dictionary
		match String(room["room"]):
			"lounge":
				part = _lounge(r, l, ctx)
			"quarters":
				part = _quarters(r, l, int(room.get("cabins", 6)), ctx)
			"node":
				part = _node(r, l, int(room.get("escape_pods", 2)), ctx)
			_:
				part = _service(r, l, ctx)
		var p: Node3D = part["node"]
		p.position.z = z
		n.add_child(p)
		for k in part.get("anchors", {}):
			anchors[k] = (part["anchors"][k] as Vector3) + Vector3(0, 0, z)
		radius = maxf(radius, float(part["radius"]))
		z += l
	return {"node": n, "length": z, "radius": radius, "anchors": anchors}


## Something on the hull at angle `a` round the Z axis, its +Y turned outward.
static func _on_hull(node: Node3D, a: float, r: float, z: float) -> Node3D:
	node.basis = Basis(Vector3.BACK, a - PI * 0.5)
	node.position = Vector3(cos(a), sin(a), 0.0) * r + Vector3(0, 0, z)
	return node


## A can from z = 0 to l: the barrel, steel frame rings at the joints, a livery band.
static func _can(r: float, l: float, ctx: Dictionary, band_at: float) -> Node3D:
	var mats: Dictionary = ctx["mats"]
	var n := Node3D.new()
	n.add_child(Kit.cylinder(r, l, mats["hull"], Vector3(0, 0, l * 0.5), 28))
	for f in [0.0, 1.0]:
		n.add_child(Kit.torus(r + 0.02, 0.13, mats["steel"], Vector3(0, 0, l * f), 28))
	n.add_child(Kit.cylinder(r + 0.03, 0.5, mats["accent"], Vector3(0, 0, l * band_at), 28))
	return n


static func _lounge(r: float, l: float, ctx: Dictionary) -> Dictionary:
	var mats: Dictionary = ctx["mats"]
	var n := _can(r, l, ctx, 0.12)
	# Picture windows: a band of tall panes along each shoulder, warm light behind.
	for a in [deg_to_rad(40.0), deg_to_rad(140.0)]:
		for k in 4:
			var pane := HullKit.window(0.95, l * 0.17, mats, mats["dark"], 0.75, 0.25)
			n.add_child(_on_hull(pane, a, r + 0.02, l * (0.3 + 0.17 * k)))
	# The galley's extractor vent and grille underneath, and a hatch to the lounge.
	var vent := Node3D.new()
	vent.add_child(Kit.box(Vector3(1.1, 0.18, 1.4), mats["dark"]))
	for k in 6:
		vent.add_child(Kit.box(Vector3(1.0, 0.06, 0.06), mats["steel"], Vector3(0, 0.1, -0.55 + 0.22 * k)))
	n.add_child(_on_hull(vent, -PI * 0.5, r, l * 0.55))
	for a in [deg_to_rad(80.0), deg_to_rad(100.0)]:
		var d := Vector3(cos(a), sin(a), 0.0)
		n.add_child(HullKit.handrail(d * r + Vector3(0, 0, l * 0.08), d * r + Vector3(0, 0, l * 0.92), d))
	return {"node": n, "radius": r + 0.3, "anchors": {"wings": Vector3(r, 0, l * 0.5)}}


static func _quarters(r: float, l: float, cabins: int, ctx: Dictionary) -> Dictionary:
	var mats: Dictionary = ctx["mats"]
	var rng: RandomNumberGenerator = ctx["rng"]
	var n := _can(r, l, ctx, 0.9)
	# A cabin each side per bay, a porthole each; some sleeping, shutters down.
	var per_side := maxi(1, cabins / 2)
	for side in [0.0, PI]:
		for k in per_side:
			var z := l * (0.15 + 0.7 * (float(k) + 0.5) / float(per_side))
			n.add_child(_on_hull(HullKit.porthole(0.24, mats, mats["dark"], rng.randf() < 0.35, 0.65), side + deg_to_rad(10.0), r + 0.01, z))
			# Each cabin's air and power service panel below its window.
			var panel := HullKit.access_panel(0.5, 0.7, mats["hull"] if rng.randf() < 0.6 else Kit.mat("grey"))
			n.add_child(_on_hull(panel, side - deg_to_rad(28.0) * (1.0 if side == 0.0 else -1.0), r, z))
	for a in [deg_to_rad(70.0), deg_to_rad(110.0), deg_to_rad(250.0), deg_to_rad(290.0)]:
		var d := Vector3(cos(a), sin(a), 0.0)
		n.add_child(HullKit.handrail(d * r + Vector3(0, 0, l * 0.06), d * r + Vector3(0, 0, l * 0.94), d))
	return {"node": n, "radius": r + 0.3, "anchors": {"dish": Vector3(0, r, l * 0.5)}}


static func _node(r: float, l: float, pods: int, ctx: Dictionary) -> Dictionary:
	var mats: Dictionary = ctx["mats"]
	var n := Node3D.new()
	var mid := l * 0.5
	n.add_child(Kit.cylinder(r * 0.8, l, mats["hull"], Vector3(0, 0, mid), 24))
	n.add_child(Kit.sphere(r, mats["hull"], Vector3(0, 0, mid)))
	n.add_child(Kit.torus(r * 0.8 + 0.02, 0.12, mats["steel"], Vector3(0, 0, 0.05), 24))
	n.add_child(Kit.torus(r * 0.8 + 0.02, 0.12, mats["steel"], Vector3(0, 0, l - 0.05), 24))
	var reach := r
	# The airlock, to starboard: a can out from the node with the outer hatch at its end.
	var lock := Node3D.new()
	var lock_l := 2.4
	lock.add_child(Kit.cylinder(0.95, lock_l, mats["hull"], Vector3(0, 0, lock_l * 0.5), 20))
	lock.add_child(Kit.torus(0.97, 0.1, mats["steel"], Vector3(0, 0, 0.1), 20))
	lock.add_child(Kit.hazard_band(0.97, 0.35, Vector3(0, 0, lock_l - 0.35), 12))
	var outer := HullKit.hatch(1.0, 1.2, mats)
	outer.basis = Basis(Vector3.RIGHT, PI * 0.5)
	outer.position.z = lock_l + 0.02
	lock.add_child(outer)
	lock.add_child(Kit.nav_light(Color("fff4d6"), Vector3(0, 1.0, lock_l - 0.3), Vector3(0, 0.6, 1.0), 0.13))
	for a in [deg_to_rad(60.0), deg_to_rad(240.0)]:
		var d := Vector3(cos(a), sin(a), 0.0)
		lock.add_child(HullKit.handrail(d * 0.95 + Vector3(0, 0, 0.3), d * 0.95 + Vector3(0, 0, lock_l - 0.2), d))
	lock.basis = Basis(Vector3.UP, PI * 0.5)
	lock.position = Vector3(r * 0.75, 0, mid)
	n.add_child(lock)
	reach = maxf(reach, r * 0.75 + lock_l + 0.2)
	# Escape pods to port, nose-in on short tunnels, heat shields out: two capsules
	# that can take the whole crew home.
	for k in pods:
		var a := PI + (float(k) - float(pods - 1) * 0.5) * deg_to_rad(50.0)
		var d := Vector3(cos(a), sin(a), 0.0)
		var pod := Node3D.new()
		pod.add_child(Kit.cylinder(0.55, 0.7, mats["steel"], Vector3(0, 0, 0.35), 16))
		pod.add_child(Kit.cone(1.15, 0.6, 1.9, Kit.mat("offwhite"), Vector3(0, 0, 0.7 + 0.95), 20))
		pod.add_child(Kit.cylinder(1.18, 0.28, Kit.mat("dark"), Vector3(0, 0, 0.7 + 1.9 + 0.14), 20))
		pod.add_child(Kit.cylinder(1.0, 0.3, Kit.mat("orange"), Vector3(0, 0, 0.7 + 1.1), 20))
		pod.add_child(Kit.beacon(Color("ff9a2a"), Vector3(0.82, 0, 1.15), 0.12, 1.2, 0.5 * k))
		pod.basis = Basis.looking_at(-d, Vector3.BACK)
		pod.position = d * r * 0.9 + Vector3(0, 0, mid)
		n.add_child(pod)
		reach = maxf(reach, r * 0.9 + 0.7 + 1.9 + 0.3)
	# Stowage lockers underneath: two rows, latched, each with its tag.
	var lockers := Node3D.new()
	for row in 2:
		for k in 3:
			var at := Vector3((float(row) - 0.5) * 0.85, 0.3, (float(k) - 1.0) * 0.8)
			lockers.add_child(Kit.box(Vector3(0.75, 0.55, 0.7), mats["dark"] if (row + k) % 2 == 0 else Kit.mat("grey"), at))
			lockers.add_child(Kit.box(Vector3(0.3, 0.06, 0.06), Kit.mat("yellow"), at + Vector3(0, 0.3, 0.2)))
	n.add_child(_on_hull(lockers, -PI * 0.5, r * 0.78, mid))
	return {"node": n, "radius": reach}


static func _service(r: float, l: float, ctx: Dictionary) -> Dictionary:
	var mats: Dictionary = ctx["mats"]
	var rng: RandomNumberGenerator = ctx["rng"]
	var n := Node3D.new()
	# An open bay: longerons between two ring frames, the crew tunnel through the middle.
	n.add_child(Kit.cylinder(0.75, l, mats["hull"], Vector3(0, 0, l * 0.5), 16))
	for f in [0.05, 0.95]:
		n.add_child(Kit.torus(r, 0.12, mats["steel"], Vector3(0, 0, l * f), 28))
	for k in 8:
		var a := TAU * float(k) / 8.0 + PI / 8.0
		var d := Vector3(cos(a), sin(a), 0.0)
		n.add_child(HullKit.bar(d * r + Vector3(0, 0, l * 0.05), d * r + Vector3(0, 0, l * 0.95), 0.07, mats["steel"]))
	# The battery bank, up top: rows of cells with cooling fins and warning tags.
	for row in 2:
		for k in 3:
			var at := Vector3((float(row) - 0.5) * 0.7, r * 0.62, l * (0.25 + 0.25 * k))
			n.add_child(Kit.box(Vector3(0.6, 0.55, 0.75), mats["dark"], at))
			for f in 3:
				n.add_child(Kit.box(Vector3(0.62, 0.04, 0.04), mats["steel"], at + Vector3(0, 0.29, -0.25 + 0.25 * f)))
			n.add_child(Kit.box(Vector3(0.2, 0.02, 0.12), Kit.mat("yellow"), at + Vector3(0, 0.29, 0.3)))
	# The ship's computer, underneath: a racked core with vents and its status lamps.
	var core_at := Vector3(0, -r * 0.6, l * 0.5)
	n.add_child(Kit.box(Vector3(1.3, 0.8, l * 0.6), mats["dark"], core_at))
	for k in 5:
		n.add_child(Kit.box(Vector3(1.2, 0.05, 0.05), mats["steel"], core_at + Vector3(0, -0.42, -l * 0.25 + l * 0.12 * k)))
	for k in 6:
		var lamp := Kit.glow(Color("4ad6ff") if rng.randf() < 0.7 else Color("58ff7a"), 2.5)
		n.add_child(Kit.box(Vector3(0.06, 0.06, 0.06), lamp, core_at + Vector3(0.66, 0.2 - 0.08 * (k % 3), -0.3 + 0.3 * (k / 3))))
	# Life support, to starboard: the water tank, air bottles, scrubber and recycler.
	n.add_child(Kit.sphere(0.75, mats["foil"], Vector3(r * 0.62, 0.15, l * 0.3)))
	for k in 2:
		var bottle := HullKit.vessel(0.28, 1.6, Kit.mat("grey") if k == 0 else Kit.mat("offwhite"), mats, 12)
		bottle["node"].position = Vector3(r * 0.6, -0.55 + 0.6 * k, l * 0.68)
		n.add_child(bottle["node"])
	n.add_child(Kit.box(Vector3(0.7, 0.9, 0.9), mats["hull"], Vector3(r * 0.55, -0.7, l * 0.3)))
	# Its own small fixed radiator, to port, for the plant's low-grade heat.
	var fin := Kit.box(Vector3(1.8, 0.05, l * 0.7), Kit.mat("dark"), Vector3(-(r + 0.9), 0, l * 0.5))
	n.add_child(fin)
	n.add_child(HullKit.bar(Vector3(-r * 0.8, 0, l * 0.5), Vector3(-r - 0.05, 0, l * 0.5), 0.08, mats["steel"]))
	return {"node": n, "radius": r + 1.9}
