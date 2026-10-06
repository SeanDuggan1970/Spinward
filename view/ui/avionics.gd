## Glass-cockpit drawing: a display's page is laid out on its own flat canvas (in
## canvas units, about one logical pixel at 16:9) and drawn as clean vectors onto
## whatever screen quad the display's glass covers, through a projective map. So the
## same page sits on a 3D panel seen in perspective (the flight deck) or on a flat
## rectangle (the chase view's telemetry strip), with crisp text and lines either way.
##
## Colour carries meaning, as on real avionics:
##   white  measured values         green  within limits, normal, engaged
##   amber  caution, needs action   red    warning, limit exceeded
##   cyan   targets and commands    grey   labels, scales, inactive
extends RefCounted

const WHITE := Color("e9e6dc")
const GREY := Color("7f898c")
const FAINT := Color("3b4447")
const GREEN := Color("62d46e")
const AMBER := Color("f2a531")
const RED := Color("ff4d3d")
const CYAN := Color("52d2e4")
const GLASS := Color("05090a")
const GLASS_EDGE := Color("1d2629")

var ci: CanvasItem
var font: Font
## Canvas size in units.
var size := Vector2(400, 160)
var ok := false
# Projective map from the unit square to the quad: x = (a u + b v + c) / (g u + h v + 1).
var _a := 0.0
var _b := 0.0
var _c := 0.0
var _d := 0.0
var _e := 0.0
var _f := 0.0
var _g := 0.0
var _h := 0.0


## Aim at a quad (screen corners: top-left, top-right, bottom-right, bottom-left).
func begin(canvas_item: CanvasItem, f: Font, quad: PackedVector2Array, canvas_size: Vector2) -> bool:
	ci = canvas_item
	font = f
	size = canvas_size
	ok = quad.size() == 4
	if not ok:
		return false
	var p0 := quad[0]
	var p1 := quad[1]
	var p2 := quad[2]
	var p3 := quad[3]
	var dx1 := p1.x - p2.x
	var dx2 := p3.x - p2.x
	var dx3 := p0.x - p1.x + p2.x - p3.x
	var dy1 := p1.y - p2.y
	var dy2 := p3.y - p2.y
	var dy3 := p0.y - p1.y + p2.y - p3.y
	var den := dx1 * dy2 - dx2 * dy1
	if absf(den) < 1e-9:
		ok = false
		return false
	_g = (dx3 * dy2 - dx2 * dy3) / den
	_h = (dx1 * dy3 - dx3 * dy1) / den
	_a = p1.x - p0.x + _g * p1.x
	_b = p3.x - p0.x + _h * p3.x
	_c = p0.x
	_d = p1.y - p0.y + _g * p1.y
	_e = p3.y - p0.y + _h * p3.y
	_f = p0.y
	return true


## Canvas units to screen.
func map(p: Vector2) -> Vector2:
	var u := p.x / size.x
	var v := p.y / size.y
	var w := _g * u + _h * v + 1.0
	return Vector2((_a * u + _b * v + _c) / w, (_d * u + _e * v + _f) / w)


## Screen pixels per canvas unit near p (vertical scale, which sets text size).
func k_at(p: Vector2) -> float:
	return map(p).distance_to(map(p + Vector2(0, 4))) * 0.25


