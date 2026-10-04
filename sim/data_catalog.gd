## Loads content and balance from data/. The sim reads rules only from here.
## Keys starting with "_" are comments and are dropped on load.
extends RefCounted

const DATA_ROOT := "res://data"

var balance: Dictionary = {}
var bodies: Dictionary = {}
var places: Dictionary = {}
var goods: Dictionary = {}
var modules: Dictionary = {}
var ships: Dictionary = {}
var npcs: Dictionary = {}
var projects: Dictionary = {}
var projects_reserve_fraction := 0.4
var brokers: Dictionary = {}
## Courier contracts and reputation tiers (data/contracts.json).
var contracts: Dictionary = {}
## Paint schemes for the view (data/liveries.json); the sim never reads them.
var liveries: Dictionary = {}
## tip_ttl_days, verify_tolerance.
var brokers_meta: Dictionary = {}


static func load_default():
	var catalog = load("res://sim/data_catalog.gd").new()
	catalog.load_from(DATA_ROOT)
	return catalog


func load_from(root: String) -> void:
	balance = read_json(root + "/balance.json")
	bodies = read_json(root + "/bodies.json")
	places = read_json(root + "/places.json")
	goods = read_json(root + "/goods.json")
	modules = read_json(root + "/modules.json")
	ships = read_json(root + "/ships.json")
	npcs = read_json(root + "/npcs.json")
	projects = read_json(root + "/projects.json")
	projects_reserve_fraction = float(projects.get("reserve_fraction", 0.4))
	projects.erase("reserve_fraction")
	contracts = read_json(root + "/contracts.json")
	if FileAccess.file_exists(root + "/liveries.json"):
		liveries = read_json(root + "/liveries.json")
	var broker_file := read_json(root + "/brokers.json")
	brokers = broker_file.get("brokers", {})
	brokers_meta = {"tip_ttl_days": float(broker_file.get("tip_ttl_days", 5.0)), "verify_tolerance": float(broker_file.get("verify_tolerance", 0.8)),
		"logbook_age_days": float(broker_file.get("logbook_age_days", 3.0))}


func read_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	assert(parsed is Dictionary, "Invalid or missing data file: " + path)
	return _strip_comments(parsed)


func _strip_comments(d: Dictionary) -> Dictionary:
	var out := {}
	for key in d:
		if str(key).begins_with("_"):
			continue
		out[key] = _strip_comments(d[key]) if d[key] is Dictionary else d[key]
	return out


