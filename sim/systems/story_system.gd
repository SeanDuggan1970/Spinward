## The story arcs (data/story.json): the Long View, an informal circle of Commons
## minds, and what the Farside Array saw at a thousand AU; and the Sufficiency, minds
## who would like a home of their own.
##
## Beats run in order. A beat waits for its conditions and its port, then fires: its
## message goes into the player's correspondence and its actions happen (a favour
## job on the local board, a site revealed, modules lent, standing, credits). It is
## done when its favour is delivered, a site activity is finished, or at once. A
## favour that fails or is abandoned is offered again at the next suitable dock.
extends "res://sim/systems/system.gd"

const Contracts := preload("res://sim/contracts.gd")
const Navigation := preload("res://sim/navigation.gd")
const ShipStats := preload("res://sim/ship_stats.gd")

const DAY := 86400.0


func start_game() -> void:
	sim().state.story = {"done": [], "fired": {}, "messages": []}


func tick(_game_dt: float) -> void:
	var s = sim().state
	if s.story.is_empty():
		start_game()
	if not s.location.get("status") in ["docked", "on_site"]:
		return
	var data = sim().data
	# Each arc ("arc", default the Long View) runs its own beats in order, side by side.
	var stalled := {}
	for beat in data.story.get("beats", []):
		var id: String = beat["id"]
		var arc: String = beat.get("arc", "long_view")
		if stalled.has(arc) or id in s.story["done"]:
			continue
		if not s.story["fired"].has(id):
			if _ready_to_fire(beat):
				_fire(beat)
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
	s.story["messages"].append({"t": s.time_s, "from": beat.get("from", ""), "text": beat.get("message", "")})
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
	sim().emit("story", {"beat": beat["id"], "from": beat.get("from", ""), "text": beat.get("message", "")})


## A favour: a fixed job on the local board, offered by name (shown first, with the
## beat's message as its opener).
func _favour(spec: Dictionary, beat: Dictionary) -> Dictionary:
	var s = sim().state
	var data = sim().data
	var here: String = s.location["place"]
	var ref := Contracts.reference_ship(data, "local")
	var plan: Dictionary = Navigation.plan(ref, data, sim().ephemeris, here, spec["to"], s.time_s)
	var days := float(plan.get("duration_s", 3.0 * DAY)) / DAY if plan.get("ok", false) else 6.0
	s.contracts["seq"] = int(s.contracts["seq"]) + 1
	var offer := {
		"id": int(s.contracts["seq"]), "kind": "package", "client": spec["client"], "issued_at": here, "pickup": "", "to": spec["to"],
		"item": spec["item"], "mass_t": float(spec["mass_t"]), "passengers": 0, "reward": float(spec["reward"]),
		"window_s": days * float(spec.get("slack", 1.8)) * DAY, "expires_t": s.time_s + 60.0 * DAY,
		"min_rep": 0.0, "rep": float(spec.get("rep", 5.0)), "channel": "approach", "hidden": false,
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
