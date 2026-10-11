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
##
## Round it is the rest of the cabin (_cabin), so looking about in the cockpit finds a
## place you live in: side and quarter windows, consoles, the overhead panel, a floor,
## and the back bulkhead with the hatch, lockers and the crew's own clutter. It sits on
## its own render layer (CABIN_LAYER), left out of the scene's suns, and is lit by its
## own sun with short, sharp shadows (sync_sun), so sunlight comes in only through
## the glass and sweeps across the cabin as the ship turns.
extends Node3D

const Kit := preload("res://view/flight/kit.gd")

## The cabin's render layer. view/flight/bay.gd shade_interior clears it from every sun.
const CABIN_LAYER := 4
## The cabin, in eye-space metres: floor, ceiling, back bulkhead, least half-width.
const FLOOR_Y := -1.2
const CEIL_Y := 0.8
const BACK_Z := 1.7
const HALF_W := 1.45

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
## The cabin's own sun: the scene's direction and strength, with shadows (sync_sun).
var _sun: DirectionalLight3D


func _init() -> void:
	name = "FlightDeck"


## Light the cabin as the scene's sun lights the ship: through the windows only.
func sync_sun(sun: DirectionalLight3D) -> void:
	if _sun == null or sun == null:
		return
	_sun.global_basis = sun.global_basis
	_sun.light_energy = sun.light_energy
	_sun.light_color = sun.light_color


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
	_cabin(tris, aspect)
	for key in tris:
		var st2: SurfaceTool = tris[key]
		var mi := MeshInstance3D.new()
		mi.mesh = st2.commit()
		mi.material_override = _mat(key)
		# Shadows only in the cabin's own sun: lights and glows cast none.
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if key.begins_with("glow") else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mi.name = key
		_parts.add_child(mi)
	for mi in _parts.find_children("*", "GeometryInstance3D", true, false):
		(mi as GeometryInstance3D).layers = CABIN_LAYER
	if _sun == null:
		_sun = DirectionalLight3D.new()
		_sun.name = "CabinSun"
		_sun.light_cull_mask = CABIN_LAYER
		_sun.shadow_enabled = true
		_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		_sun.shadow_bias = 0.02
		_sun.shadow_normal_bias = 1.0
		_sun.shadow_blur = 1.5
		_sun.light_energy = 0.0
		add_child(_sun)
	_sun.directional_shadow_max_distance = 6.0 * scale.x
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
	# The cabin's dome light, warm and low: enough to find the hatch by.
	var dome := OmniLight3D.new()
	dome.light_color = Color("ffe6c4")
	dome.light_energy = 1.1
	dome.omni_range = 4.2 * scale.x
	dome.omni_attenuation = 0.9
	dome.light_cull_mask = CABIN_LAYER
	dome.position = Vector3(0, CEIL_Y - 0.2, 0.75)
	_parts.add_child(dome)
	# Spill from the overhead panel and the side consoles' placards, low and close.
	var over := OmniLight3D.new()
	over.light_color = Color("e8eef5")
	over.light_energy = 0.4
	over.omni_range = 1.8 * scale.x
	over.omni_attenuation = 1.2
	over.light_cull_mask = CABIN_LAYER
	over.position = Vector3(0, CEIL_Y - 0.25, -0.3)
	_parts.add_child(over)
	for side in [-1.0, 1.0]:
		var low := OmniLight3D.new()
		low.light_color = Color("ffd9a8")
		low.light_energy = 0.3
		low.omni_range = 1.6 * scale.x
		low.omni_attenuation = 1.3
		low.light_cull_mask = CABIN_LAYER
		low.position = Vector3(side * 0.9, -0.35, 0.2)
		_parts.add_child(low)


# --- The cabin round the pilot ----------------------------------------------------

