## Positions of bodies and places from data, on rails (Keplerian elements).
## Frame: heliocentric, J2000 ecliptic, metres. Time: seconds since J2000.
## Places are "orbit" (elements around a parent body), "lagrange" (a point of a
## two-body system, solved from the circular restricted three-body model) or "surface"
## (a town on a body: at lat/lon, turning with its day, or always under the body it
## faces, like the Moon's near side under Earth).
extends RefCounted

const V := preload("res://sim/v3.gd")
const DAY := 86400.0
const OBLIQUITY_J2000 := deg_to_rad(23.439291)

var bodies: Dictionary
var places: Dictionary
## Positions are pure in (id, t), so each id remembers the last instant it was asked
## for. Route planning asks for the same few instants again and again (both ends of a
## burn, a shared frame body at every track step). Ids are numbered on first use, with
## parallel arrays per index: the instant and position last found, the parent's index
## (-1 for the root, -2 for places that need the long way: Lagrange points, towns) and
## the precomputed elements (see _pre).
var _idx: Dictionary = {}
var _ids: Array = []
var _slot_t := PackedFloat64Array()
var _slot_p: Array = []
var _parent := PackedInt32Array()
var _elements: Array = []
## The collinear Lagrange roots depend only on the mass ratio and the point.
var _collinear: Dictionary = {}


func _init(body_data: Dictionary, place_data: Dictionary) -> void:
	bodies = body_data
	places = place_data


func position(id: String, t: float) -> Array:
	var i: int = _idx.get(id, -1)
	if i < 0:
		i = _index(id)
	return _pos(i, t)


func _pos(i: int, t: float) -> Array:
	if _slot_t[i] == t:
		return _slot_p[i]
	var p: Array
	var par := _parent[i]
	if par >= 0:
		var c := _pos(par, t)
		var r := _kepler_pre(_elements[i], t)
		p = [c[0] + r[0], c[1] + r[1], c[2] + r[2]]
	elif par == -1:
		p = [0.0, 0.0, 0.0]
	else:
		p = _place_position(_ids[i], places[_ids[i]], t)
	_slot_t[i] = t
	_slot_p[i] = p
	return p


## Central difference. The cache is keyed by time, so t +- 30 s never collides with t.
func velocity(id: String, t: float) -> Array:
	var h := 30.0
	return V.scale(V.sub(position(id, t + h), position(id, t - h)), 0.5 / h)


## Position of `id` relative to `parent_id`.
func relative(id: String, parent_id: String, t: float) -> Array:
	var a := position(id, t)
	var b := position(parent_id, t)
	return [a[0] - b[0], a[1] - b[1], a[2] - b[2]]


## Number an id on first use (its parent first), with what its position needs.
func _index(id: String) -> int:
	var parent_id := ""
	var pre = null
	var par := -1
	if bodies.has(id):
		var body: Dictionary = bodies[id]
		if body.has("parent"):
			parent_id = body["parent"]
			var gm := float(bodies[parent_id]["gm"]) + float(body.get("gm", 0.0))
			pre = _pre("b:" + id, body["elements"], gm)
	elif places.has(id):
		var where: Dictionary = places[id]["location"]
		if where["type"] == "orbit":
			parent_id = where["parent"]
			pre = _pre("p:" + id, where["elements"], float(bodies[parent_id]["gm"]))
		else:
			par = -2
	else:
		assert(false, "Unknown body or place: " + id)
	if parent_id != "":
		par = _idx.get(parent_id, -1)
		if par < 0:
			par = _index(parent_id)
	var i := _ids.size()
	_ids.append(id)
	_slot_t.append(NAN)
	_slot_p.append(null)
	_parent.append(par)
	_elements.append(pre)
	_idx[id] = i
	return i


func _place_position(id: String, place: Dictionary, t: float) -> Array:
	var where: Dictionary = place["location"]
	match where["type"]:
		"orbit":
			var parent: String = where["parent"]
			var c := position(parent, t)
			var r := _kepler_pre(_pre("p:" + id, where["elements"], float(bodies[parent]["gm"])), t)
			return [c[0] + r[0], c[1] + r[1], c[2] + r[2]]
		"lagrange":
			var at := lagrange_point(where["system"][0], where["system"][1], where["point"], t)
			if where.has("offset_km"):
				# Along the primary-secondary line, across it in the orbit plane, and out of it.
				var o: Array = where["offset_km"]
				var p0 := position(where["system"][0], t)
				var rel := V.sub(position(where["system"][1], t), p0)
				var u := V.normalized(rel)
				var h := V.normalized(V.cross(rel, V.sub(velocity(where["system"][1], t), velocity(where["system"][0], t))))
				var w := V.cross(h, u)
				at = V.add(at, V.scale(V.add(V.add(V.scale(u, float(o[0])), V.scale(w, float(o[1]))), V.scale(h, float(o[2]))), 1000.0))
			return at
		"surface":
			return surface_point(where, t)
	assert(false, "Unknown place location type")
	return [0.0, 0.0, 0.0]


