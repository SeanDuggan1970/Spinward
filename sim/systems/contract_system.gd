## Courier contracts and reputation (data/contracts.json, helpers in sim/contracts.gd).
##
## Each port keeps a board of offers, refreshed while you are docked there (boards
## elsewhere wait until you visit, which keeps long time compression cheap). Taking a
## job puts its parcel or passengers aboard (or, for a pickup, sends you to collect
## first); docking at the destination delivers it. On time pays in full and builds
## standing with the client's operator; late pays part and costs standing; far too
## late, or abandoned, it fails. Known pilots are approached with better jobs when
## they dock, and some jobs are only heard of through rumours (tip_system.gd).
##
## Satellites (roadmap step 5) ride in the lander's payload carrier and are released
## near their orbit (release_satellite); they stay in the world (state.sites.satellites).
## Secret work (step 7, contracts.covert) comes as approaches once you are Reliable
## with anyone: covert deliveries, listening devices (plant_device), spy satellites,
## and drop-offs and extractions at sites with the lander. Each is hidden from a
## watcher: its ports seeing you build suspicion (state.detection.seen_by, from the
## detection system), and you are caught at the limit or docking at its port with the
## work aboard. Caught: fined, standing lost, an offence; enough offences and the ship
## is impounded until you pay (pay_impound).
extends "res://sim/systems/system.gd"

const Badges := preload("res://sim/badges.gd")
const Contracts := preload("res://sim/contracts.gd")
const ShipStats := preload("res://sim/ship_stats.gd")
const Favours := preload("res://sim/favours.gd")
const Fitness := preload("res://sim/fitness.gd")
const Navigation := preload("res://sim/navigation.gd")
const PodSystem := preload("res://sim/systems/pod_system.gd")
const V := preload("res://sim/v3.gd")

const DAY := 86400.0
const KEEP_HISTORY := 30

var _rng := RandomNumberGenerator.new()


func setup(owner) -> void:
	super.setup(owner)
	owner.register("accept_contract", _accept)
	owner.register("abandon_contract", _abandon)
	owner.register("release_satellite", _release)
	owner.register("plant_device", _plant)
	owner.register("pay_impound", _pay_impound)


func start_game() -> void:
	var s = sim().state
	s.contracts = {"board": {}, "next_t": {}, "active": [], "history": [], "seq": 0, "last_dock": ""}
	s.reputation = {}
	s.ship["parcels_t"] = 0.0
	s.ship["cabin_t"] = 0.0
	s.ship["passengers"] = 0
	_on_docked()


func tick(game_dt: float) -> void:
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
	if s.location.get("status") == "on_site":
		if c.get("last_site", "") != s.location["place"]:
			_on_site()
	else:
		c["last_site"] = ""
	_watchers(game_dt)
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
	# Customs: docking at a watcher's port with its secret work aboard.
	for job in s.contracts["active"].duplicate():
		if job.get("covert", false) and job["state"] == "carried" and job.get("watcher", "") == Contracts.client_of(sim().data, place) and job["to"] != place:
			_caught(job, "customs at %s found it" % sim().data.places[place]["name"])
	for job in s.contracts["active"].duplicate():
		# Satellites and devices are released or planted, not handed over at the dock.
		if job.get("release", false) or job.get("plant", false):
			continue
		if job["state"] == "collect" and job["pickup"] == place:
			_collect(job)
		elif job["state"] == "carried" and job["to"] == place:
			_deliver(job)
	if sim().data.places[place].has("foot_of"):
		return
	_with_rng(func():
		_refresh_board(place)
		_maybe_approach(place))


