## Detail parts for crewed and working hardware, shared by ship_builder.gd and
## kestrel.gd:
##   - reflector(): a dish with a real parabolic reflector, ribbed back and a feed
##   - window() and porthole(): framed glass, bolted bezels, gaskets and shutters
##   - handrail(), hatch() and access_panel(): what crews hold, open and unbolt
##   - vessel(): a pressure vessel with domed heads, like a gas cylinder
## Built from the kit's primitives. Apart from the dish face (its panels are laid out
## round its axis), every part merges, so the detail costs vertices, not draw calls.
##
## The glass is the 2060s' (view/shaders/glass.gdshader): synthetic sapphire faced
## over aluminium oxynitride, the transparent ceramic. A lit cabin shows through it,
## it reflects at a grazing angle, and it glints in the Sun.
extends RefCounted

const Kit := preload("res://view/flight/kit.gd")
const GLASS_SHADER := "res://view/shaders/glass.gdshader"


## Window glass, made once per livery (kept in its `mats`) so the panes merge.
## warmth: how brightly the cabin behind is lit; coating: a gold sun film (0 to 1).
static func glass(mats: Dictionary, warmth: float = 0.45, coating: float = 0.0) -> ShaderMaterial:
	var key := "glass_%0.2f_%0.2f" % [warmth, coating]
	if mats.has(key):
		return mats[key]
	var m := ShaderMaterial.new()
	m.shader = load(GLASS_SHADER)
	m.set_shader_parameter("warmth", warmth)
	m.set_shader_parameter("coating", coating)
	mats[key] = m
	return m


