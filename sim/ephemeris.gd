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
var _cache_t := NAN
var _cache: Dictionary = {}


func _init(body_data: Dictionary, place_data: Dictionary) -> void:
	bodies = body_data
	places = place_data


func position(id: String, t: float) -> Array:
	if t != _cache_t:
		_cache_t = t
		_cache.clear()
	if _cache.has(id):
		return _cache[id]
	var p: Array
	if bodies.has(id):
		p = _body_position(id, t)
	elif places.has(id):
		p = _place_position(places[id], t)
	else:
		assert(false, "Unknown body or place: " + id)
		p = [0.0, 0.0, 0.0]
	_cache[id] = p
	return p


## Central difference. The position cache holds one time at a time, so it is set
## aside and restored here: otherwise a Lagrange point evaluated at t would be cached
## under t - 30 s and the result of a lookup could depend on call history.
func velocity(id: String, t: float) -> Array:
	var h := 30.0
	var saved_t := _cache_t
	var saved := _cache
	_cache_t = NAN
	_cache = {}
	var v := V.scale(V.sub(position(id, t + h), position(id, t - h)), 0.5 / h)
	_cache_t = saved_t
	_cache = saved
	return v


## Position of `id` relative to `parent_id`.
func relative(id: String, parent_id: String, t: float) -> Array:
	return V.sub(position(id, t), position(parent_id, t))


func _body_position(id: String, t: float) -> Array:
	var body: Dictionary = bodies[id]
	if not body.has("parent"):
		return [0.0, 0.0, 0.0]
	var parent: String = body["parent"]
	var gm := float(bodies[parent]["gm"]) + float(body.get("gm", 0.0))
	return V.add(position(parent, t), kepler(body["elements"], gm, t))


func _place_position(place: Dictionary, t: float) -> Array:
	var where: Dictionary = place["location"]
	match where["type"]:
		"orbit":
			var parent: String = where["parent"]
			return V.add(position(parent, t), kepler(where["elements"], float(bodies[parent]["gm"]), t))
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
			var x := collinear_point(mu, point)
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
