## Courier contracts and reputation (data/contracts.json, helpers in sim/contracts.gd).
##
## Each port keeps a board of offers, refreshed while you are docked there (boards
## elsewhere wait until you visit, which keeps long time compression cheap). Taking a
## job puts its parcel or passengers aboard (or, for a pickup, sends you to collect
## first); docking at the destination delivers it. On time pays in full and builds
## standing with the client's operator; late pays part and costs standing; far too
## late, or abandoned, it fails. Known pilots are approached with better jobs when
## they dock, and some jobs are only heard of through rumours (tip_system.gd).
extends "res://sim/systems/system.gd"

const Badges := preload("res://sim/badges.gd")
const Contracts := preload("res://sim/contracts.gd")
const ShipStats := preload("res://sim/ship_stats.gd")
const Favours := preload("res://sim/favours.gd")
const Fitness := preload("res://sim/fitness.gd")

const DAY := 86400.0
const KEEP_HISTORY := 30

var _rng := RandomNumberGenerator.new()


func setup(owner) -> void:
	super.setup(owner)
	owner.register("accept_contract", _accept)
	owner.register("abandon_contract", _abandon)


func start_game() -> void:
	var s = sim().state
	s.contracts = {"board": {}, "next_t": {}, "active": [], "history": [], "seq": 0, "last_dock": ""}
	s.reputation = {}
	s.ship["parcels_t"] = 0.0
	s.ship["cabin_t"] = 0.0
	s.ship["passengers"] = 0
	_on_docked()


func tick(_game_dt: float) -> void:
	var s = sim().state
	if s.contracts.is_empty():
		# A save from before contracts: open the books now.
		s.contracts = {"board": {}, "next_t": {}, "active": [], "history": [], "seq": 0, "last_dock": ""}
	var c: Dictionary = s.contracts
	if s.location.get("status") == "docked":
		if c["last_dock"] != s.location["place"]:
			_on_docked()
		elif s.time_s >= float(c["next_t"].get(s.location["place"], 0.0)) and not sim().data.places[s.location["place"]].has("foot_of"):
			_with_rng(func(): _refresh_board(s.location["place"]))
	else:
		c["last_dock"] = ""
	_check_failures()


func _with_rng(f: Callable) -> void:
	var s = sim().state
	_rng.seed = hash(s.seed) ^ 0xC0DE
	_rng.state = s.rng_state
	f.call()
	s.rng_state = _rng.state


## Arrived and docked: collect pickups, deliver, refresh the board, maybe an approach.
func _on_docked() -> void:
	var s = sim().state
	var place: String = s.location.get("place", "")
	if s.location.get("status") != "docked" or place == "":
		return
	s.contracts["last_dock"] = place
	for job in s.contracts["active"].duplicate():
		if job["state"] == "collect" and job["pickup"] == place:
			_collect(job)
		elif job["state"] == "carried" and job["to"] == place:
			_deliver(job)
	if sim().data.places[place].has("foot_of"):
		return
	_with_rng(func():
		_refresh_board(place)
		_maybe_approach(place))


func _refresh_board(place: String) -> void:
	var s = sim().state
	var data = sim().data
	var board: Array = s.contracts["board"].get(place, [])
	board = board.filter(func(o): return float(o["expires_t"]) > s.time_s)
	var cap := int(data.contracts["board"]["max_offers"])
	var tries := 0
	while board.filter(func(o): return o["channel"] == "board").size() < cap and tries < cap * 3:
		tries += 1
		var kind := Contracts.pick_kind(data, _rng, func(_k): return true)
		var offer := Contracts.make_offer(data, sim().ephemeris, s, _rng, place, kind, "board")
		if not offer.is_empty():
			board.append(_numbered(offer))
	s.contracts["board"][place] = board
	s.contracts["next_t"][place] = s.time_s + float(data.contracts["board"]["refresh_days"]) * DAY


