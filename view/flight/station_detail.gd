## Station dressing: the detail pass on the shapes models.gd builds, in the same kit
## as the ships (view/flight/hull_kit.gd).
##
## A spinning station is two machines:
##   - the rotor, which spins and holds everything crewed
##   - a despun assembly on the axis astern, held still on a bearing, so dishes can
##     hold a link and arrays can face the Sun while everything else turns
##
## The rotor:
##   - the hub's frames, its control-room windows and the docking face: ribs, a
##     ring, floodlights trained on the port, EVA hatches, handrails and panels
##   - the spokes' lift tubes, with a housing where each meets the ring
##   - the ring's frames round the tube, and framed windows in rows on both faces
##
## The despun assembly:
##   - a truss mast with radiators edge-on
##   - solar wings: cell blankets in frames on a boom
##   - a comm farm at the tip: one big dish, two small ones, aerials and a strobe
## Both are merged per material afterwards (Kit.merge_static), so a station costs a
## few dozen draw calls however much is on it.
extends RefCounted

const Kit := preload("res://view/flight/kit.gd")
const Livery := preload("res://view/flight/livery.gd")
const HullKit := preload("res://view/flight/hull_kit.gd")


static func _lamp(mats: Dictionary, colour: Color, energy: float) -> Material:
	var key := "lamp_%s_%0.1f" % [colour.to_html(false), energy]
	if not mats.has(key):
		mats[key] = Kit.glow(colour, energy)
	return mats[key]


## On a cylinder about Z: a node at angle `a`, radius `r`, height `z`, whose +Y faces
## outward and whose X runs round the cylinder.
static func _on_drum(a: float, r: float, z: float) -> Node3D:
	var n := Node3D.new()
	n.position = Vector3(cos(a) * r, sin(a) * r, z)
	n.basis = Basis(Vector3.BACK, a - PI * 0.5)
	return n


## On a flat face at height z looking along +Z (or -Z): a node at polar (a, r) whose +Y
## faces out of the face and whose X runs round.
static func _on_face(a: float, r: float, z: float, facing: float = 1.0) -> Node3D:
	var n := Node3D.new()
	n.position = Vector3(cos(a) * r, sin(a) * r, z)
	n.basis = Basis(Vector3.BACK, a - PI * 0.5) * Basis(Vector3.RIGHT, facing * PI * 0.5)
	return n


# --- the hub ---------------------------------------------------------------------

## The hub of a wheel (radius rh, length lh, docking face at +lh/2, port radius pr):
## frames, a band of control-room windows just aft of the face, and the face itself.
static func hub(rotor: Node3D, rh: float, lh: float, pr: float, mats: Dictionary, rng: RandomNumberGenerator) -> void:
	var steel: Material = mats["steel"]
	for f in [-0.4, -0.22, 0.24, 0.38]:
		rotor.add_child(Kit.torus(rh + 0.2, 0.35, steel, Vector3(0, 0, lh * f), 48))
	# Approach control: the watch room looks out round the docking face.
	var count := clampi(int(TAU * rh / 2.8), 12, 64)
	for i in count:
		var at := _on_drum(TAU * (float(i) + 0.5) / float(count), rh + 0.02, lh * 0.5 - 6.0)
		at.add_child(HullKit.window(1.4, 0.9, mats, mats["dark"], 0.7))
		rotor.add_child(at)
	face(rotor, rh, lh * 0.5, pr, mats, rng)


## A docking face at z (radius rh, port pr): radial ribs and a ring, floodlights trained
## on the port, two EVA hatches with handrails out to them, and access panels.
static func face(rotor: Node3D, rh: float, z: float, pr: float, mats: Dictionary, rng: RandomNumberGenerator) -> void:
	var grey: Material = Kit.mat("grey")
	var inner := pr * 1.75
	for k in 8:
		var a := TAU * (float(k) + 0.5) / 8.0
		var mid := (inner + rh * 0.96) * 0.5
		var rib := Kit.box(Vector3(rh * 0.96 - inner, 0.45, 0.3), grey, Vector3(cos(a) * mid, sin(a) * mid, z + 0.15))
		rib.rotation.z = a
		rotor.add_child(rib)
	rotor.add_child(Kit.torus(rh * 0.72, 0.25, grey, Vector3(0, 0, z + 0.2), 48))
	rotor.add_child(Kit.torus(inner, 0.3, mats["steel"], Vector3(0, 0, z + 0.2), 32))
	# Floodlights: housings on the face, lenses aimed down the approach.
	for k in 4:
		var a := TAU * (float(k) + 0.5) / 4.0 + PI * 0.125
		var p := Vector3(cos(a), sin(a), 0.0) * rh * 0.84 + Vector3(0, 0, z)
		rotor.add_child(Kit.box(Vector3(1.0, 1.0, 0.7), mats["dark"], p + Vector3(0, 0, 0.35)))
		rotor.add_child(Kit.box(Vector3(0.75, 0.75, 0.06), _lamp(mats, Color("fff2d8"), 3.5), p + Vector3(0, 0, 0.72)))
	for a in [0.0, PI]:
		var h := _on_face(a, rh * 0.58, z + 0.02)
		h.add_child(HullKit.hatch(1.1, 1.4, mats))
		rotor.add_child(h)
		var d := Vector3(cos(a), sin(a), 0.0)
		for s in [-1.0, 1.0]:
			var side: Vector3 = Vector3(-d.y, d.x, 0.0) * s * 0.9
			rotor.add_child(HullKit.handrail(d * inner * 1.1 + side + Vector3(0, 0, z), d * rh * 0.5 + side + Vector3(0, 0, z), Vector3.BACK))
	for k in 6:
		var a := rng.randf_range(0.0, TAU)
		if absf(sin(a) + 0.8) < 0.5:
			continue
		var p := _on_face(a, rng.randf_range(inner * 1.3, rh * 0.85), z + 0.02)
		p.add_child(HullKit.access_panel(rng.randf_range(0.8, 1.4), rng.randf_range(0.8, 1.6), grey if rng.randf() < 0.5 else mats["hull"]))
		rotor.add_child(p)


