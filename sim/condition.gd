## Module wear and condition: pure functions of ship state and data/ship_economy.json,
## shared by the wear system, the shipyard, the insurer and the view.
##
## ship["wear"][slot] is the fraction of a module's life used (0 new, 1 worn out), so
## condition = 1 - wear. It is kept apart from collision damage (ship["damage"]), which
## is a sudden loss; wear is slow and what service and overhaul at a yard put right.
## ship["use"][slot] holds the counters wear came from (hours in service, burn hours,
## docks, landings) and ship["faults"][slot] a small fault: {loss, text, t}.
##
## A module-condition API for anything that wants to touch it later (an engine tune, a
## repair voucher): condition(), restore(), add_wear(), clear_faults().
extends RefCounted


static func econ(data) -> Dictionary:
	return data.ship_economy


## The slot's module kind as the module declares it (a tank in a cargo bay is a "tank").
static func kind_of(ship: Dictionary, slot: String, data) -> String:
	return String(data.modules[ship["modules"][slot]].get("kind", slot.split(".")[0]))


static func wear_of(ship: Dictionary, slot: String) -> float:
	return clampf(float(ship.get("wear", {}).get(slot, 0.0)), 0.0, 1.0)


## 1 (new) to 0 (worn out). A ship without wear data (an old save) is as new.
static func condition(ship: Dictionary, slot: String) -> float:
	return 1.0 - wear_of(ship, slot)


## Mean condition over the fitted modules.
static func mean_condition(ship: Dictionary) -> float:
	var total := 0.0
	var n := 0
	for slot in ship.get("modules", {}):
		total += condition(ship, slot)
		n += 1
	return 1.0 if n == 0 else total / n


static func age_days(ship: Dictionary, slot: String) -> float:
	return float(ship.get("use", {}).get(slot, {}).get("h", 0.0)) / 24.0


static func fault_loss(ship: Dictionary, slot: String) -> float:
	return float(ship.get("faults", {}).get(slot, {}).get("loss", 0.0))


## Make `slot` better by `amount` of condition, to at most `cap` (default as new). Returns
## the condition gained. The API a service, a tune or a repair voucher would call.
static func restore(ship: Dictionary, slot: String, amount: float, cap: float = 1.0) -> float:
	var before := condition(ship, slot)
	var after := minf(maxf(before, cap), before + maxf(amount, 0.0))
	set_condition(ship, slot, after)
	return after - before


static func set_condition(ship: Dictionary, slot: String, cond: float) -> void:
	if not ship.has("wear"):
		ship["wear"] = {}
	ship["wear"][slot] = 1.0 - clampf(cond, 0.0, 1.0)


static func add_wear(ship: Dictionary, slot: String, amount: float) -> void:
	set_condition(ship, slot, condition(ship, slot) - amount)


static func clear_faults(ship: Dictionary, slot: String) -> void:
	if ship.has("faults"):
		ship["faults"].erase(slot)


## A module fresh from the yard: no wear, no age, no faults.
static func reset_slot(ship: Dictionary, slot: String) -> void:
	for key in ["wear", "use", "faults", "warned"]:
		if ship.has(key):
			ship[key].erase(slot)


## What a module is worth for service, overhaul and insurance: its price or its kind's
## basis floor, whichever is higher, or the module's own "basis" override.
static func basis(module_id: String, data) -> float:
	var e := econ(data)
	var over: Dictionary = e["module_overrides"].get(module_id, {})
	if over.has("basis"):
		return float(over["basis"])
	var m: Dictionary = data.modules[module_id]
	return maxf(float(m.get("price", 0.0)), float(_kind(e, String(m.get("kind", "")))["basis_floor"]))


static func _kind(e: Dictionary, kind: String) -> Dictionary:
	return e["kinds"].get(kind, e["kinds"]["default"])


## Output multiplier for one stat of one module from wear and small faults (1 = no loss).
## Only supply and rating stats are scaled (performance.keys).
static func perf(ship: Dictionary, slot: String, key: String, data) -> float:
	var e: Dictionary = data.ship_economy.get("performance", {})
	if not key in e.get("keys", []):
		return 1.0
	var onset := float(e["onset"])
	var cond := condition(ship, slot)
	var loss := float(e["max_loss"]) * clampf((onset - cond) / maxf(onset, 1e-9), 0.0, 1.0)
	return maxf(0.0, 1.0 - loss - fault_loss(ship, slot))


## Fraction of its new price a module of this condition and age is worth (before damage).
static func value_factor(cond: float, age_d: float, data) -> float:
	var r: Dictionary = econ(data)["resale"]
	var base := lerpf(float(r["scrap_fraction"]), float(r["new_fraction"]), pow(clampf(cond, 0.0, 1.0), float(r["condition_exp"])))
	var age := maxf(float(r["age_floor"]), 1.0 - float(r["age_loss_per_year"]) * age_d / 365.0)
	return base * age


