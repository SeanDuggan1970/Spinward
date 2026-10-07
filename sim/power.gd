## Ship electrical power: pure functions of ship state, the data and where the ship
## is, shared by the power system and the cockpit so there is one definition of
## "how is the bus". Kilowatts and kilowatt-hours; every number is data (module
## fields in data/modules.json, globals in balance.json "power").
##
## Supply: the reactor on the drives while it is lit, the crew section's solar wings
## (falling with the inverse square of the distance from the Sun), and shore power
## when docked. Demand: life support, avionics, comms, sensors, the mining rig, and
## the radiator pumps (in proportion to the heat being rejected). A deficit drains
## the battery; as charge runs low, comms and sensors shed first, then the rig, and
## life support last, with a warning before anything is done to it.
extends RefCounted

const ShipStats := preload("res://sim/ship_stats.gd")
const Navigation := preload("res://sim/navigation.gd")
const V := preload("res://sim/v3.gd")

const AU_M := 1.495978707e11
## Loads that come from module data, in shed order (the pumps are never shed).
const LOAD_KEYS := ["life", "avionics", "comms", "sensor", "mining"]
const EPS := 1e-9


## Fraction of the 1 AU solar output at this distance from the Sun.
static func solar_factor(au: float, tune: Dictionary) -> float:
	return minf(float(tune["solar_factor_max"]), 1.0 / maxf(au * au, 1e-6))


## Distance of the ship from the Sun, AU (1 if the place is not on the ephemeris).
static func sun_distance_au(state, eph) -> float:
	var loc: Dictionary = state.location
	var p: Array
	if loc.get("status") == "transit" and not (loc.has("burn_s") or loc.get("samples") != null):
		# A trip without its path (a hand-made state): somewhere between its ports.
		var a_id: String = loc.get("from", "")
		var b_id: String = loc.get("to", "")
		if not (eph.places.has(a_id) or eph.bodies.has(a_id)) or not (eph.places.has(b_id) or eph.bodies.has(b_id)):
			return 1.0
		var span := maxf(float(loc.get("arrive_t", state.time_s)) - float(loc.get("depart_t", state.time_s)), 1.0)
		var f := clampf((state.time_s - float(loc.get("depart_t", state.time_s))) / span, 0.0, 1.0)
		p = V.lerp(eph.position(a_id, state.time_s), eph.position(b_id, state.time_s), f)
	elif loc.get("status") == "transit":
		p = Navigation.transit_position(loc, state.time_s)
		var frame: String = loc.get("frame", "earth")
		if frame != "sun" and (eph.bodies.has(frame) or eph.places.has(frame)):
			p = V.add(p, eph.position(frame, state.time_s))
	else:
		var place: String = loc.get("place", "")
		if not (eph.bodies.has(place) or eph.places.has(place)):
			return 1.0
		p = eph.position(place, state.time_s)
	return V.length(p) / AU_M


## What the ship is doing as far as the bus is concerned:
## {mode: docked|transit|approach|work|parked, au, lit, active: {sensor, mining}}.
static func context(state, data, eph) -> Dictionary:
	var loc: Dictionary = state.location
	var mode := "parked"
	match String(loc.get("status", "docked")):
		"docked", "lifeboat":
			mode = "docked"
		"transit":
			mode = "transit"
		"approach":
			mode = "approach"
		"on_site":
			mode = "work" if not state.sites.get("work", {}).is_empty() else "parked"
	var active := {"sensor": false, "mining": false}
	if mode == "work":
		var w: Dictionary = state.sites["work"]
		var needs: Array = data.sites.get(w.get("site", ""), {}).get("activities", {}).get(w.get("activity", ""), {}).get("needs", [])
		active["sensor"] = "survey" in needs
		active["mining"] = "mining" in needs
	var manual := String(state.power.get("reactor", "auto")) == "on"
	return {
		"mode": mode,
		"au": sun_distance_au(state, eph),
		"lit": mode in ["transit", "approach", "work"] or manual,
		"manual": manual,
		"active": active,
	}


## Shed level for a charge fraction: 0 none, 1 comms and sensors, 2 the rig too,
## 3 life support (red warning; on reserve once the battery is flat). Only while the
## bus is in deficit. Hysteresis: a level held stays until charge is
## shed_release_margin above its threshold.
static func shed_level(frac: float, deficit: bool, prev: int, tune: Dictionary) -> int:
	if not deficit:
		return 0
	var margin := float(tune["shed_release_margin"])
	var level := 0
	var thresholds := [float(tune["shed_comms_below"]), float(tune["shed_mining_below"]), float(tune["life_warn_below"])]
	for i in 3:
		var t: float = thresholds[i]
		if frac < t or (prev > i and frac < t + margin):
			level = i + 1
	return level


