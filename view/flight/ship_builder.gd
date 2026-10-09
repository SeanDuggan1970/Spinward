## Ship models in three standard sections along a keel truss, nose at -Z:
##   crew      cockpit and hab up front, dished and aerialled for deep space
##   cargo     standard containers (or bulk hoppers, or an outsize cradle) in the
##             middle, so the payload sits between the crew and any drive trouble
##   drive     propellant tanks, a shadow shield, then one or more drives crusted
##             with pumps, pipe runs and bottles, each ending in a magnetic nozzle: a
##             hollow lathed bell inside a coil stack (_nozzle_hardware)
## Layout follows the hull's data (ships.json "look") and modules (modules.json
## "look"); the small hardware is seeded by the ship's name, so sister ships differ.
## Static parts are merged per material at the end to keep draw calls down.
##
## The node named DrivePlume holds what a lit drive shows (_plume): a volumetric
## plasma jet, the bell's walls glowing with heat, and a light on the stern. Views
## show it while the drive burns and hide it otherwise; set_throttle dims it.
##
## Moving parts are returned as a rig for view/flight/ship_rig.gd: every panel (solar
## and radiator) hangs on a boom along the ship's X axis, all in one plane, and turns
## about that boom; the high-gain dish sits on an azimuth/elevation mount.
extends RefCounted

const Kit := preload("res://view/flight/kit.gd")
const Livery := preload("res://view/flight/livery.gd")
const HullKit := preload("res://view/flight/hull_kit.gd")

## The standard container: across, high, long (metres). Cages carry half-length ones.
const BOX := Vector3(2.4, 2.6, 6.0)
const GAP := 0.6


## Returns {node, nose_z, radius, length}. nose_z is the docking collar tip.
static func build(ship_state: Dictionary, data, livery: Dictionary) -> Dictionary:
	var hull: Dictionary = data.ships[ship_state["hull"]]
	var look: Dictionary = hull.get("look", {})
	# Frame-built craft (the Kestrel surface transporter) have their own layout.
	if look.get("layout", "") == "frame":
		return load("res://view/flight/kestrel.gd").build(livery, 1.0, String(look.get("payload", "passenger")))
	var spine: Dictionary = data.modules[hull["spine"]]
	var truss_w := float(spine["look"].get("truss_m", 1.4))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(livery.get("name", "")) + "|" + String(ship_state["hull"]))
	var by_kind := _modules_by_kind(ship_state["modules"], data)
	var rig := {"arrays": [], "dish": {}, "rcs": []}
	var ctx := {"livery": livery, "mats": livery["mats"], "rng": rng, "look": look, "truss_w": truss_w, "rig": rig, "deep": _deep(by_kind, look)}

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
	var bay: Array = by_kind.get("cargo", []) + by_kind.get("hab", []) + by_kind.get("lander", []) + by_kind.get("sensor", []) + by_kind.get("mining", []) + by_kind.get("sink", [])
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
	# Navigation lights, in fixtures on the hull (Kit.nav_light): red to port, green to
	# starboard, pulsing together, and a white anti-collision strobe on the keel aft.
	var crew_w := float(sections[0].get("hull_r", sections[0]["radius"])) if sections.size() > 1 else 2.0
	var crew_z := float(sections[0]["length"]) * 0.55 if sections.size() > 1 else 2.0
	parts.add_child(Kit.nav_light(Color("ff3a2a"), Vector3(-crew_w, 0, crew_z), Vector3.LEFT, 0.2, "flash", 1.6, 0.0))
	parts.add_child(Kit.nav_light(Color("3aff5a"), Vector3(crew_w, 0, crew_z), Vector3.RIGHT, 0.2, "flash", 1.6, 0.0))
	parts.add_child(Kit.nav_light(Color("f4f8ff"), Vector3(0, truss_w * 0.55, length * 0.7), Vector3.UP, 0.16, "strobe", 1.4, 0.4))
	var root := Node3D.new()
	parts.position.z = -length * 0.5
	root.add_child(parts)
	Kit.merge_static(root)
	return {"node": root, "nose_z": -length * 0.5, "radius": radius, "length": length, "rig": rig}


## Built for deep space: a D-He3 drive (Isp 50,000 s or more) or life support for 250
## days or more, or the hull says so (look "deep"). Such ships carry a high-gain dish
## big enough to hear Earth from Saturn.
static func _deep(by_kind: Dictionary, look: Dictionary) -> bool:
	if bool(look.get("deep", false)):
		return true
	var days := 0.0
	for kind in by_kind:
		for entry in by_kind[kind]:
			var md: Dictionary = entry[1]
			days += float(md.get("life_support_days", 0.0))
			if kind == "drive" and float(md.get("isp_s", 0.0)) >= 50000.0:
				return true
	return days >= 250.0


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


