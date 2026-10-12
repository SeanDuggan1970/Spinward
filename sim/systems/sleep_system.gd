## Hibernation (data/balance.json "sleep"). With a sleep pod fitted (a module with
## "sleep": true) the pilot can sleep through a voyage, waking a couple of days before
## arrival, or sleep at port for a while. The ship's mind keeps watch. While asleep the
## world steps a day at a time (Sim.step_s), NPC traders reuse their route estimates,
## and time runs fast, so years go by in a minute. The world goes on without you: the
## view shows what changed when you wake.
extends "res://sim/systems/system.gd"

const DAY := 86400.0


func setup(owner) -> void:
	super.setup(owner)
	owner.register("sleep", _sleep)
	owner.register("wake", _wake_command)


func start_game() -> void:
	sim().state.sleep = {}


static func cfg(data) -> Dictionary:
	return data.balance["sleep"]


## The pod aboard, or "" if there is none.
static func pod_of(ship: Dictionary, data) -> String:
	for slot in ship.get("modules", {}):
		if bool(data.modules.get(ship["modules"][slot], {}).get("sleep", false)):
			return ship["modules"][slot]
	return ""


## Why the pilot cannot sleep now ("" if they can), and until when they would sleep.
## `days` is for a sleep at port; a voyage sleeps until shortly before arrival.
static func plan(state, data, days: float = 0.0) -> Dictionary:
	var c := cfg(data)
	if bool(state.sleep.get("active", false)):
		return {"why": "already asleep", "until_t": 0.0}
	if pod_of(state.ship, data) == "":
		return {"why": "you need a hibernation pod fitted (a cargo slot, at a shipyard that sells one)", "until_t": 0.0}
	match String(state.location.get("status", "")):
		"transit":
			var until := float(state.location["arrive_t"]) - float(c["wake_before_arrival_h"]) * 3600.0
			if until - state.time_s < float(c["min_voyage_days"]) * DAY:
				return {"why": "too close to arrival to be worth the pod", "until_t": until}
			return {"why": "", "until_t": until, "kind": "voyage"}
		"docked", "on_site":
			if days <= 0.0 or days > float(c["max_port_days"]):
				return {"why": "sleep between 1 and %d days" % int(c["max_port_days"]), "until_t": 0.0}
			return {"why": "", "until_t": state.time_s + days * DAY, "kind": "port"}
	return {"why": "not now: you're flying her", "until_t": 0.0}


## {days?}: sleep. In transit, until shortly before arrival; at port, for `days`.
func _sleep(command: Dictionary) -> String:
	var s = sim().state
	var data = sim().data
	var p := plan(s, data, float(command.get("days", 0.0)))
	if p["why"] != "":
		return p["why"]
	var total := float(s.sleep.get("total_s", 0.0))
	var count := int(s.sleep.get("count", 0))
	s.sleep = {"active": true, "kind": p["kind"], "start_t": s.time_s, "until_t": p["until_t"],
		"total_s": total, "count": count + 1}
	s.time_scale = float(cfg(data)["time_scale"])
	s.paused = false
	sim().emit("slept", {"kind": p["kind"], "until_t": p["until_t"], "pod": pod_of(s.ship, data)})
	return ""


func _wake_command(_command: Dictionary) -> String:
	if not bool(sim().state.sleep.get("active", false)):
		return "not asleep"
	_wake("woken")
	return ""


func tick(_game_dt: float) -> void:
	var s = sim().state
	if not bool(s.sleep.get("active", false)):
		return
	var voyage_over: bool = s.sleep["kind"] == "voyage" and s.location.get("status") != "transit"
	if voyage_over or s.time_s >= float(s.sleep["until_t"]) - 1e-6:
		_wake("rested")


func _wake(why: String) -> void:
	var s = sim().state
	var slept: float = s.time_s - float(s.sleep["start_t"])
	s.sleep["active"] = false
	s.sleep["total_s"] = float(s.sleep.get("total_s", 0.0)) + slept
	# At port, back to x1. On a voyage, fast enough to close the last hours (the
	# approach caps slow it as the port nears).
	s.time_scale = 1.0 if s.sleep["kind"] == "port" else float(cfg(sim().data)["wake_scale"])
	sim().emit("woke", {"kind": s.sleep["kind"], "from_t": s.sleep["start_t"], "to_t": s.time_s, "days": slept / DAY, "why": why})