## Latch blocks and a bolted flange round a docking port of radius pr at z.
static func port(rotor: Node3D, pr: float, z: float, mats: Dictionary) -> void:
	rotor.add_child(HullKit.annulus(pr * 1.02, pr * 1.3, 0.2, mats["steel"], 32))
	rotor.get_child(-1).position.z = z - 0.35
	for k in 8:
		var a := TAU * (float(k) + 0.5) / 8.0
		rotor.add_child(Kit.box(Vector3(0.5, 0.5, 0.45), mats["dark"], Vector3(cos(a), sin(a), 0.0) * pr * 1.16 + Vector3(0, 0, z - 0.1)))


# --- spokes and the ring --------------------------------------------------------------

## A spoke's lift tube inside its truss, from the hub (rh) to the ring's inner side, with
## collars, and a housing where it meets the ring (the lift head). `a` is its angle.
static func spoke(rotor: Node3D, a: float, rh: float, rr: float, rt: float, mats: Dictionary) -> void:
	var holder := Node3D.new()
	holder.rotation.z = a
	rotor.add_child(holder)
	var from := rh
	var to := rr - rt * 0.85
	var tube := Kit.cylinder(1.0, to - from, mats["hull"], Vector3((from + to) * 0.5, 0, 0), 12)
	tube.rotation = Vector3(0, 0, PI * 0.5)
	holder.add_child(tube)
	var steps := maxi(2, int((to - from) / 12.0))
	for i in steps + 1:
		holder.add_child(Kit.box(Vector3(0.5, 2.6, 2.6), Kit.mat("grey"), Vector3(lerpf(from + 1.0, to - 1.0, float(i) / float(steps)), 0, 0)))
	var head := Vector3(rr - rt * 0.95, 0, 0)
	holder.add_child(Kit.box(Vector3(rt * 0.5, 5.0, 5.5), mats["hull"], head))
	holder.add_child(Kit.box(Vector3(rt * 0.52, 5.1, 1.0), mats["accent"], head))
	holder.add_child(Kit.box(Vector3(3.0, 3.6, 3.6), mats["hull"], Vector3(rh + 1.2, 0, 0)))


## The ring (radius rr, tube rt): frames round the tube, and between them rows of
## framed windows on both faces, where the decks look out.
static func ring(rotor: Node3D, rr: float, rt: float, spokes: int, mats: Dictionary) -> void:
	var frames := maxi(12, spokes * 6)
	var steel: Material = mats["steel"]
	for i in frames:
		var a := TAU * float(i) / float(frames)
		var t := Vector3(-sin(a), cos(a), 0.0)
		var holder := Node3D.new()
		holder.position = Vector3(cos(a), sin(a), 0.0) * rr
		holder.basis = Basis.looking_at(-t, Vector3.BACK)
		holder.add_child(Kit.torus(rt + 0.15, clampf(rt * 0.035, 0.2, 0.6), steel, Vector3.ZERO, 32))
		rotor.add_child(holder)
		# A running light on the outer rim at every frame.
		rotor.add_child(Kit.box(Vector3(0.5, 0.5, 0.5), _lamp(mats, Color("ffdca0"), 2.0), Vector3(cos(a), sin(a), 0.0) * (rr + rt + 0.3)))
	# Two decks of windows on each face, four to a bay.
	var w := clampf(rt * 0.22, 1.2, 2.6)
	var per := 4
	for deck in [0.3, -0.12]:
		var face_z: float = sqrt(1.0 - deck * deck) * rt * 0.995
		for i in frames:
			for k in per:
				var a := TAU * (float(i) + (float(k) + 1.0) / float(per + 1)) / float(frames)
				for side in [1.0, -1.0]:
					var holder := _on_face(a, rr + rt * deck, side * face_z, side)
					holder.add_child(HullKit.window(w, w * 0.6, mats, mats["dark"], 0.75, 0.0, w * 0.08, false))
					rotor.add_child(holder)


