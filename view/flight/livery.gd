## Paint schemes from data/liveries.json. An operator's ships share its colours, and
## each ship weathers in its own way, seeded by its name, so a fleet reads as one
## outfit yet no two hulls are quite alike. Independents pick a scheme by name.
extends RefCounted

const Kit := preload("res://view/flight/kit.gd")


## {name, hull, accent, trim, foil, patch: Color, wear, mismatch, seed: float,
## containers: Array of Color, mats: role -> material}. Roles: hull, accent, trim,
## foil, steel, dark, black.
static func for_ship(data, operator: String, ship_name: String, player: bool = false) -> Dictionary:
	var lv: Dictionary = data.liveries
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(ship_name + "/" + operator)
	var base: Dictionary
	var wear: float
	var mismatch: float
	if player and lv.has("player"):
		base = lv["player"]
		wear = float(base.get("wear", 0.5))
		mismatch = float(base.get("mismatch", 0.2))
	elif lv.get("operators", {}).has(operator):
		base = lv["operators"][operator]
		wear = clampf(float(base.get("wear", 0.4)) + rng.randf_range(-0.12, 0.12), 0.0, 1.0)
		mismatch = clampf(float(base.get("mismatch", 0.1)) * rng.randf_range(0.5, 1.5), 0.0, 1.0)
	else:
		var ind: Dictionary = lv.get("independent", {})
		var palette: Array = ind.get("palette", [{}])
		base = palette[rng.randi() % palette.size()]
		var w: Array = ind.get("wear", [0.4, 0.8])
		var m: Array = ind.get("mismatch", [0.15, 0.4])
		wear = rng.randf_range(float(w[0]), float(w[1]))
		mismatch = rng.randf_range(float(m[0]), float(m[1]))
	var scheme := {
		"name": ship_name,
		"hull": Color(base.get("hull", "#d9d4c7")),
		"accent": Color(base.get("accent", "#d2702c")),
		"trim": Color(base.get("trim", "#d8b02a")),
		"foil": Color(base.get("foil", "#c9a24a")),
		"patch": Color(base.get("patch", "#8c9196")),
		"wear": wear,
		"mismatch": mismatch,
		"seed": rng.randf_range(0.0, 100.0),
		"containers": [],
	}
	for c in lv.get("containers", ["#9a5a3a"]):
		scheme["containers"].append(Color(c))
	scheme["mats"] = _materials(scheme)
	return scheme


## A station's scheme: its own hull colour (data "colour"), the operator's markings.
static func for_station(data, place_id: String) -> Dictionary:
	var place: Dictionary = data.places[place_id]
	var scheme := for_ship(data, place.get("operator", ""), place_id)
	var geom: Dictionary = place["station"]
	scheme["hull"] = Kit.COLOURS.get(geom.get("colour", "offwhite"), scheme["hull"])
	scheme["wear"] = float(geom.get("wear", clampf(scheme["wear"], 0.15, 0.5)))
	scheme["panel_m"] = 3.0
	scheme["mats"] = _materials(scheme)
	return scheme


## A cargo box colour for one slot, fixed by the ship and slot.
static func container_colour(scheme: Dictionary, slot: String) -> Color:
	var list: Array = scheme["containers"]
	return list[absi(hash(scheme["name"] + slot)) % list.size()]


static func paint(scheme: Dictionary, colour: Color, extra: Dictionary = {}) -> ShaderMaterial:
	var opts := {"wear": scheme["wear"], "mismatch": scheme["mismatch"], "patch": scheme["patch"],
		"seed": scheme["seed"], "panel_m": scheme.get("panel_m", 1.6)}
	opts.merge(extra, true)
	return Kit.paint(colour, opts)


static func _materials(s: Dictionary) -> Dictionary:
	return {
		"hull": paint(s, s["hull"], {"weld": 1.0}),
		"accent": paint(s, s["accent"], {"mismatch": 0.0}),
		"trim": paint(s, s["trim"], {"mismatch": 0.0, "wear": minf(1.0, s["wear"] * 1.3)}),
		"foil": paint(s, s["foil"], {"finish": 2, "roughness": 0.35, "metallic": 0.85}),
		"steel": paint(s, Kit.COLOURS["steel"], {"finish": 1, "roughness": 0.5, "metallic": 0.6}),
		"dark": paint(s, Kit.COLOURS["dark"], {"mismatch": 0.03, "roughness": 0.75}),
		"black": paint(s, Kit.COLOURS["black"], {"mismatch": 0.0}),
	}