func _maybe_approach(place: String) -> void:
	var s = sim().state
	var data = sim().data
	var ap: Dictionary = data.contracts["approach"]
	var client := Contracts.client_of(data, place)
	if Contracts.rep_of(s, client) < float(ap["min_rep"]):
		return
	var board: Array = s.contracts["board"].get(place, [])
	if board.any(func(o): return o["channel"] == "approach"):
		return
	# Renown (badges) gets you noticed: clients ask a well-known pilot by name more often.
	if _rng.randf() >= float(ap["chance"]) * Badges.chance_mult(s, data, "approach_per_point"):
		return
	var rep := Contracts.rep_of(s, client)
	var kind := Contracts.pick_kind(data, _rng, func(k): return float(data.contracts["kinds"][k].get("min_rep", 0.0)) <= rep)
	var offer := Contracts.make_offer(data, sim().ephemeris, s, _rng, place, kind, "approach")
	if offer.is_empty():
		return
	var openers: Array = ap["openers"]
	offer["opener"] = openers[_rng.randi() % openers.size()]
	board.append(_numbered(offer))
	s.contracts["board"][place] = board
	sim().emit("contract_approach", {"place": place, "offer": offer["id"], "client": client})


func _numbered(offer: Dictionary) -> Dictionary:
	var s = sim().state
	s.contracts["seq"] = int(s.contracts["seq"]) + 1
	offer["id"] = int(s.contracts["seq"])
	return offer


## Can this offer be seen (and taken) by the player now?
static func visible_to(state, data, offer: Dictionary) -> bool:
	return not offer.get("hidden", false) and Contracts.rep_of(state, offer["client"]) >= float(offer["min_rep"])


static func free_berths(state, data) -> int:
	return int(ShipStats.berths(state.ship, data)) - int(state.ship.get("passengers", 0))


## {id}: take a job from the board where you are docked.
func _accept(command: Dictionary) -> String:
	var s = sim().state
	var data = sim().data
	if s.location.get("status") != "docked":
		return "not docked"
	var place: String = s.location["place"]
	var board: Array = s.contracts["board"].get(place, [])
	var offer := {}
	for o in board:
		if int(o["id"]) == int(command.get("id", -1)):
			offer = o
	if offer.is_empty():
		return "that job is not on this board"
	if not visible_to(s, data, offer):
		return "they want someone they know for that one"
	if s.contracts["active"].size() >= int(data.contracts["board"]["max_active"]):
		return "you already have as many jobs as you can keep track of"
	if int(offer.get("passengers", 0)) > 0:
		var unfit := Fitness.passenger_job_block(s, data)
		if unfit != "":
			return unfit
	var job: Dictionary = offer.duplicate(true)
	job["accepted_t"] = s.time_s
	job["deadline_t"] = s.time_s + float(job["window_s"])
	job["state"] = "collect" if job["pickup"] != "" else "carried"
	if job["state"] == "carried":
		var why := _room_for(job)
		if why != "":
			return why
		_load(job)
	board.erase(offer)
	s.contracts["active"].append(job)
	sim().emit("contract_accepted", {"id": job["id"], "to": job["to"], "pickup": job["pickup"], "reward": job["reward"]})
	return ""


func _room_for(job: Dictionary) -> String:
	var s = sim().state
	var data = sim().data
	if int(job["passengers"]) > 0:
		if free_berths(s, data) < int(job["passengers"]):
			var yards := berth_yards(data)
			return "no berths: fit passenger berths (%d needed, %d free)%s" % [int(job["passengers"]), free_berths(s, data),
				(". Sold at " + ", ".join(yards)) if not yards.is_empty() else ""]
	elif in_cabin(job):
		return ""
	elif ShipStats.cargo_t(s.ship) + float(job["mass_t"]) > ShipStats.cargo_capacity_t(s.ship, data) + 1e-9:
		return "no room in the hold for %.2f t" % float(job["mass_t"])
	return ""


## Rides in the cabin, not the hold: passengers (in their berths) and anything small
## enough to carry by hand. Its mass still counts; it takes no hold space.
static func in_cabin(job: Dictionary) -> bool:
	return int(job.get("passengers", 0)) > 0 or bool(job.get("hand", false))


## The ports whose shipyards sell passenger berths (any module with berths), by name.
static func berth_yards(data) -> Array:
	var out := []
	for id in data.places:
		var place: Dictionary = data.places[id]
		if not "shipyard" in place.get("services", []):
			continue
		for m in place.get("shipyard_stock", []):
			if int(data.modules[m].get("berths", 0)) > 0:
				out.append(String(place["name"]))
				break
	return out


