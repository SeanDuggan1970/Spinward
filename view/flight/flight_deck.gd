## The flight deck around the pilot's eye: windscreen header and pillars, the
## anti-glare coaming, the glareshield's annunciator panel, and the instrument panel
## with three multi-function displays in their bezels. Real geometry, so the Sun
## falls across it as the ship turns, a dim flood lights the panel from under the
## glareshield, and looking around in transit gives parallax.
##
## Built in eye space (the eye at the origin looking down -Z, +Y up) from where each
## edge should sit in the view (normalised device coordinates at the design field of
## view), so the layout holds at any window size and is rebuilt for a new aspect. The
## displays' content is drawn in 2D over the glass by the HUD: quads() gives the
## screen corners of each glass.
extends Node3D

const FOV := 72.0
## Where things sit in the view (NDC: -1 bottom/left, +1 top/right) and how far away.
const SILL_NY := -0.30
const SILL_D := 1.05
const LIP_NY := -0.37
const LIP_D := 0.62
const FACE_NY := -0.515
const HEADER_NY := 0.83
const HEADER_D := 0.80
const PILLAR_BOTTOM_NX := 0.84
const PILLAR_TOP_NX := 0.70
const ANN_NX := 0.935
const ANN_TOP_NY := -0.382
const ANN_BOTTOM_NY := -0.503
const GLASS_TOP_NY := -0.545
const GLASS_BOTTOM_NY := -0.915
const PANEL_TOP := Vector2(0.705, -0.53)   # (distance, NDC y) of the panel's top edge
const PANEL_BOTTOM := Vector2(0.675, -1.3)
## Display columns in NDC x.
const DISPLAYS := {"left": [-0.935, -0.352], "centre": [-0.322, 0.322], "right": [0.352, 0.935]}
const MFD_UNITS_H := 160.0
const ANN_UNITS_H := 50.0

var aspect := 0.0
## Canvas size (units) of each glass, by name: "left", "centre", "right", "annunciator".
var canvas := {}
var _glass := {}
var _sill := PackedVector3Array()
var _parts: Node3D
var _t := tan(deg_to_rad(FOV * 0.5))
var _mats := {}


func _init() -> void:
	name = "FlightDeck"


## Rebuild for this aspect ratio if it has changed.
func fit(new_aspect: float) -> void:
	if absf(new_aspect - aspect) > 0.005:
		_build(new_aspect)


## Screen corners (TL, TR, BR, BL) of each glass, or no entry if it is out of view.
func quads(cam: Camera3D) -> Dictionary:
	var out := {}
	if not is_visible_in_tree():
		return out
	var xf := global_transform
	for key in _glass:
		var corners: PackedVector3Array = _glass[key]
		var q := PackedVector2Array()
		for p in corners:
			var w := xf * p
			if cam.is_position_behind(w):
				q = PackedVector2Array()
				break
			q.append(cam.unproject_position(w))
		if q.size() == 4:
			out[key] = q
	return out


## The bottom edge of the windscreen on screen (two points), for clipping markers.
func sill(cam: Camera3D) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in _sill:
		var w := global_transform * p
		if cam.is_position_behind(w):
			return PackedVector2Array()
		out.append(cam.unproject_position(w))
	return out


# --- Building -----------------------------------------------------------------------

func _p(nx: float, ny: float, d: float) -> Vector3:
	return Vector3(nx * d * _t * aspect, ny * d * _t, -d)


