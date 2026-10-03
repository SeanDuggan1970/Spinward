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
			if module.get("kind") != kind:
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
	var start: Dictionary = balance.get("start", {})
	if not places.has(start.get("place", "")):
		problems.append("balance.start.place is not a place")
	if not ships.has(start.get("ship", "")):
		problems.append("balance.start.ship is not a ship")
	return problems
