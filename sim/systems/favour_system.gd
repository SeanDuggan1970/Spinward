## Favours (data/favours.json, helpers in sim/favours.gd): vouchers earned from jobs paid
## in kind, and hitchhikers.
##
## Vouchers are held in state.favours and expire. Fuel and docking ones are used
## automatically when you next pay (economy and travel systems ask Favours); a repair
## voucher is spent with use_voucher at the client's yard.
##
## Hitchhikers: at some ports, while you are docked, someone asks for a ride. They need a
## free berth (the same berths contract passengers use), pay a small fare on arrival, and
## help by trade while aboard: an engineer mends small damage in flight, a navigator
## trims the propellant a burn takes, a pilot talks the tug fee down, a cook stretches
## life support, and a tinkerer may leave an engine tune. Their effects are read where
## they apply (ShipStats.crew_*, Favours.route_fuel, Favours.dock_mult); this system
## boards them, mends, speaks, and sets them down.
extends "res://sim/systems/system.gd"

const Favours := preload("res://sim/favours.gd")
const Fitness := preload("res://sim/fitness.gd")
const ShipStats := preload("res://sim/ship_stats.gd")

const DAY := 86400.0

var _rng := RandomNumberGenerator.new()


func setup(owner) -> void:
	super.setup(owner)
	owner.register("accept_hitchhiker", _accept)
	owner.register("use_voucher", _use_voucher)


func start_game() -> void:
	sim().state.favours = Favours.empty()


func tick(game_dt: float) -> void:
	var s = sim().state
	if sim().data.favours.is_empty():
		return
	Favours.ensure(s)
	_expire()
	_mend(game_dt)
	_midway()
	if s.location.get("status") == "docked":
		var place: String = s.location["place"]
		if s.favours["last_dock"] != place:
			s.favours["last_dock"] = place
			_set_down(place)
			if not sim().data.places[place].has("foot_of"):
				_with_rng(func(): _maybe_hiker(place))
	else:
		s.favours["last_dock"] = ""


func _with_rng(f: Callable) -> void:
	var s = sim().state
	_rng.seed = hash(s.seed) ^ 0xF4B0
	_rng.state = s.rng_state
	f.call()
	s.rng_state = _rng.state


func _expire() -> void:
	var s = sim().state
	for v in s.favours["vouchers"].duplicate():
		if float(v["expires_t"]) <= s.time_s:
			s.favours["vouchers"].erase(v)
			sim().emit("voucher_expired", {"id": v["id"], "form": v["form"], "operator": v["operator"]})
	for place in s.favours["waiting"].keys():
		s.favours["waiting"][place] = s.favours["waiting"][place].filter(func(h): return float(h["expires_t"]) > s.time_s)


## An engineer aboard mends damage (the worst module first) while the ship flies.
func _mend(dt: float) -> void:
	var s = sim().state
	var data = sim().data
	if not s.location.get("status") in ["transit", "approach"]:
		return
	var rate := ShipStats.crew_sum(s.ship, data, "heal_per_day")
	var damage: Dictionary = s.ship.get("damage", {})
	if rate <= 0.0 or damage.is_empty():
		return
	var left := rate * dt / DAY
	var slots := damage.keys().filter(func(k): return k != "keel" and float(damage[k]) > 0.0)
	slots.sort_custom(func(a, b): return float(damage[a]) > float(damage[b]) or (float(damage[a]) == float(damage[b]) and String(a) < String(b)))
	for slot in slots:
		if left <= 0.0:
			break
		var fix := minf(left, float(damage[slot]))
		damage[slot] = float(damage[slot]) - fix
		left -= fix
		if float(damage[slot]) <= 1e-6:
			damage.erase(slot)
			var who := _helper(s.ship, "heal_per_day")
			sim().emit("hitchhiker_helped", {"name": who, "text": "%s has fixed the %s." % [who, String(data.modules[s.ship["modules"][slot]]["name"]).to_lower()]})


func _helper(ship: Dictionary, key: String) -> String:
	var trades: Dictionary = sim().data.favours["hitchhikers"]["trades"]
	for h in ship.get("hikers", []):
		if float(trades[h["trade"]].get(key, 0.0)) > 0.0:
			return h["name"]
	return "Someone aboard"


## Halfway through a flight, whoever is aboard has something to say.
func _midway() -> void:
	var s = sim().state
	var loc: Dictionary = s.location
	if loc.get("status") != "transit":
		return
	var span := float(loc["arrive_t"]) - float(loc["depart_t"])
	if span <= 0.0 or (s.time_s - float(loc["depart_t"])) / span < 0.5:
		return
	for h in s.ship.get("hikers", []):
		if not h["mid_sent"]:
			h["mid_sent"] = true
			sim().emit("hitchhiker_line", {"name": h["name"], "trade": h["trade"], "text": h["lines"]["mid"]})