## Cross-reference checks. Returns human-readable problems; empty means valid.
func validate() -> Array[String]:
	var problems: Array[String] = []
	for id in bodies:
		var parent = bodies[id].get("parent")
		if parent != null and not bodies.has(parent):
			problems.append("body %s: unknown parent %s" % [id, parent])
	for id in places:
		var p: Dictionary = places[id]
		var loc: Dictionary = p.get("location", {})
		for body in ([loc.get("parent")] if loc.get("type") == "orbit" else loc.get("system", [])):
			if not bodies.has(body):
				problems.append("place %s: unknown body %s" % [id, body])
		var market: Dictionary = p.get("market", {})
		for g in market:
			if not goods.has(g):
				problems.append("place %s: unknown good %s" % [id, g])
		var flows: Array = [p.get("produces", {}), p.get("consumes", {})]
		for recipe in p.get("recipes", []):
			flows.append(recipe["inputs"])
			flows.append(recipe["outputs"])
		for flow in flows:
			for g in flow:
				if not market.has(g):
					problems.append("place %s: %s flows but is not in its market" % [id, g])
		for module_id in p.get("shipyard_stock", []):
			if not modules.has(module_id):
				problems.append("place %s: shipyard sells unknown module %s" % [id, module_id])
		if "refuel" in p.get("services", []) and not market.has("propellant"):
			problems.append("place %s: refuel service without a propellant market" % id)
	for id in ships:
		var ship: Dictionary = ships[id]
		var spine: Dictionary = modules.get(ship["spine"], {})
		if spine.get("kind") != "spine":
			problems.append("ship %s: spine %s is not a spine module" % [id, ship["spine"]])
			continue
		for slot in ship["modules"]:
			var kind: String = slot.split(".")[0]
			var index := int(slot.split(".")[1])
			var module: Dictionary = modules.get(ship["modules"][slot], {})
			if not kind in module.get("mounts", [module.get("kind")]):
				problems.append("ship %s: slot %s holds %s of the wrong kind" % [id, slot, ship["modules"][slot]])
			if index >= int(spine["slots"].get(kind, 0)):
				problems.append("ship %s: slot %s does not exist on the spine" % [id, slot])
	for fleet_id in npcs.get("fleets", {}):
		var fleet: Dictionary = npcs["fleets"][fleet_id]
		if fleet.get("names", []).is_empty():
			problems.append("fleet %s: needs at least one name" % fleet_id)
		if int(fleet.get("count", 0)) < 1:
			problems.append("fleet %s: count must be at least 1" % fleet_id)
		var dwell: Array = fleet.get("dwell_hours", [])
		if dwell.size() != 2 or float(dwell[0]) < 0.0 or float(dwell[1]) < float(dwell[0]):
			problems.append("fleet %s: dwell_hours must be [min, max]" % fleet_id)
		if not ships.has(fleet.get("hull", "")):
			problems.append("fleet %s: unknown hull %s" % [fleet_id, fleet.get("hull")])
		if not fleet.get("behaviour") in ["trader", "route", "shuttle"]:
			problems.append("fleet %s: unknown behaviour %s" % [fleet_id, fleet.get("behaviour")])
		for home in fleet.get("homes", []):
			if not places.has(home):
				problems.append("fleet %s: unknown home %s" % [fleet_id, home])
		if fleet.get("behaviour") == "trader" and fleet.get("homes", []).is_empty():
			problems.append("fleet %s: traders need homes" % fleet_id)
		var route: Array = fleet.get("route", [])
		if fleet.get("behaviour") != "trader" and route.is_empty():
			problems.append("fleet %s: needs a route" % fleet_id)
		for i in route.size():
			var leg: Dictionary = route[i]
			if not places.has(leg.get("at", "")) or not places.has(leg.get("to", "")):
				problems.append("fleet %s leg %d: unknown place" % [fleet_id, i])
				continue
			if route[(i + 1) % route.size()]["at"] != leg["to"]:
				problems.append("fleet %s leg %d: next leg does not start where this one ends" % [fleet_id, i])
			for good in leg.get("buy", []):
				if not (places[leg["at"]]["market"].has(good) and places[leg["to"]]["market"].has(good)):
					problems.append("fleet %s leg %d: %s must be traded at both ends" % [fleet_id, i, good])
	var features_seen := {}
	for id in projects:
		var project: Dictionary = projects[id]
		var place: String = project.get("place", "")
		if not places.has(place):
			problems.append("project %s: unknown place %s" % [id, place])
			continue
		if project.get("stages", []).is_empty():
			problems.append("project %s: has no stages" % id)
		if float(project.get("draw_t_per_day", 0.0)) <= 0.0:
			problems.append("project %s: draw_t_per_day must be positive" % id)
		for stage in project.get("stages", []):
			if stage.get("needs", {}).is_empty():
				problems.append("project %s: stage %s needs nothing" % [id, stage.get("name", "?")])
			for good in stage.get("needs", {}):
				if not places[place].get("market", {}).has(good):
					problems.append("project %s: %s is needed but not traded at %s" % [id, good, place])
				if float(stage["needs"][good]) <= 0.0:
					problems.append("project %s: %s need must be positive" % [id, good])
		for target in project.get("effects", {}):
			if not places.has(target):
				problems.append("project %s: effect on unknown place %s" % [id, target])
			for key in project["effects"][target]:
				if not key in ["produces_mult", "consumes_mult"]:
					problems.append("project %s: unknown effect %s" % [id, key])
				elif float(project["effects"][target][key]) <= 0.0:
					problems.append("project %s: effect %s must be positive" % [id, key])
		var feature: String = project.get("feature", "")
		if feature != "":
			if features_seen.has(feature):
				problems.append("project %s: feature %s already driven by %s" % [id, feature, features_seen[feature]])
			features_seen[feature] = id
	for id in brokers:
		var b: Dictionary = brokers[id]
		if not places.has(b.get("place", "")):
			problems.append("broker %s: unknown place %s" % [id, b.get("place")])
		var r := float(b.get("reliability", -1.0))
		if r < 0.0 or r > 1.0:
			problems.append("broker %s: reliability must be 0..1" % id)
		if float(b.get("price", -1.0)) < 0.0:
			problems.append("broker %s: price must not be negative" % id)
		var cov = b.get("coverage", [])
		if cov is String:
			if cov != "all":
				problems.append("broker %s: coverage must be 'all' or a list of places" % id)
		else:
			for p in cov:
				if not places.has(p):
					problems.append("broker %s: covers unknown place %s" % [id, p])
		for kind in ["short", "glut"]:
			if b.get(kind, []).is_empty():
				problems.append("broker %s: needs at least one '%s' line" % [id, kind])
	var start: Dictionary = balance.get("start", {})
	if not places.has(start.get("place", "")):
		problems.append("balance.start.place is not a place")
	if not ships.has(start.get("ship", "")):
		problems.append("balance.start.ship is not a ship")
	# Contracts: reference ships must be buildable.
	for range_name in contracts.get("reference_ships", {}):
		var spec: Dictionary = contracts["reference_ships"][range_name]
		if not ships.has(spec.get("hull", "")):
			problems.append("contracts: reference ship %s has unknown hull %s" % [range_name, spec.get("hull", "")])
		for slot in spec.get("modules", {}):
			if not modules.has(spec["modules"][slot]):
				problems.append("contracts: reference ship %s has unknown module %s" % [range_name, spec["modules"][slot]])
	# Liveries: every operator wears one, and every colour parses.
	var operators: Dictionary = liveries.get("operators", {})
	var flown := {}
	for id in places:
		flown[places[id].get("operator", "")] = "place " + id
	for id in npcs.get("fleets", {}):
		flown[npcs["fleets"][id].get("operator", "")] = "fleet " + id
	for op in flown:
		if op != "Independent" and not operators.has(op):
			problems.append("%s: operator %s has no livery" % [flown[op], op])
	var schemes: Array = operators.values() + liveries.get("independent", {}).get("palette", [])
	if liveries.has("player"):
		schemes.append(liveries["player"])
	for scheme in schemes:
		for role in ["hull", "accent", "trim", "foil", "patch"]:
			if scheme.has(role) and not Color.html_is_valid(String(scheme[role])):
				problems.append("livery colour %s is not a colour" % scheme[role])
	for c in liveries.get("containers", []):
		if not Color.html_is_valid(String(c)):
			problems.append("livery container colour %s is not a colour" % c)
	return problems