## Box between two corners (any order).
func _blk(tris: Dictionary, mat: String, a: Vector3, b: Vector3) -> void:
	var lo := Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
	var hi := Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
	_hexa(tris, mat, [Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(lo.x, lo.y, lo.z),
		Vector3(lo.x, hi.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(hi.x, lo.y, hi.z), Vector3(lo.x, lo.y, hi.z)])


## A row of toggle switches with a lamp over each, on a face at `at` spanning `along`
## (switches stick out along `out`).
func _switches(tris: Dictionary, at: Vector3, along: Vector3, out: Vector3, n: int, seed_: int) -> void:
	var lamps := ["glow_g", "glow_g", "glow_a", "glow_g", "glow_b", "glow_g", "glow_r"]
	var up := along.cross(out).normalized() * 0.03
	for i in n:
		var c := at + along * ((i + 0.5) / float(n) - 0.5)
		_beam(tris, "switch", c - along.normalized() * 0.004, c + out * 0.028 - along.normalized() * 0.004, along.normalized() * 0.008, up * 0.25)
		var lamp := c + up
		var lamp_key: String = lamps[absi(hash(seed_ * 31 + i)) % lamps.size()]
		if absi(hash(seed_ * 17 + i)) % 3 != 0:
			_beam(tris, lamp_key, lamp, lamp + out * 0.004, along.normalized() * 0.012, up * 0.18)


func _cabin(tris: Dictionary, asp: float) -> void:
	var t := _t
	# Windscreen frame, from the same numbers _build used.
	var pb_x := PILLAR_BOTTOM_NX * SILL_D * t * asp
	var st := SILL_NY * SILL_D * t
	var hy := HEADER_NY * HEADER_D * t
	var w := maxf(HALF_W, pb_x + 0.3)
	var f := FLOOR_Y
	var c := CEIL_Y
	var b := BACK_Z
	var zf := -1.15
	var th := 0.06
	# Side windows: an opening in each wall.
	var win_z := Vector2(-0.55, 0.3)
	var win_y := Vector2(-0.18, 0.4)
	var bevel := 0.28
	for side in [-1.0, 1.0]:
		var x0: float = side * w
		var x1: float = side * (w + th)
		# Wall panels round the window: below, the strip above (to the shoulder), fore and aft.
		_blk(tris, "wall", Vector3(x0, f, zf), Vector3(x1, win_y.x, b))
		_blk(tris, "wall", Vector3(x0, win_y.y, zf), Vector3(x1, c - bevel, b))
		_blk(tris, "wall", Vector3(x0, win_y.x, zf), Vector3(x1, win_y.y, win_z.x))
		_blk(tris, "wall", Vector3(x0, win_y.x, win_z.y), Vector3(x1, win_y.y, b))
		# The shoulder: a bevel up to the ceiling.
		var sx: float = side * (w - bevel)
		_hexa(tris, "liner", [Vector3(x0, c - bevel, zf), Vector3(sx, c, zf), Vector3(sx, c, b), Vector3(x0, c - bevel, b),
			Vector3(x1, c - bevel, zf), Vector3(sx, c + th, zf), Vector3(sx, c + th, b), Vector3(x1, c - bevel, b)])
		# The window's frame and seal, standing proud of the wall.
		var px: float = side * (w - 0.035)
		_blk(tris, "frame", Vector3(x0, win_y.x - 0.05, win_z.x - 0.05), Vector3(px, win_y.x, win_z.y + 0.05))
		_blk(tris, "frame", Vector3(x0, win_y.y, win_z.x - 0.05), Vector3(px, win_y.y + 0.05, win_z.y + 0.05))
		_blk(tris, "frame", Vector3(x0, win_y.x, win_z.x - 0.05), Vector3(px, win_y.y, win_z.x))
		_blk(tris, "frame", Vector3(x0, win_y.x, win_z.y), Vector3(px, win_y.y, win_z.y + 0.05))
		_blk(tris, "rubber", Vector3(x0, win_y.x, win_z.x), Vector3(side * (w + 0.01), win_y.x + 0.012, win_z.y))
		_blk(tris, "rubber", Vector3(x0, win_y.y - 0.012, win_z.x), Vector3(side * (w + 0.01), win_y.y, win_z.y))
		# A grab handle over the window.
		var gh := Vector3(side * (w - 0.07), win_y.y + 0.11, 0.0)
		_beam(tris, "handle", gh + Vector3(0, 0, -0.25), gh + Vector3(0, 0, 0.15), Vector3(side * 0.018, 0, 0), Vector3(0, 0.018, 0))
		for hz in [-0.25, 0.15]:
			_blk(tris, "frame", gh + Vector3(0, -0.01, hz - 0.012), Vector3(x0, gh.y + 0.01, hz + 0.012))
		# The quarter light: from the pillar out to the wall, between sill and header, open
		# glass; a corner post where it meets the wall.
		_beam(tris, "frame", Vector3(side * (w - 0.08), st - 0.06, -SILL_D), Vector3(side * (w - 0.08), hy + 0.05, -HEADER_D), Vector3(side * 0.09, 0, 0), Vector3(0, 0, 0.06))
		_blk(tris, "wall", Vector3(side * (w - 0.08), st - 0.1, zf), Vector3(x1, st, -SILL_D + 0.06))
		# Side console along the wall, elbow high, its top tilted to the pilot.
		var ci: float = side * (w - 0.42)
		var top_in := -0.5
		var top_out := -0.43
		_hexa(tris, "console", [Vector3(ci, top_in, -0.95), Vector3(x0, top_out, -0.95), Vector3(x0, f, -0.95), Vector3(ci, f, -0.95),
			Vector3(ci, top_in, 0.5), Vector3(x0, top_out, 0.5), Vector3(x0, f, 0.5), Vector3(ci, f, 0.5)])
		# Two panels of switches on it, and a lit placard.
		for k in 2:
			var z0 := -0.75 + k * 0.55
			var mid := Vector3(side * (w - 0.21), (top_in + top_out) * 0.5 + 0.005, z0 + 0.2)
			_switches(tris, mid, Vector3(0, 0, 0.36), Vector3(0, 1, 0), 6, int(side) * 10 + k)
			_switches(tris, mid + Vector3(side * -0.1, -0.012, 0), Vector3(0, 0, 0.36), Vector3(0, 1, 0), 6, int(side) * 10 + k + 5)
		_blk(tris, "glow_w", Vector3(side * (w - 0.38), top_in + 0.004, -0.92), Vector3(side * (w - 0.3), top_in + 0.012, -0.84))
	# Front: the footwell under the panel, and the fascia over the header to the ceiling.
	_blk(tris, "console", Vector3(-w, f, zf - th), Vector3(w, -0.62, zf))
	_blk(tris, "frame", Vector3(-w, hy + 0.28, -HEADER_D + 0.02), Vector3(w, c + th, -HEADER_D + 0.12))
	for side in [-1.0, 1.0]:
		# Rudder pedals.
		var px2: float = side * 0.22
		_hexa(tris, "rubber", _slab(Vector3(px2, f + 0.28, -0.98), Vector3(0.07, 0, 0), Vector3(0, 0.12, 0.03), Vector3(0, 0, -0.03)))
	# Ceiling, and the floor with its grating.
	_blk(tris, "liner", Vector3(-(w - bevel), c, -HEADER_D + 0.05), Vector3(w - bevel, c + th, b))
	_blk(tris, "floor", Vector3(-w, f - th, zf), Vector3(w, f, b))
	for i in 9:
		var gz := lerpf(zf + 0.15, b - 0.15, i / 8.0)
		_blk(tris, "frame", Vector3(-w + 0.45, f, gz - 0.015), Vector3(w - 0.45, f + 0.012, gz + 0.015))
	# The overhead panel: breakers and switches, within reach of a raised hand.
	var oh := Vector2(-0.62, 0.1)
	_blk(tris, "console", Vector3(-0.48, c - 0.1, oh.x), Vector3(0.48, c, oh.y))
	for r in 3:
		var z := lerpf(oh.x + 0.12, oh.y - 0.1, r / 2.0)
		_switches(tris, Vector3(0, c - 0.1, z), Vector3(0.8, 0, 0), Vector3(0, -1, 0), 10, 40 + r)
	# The dome light behind the head, and a strip light along each shoulder.
	_blk(tris, "glow_w", Vector3(-0.22, c - 0.015, 0.6), Vector3(0.22, c, 0.9))
	for side in [-1.0, 1.0]:
		_blk(tris, "glow_w", Vector3(side * (w - bevel - 0.03), c - 0.01, -0.2), Vector3(side * (w - bevel - 0.07), c, 1.3))
	# The seat: armrests, the throttle quadrant at the right hand, and harness straps.
	_blk(tris, "fabric", Vector3(-0.66, -0.78, -0.25), Vector3(-0.42, -0.66, 0.35))
	_blk(tris, "console", Vector3(0.42, -0.8, -0.38), Vector3(0.68, -0.64, 0.3))
	for k in 2:
		var lx := 0.5 + k * 0.1
		_beam(tris, "frame", Vector3(lx, -0.64, -0.1), Vector3(lx, -0.52, -0.16), Vector3(0.014, 0, 0), Vector3(0, 0, 0.014))
		_blk(tris, "rubber" if k == 0 else "red", Vector3(lx - 0.025, -0.53, -0.19), Vector3(lx + 0.039, -0.49, -0.13))
	_switches(tris, Vector3(0.55, -0.64, 0.15), Vector3(0, 0, 0.2), Vector3(0, 1, 0), 4, 77)
	for side in [-1.0, 1.0]:
		_blk(tris, "fabric", Vector3(side * 0.3, -1.0, -0.35), Vector3(side * 0.42, -0.62, 0.35))
	# The back bulkhead: the hatch aft, lockers either side, and the crew's things.
	_blk(tris, "wall", Vector3(-w - th, f - th, b), Vector3(w + th, c + th, b + th))
	var hc := Vector3(0, -0.2, b - 0.02)
	var hatch := Kit.cylinder(0.46, 0.05, _mat("frame"), hc)
	_parts.add_child(hatch)
	var door := Kit.cylinder(0.4, 0.04, _mat("console"), hc - Vector3(0, 0, 0.03))
	_parts.add_child(door)
	var wheel := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.15
	torus.outer_radius = 0.18
	wheel.mesh = torus
	wheel.material_override = _mat("switch")
	wheel.rotation_degrees = Vector3(90, 0, 0)
	wheel.position = hc - Vector3(0, 0, 0.1)
	_parts.add_child(wheel)
	for a in 3:
		var ang := a * PI / 3.0
		var dir := Vector3(cos(ang), sin(ang), 0) * 0.165
		_beam(tris, "switch", hc - Vector3(0, 0, 0.1) - dir, hc - Vector3(0, 0, 0.1) + dir, Vector3(0, 0, 0.012), dir.cross(Vector3(0, 0, 1)).normalized() * 0.012)
	_blk(tris, "glow_g", Vector3(-0.08, hc.y + 0.52, b - 0.02), Vector3(0.08, hc.y + 0.56, b - 0.01))
	for side in [-1.0, 1.0]:
		var lx0: float = side * 0.62
		var lx1: float = side * (w - 0.05)
		for row in 3:
			var y0 := -0.9 + row * 0.55
			_blk(tris, "liner", Vector3(lx0, y0, b - 0.32), Vector3(lx1, y0 + 0.5, b))
			var hx := (lx0 + lx1) * 0.5
			_blk(tris, "frame", Vector3(hx - 0.08, y0 + 0.4, b - 0.345), Vector3(hx + 0.08, y0 + 0.43, b - 0.32))
	# A cargo strap across the left lockers, the checklist and photos on the right.
	_blk(tris, "strap", Vector3(-w + 0.05, -0.12, b - 0.35), Vector3(-0.62, -0.07, b - 0.33))
	_blk(tris, "paper", Vector3(0.75, 0.05, b - 0.335), Vector3(1.0, 0.38, b - 0.325))
	for i in 5:
		_blk(tris, "rubber", Vector3(0.78, 0.33 - i * 0.055, b - 0.337), Vector3(0.97, 0.335 - i * 0.055, b - 0.336))
	_blk(tris, "photo", Vector3(0.66, 0.42, b - 0.335), Vector3(0.82, 0.54, b - 0.325))
	_blk(tris, "paper", Vector3(0.86, 0.43, b - 0.336), Vector3(1.02, 0.56, b - 0.326))
	_blk(tris, "leaf", Vector3(0.9, 0.46, b - 0.338), Vector3(0.96, 0.5, b - 0.337))
	# A fire extinguisher by the hatch, and a basil plant in a clamped pot on the left console.
	var ext := Kit.cylinder(0.065, 0.42, _mat("red"), Vector3(-0.5, -0.55, b - 0.1))
	ext.rotation_degrees = Vector3.ZERO
	_parts.add_child(ext)
	_parts.add_child(Kit.cylinder(0.02, 0.06, _mat("rubber"), Vector3(-0.5, -0.31, b - 0.1)))
	var pot := Kit.cylinder(0.07, 0.11, _mat("pot"), Vector3(-(w - 0.2), -0.4, 0.38))
	pot.rotation_degrees = Vector3.ZERO
	_parts.add_child(pot)
	for i in 7:
		var a2 := i * TAU / 7.0
		var leaf := Kit.sphere(0.045 + 0.01 * (i % 3), _mat("leaf"), Vector3(-(w - 0.2) + cos(a2) * 0.05, -0.28 + 0.03 * (i % 2), 0.38 + sin(a2) * 0.05))
		leaf.scale = Vector3(1.0, 0.55, 1.0)
		_parts.add_child(leaf)
	_blk(tris, "strap", Vector3(-(w - 0.08), -0.43, 0.36), Vector3(-(w - 0.32), -0.4, 0.4))


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
		if nrm.dot(outward) > 0.0:
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
		"wall": [Color("c7c3b8"), 0.85, 0.0],
		"liner": [Color("9e9b93"), 0.9, 0.0],
		"floor": [Color("26292c"), 0.8, 0.3],
		"console": [Color("33393e"), 0.7, 0.15],
		"switch": [Color("b9bcbe"), 0.4, 0.6],
		"fabric": [Color("2f4b6e"), 0.95, 0.0],
		"red": [Color("b8352a"), 0.45, 0.1],
		"paper": [Color("e9e4d6"), 0.9, 0.0],
		"photo": [Color("3c6f9e"), 0.3, 0.0],
		"leaf": [Color("4f8f3c"), 0.7, 0.0],
		"pot": [Color("b5653d"), 0.8, 0.0],
		"strap": [Color("d9a531"), 0.8, 0.0],
	}
	if key.begins_with("glow"):
		var glows := {"glow_g": Color("6fe39a"), "glow_a": Color("ffb547"), "glow_r": Color("ff5a4a"), "glow_w": Color("fff1d6"), "glow_b": Color("7fc8ff")}
		var g := Kit.glow(glows.get(key, Color.WHITE), 1.6 if key != "glow_w" else 2.4)
		_mats[key] = g
		return g
	var l: Array = looks.get(key, [Color.MAGENTA, 0.5, 0.0])
	var m := StandardMaterial3D.new()
	m.albedo_color = l[0]
	m.roughness = l[1]
	m.metallic = l[2]
	if key in ["frame", "panel", "bezel", "wall", "liner", "console"]:
		# A little bounce light from the cabin.
		m.emission_enabled = true
		m.emission = Color(l[0]).lightened(0.1)
		m.emission_energy_multiplier = 0.12
	_mats[key] = m
	return m
