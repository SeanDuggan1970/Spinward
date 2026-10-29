## A sky full of homesteads (data/homesteads.json): small claims and beacons on
## circular orbits about a world or the Sun, for the system map. View-only: where
## each one is comes from hashing its name, never from the sim's generator.
extends RefCounted

const V := preload("res://sim/v3.gd")
const AU := 1.495978707e11

## Built once per catalog: catalog instance id -> the list.
static var _cache := {}


## Every homestead: {name, who (named ones), around, r_m, phase, omega}.
static func all(data) -> Array:
	var key: int = data.get_instance_id()
	if _cache.has(key):
		return _cache[key]
	var out: Array = []
	var file: Dictionary = data.homesteads
	for h in file.get("named", []):
		out.append(_orbit(data, String(h["name"]), String(h.get("who", "")), String(h["around"]), _radius(h, 0.5)))
	var first: Array = file.get("first", ["Little"])
	var second: Array = file.get("second", ["Rock"])
	for i in file.get("scatter", []).size():
		var region: Dictionary = file["scatter"][i]
		for k in int(region["count"]):
			var hk := absi(hash("homestead:%d:%d" % [i, k]))
			var name := "%s %s" % [first[hk % first.size()], second[(hk / 97) % second.size()]]
			out.append(_orbit(data, name, "", String(region["around"]), _radius(region, float((hk / 7919) % 1000) / 1000.0)))
	_cache[key] = out
	return out


## Where a homestead is at t (heliocentric, metres), in the ecliptic plane about its body.
static func position(h: Dictionary, eph, t: float) -> Array:
	var a: float = float(h["phase"]) + float(h["omega"]) * t
	return V.add(eph.position(h["around"], t), [float(h["r_m"]) * cos(a), float(h["r_m"]) * sin(a), 0.0])


## A radius (metres) from r_km or a_au: a single value, or [min, max] at share u.
static func _radius(spec: Dictionary, u: float) -> float:
	var scale := 1000.0 if spec.has("r_km") else AU
	var v = spec.get("r_km", spec.get("a_au", 1.0))
	if v is Array:
		return lerpf(float(v[0]), float(v[1]), u) * scale
	return float(v) * scale


static func _orbit(data, name: String, who: String, around: String, r: float) -> Dictionary:
	var gm := float(data.bodies[around]["gm"])
	return {"name": name, "who": who, "around": around, "r_m": r,
		"phase": float(absi(hash("phase:" + name + str(r))) % 3600) / 3600.0 * TAU, "omega": sqrt(gm / (r * r * r))}


## The named homestead nearest `pos` (heliocentric) at t, with its distance: {h, d}, or {}.
static func nearest_named(data, eph, pos: Array, t: float) -> Dictionary:
	var best := {}
	for h in all(data):
		if h["who"] == "":
			continue
		var d := V.distance(position(h, eph, t), pos)
		if best.is_empty() or d < float(best["d"]):
			best = {"h": h, "d": d}
	return best