func _pts(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(points.size())
	for i in points.size():
		out[i] = map(points[i])
	return out


func _w(width: float, at: Vector2) -> float:
	return maxf(1.0, width * k_at(at))


# --- Primitives ----------------------------------------------------------------------

func line(a: Vector2, b: Vector2, col: Color, width: float = 1.0) -> void:
	ci.draw_line(map(a), map(b), col, _w(width, a), true)


func dashed(a: Vector2, b: Vector2, col: Color, width: float = 1.0, dash: float = 5.0) -> void:
	var n := maxi(1, int(a.distance_to(b) / dash))
	for i in range(0, n, 2):
		line(a.lerp(b, float(i) / n), a.lerp(b, minf(1.0, float(i + 1) / n)), col, width)


func polyline(points: PackedVector2Array, col: Color, width: float = 1.0) -> void:
	if points.size() >= 2:
		ci.draw_polyline(_pts(points), col, _w(width, points[0]), true)


## A polyline kept inside a rectangle (points outside it break the line).
func clipped(points: PackedVector2Array, r: Rect2, col: Color, width: float = 1.0) -> void:
	var run := PackedVector2Array()
	for p in points:
		if r.has_point(p):
			run.append(p)
		else:
			if run.size() >= 2:
				polyline(run, col, width)
			run = PackedVector2Array()
	if run.size() >= 2:
		polyline(run, col, width)


func poly(points: PackedVector2Array, col: Color) -> void:
	if points.size() >= 3:
		ci.draw_colored_polygon(_pts(points), col)


func rect(r: Rect2, col: Color, filled: bool = true, width: float = 1.0) -> void:
	var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	if filled:
		poly(pts, col)
	else:
		pts.append(r.position)
		polyline(pts, col, width)


func ellipse_points(c: Vector2, rx: float, ry: float, segs: int = 48, from: float = 0.0, to: float = TAU) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segs + 1:
		var a := lerpf(from, to, float(i) / segs)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


func circle(c: Vector2, r: float, col: Color, filled: bool = false, width: float = 1.0, segs: int = 32) -> void:
	ellipse(c, r, r, col, filled, width, segs)


func ellipse(c: Vector2, rx: float, ry: float, col: Color, filled: bool = false, width: float = 1.0, segs: int = 48) -> void:
	var pts := ellipse_points(c, rx, ry, segs)
	if filled:
		pts.remove_at(pts.size() - 1)
		poly(pts, col)
	else:
		polyline(pts, col, width)


func arc(c: Vector2, r: float, from: float, to: float, col: Color, width: float = 1.0, segs: int = 24) -> void:
	polyline(ellipse_points(c, r, r, segs, from, to), col, width)


## Text with its baseline at p. align: -1 left, 0 centre, 1 right.
func text(p: Vector2, s: String, px: float, col: Color, align: int = -1) -> void:
	var fs := maxi(6, int(round(px * k_at(p))))
	var at := map(p)
	if align != -1:
		var tw := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		at.x -= tw if align == 1 else tw * 0.5
	ci.draw_string(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## Width of text in canvas units.
func text_width(s: String, px: float) -> float:
	return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(px)).x


# --- Display furniture ------------------------------------------------------------------

## The glass itself: near-black, with a faint edge.
func glass() -> void:
	rect(Rect2(Vector2.ZERO, size), GLASS)
	rect(Rect2(Vector2(0.5, 0.5), size - Vector2(1, 1)), GLASS_EDGE, false, 1.0)


## Page title, boxed, top left; an optional note top right.
func title(name: String, note: String = "", note_col: Color = GREY) -> void:
	var tw := text_width(name, 12) + 10
	rect(Rect2(4, 3, tw, 15), FAINT, false, 1.0)
	text(Vector2(9, 15), name, 12, WHITE)
	if note != "":
		text(Vector2(size.x - 6, 15), note, 11, note_col, 1)


## Soft-key legends along the bottom edge, one over each button on the bezel:
## [[key, label, colour], ...]. Empty entries leave a key blank.
func soft_keys(keys: Array) -> void:
	var n := 5
	var w := size.x / n
	var y := size.y - 5.0
	for i in mini(n, keys.size()):
		var k: Array = keys[i]
		if k.is_empty():
			continue
		var cx := w * (i + 0.5)
		line(Vector2(cx - 5, size.y - 1.5), Vector2(cx + 5, size.y - 1.5), GREY, 1.0)
		var key: String = k[0]
		var label: String = k[1]
		var col: Color = k[2] if k.size() > 2 else GREY
		var kw := text_width(key, 10) + 4 if key != "" else -3.0
		var px := 11.0
		var lw := text_width(label, px)
		while kw + 3 + lw > w - 4 and px > 8.0:
			px -= 1.0
			lw = text_width(label, px)
		var x0 := cx - (kw + 3 + lw) * 0.5
		if key != "":
			rect(Rect2(x0, y - 10, kw, 12), FAINT, false, 1.0)
			text(Vector2(x0 + 2, y - 0.5), key, 10, GREY)
		text(Vector2(x0 + kw + 3, y), label, px, col)


## Label, horizontal bar (0..1) and value. limit_at draws a tick (e.g. a red line).
func bar(at: Vector2, w: float, label: String, frac: float, value: String, col: Color, limit_at: float = -1.0) -> void:
	text(at + Vector2(0, 0), label, 11, GREY)
	var r := Rect2(at.x + 36, at.y - 8, w - 36 - 56, 8)
	rect(r, Color(FAINT, 0.55))
	rect(Rect2(r.position, Vector2(r.size.x * clampf(frac, 0.0, 1.0), r.size.y)), col)
	rect(r, FAINT, false, 1.0)
	if limit_at >= 0.0:
		var x := r.position.x + r.size.x * clampf(limit_at, 0.0, 1.0)
		line(Vector2(x, r.position.y - 2), Vector2(x, r.end.y + 2), WHITE, 1.0)
	text(Vector2(at.x + w, at.y), value, 12, col if col != GREEN else WHITE, 1)


## A label and value row: label grey, value coloured.
func row(at: Vector2, label: String, value: String, col: Color = WHITE, value_x: float = 34.0) -> void:
	text(at, label, 11, GREY)
	text(at + Vector2(value_x, 0), value, 13, col)


## One annunciator capsule: legend lit in its colour when on, a dark legend when off.
func capsule(r: Rect2, legend: String, on: bool, col: Color, blink_off: bool = false) -> void:
	rect(r, Color("0b0d0e"))
	if on and not blink_off:
		rect(r.grow(-1.5), Color(col, 0.22))
		rect(r.grow(-1.5), Color(col, 0.9), false, 1.0)
		text(Vector2(r.get_center().x, r.end.y - r.size.y * 0.28), legend, minf(12.0, r.size.y * 0.58), col.lightened(0.15), 0)
	else:
		rect(r.grow(-1.5), Color("23292b"), false, 1.0)
		text(Vector2(r.get_center().x, r.end.y - r.size.y * 0.28), legend, minf(12.0, r.size.y * 0.58), Color("3e4649"), 0)