## Docked: hitchhikers whose stop this is (or who have been aboard long enough) get off.
func _set_down(place: String) -> void:
	var s = sim().state
	var data = sim().data
	var patience := float(data.favours["hitchhikers"]["patience_days"]) * DAY
	# A strict port will not clear passengers through for a ship with no valid Warrant of
	# Fitness (the rule contract passengers meet in the travel system): hitchhikers go
	# ashore here, with no fare.
	var refused: bool = Fitness.dock_terms(s, data, place)["refuse_passengers"]
	for h in s.ship.get("hikers", []).duplicate():
		if h["to"] != place and s.time_s - float(h["boarded_t"]) < patience and not refused:
			continue
		s.ship["hikers"].erase(h)
		s.ship["passengers"] = maxi(0, int(s.ship.get("passengers", 0)) - 1)
		s.ship["cabin_t"] = maxf(0.0, float(s.ship.get("cabin_t", 0.0)) - float(data.favours["hitchhikers"]["mass_t"]))
		var fare := 0.0 if refused else float(h["fare"])
		s.credits += fare
		if refused:
			sim().emit("hitchhiker_refused", {"name": h["name"], "place": place, "text": "%s is not cleared through here: the ship has no valid Warrant of Fitness." % h["name"]})
		var tune := ""
		if not refused and h["gift"] != "" and Favours.install_tune(s.ship, data, h["gift"], "%s, a tinkerer you gave a ride" % h["name"], s.time_s) == "":
			tune = h["gift"]
		sim().emit("hitchhiker_left", {"name": h["name"], "trade": h["trade"], "place": place, "text": h["lines"]["leave"], "fare": fare, "tune": tune})


func _maybe_hiker(place: String) -> void:
	var s = sim().state
	var data = sim().data
	var cfg: Dictionary = data.favours["hitchhikers"]
	if s.time_s < float(s.favours["next_t"].get(place, 0.0)):
		return
	s.favours["next_t"][place] = s.time_s + float(cfg["cooldown_days"]) * DAY
	if _rng.randf() >= float(cfg["chance"]):
		return
	var waiting: Array = s.favours["waiting"].get(place, [])
	if waiting.size() >= int(cfg["max_waiting"]):
		return
	var h := Favours.make_hiker(data, s, _rng, place)
	waiting.append(h)
	s.favours["waiting"][place] = waiting
	sim().emit("hitchhiker_asks", {"place": place, "id": h["id"], "name": h["name"], "trade": h["trade"]})


## {id}: take a hitchhiker waiting at this port aboard. They need a free berth.
func _accept(command: Dictionary) -> String:
	var s = sim().state
	var data = sim().data
	if s.location.get("status") != "docked":
		return "not docked"
	Favours.ensure(s)
	var place: String = s.location["place"]
	var waiting: Array = s.favours["waiting"].get(place, [])
	var h := {}
	for w in waiting:
		if int(w["id"]) == int(command.get("id", -1)):
			h = w
	if h.is_empty():
		return "nobody here is asking for a ride"
	var cfg: Dictionary = data.favours["hitchhikers"]
	# A hitchhiker sits in a passenger berth like any passenger, so the same rule holds:
	# no ride without a valid Warrant of Fitness (a pilot who is unfit says so).
	var unfit := Fitness.passenger_job_block(s, data)
	if unfit != "":
		return unfit
	if s.ship.get("hikers", []).size() >= int(cfg["max_aboard"]):
		return "you already have as many hitchhikers as the galley can feed"
	if Favours.free_berths(s, data) < 1:
		return "no berths: fit passenger berths (1 needed, %d free)" % Favours.free_berths(s, data)
	waiting.erase(h)
	h["boarded_t"] = s.time_s
	if not s.ship.has("hikers"):
		s.ship["hikers"] = []
	s.ship["hikers"].append(h)
	s.ship["passengers"] = int(s.ship.get("passengers", 0)) + 1
	s.ship["cabin_t"] = float(s.ship.get("cabin_t", 0.0)) + float(cfg["mass_t"])
	sim().emit("hitchhiker_boarded", {"id": h["id"], "name": h["name"], "trade": h["trade"], "to": h["to"], "text": h["lines"]["board"]})
	return ""


## {id}: spend a repair voucher at one of its operator's yards.
func _use_voucher(command: Dictionary) -> String:
	var s = sim().state
	var data = sim().data
	if s.location.get("status") != "docked":
		return "not docked"
	Favours.ensure(s)
	var v := {}
	for x in s.favours["vouchers"]:
		if int(x["id"]) == int(command.get("id", -1)) and x["form"] == "yard":
			v = x
	if v.is_empty():
		return "no such voucher"
	var place: String = s.location["place"]
	if Favours.operator_of(data, place) != v["operator"] or not "shipyard" in data.places[place].get("services", []):
		return "that voucher is good at %s yards: %s" % [v["operator"], ", ".join(Favours.yard_names(data, v["operator"]))]
	var spent := Favours.repair_service(s, data, float(v["value_cr"]))
	if spent <= 0.0:
		return "nothing to repair"
	v["value_cr"] = float(v["value_cr"]) - spent
	if float(v["value_cr"]) < 1.0:
		s.favours["vouchers"].erase(v)
	sim().emit("voucher_used", {"id": v["id"], "spent": spent, "left": maxf(0.0, float(v["value_cr"])), "place": place})
	return ""
