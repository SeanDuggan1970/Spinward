## A small satellite (roadmap step 5): a foil-wrapped bus, a dish and two solar wings
## that unfold from against its sides. Cosmetic variety from a hash of its name.
extends RefCounted

const Kit := preload("res://view/flight/kit.gd")

## Wing panels per side, each this long (metres).
const PANELS := 3
const PANEL_M := 1.4


## {node, hinges: [[node, side, k]]}. Unfold it with unfold().
static func build(name: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name + "|sat")
	var root := Node3D.new()
	var size := Vector3(rng.randf_range(1.0, 1.6), rng.randf_range(1.0, 1.4), rng.randf_range(1.2, 2.0))
	root.add_child(Kit.box(size, Kit.mat("foil")))
	root.add_child(Kit.box(Vector3(size.x * 1.02, 0.12, size.z * 1.02), Kit.mat("dark"), Vector3(0, size.y * 0.5, 0)))
	# The dish on a short mast, and a light so it reads as a star at a distance.
	var dish := Kit.cylinder(size.x * 0.45, 0.08, Kit.mat("offwhite"), Vector3(0, size.y * 0.5 + 0.5, 0), 16)
	dish.rotation_degrees = Vector3.ZERO
	root.add_child(dish)
	root.add_child(Kit.cylinder(0.05, 0.5, Kit.mat("steel"), Vector3(0, size.y * 0.5 + 0.25, 0), 6))
	var light := Kit.beacon(Color("ffd890"), Vector3(0, -size.y * 0.5 - 0.1, 0), 0.12, 1.8, rng.randf())
	root.add_child(light)
	var cells := Kit.paint(Color("1d2b4a"), {"finish": 1, "metallic": 0.35, "roughness": 0.3})
	var hinges := []
	for side in [-1.0, 1.0]:
		var parent: Node3D = root
		for k in PANELS:
			var h := Node3D.new()
			h.position = Vector3(side * (size.x * 0.5 if k == 0 else PANEL_M), 0, 0)
			h.add_child(Kit.box(Vector3(PANEL_M * 0.96, 0.04, size.z * 0.9), cells, Vector3(side * PANEL_M * 0.5, 0, 0)))
			parent.add_child(h)
			hinges.append([h, side, k])
			parent = h
	var model := {"node": root, "hinges": hinges}
	unfold(model, 1.0)
	return model


## 0: wings folded flat against the bus (a stack at each side); 1: spread out.
static func unfold(model: Dictionary, f: float) -> void:
	var e := clampf(f, 0.0, 1.0)
	e = e * e * (3.0 - 2.0 * e)
	for item in model["hinges"]:
		var h: Node3D = item[0]
		var side: float = item[1]
		var k: int = item[2]
		# Folded: the first panel lies down the bus's side, the rest zig-zag on it.
		var folded := -PI * 0.5 if k == 0 else PI * 0.97 * (1.0 if k % 2 == 1 else -1.0)
		h.rotation.z = side * folded * (1.0 - e)
