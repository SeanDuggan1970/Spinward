## Badges (data/badges.json): what earns them, and what being known for them does.
## Pure functions of state and data, shared by the badge system, the systems that
## read renown (hitchhikers, approaches) and the view.
extends RefCounted


## Badge state, made if missing (saves from before badges).
static func ensure(state) -> void:
	if state.badges.is_empty():
		state.badges = {"earned": {}, "visited": [], "rounds": 0, "rounds_at": {}}


## Renown: the sum of the renown of every badge earned.
static func renown(state, data) -> float:
	var total := 0.0
	var all: Dictionary = data.badges.get("badges", {})
	for id in state.badges.get("earned", {}):
		total += float(all.get(id, {}).get("renown", 0.0))
	return total


## How much likelier renown makes something: 1 + per point, capped (data badges.renown).
static func chance_mult(state, data, key: String) -> float:
	var cfg: Dictionary = data.badges.get("renown", {})
	return minf(1.0 + float(cfg.get(key, 0.0)) * renown(state, data), float(cfg.get("max_mult", 1.0)))


## Whether a badge's conditions are met now.
static func met(state, badge: Dictionary) -> bool:
	var b: Dictionary = state.badges
	var visited: Array = b.get("visited", [])
	if badge.has("visit") and not badge["visit"].any(func(p): return p in visited):
		return false
	if badge.has("visit_all") and not badge["visit_all"].all(func(p): return p in visited):
		return false
	if badge.has("rounds"):
		var need := int(badge["rounds"])
		if badge.has("at"):
			var at: Dictionary = b.get("rounds_at", {})
			if not badge["at"].any(func(p): return int(at.get(p, 0)) >= need):
				return false
		elif int(b.get("rounds", 0)) < need:
			return false
	return true


## What a round costs at a place's bar, or -1 if there is no bar.
static func round_cost(data, place: String) -> float:
	var p: Dictionary = data.places.get(place, {})
	if not "bar" in p.get("services", []):
		return -1.0
	return float(p["bar"]["patrons"]) * float(p["bar"]["round_cr"])
