## Owning more than one ship (helpers and rules in sim/fleet.gd). At a shipyard you can
## buy a hull it sells, step across to one of your ships laid up there (the one you
## were flying takes her berth), or sell one. Every laid-up ship pays a month's berth
## rent ahead; rent you cannot pay is owed, and after enough unpaid months the yard
## sells her to cover it and sends you what is left.
extends "res://sim/systems/system.gd"

const Fleet := preload("res://sim/fleet.gd")


func setup(owner) -> void:
	super.setup(owner)
	owner.register("buy_ship", _buy)
	owner.register("switch_ship", _switch)
	owner.register("sell_ship", _sell)


func start_game() -> void:
	sim().state.fleet = []


func tick(_game_dt: float) -> void:
	var s = sim().state
	var data = sim().data
	for entry in s.fleet.duplicate():
		var hull := String(entry["ship"]["hull"])
		while s.time_s >= float(entry["due_t"]):
			var due := Fleet.rent(data, hull, String(entry["place"]))
			entry["due_t"] = float(entry["due_t"]) + Fleet.month_s(data)
			if s.credits >= due:
				s.credits -= due
				sim().emit("berth_rent", {"ship": entry["ship"]["name"], "place": entry["place"], "credits": -due}, entry["due_t"] - Fleet.month_s(data))
			else:
				entry["owed_cr"] = float(entry.get("owed_cr", 0.0)) + due
				entry["unpaid"] = int(entry.get("unpaid", 0)) + 1
				sim().emit("berth_unpaid", {"ship": entry["ship"]["name"], "place": entry["place"], "owed": entry["owed_cr"], "months": entry["unpaid"]})
				if int(entry["unpaid"]) >= int(Fleet.cfg(data)["seize_after"]):
					_seize(entry)
					break
		# Settle what is owed as soon as there is money for it.
		var owed := float(entry.get("owed_cr", 0.0))
		if owed > 0.0 and s.credits >= owed and s.fleet.has(entry):
			s.credits -= owed
			entry["owed_cr"] = 0.0
			entry["unpaid"] = 0
			sim().emit("berth_rent", {"ship": entry["ship"]["name"], "place": entry["place"], "credits": -owed})


func _seize(entry: Dictionary) -> void:
	var s = sim().state
	var value := Fleet.sale_value(sim().data, entry["ship"])
	var back := maxf(0.0, value - float(entry["owed_cr"]))
	s.credits += back
	s.fleet.erase(entry)
	sim().emit("ship_seized", {"ship": entry["ship"]["name"], "place": entry["place"], "owed": entry["owed_cr"], "credits": back})


## Lay up the ship you are flying at this yard and charge her first month.
func _lay_up(ship: Dictionary) -> void:
	var s = sim().state
	var data = sim().data
	var place: String = s.location["place"]
	var first := Fleet.rent(data, String(ship["hull"]), place)
	s.credits -= first
	s.fleet.append({"ship": ship, "place": place, "since_t": s.time_s, "due_t": s.time_s + Fleet.month_s(data), "owed_cr": 0.0, "unpaid": 0})
	sim().emit("berth_rent", {"ship": ship["name"], "place": place, "credits": -first})


## {hull, name?, board?}: buy a hull this yard sells. She is laid up here (first month
## charged) unless you board her at once, when the ship you were flying takes the berth.
func _buy(command: Dictionary) -> String:
	var s = sim().state
	var data = sim().data
	if s.location.get("status") != "docked":
		return "not docked"
	var place: String = s.location["place"]
	var hull := String(command.get("hull", ""))
	if not hull in Fleet.hulls_sold(data, place):
		return "this yard does not sell that hull"
	if s.fleet.size() + 1 >= int(Fleet.cfg(data)["max_ships"]):
		return "you already own as many ships as you can look after (%d)" % int(Fleet.cfg(data)["max_ships"])
	var board := bool(command.get("board", false))
	if board:
		var why := Fleet.why_not_leave(s, data)
		if why != "":
			return why
	var cost := Fleet.price(data, hull)
	var berth := Fleet.rent(data, String(s.ship["hull"]) if board else hull, place)
	if s.credits + 1e-6 < cost + berth:
		return "not enough credits: %d cr needed with the first month's berth" % int(ceil(cost + berth))
	var ship_name := String(command.get("name", "")).strip_edges()
	if ship_name == "":
		ship_name = Fleet.fresh_name(s, data)
	var ship := Fleet.make_ship(data, hull, ship_name, s.time_s)
	s.credits -= cost
	sim().emit("ship_bought", {"ship": ship_name, "hull": hull, "place": place, "credits": -cost})
	if board:
		var old: Dictionary = s.ship
		_lay_up(old)
		_take(ship)
	else:
		_lay_up(ship)
	return ""


## {index}: step across to your ship berthed here; the one you were flying takes her berth.
func _switch(command: Dictionary) -> String:
	var s = sim().state
	var data = sim().data
	var why := Fleet.why_not_leave(s, data)
	if why != "":
		return why
	var i := int(command.get("index", -1))
	if i < 0 or i >= s.fleet.size() or s.fleet[i]["place"] != s.location["place"]:
		return "that ship is not berthed here"
	var entry: Dictionary = s.fleet[i]
	var owed := float(entry.get("owed_cr", 0.0))
	var berth := Fleet.rent(data, String(s.ship["hull"]), s.location["place"])
	if s.credits + 1e-6 < owed + berth:
		return "not enough credits: %d cr for her rent owed and a month's berth for the ship you leave" % int(ceil(owed + berth))
	s.credits -= owed
	s.fleet.remove_at(i)
	var old: Dictionary = s.ship
	_lay_up(old)
	_take(entry["ship"])
	return ""


func _take(ship: Dictionary) -> void:
	var s = sim().state
	var from := String(s.ship.get("name", ""))
	s.ship = ship
	# Her batteries were kept topped up on shore power.
	s.power = {}
	sim().emit("ship_switched", {"ship": ship["name"], "hull": ship["hull"], "from": from, "place": s.location["place"]})


## {index}: sell one of your ships berthed here. What she owes comes out of the price.
func _sell(command: Dictionary) -> String:
	var s = sim().state
	var data = sim().data
	if s.location.get("status") != "docked":
		return "not docked"
	var i := int(command.get("index", -1))
	if i < 0 or i >= s.fleet.size() or s.fleet[i]["place"] != s.location["place"]:
		return "that ship is not berthed here"
	var entry: Dictionary = s.fleet[i]
	var paid := Fleet.sale_value(data, entry["ship"]) - float(entry.get("owed_cr", 0.0))
	if s.credits + paid < -1e-6:
		return "she is worth less than the rent she owes: %d cr short" % int(ceil(-paid - s.credits))
	s.credits += paid
	s.fleet.remove_at(i)
	sim().emit("ship_sold", {"ship": entry["ship"]["name"], "hull": entry["ship"]["hull"], "place": entry["place"], "credits": paid})
	return ""
