## Markets: production, consumption, recipes, background traffic, and player trades.
extends "res://sim/systems/system.gd"

const Market := preload("res://sim/market.gd")
const Perks := preload("res://sim/perks.gd")
const ShipStats := preload("res://sim/ship_stats.gd")


func setup(owner) -> void:
	super.setup(owner)
	owner.register("buy", _buy)
	owner.register("sell", _sell)
	owner.register("refuel", _refuel)
	owner.register("emergency_refuel", _emergency_refuel)


func start_game() -> void:
	var s = sim().state
	s.markets = {}
	for place in sim().data.places:
		var stocks := {}
		for good in sim().data.places[place].get("market", {}):
			stocks[good] = Market.target(sim().data, place, good)
		s.markets[place] = stocks
	# Let surpluses and shortages develop before the player arrives, so day one has trades.
	var step := float(sim().data.balance["economy"]["step_hours"]) / 24.0
	for _i in int(float(sim().data.balance["economy"]["warmup_days"]) / step):
		_integrate(step)
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
		if not sim().state.markets.has(place):
			# A place added since this save was made: open its market at target.
			var fresh := {}
			for good in p.get("market", {}):
				fresh[good] = Market.target(sim().data, place, good)
			sim().state.markets[place] = fresh
		var stock: Dictionary = sim().state.markets[place]
		var mods: Dictionary = sim().state.place_mods.get(place, {})
		var produce_mult := float(mods.get("produces_mult", 1.0))
		var consume_mult := float(mods.get("consumes_mult", 1.0))
		for good in p.get("produces", {}):
			stock[good] += float(p["produces"][good]) * produce_mult * days
		for good in p.get("consumes", {}):
			stock[good] = maxf(0.0, stock[good] - float(p["consumes"][good]) * consume_mult * days)
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
	var cost := Market.buy_cost(s, sim().data, place, good, tonnes)
	if cost > s.credits + 1e-6:
		return "not enough credits"
	s.credits -= cost
	s.markets[place][good] -= tonnes
	var bought: Dictionary = s.stats.get("player_bought", {})
	var here_bought: Dictionary = bought.get(place, {})
	here_bought[good] = float(here_bought.get(good, 0.0)) + tonnes
	bought[place] = here_bought
	s.stats["player_bought"] = bought
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
	# Cumulative tonnage the player sold per place and good (projects credit the player from this).
	var sold: Dictionary = s.stats.get("player_sold", {})
	var here_sold: Dictionary = sold.get(place, {})
	here_sold[good] = float(here_sold.get(good, 0.0)) + tonnes
	sold[place] = here_sold
	s.stats["player_sold"] = sold
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
	# Exact cost of what can be afforded, priced on the tonnes actually bought, less any
	# backer's discount (fuel into the tanks cannot be resold).
	var mult := Perks.fuel_mult(s, place)
	tonnes = Market.affordable_tonnes(s, sim().data, place, "propellant", s.credits / maxf(mult, 0.01), tonnes)
	if tonnes <= 1e-6:
		return "tanks full" if space <= 1e-6 else "cannot refuel"
	var cost := Market.buy_cost(s, sim().data, place, "propellant", tonnes) * mult
	s.credits -= cost
	s.markets[place]["propellant"] -= tonnes
	s.ship["fuel_t"] += tonnes
	sim().emit("refuelled", {"place": place, "tonnes": tonnes, "credits": -cost})
	return ""


## Stranded or broke: a tanker drone brings propellant at a steep premium. Available
## where no fuel is sold, or where it is but you cannot afford a tonne. If you cannot
## pay, it still brings a rescue load on credit (your balance goes negative), so the
## game can never soft-lock; priced so planning ahead is always better.
static func emergency_available(state, data) -> bool:
	if not state.location.get("status") in ["docked", "on_site"]:
		return false
	var place: String = state.location["place"]
	if not "refuel" in data.locations[place].get("services", []):
		return true
	return state.credits < Market.buy_price(state, data, place, "propellant", 1.0)


func _emergency_refuel(command: Dictionary) -> String:
	var s = sim().state
	var data = sim().data
	if not s.location.get("status") in ["docked", "on_site"]:
		return "not docked"
	if not emergency_available(s, data):
		return "refuel normally here"
	var e: Dictionary = data.balance["economy"]
	var price := float(data.goods["propellant"]["base_price"]) * float(e["emergency_fuel_price_mult"])
	var space := ShipStats.fuel_capacity_t(s.ship, data) - float(s.ship["fuel_t"])
	var tonnes := minf(float(command.get("tonnes", space)), space)
	if tonnes <= 1e-6:
		return "tanks full"
	var on_credit := false
	if price * tonnes > s.credits:
		var affordable := maxf(0.0, s.credits) / price
		var rescue_t := float(e["emergency_rescue_t"])
		# Credit covers one rescue load: never once already in debt, never to top up a
		# tank that already holds a rescue load.
		var rescue := minf(tonnes, maxf(0.0, rescue_t - float(s.ship["fuel_t"]))) if s.credits >= 0.0 else 0.0
		on_credit = affordable < rescue
		tonnes = maxf(affordable, rescue)
		if tonnes <= 1e-6:
			return "no more credit: sell cargo or modules first"
	s.credits -= price * tonnes
	s.ship["fuel_t"] += tonnes
	sim().emit("refuelled", {"place": s.location["place"], "tonnes": tonnes, "credits": -price * tonnes, "emergency": true, "on_credit": on_credit})
	return ""