## A town on a body's surface (see the header). The body's equator follows its pole
## where data gives one, otherwise the ecliptic.
func surface_point(where: Dictionary, t: float) -> Array:
	var parent: String = where["parent"]
	var c := position(parent, t)
	var r := float(bodies[parent]["radius_m"])
	if where.has("facing"):
		return V.add(c, V.scale(V.normalized(V.sub(position(where["facing"], t), c)), r))
	var lat := deg_to_rad(float(where.get("lat_deg", 0.0)))
	var lon := deg_to_rad(float(where.get("lon_deg", 0.0))) + TAU * t / float(where.get("day_s", 86400.0))
	var pole := [0.0, 0.0, 1.0]
	var b: Dictionary = bodies[parent]
	if b.has("pole_ra_deg"):
		var ra := deg_to_rad(float(b["pole_ra_deg"]))
		var dec := deg_to_rad(float(b["pole_dec_deg"]))
		pole = equatorial_to_ecliptic([cos(dec) * cos(ra), cos(dec) * sin(ra), sin(dec)])
	var x := V.cross([0.0, 0.0, 1.0], pole)
	x = V.normalized(x) if V.length(x) > 1e-6 else [1.0, 0.0, 0.0]
	var y := V.cross(pole, x)
	var d := V.add(V.add(V.scale(x, cos(lat) * cos(lon)), V.scale(y, cos(lat) * sin(lon))), V.scale(pole, sin(lat)))
	return V.add(c, V.scale(d, r))


## Everything kepler() derives from the elements alone (not from t), computed once per
## element set: [a, e, n, m0 (rad), node0 (deg), node rate, peri0 (deg), peri rate,
## cos i, sin i, a * sqrt(1 - e^2), equatorial?]. Same arithmetic as kepler(), so the
## positions are bit-identical.
var _pre_cache: Dictionary = {}


func _pre(key: String, el: Dictionary, gm: float) -> Array:
	var hit = _pre_cache.get(key)
	if hit != null:
		return hit
	var a := float(el["a_m"])
	var e := float(el.get("e", 0.0))
	var n: float
	if el.has("period_days"):
		n = TAU / (float(el["period_days"]) * DAY)
	else:
		n = sqrt(gm / (a * a * a))
	var inc := deg_to_rad(float(el.get("i_deg", 0.0)))
	var pre := [a, e, n, deg_to_rad(float(el.get("m0_deg", 0.0))),
		float(el.get("node_deg", 0.0)), float(el.get("node_rate_deg_per_day", 0.0)),
		float(el.get("peri_deg", 0.0)), float(el.get("peri_rate_deg_per_day", 0.0)),
		cos(inc), sin(inc), a * sqrt(1.0 - e * e), el.get("frame", "ecliptic") == "equatorial"]
	_pre_cache[key] = pre
	return pre


static func _kepler_pre(k: Array, t: float) -> Array:
	var e: float = k[1]
	var days := t / DAY
	var node := deg_to_rad(k[4] + k[5] * days)
	var peri := deg_to_rad(k[6] + k[7] * days)
	var m := fposmod(k[3] + k[2] * t, TAU)
	var ecc_anomaly := m if e < 0.8 else PI
	for _i in 30:
		var step := (ecc_anomaly - e * sin(ecc_anomaly) - m) / (1.0 - e * cos(ecc_anomaly))
		ecc_anomaly -= step
		if absf(step) < 1e-13:
			break
	var x: float = k[0] * (cos(ecc_anomaly) - e)
	var y: float = k[10] * sin(ecc_anomaly)
	var cp := cos(peri); var sp := sin(peri)
	var cn := cos(node); var sn := sin(node)
	var ci: float = k[8]
	var si: float = k[9]
	var xp := x * cp - y * sp
	var yp := x * sp + y * cp
	var r := [xp * cn - yp * ci * sn, xp * sn + yp * ci * cn, yp * si]
	if k[11]:
		r = equatorial_to_ecliptic(r)
	return r


