## Ship models in three standard sections along a keel truss, nose at -Z:
##   crew      cockpit and hab up front, dished and aerialled for deep space
##   cargo     standard containers (or bulk hoppers, or an outsize cradle) in the
##             middle, so the payload sits between the crew and any drive trouble
##   drive     propellant tanks, a shadow shield, then one or more drives crusted
##             with pumps, pipe runs and bottles
## Layout follows the hull's data (ships.json "look") and modules (modules.json
## "look"); the small hardware is seeded by the ship's name, so sister ships differ.
## Static parts are merged per material at the end to keep draw calls down.
##
## Moving parts are returned as a rig for view/flight/ship_rig.gd: every panel (solar
## and radiator) hangs on a boom along the ship's X axis, all in one plane, and turns
## about that boom; the high-gain dish sits on an azimuth/elevation mount.
extends RefCounted

const Kit := preload("res://view/flight/kit.gd")
const Livery := preload("res://view/flight/livery.gd")

## The standard container: across, high, long (metres). Cages carry half-length ones.
const BOX := Vector3(2.4, 2.6, 6.0)
const GAP := 0.6


## Returns {node, nose_z, radius, length}. nose_z is the docking collar tip.
static func build(ship_state: Dictionary, data, livery: Dictionary) -> Dictionary:
	var hull: Dictionary = data.ships[ship_state["hull"]]
	var look: Dictionary = hull.get("look", {})
	var spine: Dictionary = data.modules[hull["spine"]]
	var truss_w := float(spine["look"].get("truss_m", 1.4))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(livery.get("name", "")) + "|" + String(ship_state["hull"]))
	var by_kind := _modules_by_kind(ship_state["modules"], data)
	var rig := {"arrays": [], "dish": {}}
	var ctx := {"livery": livery, "mats": livery["mats"], "rng": rng, "look": look, "truss_w": truss_w, "rig": rig}

	var parts := Node3D.new()
	var z := 0.0
	var radius := 2.0
	var sections := []
	# Crew up front, passenger habs right behind it.
	var command: Array = by_kind.get("command", [])
	if not command.is_empty():
		sections.append(_crew(command[0][1], ctx))
	var cargo := []
	# Whatever bay a module sits in, it goes where it belongs: habs behind the crew,
	# freight and working kit amidships, tanks ahead of the drives.
	var bay: Array = by_kind.get("cargo", []) + by_kind.get("hab", []) + by_kind.get("lander", []) + by_kind.get("sensor", []) + by_kind.get("mining", [])
	for entry in bay:
		if entry[1]["look"].get("shape", "") == "hab":
			sections.append(_hab(entry[1], ctx))
		else:
			cargo.append(entry)
	if not cargo.is_empty():
		sections.append(_cargo(cargo, ctx))
	sections.append(_propulsion(by_kind.get("tank", []), by_kind.get("drive", []), by_kind.get("radiator", []), ctx))
	var keel_from := 0.0
	var keel_to := 0.0
	for i in sections.size():
		var s: Dictionary = sections[i]
		var n: Node3D = s["node"]
		n.position.z = z
		parts.add_child(n)
		if i == 0:
			keel_from = z + float(s["length"]) * 0.6
		if s.get("shield", -1.0) >= 0.0:
			keel_to = z + float(s["shield"])
		radius = maxf(radius, float(s["radius"]))
		z += float(s["length"]) + (GAP if i < sections.size() - 1 else 0.0)
	var length := z
	# The keel runs from inside the crew section to the shadow shield.
	if keel_to <= keel_from:
		keel_to = length * 0.8
	parts.add_child(Kit.truss(keel_to - keel_from, truss_w, ctx["mats"]["steel"], Vector3(0, 0, (keel_from + keel_to) * 0.5)))
	# Navigation lights: red port, green starboard, white strobe aft.
	var crew_w := float(sections[0]["radius"]) if sections.size() > 1 else 2.0
	var crew_z := float(sections[0]["length"]) * 0.55 if sections.size() > 1 else 2.0
	parts.add_child(Kit.beacon(Color("ff3a2a"), Vector3(-crew_w, 0, crew_z), 0.2, 1.4, 0.0))
	parts.add_child(Kit.beacon(Color("3aff5a"), Vector3(crew_w, 0, crew_z), 0.2, 1.4, 0.0))
	parts.add_child(Kit.beacon(Color.WHITE, Vector3(0, truss_w, length * 0.7), 0.2, 1.0, 0.5))
	var root := Node3D.new()
	parts.position.z = -length * 0.5
	root.add_child(parts)
	Kit.merge_static(root)
	return {"node": root, "nose_z": -length * 0.5, "radius": radius, "length": length, "rig": rig}


static func _modules_by_kind(mods: Dictionary, data) -> Dictionary:
	var out := {}
	var slots: Array = mods.keys()
	slots.sort()
	for slot in slots:
		var kind: String = String(data.modules[mods[slot]]["kind"])
		if not out.has(kind):
			out[kind] = []
		out[kind].append([slot, data.modules[mods[slot]]])
	return out


static func _size(m: Dictionary) -> Vector3:
	var s: Array = m["look"].get("size_m", [3, 3, 3])
	return Vector3(s[0], s[1], s[2])


# --- shared bits -----------------------------------------------------------------