## What the yard pays for the module in `slot` as a trade-in: its price by condition,
## age and collision damage. Fresh near full value, tired near scrap.
static func trade_in(ship: Dictionary, slot: String, data) -> float:
	var id: String = ship["modules"].get(slot, "")
	if id == "":
		return 0.0
	var damage := clampf(float(ship.get("damage", {}).get(slot, 0.0)), 0.0, 1.0)
	return float(data.modules[id].get("price", 0.0)) * value_factor(condition(ship, slot), age_days(ship, slot), data) * (1.0 - damage)


## What a ship's modules are worth to an insurer: the keel plus each module's basis by
## its condition and age.
static func insured_value(ship: Dictionary, data) -> float:
	var total := float(data.balance["damage"]["keel_value"])
	for slot in ship.get("modules", {}):
		total += basis(ship["modules"][slot], data) * value_factor(condition(ship, slot), age_days(ship, slot), data)
	return total


## The yard's rate multipliers at a place.
static func yard_rates(place: String, data) -> Dictionary:
	var y: Dictionary = econ(data)["yards"]
	return y.get(place, y["default"])


## {cost, days, to} for a routine "service" or an "overhaul" of one slot at a yard
## ("" if there is nothing to do: already at or above what the work would reach).
static func work_quote(ship: Dictionary, slot: String, level: String, place: String, data) -> Dictionary:
	var e := econ(data)
	var id: String = ship["modules"][slot]
	var over: Dictionary = e["module_overrides"].get(id, {})
	var k := _kind(e, kind_of(ship, slot, data))
	var rate := float(yard_rates(place, data).get(level, 1.0))
	var b := basis(id, data)
	var cond := condition(ship, slot)
	var has_faults := fault_loss(ship, slot) > 0.0
	if level == "service":
		var s: Dictionary = e["service"]
		var to := maxf(cond, minf(float(s["cap"]), cond + float(s["restore"])))
		if to - cond < float(s["min_gain"]) and not has_faults:
			return {"cost": 0.0, "days": 0.0, "to": cond, "reason": "nothing to service"}
		var cost: float = float(over["service_cr"]) if over.has("service_cr") else maxf(float(s["min_cr"]), b * float(s["cost_frac"]))
		return {"cost": ceilf(cost * rate), "days": float(over.get("service_days", k["service_days"])), "to": to}
	var o: Dictionary = e["overhaul"]
	var target := maxf(cond, float(o["target"]))
	if target - cond < float(o["min_gain"]) and not has_faults:
		return {"cost": 0.0, "days": 0.0, "to": cond, "reason": "already near new"}
	var mix := float(o["cost_floor_mix"])
	var ocost: float = float(over["overhaul_cr"]) if over.has("overhaul_cr") else maxf(float(o["min_cr"]), b * float(o["cost_frac"]) * (mix + (1.0 - mix) * (1.0 - cond)))
	return {"cost": ceilf(ocost * rate), "days": float(over.get("overhaul_days", k["overhaul_days"])), "to": target}


## Do the work on the ship (no payment): restore condition, clear faults.
static func apply_work(ship: Dictionary, slot: String, level: String, data) -> void:
	var e := econ(data)
	var cond := condition(ship, slot)
	if level == "service":
		var s: Dictionary = e["service"]
		restore(ship, slot, float(s["restore"]), float(s["cap"]))
	else:
		restore(ship, slot, 1.0, float(e["overhaul"]["target"]))
	if ship.has("warned") and cond < condition(ship, slot):
		ship["warned"].erase(slot)
	clear_faults(ship, slot)


## {labour_cr, days} to fit `module_id` at a yard.
static func refit_quote(module_id: String, place: String, data) -> Dictionary:
	var e := econ(data)
	var over: Dictionary = e["module_overrides"].get(module_id, {})
	var k := _kind(e, String(data.modules[module_id].get("kind", "")))
	return {
		"labour_cr": ceilf(float(over.get("labour_cr", k["labour_cr"])) * float(yard_rates(place, data)["labour"])),
		"days": float(over.get("refit_days", k["days"])),
	}


## Days a batch of jobs takes: the longest, or the total over the yard's crews.
static func batch_days(days: Array, data) -> float:
	var longest := 0.0
	var total := 0.0
	for d in days:
		longest = maxf(longest, float(d))
		total += float(d)
	return maxf(longest, total / maxf(float(econ(data)["refit"]["crew_parallel"]), 1.0))


## A fresh stock hull as the start of a game, or the Commons' replacement, would be:
## the part-worn second-hand state the game begins with.
static func make_worn(ship: Dictionary, data) -> void:
	var st: Dictionary = econ(data)["start"]
	ship["wear"] = {}
	ship["use"] = {}
	ship["faults"] = {}
	for slot in ship["modules"]:
		var kind := kind_of(ship, slot, data)
		ship["wear"][slot] = float(st["wear"].get(kind, 0.0))
		ship["use"][slot] = {"h": float(st["age_days"]) * 24.0}