## Everything the bus is doing, for a ship in context `ctx` with `charge` kWh in the
## battery and shed level `prev_shed` held from the last step.
static func snapshot(ship: Dictionary, data, ctx: Dictionary, charge: float, prev_shed: int) -> Dictionary:
	var tune: Dictionary = data.balance["power"]
	var mode: String = ctx["mode"]
	# Supply.
	var solar := ShipStats.solar_kw_1au(ship, data) * solar_factor(float(ctx["au"]), tune)
	var reactor := ShipStats.reactor_kw(ship, data) if ctx["lit"] else 0.0
	var shore := float(tune["shore_kw"]) if mode == "docked" else 0.0
	var supply := {"reactor": reactor, "solar": solar, "shore": shore, "total": reactor + solar + shore}
	# Demand: module loads (sensors and the rig idle at a standby fraction until used)
	# and pumps for the heat being rejected.
	var standby := float(tune["standby_frac"])
	var demand := {}
	for key in LOAD_KEYS:
		var kw := ShipStats.load_kw(ship, data, key + "_kw")
		if key in ["sensor", "mining"] and not bool(ctx["active"].get(key, false)):
			kw *= standby
		demand[key] = kw
	var heat_mode: String = mode if tune["heat_frac"].has(mode) else ("work" if ctx["lit"] else "")
	var heat := 0.0 if heat_mode == "" else ShipStats.heat_mw(ship, data) * float(tune["heat_frac"][heat_mode])
	var rejected := minf(heat, ShipStats.reject_mw(ship, data))
	demand["pumps"] = rejected * float(tune["pump_kw_per_mw"])
	demand["total"] = _total(demand)
	# Charge and shedding.
	var cap := ShipStats.battery_kwh(ship, data)
	charge = clampf(charge, 0.0, cap)
	var frac := 0.0 if cap <= EPS else charge / cap
	var level := shed_level(frac, float(supply["total"]) < float(demand["total"]) - EPS, prev_shed, tune)
	var draw := demand.duplicate()
	if level >= 1:
		draw["comms"] = 0.0
		draw["sensor"] = 0.0
	if level >= 2:
		draw["mining"] = 0.0
	draw["total"] = _total(draw)
	var net := float(supply["total"]) - float(draw["total"])
	var flat := charge <= EPS and net < -EPS
	var state := "NORM"
	if mode == "docked":
		state = "SHORE"
	elif level >= 3 or flat:
		state = "LOW"
	elif level >= 1:
		state = "SHED"
	elif net < -EPS:
		state = "BATT"
	elif net > EPS and frac < 0.999:
		state = "CHG"
	return {
		"mode": mode, "lit": ctx["lit"], "au": ctx["au"], "solar_factor": solar_factor(float(ctx["au"]), tune),
		"supply": supply, "demand": demand, "draw": draw, "net_kw": net,
		"battery_kwh": cap, "charge_kwh": charge, "frac": frac, "shed": level, "flat": flat, "state": state,
		"hours_to_empty": INF if net >= -EPS else charge / -net,
		"hours_to_full": INF if net <= EPS or cap - charge <= EPS else (cap - charge) / net,
	}


## Charge after `dt_s` seconds at the snapshot's net power.
static func charge_after(snap: Dictionary, dt_s: float) -> float:
	return clampf(float(snap["charge_kwh"]) + float(snap["net_kw"]) * dt_s / 3600.0, 0.0, float(snap["battery_kwh"]))


## The bus now, from the saved state (battery full if nothing is saved yet: a new
## ship, or a save from before there was power).
static func now(state, data, eph) -> Dictionary:
	var ship: Dictionary = state.ship
	var charge := float(state.power.get("charge_kwh", ShipStats.battery_kwh(ship, data)))
	return snapshot(ship, data, context(state, data, eph), charge, int(state.power.get("shed", 0)))


## Whether a module ability ("sensor" or "mining") has the power to work: comms and
## sensors shed first, the rig next.
static func powered(state, ability: String) -> bool:
	var level := int(state.power.get("shed", 0))
	match ability:
		"sensor":
			return level < 1
		"mining":
			return level < 2
	return true


static func _total(d: Dictionary) -> float:
	var t := 0.0
	for k in d:
		if k != "total":
			t += float(d[k])
	return t