## A box from a to b, `t` thick: struts, booms, pipe runs and cable trays.
static func strut(a: Vector3, b: Vector3, t: float, material: Material) -> MeshInstance3D:
	var d := b - a
	var mi := Kit.box(Vector3(t, t, d.length()), material, (a + b) * 0.5)
	if d.length() > 0.001:
		var up := Vector3.UP if absf(d.normalized().dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
		mi.basis = Basis.looking_at(d.normalized(), up)
	return mi


## A cylinder from a to b (pipes, booms, tanks lying across).
static func rod(a: Vector3, b: Vector3, r: float, material: Material, sides: int = 8) -> MeshInstance3D:
	var d := b - a
	var mi := Kit.cylinder(r, d.length(), material, (a + b) * 0.5, sides)
	var up := Vector3.UP if absf(d.normalized().dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	mi.basis = Basis.looking_at(d.normalized(), up) * Basis(Vector3.RIGHT, -PI * 0.5)
	return mi


## A dish opening along `facing`, on its own short mast from `base`.
static func dish(base: Vector3, facing: Vector3, r: float, ctx: Dictionary) -> Node3D:
	var mats: Dictionary = ctx["mats"]
	var n := Node3D.new()
	var head := base + facing.normalized() * maxf(1.0, r * 1.2)
	n.add_child(strut(base, head, 0.12, mats["steel"]))
	var holder := Node3D.new()
	holder.position = head
	var up := Vector3.UP if absf(facing.normalized().dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	holder.basis = Basis.looking_at(-facing.normalized(), up)
	# Built opening toward +Z: the reflector, a back frame and the feed on a tripod.
	holder.add_child(Kit.cone(r, r * 0.15, r * 0.35, Kit.mat("offwhite"), Vector3(0, 0, r * 0.1), 16))
	holder.add_child(Kit.box(Vector3(r * 0.5, r * 0.5, 0.2), mats["dark"], Vector3(0, 0, -r * 0.1)))
	holder.add_child(strut(Vector3(0, 0, 0.0), Vector3(0, 0, r * 0.9), 0.06, mats["steel"]))
	holder.add_child(Kit.box(Vector3(0.18, 0.18, 0.25), mats["dark"], Vector3(0, 0, r * 0.95)))
	n.add_child(holder)
	return n


## The high-gain dish on an azimuth/elevation mount atop a mast at `base` (mast +Y).
## Registers itself as the rig's dish; ship_rig.gd turns "az" about Y and "el" about X.
static func steerable_dish(base: Vector3, r: float, ctx: Dictionary) -> Node3D:
	var mats: Dictionary = ctx["mats"]
	var n := Node3D.new()
	var mast_top := base + Vector3(0, maxf(1.0, r * 1.1), 0)
	n.add_child(strut(base, mast_top, 0.16, mats["steel"]))
	var az := Node3D.new()
	az.position = mast_top
	az.set_meta("no_merge", true)
	az.add_child(Kit.box(Vector3(0.4, 0.3, 0.4), mats["dark"]))
	var el := Node3D.new()
	el.position = Vector3(0, 0.25, 0)
	az.add_child(el)
	# Opening toward +Z: reflector, back frame, and the feed on its strut.
	el.add_child(Kit.cone(r, r * 0.15, r * 0.35, Kit.mat("offwhite"), Vector3(0, 0, r * 0.15), 16))
	el.add_child(Kit.box(Vector3(r * 0.5, r * 0.5, 0.2), mats["dark"], Vector3(0, 0, -0.05)))
	el.add_child(strut(Vector3(0, 0, 0.0), Vector3(0, 0, r * 0.95), 0.06, mats["steel"]))
	el.add_child(Kit.box(Vector3(0.18, 0.18, 0.25), mats["dark"], Vector3(0, 0, r)))
	n.add_child(az)
	ctx["rig"]["dish"] = {"az": az, "el": el}
	return n


## A panel on a boom: the boom is fixed, the panel turns about it. The panel spans
## `span` outward along X, `width` along Z; kind "solar" or "radiator".
static func boom_panel(root: Vector3, side: float, reach: float, span: float, width: float, kind: String, material: Material, ctx: Dictionary) -> Node3D:
	var mats: Dictionary = ctx["mats"]
	var n := Node3D.new()
	var boom_end := root + Vector3(side * reach, 0, 0)
	n.add_child(strut(root, boom_end, 0.22, mats["steel"]))
	var gimbal := Node3D.new()
	gimbal.position = boom_end
	gimbal.set_meta("no_merge", true)
	gimbal.add_child(Kit.box(Vector3(0.35, 0.35, 0.35), mats["dark"]))
	var at := Vector3(side * (span * 0.5 + 0.2), 0, 0)
	gimbal.add_child(Kit.box(Vector3(span, 0.08 if kind == "solar" else 0.2, width), material, at))
	gimbal.add_child(rod(Vector3(side * 0.2, 0, 0), Vector3(side * (span + 0.2), 0, 0), 0.07, mats["steel"]))
	for f in [-0.5, 0.5]:
		gimbal.add_child(Kit.box(Vector3(span, 0.1, 0.08), mats["steel"], at + Vector3(0, 0, width * f)))
	n.add_child(gimbal)
	ctx["rig"]["arrays"].append({"node": gimbal, "kind": kind})
	return n


static func solar_cells(ctx: Dictionary) -> Material:
	return Livery.paint(ctx["livery"], Color("1d2b4a"), {"finish": 1, "mismatch": 0.0, "panel_m": 0.3, "roughness": 0.3, "metallic": 0.35, "wear": 0.1})


## Reaction-control quad: a block with four little nozzles.
static func rcs(at: Vector3, outward: Vector3, ctx: Dictionary) -> Node3D:
	var n := Node3D.new()
	n.position = at
	n.add_child(Kit.box(Vector3(0.4, 0.4, 0.4), ctx["mats"]["dark"]))
	var side := outward.normalized()
	var a := side.cross(Vector3.FORWARD if absf(side.z) < 0.9 else Vector3.UP).normalized()
	for d in [side, a, -a, Vector3(0, 0, 1)]:
		n.add_child(Kit.box(Vector3(0.14, 0.14, 0.14), Kit.mat("black"), d * 0.27))
	return n


static func aerial(at: Vector3, dir: Vector3, length: float, ctx: Dictionary) -> MeshInstance3D:
	return strut(at, at + dir.normalized() * length, 0.05, ctx["mats"]["steel"])


# --- crew section --------------------------------------------------------------

static func _crew(m: Dictionary, ctx: Dictionary) -> Dictionary:
	if m["look"].get("shape", "") == "drone":
		return _drone_bus(m, ctx)
	var mats: Dictionary = ctx["mats"]
	var rng: RandomNumberGenerator = ctx["rng"]
	var size := _size(m)
	var w := size.x
	var h := size.y
	var n := Node3D.new()
	# Faceted nose: a four-sided frustum from the docking collar back to the flight deck.
	var nose_len := size.z * 0.62
	var tip := 1.0
	var nose := Kit.cone(h * 0.5 * sqrt(2.0), tip * sqrt(2.0), nose_len, mats["hull"], Vector3(0, 0, nose_len * 0.5), 4)
	nose.basis = Basis.from_scale(Vector3(w / h, 1.0, 1.0)) * Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.UP, PI * 0.25)
	n.add_child(nose)
	# Windscreen: three panes on the upper slope of the nose, and one in each cheek,
	# dark glass in heavy frames.
	var slope := atan((h * 0.5 - tip) / nose_len)
	var glass := Kit.glass(0.3)
	var frame: Material = mats["dark"]
	var screen := Node3D.new()
	screen.position = Vector3(0, (h * 0.5 + tip) * 0.5 + 0.03, nose_len * 0.55)
	screen.basis = Basis(Vector3.RIGHT, -slope)
	var pane_len := nose_len / cos(slope) * 0.5
	var pane_w := w * 0.62 / 3.0
	for k in 3:
		screen.add_child(Kit.box(Vector3(pane_w * 0.86, 0.05, pane_len), glass, Vector3((float(k) - 1.0) * pane_w, 0, 0)))
	screen.add_child(Kit.box(Vector3(w * 0.68, 0.09, 0.16), frame, Vector3(0, 0, -pane_len * 0.5)))
	screen.add_child(Kit.box(Vector3(w * 0.68, 0.09, 0.16), frame, Vector3(0, 0, pane_len * 0.5)))
	for k in 4:
		screen.add_child(Kit.box(Vector3(0.12, 0.09, pane_len), frame, Vector3((float(k) - 1.5) * pane_w, 0, 0)))
	n.add_child(screen)
	for side in [1.0, -1.0]:
		var cheek := Node3D.new()
		cheek.position = Vector3(side * ((w * 0.5 + tip * w / h) * 0.5 + 0.03), h * 0.1, nose_len * 0.6)
		cheek.basis = Basis(Vector3.UP, side * atan((w * 0.5 - tip * w / h) / nose_len))
		cheek.add_child(Kit.box(Vector3(0.05, h * 0.2, nose_len * 0.32), glass))
		cheek.add_child(Kit.box(Vector3(0.08, h * 0.26, 0.12), frame, Vector3(0, 0, nose_len * 0.17)))
		cheek.add_child(Kit.box(Vector3(0.08, h * 0.26, 0.12), frame, Vector3(0, 0, -nose_len * 0.17)))
		n.add_child(cheek)
	n.add_child(Kit.torus(0.9, 0.18, mats["trim"], Vector3(0, 0, -0.05), 20))
	n.add_child(Kit.beacon(Color("fff4d6"), Vector3(w * 0.3, h * 0.25, nose_len * 0.3), 0.16))
	n.add_child(Kit.beacon(Color("fff4d6"), Vector3(-w * 0.3, h * 0.25, nose_len * 0.3), 0.16))
	# Flight deck: the box behind the nose, banded and stencilled.
	var deck_len := size.z * 0.6
	var deck_z := nose_len + deck_len * 0.5
	var deck := Node3D.new()
	deck.position.z = deck_z
	deck.add_child(Kit.box(Vector3(w, h, deck_len), mats["hull"]))
	deck.add_child(Kit.box(Vector3(w + 0.04, h + 0.04, 0.6), mats["accent"], Vector3(0, 0, deck_len * 0.25)))
	deck.add_child(Kit.box(Vector3(w + 0.04, 0.3, 0.3), mats["trim"], Vector3(0, h * 0.5 - 0.15, -deck_len * 0.5 + 0.15)))
	for side in [1.0, -1.0]:
		deck.add_child(Kit.box(Vector3(0.08, 0.08, deck_len * 0.8), Kit.mat("orange"), Vector3(side * (w * 0.5 + 0.12), -h * 0.2, 0)))
	_name_stencils(deck, ctx["livery"], Vector3(w, h, deck_len))
	n.add_child(deck)
	# Crew hab: a pressure can with portholes, where they sleep, eat and argue.
	var hab_r := minf(w, h) * 0.48
	var hab_len := size.z * 0.9
	var hab_z := nose_len + deck_len + hab_len * 0.5
	n.add_child(Kit.cylinder(hab_r, hab_len, mats["hull"], Vector3(0, 0, hab_z), 16))
	n.add_child(Kit.torus(hab_r + 0.02, 0.12, mats["steel"], Vector3(0, 0, hab_z - hab_len * 0.3), 24))
	n.add_child(Kit.torus(hab_r + 0.02, 0.12, mats["steel"], Vector3(0, 0, hab_z + hab_len * 0.3), 24))
	var lit := Kit.glow(Color("ffdca0"), 0.9)
	for k in 8:
		var a := TAU * (float(k) + 0.5) / 8.0
		if rng.randf() < 0.75:
			var port := Kit.box(Vector3(0.35, 0.06, 0.35), lit, Vector3(cos(a) * (hab_r + 0.01), sin(a) * (hab_r + 0.01), hab_z))
			port.rotation.z = a - PI * 0.5
			n.add_child(port)
	# Deep-space kit on the hab's back: high-gain dish, nav radar, aerials, star trackers.
	var top := Vector3(0, hab_r, hab_z)
	n.add_child(steerable_dish(top + Vector3(0, 0, hab_len * rng.randf_range(0.0, 0.25)), rng.randf_range(1.0, 1.6), ctx))
	# Housekeeping solar wings, for when the reactor is cold: one each side, in the
	# same plane as the radiators aft.
	var cells := solar_cells(ctx)
	var wing := rng.randf_range(3.0, 4.5)
	for side in [1.0, -1.0]:
		n.add_child(boom_panel(Vector3(side * hab_r, 0, hab_z - hab_len * 0.15), side, 0.8, wing, minf(hab_len * 0.55, 2.4), "solar", cells, ctx))
	n.add_child(dish(Vector3(w * 0.5, h * 0.3, deck_z), Vector3(1.0, 0.4, -0.2), 0.45, ctx))
	for k in rng.randi_range(2, 4):
		var at := Vector3(rng.randf_range(-w, w) * 0.4, h * 0.5, nose_len + rng.randf_range(0.2, deck_len))
		n.add_child(aerial(at, Vector3(rng.randf_range(-0.3, 0.3), 1.0, rng.randf_range(0.0, 0.5)), rng.randf_range(1.2, 3.0), ctx))
	for side in [1.0, -1.0]:
		var tracker := Kit.box(Vector3(0.5, 0.4, 0.5), mats["dark"], Vector3(side * w * 0.35, -h * 0.5 - 0.2, deck_z))
		n.add_child(tracker)
		n.add_child(Kit.box(Vector3(0.22, 0.22, 0.3), Kit.mat("black"), Vector3(side * w * 0.35, -h * 0.5 - 0.35, deck_z - 0.35)))
	for c in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		n.add_child(rcs(Vector3(c.x * w * 0.5, c.y * h * 0.5, deck_z - deck_len * 0.3), Vector3(c.x, c.y, 0), ctx))
	return {"node": n, "length": nose_len + deck_len + hab_len, "radius": maxf(w, h) * 0.6 + 0.5}


## An uncrewed bus: an octagonal avionics drum, sensor turret, dishes; no windows.
static func _drone_bus(m: Dictionary, ctx: Dictionary) -> Dictionary:
	var mats: Dictionary = ctx["mats"]
	var rng: RandomNumberGenerator = ctx["rng"]
	var size := _size(m)
	var r := maxf(size.x, size.y) * 0.62
	var l := size.z * 1.3
	var n := Node3D.new()
	n.add_child(Kit.cone(r * 0.75, 1.0, 1.2, mats["dark"], Vector3(0, 0, 0.6), 8))
	n.add_child(Kit.cylinder(r, l, mats["dark"], Vector3(0, 0, 1.2 + l * 0.5), 8))
	n.add_child(Kit.cylinder(r + 0.03, 0.5, mats["accent"], Vector3(0, 0, 1.2 + l * 0.35), 8))
	n.add_child(Kit.torus(0.9, 0.18, mats["trim"], Vector3(0, 0, -0.05), 20))
	# The mind's eyes: a sensor turret under the chin, lit lenses round the drum.
	n.add_child(Kit.sphere(0.55, Kit.mat("black"), Vector3(0, -r * 0.8, 1.6)))
	n.add_child(Kit.sphere(0.2, Kit.glow(ctx["livery"]["accent"], 2.0), Vector3(0, -r * 0.8, 1.1)))
	for k in 4:
		var a := TAU * float(k) / 4.0 + PI * 0.25
		n.add_child(Kit.sphere(0.12, Kit.glow(ctx["livery"]["accent"], 2.0), Vector3(cos(a) * r * 0.75, sin(a) * r * 0.75, 0.4)))
	n.add_child(steerable_dish(Vector3(0, r * 0.9, 1.2 + l * 0.6), rng.randf_range(0.9, 1.4), ctx))
	var cells := solar_cells(ctx)
	for side in [1.0, -1.0]:
		n.add_child(boom_panel(Vector3(side * r * 0.95, 0, 1.2 + l * 0.35), side, 0.6, 3.0, 1.6, "solar", cells, ctx))
	n.add_child(dish(Vector3(r * 0.9, 0, 1.2 + l * 0.7), Vector3(1.0, -0.2, 0.3), rng.randf_range(0.5, 0.8), ctx))
	for k in rng.randi_range(2, 4):
		var a := rng.randf_range(0.0, TAU)
		n.add_child(aerial(Vector3(cos(a) * r, sin(a) * r, 1.2 + rng.randf() * l), Vector3(cos(a), sin(a), 0.3), rng.randf_range(1.0, 2.5), ctx))
	var stencil := Node3D.new()
	stencil.position.z = 1.2 + l * 0.5
	_name_stencils(stencil, ctx["livery"], Vector3(r * 1.7, r, l))
	n.add_child(stencil)
	return {"node": n, "length": 1.2 + l, "radius": r + 1.0}


## A passenger can, next to the crew: rows of lit ports and a boarding hatch.
static func _hab(m: Dictionary, ctx: Dictionary) -> Dictionary:
	var mats: Dictionary = ctx["mats"]
	var size := _size(m)
	var r := maxf(size.x, size.y) * 0.5
	var n := Node3D.new()
	n.add_child(Kit.cylinder(r, size.z, mats["hull"], Vector3(0, 0, size.z * 0.5), 18))
	n.add_child(Kit.cylinder(r + 0.03, 0.7, mats["accent"], Vector3(0, 0, size.z * 0.2), 18))
	for f in [0.05, 0.95]:
		n.add_child(Kit.torus(r * 0.8, 0.25, mats["steel"], Vector3(0, 0, size.z * f), 24))
	var lit := Kit.glow(Color("ffdca0"), 1.0)
	for row in 4:
		for k in 10:
			var a := TAU * float(k) / 10.0
			if absf(sin(a)) > 0.95:
				continue
			var port := Kit.box(Vector3(0.3, 0.05, 0.3), lit, Vector3(cos(a) * (r + 0.01), sin(a) * (r + 0.01), size.z * (0.35 + 0.16 * row)))
			port.rotation.z = a - PI * 0.5
			n.add_child(port)
	n.add_child(Kit.box(Vector3(1.2, 0.1, 1.6), Kit.mat("yellow"), Vector3(0, -r - 0.02, size.z * 0.7)))
	return {"node": n, "length": size.z, "radius": r + 0.5}


# --- cargo section -------------------------------------------------------------

## Cargo modules arranged by the hull's layout: "line" (on the keel, nose to tail),
## "pair" (two abreast) or "cross" (four round the keel). Rows step aft.
static func _cargo(entries: Array, ctx: Dictionary) -> Dictionary:
	var layout: String = ctx["look"].get("cargo_layout", "line")
	var per_row: int = {"line": 1, "pair": 2, "cross": 4}.get(layout, 1)
	var n := Node3D.new()
	var z := 0.0
	var radius := 2.0
	var i := 0
	while i < entries.size():
		var row: Array = entries.slice(i, i + per_row)
		i += per_row
		var blocks := []
		var row_len := 0.0
		for e in row:
			var b := _cargo_block(e[1], e[0], ctx)
			blocks.append(b)
			row_len = maxf(row_len, float(b["size"].z))
		for k in blocks.size():
			var b: Dictionary = blocks[k]
			var bs: Vector3 = b["size"]
			var off := Vector3.ZERO
			if per_row == 2 and blocks.size() == 2:
				off = Vector3((1.0 if k == 0 else -1.0) * (bs.x * 0.5 + 0.35 + float(ctx["truss_w"]) * 0.5), 0, 0)
			elif per_row == 4 and blocks.size() > 1:
				var a := TAU * float(k) / 4.0
				off = Vector3(cos(a), sin(a), 0) * (maxf(bs.x, bs.y) * 0.5 + 0.35 + float(ctx["truss_w"]) * 0.5)
			var node: Node3D = b["node"]
			node.position = off + Vector3(0, 0, z + row_len * 0.5)
			n.add_child(node)
			# Latch arms from the keel to anything carried off-centre.
			if off.length() > 0.01:
				for f in [-0.3, 0.3]:
					n.add_child(strut(Vector3(0, 0, z + row_len * (0.5 + f)), off * 0.8 + Vector3(0, 0, z + row_len * (0.5 + f)), 0.25, ctx["mats"]["steel"]))
			radius = maxf(radius, off.length() + maxf(bs.x, bs.y) * 0.6)
		z += row_len + 0.5
	return {"node": n, "length": z - 0.5, "radius": radius}


## One cargo module: {node, size}. Node centred on its own origin.
static func _cargo_block(m: Dictionary, slot: String, ctx: Dictionary) -> Dictionary:
	var look: Dictionary = m["look"]
	var mats: Dictionary = ctx["mats"]
	var livery: Dictionary = ctx["livery"]
	if look.get("shape", "") == "cradle":
		return _cradle(m, ctx)
	var n := Node3D.new()
	match look.get("shape", "container"):
		"cage":
			# An open frame in trim colour holding half-length containers end to end.
			var c: Array = look.get("containers", [1, 1, 2])
			var unit := Vector3(BOX.x, BOX.y, BOX.z * 0.5)
			var size := Vector3(unit.x * c[0] + 0.5, unit.y * c[1] + 0.5, unit.z * c[2] + 0.4)
			n.add_child(Kit.truss(size.z, maxf(size.x, size.y), mats["trim"]))
			for k in int(c[2]):
				var z := -size.z * 0.5 + 0.2 + unit.z * (float(k) + 0.5)
				n.add_child(_container(unit * Vector3(1, 1, 0.97), Livery.container_colour(livery, slot + str(k)), livery, Vector3(0, 0, z)))
			return {"node": n, "size": size}
		"bulk":
			# Bulk hoppers: a ribbed can with loading hatches on top and a discharge cone.
			var size := _size(m)
			var r := minf(size.x, size.y) * 0.5
			n.add_child(Kit.cylinder(r, size.z * 0.85, mats["hull"], Vector3(0, 0, -size.z * 0.05), 18))
			n.add_child(Kit.cone(r * 0.35, r, size.z * 0.15, mats["hull"], Vector3(0, 0, size.z * 0.425), 18))
			for f in [-0.38, -0.12, 0.14]:
				n.add_child(Kit.torus(r + 0.03, 0.1, mats["steel"], Vector3(0, 0, size.z * f), 28))
			n.add_child(Kit.cylinder(r + 0.04, 0.6, mats["accent"], Vector3(0, 0, size.z * 0.27), 18))
			for f in [-0.25, 0.0]:
				n.add_child(Kit.box(Vector3(1.4, 0.3, 1.4), Kit.mat("yellow"), Vector3(0, r + 0.1, size.z * f)))
			return {"node": n, "size": Vector3(2.0 * r, 2.0 * r, size.z)}
		"lander":
			n.free()
			return _lander(m, ctx)
		"sensor":
			# A survey pod: sensor drum, a lens turret and a small dish.
			var size := _size(m)
			n.add_child(Kit.cylinder(size.x * 0.45, size.z, mats["hull"], Vector3.ZERO, 12))
			n.add_child(Kit.cylinder(size.x * 0.47, 0.4, mats["accent"], Vector3(0, 0, -size.z * 0.2), 12))
			n.add_child(Kit.sphere(0.5, Kit.mat("black"), Vector3(0, -size.y * 0.5, 0)))
			n.add_child(Kit.sphere(0.2, Kit.glow(Color("8fd0ff"), 2.0), Vector3(0, -size.y * 0.5 - 0.35, 0)))
			n.add_child(dish(Vector3(0, size.y * 0.45, size.z * 0.2), Vector3(0.3, 1.0, 0.2), 0.7, ctx))
			return {"node": n, "size": size + Vector3(0.0, 1.5, 0.0)}
		"mining":
			# A prospecting and mining rig: a drill boom folded along a hopper.
			var size := _size(m)
			n.add_child(Kit.box(Vector3(size.x * 0.8, size.y * 0.7, size.z * 0.6), mats["hull"], Vector3(0, -size.y * 0.1, size.z * 0.15)))
			n.add_child(Kit.cone(size.x * 0.35, size.x * 0.15, size.z * 0.25, mats["steel"], Vector3(0, -size.y * 0.1, size.z * 0.55), 10))
			n.add_child(strut(Vector3(size.x * 0.3, size.y * 0.35, size.z * 0.4), Vector3(size.x * 0.3, size.y * 0.35, -size.z * 0.5), 0.35, Kit.mat("orange")))
			n.add_child(Kit.cone(0.15, 0.6, 1.4, mats["steel"], Vector3(size.x * 0.3, size.y * 0.35, -size.z * 0.5 - 0.7), 8))
			n.add_child(Kit.hazard_band(size.x * 0.42, 0.4, Vector3(0, -size.y * 0.1, -size.z * 0.12), 12))
			return {"node": n, "size": size}
		_:
			# Standard containers stacked across, high and long on a pallet frame.
			var c: Array = look.get("containers", [1, 1, 1])
			var size := Vector3(BOX.x * c[0], BOX.y * c[1], BOX.z * c[2])
			var k := 0
			for ix in int(c[0]):
				for iy in int(c[1]):
					for iz in int(c[2]):
						var at := Vector3((float(ix) + 0.5) * BOX.x - size.x * 0.5, (float(iy) + 0.5) * BOX.y - size.y * 0.5, (float(iz) + 0.5) * BOX.z - size.z * 0.5)
						n.add_child(_container(BOX * 0.98, Livery.container_colour(livery, slot + str(k)), livery, at))
						k += 1
			# Clamp frame round the stack.
			for f in [-0.5, 0.5]:
				n.add_child(Kit.box(Vector3(size.x + 0.2, 0.2, 0.2), mats["trim"], Vector3(0, size.y * 0.5 + 0.1, size.z * f * 0.95)))
				n.add_child(Kit.box(Vector3(size.x + 0.2, 0.2, 0.2), mats["trim"], Vector3(0, -size.y * 0.5 - 0.1, size.z * f * 0.95)))
			return {"node": n, "size": size + Vector3(0.2, 0.4, 0.0)}


## A standard box: corrugated sides, door-end frames, a stencilled code panel.
static func _container(size: Vector3, colour: Color, livery: Dictionary, at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = at
	n.add_child(Kit.box(size, Livery.paint(livery, colour, {"finish": 3, "mismatch": 0.0})))
	var frame := Livery.paint(livery, colour.darkened(0.35), {"mismatch": 0.0})
	for f in [-0.5, 0.5]:
		n.add_child(Kit.box(Vector3(size.x + 0.06, size.y + 0.06, 0.18), frame, Vector3(0, 0, size.z * f)))
	n.add_child(Kit.box(Vector3(0.02, 0.5, 1.0), Kit.mat("offwhite"), Vector3(size.x * 0.5 + 0.02, size.y * 0.2, -size.z * 0.3)))
	return n


## A lander in its bay: an open cradle holding a squat two-seat lander, legs folded,
## descent engine down and its own little dish.
static func _lander(m: Dictionary, ctx: Dictionary) -> Dictionary:
	var mats: Dictionary = ctx["mats"]
	var size := _size(m)
	var n := Node3D.new()
	var bed_y := float(ctx["truss_w"]) * 0.5 + 0.5
	for f in [-0.45, 0.45]:
		n.add_child(Kit.box(Vector3(size.x, 0.3, 0.3), mats["steel"], Vector3(0, bed_y, size.z * f)))
		n.add_child(strut(Vector3(0, 0, size.z * f), Vector3(0, bed_y, size.z * f), 0.3, mats["steel"]))
	var lander := Node3D.new()
	lander.position = Vector3(0, bed_y + size.y * 0.55, 0)
	var cab := Livery.paint(ctx["livery"], Kit.COLOURS["yellow"], {"wear": 0.55})
	lander.add_child(Kit.cylinder(size.x * 0.32, size.z * 0.45, cab, Vector3(0, size.y * 0.1, 0), 8))
	lander.add_child(Kit.box(Vector3(size.x * 0.4, 0.06, size.z * 0.12), Kit.glass(0.3), Vector3(0, size.y * 0.1 + size.x * 0.3, -size.z * 0.15)))
	var engine := Kit.cone(size.x * 0.22, size.x * 0.12, size.y * 0.3, mats["steel"], Vector3(0, -size.y * 0.2, 0), 10)
	engine.basis = Basis(Vector3.RIGHT, PI)  # wide bell down
	lander.add_child(engine)
	for k in 4:
		var a := TAU * float(k) / 4.0 + PI * 0.25
		var foot := Vector3(cos(a) * size.x * 0.48, -size.y * 0.4, sin(a) * size.z * 0.36)
		lander.add_child(strut(Vector3(cos(a) * size.x * 0.25, 0.0, sin(a) * size.z * 0.2), foot, 0.12, mats["steel"]))
		lander.add_child(Kit.cylinder(0.35, 0.1, mats["dark"], foot + Vector3(0, -0.05, 0), 8))
	lander.add_child(dish(Vector3(0, size.y * 0.1 + size.x * 0.32, size.z * 0.15), Vector3(0.0, 1.0, 0.3), 0.45, ctx))
	lander.add_child(Kit.beacon(Color("f0a030"), Vector3(0, size.y * 0.1 + size.x * 0.34, -size.z * 0.05), 0.15, 1.6, 0.3))
	n.add_child(lander)
	return {"node": n, "size": Vector3(size.x, (bed_y + size.y) * 2.0, size.z)}


## An open flatbed for outsize loads: a mirror segment, a hull section, or a netted
## pile of crates. The hull's look "oversize" picks one; otherwise the name does.
static func _cradle(m: Dictionary, ctx: Dictionary) -> Dictionary:
	var mats: Dictionary = ctx["mats"]
	var rng: RandomNumberGenerator = ctx["rng"]
	var size := _size(m)
	var n := Node3D.new()
	# The bed rides just above the keel on short legs; the load sits on the bed.
	var bed_y := float(ctx["truss_w"]) * 0.5 + 0.6
	n.add_child(Kit.box(Vector3(size.x, 0.4, size.z), mats["trim"], Vector3(0, bed_y, 0)))
	for f in [-0.45, -0.15, 0.15, 0.45]:
		n.add_child(Kit.box(Vector3(size.x + 0.3, 0.6, 0.3), mats["steel"], Vector3(0, bed_y + 0.3, size.z * f)))
		n.add_child(strut(Vector3(0, 0, size.z * f), Vector3(0, bed_y, size.z * f), 0.3, mats["steel"]))
	var kinds := ["mirror", "hull_section", "crates"]
	var load: String = ctx["look"].get("oversize", kinds[rng.randi() % kinds.size()])
	match load:
		"mirror":
			# A hexagonal mirror segment standing edge-on in a packing frame.
			var seg := Kit.cylinder(size.y * 0.75, 0.35, Kit.paint(Color("c9a24a"), {"finish": 1, "metallic": 0.8, "roughness": 0.3, "wear": 0.05}), Vector3(0, bed_y + size.y * 0.8, 0), 6)
			seg.basis = Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.RIGHT, PI * 0.5)
			n.add_child(seg)
			for f in [-1.0, 1.0]:
				n.add_child(strut(Vector3(f * 0.6, bed_y + 0.2, -size.z * 0.35), Vector3(f * 0.3, bed_y + size.y * 1.4, 0), 0.2, mats["steel"]))
				n.add_child(strut(Vector3(f * 0.6, bed_y + 0.2, size.z * 0.35), Vector3(f * 0.3, bed_y + size.y * 1.4, 0), 0.2, mats["steel"]))
		"hull_section":
			# A pressure-hull ring for someone's habitat, in primer, ends taped and striped.
			var r := size.x * 0.48
			n.add_child(Kit.cylinder(r, size.z * 0.8, Kit.paint(Color("8c8f84"), {"wear": 0.2, "mismatch": 0.0}), Vector3(0, bed_y + 0.4 + r, 0), 24))
			n.add_child(Kit.hazard_band(r + 0.03, 0.5, Vector3(0, bed_y + 0.4 + r, size.z * 0.38), 20))
			n.add_child(Kit.hazard_band(r + 0.03, 0.5, Vector3(0, bed_y + 0.4 + r, -size.z * 0.38), 20))
		_:
			# Crates of every size under a cargo net.
			var z := -size.z * 0.45
			while z < size.z * 0.4:
				var c := Vector3(rng.randf_range(1.2, size.x * 0.9), rng.randf_range(1.0, size.y * 1.2), rng.randf_range(1.0, 3.0))
				var col: Color = ctx["livery"]["containers"][rng.randi() % ctx["livery"]["containers"].size()]
				n.add_child(Kit.box(c, Livery.paint(ctx["livery"], col, {"panel_m": 0.5}), Vector3(rng.randf_range(-0.3, 0.3), bed_y + 0.2 + c.y * 0.5, z + c.z * 0.5)))
				z += c.z + 0.15
			n.add_child(Kit.box(Vector3(size.x * 0.95, 0.05, size.z * 0.9), Livery.paint(ctx["livery"], Color("4a5a3a"), {"mismatch": 0.0, "panel_m": 0.4}), Vector3(0, bed_y + size.y * 1.25, 0)))
	# Report a block centred on the keel, tall enough to cover the load.
	return {"node": n, "size": Vector3(size.x, (bed_y + size.y * 1.6) * 2.0, size.z)}


# --- propulsion section --------------------------------------------------------

## Tanks first (they shield too), then radiators on booms, the shadow shield, and
## the drives: one on the axis, or a pair, a triangle or a square of them.
static func _propulsion(tanks: Array, drives: Array, radiators: Array, ctx: Dictionary) -> Dictionary:
	var mats: Dictionary = ctx["mats"]
	var rng: RandomNumberGenerator = ctx["rng"]
	var truss_w := float(ctx["truss_w"])
	var n := Node3D.new()
	var z := 0.0
	var radius := 2.0
	# Tanks in pairs above and below the keel, stepping aft: the radiator plane (X-Z)
	# stays clear however many a long-haul refit carries.
	var tank_len := 0.0
	var tz := 0.0
	for k in tanks.size():
		var m: Dictionary = tanks[k][1]
		var s := _size(m)
		var off := Vector3.ZERO
		if tanks.size() > 1:
			off = Vector3(0, (1.0 if k % 2 == 0 else -1.0) * (s.x * 0.5 + truss_w * 0.5 + 0.2), 0)
		var t := Node3D.new()
		t.position = off + Vector3(0, 0, tz + s.z * 0.5)
		if m["look"].get("shape", "") == "sphere":
			t.add_child(Kit.sphere(s.x * 0.5, mats["foil"]))
			t.add_child(Kit.torus(s.x * 0.5, 0.08, mats["steel"], Vector3.ZERO, 32))
		else:
			t.add_child(Kit.cylinder(s.x * 0.5, s.z, mats["foil"]))
			t.add_child(Kit.hazard_band(s.x * 0.5 + 0.02, 0.4, Vector3(0, 0, s.z * 0.4), 12))
			t.add_child(Kit.torus(s.x * 0.5 + 0.03, 0.12, mats["accent"], Vector3(0, 0, -s.z * 0.35), 32))
		n.add_child(t)
		if off.length() > 0.01:
			n.add_child(strut(Vector3(0, 0, tz + s.z * 0.5), off * 0.7 + Vector3(0, 0, tz + s.z * 0.5), 0.3, mats["steel"]))
		tank_len = maxf(tank_len, tz + s.z)
		if tanks.size() == 1 or k % 2 == 1:
			tz = tank_len + 0.4
		radius = maxf(radius, off.length() + s.x * 0.5)
	z += tank_len + 0.4
	# Drive cluster geometry, to size the shield.
	var count := drives.size()
	var drive_r := 1.5
	for d in drives:
		drive_r = maxf(drive_r, _size(d[1]).x * 0.5)
	var spread := 0.0 if count <= 1 else drive_r * (1.5 if count == 2 else 1.8)
	var offsets := []
	for k in count:
		if count == 1:
			offsets.append(Vector3.ZERO)
		else:
			var a := TAU * float(k) / float(count) + (0.0 if count == 2 else PI * 0.25 if count == 4 else PI * 0.5)
			offsets.append(Vector3(cos(a), sin(a), 0) * spread)
	var shield_r := spread + drive_r * 1.15
	# Radiators fold out from the tank section on booms, edge-on to the crew.
	var rads_z := z * 0.5
	# All in the ship's X-Z plane, one pair after another along the hull, never
	# stacked, so each can turn edge-on to the Sun without shading the next.
	var rad_mat := Livery.paint(ctx["livery"], Kit.COLOURS["dark"], {"finish": 1, "mismatch": 0.0, "panel_m": 0.35, "roughness": 0.6, "metallic": 0.3})
	var pair_z := rads_z
	for k in radiators.size():
		var s := _size(radiators[k][1])
		var side := 1.0 if k % 2 == 0 else -1.0
		var reach := maxf(1.2, shield_r - truss_w * 0.5)
		n.add_child(boom_panel(Vector3(side * (truss_w * 0.5 + 0.1), 0, pair_z), side, reach, s.y, s.z, "radiator", rad_mat, ctx))
		radius = maxf(radius, truss_w * 0.5 + reach + s.y + 0.3)
		if side < 0.0:
			pair_z += s.z + 0.6
	# Shadow shield: a thick plate between the reactor(s) and everything forward.
	var shield_z := z + 0.3
	n.add_child(Kit.cylinder(shield_r, 0.6, mats["steel"], Vector3(0, 0, shield_z), 16))
	n.add_child(Kit.hazard_band(shield_r + 0.02, 0.5, Vector3(0, 0, shield_z), 20))
	z += 0.8
	# Thrust frame: the keel splits to carry each drive.
	var drive_len := 0.0
	for k in count:
		var dm: Dictionary = drives[k][1]
		var ds := _size(dm)
		var off: Vector3 = offsets[k]
		var unit := _drive(dm, ds, ctx, k)
		unit.position = off + Vector3(0, 0, z)
		n.add_child(unit)
		if off.length() > 0.01:
			n.add_child(strut(Vector3(0, 0, z - 0.2), off + Vector3(0, 0, z + ds.z * 0.3), 0.35, mats["steel"]))
		drive_len = maxf(drive_len, ds.z * 1.5 + 1.0)
		radius = maxf(radius, off.length() + ds.x * 0.6)
	# All the drives' plumes switch together.
	var plumes := Node3D.new()
	plumes.name = "DrivePlume"
	for k in count:
		var ds := _size(drives[k][1])
		plumes.add_child(Kit.sphere(ds.x * 0.3, Kit.glow(Color("8fd0ff"), 4.0), offsets[k] + Vector3(0, 0, z + ds.z * 1.45 + 0.6)))
	n.add_child(plumes)
	radius = maxf(radius, shield_r)
	return {"node": n, "length": z + drive_len, "radius": radius, "shield": shield_z}


## One drive: reactor drum, field coils, a heat-tinted magnetic nozzle, and the
## barnacles: pumps, pipe runs to the tanks, gas bottles, cable trays, RCS.
static func _drive(m: Dictionary, s: Vector3, ctx: Dictionary, index: int) -> Node3D:
	var mats: Dictionary = ctx["mats"]
	var rng: RandomNumberGenerator = ctx["rng"]
	var n := Node3D.new()
	var r := s.x * 0.46
	var reactor_len := s.z * 0.75
	n.add_child(Kit.cylinder(r, reactor_len, mats["steel"], Vector3(0, 0, reactor_len * 0.5), 14))
	for f in [0.2, 0.55, 0.85]:
		n.add_child(Kit.torus(r + 0.05, 0.14, mats["dark"], Vector3(0, 0, reactor_len * f), 24))
	n.add_child(Kit.cylinder(r + 0.06, 0.5, mats["accent"], Vector3(0, 0, reactor_len * 0.38), 14))
	# Field coils round the throat, then the bell.
	var coils := int(m["look"].get("coils", 2))
	for k in coils:
		n.add_child(Kit.torus(r * (0.75 + 0.12 * k), 0.16, Kit.paint(Color("8a5a2a"), {"finish": 1, "metallic": 0.8, "roughness": 0.4}), Vector3(0, 0, reactor_len + 0.3 + 0.45 * k), 24))
	var bell_len := s.z * 0.7
	n.add_child(Kit.cone(s.x * 0.68, r * 0.5, bell_len, Livery.paint(ctx["livery"], Color("4a3d32"), {"finish": 1, "metallic": 0.7, "roughness": 0.45}), Vector3(0, 0, reactor_len + bell_len * 0.5 + 0.2), 20))
	# Thrust frame: a cage of longerons from the shield to the coil ring.
	for k in 6:
		var a := TAU * float(k) / 6.0 + 0.3
		var d := Vector3(cos(a), sin(a), 0)
		n.add_child(strut(d * (r + 0.7) + Vector3(0, 0, -0.1), d * (r + 0.35) + Vector3(0, 0, reactor_len + 0.4), 0.16, mats["steel"]))
	n.add_child(Kit.torus(r + 0.55, 0.12, mats["steel"], Vector3(0, 0, reactor_len * 0.5), 24))
	# Barnacles, seeded per ship and per drive.
	for k in rng.randi_range(7, 11):
		var a := rng.randf_range(0.0, TAU)
		var zz := rng.randf_range(0.1, 0.9) * reactor_len
		var dir := Vector3(cos(a), sin(a), 0)
		match rng.randi() % 4:
			0:
				var b := Vector3(rng.randf_range(0.5, 1.1), rng.randf_range(0.4, 0.8), rng.randf_range(0.6, 1.4))
				var pump := Kit.box(b, mats["dark"] if rng.randf() < 0.5 else mats["hull"], dir * (r + b.y * 0.5) + Vector3(0, 0, zz))
				pump.rotation.z = a - PI * 0.5
				n.add_child(pump)
			1:
				n.add_child(Kit.sphere(rng.randf_range(0.3, 0.55), mats["foil"], dir * (r + 0.45) + Vector3(0, 0, zz)))
			2:
				# A pipe run forward along the drum and over the shield to the tanks.
				var p0 := dir * (r + 0.2) + Vector3(0, 0, zz)
				n.add_child(rod(p0, p0 + Vector3(0, 0, -zz - 0.8), 0.1, mats["steel"]))
				n.add_child(rod(p0 + Vector3(0, 0, -zz - 0.8), dir * (r + 0.6) + Vector3(0, 0, -1.4), 0.1, mats["steel"]))
			_:
				var tray := Kit.box(Vector3(0.35, 0.12, reactor_len * 0.7), Kit.mat("yellow"), dir * (r + 0.08) + Vector3(0, 0, reactor_len * 0.5))
				tray.rotation.z = a - PI * 0.5
				n.add_child(tray)
	for k in 4:
		var a := TAU * float(k) / 4.0 + PI * 0.25
		n.add_child(rcs(Vector3(cos(a), sin(a), 0) * (r + 0.4) + Vector3(0, 0, reactor_len * 0.9), Vector3(cos(a), sin(a), 0), ctx))
	n.add_child(Kit.beacon(Color("ff3a2a"), Vector3(0, r + 0.3, 0.3), 0.18, 2.0, 0.25 * index))
	return n


## The ship's name painted on both flanks of a section `size` across.
static func _name_stencils(n: Node3D, livery: Dictionary, size: Vector3) -> void:
	var text := String(livery.get("name", "")).to_upper()
	if text == "" or size.x < 2.0:
		return
	var hull: Color = livery["hull"]
	for side in [1.0, -1.0]:
		var l := Label3D.new()
		l.text = text
		l.font_size = 64
		l.outline_size = 0
		l.shaded = true
		l.double_sided = false
		l.modulate = Color("1b1d20") if hull.get_luminance() > 0.45 else Color("e6dcc4")
		l.pixel_size = minf(0.42, size.z * 0.75 / maxf(1.0, text.length() * 0.6)) / 64.0
		l.position = Vector3(side * (size.x * 0.5 + 0.03), -size.y * 0.15, 0.0)
		l.rotation.y = side * PI * 0.5
		n.add_child(l)