## A fixed dish opening along `facing`, on its own short mast from `base`
## (HullKit.reflector: a real paraboloid with its feed).
static func dish(base: Vector3, facing: Vector3, r: float, ctx: Dictionary) -> Node3D:
	var mats: Dictionary = ctx["mats"]
	var n := Node3D.new()
	var head := base + facing.normalized() * maxf(0.6, r * 1.2)
	n.add_child(strut(base, head, 0.06 + r * 0.06, mats["steel"]))
	var holder := Node3D.new()
	holder.position = head
	var up := Vector3.UP if absf(facing.normalized().dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	holder.basis = Basis.looking_at(-facing.normalized(), up)
	holder.add_child(HullKit.reflector(r, mats, false))
	n.add_child(holder)
	return n


## The high-gain dish on an azimuth/elevation mount atop a mast at `base` (mast +Y):
## a turntable drum, a yoke, and the elevation axle with the reflector hung in front
## of it. A big dish gets braces at the mast's foot. Registers itself as the rig's
## dish; ship_rig.gd turns "az" about Y and "el" about X.
static func steerable_dish(base: Vector3, r: float, ctx: Dictionary) -> Node3D:
	var mats: Dictionary = ctx["mats"]
	var n := Node3D.new()
	var yoke_h := 0.3 + r * 0.12
	var mast_h := maxf(1.0, r * 1.05 + 0.4 - yoke_h)
	var mast_top := base + Vector3(0, mast_h, 0)
	var mast_w := 0.16 + r * 0.03
	n.add_child(strut(base, mast_top, mast_w, mats["steel"]))
	if r > 2.0:
		for s in [-1.0, 1.0]:
			n.add_child(strut(base + Vector3(s * r * 0.35, 0, 0), base + Vector3(0, mast_h * 0.6, 0), mast_w * 0.5, mats["steel"]))
	var az := Node3D.new()
	az.position = mast_top
	az.set_meta("no_merge", true)
	var drum_r := 0.22 + r * 0.06
	var drum := Kit.cylinder(drum_r, 0.22, mats["dark"], Vector3(0, 0.11, 0), 16)
	drum.rotation = Vector3.ZERO
	az.add_child(drum)
	var arm_x := drum_r * 0.9
	for s in [-1.0, 1.0]:
		az.add_child(Kit.box(Vector3(0.1 + r * 0.02, yoke_h, 0.14 + r * 0.03), mats["steel"], Vector3(s * arm_x, 0.22 + yoke_h * 0.5, 0)))
	var el := Node3D.new()
	el.position = Vector3(0, 0.22 + yoke_h, 0)
	az.add_child(el)
	el.add_child(Kit.box(Vector3(arm_x * 2.0 + 0.16, 0.09 + r * 0.02, 0.09 + r * 0.02), mats["dark"]))
	var reflector := HullKit.reflector(r, mats, bool(ctx.get("deep", false)))
	reflector.position = Vector3(0, 0, maxf(0.08, r * 0.2) + r * 0.12 + 0.05)
	el.add_child(reflector)
	n.add_child(az)
	ctx["rig"]["dish"] = {"az": az, "el": el}
	return n


## A panel on a boom: the boom is fixed, the panel turns about it. The panel spans
## `span` outward along X, `width` along Z; kind "solar" or "radiator". It is built
## in segments hinged along Z, so it can fold up accordion-fashion at the boom's end
## for docking (ShipRig.set_fold): each hinge is in the rig entry's "hinges".
static func boom_panel(root: Vector3, side: float, reach: float, span: float, width: float, kind: String, material: Material, ctx: Dictionary) -> Node3D:
	var mats: Dictionary = ctx["mats"]
	var n := Node3D.new()
	var boom_end := root + Vector3(side * reach, 0, 0)
	n.add_child(strut(root, boom_end, 0.22, mats["steel"]))
	var gimbal := Node3D.new()
	gimbal.position = boom_end
	gimbal.set_meta("no_merge", true)
	gimbal.add_child(Kit.box(Vector3(0.35, 0.35, 0.35), mats["dark"]))
	var segments := maxi(2, ceili(span / FOLD_SEGMENT_M))
	var seg := span / float(segments)
	var thick := 0.08 if kind == "solar" else 0.2
	var hinges := []
	var parent: Node3D = gimbal
	for k in segments:
		var hinge := Node3D.new()
		hinge.position = Vector3(side * (0.2 if k == 0 else seg), 0, 0)
		hinge.add_child(Kit.box(Vector3(seg * 0.97, thick, width), material, Vector3(side * seg * 0.5, 0, 0)))
		for f in [-0.5, 0.5]:
			hinge.add_child(Kit.box(Vector3(seg, 0.1, 0.08), mats["steel"], Vector3(side * seg * 0.5, 0, width * f)))
		parent.add_child(hinge)
		hinges.append(hinge)
		parent = hinge
	n.add_child(gimbal)
	ctx["rig"]["arrays"].append({"node": gimbal, "kind": kind, "hinges": hinges, "side": side})
	return n


## Panels fold in segments about this long (metres).
const FOLD_SEGMENT_M := 1.6


static func solar_cells(ctx: Dictionary) -> Material:
	return Livery.paint(ctx["livery"], Color("1d2b4a"), {"finish": 1, "mismatch": 0.0, "panel_m": 0.3, "roughness": 0.3, "metallic": 0.35, "wear": 0.1})


## Reaction-control quad: a block with four little nozzles.
static func rcs(at: Vector3, outward: Vector3, ctx: Dictionary) -> Node3D:
	var n := Node3D.new()
	n.position = at
	ctx["rig"]["rcs"].append({"node": n, "outward": outward.normalized()})
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
	# Windscreen: three framed panes on the upper slope of the nose under a brow that
	# shades them, a framed pane in each cheek, and a pair of docking windows under
	# the chin looking down the axis (HullKit.window: sapphire-faced, the deck lit
	# behind). The windscreen carries a faint gold sun film.
	var slope := atan((h * 0.5 - tip) / nose_len)
	var frame: Material = mats["dark"]
	var screen := Node3D.new()
	# Set on the skin: the nose's faces widen linearly from the tip.
	screen.position = Vector3(0, lerpf(tip, h * 0.5, 0.55) + 0.03, nose_len * 0.55)
	screen.basis = Basis(Vector3.RIGHT, -slope)
	var pane_len := nose_len / cos(slope) * 0.5
	var pane_w := w * 0.62 / 3.0
	for k in 3:
		var pane := HullKit.window(pane_w * 0.78, pane_len * 0.86, mats, frame, 0.6, 0.35)
		pane.position.x = (float(k) - 1.0) * pane_w
		screen.add_child(pane)
	screen.add_child(Kit.box(Vector3(w * 0.7, 0.08, 0.4), mats["hull"], Vector3(0, 0.16, pane_len * 0.5 + 0.22)))
	n.add_child(screen)
	for side in [1.0, -1.0]:
		var cheek := Node3D.new()
		cheek.position = Vector3(side * (lerpf(tip * w / h, w * 0.5, 0.6) + 0.03), h * 0.1, nose_len * 0.6)
		cheek.basis = Basis(Vector3.UP, side * atan((w * 0.5 - tip * w / h) / nose_len))
		var pane := HullKit.window(h * 0.2, nose_len * 0.3, mats, frame, 0.6)
		pane.basis = Basis(Vector3.BACK, -side * PI * 0.5)
		cheek.add_child(pane)
		n.add_child(cheek)
	var chin := Node3D.new()
	chin.position = Vector3(0, -lerpf(tip, h * 0.5, 0.45) - 0.03, nose_len * 0.45)
	chin.basis = Basis(Vector3.RIGHT, slope) * Basis(Vector3.BACK, PI)
	for s in [-1.0, 1.0]:
		var pane := HullKit.window(pane_w * 0.42, pane_len * 0.45, mats, frame, 0.5)
		pane.position.x = s * pane_w * 0.42
		chin.add_child(pane)
	n.add_child(chin)
	n.add_child(Kit.torus(0.9, 0.18, mats["trim"], Vector3(0, 0, -0.05), 20))
	# Docking floodlights either side of the collar.
	n.add_child(Kit.nav_light(Color("fff4d6"), Vector3(w * 0.3, h * 0.25, nose_len * 0.3), Vector3(0.3, 0.2, -1.0), 0.14))
	n.add_child(Kit.nav_light(Color("fff4d6"), Vector3(-w * 0.3, h * 0.25, nose_len * 0.3), Vector3(-0.3, 0.2, -1.0), 0.14))
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
		# Access panels high on the flanks (the name goes below), handrails along the
		# shoulders for whoever's outside.
		for f in [-0.32, -0.05]:
			var panel := HullKit.access_panel(rng.randf_range(0.45, 0.7), deck_len * 0.2, mats["hull"] if rng.randf() < 0.6 else Kit.mat("grey"))
			panel.basis = Basis(Vector3.BACK, -side * PI * 0.5)
			panel.position = Vector3(side * w * 0.5, h * 0.28, deck_len * f)
			deck.add_child(panel)
		deck.add_child(HullKit.handrail(Vector3(side * w * 0.4, h * 0.5, -deck_len * 0.42), Vector3(side * w * 0.4, h * 0.5, deck_len * 0.1), Vector3.UP))
	_name_stencils(deck, ctx["livery"], Vector3(w, h, deck_len))
	n.add_child(deck)
	# Crew hab: a pressure can with a domed aft head (its fore head is buried in the
	# deck), where they sleep, eat and argue. Two rows of portholes, some shuttered;
	# the EVA hatch to starboard; handrails along its back and belly.
	var hab_r := minf(w, h) * 0.48
	var hab_len := size.z * 0.9
	var hab_z := nose_len + deck_len + hab_len * 0.5
	var can := HullKit.vessel(hab_r, hab_len + hab_r * 0.5, mats["hull"], mats, 24)
	can["node"].position.z = hab_z - hab_r * 0.25
	n.add_child(can["node"])
	n.add_child(Kit.torus(hab_r + 0.02, 0.12, mats["steel"], Vector3(0, 0, hab_z - hab_len * 0.3), 24))
	n.add_child(Kit.torus(hab_r + 0.02, 0.12, mats["steel"], Vector3(0, 0, hab_z + hab_len * 0.2), 24))
	for row in [-0.12, 0.08]:
		for deg in [40.0, 140.0, 220.0, 320.0]:
			var a := deg_to_rad(deg)
			var d := Vector3(cos(a), sin(a), 0.0)
			var port := HullKit.porthole(0.2, mats, frame, rng.randf() < 0.25)
			port.basis = Basis.looking_at(-d, Vector3.BACK)
			port.position = d * hab_r + Vector3(0, 0, hab_z + hab_len * row)
			n.add_child(port)
	var hatch := HullKit.hatch(0.85, 1.1, mats)
	hatch.basis = Basis(Vector3.BACK, -PI * 0.5)
	hatch.position = Vector3(hab_r + 0.04, 0, hab_z + hab_len * 0.27)
	n.add_child(hatch)
	for deg in [65.0, 115.0, 250.0, 290.0]:
		var d := Vector3(cos(deg_to_rad(deg)), sin(deg_to_rad(deg)), 0.0)
		n.add_child(HullKit.handrail(d * hab_r + Vector3(0, 0, hab_z - hab_len * 0.42), d * hab_r + Vector3(0, 0, hab_z + hab_len * 0.4), d))
	# Deep-space kit on the hab's back: the high-gain dish (much bigger on a ship built
	# to go far: a weak signal needs a big ear), nav radar, aerials, star trackers.
	var top := Vector3(0, hab_r, hab_z)
	var deep := bool(ctx.get("deep", false))
	var dish_r := rng.randf_range(3.0, 3.6) if deep else rng.randf_range(1.1, 1.6)
	n.add_child(steerable_dish(top + Vector3(0, 0, hab_len * rng.randf_range(0.0, 0.25)), dish_r, ctx))
	# Housekeeping solar wings, for when the reactor is cold: one each side, in the
	# same plane as the radiators aft.
	var cells := solar_cells(ctx)
	var wing := rng.randf_range(3.0, 4.5)
	for side in [1.0, -1.0]:
		n.add_child(boom_panel(Vector3(side * hab_r, 0, hab_z - hab_len * 0.15), side, 0.8, wing, minf(hab_len * 0.55, 2.4), "solar", cells, ctx))
	n.add_child(dish(Vector3(w * 0.5, h * 0.3, deck_z), Vector3(1.0, 0.4, -0.2), 0.75 if deep else 0.45, ctx))
	for k in rng.randi_range(2, 4):
		var at := Vector3(rng.randf_range(-w, w) * 0.4, h * 0.5, nose_len + rng.randf_range(0.2, deck_len))
		n.add_child(aerial(at, Vector3(rng.randf_range(-0.3, 0.3), 1.0, rng.randf_range(0.0, 0.5)), rng.randf_range(1.2, 3.0), ctx))
	for side in [1.0, -1.0]:
		var tracker := Kit.box(Vector3(0.5, 0.4, 0.5), mats["dark"], Vector3(side * w * 0.35, -h * 0.5 - 0.2, deck_z))
		n.add_child(tracker)
		n.add_child(Kit.box(Vector3(0.22, 0.22, 0.3), Kit.mat("black"), Vector3(side * w * 0.35, -h * 0.5 - 0.35, deck_z - 0.35)))
	for c in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		n.add_child(rcs(Vector3(c.x * w * 0.5, c.y * h * 0.5, deck_z - deck_len * 0.3), Vector3(c.x, c.y, 0), ctx))
	return {"node": n, "length": nose_len + deck_len + hab_len, "radius": maxf(maxf(w, h) * 0.6 + 0.5, hab_r + dish_r * 2.1 + 0.7), "hull_r": maxf(w, h) * 0.6 + 0.5}


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


## A passenger can, next to the crew: a pressure vessel with domed heads, rows of
## portholes (a few shuttered by whoever's asleep behind them), a boarding hatch
## under it and handrails along its back.
static func _hab(m: Dictionary, ctx: Dictionary) -> Dictionary:
	var mats: Dictionary = ctx["mats"]
	var rng: RandomNumberGenerator = ctx["rng"]
	var size := _size(m)
	var r := maxf(size.x, size.y) * 0.5
	var n := Node3D.new()
	var can := HullKit.vessel(r, size.z, mats["hull"], mats, 24)
	can["node"].position.z = size.z * 0.5
	n.add_child(can["node"])
	var barrel: float = can["barrel"]
	var z0 := (size.z - barrel) * 0.5
	n.add_child(Kit.cylinder(r + 0.03, 0.7, mats["accent"], Vector3(0, 0, z0 + barrel * 0.08 + 0.35), 18))
	for f in [0.0, 1.0]:
		n.add_child(Kit.torus(r + 0.02, 0.12, mats["steel"], Vector3(0, 0, z0 + barrel * f), 24))
	var frame: Material = mats["dark"]
	for row in 4:
		for k in 10:
			var a := TAU * float(k) / 10.0
			if absf(sin(a)) > 0.95:
				continue
			var d := Vector3(cos(a), sin(a), 0.0)
			var port := HullKit.porthole(0.17, mats, frame, rng.randf() < 0.15, 0.6)
			port.basis = Basis.looking_at(-d, Vector3.BACK)
			port.position = d * r + Vector3(0, 0, z0 + barrel * (0.3 + 0.18 * row))
			n.add_child(port)
	var hatch := HullKit.hatch(1.1, 1.5, mats)
	hatch.basis = Basis(Vector3.BACK, PI)
	hatch.position = Vector3(0, -r - 0.04, z0 + barrel * 0.85)
	n.add_child(hatch)
	for deg in [72.0, 108.0]:
		var d := Vector3(cos(deg_to_rad(deg)), sin(deg_to_rad(deg)), 0.0)
		n.add_child(HullKit.handrail(d * r + Vector3(0, 0, z0 + barrel * 0.05), d * r + Vector3(0, 0, z0 + barrel * 0.95), d))
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
	lander.add_child(Kit.box(Vector3(size.x * 0.4, 0.06, size.z * 0.12), HullKit.glass(mats, 0.5), Vector3(0, size.y * 0.1 + size.x * 0.3, -size.z * 0.15)))
	var engine := small_bell(size.x * 0.07, size.x * 0.22, size.y * 0.3, mats["steel"], mats["black"])
	engine.position = Vector3(0, -size.y * 0.05, 0)
	engine.basis = Basis(Vector3.RIGHT, PI * 0.5)  # bell opening down
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
			for f in [-1.0, 1.0]:
				t.add_child(Kit.box(Vector3(0.35, 0.35, 0.18), mats["steel"], Vector3(0, 0, f * (s.x * 0.5 + 0.05))))
		else:
			# A gas cylinder: domed heads, not flat ends.
			var vessel := HullKit.vessel(s.x * 0.5, s.z, mats["foil"], mats, 24)
			t.add_child(vessel["node"])
			var barrel: float = vessel["barrel"]
			t.add_child(Kit.hazard_band(s.x * 0.5 + 0.02, 0.4, Vector3(0, 0, barrel * 0.36), 12))
			t.add_child(Kit.torus(s.x * 0.5 + 0.03, 0.12, mats["accent"], Vector3(0, 0, -barrel * 0.34), 32))
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
		if dm["look"].get("shape", "") == "sail":
			radius = maxf(radius, float(dm["look"].get("span_m", 300.0)) * 0.72)
	# All the drives' plumes switch together: jets, hot walls and one stern light.
	var plumes := Node3D.new()
	plumes.name = "DrivePlume"
	var lit := 0
	var stern := Vector3.ZERO
	for k in count:
		var dm: Dictionary = drives[k][1]
		var ds := _size(dm)
		if dm["look"].get("shape", "") in ["sail", "climber"]:
			continue
		plumes.add_child(_plume(dm, ds, offsets[k] + Vector3(0, 0, z), float(ctx["livery"].get("seed", 0.0)) + 3.7 * k))
		var nzk := _nozzle(dm, ds)
		stern += offsets[k] + Vector3(0, 0, z + float(nzk["z_t"]) + float(nzk["lb"]) * 0.3)
		lit += 1
	if lit > 0:
		# The plasma lights the stern a little. The light sits up in the bell, where the
		# jet is brightest, so it lights the bell's inside and not the lip's face.
		var glow := OmniLight3D.new()
		glow.light_color = Color("b8b0ff")
		glow.light_energy = 0.7
		glow.set_meta("energy", 0.7)
		glow.omni_range = 6.0 + spread * 2.0 + drive_r * 3.0
		glow.omni_attenuation = 2.0
		glow.shadow_enabled = false
		glow.position = stern / float(lit)
		plumes.add_child(glow)
	n.add_child(plumes)
	radius = maxf(radius, shield_r)
	return {"node": n, "length": z + drive_len, "radius": radius, "shield": shield_z}


## One drive: reactor drum, the magnetic nozzle (_nozzle_hardware), and the
## barnacles: pumps, pipe runs to the tanks, gas bottles, cable trays, RCS.
static func _drive(m: Dictionary, s: Vector3, ctx: Dictionary, index: int) -> Node3D:
	if m["look"].get("shape", "") == "sail":
		return _sail(m, s, ctx)
	if m["look"].get("shape", "") == "climber":
		return _climber_drive(s, ctx)
	var mats: Dictionary = ctx["mats"]
	var rng: RandomNumberGenerator = ctx["rng"]
	var n := Node3D.new()
	var r := s.x * 0.46
	var reactor_len := s.z * 0.75
	n.add_child(Kit.cylinder(r, reactor_len, mats["steel"], Vector3(0, 0, reactor_len * 0.5), 14))
	for f in [0.2, 0.55, 0.85]:
		n.add_child(Kit.torus(r + 0.05, 0.14, mats["dark"], Vector3(0, 0, reactor_len * f), 24))
	n.add_child(Kit.cylinder(r + 0.06, 0.5, mats["accent"], Vector3(0, 0, reactor_len * 0.38), 14))
	# The nozzle: a hollow bell turned on a lathe, its magnetic coil stack, the coolant
	# manifold, feed lines and the gimbal rams (see _nozzle_hardware).
	n.add_child(_nozzle_hardware(m, s, ctx, index))
	# Thrust frame: a cage of longerons from the shield to the thrust plate.
	for k in 6:
		var a := TAU * float(k) / 6.0 + 0.3
		var d := Vector3(cos(a), sin(a), 0)
		n.add_child(strut(d * (r + 0.7) + Vector3(0, 0, -0.1), d * (r + 0.12) + Vector3(0, 0, reactor_len - 0.05), 0.16, mats["steel"]))
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
	# The drive's red rotating beacon: keep clear when it's lit.
	n.add_child(Kit.nav_light(Color("ff3a2a"), Vector3(0, r + 0.1, 0.3), Vector3.UP, 0.18, "beacon", 2.0, 0.25 * index))
	return n


## A fusion drive's nozzle, in the drive's own frame (aft is +Z): where the throat
## and lip are, their radii, the wall, and the bell's inner contour from the chamber
## to the lip as (radius, z) points. Shared by the hardware and the plume.
static func _nozzle(m: Dictionary, s: Vector3) -> Dictionary:
	var reactor_len := s.z * 0.75
	var z_t := reactor_len + 0.55
	var z_e := reactor_len + 0.2 + s.z * 0.7
	var rt := s.x * 0.13
	var re := s.x * 0.66
	var lb := z_e - z_t
	var rc := s.x * 0.46 * 0.55
	var c := PackedVector2Array()
	# Convergent: straight in from the chamber, then a tight arc into the throat.
	var up := deg_to_rad(35.0)
	var arc_u := 1.5 * rt
	var arc_start := Vector2(rt + arc_u * (1.0 - cos(up)), -arc_u * sin(up))
	c.append(Vector2(rc, reactor_len - z_t))
	c.append(Vector2(lerpf(rc, arc_start.x, 0.5), lerpf(reactor_len - z_t, arc_start.y, 0.5)))
	for i in 5:
		var a := -up * (1.0 - float(i) / 4.0)
		c.append(Vector2(rt + arc_u * (1.0 - cos(a)), arc_u * sin(a)))
	# Divergent: Rao's short arc out of the throat to the initial angle, then a
	# parabola (a quadratic Bezier) turning to the shallow exit angle at the lip.
	var tn := deg_to_rad(36.0)
	var te := deg_to_rad(9.0)
	var arc_d := 0.382 * rt
	for i in range(1, 4):
		var a := tn * float(i) / 3.0
		c.append(Vector2(rt + arc_d * (1.0 - cos(a)), arc_d * sin(a)))
	var p0 := Vector2(c[c.size() - 1].y, c[c.size() - 1].x)  # (z, r)
	var p2 := Vector2(lb, re)
	var z1 := (p2.y - p0.y - p2.x * tan(te) + p0.x * tan(tn)) / (tan(tn) - tan(te))
	z1 = clampf(z1, p0.x + (lb - p0.x) * 0.1, lb * 0.9)
	var p1 := Vector2(z1, minf(p0.y + (z1 - p0.x) * tan(tn), re))
	for i in range(1, 17):
		var u := float(i) / 16.0
		var b := p0 * (1.0 - u) * (1.0 - u) + p1 * 2.0 * u * (1.0 - u) + p2 * u * u
		c.append(Vector2(b.y, b.x))
	# Into the drive's frame.
	for i in c.size():
		c[i] = Vector2(c[i].x, c[i].y + z_t)
	return {"z_t": z_t, "z_e": z_e, "rt": rt, "re": re, "lb": lb, "reactor_len": reactor_len,
		"wall": clampf(s.x * 0.016, 0.035, 0.08), "inner": c, "coils": int(m["look"].get("coils", 2)),
		"joint": 0.62}


## A profile pushed `by` metres off its own surface (positive: away from the axis).
static func _offset(c: PackedVector2Array, by: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in c.size():
		var t := (c[mini(i + 1, c.size() - 1)] - c[maxi(i - 1, 0)]).normalized()
		out.append(c[i] + Vector2(t.y, -t.x) * by)
	return out


## The bell's radius (inner wall) at the drive's z.
static func _bell_r(c: PackedVector2Array, z: float) -> float:
	for i in c.size() - 1:
		if z <= c[i + 1].y:
			return lerpf(c[i].x, c[i + 1].x, clampf((z - c[i].y) / maxf(c[i + 1].y - c[i].y, 1e-4), 0.0, 1.0))
	return c[c.size() - 1].x


## A ring of rectangular section turned on the lathe: four faces, hard edges.
static func _ring(r_in: float, r_out: float, z0: float, z1: float) -> Array:
	return [PackedVector2Array([Vector2(r_out, z0), Vector2(r_out, z1)]),
		PackedVector2Array([Vector2(r_out, z1), Vector2(r_in, z1)]),
		PackedVector2Array([Vector2(r_in, z1), Vector2(r_in, z0)]),
		PackedVector2Array([Vector2(r_in, z0), Vector2(r_out, z0)])]


## The bell and everything bolted round it. A D-He3 drive at tens of thousands of
## seconds cannot hold its plasma with a wall, so the field does it: a stack of
## superconducting coils round the throat and upper bell shapes the jet, and the
## bell is a heat shield and a skirt. The upper bell is tube-wall, regeneratively
## cooled, feeding a manifold at the joint; aft of that the skirt is radiation-cooled
## and glows when the drive is lit. Two gimbal rams from the thrust plate steer it.
static func _nozzle_hardware(m: Dictionary, s: Vector3, ctx: Dictionary, index: int) -> Node3D:
	var mats: Dictionary = ctx["mats"]
	var nz := _nozzle(m, s)
	var n := Node3D.new()
	var c: PackedVector2Array = nz["inner"]
	var wall: float = nz["wall"]
	var outer := _offset(c, wall)
	var z_t: float = nz["z_t"]
	var z_e: float = nz["z_e"]
	var lb: float = nz["lb"]
	var r := s.x * 0.46
	var reactor_len: float = nz["reactor_len"]
	var mats_n := _nozzle_mats(m, nz, ctx)
	# The bell itself: outer wall aft, a square lip, inner wall forward to the chamber.
	var inner_rev := c.duplicate()
	inner_rev.reverse()
	n.add_child(Kit.lathe([outer, PackedVector2Array([outer[outer.size() - 1], c[c.size() - 1]])], mats_n[0], 40))
	n.add_child(Kit.lathe([inner_rev], mats_n[1], 40))
	# Thrust plate where the bell bolts to the reactor.
	n.add_child(Kit.lathe(_ring(c[0].x - 0.05, r + 0.15, reactor_len - 0.12, reactor_len + 0.04), mats["steel"], 28))
	# Lip stiffener, and two stiffening bands on the skirt.
	var lip_r := _bell_r(outer, z_e - 0.1)
	n.add_child(Kit.lathe(_ring(lip_r - 0.01, lip_r + 0.06, z_e - 0.16, z_e - 0.01), mats["dark"], 40))
	var joint_z := z_t + lb * float(nz["joint"])
	for f in [0.42, 0.75]:
		var bz := lerpf(joint_z, z_e, f)
		var br := _bell_r(outer, bz)
		n.add_child(Kit.lathe(_ring(br - 0.01, br + 0.035, bz - 0.05, bz + 0.05), mats["steel"], 40))
	# Magnetic coil stack: a heavy throat coil, then lighter ones down the upper bell,
	# each a cryostat can with its winding showing in a copper band.
	var coils: int = maxi(1, nz["coils"])
	var copper := Kit.paint(Color("8a5a2a"), {"finish": 1, "metallic": 0.8, "roughness": 0.4})
	var coil_rings := []
	for k in coils:
		var f := 0.0 if coils == 1 else float(k) / float(coils - 1)
		var cz := z_t + lb * lerpf(-0.02, 0.5, f)
		var cw := s.x * (0.13 if k == 0 else 0.085)
		var r_in := _bell_r(outer, cz + cw * 0.5) + 0.12
		var r_out := r_in + s.x * (0.13 if k == 0 else 0.07)
		coil_rings.append([r_out, cz])
		n.add_child(Kit.lathe(_ring(r_in, r_out, cz - cw * 0.5, cz + cw * 0.5), mats["dark"], 32))
		n.add_child(Kit.lathe(_ring(r_out - 0.02, r_out + 0.025, cz - cw * 0.22, cz + cw * 0.22), copper, 32))
	# Tie rods: from the thrust plate out over each coil in turn, a stepped cage.
	for k in 6:
		var a := TAU * float(k) / 6.0
		var d := Vector3(cos(a), sin(a), 0)
		var prev := d * (r * 0.95) + Vector3(0, 0, reactor_len + 0.04)
		for ring in coil_rings:
			var here: Vector3 = d * (float(ring[0]) + 0.05) + Vector3(0, 0, float(ring[1]))
			n.add_child(rod(prev, here, 0.045, mats["steel"], 6))
			prev = here
	# Coolant: tubes forward under the coils from the manifold at the joint, and two
	# fat propellant feeds from the drum round to the injector ring at the throat.
	var man_r := _bell_r(outer, joint_z) + 0.1
	n.add_child(Kit.torus(man_r, 0.075, mats["steel"], Vector3(0, 0, joint_z), 40))
	var inj_z := lerpf(reactor_len, z_t, 0.45)
	var inj_r := _bell_r(outer, inj_z) + 0.1
	n.add_child(Kit.torus(inj_r, 0.07, mats["steel"], Vector3(0, 0, inj_z), 28))
	for k in 8:
		var a := TAU * (float(k) + 0.5) / 8.0
		var d := Vector3(cos(a), sin(a), 0)
		var prev := d * man_r + Vector3(0, 0, joint_z)
		for f in [0.65, 0.35, 0.08]:
			var pz := lerpf(z_t, joint_z, f)
			var here := d * (_bell_r(outer, pz) + 0.07) + Vector3(0, 0, pz)
			n.add_child(rod(prev, here, 0.03, mats["steel"], 6))
			prev = here
		n.add_child(rod(prev, d * inj_r + Vector3(0, 0, inj_z), 0.03, mats["steel"], 6))
	for side in [1.0, -1.0]:
		var d := Vector3(side * 0.94, -0.34, 0).normalized()
		var p0 := d * (r + 0.16) + Vector3(0, 0, reactor_len * 0.55)
		var p1 := d * (r + 0.16) + Vector3(0, 0, reactor_len - 0.25)
		var p2 := d * (r * 0.62) + Vector3(0, 0, reactor_len + 0.12)
		n.add_child(rod(p0, p1, 0.09, mats["steel"], 8))
		n.add_child(rod(p1, p2, 0.09, mats["steel"], 8))
		n.add_child(rod(p2, d * (inj_r + 0.05) + Vector3(0, 0, inj_z), 0.08, mats["steel"], 8))
		n.add_child(Kit.box(Vector3(0.3, 0.3, 0.3), mats["dark"], p1))
	# Gimbal rams, pitch and yaw, from clevises on the thrust plate to the last coil.
	var last: Array = coil_rings[coil_rings.size() - 1]
	for k in 2:
		var a := PI * 0.25 + PI * 0.5 * float(k) + (PI if index % 2 == 1 else 0.0)
		var d := Vector3(cos(a), sin(a), 0)
		var anchor := d * (r + 0.32) + Vector3(0, 0, reactor_len - 0.45)
		var tip := d * (float(last[0]) + 0.12) + Vector3(0, 0, float(last[1]))
		n.add_child(rod(anchor, anchor.lerp(tip, 0.58), 0.11, mats["dark"], 10))
		n.add_child(rod(anchor.lerp(tip, 0.5), tip, 0.05, mats["steel"], 8))
		n.add_child(Kit.box(Vector3(0.26, 0.26, 0.3), mats["steel"], anchor))
		n.add_child(Kit.box(Vector3(0.2, 0.2, 0.22), mats["steel"], tip))
		n.add_child(Kit.box(Vector3(0.36, 0.2, 0.36), Kit.mat("black"), anchor + Vector3(0, 0, -0.3)))
	return n


## The bell's outer and inner finishes, one pair per ship and drive type.
static func _nozzle_mats(m: Dictionary, nz: Dictionary, ctx: Dictionary) -> Array:
	var key := "nozzle_mats_%s" % m["name"]
	if ctx.has(key):
		return ctx[key]
	var livery: Dictionary = ctx["livery"]
	var dark := String(m["look"].get("colour", "grey")) == "dark"
	var out := []
	for inner in [0.0, 1.0]:
		var mm := ShaderMaterial.new()
		mm.shader = load("res://view/shaders/nozzle.gdshader")
		mm.set_shader_parameter("paint", Color("3e3a36") if dark else Color("5a4a3c"))
		mm.set_shader_parameter("z_throat", nz["z_t"])
		mm.set_shader_parameter("z_exit", nz["z_e"])
		mm.set_shader_parameter("joint", nz["joint"])
		mm.set_shader_parameter("tubes", roundf(float(nz["re"]) * 40.0))
		mm.set_shader_parameter("girth", float(nz["re"]) * TAU)
		mm.set_shader_parameter("inner", inner)
		mm.set_shader_parameter("wear", float(livery.get("wear", 0.4)))
		mm.set_shader_parameter("seed", float(livery.get("seed", 0.0)))
		out.append(mm)
	ctx[key] = out
	return out


## What a lit drive shows, under the ship's DrivePlume: the plasma jet (two raymarched
## bounds that meet at the exit plane, view/shaders/exhaust.gdshader) and the bell's
## walls glowing with heat (view/shaders/heat.gdshader). `at` is the drive's origin.
static func _plume(m: Dictionary, s: Vector3, at: Vector3, seed: float) -> Node3D:
	var nz := _nozzle(m, s)
	var n := Node3D.new()
	n.position = at
	var c: PackedVector2Array = nz["inner"]
	var z_t: float = nz["z_t"]
	var z_e: float = nz["z_e"]
	var lb: float = nz["lb"]
	var rt: float = nz["rt"]
	var re: float = nz["re"]
	var isp := float(m.get("isp_s", 30000.0))
	# The faster the exhaust, the tighter and longer the jet.
	var spread := clampf(0.2 - 0.02 * log(isp / 10000.0) / log(2.0), 0.06, 0.18)
	var plume_len := lb * 14.0
	var exhaust := load("res://view/shaders/exhaust.gdshader")
	var base := {"rt": rt, "re": re, "lb": lb, "spread": spread, "fade": lb * 6.0, "seed": seed, "brightness": 1.6}
	# Inside the bell: a bound just off the inner wall, throat-relative.
	# It starts a hand's breadth aft of the reactor's face, so looking up the throat
	# the plasma is in front of it.
	var inside := _offset(c, -0.04)
	var fore := float(nz["reactor_len"]) + 0.08
	var bound := PackedVector2Array([Vector2(0.0, fore - z_t), Vector2(_bell_r(inside, fore), fore - z_t)])
	for p in inside:
		if p.y > fore:
			bound.append(Vector2(maxf(p.x, 0.01), p.y - z_t))
	bound.append(Vector2(0.0, lb))
	var in_mat := ShaderMaterial.new()
	in_mat.shader = exhaust
	for k in base:
		in_mat.set_shader_parameter(k, base[k])
	in_mat.set_shader_parameter("z_from", bound[0].y)
	in_mat.set_shader_parameter("z_to", lb)
	in_mat.set_shader_parameter("r_from", re)
	in_mat.set_shader_parameter("r_bound", re)
	var inner_vol := Kit.lathe([bound], in_mat, 28, Vector3(0, 0, z_t))
	inner_vol.set_meta("brightness", 1.6)
	n.add_child(inner_vol)
	# Aft of the lip: a cone wide enough to hold the jet's soft edge.
	var w_end := re * 0.55 + plume_len * spread
	var free := PackedVector2Array([Vector2(0.0, lb), Vector2(re * 0.97, lb), Vector2(w_end * 1.8, lb + plume_len), Vector2(0.0, lb + plume_len)])
	var out_mat := in_mat.duplicate() as ShaderMaterial
	out_mat.set_shader_parameter("z_from", lb)
	out_mat.set_shader_parameter("z_to", lb + plume_len)
	out_mat.set_shader_parameter("r_from", re * 0.97)
	out_mat.set_shader_parameter("r_bound", w_end * 1.8)
	out_mat.set_shader_parameter("end_fade", plume_len * 0.35)
	var outer_vol := Kit.lathe([free], out_mat, 28, Vector3(0, 0, z_t))
	outer_vol.set_meta("brightness", 1.6)
	n.add_child(outer_vol)
	# Heat: the inner wall hottest at the throat, the skirt aft of the joint.
	var heat := load("res://view/shaders/heat.gdshader")
	var in_skin := _offset(c, -0.012)
	in_skin.reverse()
	var outer_skin := PackedVector2Array()
	var joint_z := z_t + lb * float(nz["joint"])
	for p in _offset(c, float(nz["wall"]) + 0.012):
		if p.y >= joint_z - 0.05:
			outer_skin.append(p)
	var joint := float(nz["joint"])
	for spec in [[in_skin, -0.25, 0.0, 0.55, 0.6], [outer_skin, joint, joint + 0.12, 1.05, 0.5]]:
		var hm := ShaderMaterial.new()
		hm.shader = heat
		hm.set_shader_parameter("z_throat", z_t)
		hm.set_shader_parameter("z_exit", z_e)
		hm.set_shader_parameter("rise", spec[1])
		hm.set_shader_parameter("peak", spec[2])
		hm.set_shader_parameter("end", spec[3])
		hm.set_shader_parameter("brightness", spec[4])
		hm.set_shader_parameter("seed", seed)
		var skin := Kit.lathe([spec[0]], hm, 40)
		skin.set_meta("brightness", spec[4])
		n.add_child(skin)
	return n


## Throttle a ship's lit drives, 0 to 1. Views that only show and hide DrivePlume
## needn't call this; it starts at full.
static func set_throttle(plume: Node3D, throttle: float) -> void:
	for node in plume.find_children("*", "", true, false):
		if node is MeshInstance3D and node.has_meta("brightness"):
			(node.material_override as ShaderMaterial).set_shader_parameter("brightness", float(node.get_meta("brightness")) * throttle)
		elif node is OmniLight3D and node.has_meta("energy"):
			node.light_energy = float(node.get_meta("energy")) * throttle

## A solar sail on the stern: a boom hub, four booms out to the corners, and a square
## of aluminised film hundreds of metres across, square to the keel. Sunlight does the
## pushing, so there is no plume.
static func _sail(m: Dictionary, s: Vector3, ctx: Dictionary) -> Node3D:
	var mats: Dictionary = ctx["mats"]
	var n := Node3D.new()
	var span := float(m["look"].get("span_m", 300.0))
	n.add_child(Kit.cylinder(s.x * 0.45, s.z, mats["dark"], Vector3(0, 0, s.z * 0.5), 12))
	n.add_child(Kit.torus(s.x * 0.5, 0.12, mats["accent"], Vector3(0, 0, s.z * 0.3), 20))
	var film_z := s.z + 0.5
	var film := Kit.paint(Color("9ea4ad"), {"finish": 2, "panel_m": span / 24.0, "wear": 0.04, "mismatch": 0.0, "roughness": 0.4, "metallic": 0.8})
	var boom_mat := Kit.paint(Color("8c9196"), {"finish": 1, "wear": 0.1, "mismatch": 0.0})
	for k in 4:
		var boom := Node3D.new()
		boom.rotation.z = TAU * float(k) / 4.0 + PI * 0.25
		boom.position = Vector3(0, 0, film_z)
		boom.add_child(Kit.box(Vector3(span * 0.707, 2.5, 2.5), boom_mat, Vector3(span * 0.354, 0, 0)))
		n.add_child(boom)
	# Four quadrants, each billowed a little by the light pushing on it.
	for k in 4:
		var quad := Node3D.new()
		quad.rotation.z = TAU * float(k) / 4.0
		quad.position = Vector3(0, 0, film_z + 0.4)
		var panel := Node3D.new()
		panel.rotation.y = deg_to_rad(2.5)
		panel.add_child(Kit.box(Vector3(span * 0.5, span * 0.5, 0.05), film, Vector3(span * 0.25, span * 0.25, 0)))
		quad.add_child(panel)
		n.add_child(quad)
	for k in 4:
		var a := TAU * float(k) / 4.0 + PI * 0.25
		n.add_child(Kit.beacon(Color("ff3a2a"), Vector3(cos(a), sin(a), 0) * span * 0.707 + Vector3(0, 0, film_z), 2.0, 2.0, float(k) * 0.25))
	return n


## A climber's traction head: the ribbon runs through a slot between pairs of
## wheels, with the power pickup and its photovoltaic skirt round it.
static func _climber_drive(s: Vector3, ctx: Dictionary) -> Node3D:
	var mats: Dictionary = ctx["mats"]
	var n := Node3D.new()
	n.add_child(Kit.box(Vector3(s.x, s.y, s.z * 0.6), Kit.mat("yellow"), Vector3(0, 0, s.z * 0.3)))
	for side in [-1.0, 1.0]:
		for k in 3:
			var wheel := Kit.cylinder(0.6, 0.4, mats["dark"], Vector3(side * 0.5, 0, 0.6 + 0.9 * k), 16)
			wheel.rotation = Vector3(0, 0, PI * 0.5)
			n.add_child(wheel)
	n.add_child(Kit.cylinder(s.x * 0.9, 0.2, solar_cells(ctx), Vector3(0, 0, s.z * 0.65), 24))
	n.add_child(Kit.beacon(Color("ff3a2a"), Vector3(0, s.y * 0.55, s.z * 0.3), 0.2, 1.4))
	return n


## A small hollow bell for landers and work craft, throat at the origin opening
## toward +Z: a bell-curved wall with a lip, `outside` and `inside` finishes.
static func small_bell(rt: float, re: float, length: float, outside: Material, inside: Material) -> Node3D:
	var c := PackedVector2Array()
	for i in 13:
		var u := float(i) / 12.0
		c.append(Vector2(lerpf(rt, re, 1.0 - pow(1.0 - u, 1.8)), u * length))
	var outer := _offset(c, maxf(0.02, re * 0.04))
	var inner := c.duplicate()
	inner.reverse()
	var n := Node3D.new()
	n.add_child(Kit.lathe([outer, PackedVector2Array([outer[outer.size() - 1], c[c.size() - 1]])], outside, 20))
	n.add_child(Kit.lathe([inner], inside, 20))
	n.add_child(Kit.lathe(_ring(rt * 0.6, rt * 1.6, -0.12, 0.02), outside, 16))
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