# --- the despun assembly ------------------------------------------------------------

## The still part astern of the hub's aft face (at z_from): a truss mast `length` long,
## radiators along it, solar wings `span` from the axis, and the comm farm on its tip.
## dish_r: the big dish's radius.
static func despun(n: Node3D, z_from: float, length: float, span: float, dish_r: float, livery: Dictionary, rng: RandomNumberGenerator) -> void:
	var mats: Dictionary = livery["mats"]
	var steel: Material = mats["steel"]
	var w := clampf(length * 0.06, 2.0, 8.0)
	var z_mid := z_from - length * 0.5
	n.add_child(Kit.truss(length, w, steel, Vector3(0, 0, z_mid)))
	n.add_child(Kit.cylinder(w * 0.9, 1.5, mats["dark"], Vector3(0, 0, z_from - 0.75), 24))
	n.add_child(Kit.torus(w * 0.95, 0.3, Kit.mat("yellow"), Vector3(0, 0, z_from - 1.4), 24))
	# Radiators, edge-on: up and down from the mast.
	var rad := Livery.paint(livery, Kit.COLOURS["dark"], {"finish": 1, "mismatch": 0.0, "panel_m": 0.6, "roughness": 0.6, "metallic": 0.3})
	var rad_len := length * 0.35
	for s in [-1.0, 1.0]:
		n.add_child(Kit.box(Vector3(0.3, span * 0.3, rad_len), rad, Vector3(0, s * (w * 0.5 + span * 0.15), z_from - length * 0.25)))
		n.add_child(Kit.box(Vector3(0.5, span * 0.3, 0.4), steel, Vector3(0, s * (w * 0.5 + span * 0.15), z_from - length * 0.25 - rad_len * 0.5)))
	# Solar wings: a boom each way, four framed blankets on each.
	var cells := Livery.paint(livery, Color("1d2b4a"), {"finish": 1, "mismatch": 0.0, "panel_m": 0.9, "roughness": 0.3, "metallic": 0.35, "wear": 0.1})
	var wing_w := clampf(span * 0.12, 6.0, 40.0)
	var wz := z_from - length * 0.62
	for s in [-1.0, 1.0]:
		var root := w * 0.5
		n.add_child(Kit.box(Vector3(span - root, 0.6, 0.6), steel, Vector3(s * (root + span) * 0.5, 0, wz)))
		var blank := (span - root - 2.0) / 4.0
		for k in 4:
			var cx: float = s * (root + 2.0 + blank * (float(k) + 0.5))
			n.add_child(Kit.box(Vector3(blank - 0.6, 0.12, wing_w), cells, Vector3(cx, 0, wz)))
			for f in [-0.5, 0.5]:
				n.add_child(Kit.box(Vector3(blank - 0.6, 0.2, 0.25), steel, Vector3(cx, 0, wz + wing_w * f)))
			n.add_child(Kit.box(Vector3(0.25, 0.2, wing_w), steel, Vector3(cx + s * (blank * 0.5 - 0.3), 0, wz)))
	# The comm farm: a platform at the tip, the big dish looking out and back, two
	# smaller ones elsewhere, whips and a strobe.
	var tip := z_from - length
	n.add_child(Kit.box(Vector3(w * 2.2, 1.2, w * 1.6), mats["dark"], Vector3(0, 0, tip - w * 0.4)))
	var dishes := [[dish_r, Vector3(0.45, 0.7, -0.55)], [dish_r * 0.4, Vector3(-0.8, 0.3, -0.5)], [dish_r * 0.3, Vector3(0.2, -0.9, -0.4)]]
	for k in dishes.size():
		var r: float = dishes[k][0]
		var facing: Vector3 = (dishes[k][1] as Vector3).normalized()
		var base := Vector3([0.0, -w * 0.8, w * 0.7][k], [0.6, 0.6, -0.6][k], tip - w * 0.4)
		var head := base + facing * maxf(1.0, r * 1.1)
		n.add_child(HullKit.bar(base, head, 0.2 + r * 0.06, steel))
		var holder := Node3D.new()
		holder.position = head
		holder.basis = Basis.looking_at(-facing, Vector3.UP if absf(facing.y) < 0.95 else Vector3.RIGHT)
		holder.add_child(HullKit.reflector(r, mats, true))
		n.add_child(holder)
	for k in rng.randi_range(3, 5):
		var at := Vector3(rng.randf_range(-w, w), 0.6, tip - w * 0.4 + rng.randf_range(-w * 0.6, w * 0.6))
		n.add_child(HullKit.bar(at, at + Vector3(rng.randf_range(-0.2, 0.2), 1.0, rng.randf_range(-0.2, 0.2)).normalized() * rng.randf_range(3.0, 7.0), 0.08, steel))
	n.add_child(Kit.beacon(Color.WHITE, Vector3(0, 1.4, tip - w), 0.5, 1.2, 0.0))