## Arrived on site: drop people off, or collect them for the lander's trip home.
func _on_site() -> void:
	var s = sim().state
	var place: String = s.location["place"]
	s.contracts["last_site"] = place
	for job in s.contracts["active"].duplicate():
		if job["state"] == "collect" and job["pickup"] == place:
			_collect(job)
		elif job["state"] == "carried" and job["to"] == place and not (job.get("release", false) or job.get("plant", false)):
			_deliver(job)


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
	# Once you are Reliable with anyone, some of the quiet words are about secret work.
	var covert: bool = Contracts.covert_unlocked(s, data) and _rng.randf() < float(data.contracts["covert"]["chance"])
	var kind := Contracts.pick_kind(data, _rng, func(k): return float(data.contracts["kinds"][k].get("min_rep", 0.0)) <= rep, covert)
	if kind == "":
		return
	var offer := Contracts.make_offer(data, sim().ephemeris, s, _rng, place, kind, "approach")
	if offer.is_empty():
		return
	var openers: Array = data.contracts["covert"]["openers"] if covert else ap["openers"]
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
	if int(offer.get("passengers", 0)) > 0 and not offer.get("covert", false):
		var unfit := Fitness.passenger_job_block(s, data)
		if unfit != "":
			return unfit
	if offer.get("lander", false) and not PodSystem.has_mount(s.ship, data):
		return "that needs a lander: fit a lander bay"
	var job: Dictionary = offer.duplicate(true)
	# A drop or extraction at a site tells you where the site is.
	for p in [job["to"], job["pickup"]]:
		if data.sites.has(p) and not p in s.sites.get("known", []):
			if not s.sites.has("known"):
				s.sites["known"] = []
			s.sites["known"].append(p)
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
	if job.get("payload", false):
		if payload_room_t(s, data) + 1e-9 < float(job["mass_t"]):
			return "no room in a payload carrier: fit a lander bay and a payload carrier pod (%.1f t free)" % payload_room_t(s, data)
		return ""
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


## Room left in the lander's payload carrier (tonnes).
static func payload_room_t(state, data) -> float:
	return ShipStats.payload_capacity_t(state.ship, data) - float(state.ship.get("payload_load_t", 0.0))


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
	var key := "payload_load_t" if job.get("payload", false) else ("cabin_t" if in_cabin(job) else "parcels_t")
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


# --- satellites and secret work ------------------------------------------------------

## The ship's position now (sim frame, metres), in transit or at a place.
func _ship_at() -> Array:
	var s = sim().state
	var eph = sim().ephemeris
	var loc: Dictionary = s.location
	if loc.get("status") == "transit" and loc.has("frame"):
		return V.add(eph.position(loc["frame"], s.time_s), Navigation.transit_position(loc, s.time_s))
	return eph.position(loc.get("place", ""), s.time_s)


func _job(id) -> Dictionary:
	for job in sim().state.contracts["active"]:
		if int(job["id"]) == int(id):
			return job
	return {}


## Why a satellite or device can't go in here and now ("" if it can). Ordinary
## satellites go anywhere within release_m of their orbit; anything aimed at a
## watched port goes in on a long drift from within plant_m, coasting, dark and
## unseen by its watcher.
func release_block(job: Dictionary) -> String:
	var s = sim().state
	var data = sim().data
	var cfg: Dictionary = data.contracts["covert"]
	if job.is_empty() or job["state"] != "carried":
		return "no such job aboard"
	if not s.location.get("status") in ["transit", "docked", "on_site"]:
		return "not from here"
	var d := V.distance(_ship_at(), sim().ephemeris.position(job["to"], s.time_s))
	var reach := float(cfg["plant_m"]) if job.get("watched", false) or job.get("plant", false) else float(cfg["release_m"])
	if d > reach:
		return "too far from %s (%s km; within %s km)" % [data.locations[job["to"]]["name"], _km(d), _km(reach)]
	if job.get("watched", false) or job.get("plant", false):
		var loc: Dictionary = s.location
		if loc.get("status") != "transit":
			return "not from a berth: it has to go in unseen, under way"
		if V.length(Navigation.transit_accel(loc, s.time_s)) > 1e-6:
			return "not with the drive lit: they'd see it go"
		if not bool(s.detection.get("dark", false)):
			return "run dark first: transponder and lights off"
		for p in s.detection.get("seen_by", []):
			if Contracts.client_of(data, p) == job.get("watcher", ""):
				return "%s can see us: wait until we're out of its sight" % data.places[p]["name"]
	return ""


static func _km(m: float) -> String:
	return "%d" % int(round(m / 1000.0))