func _build(new_aspect: float) -> void:
	aspect = new_aspect
	if _parts:
		_parts.queue_free()
	_parts = Node3D.new()
	add_child(_parts)
	_glass.clear()
	canvas.clear()
	var tris := {}
	var wide := 1.35
	# Anti-glare coaming: from the glareshield lip back to the windscreen sill.
	var lt := _p(0, LIP_NY, LIP_D).y
	var lb := _p(0, FACE_NY, LIP_D).y
	var st := _p(0, SILL_NY, SILL_D).y
	var xl := _p(wide, 0, LIP_D).x
	var xs := _p(wide, 0, SILL_D).x
	_hexa(tris, "coaming", [Vector3(-xl, lt, -LIP_D), Vector3(xl, lt, -LIP_D), Vector3(xl, lb, -LIP_D), Vector3(-xl, lb, -LIP_D),
		Vector3(-xs, st, -SILL_D), Vector3(xs, st, -SILL_D), Vector3(xs, st - 0.08, -SILL_D), Vector3(-xs, st - 0.08, -SILL_D)])
	# A rubber bumper along the lip catches the light.
	_beam(tris, "rubber", Vector3(-xl, lt + 0.004, -LIP_D + 0.006), Vector3(xl, lt + 0.004, -LIP_D + 0.006), Vector3(0, 0.012, 0), Vector3(0, 0, 0.014))
	_sill = PackedVector3Array([_p(-PILLAR_BOTTOM_NX, SILL_NY, SILL_D), _p(PILLAR_BOTTOM_NX, SILL_NY, SILL_D)])
	# Annunciator panel on the glareshield face.
	var a0 := _p(-ANN_NX, ANN_TOP_NY, LIP_D)
	var a1 := _p(ANN_NX, ANN_BOTTOM_NY, LIP_D)
	var az := -LIP_D + 0.006
	_box(tris, "bezel", Vector3(a0.x - 0.008, a0.y + 0.006, az), Vector3(a1.x + 0.008, a1.y - 0.006, az), 0.006)
	_glass["annunciator"] = PackedVector3Array([Vector3(a0.x, a0.y, az + 0.0005), Vector3(a1.x, a0.y, az + 0.0005), Vector3(a1.x, a1.y, az + 0.0005), Vector3(a0.x, a1.y, az + 0.0005)])
	canvas["annunciator"] = Vector2(ANN_UNITS_H * (a1.x - a0.x) / (a0.y - a1.y), ANN_UNITS_H)
	# Instrument panel, tilted back toward the eye, under the glareshield's hood.
	var top := Vector3(0, PANEL_TOP.y * PANEL_TOP.x * _t, -PANEL_TOP.x)
	var bottom := Vector3(0, PANEL_BOTTOM.y * PANEL_BOTTOM.x * _t, -PANEL_BOTTOM.x)
	var down := bottom - top
	var n := Vector3(0, -down.z, down.y).normalized()
	if n.y < 0.0:
		n = -n
	var xp := _p(wide, 0, PANEL_TOP.x).x
	_hexa(tris, "panel", [top + Vector3(-xp, 0, 0), top + Vector3(xp, 0, 0), bottom + Vector3(xp, 0, 0), bottom + Vector3(-xp, 0, 0),
		top + Vector3(-xp, 0, 0) - n * 0.04, top + Vector3(xp, 0, 0) - n * 0.04, bottom + Vector3(xp, 0, 0) - n * 0.04, bottom + Vector3(-xp, 0, 0) - n * 0.04])
	# The hood: closes the gap from the glareshield face back to the panel.
	_hexa(tris, "coaming", [Vector3(-xl, lb, -LIP_D), Vector3(xl, lb, -LIP_D), top + Vector3(xp, 0, 0), top + Vector3(-xp, 0, 0),
		Vector3(-xl, lb + 0.02, -LIP_D - 0.05), Vector3(xl, lb + 0.02, -LIP_D - 0.05), top + Vector3(xp, 0.02, -0.03), top + Vector3(-xp, 0.02, -0.03)])
	var s_top := _panel_s(top, bottom, GLASS_TOP_NY)
	var s_bot := _panel_s(top, bottom, GLASS_BOTTOM_NY)
	var g_top := top.lerp(bottom, s_top)
	var g_bot := top.lerp(bottom, s_bot)
	var d_mid := -(g_top.z + g_bot.z) * 0.5
	var up := -down.normalized()
	for key in DISPLAYS:
		var cols: Array = DISPLAYS[key]
		var x0 := float(cols[0]) * d_mid * _t * aspect
		var x1 := float(cols[1]) * d_mid * _t * aspect
		var proud := n * 0.016
		# Bezel: a margin round the glass, deeper below for the soft keys.
		var bt := g_top + up * 0.012
		var bb := g_bot - up * 0.034
		_hexa(tris, "bezel", [bt + Vector3(x0 - 0.014, 0, 0) + proud, bt + Vector3(x1 + 0.014, 0, 0) + proud, bb + Vector3(x1 + 0.014, 0, 0) + proud, bb + Vector3(x0 - 0.014, 0, 0) + proud,
			bt + Vector3(x0 - 0.014, 0, 0), bt + Vector3(x1 + 0.014, 0, 0), bb + Vector3(x1 + 0.014, 0, 0), bb + Vector3(x0 - 0.014, 0, 0)])
		var front := n * 0.0165
		_glass[key] = PackedVector3Array([g_top + Vector3(x0, 0, 0) + front, g_top + Vector3(x1, 0, 0) + front, g_bot + Vector3(x1, 0, 0) + front, g_bot + Vector3(x0, 0, 0) + front])
		canvas[key] = Vector2(MFD_UNITS_H * (x1 - x0) / g_top.distance_to(g_bot), MFD_UNITS_H)
		# Five soft keys under the glass, and a brightness knob at each lower corner.
		for i in 5:
			var cx := lerpf(x0, x1, (i + 0.5) / 5.0)
			var kc := g_bot - up * 0.017 + Vector3(cx, 0, 0) + proud
			_hexa(tris, "key", _slab(kc, Vector3(0.013, 0, 0), up * 0.0065, n * 0.006))
		for kx in [x0 - 0.002, x1 + 0.002]:
			var kc: Vector3 = g_bot - up * 0.022 + Vector3(kx, 0, 0) + proud
			_hexa(tris, "rubber", _slab(kc, Vector3(0.006, 0, 0), up * 0.006, n * 0.008))
	# Windscreen frame: a sill member, the header beam and the two pillars, with a grab
	# handle on each.
	_beam(tris, "frame", Vector3(-xs, st, -SILL_D), Vector3(xs, st, -SILL_D), Vector3(0, 0.03, 0), Vector3(0, 0, 0.05))
	var hy := _p(0, HEADER_NY, HEADER_D).y
	var xh := _p(wide, 0, HEADER_D).x
	_hexa(tris, "frame", [Vector3(-xh, hy, -HEADER_D), Vector3(xh, hy, -HEADER_D), Vector3(xh, hy + 0.3, -HEADER_D + 0.05), Vector3(-xh, hy + 0.3, -HEADER_D + 0.05),
		Vector3(-xh, hy - 0.01, -HEADER_D + 0.12), Vector3(xh, hy - 0.01, -HEADER_D + 0.12), Vector3(xh, hy + 0.3, -HEADER_D + 0.17), Vector3(-xh, hy + 0.3, -HEADER_D + 0.17)])
	_beam(tris, "rubber", Vector3(-xh, hy + 0.004, -HEADER_D - 0.004), Vector3(xh, hy + 0.004, -HEADER_D - 0.004), Vector3(0, 0.012, 0), Vector3(0, 0, -0.01))
	for side in [-1.0, 1.0]:
		var pb := _p(side * PILLAR_BOTTOM_NX, SILL_NY - 0.03, SILL_D)
		var pt := _p(side * PILLAR_TOP_NX, HEADER_NY + 0.03, HEADER_D)
		var out := Vector3(side * 0.09, 0, 0)
		var toward := Vector3(0, 0, 0.05)
		_hexa(tris, "frame", [pb, pt, pt + out, pb + out, pb + toward, pt + toward, pt + toward + out, pb + toward + out])
		# Inner seal strip where the pane meets the pillar.
		_beam(tris, "rubber", pb + Vector3(-side * 0.004, 0, -0.004), pt + Vector3(-side * 0.004, 0, -0.004), Vector3(side * 0.01, 0, 0), Vector3(0, 0, 0.012))
		# Rescue-orange grab handle on stand-offs, along the pillar's inner face.
		var h0 := pb.lerp(pt, 0.3) + toward * 1.25 + Vector3(side * 0.03, 0, 0)
		var h1 := pb.lerp(pt, 0.7) + toward * 1.25 + Vector3(side * 0.03, 0, 0)
		_beam(tris, "handle", h0, h1, Vector3(0.011, 0, 0), Vector3(0, 0, 0.011))
		for hp in [h0, h1]:
			_beam(tris, "frame", hp - toward * 0.3, hp, Vector3(0.012, 0, 0), Vector3(0, 0.012, 0))
	for key in tris:
		var st2: SurfaceTool = tris[key]
		var mi := MeshInstance3D.new()
		mi.mesh = st2.commit()
		mi.material_override = _mat(key)
		# The hull it belongs to is not drawn from inside, so neither is its shadow.
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.name = key
		_parts.add_child(mi)
	# The panel flood: a dim warm light from under the glareshield.
	var flood := OmniLight3D.new()
	flood.light_color = Color("ffdcae")
	flood.light_energy = 0.35
	flood.omni_range = 0.75 * scale.x
	flood.omni_attenuation = 1.4
	flood.position = Vector3(0, lb - 0.02, -LIP_D + 0.12)
	_parts.add_child(flood)
	# The displays' own glow, thrown up from the panel onto the frame, so the pillars
	# and header never go fully black on the shadow side.
	var fill := OmniLight3D.new()
	fill.light_color = Color("b9d2d4")
	fill.light_energy = 0.6
	fill.omni_range = 2.4 * scale.x
	fill.omni_attenuation = 0.8
	fill.position = Vector3(0, -0.42, -0.3)
	_parts.add_child(fill)


