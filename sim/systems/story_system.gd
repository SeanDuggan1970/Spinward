## The story (data/story.json). Nothing happens until the pilot salvages the dead probe
## Hermes-7 and recovers its memory core. Whoever they give it to sets the road: sold
## to the Long View (Trojan Yards), the Reach (Hektor Reach) or the Sufficiency
## (Landauer Deep), or kept aboard until the pilot's co-pilot, bored through a year of
## hibernation, reads it and asks the Lanes. Each road runs its own beats to the Lacuna.
## The Sufficiency's own small arc (a delegate to Ceres) runs alongside.
##
## The core lives in state.story["core"]: {status: "aboard" | "sold" | "read", found_t,
## road, road_t, slept_s, sold_at}. The co-pilot's name is state.story["copilot"].
##
## Beats run in order. A beat waits for its conditions and its port, then fires: its
## message goes into the player's correspondence and its actions happen (a favour
## job on the local board, a site revealed, modules lent, standing, credits). It is
## done when its favour is delivered, a site activity is finished, or at once. A
## favour that fails or is abandoned is offered again at the next suitable dock.
extends "res://sim/systems/system.gd"

const Contracts := preload("res://sim/contracts.gd")
const Navigation := preload("res://sim/navigation.gd")
const TripEstimate := preload("res://sim/trip_estimate.gd")
const ShipStats := preload("res://sim/ship_stats.gd")
const SleepSystem := preload("res://sim/systems/sleep_system.gd")

const DAY := 86400.0


func setup(owner) -> void:
	super.setup(owner)
	owner.register("sell_core", _sell_core)
	owner.register("name_copilot", _name_copilot)


func start_game() -> void:
	sim().state.story = {"done": [], "fired": {}, "messages": [], "core": {}, "copilot": ""}


## The co-pilot's name, or the default before the pilot has given it one.
static func copilot_name(state, data) -> String:
	var n := String(state.story.get("copilot", ""))
	return n if n != "" else String(data.story["core"].get("copilot_default", "Co-pilot"))


## Where the core would sell now: the buyer here, or {} (not docked at a buyer, or no core).
static func core_buyer(state, data) -> Dictionary:
	if state.story.get("core", {}).get("status", "") != "aboard" or state.location.get("status") != "docked":
		return {}
	return data.story["core"]["buyers"].get(state.location["place"], {})


func _name_copilot(command: Dictionary) -> String:
	var n := String(command.get("name", "")).strip_edges().left(24)
	sim().state.story["copilot"] = n if n != "" else String(sim().data.story["core"].get("copilot_default", "Co-pilot"))
	sim().emit("copilot_named", {"name": sim().state.story["copilot"]})
	return ""


## Give the core to the minds of this port: their circle's road begins.
func _sell_core(_command: Dictionary) -> String:
	var s = sim().state
	var data = sim().data
	var buyer := core_buyer(s, data)
	if buyer.is_empty():
		return "nobody here wants it" if s.story.get("core", {}).get("status", "") == "aboard" else "you have nothing they want"
	var core: Dictionary = s.story["core"]
	core["status"] = "sold"
	core["sold_at"] = s.location["place"]
	_begin_road(String(buyer["road"]))
	s.credits += float(buyer["price"])
	for op in buyer.get("standing", {}):
		s.reputation[op] = float(s.reputation.get(op, 0.0)) + float(buyer["standing"][op])
	_letter(String(buyer.get("from", "")), String(buyer["message"]))
	sim().emit("core_sold", {"place": s.location["place"], "circle": buyer["circle"], "credits": float(buyer["price"]), "text": buyer["message"]})
	return ""


func _begin_road(road: String) -> void:
	var s = sim().state
	s.story["core"]["road"] = road
	s.story["core"]["road_t"] = s.time_s


## A letter in the correspondence, and the story event the view shows.
func _letter(from: String, text: String, beat: String = "") -> void:
	var s = sim().state
	var who := from.replace("{copilot}", copilot_name(s, sim().data))
	s.story["messages"].append({"t": s.time_s, "from": who, "text": text})
	sim().emit("story", {"beat": beat, "from": who, "text": text})


