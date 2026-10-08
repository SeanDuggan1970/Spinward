## An elevator climber, after the ISEC and Edwards designs: a truss spine that rides the
## ribbon, a stack of opposed wheel pairs pinching the tape between them (friction
## drive, no capstan), two pods hung either side of the ribbon so the load sits on
## its line, and power from below: a photocell dish catching a beam sent up from the
## foot, or solar wings where the line runs on sunlight.
##
## Local frame: the ribbon runs along +Y through the origin, its thin face along X and
## its width along Z. Sizes are metres for a working climber (about 20 m tall), scaled
## by `scale`.
extends RefCounted

const Kit := preload("res://view/flight/kit.gd")

const WHEEL_PAIRS := 5
const WHEEL_R := 0.55
const WHEEL_PITCH := 1.6


## {node, wheels: [MeshInstance3D], radius: wheel radius}. power: "beam" or "solar".
## drive_only: just the traction head (for the cab you ride in, seen from its window).
static func build(power: String = "beam", livery: String = "yellow", scale: float = 1.0, drive_only: bool = false) -> Dictionary:
	var root := Node3D.new()
	var body := Node3D.new()
	body.scale = Vector3.ONE * scale
	root.add_child(body)
	var frame_mat := Kit.mat(livery)
	var dark := Kit.mat("dark")
	var steel := Kit.mat("steel")
	var wheels := []
	# The traction head: wheel pairs either side of the tape, in a frame that closes
	# round them, with a motor on every wheel.
	var span := float(WHEEL_PAIRS - 1) * WHEEL_PITCH
	for i in WHEEL_PAIRS:
		var y := -span * 0.5 + float(i) * WHEEL_PITCH
		for side in [-1.0, 1.0]:
			var w := Kit.cylinder(WHEEL_R, 1.9, dark, Vector3(side * (WHEEL_R + 0.02), y, 0.0), 18)
			body.add_child(w)
			wheels.append(w)
			body.add_child(Kit.cylinder(0.22, 0.5, steel, Vector3(side * (WHEEL_R + 0.02), y, 1.2), 10))
	# An open frame either side (rails and a cross-bar at each axle), so the wheels show.
	for side in [-1.0, 1.0]:
		var x: float = side * (WHEEL_R * 2.0 + 0.35)
		for edge in [-1.0, 1.0]:
			body.add_child(Kit.box(Vector3(0.22, span + 1.6, 0.22), frame_mat, Vector3(x, 0.0, edge * 1.2)))
		for i in WHEEL_PAIRS:
			body.add_child(Kit.box(Vector3(0.16, 0.16, 2.6), frame_mat, Vector3(x, -span * 0.5 + float(i) * WHEEL_PITCH, 0.0)))
	body.add_child(Kit.box(Vector3(2.0 * WHEEL_R + 0.95, 0.3, 2.6), frame_mat, Vector3(0, span * 0.5 + 0.95, 0)))
	body.add_child(Kit.box(Vector3(2.0 * WHEEL_R + 0.95, 0.3, 2.6), frame_mat, Vector3(0, -span * 0.5 - 0.95, 0)))
	body.add_child(Kit.beacon(Color("ff3a2a"), Vector3(0, span * 0.5 + 1.3, 0), 0.2, 1.4))
	if drive_only:
		return {"node": root, "wheels": wheels, "radius": WHEEL_R * scale}
	# The spine: a truss up the ribbon's line, carrying everything else.
	for side in [-1.0, 1.0]:
		for edge in [-1.0, 1.0]:
			body.add_child(Kit.box(Vector3(0.18, 16.0, 0.18), steel, Vector3(side * 1.6, -2.0, edge * 1.4)))
	for k in 6:
		body.add_child(Kit.box(Vector3(3.4, 0.14, 3.0), steel, Vector3(0, -9.5 + float(k) * 3.0, 0)))
	# Two pods, one either side of the ribbon's width, so the load hangs on its line:
	# a crew cab with windows, and a cargo container.
	var cab := Kit.box(Vector3(2.6, 5.0, 2.8), Kit.mat("offwhite"), Vector3(0, -3.5, 3.4))
	body.add_child(cab)
	body.add_child(Kit.box(Vector3(2.62, 0.5, 2.0), Kit.glass(0.4), Vector3(0, -2.4, 3.6)))
	body.add_child(Kit.box(Vector3(2.4, 6.0, 2.4), Kit.mat("grey"), Vector3(0, -4.0, -3.4)))
	body.add_child(Kit.box(Vector3(2.45, 0.3, 2.45), frame_mat, Vector3(0, -1.2, -3.4)))
	body.add_child(Kit.beacon(Color.WHITE, Vector3(0, -6.2, 4.9), 0.18, 1.0, 0.5))
	match power:
		"solar":
			# Sunlight: two wings off the spine, across the ribbon's width.
			for side in [-1.0, 1.0]:
				body.add_child(Kit.box(Vector3(0.12, 4.0, 9.0), Kit.paint(Color("1d2b4a"), {"finish": 1, "metallic": 0.35, "roughness": 0.3}), Vector3(side * 2.2, 1.0, side * 6.0)))
		_:
			# A beam from the foot: the photocell dish faces down the ribbon.
			var dish := Kit.cylinder(4.2, 0.18, Kit.paint(Color("1d2b4a"), {"finish": 1, "metallic": 0.35, "roughness": 0.3}), Vector3(0, -10.5, 0), 32)
			dish.rotation_degrees = Vector3.ZERO
			body.add_child(dish)
			# TorusMesh lies round Y already: undo Kit's turn onto Z.
			var rim := Kit.torus(4.2, 0.12, steel, Vector3(0, -10.5, 0), 32)
			rim.rotation_degrees = Vector3.ZERO
			body.add_child(rim)
	return {"node": root, "wheels": wheels, "radius": WHEEL_R * scale}


## Turn the wheels for a climb of `moved` metres (positive up the ribbon).
static func roll(model: Dictionary, moved: float) -> void:
	var r := float(model.get("radius", WHEEL_R))
	var turn := moved / maxf(r, 1e-3)
	for i in model["wheels"].size():
		var w: Node3D = model["wheels"][i]
		# Opposed wheels turn opposite ways, each rolling along its own face of the tape.
		w.rotate_object_local(Vector3.UP, turn * (1.0 if i % 2 == 0 else -1.0))