## Panel parameter (0 top .. 1 bottom) where the panel line crosses NDC y `ny`.
func _panel_s(top: Vector3, bottom: Vector3, ny: float) -> float:
	var d0 := -top.z
	var d1 := -bottom.z
	return (ny * _t * d0 - top.y) / ((bottom.y - top.y) - ny * _t * (d1 - d0))


## A slab centred at c with half-extents along three axes, as hexa corners.
func _slab(c: Vector3, hx: Vector3, hy: Vector3, depth: Vector3) -> Array:
	return [c - hx + hy + depth, c + hx + hy + depth, c + hx - hy + depth, c - hx - hy + depth,
		c - hx + hy, c + hx + hy, c + hx - hy, c - hx - hy]


## A bar from a to b with cross-section axes u and v.
func _beam(tris: Dictionary, mat: String, a: Vector3, b: Vector3, u: Vector3, v: Vector3) -> void:
	_hexa(tris, mat, [a, b, b + u, a + u, a + v, b + v, b + u + v, a + u + v])


## An axis-aligned box between two corners (x, y) at z, `depth` toward the eye.
func _box(tris: Dictionary, mat: String, c0: Vector3, c1: Vector3, depth: float) -> void:
	_hexa(tris, mat, [Vector3(c0.x, c0.y, c0.z), Vector3(c1.x, c0.y, c0.z), Vector3(c1.x, c1.y, c0.z), Vector3(c0.x, c1.y, c0.z),
		Vector3(c0.x, c0.y, c0.z - depth), Vector3(c1.x, c0.y, c0.z - depth), Vector3(c1.x, c1.y, c0.z - depth), Vector3(c0.x, c1.y, c0.z - depth)])


