## Markets: production, consumption, recipes, background traffic, and player trades.
extends "res://sim/systems/system.gd"

const Market := preload("res://sim/market.gd")
const ShipStats := preload("res://sim/ship_stats.gd")


func setup(owner) -> void:
	super.setup(owner)
	owner.register("buy", _buy)
	owner.register("sell", _sell)
	owner.register("refuel", _refuel)


func start_game() -> void:
	var s = sim().state
	s.markets = {}
	for place in sim().data.places:
		var stocks := {}
		for good in sim().data.places[place].get("market", {}):
			stocks[good] = Market.target(sim().data, place, good)
		s.markets[place] = stocks
	s.economy_t = s.time_s


func tick(_game_dt: float) -> void:
	var s = sim().state
	var step := float(sim().data.balance["economy"]["step_hours"]) * 3600.0
	while s.economy_t + step <= s.time_s:
		_integrate(step / 86400.0)
		s.economy_t += step


func _integrate(days: float) -> void:
	var e: Dictionary = sim().data.balance["economy"]
	var relax := float(e["relaxation_per_day"]) * days
	var cap_mult := float(e["max_stock_mult"])
	for place in sim().data.places:
		var p: Dictionary = sim().data.places[place]
		var stock: Dictionary = sim().state.markets[place]
		for good in p.get("produces", {}):
			stock[good] += float(p["produces"][good]) * days
		for good in p.get("consumes", {}):
			stock[good] = maxf(0.0, stock[good] - float(p["consumes"][good]) * days)
		for recipe in p.get("recipes", []):
			var run := 1.0
			for good in recipe["inputs"]:
				var need := float(recipe["inputs"][good]) * days
				run = minf(run, stock[good] / need if need > 0.0 else 1.0)
			for good in recipe["inputs"]:
				stock[good] -= float(recipe["inputs"][good]) * days * run
			for good in recipe["outputs"]:
				stock[good] += float(recipe["outputs"][good]) * days * run
		for good in stock:
			var target := Market.target(sim().data, place, good)
			stock[good] = clampf(stock[good] + (target - stock[good]) * minf(relax, 1.0), 0.0, target * cap_mult)


func _docked_market(command: Dictionary) -> String:
	var loc: Dictionary = sim().state.location
	if loc.get("status") != "docked":
		return "not docked"
	if not Market.trades(sim().data, loc["place"], command.get("good", "")):
		return "%s is not traded here" % command.get("good", "?")
	if float(command.get("tonnes", 0.0)) <= 0.0:
		return "nothing to trade"
	return ""


func _buy(command: Dictionary) -> String:
	var error := _docked_market(command)
	if error != "":
		return error
	var s = sim().state
	var place: String = s.location["place"]
	var good: String = command["good"]
	var tonnes := float(command["tonnes"])
	if tonnes > Market.stock(s, place, good) + 1e-9:
		return "only %.1f t in stock" % Market.stock(s, place, good)
	if ShipStats.cargo_t(s.ship) + tonnes > ShipStats.cargo_capacity_t(s.ship, sim().data) + 1e-9:
		return "not enough cargo space"
	var cost := Market.buy_price(s, sim().data, place, good, tonnes) * tonnes
	if cost > s.credits + 1e-6:
		return "not enough credits"
	s.credits -= cost
	s.markets[place][good] -= tonnes
	s.ship["cargo"][good] = float(s.ship["cargo"].get(good, 0.0)) + tonnes
	s.ship["cargo_paid"][good] = float(s.ship["cargo_paid"].get(good, 0.0)) + cost
	sim().emit("traded", {"place": place, "good": good, "tonnes": tonnes, "credits": -cost})
	return ""


func _sell(command: Dictionary) -> String:
	var error := _docked_market(command)
	if error != "":
		return error
	var s = sim().state
	var place: String = s.location["place"]
	var good: String = command["good"]
	var tonnes := float(command["tonnes"])
	var held := float(s.ship["cargo"].get(good, 0.0))
	if tonnes > held + 1e-9:
		return "only %.1f t aboard" % held
	var income := Market.sell_price(s, sim().data, place, good, tonnes) * tonnes
	var paid := float(s.ship["cargo_paid"].get(good, 0.0)) * (tonnes / held)
	s.credits += income
	s.markets[place][good] += tonnes
	s.ship["cargo"][good] = held - tonnes
	s.ship["cargo_paid"][good] = float(s.ship["cargo_paid"].get(good, 0.0)) - paid
	if s.ship["cargo"][good] <= 1e-9:
		s.ship["cargo"].erase(good)
		s.ship["cargo_paid"].erase(good)
	s.stats["trade_profit"] += income - paid
	sim().emit("traded", {"place": place, "good": good, "tonnes": tonnes, "credits": income, "profit": income - paid})
	return ""


## {tonnes} or {fill: true}. Buys propellant from the local market into the tanks.
func _refuel(command: Dictionary) -> String:
	var s = sim().state
	if s.location.get("status") != "docked":
		return "not docked"
	var place: String = s.location["place"]
	if not "refuel" in sim().data.places[place].get("services", []):
		return "no refuelling here"
	var space := ShipStats.fuel_capacity_t(s.ship, sim().data) - float(s.ship["fuel_t"])
	var tonnes := space if command.get("fill", false) else minf(float(command.get("tonnes", 0.0)), space)
	tonnes = minf(tonnes, Market.stock(s, place, "propellant"))
	var price := Market.buy_price(s, sim().data, place, "propellant", tonnes)
	tonnes = minf(tonnes, s.credits / price)
	if tonnes <= 1e-6:
		return "tanks full" if space <= 1e-6 else "cannot refuel"
	s.credits -= price * tonnes
	s.markets[place]["propellant"] -= tonnes
	s.ship["fuel_t"] += tonnes
	sim().emit("refuelled", {"place": place, "tonnes": tonnes, "credits": -price * tonnes})
	return ""
