## The stock second-hand hull a game starts with, and the one the Commons or an insurer
## hands a pilot who has lost theirs: a part-worn Mule with full tanks, a few months of
## Warrant of Fitness left, and nothing in the hold (data/ship_economy.json "start").
extends RefCounted

const ShipStats := preload("res://sim/ship_stats.gd")
const Condition := preload("res://sim/condition.gd")


static func make(data, ship_name: String, now_t: float) -> Dictionary:
	var start: Dictionary = data.balance["start"]
	var hull: Dictionary = data.ships[start["ship"]]
	var ship := {
		"name": ship_name, "hull": start["ship"], "modules": hull["modules"].duplicate(),
		"cargo": {}, "cargo_paid": {}, "fuel_t": 0.0, "damage": {},
	}
	Condition.make_worn(ship, data)
	ship["wof"] = {"valid_until_t": now_t + float(data.ship_economy["start"]["wof_days"]) * 86400.0, "result": "pass", "issues": [], "inspected_t": now_t}
	ship["fuel_t"] = ShipStats.fuel_capacity_t(ship, data)
	return ship