## A six-sided solid from two quads (0-3 and 4-7, corresponding corners), flat shaded,
## each face wound clockwise seen from outside (Godot's front face).
func _hexa(tris: Dictionary, mat: String, c: Array) -> void:
	if not tris.has(mat):
		var s := SurfaceTool.new()
		s.begin(Mesh.PRIMITIVE_TRIANGLES)
		tris[mat] = s
	var st: SurfaceTool = tris[mat]
	var centre := Vector3.ZERO
	for p in c:
		centre += p
	centre /= 8.0
	for f in [[0, 1, 2, 3], [7, 6, 5, 4], [4, 5, 1, 0], [3, 2, 6, 7], [4, 0, 3, 7], [1, 5, 6, 2]]:
		var q := [c[f[0]], c[f[1]], c[f[2]], c[f[3]]]
		var fc: Vector3 = (q[0] + q[1] + q[2] + q[3]) * 0.25
		var nrm: Vector3 = (q[1] - q[0]).cross(q[2] - q[0])
		if nrm.length() < 1e-10:
			nrm = (q[2] - q[0]).cross(q[3] - q[0])
		if nrm.length() < 1e-10:
			continue
		nrm = nrm.normalized()
		var outward := nrm if nrm.dot(fc - centre) >= 0.0 else -nrm
		# Clockwise from outside means the right-hand normal points inward.
		if nrm.dot(outward) < 0.0:
			q.reverse()
		st.set_normal(outward)
		for i in [0, 1, 2, 0, 2, 3]:
			st.add_vertex(q[i])


func _mat(key: String) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var looks := {
		"coaming": [Color("1b1d1f"), 0.95, 0.0],
		"panel": [Color("2c3135"), 0.75, 0.1],
		"bezel": [Color("1e2124"), 0.5, 0.2],
		"key": [Color("3a4044"), 0.55, 0.1],
		"rubber": [Color("0e0f10"), 0.6, 0.0],
		"frame": [Color("383d42"), 0.7, 0.2],
		"handle": [Color("d2702c"), 0.55, 0.0],
	}
	var l: Array = looks.get(key, [Color.MAGENTA, 0.5, 0.0])
	var m := StandardMaterial3D.new()
	m.albedo_color = l[0]
	m.roughness = l[1]
	m.metallic = l[2]
	if key in ["frame", "panel", "bezel"]:
		# A little bounce light from the cabin.
		m.emission_enabled = true
		m.emission = Color(l[0]).lightened(0.1)
		m.emission_energy_multiplier = 0.12
	_mats[key] = m
	return m