## Keplerian elements -> position relative to the focus.
static func kepler(el: Dictionary, gm: float, t: float) -> Array:
	var a := float(el["a_m"])
	var e := float(el.get("e", 0.0))
	var days := t / DAY
	var n: float
	if el.has("period_days"):
		n = TAU / (float(el["period_days"]) * DAY)
	else:
		n = sqrt(gm / (a * a * a))
	var node := deg_to_rad(float(el.get("node_deg", 0.0)) + float(el.get("node_rate_deg_per_day", 0.0)) * days)
	var peri := deg_to_rad(float(el.get("peri_deg", 0.0)) + float(el.get("peri_rate_deg_per_day", 0.0)) * days)
	var inc := deg_to_rad(float(el.get("i_deg", 0.0)))
	var m := fposmod(deg_to_rad(float(el.get("m0_deg", 0.0))) + n * t, TAU)
	var ecc_anomaly := m if e < 0.8 else PI
	for _i in 30:
		var step := (ecc_anomaly - e * sin(ecc_anomaly) - m) / (1.0 - e * cos(ecc_anomaly))
		ecc_anomaly -= step
		if absf(step) < 1e-13:
			break
	var x := a * (cos(ecc_anomaly) - e)
	var y := a * sqrt(1.0 - e * e) * sin(ecc_anomaly)
	# Perifocal -> ecliptic: Rz(node) * Rx(inc) * Rz(peri).
	var cp := cos(peri); var sp := sin(peri)
	var cn := cos(node); var sn := sin(node)
	var ci := cos(inc); var si := sin(inc)
	var xp := x * cp - y * sp
	var yp := x * sp + y * cp
	var r := [xp * cn - yp * ci * sn, xp * sn + yp * ci * cn, yp * si]
	match el.get("frame", "ecliptic"):
		"equatorial":
			# Elements on Earth's equator (node from the vernal equinox).
			r = equatorial_to_ecliptic(r)
	return r


## ICRF (Earth-equatorial) to J2000 ecliptic: rotate about X by the obliquity. The
## equator's point at RA 90 deg lies 23.4 deg south of the ecliptic.
static func equatorial_to_ecliptic(r: Array) -> Array:
	var co := cos(OBLIQUITY_J2000)
	var so := sin(OBLIQUITY_J2000)
	return [r[0], r[1] * co + r[2] * so, -r[1] * so + r[2] * co]


## Lagrange point of the primary/secondary system ("L1".."L5").
func lagrange_point(primary: String, secondary: String, point: String, t: float) -> Array:
	var p0 := position(primary, t)
	var rel := V.sub(position(secondary, t), p0)
	var dist := V.length(rel)
	var u := V.normalized(rel)
	var mu := float(bodies[secondary]["gm"]) / (float(bodies[primary]["gm"]) + float(bodies[secondary]["gm"]))
	match point:
		"L4", "L5":
			var h := V.normalized(V.cross(rel, V.sub(velocity(secondary, t), velocity(primary, t))))
			return V.add(p0, V.rotate(rel, h, deg_to_rad(60.0 if point == "L4" else -60.0)))
		"L1", "L2", "L3":
			var key := "%s|%s|%s" % [primary, secondary, point]
			if not _collinear.has(key):
				_collinear[key] = collinear_point(mu, point)
			var x: float = _collinear[key]
			# x is measured from the barycentre in units of the separation; primary sits at -mu.
			return V.add(p0, V.scale(u, (x + mu) * dist))
	assert(false, "Unknown Lagrange point " + point)
	return p0


## Root of the collinear-point equation of the rotating-frame CR3BP, by bisection.
static func collinear_point(mu: float, point: String) -> float:
	var lo: float
	var hi: float
	match point:
		"L1":
			lo = -mu + 1e-6; hi = 1.0 - mu - 1e-6
		"L2":
			lo = 1.0 - mu + 1e-6; hi = 2.0
		_:
			lo = -2.0; hi = -mu - 1e-6
	var f := func(x: float) -> float:
		var d1 := x + mu
		var d2 := x - 1.0 + mu
		return x - (1.0 - mu) * d1 / pow(absf(d1), 3) - mu * d2 / pow(absf(d2), 3)
	var flo: float = f.call(lo)
	for _i in 200:
		var mid := 0.5 * (lo + hi)
		var fm: float = f.call(mid)
		if (fm < 0.0) == (flo < 0.0):
			lo = mid; flo = fm
		else:
			hi = mid
	return 0.5 * (lo + hi)