## {id}: release a satellite from the payload carrier near its orbit.
func _release(command: Dictionary) -> String:
	var job := _job(command.get("id", -1))
	if job.is_empty() or not job.get("release", false):
		return "no satellite job like that"
	var why := release_block(job)
	if why != "":
		return why
	var s = sim().state
	if not s.sites.has("satellites"):
		s.sites["satellites"] = []
	s.sites["satellites"].append({"name": job["item"], "client": job["client"], "place": job["to"], "t": s.time_s, "covert": job.get("covert", false)})
	while s.sites["satellites"].size() > MAX_SATELLITES:
		s.sites["satellites"].pop_front()
	sim().emit("satellite_released", {"id": job["id"], "name": job["item"], "place": job["to"], "covert": job.get("covert", false)})
	_deliver(job)
	return ""


## {id}: plant a listening device on its target, unseen.
func _plant(command: Dictionary) -> String:
	var job := _job(command.get("id", -1))
	if job.is_empty() or not job.get("plant", false):
		return "no device like that aboard"
	var why := release_block(job)
	if why != "":
		return why
	sim().emit("device_planted", {"id": job["id"], "place": job["to"]})
	_deliver(job)
	return ""


## Placed satellites kept in the world (the oldest drop off the list past this).
const MAX_SATELLITES := 60


## Secret work aboard in transit: each watcher's ports that can see us build
## suspicion; on a trip with no plan filed, slipping every port's sensors loses them.
func _watchers(dt: float) -> void:
	var s = sim().state
	var data = sim().data
	if s.location.get("status") != "transit" or dt <= 0.0:
		return
	var cfg: Dictionary = data.contracts["covert"]
	var seen: Array = s.detection.get("seen_by", [])
	var filed := bool(s.location.get("filed", true))
	for job in s.contracts["active"].duplicate():
		if not job.get("covert", false) or job["state"] != "carried":
			continue
		var watching: bool = seen.any(func(p): return Contracts.client_of(data, p) == job["watcher"])
		if watching:
			var rate := float(cfg["transponder_mult"]) if not bool(s.detection.get("dark", false)) else 1.0
			if filed:
				rate *= float(cfg["filed_mult"])
			var before := float(job.get("suspicion_s", 0.0))
			job["suspicion_s"] = before + dt * rate
			if before == 0.0:
				sim().emit("covert_watched", {"id": job["id"], "watcher": job["watcher"]})
			if float(job["suspicion_s"]) >= float(cfg["suspicion_s"]):
				_caught(job, "%s's traffic control put it together" % job["watcher"])
		elif not filed and seen.is_empty() and float(job.get("suspicion_s", 0.0)) > 0.0:
			job["suspicion_s"] = 0.0
			sim().emit("covert_lost_them", {"id": job["id"], "watcher": job["watcher"]})


## Caught with secret work: it fails, the fine and the standing, and an offence.
func _caught(job: Dictionary, how: String) -> void:
	var s = sim().state
	var cfg: Dictionary = sim().data.contracts["covert"]
	if job["state"] == "carried":
		_unload(job)
	s.credits -= float(cfg["caught_fine_cr"])
	_add_rep(job["watcher"], float(cfg["caught_rep"]))
	_add_rep(job["client"], float(cfg["client_rep"]))
	_retire(job, "caught")
	var offences := int(s.detection.get("offences", 0)) + 1
	s.detection["offences"] = offences
	var impound := offences >= int(cfg["impound_after"])
	if impound:
		s.detection["impound_cr"] = float(cfg["impound_fee_cr"])
	sim().emit("covert_caught", {"id": job["id"], "watcher": job["watcher"], "how": how, "credits": -float(cfg["caught_fine_cr"]), "impound": impound})


## Pay the fee and the ship is released.
func _pay_impound(_command: Dictionary) -> String:
	var s = sim().state
	var fee := float(s.detection.get("impound_cr", 0.0))
	if fee <= 0.0:
		return "your ship isn't held"
	if s.location.get("status") != "docked":
		return "only at a port"
	if s.credits < fee:
		return "the release fee is %d cr" % int(fee)
	s.credits -= fee
	s.detection.erase("impound_cr")
	sim().emit("impound_paid", {"credits": -fee})
	return ""
