## Warrant of Fitness (WoF): a periodic safety inspection at a shipyard, as in New
## Zealand. Pure functions of state and data/ship_economy.json "wof".
##
## ship["wof"] = {valid_until_t, result: "pass" | "fail" | "void", issues: [text], inspected_t}.
## A ship with no "wof" key (an old save) counts as valid until the fitness system gives it
## one. Without a valid WoF: passenger jobs are refused, insurance is void, and traffic
## control at some ports charges extra or refuses passengers (all in data).
extends RefCounted

const Condition := preload("res://sim/condition.gd")


static func rules(data) -> Dictionary:
	return data.ship_economy["wof"]


## {state: valid | expiring | expired | failed | voided, valid, days_left, issues}.
static func status(state, data) -> Dictionary:
	var w: Dictionary = state.ship.get("wof", {})
	if w.is_empty():
		return {"state": "valid", "valid": true, "days_left": INF, "issues": []}
	var days_left: float = (float(w.get("valid_until_t", 0.0)) - state.time_s) / 86400.0
	var result: String = w.get("result", "pass")
	var issues: Array = w.get("issues", [])
	if result == "fail":
		return {"state": "failed", "valid": false, "days_left": 0.0, "issues": issues}
	if result == "void":
		return {"state": "voided", "valid": false, "days_left": 0.0, "issues": issues}
	if days_left <= 0.0:
		return {"state": "expired", "valid": false, "days_left": days_left, "issues": issues}
	return {"state": "expiring" if days_left <= float(rules(data)["warn_days"]) else "valid", "valid": true, "days_left": days_left, "issues": issues}


static func valid(state, data) -> bool:
	return bool(status(state, data)["valid"])


## What an inspection would find on this ship: {pass, issues: [{slot, text}]}. Each issue
## is something that must be fixed before a certificate is issued.
static func inspect(ship: Dictionary, data) -> Dictionary:
	var r := rules(data)
	var issues := []
	var slots: Array = ship.get("modules", {}).keys()
	slots.sort()
	for slot in slots:
		var name: String = data.modules[ship["modules"][slot]]["name"]
		var cond := Condition.condition(ship, slot)
		if cond < float(r["min_condition"]):
			issues.append({"slot": slot, "text": "%s is worn out (condition %d%%): overhaul it" % [name, int(round(cond * 100.0))]})
		var dmg := float(ship.get("damage", {}).get(slot, 0.0))
		if dmg > float(r["max_module_damage"]):
			issues.append({"slot": slot, "text": "%s is damaged (%d%%): repair it" % [name, int(round(dmg * 100.0))]})
	var keel := float(ship.get("damage", {}).get("keel", 0.0))
	if keel > float(r["max_keel_damage"]):
		issues.append({"slot": "keel", "text": "the keel is strained (%d%%): repair it" % int(round(keel * 100.0))})
	return {"pass": issues.is_empty(), "issues": issues}


## Record an inspection's outcome on the ship (no payment). Returns the result dictionary.
static func certify(ship: Dictionary, now_t: float, data) -> Dictionary:
	var res := inspect(ship, data)
	var texts := []
	for i in res["issues"]:
		texts.append(i["text"])
	ship["wof"] = {
		"valid_until_t": now_t + float(rules(data)["valid_days"]) * 86400.0 if res["pass"] else now_t,
		"result": "pass" if res["pass"] else "fail", "issues": texts, "inspected_t": now_t,
	}
	return res


## A refit of a safety-critical kind (data: refit_voids) voids the certificate until the
## ship is inspected again.
static func void_for_refit(ship: Dictionary, now_t: float, data) -> void:
	if not ship.has("wof"):
		return
	ship["wof"] = {"valid_until_t": now_t, "result": "void", "issues": ["refitted since the last inspection: inspect again"], "inspected_t": float(ship["wof"].get("inspected_t", now_t))}


## The traffic-control class of a place: its own "traffic" field, else by operator.
static func port_class(place: String, data) -> String:
	var p: Dictionary = data.locations.get(place, {})
	var r := rules(data)
	return String(p.get("traffic", r["operator_class"].get(p.get("operator", ""), r["default_class"])))


## What docking at `place` costs for want of a valid WoF: {class, surcharge_cr, refuse_passengers}.
## Zero and false when the WoF is valid.
static func dock_terms(state, data, place: String) -> Dictionary:
	var cls := port_class(place, data)
	if valid(state, data):
		return {"class": cls, "surcharge_cr": 0.0, "refuse_passengers": false}
	var rule: Dictionary = rules(data)["port_rules"][cls]
	return {"class": cls, "surcharge_cr": float(rule["surcharge_cr"]), "refuse_passengers": bool(rule["refuse_passengers"])}


## "" if a passenger job may be taken, else why not.
static func passenger_job_block(state, data) -> String:
	if not bool(rules(data)["effects"].get("passenger_jobs_refused", false)) or valid(state, data):
		return ""
	return "no passengers without a valid Warrant of Fitness: get an inspection at a shipyard"
