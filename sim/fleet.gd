## Owning more than one ship (data/ship_economy.json "fleet"): what a yard sells and
## for how much, what a laid-up ship costs to keep in a berth, what she would fetch,
## and whether you can step across to her now. Pure helpers shared by the fleet
## system and the shipyard screen.
##
## The ship you fly is state.ship. The rest are in state.fleet, each laid up at the
## yard where you left her: {ship, place, since_t, due_t (next rent), owed_cr, unpaid
## (months behind)}. A ship keeps everything that is hers (fit, wear, Warrant of
## Fitness, fuel, trade cargo) while she waits.
extends RefCounted

const ShipStats := preload("res://sim/ship_stats.gd")
const Condition := preload("res://sim/condition.gd")

const DAY := 86400.0


static func cfg(data) -> Dictionary:
	return data.ship_economy["fleet"]


## The craft a hull counts as for contracts ("utility", "fast", "heavy"...).
static func class_of(data, hull: String) -> String:
	return String(cfg(data)["hulls"].get(hull, {}).get("class", "utility"))


static func class_name_of(data, craft: String) -> String:
	return String(cfg(data)["classes"].get(craft, craft))


## "a fast courier or a heavy freighter", for a contract's list of craft.
static func craft_words(data, crafts: Array) -> String:
	var names := []
	for c in crafts:
		names.append("a " + class_name_of(data, String(c)))
	return " or ".join(names)


## Does the ship you fly count as one of these craft?
static func is_craft(data, ship: Dictionary, crafts: Array) -> bool:
	return crafts.is_empty() or class_of(data, String(ship.get("hull", ""))) in crafts


## Hulls this yard sells, in the order the data lists them.
static func hulls_sold(data, place: String) -> Array:
	var out := []
	if not "shipyard" in data.places.get(place, {}).get("services", []):
		return out
	var hulls: Dictionary = cfg(data)["hulls"]
	for hull in hulls:
		var yards = hulls[hull].get("yards", "all")
		if yards is String and yards == "all" or yards is Array and place in yards:
			out.append(hull)
	return out


static func price(data, hull: String) -> float:
	return float(cfg(data)["hulls"][hull]["price_cr"])


## A month's berth at `place` for this hull.
static func rent(data, hull: String, place: String) -> float:
	var rates: Dictionary = Condition.yard_rates(place, data)
	var mult := float(cfg(data)["hulls"].get(hull, {}).get("berth_mult", 1.0))
	return float(cfg(data)["berth_month_cr"]) * mult * float(rates.get("berth", 1.0))


static func month_s(data) -> float:
	return float(cfg(data)["month_days"]) * DAY


## A sound second-hand example of a hull, as a yard sells it.
static func make_ship(data, hull: String, ship_name: String, now_t: float) -> Dictionary:
	var c := cfg(data)
	var ship := {
		"name": ship_name, "hull": hull, "modules": data.ships[hull]["modules"].duplicate(),
		"cargo": {}, "cargo_paid": {}, "fuel_t": 0.0, "damage": {},
		"parcels_t": 0.0, "cabin_t": 0.0, "passengers": 0,
		"wear": {}, "use": {}, "faults": {},
	}
	for slot in ship["modules"]:
		ship["wear"][slot] = float(c["bought_wear"])
		ship["use"][slot] = {"h": float(c["bought_age_days"]) * 24.0}
	var wof: Dictionary = data.ship_economy["wof"]
	ship["wof"] = {"valid_until_t": now_t + float(wof["valid_days"]) * DAY, "result": "pass", "issues": [], "inspected_t": now_t}
	ship["fuel_t"] = ShipStats.fuel_capacity_t(ship, data)
	return ship


## A name for a new ship that none of yours has yet.
static func fresh_name(state, data) -> String:
	var taken := [String(state.ship.get("name", ""))]
	for entry in state.fleet:
		taken.append(String(entry["ship"].get("name", "")))
	var names: Array = cfg(data)["names"]
	for n in names:
		if not n in taken:
			return n
	return "%s %d" % [names[0], state.fleet.size() + 2]


## What a yard pays for one of your ships: the hull's price by her mean condition and
## age, less keel damage, plus any module that differs from the stock fit.
static func sale_value(data, ship: Dictionary) -> float:
	var hull := String(ship.get("hull", ""))
	if not cfg(data)["hulls"].has(hull):
		return 0.0
	var age := 0.0
	var n := 0
	for slot in ship.get("modules", {}):
		age += Condition.age_days(ship, slot)
		n += 1
	age = age / maxf(1.0, float(n))
	var keel := clampf(float(ship.get("damage", {}).get("keel", 0.0)), 0.0, 1.0)
	var value := price(data, hull) * Condition.value_factor(Condition.mean_condition(ship), age, data) * float(cfg(data)["sell_fraction"]) * (1.0 - keel)
	var stock: Dictionary = data.ships[hull]["modules"]
	for slot in ship.get("modules", {}):
		if stock.get(slot, "") != ship["modules"][slot]:
			value += Condition.trade_in(ship, slot, data)
	return value


## Why you cannot step out of the ship you fly here and now ("" if you can): she has to
## be docked at a yard, free of the work and people aboard that belong to her.
static func why_not_leave(state, data) -> String:
	if state.location.get("status") != "docked":
		return "you can only change ships docked at a shipyard"
	var place: String = state.location["place"]
	if not "shipyard" in data.places[place].get("services", []):
		return "there is no shipyard here to berth her"
	if float(state.detection.get("impound_cr", 0.0)) > 0.0:
		return "your ship is impounded: pay the release fee first"
	for job in state.contracts.get("active", []):
		if job.get("state", "") == "carried":
			return "you have contract work aboard: deliver it or give it up first"
	if int(state.ship.get("passengers", 0)) > 0 or not state.ship.get("hikers", []).is_empty():
		return "you have people aboard: see them ashore first"
	return ""


## Your ships laid up at a place, as [index into state.fleet].
static func here(state, place: String) -> Array:
	var out := []
	for i in state.fleet.size():
		if state.fleet[i]["place"] == place:
			out.append(i)
	return out


## Rent a month from now for every ship laid up, at their yards.
static func monthly_rent(state, data) -> float:
	var total := 0.0
	for entry in state.fleet:
		total += rent(data, String(entry["ship"]["hull"]), String(entry["place"]))
	return total
