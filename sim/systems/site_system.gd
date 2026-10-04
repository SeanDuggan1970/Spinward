## Sites: places to go that are not ports (data/sites.json). On site you can work:
## salvage a derelict, survey from orbit, land and core, or mine. Work takes days
## of game time, needs the right kit (a survey pod, a lander, a rig), and can go
## wrong (less yield; a landing that goes wrong burns extra propellant). Yields go
## into the hold as room allows; survey data is sold by radio on completion.
## Which sites you know of: the well-known ones from the start, others by rumour.
extends "res://sim/systems/system.gd"

const ShipStats := preload("res://sim/ship_stats.gd")

const DAY := 86400.0
## Propellant a lander burns when a landing goes wrong.
const BAD_LANDING_FUEL_T := 0.6

var _rng := RandomNumberGenerator.new()


func setup(owner) -> void:
	super.setup(owner)
	owner.register("site_work", _start_work)


func start_game() -> void:
	var s = sim().state
	s.sites = {"known": [], "worked": {}, "work": {}}
	for id in sim().data.sites:
		if sim().data.sites[id].get("visibility", "known") == "known":
			s.sites["known"].append(id)


func tick(_game_dt: float) -> void:
	var s = sim().state
	if s.sites.is_empty():
		start_game()
	var work: Dictionary = s.sites["work"]
	if not work.is_empty() and s.time_s >= float(work["end_t"]):
		_finish(work)


static func knows(state, site: String) -> bool:
	return site in state.sites.get("known", [])


## What the ship can do: abilities come from modules (survey, lander, mining).
static func can(ship: Dictionary, data, ability: String) -> bool:
	for m in ShipStats.modules_of(ship, data):
		if m.get(ability, false):
			return true
	return false


## Why an activity cannot be started here and now ("" if it can).
static func blocked(state, data, site: String, activity: String) -> String:
	if state.location.get("status") != "on_site" or state.location.get("place") != site:
		return "not on site"
	if not state.sites.get("work", {}).is_empty():
		return "already at work"
	var act: Dictionary = data.sites[site]["activities"].get(activity, {})
	if act.is_empty():
		return "nothing like that to do here"
	if activity in state.sites.get("worked", {}).get(site, []) or (data.sites[site].get("once", false) and not state.sites.get("worked", {}).get(site, []).is_empty()):
		return "already done"
	for need in act.get("needs", []):
		if not can(state.ship, data, need):
			return "needs a %s" % {"survey": "survey pod", "lander": "lander", "mining": "mining rig"}.get(need, need)
	return ""


## {activity}
func _start_work(command: Dictionary) -> String:
	var s = sim().state
	var data = sim().data
	var site: String = s.location.get("place", "")
	var activity: String = command.get("activity", "")
	var why := blocked(s, data, site, activity)
	if why != "":
		return why
	var act: Dictionary = data.sites[site]["activities"][activity]
	s.sites["work"] = {"site": site, "activity": activity, "start_t": s.time_s, "end_t": s.time_s + float(act["days"]) * DAY}
	sim().emit("site_work_started", {"site": site, "activity": activity, "days": float(act["days"])})
	return ""


func _finish(work: Dictionary) -> void:
	var s = sim().state
	var data = sim().data
	var site: String = work["site"]
	var activity: String = work["activity"]
	var act: Dictionary = data.sites[site]["activities"][activity]
	_rng.seed = hash(s.seed) ^ 0x517E
	_rng.state = s.rng_state
	var went_wrong := _rng.randf() < float(act.get("risk", 0.0))
	var share := 0.35 if went_wrong else 1.0
	var got := {}
	var lost := 0.0
	for good in act.get("yields", {}):
		var r: Array = act["yields"][good]
		var t := snappedf(_rng.randf_range(float(r[0]), float(r[1])) * share, 0.01)
		var room := maxf(0.0, ShipStats.cargo_capacity_t(s.ship, data) - ShipStats.cargo_t(s.ship))
		var load := minf(t, room)
		lost += t - load
		if load > 0.0:
			s.ship["cargo"][good] = float(s.ship["cargo"].get(good, 0.0)) + load
			got[good] = load
	s.rng_state = _rng.state
	var credits := float(act.get("credits", 0.0)) * share
	s.credits += credits
	for op in act.get("rep", {}):
		s.reputation[op] = float(s.reputation.get(op, 0.0)) + float(act["rep"][op]) * share
	if went_wrong and "lander" in act.get("needs", []):
		s.ship["fuel_t"] = maxf(0.0, float(s.ship["fuel_t"]) - BAD_LANDING_FUEL_T)
	var worked: Array = s.sites["worked"].get(site, [])
	worked.append(activity)
	s.sites["worked"][site] = worked
	s.sites["work"] = {}
	s.stats["site_jobs"] = int(s.stats.get("site_jobs", 0)) + 1
	sim().emit("site_work_done", {"site": site, "activity": activity, "went_wrong": went_wrong, "got": got, "lost_t": lost, "credits": credits})