## Aboard: in the cabin (cabin_t: mass, no hold space) or the hold (parcels_t). The job
## remembers where it went, so it comes off the same way (jobs loaded by older builds
## went in the hold).
func _load(job: Dictionary) -> void:
	var s = sim().state
	var key := "cabin_t" if in_cabin(job) else "parcels_t"
	job["stowed"] = key
	s.ship[key] = float(s.ship.get(key, 0.0)) + float(job["mass_t"])
	s.ship["passengers"] = int(s.ship.get("passengers", 0)) + int(job["passengers"])


func _unload(job: Dictionary) -> void:
	var s = sim().state
	var key := String(job.get("stowed", "parcels_t"))
	s.ship[key] = maxf(0.0, float(s.ship.get(key, 0.0)) - float(job["mass_t"]))
	s.ship["passengers"] = maxi(0, int(s.ship.get("passengers", 0)) - int(job["passengers"]))


func _collect(job: Dictionary) -> void:
	var why := _room_for(job)
	if why != "":
		sim().emit("contract_no_room", {"id": job["id"], "reason": why})
		return
	_load(job)
	job["state"] = "carried"
	sim().emit("contract_collected", {"id": job["id"], "place": job["pickup"]})


func _deliver(job: Dictionary) -> void:
	var s = sim().state
	var data = sim().data
	var late: Dictionary = data.contracts["late"]
	var on_time: bool = s.time_s <= float(job["deadline_t"])
	var pay := float(job["reward"]) * (1.0 if on_time else float(late["pay_fraction"]))
	var rep := float(job["rep"]) if on_time else float(late["rep"])
	_unload(job)
	s.credits += pay
	# Part of the reward may be in kind (a voucher, a tune, a favour owed).
	var kind_pay := Favours.grant(s, data, job, 1.0 if on_time else float(late["pay_fraction"]))
	s.credits += float(kind_pay.get("credits", 0.0))
	_add_rep(job["client"], rep + float(kind_pay.get("rep", 0.0)))
	_retire(job, "delivered" if on_time else "late")
	sim().emit("contract_delivered", {"id": job["id"], "on_time": on_time, "credits": pay + float(kind_pay.get("credits", 0.0)), "rep": rep, "client": job["client"]})
	if not kind_pay.is_empty():
		sim().emit("favour_granted", {"id": job["id"], "form": kind_pay["form"], "text": kind_pay["text"], "client": job["client"]})


func _check_failures() -> void:
	var s = sim().state
	var late: Dictionary = sim().data.contracts["late"]
	for job in s.contracts["active"].duplicate():
		var window := float(job["deadline_t"]) - float(job["accepted_t"])
		if s.time_s > float(job["accepted_t"]) + window * float(late["fail_after"]):
			if job["state"] == "carried":
				_unload(job)
			_add_rep(job["client"], float(late["fail_rep"]))
			_retire(job, "failed")
			sim().emit("contract_failed", {"id": job["id"], "client": job["client"]})


## {id}: give up a job (whatever was aboard is put off at the next port).
func _abandon(command: Dictionary) -> String:
	var s = sim().state
	for job in s.contracts["active"]:
		if int(job["id"]) == int(command.get("id", -1)):
			if job["state"] == "carried":
				_unload(job)
			_add_rep(job["client"], float(sim().data.contracts["late"]["abandon_rep"]))
			_retire(job, "abandoned")
			sim().emit("contract_abandoned", {"id": job["id"], "client": job["client"]})
			return ""
	return "no such job"


func _retire(job: Dictionary, outcome: String) -> void:
	var s = sim().state
	s.contracts["active"].erase(job)
	job["outcome"] = outcome
	job["closed_t"] = s.time_s
	s.contracts["history"].append(job)
	while s.contracts["history"].size() > KEEP_HISTORY:
		s.contracts["history"].pop_front()
	var key := "contracts_" + outcome
	s.stats[key] = int(s.stats.get(key, 0)) + 1


func _add_rep(operator: String, amount: float) -> void:
	var s = sim().state
	var before := Contracts.rep_of(s, operator)
	s.reputation[operator] = maxf(-50.0, before + amount)
	var data = sim().data
	if Contracts.tier(data, before) != Contracts.tier(data, s.reputation[operator]):
		sim().emit("reputation_tier", {"operator": operator, "tier": Contracts.tier(data, s.reputation[operator]), "up": amount > 0.0})
