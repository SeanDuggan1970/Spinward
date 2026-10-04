## The information economy: what the player knows about prices elsewhere, and the
## info brokers who sell tips about it (data/brokers.json).
##
## Knowledge: each time the player is docked, the local price board is recorded with
## its time. Elsewhere you only have that snapshot, and it goes stale.
## Tips: a broker's tip is true with the broker's (hidden) reliability, with some
## price noise; otherwise it is invented. When the player next docks at the tipped
## place, the tip is checked against the real board and the broker's track record
## with the player is updated. Randomness comes from the shared saved generator.
extends "res://sim/systems/system.gd"

const Market := preload("res://sim/market.gd")
const Contracts := preload("res://sim/contracts.gd")

const DAY := 86400.0
const KNOWLEDGE_REFRESH_S := 3600.0
const KEEP_TIPS := 40

var _rng := RandomNumberGenerator.new()


func setup(owner) -> void:
	super.setup(owner)
	owner.register("buy_tip", _buy_tip)


func start_game() -> void:
	var s = sim().state
	s.tips = []
	s.broker_record = {}
	s.knowledge = {}
	s.tip_seq = 0
	# The previous owner's logbook: every port's board, a few days old. A new pilot
	# starts with stale but useful guidance; from then on, knowledge has to be earned.
	var age := float(sim().data.brokers_meta["logbook_age_days"]) * DAY
	for place in sim().data.places:
		var prices := {}
		for good in sim().data.places[place].get("market", {}):
			prices[good] = [Market.buy_price(s, sim().data, place, good), Market.sell_price(s, sim().data, place, good)]
		s.knowledge[place] = {"t": s.time_s - age, "prices": prices, "source": "logbook"}
	_observe()


func tick(_game_dt: float) -> void:
	var s = sim().state
	if s.location.get("status") != "docked":
		_expire()
		return
	var place: String = s.location["place"]
	var known: Dictionary = s.knowledge.get(place, {})
	if known.is_empty() or s.time_s - float(known["t"]) >= KNOWLEDGE_REFRESH_S:
		_observe()
	for tip in s.tips:
		if tip["verified"] == null and tip["place"] == place:
			_verify(tip)
	_expire()


## Record the local price board as the player's knowledge of this place.
func _observe() -> void:
	var s = sim().state
	if s.location.get("status") != "docked":
		return
	var place: String = s.location["place"]
	var prices := {}
	for good in sim().data.places[place].get("market", {}):
		prices[good] = [Market.buy_price(s, sim().data, place, good), Market.sell_price(s, sim().data, place, good)]
	s.knowledge[place] = {"t": s.time_s, "prices": prices, "source": "seen"}


func _verify(tip: Dictionary) -> void:
	var s = sim().state
	var data = sim().data
	var tol := float(data.brokers_meta["verify_tolerance"])
	var held: bool
	var actual: float
	if tip["kind"] == "short":
		actual = Market.sell_price(s, data, tip["place"], tip["good"])
		held = actual >= float(tip["price"]) * tol
	else:
		actual = Market.buy_price(s, data, tip["place"], tip["good"])
		held = actual <= float(tip["price"]) / tol
	tip["verified"] = held
	tip["actual"] = actual
	var rec: Dictionary = s.broker_record.get(tip["broker"], {"good": 0, "bad": 0})
	rec["good" if held else "bad"] = int(rec["good" if held else "bad"]) + 1
	s.broker_record[tip["broker"]] = rec
	sim().emit("tip_verified", {"tip": tip["id"], "broker": tip["broker"], "held": held, "actual": actual})


func _expire() -> void:
	var s = sim().state
	for tip in s.tips:
		if tip["verified"] == null and not tip.get("expired", false) and s.time_s > float(tip["expires_t"]):
			tip["expired"] = true
	while s.tips.size() > KEEP_TIPS:
		s.tips.pop_front()


## {broker}. Must be docked where the broker works, and able to pay.
func _buy_tip(command: Dictionary) -> String:
	var s = sim().state
	var data = sim().data
	var id: String = command.get("broker", "")
	if not data.brokers.has(id):
		return "no such broker"
	var broker: Dictionary = data.brokers[id]
	if s.location.get("status") != "docked" or s.location["place"] != broker["place"]:
		return "%s is not here" % broker["name"]
	var price := float(broker["price"])
	if s.credits < price:
		return "not enough credits for a tip"
	_rng.seed = hash(s.seed) ^ 0x5EED
	_rng.state = s.rng_state
	var tip := _make_tip(id, broker)
	if not tip.is_empty():
		_maybe_rumour(tip)
		_maybe_site(tip)
	s.rng_state = _rng.state
	if tip.is_empty():
		return "%s has nothing worth selling right now" % broker["name"]
	s.credits -= price
	s.tip_seq += 1
	tip["id"] = s.tip_seq
	s.tips.append(tip)
	sim().emit("tip_bought", {"tip": tip["id"], "broker": id, "credits": -price})
	return ""