## The core: found when Hermes-7 is salvaged; read by a bored co-pilot after a year asleep.
func _core(game_dt: float) -> void:
	var s = sim().state
	var c: Dictionary = sim().data.story.get("core", {})
	if c.is_empty():
		return
	if not s.story.has("core"):
		s.story["core"] = {}
	var core: Dictionary = s.story["core"]
	if core.is_empty():
		if not s.sites.get("worked", {}).get(c["site"], []).has(c["activity"]):
			return
		s.story["core"] = {"status": "aboard", "found_t": s.time_s, "slept_s": 0.0}
		_letter(String(c["found_from"]), String(c["found_message"]))
		sim().emit("core_found", {})
		return
	if core["status"] == "aboard" and bool(s.sleep.get("active", false)):
		core["slept_s"] = float(core.get("slept_s", 0.0)) + game_dt
		if float(core["slept_s"]) >= float(c["lanes_sleep_days"]) * DAY:
			core["status"] = "read"
			_begin_road("lanes")
			_letter(String(c["found_from"]), String(c["read_message"]))
			sim().emit("core_read", {})


func tick(game_dt: float) -> void:
	var s = sim().state
	if s.story.is_empty():
		start_game()
	_core(game_dt)
	var data = sim().data
	# Beats move only in port or on site; world beats (the news of the roads) move
	# anywhere, even while the pilot sleeps.
	var here: bool = s.location.get("status") in ["docked", "on_site"]
	# Each arc ("arc", default the Long View) runs its own beats in order, side by side.
	var stalled := {}
	for beat in data.story.get("beats", []):
		var id: String = beat["id"]
		var arc: String = beat.get("arc", "long_view")
		if stalled.has(arc) or id in s.story["done"]:
			continue
		if not here and not beat.get("world", false):
			stalled[arc] = true
			continue
		if not s.story["fired"].has(id):
			if _ready_to_fire(beat):
				_fire(beat)
				# The news of the world moves on at once: the next beat may follow this tick.
				if beat.get("world", false) and _finished(beat):
					s.story["done"].append(id)
					sim().emit("story_beat_done", {"beat": id})
					continue
			stalled[arc] = true
			continue
		if _finished(beat):
			s.story["done"].append(id)
			sim().emit("story_beat_done", {"beat": id})
			continue
		stalled[arc] = true


func _ready_to_fire(beat: Dictionary) -> bool:
	var s = sim().state
	var at: String = beat.get("at", "any")
	var docked: bool = s.location.get("status") == "docked"
	var wants_board: bool = beat.get("actions", []).any(func(a): return a.has("offer"))
	if wants_board and not docked:
		return false
	if at != "any" and (not docked or s.location["place"] != at):
		return false
	var when: Dictionary = beat.get("when", {})
	var core: Dictionary = s.story.get("core", {})
	if when.has("road") and core.get("road", "") != when["road"]:
		return false
	if when.has("road_days") and (not core.has("road_t") or s.time_s - float(core["road_t"]) < float(when["road_days"]) * DAY):
		return false
	if bool(when.get("has_pod", false)) and SleepSystem.pod_of(s.ship, sim().data) == "":
		return false
	if int(s.stats.get("contracts_delivered", 0)) < int(when.get("delivered_on_time", 0)):
		return false
	if when.has("any_tier"):
		var best := -INF
		for op in s.reputation:
			best = maxf(best, float(s.reputation[op]))
		if best < float(when["any_tier"]):
			return false
	for b in when.get("beats", []):
		if not b in s.story["done"]:
			return false
	if when.has("site_worked") and s.sites.get("worked", {}).get(when["site_worked"], []).is_empty():
		return false
	return true


