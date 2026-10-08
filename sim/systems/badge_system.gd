## Badges: one-off marks for going where few go, or for standing a bar a round
## (data/badges.json, sim/badges.gd). Earning one adds renown, and sometimes standing
## with an operator; renown gets you noticed (hitchhikers, clients asking by name).
extends "res://sim/systems/system.gd"

const Badges := preload("res://sim/badges.gd")


func setup(owner) -> void:
	super.setup(owner)
	owner.register("buy_round", _buy_round)


func start_game() -> void:
	Badges.ensure(sim().state)


func tick(_game_dt: float) -> void:
	var s = sim().state
	Badges.ensure(s)
	if s.location.get("status") == "docked":
		var place: String = s.location["place"]
		if not place in s.badges["visited"]:
			s.badges["visited"].append(place)
			_award()


## Docked at a bar: stand everyone in it a drink.
func _buy_round(_command: Dictionary) -> String:
	var s = sim().state
	var data = sim().data
	if s.location.get("status") != "docked":
		return "not docked"
	var place: String = s.location["place"]
	var cost := Badges.round_cost(data, place)
	if cost < 0.0:
		return "there is no bar here"
	if s.credits < cost:
		return "a round is %d cr" % int(ceil(cost))
	Badges.ensure(s)
	s.credits -= cost
	s.badges["rounds"] = int(s.badges["rounds"]) + 1
	s.badges["rounds_at"][place] = int(s.badges["rounds_at"].get(place, 0)) + 1
	var op: String = data.places[place].get("operator", "")
	if op != "":
		s.reputation[op] = float(s.reputation.get(op, 0.0)) + float(data.badges.get("round_rep", 0.0))
	var bar: Dictionary = data.places[place]["bar"]
	sim().emit("round_bought", {"place": place, "bar": bar["name"], "patrons": int(bar["patrons"]), "credits": -cost})
	_award()
	return ""


## Award every badge newly earned.
func _award() -> void:
	var s = sim().state
	var all: Dictionary = sim().data.badges.get("badges", {})
	for id in all:
		if s.badges["earned"].has(id) or not Badges.met(s, all[id]):
			continue
		var badge: Dictionary = all[id]
		s.badges["earned"][id] = s.time_s
		for op in badge.get("rep", {}):
			s.reputation[op] = float(s.reputation.get(op, 0.0)) + float(badge["rep"][op])
		sim().emit("badge_earned", {"id": id, "name": badge["name"], "text": badge["text"], "renown": Badges.renown(s, sim().data)})
