## Bay traffic at a port: who uses the docking bay, and when (balance.traffic, and a
## place's own "bay_traffic" in data/places.json). A bay takes one ship at a time: its
## doors open, the ship goes in or out, the doors shut, over cycle_s.
##
## Two kinds of ship use it. The long-haul ships of data/npcs.json arrive and leave on
## their own schedules. The port's own local craft (tenders, shuttles, ferries) are laid
## on a grid of slot_s slots, per_hour of them an hour on average, by a low-discrepancy
## sequence: evenly spread, never clumped. Everything here follows from the time and
## the state alone, with no random draws, so the flight scene, the departure and the
## sim all agree on who is in the pattern.
##
## A port with a tower ("control": "tower") sequences ships strictly: you wait behind
## anyone scheduled first. Out-system ports ("open") have no controller: pilots call
## their moves on a common channel, like a club airfield with no tower, and give way to
## whoever is already committed (starting within lead_s).
extends RefCounted

## Low-discrepancy sequence steps (golden ratio and relatives): occupancy, kind, offset.
const STEP_BUSY := 0.6180339887498949
const STEP_KIND := 0.7548776662466927
const STEP_OFFSET := 0.5698402909980532
const STEP_PLACE := 0.3819660112501051


static func has_bay(data, place: String) -> bool:
	return data.places.get(place, {}).has("station") and data.balance.has("bays")


## "tower" or "open".
static func control(data, place: String) -> String:
	return String(data.places.get(place, {}).get("bay_traffic", {}).get("control", "tower"))


## Local craft movements an hour.
static func per_hour(data, place: String) -> float:
	return float(data.places.get(place, {}).get("bay_traffic", {}).get("per_hour", data.balance["traffic"]["per_hour"]))


## Each port's sequence starts at its own phase, so ports don't move in step.
static func _phase(data, place: String) -> float:
	var keys: Array = data.places.keys()
	keys.sort()
	return fposmod(float(keys.find(place)) * STEP_PLACE, 1.0)


## Bay movements at `place` starting in [t0, t1), sorted by start:
## {t, end, kind ("in" | "out"), and either npc (its id) or local (its slot index)}.
## One at a time: each waits for the bay (sequence), so no two ever share it.
static func movements(state, data, place: String, t0: float, t1: float) -> Array:
	if not has_bay(data, place):
		return []
	# Queues form from earlier movements, so sequence from well before the window.
	var lookback := float(data.balance["traffic"]["queue_lookback_s"])
	var out := []
	for m in sequence(data, _wanted(state, data, place, t0 - lookback, t1, t0)):
		if float(m["t"]) >= t0 and float(m["t"]) < t1:
			out.append(m)
	return out


## Movements in order, each waiting for the bay: it starts once the one before has
## finished, and a ship coming in also waits turnaround_s after one has gone out, so
## the leaver is off the axis before the next closes on the doors.
static func sequence(data, wanted: Array) -> Array:
	var cfg: Dictionary = data.balance["traffic"]
	var turnaround := float(cfg["turnaround_s"])
	var free := -INF
	var last_kind := ""
	for m in wanted:
		var start := maxf(float(m["t"]), free + (turnaround if last_kind == "out" and m["kind"] == "in" else 0.0))
		var length := float(m["end"]) - float(m["t"])
		m["t"] = start
		m["end"] = start + length
		free = start + length
		last_kind = m["kind"]
	return wanted


## When each ship would like the bay, starting in [t0, t1), sorted, before sequencing.
## active_t0: docked long-haul ships count from when they are free to go at this time.
static func _wanted(state, data, place: String, t0: float, t1: float, active_t0: float) -> Array:
	var cfg: Dictionary = data.balance["traffic"]
	var slot := float(cfg["slot_s"])
	var cycle := float(cfg["cycle_s"])
	var out := []
	# Long-haul ships: in over the cycle before they dock, out from when they leave.
	for npc in state.npcs:
		var fleet: Dictionary = data.npcs["fleets"].get(npc["fleet"], {})
		# Sails moor at the sail park and climbers ride the ribbon: neither uses the bay.
		if fleet.get("sail", false) or fleet.get("elevator", false):
			continue
		var loc: Dictionary = npc["location"]
		var start := INF
		var kind := ""
		if loc.get("status") == "transit" and loc.get("to") == place:
			start = float(loc["arrive_t"]) - cycle
			kind = "in"
		elif loc.get("status") == "transit" and loc.get("from") == place:
			start = float(loc["depart_t"])
			kind = "out"
		elif loc.get("status") == "docked" and loc.get("place") == place and float(npc.get("active_t", 0.0)) <= active_t0:
			start = float(npc.get("next_t", INF))
			kind = "out"
		if start >= t0 and start < t1:
			out.append({"t": start, "end": start + cycle, "kind": kind, "npc": npc["id"]})
	# The port's own craft, one slot at a time, clear of the long-haul ships.
	var busy := clampf(per_hour(data, place) * slot / 3600.0, 0.0, 1.0)
	var ph := _phase(data, place)
	var k := int(floor(t0 / slot)) - 1
	var last := int(floor(t1 / slot))
	while k <= last:
		var kf := float(k)
		if fposmod(kf * STEP_BUSY + ph, 1.0) < busy:
			var start := kf * slot + (slot - cycle) * fposmod(kf * STEP_OFFSET + ph, 1.0)
			if start >= t0 and start < t1:
				var clash := false
				for m in out:
					if m.has("npc") and start < float(m["end"]) and start + cycle > float(m["t"]):
						clash = true
						break
				if not clash:
					out.append({"t": start, "end": start + cycle, "kind": "in" if fposmod(kf * STEP_KIND + ph * 0.5, 1.0) < 0.5 else "out", "local": k})
		k += 1
	out.sort_custom(func(a, b): return float(a["t"]) < float(b["t"]) or (float(a["t"]) == float(b["t"]) and str(a.get("npc", a.get("local"))) < str(b.get("npc", b.get("local")))))
	return out


## How long a ship leaving `place` at t holds in its cradle for traffic, and who it
## waits for: {hold_s, ahead (the movement it waits for, or {}), control}. The bay must
## be free for depart_need_s. A tower holds you behind everyone scheduled first; at an
## open port you give way only to ships already committed. Capped at max_hold_s.
static func departure_hold(state, data, place: String, t: float) -> Dictionary:
	var result := {"hold_s": 0.0, "ahead": {}, "control": control(data, place)}
	if not has_bay(data, place):
		return result
	var cfg: Dictionary = data.balance["traffic"]
	var need := float(cfg["depart_need_s"])
	var cap := float(cfg["max_hold_s"])
	var open: bool = result["control"] == "open"
	var start := t
	for m in movements(state, data, place, t - float(cfg["cycle_s"]), t + cap + need):
		# Sorted by start: at an open port, those not yet committed give way to us.
		if open and float(m["t"]) > t + float(cfg["lead_s"]):
			break
		if float(m["end"]) > start and float(m["t"]) < start + need:
			start = float(m["end"])
			result["ahead"] = m
	result["hold_s"] = minf(start - t, cap)
	return result