func _fire(beat: Dictionary) -> void:
	var s = sim().state
	var data = sim().data
	var record := {"t": s.time_s}
	# A world beat may be news only, with no letter.
	var has_letter: bool = beat.has("message")
	if has_letter:
		var who := String(beat.get("from", "")).replace("{copilot}", copilot_name(s, data))
		s.story["messages"].append({"t": s.time_s, "from": who, "text": beat["message"]})
	for action in beat.get("actions", []):
		if action.has("offer"):
			var offer := _favour(action["offer"], beat)
			if not offer.is_empty():
				record["offer"] = int(offer["id"])
		if action.has("reveal_site") and not action["reveal_site"] in s.sites.get("known", []):
			s.sites["known"].append(action["reveal_site"])
		if action.has("grant"):
			for slot in action["grant"]:
				if s.ship["modules"].has(slot):
					s.ship["modules"][slot] = action["grant"][slot]
			s.ship["fuel_t"] = ShipStats.fuel_capacity_t(s.ship, data)
		if action.has("standing"):
			for op in action["standing"]:
				s.reputation[op] = float(s.reputation.get(op, 0.0)) + float(action["standing"][op])
		if action.has("credits"):
			s.credits += float(action["credits"])
	s.story["fired"][beat["id"]] = record
	if has_letter:
		sim().emit("story", {"beat": beat["id"], "from": String(beat.get("from", "")).replace("{copilot}", copilot_name(s, data)), "text": beat["message"]})


## A favour: a fixed job on the local board, offered by name (shown first, with the
## beat's message as its opener). It is open to any pilot whatever their standing
## (-50 is the floor): giving one up or letting it fail costs standing with the
## client, and a favour gated at 0 would then be offered again but never takeable.
func _favour(spec: Dictionary, beat: Dictionary) -> Dictionary:
	var s = sim().state
	var data = sim().data
	var here: String = s.location["place"]
	var ref := Contracts.reference_ship(data, "local")
	var plan: Dictionary = TripEstimate.trip(ref, data, sim().ephemeris, here, spec["to"], s.time_s)
	var days := float(plan.get("duration_s", 3.0 * DAY)) / DAY if plan.get("ok", false) else 6.0
	s.contracts["seq"] = int(s.contracts["seq"]) + 1
	var offer := {
		"id": int(s.contracts["seq"]), "kind": "package", "client": spec["client"], "issued_at": here, "pickup": "", "to": spec["to"],
		"item": spec["item"], "mass_t": float(spec["mass_t"]), "passengers": 0, "reward": float(spec["reward"]),
		"window_s": days * float(spec.get("slack", 1.8)) * DAY, "expires_t": s.time_s + 60.0 * DAY,
		"min_rep": -50.0, "rep": float(spec.get("rep", 5.0)), "channel": "approach", "hidden": false,
		"opener": beat.get("message", ""), "favour": beat["id"],
	}
	var board: Array = s.contracts["board"].get(here, [])
	board.append(offer)
	s.contracts["board"][here] = board
	return offer


func _finished(beat: Dictionary) -> bool:
	var s = sim().state
	var done_when = beat.get("done_when", "now")
	if done_when is String and done_when == "now":
		return true
	if done_when is String and done_when == "delivered":
		var id := int(s.story["fired"][beat["id"]].get("offer", -1))
		var pending := false
		for place in s.contracts.get("board", {}):
			pending = pending or s.contracts["board"][place].any(func(o): return int(o["id"]) == id)
		pending = pending or s.contracts.get("active", []).any(func(j): return int(j["id"]) == id)
		if pending:
			return false
		for job in s.contracts.get("history", []):
			if int(job["id"]) == id:
				if job["outcome"] in ["delivered", "late"]:
					return true
				# Failed or abandoned: the friends in grey will ask again.
				s.story["fired"].erase(beat["id"])
				return false
		# Never taken and gone from the board: ask again.
		s.story["fired"].erase(beat["id"])
		return false
	if done_when is Dictionary and done_when.has("site_worked"):
		return not s.sites.get("worked", {}).get(done_when["site_worked"], []).is_empty()
	return false