## A box from a to b, `w` square: ribs, struts, rails.
static func bar(a: Vector3, b: Vector3, w: float, material: Material) -> MeshInstance3D:
	var d := b - a
	var mi := Kit.box(Vector3(w, w, maxf(d.length(), 0.001)), material, (a + b) * 0.5)
	if d.length() > 0.001:
		var up := Vector3.UP if absf(d.normalized().dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
		mi.basis = Basis.looking_at(d.normalized(), up)
	return mi


## A flat ring facing +Z between radii ri and ro, `h` proud of z = 0 (ri 0 for a disc).
static func annulus(ri: float, ro: float, h: float, material: Material, sides: int = 20) -> MeshInstance3D:
	var top := PackedVector2Array([Vector2(ro, h), Vector2(ri, h)])
	var rim := PackedVector2Array([Vector2(ro, 0.0), Vector2(ro, h)])
	var strips := [rim, top]
	if ri > 0.0:
		strips.append(PackedVector2Array([Vector2(ri, h), Vector2(ri, 0.0)]))
	return Kit.lathe(strips, material, sides)


# --- dishes ------------------------------------------------------------------------

## A dish of radius r opening toward +Z, its vertex at the origin. f/D is 0.38. Parts:
##   - the face: a paraboloid in white panels, laid in rings round the axis
##   - a rolled rim
##   - the back: radial ribs and a hoop, and a hub with the receiver in foil
##   - the feed. Big dishes are Cassegrain: a horn at the vertex and a subreflector
##     at the focus on four struts. Small ones carry a feed box at the focus on three.
## A deep-space dish also carries a low-gain horn on the subreflector, for when the
## big one can't point home.
static func reflector(r: float, mats: Dictionary, deep: bool = false) -> Node3D:
	var n := Node3D.new()
	var f := r * 0.76
	var depth := r * r / (4.0 * f)
	var t := maxf(0.012, r * 0.012)
	var steps := 12
	var face := PackedVector2Array()
	var back := PackedVector2Array()
	for i in steps + 1:
		# Rim to vertex is the face (it faces the opening); vertex to rim the back.
		var rho_in := r * float(steps - i) / float(steps)
		face.append(Vector2(rho_in, rho_in * rho_in / (4.0 * f)))
		var rho_out := r * float(i) / float(steps)
		back.append(Vector2(rho_out, rho_out * rho_out / (4.0 * f) - t))
	var sides := 48 if r > 2.0 else (32 if r > 0.8 else 20)
	n.add_child(Kit.lathe([face], _dish_face(mats, r), sides))
	var back_mat: Material = Kit.mat("grey")
	n.add_child(Kit.lathe([back, PackedVector2Array([Vector2(r, depth - t), Vector2(r, depth)])], back_mat, sides))
	n.add_child(Kit.torus(r, maxf(0.01, r * 0.014), back_mat, Vector3(0, 0, depth - t * 0.5), sides))
	var steel: Material = mats["steel"]
	# The back structure: ribs following the curve in three straight runs, a hoop
	# where they're stiffest, and the hub.
	if r >= 0.8:
		var ribs := 12 if r > 2.0 else 8
		var rib_w := maxf(0.025, r * 0.03)
		for k in ribs:
			var a := TAU * float(k) / float(ribs)
			var d := Vector3(cos(a), sin(a), 0.0)
			var pts := []
			for rho in [r * 0.16, r * 0.45, r * 0.75, r * 0.98]:
				pts.append(d * rho + Vector3(0, 0, rho * rho / (4.0 * f) - t - rib_w * 0.75))
			for i in pts.size() - 1:
				n.add_child(bar(pts[i], pts[i + 1], rib_w, steel))
		var hoop := r * 0.62
		n.add_child(Kit.torus(hoop, rib_w * 0.5, steel, Vector3(0, 0, hoop * hoop / (4.0 * f) - t - rib_w * 0.75), sides))
	n.add_child(Kit.cylinder(maxf(0.06, r * 0.17), maxf(0.08, r * 0.2), mats["foil"], Vector3(0, 0, -t - maxf(0.08, r * 0.2) * 0.5), 12))
	n.add_child(Kit.box(Vector3(r * 0.22, r * 0.16, r * 0.12) + Vector3.ONE * 0.04, mats["dark"], Vector3(0, 0, -t - maxf(0.08, r * 0.2) - r * 0.06)))
	# The feed.
	var white: Material = Kit.mat("offwhite")
	var strut_w := maxf(0.02, r * 0.016)
	if r >= 1.0:
		n.add_child(Kit.cone(r * 0.075, r * 0.045, r * 0.26, white, Vector3(0, 0, r * 0.13), 16))
		var z_s := f * 0.86
		var r_s := r * 0.12
		n.add_child(Kit.cone(r_s * 0.25, r_s, r * 0.04, back_mat, Vector3(0, 0, z_s), 20))
		for k in 4:
			var a := TAU * (float(k) + 0.5) / 4.0
			var d := Vector3(cos(a), sin(a), 0.0)
			n.add_child(bar(d * r * 0.95 + Vector3(0, 0, depth * 0.95), d * r_s * 0.6 + Vector3(0, 0, z_s - r * 0.01), strut_w, white))
		if deep:
			n.add_child(Kit.cone(r * 0.05, r * 0.03, r * 0.1, mats["foil"], Vector3(0, 0, z_s + r * 0.07), 12))
	else:
		var feed := maxf(0.05, r * 0.16)
		n.add_child(Kit.box(Vector3(feed, feed, feed * 1.4), mats["dark"], Vector3(0, 0, f)))
		for k in 3:
			var a := TAU * float(k) / 3.0 + PI * 0.5
			var d := Vector3(cos(a), sin(a), 0.0)
			n.add_child(bar(d * r * 0.93 + Vector3(0, 0, depth * 0.93), d * feed * 0.3 + Vector3(0, 0, f - feed * 0.5), maxf(0.012, r * 0.02), white))
	return n


## The dish face: white thermal paint in panels laid round the axis, barely worn
## (crews keep them clean; a dirty dish loses gain). Panel size scales with the dish.
static func _dish_face(mats: Dictionary, r: float) -> ShaderMaterial:
	var panel := snappedf(clampf(r * 0.2, 0.08, 0.8), 0.02)
	var key := "dish_face_%0.2f" % panel
	if mats.has(key):
		return mats[key]
	var m := Kit.paint(Color("e2dfd6"), {"wear": 0.08, "mismatch": 0.02, "panel_m": panel, "roughness": 0.65})
	m.set_shader_parameter("mapping", 3)
	mats[key] = m
	return m


# --- windows -----------------------------------------------------------------------

## A framed window facing +Y, `w` across (X) by `l` along (Z). The pane sits a little
## back in its frame, behind a black gasket, with a raised bezel bolted all round.
## frame_w sets the bezel's width (else it follows the pane, 5 to 12 cm); a station's
## windows leave the bolts off (`bolts`), too small to see at that scale.
static func window(w: float, l: float, mats: Dictionary, frame: Material, warmth: float = 0.45, coating: float = 0.0, frame_w: float = -1.0, bolts: bool = true) -> Node3D:
	var n := Node3D.new()
	var fw := frame_w if frame_w > 0.0 else clampf(minf(w, l) * 0.12, 0.05, 0.12)
	var fh := fw * 0.75
	var g := fw * 0.3
	n.add_child(Kit.box(Vector3(w, 0.03, l), glass(mats, warmth, coating), Vector3(0, -0.01, 0)))
	var black: Material = Kit.mat("black")
	for s in [-1.0, 1.0]:
		n.add_child(Kit.box(Vector3(w + g * 2.0, fh * 0.5, g), black, Vector3(0, fh * 0.25, s * (l + g) * 0.5)))
		n.add_child(Kit.box(Vector3(g, fh * 0.5, l), black, Vector3(s * (w + g) * 0.5, fh * 0.25, 0)))
	var ow := w + g * 2.0
	var ol := l + g * 2.0
	for s in [-1.0, 1.0]:
		n.add_child(Kit.box(Vector3(ow + fw * 2.0, fh, fw), frame, Vector3(0, fh * 0.5, s * (ol + fw) * 0.5)))
		n.add_child(Kit.box(Vector3(fw, fh, ol), frame, Vector3(s * (ow + fw) * 0.5, fh * 0.5, 0)))
	if not bolts:
		return n
	# Bolts down the middle of the bezel, about every 20 cm.
	var bolt: Material = Kit.mat("steel")
	var b := fw * 0.3
	for s in [-1.0, 1.0]:
		var nx := maxi(2, roundi((ow + fw) / 0.2))
		for k in nx + 1:
			var x := lerpf(-(ow + fw) * 0.5, (ow + fw) * 0.5, float(k) / float(nx))
			n.add_child(Kit.box(Vector3(b, b * 0.6, b), bolt, Vector3(x, fh + b * 0.3, s * (ol + fw) * 0.5)))
		var nz := maxi(1, roundi(ol / 0.2))
		for k in range(1, nz):
			var z := lerpf(-ol * 0.5, ol * 0.5, float(k) / float(nz))
			n.add_child(Kit.box(Vector3(b, b * 0.6, b), bolt, Vector3(s * (ow + fw) * 0.5, fh + b * 0.3, z)))
	return n


## A round port facing +Z, radius `r`: the glass behind a gasket in a heavy ring, on a
## bolted flange. Shut, an armoured shutter is swung over it against micrometeoroids.
static func porthole(r: float, mats: Dictionary, frame: Material, shut: bool = false, warmth: float = 0.55) -> Node3D:
	var n := Node3D.new()
	var tube := clampf(r * 0.16, 0.025, 0.08)
	var flange := r + tube * 2.6
	n.add_child(annulus(r + tube * 0.5, flange, tube * 0.35, frame, 20))
	n.add_child(Kit.torus(r + tube * 0.55, tube * 0.7, frame, Vector3(0, 0, tube * 0.45), 20))
	n.add_child(annulus(r - tube * 0.15, r + tube * 0.2, tube * 0.55, Kit.mat("black"), 16))
	var bolt: Material = Kit.mat("steel")
	var b := tube * 0.45
	for k in 8:
		var a := TAU * (float(k) + 0.5) / 8.0
		n.add_child(Kit.box(Vector3(b, b, b * 0.6), bolt, Vector3(cos(a), sin(a), 0.0) * (r + tube * 1.9) + Vector3(0, 0, tube * 0.35 + b * 0.3)))
	if shut:
		var cover := annulus(0.0, r + tube * 1.2, tube * 0.5, frame, 20)
		cover.position.z = tube * 0.95
		n.add_child(cover)
		n.add_child(Kit.box(Vector3(tube * 1.6, tube * 1.6, tube * 1.2), mats["dark"], Vector3(r + tube * 1.5, 0, tube * 1.0)))
	else:
		n.add_child(Kit.cylinder(r, 0.02, glass(mats, warmth), Vector3(0, 0, 0.0), 20))
	return n


# --- things crews hold, open and unbolt ---------------------------------------------

## An EVA handrail from a to b, stood off the skin along `out`: a rescue-yellow bar on
## standoffs about every 60 cm, as on any crewed hull.
static func handrail(a: Vector3, b: Vector3, out: Vector3) -> Node3D:
	var n := Node3D.new()
	var yellow: Material = Kit.mat("yellow")
	var off := out.normalized() * 0.1
	n.add_child(bar(a + off, b + off, 0.035, yellow))
	var count := maxi(2, int(a.distance_to(b) / 0.6) + 1)
	for k in count:
		var p := a.lerp(b, float(k) / float(count - 1))
		n.add_child(bar(p, p + off, 0.03, yellow))
	return n


## A crew hatch facing +Y, `w` by `l`: the door in a raised frame, hinges down one
## side, a handle, and a status lamp (green: sealed and ready).
static func hatch(w: float, l: float, mats: Dictionary) -> Node3D:
	var n := Node3D.new()
	n.add_child(Kit.box(Vector3(w, 0.04, l), mats["hull"], Vector3(0, 0.02, 0)))
	var fw := 0.08
	for s in [-1.0, 1.0]:
		n.add_child(Kit.box(Vector3(w + fw * 2.0, 0.07, fw), mats["trim"], Vector3(0, 0.035, s * (l + fw) * 0.5)))
		n.add_child(Kit.box(Vector3(fw, 0.07, l), mats["trim"], Vector3(s * (w + fw) * 0.5, 0.035, 0)))
	for f in [-0.32, 0.32]:
		n.add_child(Kit.box(Vector3(0.1, 0.08, 0.16), mats["dark"], Vector3(-w * 0.5, 0.06, l * f)))
	n.add_child(bar(Vector3(w * 0.28, 0.11, -l * 0.15), Vector3(w * 0.28, 0.11, l * 0.15), 0.035, Kit.mat("yellow")))
	for f in [-0.15, 0.15]:
		n.add_child(bar(Vector3(w * 0.28, 0.04, l * f), Vector3(w * 0.28, 0.11, l * f), 0.03, Kit.mat("yellow")))
	if not mats.has("lamp_green"):
		mats["lamp_green"] = Kit.glow(Color("58ff7a"), 2.5)
	n.add_child(Kit.box(Vector3(0.07, 0.05, 0.07), mats["lamp_green"], Vector3(w * 0.5 + fw * 2.0, 0.04, -l * 0.5)))
	return n


## An access panel facing +Y, `w` by `l`: a plate a couple of centimetres proud of the
## skin, a bolt at each corner and fasteners down the long sides.
static func access_panel(w: float, l: float, plate: Material) -> Node3D:
	var n := Node3D.new()
	n.add_child(Kit.box(Vector3(w, 0.025, l), plate, Vector3(0, 0.0125, 0)))
	var bolt: Material = Kit.mat("steel")
	var b := 0.035
	for sx in [-1.0, 1.0]:
		var count := maxi(2, roundi(l / 0.3))
		for k in count + 1:
			n.add_child(Kit.box(Vector3(b, 0.02, b), bolt, Vector3(sx * (w * 0.5 - 0.05), 0.03, lerpf(-l * 0.5 + 0.05, l * 0.5 - 0.05, float(k) / float(count)))))
	return n


# --- pressure vessels ----------------------------------------------------------------

## A pressure vessel along Z, `length` overall, radius `r`: a barrel closed by 2:1
## ellipsoidal heads, as on a gas cylinder, the girth welds banded, and a boss with a
## valve on each pole. Returns {node, barrel} (the straight length, for markings).
static func vessel(r: float, length: float, material: Material, mats: Dictionary, sides: int = 24) -> Dictionary:
	var n := Node3D.new()
	var head := minf(r * 0.5, length * 0.3)
	var barrel := maxf(length - head * 2.0, 0.01)
	n.add_child(Kit.cylinder(r, barrel, material, Vector3.ZERO, sides))
	var aft := PackedVector2Array()
	var fore := PackedVector2Array()
	for i in 9:
		var th := PI * 0.5 * float(i) / 8.0
		aft.append(Vector2(r * cos(th), barrel * 0.5 + head * sin(th)))
		var tf := PI * 0.5 * float(8 - i) / 8.0
		fore.append(Vector2(r * cos(tf), -barrel * 0.5 - head * sin(tf)))
	n.add_child(Kit.lathe([aft, fore], material, sides))
	var steel: Material = mats["steel"]
	for s in [-1.0, 1.0]:
		n.add_child(Kit.torus(r + 0.005, clampf(r * 0.025, 0.02, 0.06), steel, Vector3(0, 0, s * barrel * 0.5), sides))
		var boss := Kit.box(Vector3(r * 0.22, r * 0.22, r * 0.12) + Vector3.ONE * 0.05, steel, Vector3(0, 0, s * (barrel * 0.5 + head + r * 0.03)))
		n.add_child(boss)
		n.add_child(Kit.box(Vector3(r * 0.1, r * 0.14, r * 0.1) + Vector3.ONE * 0.04, mats["dark"], Vector3(0, r * 0.1, s * (barrel * 0.5 + head + r * 0.1))))
	return {"node": n, "barrel": barrel}