## And sometimes a broker knows where something is: a derelict, an unclaimed patch.
func _maybe_site(tip: Dictionary) -> void:
	var s = sim().state
	var data = sim().data
	if tip.has("rumour") or s.sites.is_empty() or _rng.randf() >= float(data.contracts.get("rumour", {}).get("site_chance", 0.0)):
		return
	var unknown: Array = data.sites.keys().filter(func(id): return data.sites[id].get("visibility", "known") == "rumour" and not id in s.sites["known"])
	if unknown.is_empty():
		return
	var site: String = unknown[_rng.randi() % unknown.size()]
	s.sites["known"].append(site)
	tip["site"] = site


## Brokers hear things besides prices: sometimes a tip comes with word of a job
## nobody has taken, at another port. The job is real, and only you have heard of it.
func _maybe_rumour(tip: Dictionary) -> void:
	var s = sim().state
	var data = sim().data
	var rc: Dictionary = data.contracts.get("rumour", {})
	if s.contracts.is_empty() or _rng.randf() >= float(rc.get("chance", 0.0)):
		return
	var here: String = s.location["place"]
	var ports: Array = data.places.keys().filter(func(p): return p != here and preload("res://sim/perks.gd").place_open(s, data, p))
	var place := ""
	var kind := ""
	var offer := {}
	for _try in 5:
		place = ports[_rng.randi() % ports.size()]
		var rep := Contracts.rep_of(s, Contracts.client_of(data, place))
		kind = Contracts.pick_kind(data, _rng, func(k): return k != "passenger" and float(data.contracts["kinds"][k].get("min_rep", 0.0)) <= maxf(rep, 0.0))
		if kind != "":
			offer = Contracts.make_offer(data, sim().ephemeris, s, _rng, place, kind, "rumour")
		if not offer.is_empty():
			break
	if offer.is_empty():
		return
	offer["hidden"] = false
	s.contracts["seq"] = int(s.contracts["seq"]) + 1
	offer["id"] = int(s.contracts["seq"])
	var board: Array = s.contracts["board"].get(place, [])
	board.append(offer)
	s.contracts["board"][place] = board
	tip["rumour"] = {"place": place, "offer": offer["id"], "kind": kind, "reward": offer["reward"], "window_s": offer["window_s"]}


func _make_tip(id: String, broker: Dictionary) -> Dictionary:
	var s = sim().state
	var data = sim().data
	var here: String = s.location["place"]
	var coverage: Array = data.places.keys() if broker["coverage"] is String else broker["coverage"]
	var places := coverage.filter(func(p): return p != here and data.places.has(p) and preload("res://sim/perks.gd").place_open(s, data, p))
	if places.is_empty():
		return {}
	var tip := {"broker": id, "t": s.time_s, "expires_t": s.time_s + float(data.brokers_meta["tip_ttl_days"]) * DAY,
		"verified": null, "template": _rng.randi_range(0, 99)}
	if _rng.randf() < float(broker["reliability"]):
		# A real opportunity: the strongest shortages and gluts the broker hears about.
		var options := []
		for place in places:
			for good in data.places[place]["market"]:
				var base := float(data.goods[good]["base_price"])
				var sell := Market.sell_price(s, data, place, good)
				var buy := Market.buy_price(s, data, place, good)
				options.append({"place": place, "good": good, "kind": "short", "score": sell / base, "price": sell})
				options.append({"place": place, "good": good, "kind": "glut", "score": base / buy, "price": buy})
		options.sort_custom(func(a, b): return a["score"] > b["score"])
		var pick: Dictionary = options[_rng.randi_range(0, mini(4, options.size()) - 1)]
		var noise := float(broker["noise"])
		tip.merge({"place": pick["place"], "good": pick["good"], "kind": pick["kind"], "truthful": true,
			"price": float(pick["price"]) * (1.0 + _rng.randf_range(-noise, noise))})
	else:
		# Stale or invented: plausible-sounding, and wrong.
		var place: String = places[_rng.randi_range(0, places.size() - 1)]
		var goods: Array = data.places[place]["market"].keys()
		var good: String = goods[_rng.randi_range(0, goods.size() - 1)]
		var base := float(data.goods[good]["base_price"])
		var short := _rng.randf() < 0.7
		tip.merge({"place": place, "good": good, "kind": "short" if short else "glut", "truthful": false,
			"price": base * (_rng.randf_range(1.5, 2.1) if short else _rng.randf_range(0.35, 0.6))})
	return tip
