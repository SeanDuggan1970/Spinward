## Derived ship numbers. Pure functions of ship state and data, shared by systems
## and the view, so there is one definition of "what this ship can do".
extends RefCounted

const Condition := preload("res://sim/condition.gd")


static func modules_of(ship: Dictionary, data) -> Array:
	var out := []
	for slot in ship.get("modules", {}):
		out.append(data.modules[ship["modules"][slot]])
	return out


static func dry_mass_t(ship: Dictionary, data) -> float:
	var hull: Dictionary = data.ships[ship["hull"]]
	var total := float(data.modules[hull["spine"]]["mass_t"])
	var modules: Dictionary = ship.get("modules", {})
	for slot in modules:
		total += float(data.modules[modules[slot]]["mass_t"])
	return total


static func cargo_capacity_t(ship: Dictionary, data) -> float:
	return _sum(ship, data, "cargo_t")


static func fuel_capacity_t(ship: Dictionary, data) -> float:
	return _sum(ship, data, "fuel_t")


## Freight in the hold, including contract parcels stowed there (parcels_t). Passengers
## and hand-carried parcels ride in the cabin (cabin_t) and take no hold space.
static func cargo_t(ship: Dictionary) -> float:
	var total := float(ship.get("parcels_t", 0.0))
	for g in ship.get("cargo", {}):
		total += float(ship["cargo"][g])
	return total


## Everything aboard that has mass: the hold, plus what rides in the cabin (cabin_t:
## passengers and hand-carried parcels, which take no hold space).
static func total_mass_t(ship: Dictionary, data) -> float:
	return dry_mass_t(ship, data) + cargo_t(ship) + float(ship.get("cabin_t", 0.0)) + float(ship.get("fuel_t", 0.0))


## Thrust after heat limits: drives throttle down when radiators cannot keep up.
static func thrust_n(ship: Dictionary, data) -> float:
	var heat := _sum(ship, data, "heat_mw")
	var reject := _sum(ship, data, "reject_mw")
	var throttle := 1.0 if heat <= 0.0 else minf(1.0, reject / heat)
	return _sum(ship, data, "thrust_n") * throttle


static func heat_ratio(ship: Dictionary, data) -> float:
	var reject := _sum(ship, data, "reject_mw")
	return INF if reject <= 0.0 else _sum(ship, data, "heat_mw") / reject


## Effective exhaust velocity (m/s), thrust-weighted across drives.
static func exhaust_velocity(ship: Dictionary, data) -> float:
	var thrust := 0.0
	var weighted := 0.0
	var tunes := _tune_factors(ship, data)
	for slot in ship.get("modules", {}):
		var m: Dictionary = data.modules[ship["modules"][slot]]
		if m.has("thrust_n"):
			var f: Dictionary = tunes.get(slot, NO_TUNE)
			thrust += float(m["thrust_n"]) * f["thrust_n"]
			weighted += float(m["thrust_n"]) * f["thrust_n"] * float(m["isp_s"]) * f["isp"]
	return 0.0 if thrust <= 0.0 else weighted / thrust * float(data.balance["travel"]["g0"])


static func accel_mps2(ship: Dictionary, data, extra_mass_t: float = 0.0) -> float:
	return thrust_n(ship, data) / ((total_mass_t(ship, data) + extra_mass_t) * 1000.0)


## What a module makes or draws regardless of damage: a drive's heat, and the
## electrical loads (a hit module still draws its power).
const UNDAMAGED := ["heat_mw", "life_kw", "avionics_kw", "comms_kw", "sensor_kw", "mining_kw"]


## Summed over the modules, each counting for what is left of it after damage
## (ship["damage"][slot], 0 sound to 1 wrecked): a holed tank holds less, a hit drive
## pushes less, scorched solar wings and reactors make less power. Heat is what a
## drive makes, so damage doesn't reduce it (see UNDAMAGED). Wear (sim/condition.gd) trims
## a few percent more off the stats it names in data (performance.keys).
static func _sum(ship: Dictionary, data, key: String) -> float:
	var total := 0.0
	var damage: Dictionary = ship.get("damage", {})
	var tunes := _tune_factors(ship, data) if key == "thrust_n" or key == "heat_mw" else {}
	var undamaged := key in UNDAMAGED
	var modules: Dictionary = ship.get("modules", {})
	for slot in modules:
		# A module that does not have the stat adds exactly 0: skip its wear and tune lookups.
		var base := float(data.modules[modules[slot]].get(key, 0.0))
		if base == 0.0:
			continue
		var left := 1.0 if undamaged else 1.0 - clampf(float(damage.get(slot, 0.0)), 0.0, 1.0)
		var tune: float = tunes.get(slot, NO_TUNE)[key] if not tunes.is_empty() else 1.0
		# Wear and small faults shave a little off supply and rating stats (Condition.perf).
		total += base * left * tune * Condition.perf(ship, slot, key, data)
	return total


## Engine tunes (data/favours.json "tunes"): ship["tunes"] is [{id, slot, module, source}].
## A tune counts only while the drive it was fitted to is still in that slot. Per drive
## slot: multipliers on its thrust and heat, and on its Isp (fuel efficiency). Route
## planning reads thrust and Isp through here, so tuned ships plan and burn differently.
const NO_TUNE := {"thrust_n": 1.0, "heat_mw": 1.0, "isp": 1.0}


static func active_tunes(ship: Dictionary, data) -> Array:
	var out := []
	for t in ship.get("tunes", []):
		if ship.get("modules", {}).get(t["slot"], "") == t["module"] and data.favours.get("tunes", {}).has(t["id"]):
			out.append(t)
	return out


static func _tune_factors(ship: Dictionary, data) -> Dictionary:
	var out := {}
	if ship.get("tunes", []).is_empty():
		return out
	for t in active_tunes(ship, data):
		var spec: Dictionary = data.favours["tunes"][t["id"]]
		var f: Dictionary = out.get(t["slot"], NO_TUNE).duplicate()
		f["thrust_n"] += float(spec.get("thrust_pct", 0.0))
		f["heat_mw"] += float(spec.get("heat_pct", 0.0))
		f["isp"] += float(spec.get("isp_pct", 0.0))
		out[t["slot"]] = f
	return out


## How much the tunes and the crew change the rate at which parts wear (1.0 untuned, no
## one aboard). The wear system reads it per slot: a tune wears only the drive it is on;
## an engineer aboard eases wear on everything. Without a slot, every tune counts.
static func wear_mult(ship: Dictionary, data, slot: String = "") -> float:
	var m := 1.0
	for t in active_tunes(ship, data):
		if slot == "" or t["slot"] == slot:
			m += float(data.favours["tunes"][t["id"]].get("wear_pct", 0.0))
	for h in ship.get("hikers", []):
		m *= float(data.favours.get("hitchhikers", {}).get("trades", {}).get(h["trade"], {}).get("wear_mult", 1.0))
	return m


## A short signature of the active tunes, for route-plan cache keys ("" if none).
static func tunes_key(ship: Dictionary) -> String:
	var ids := []
	for t in ship.get("tunes", []):
		ids.append("%s@%s:%s" % [t["id"], t["slot"], t["module"]])
	return "" if ids.is_empty() else "#" + ",".join(ids)


## Sum of a trade effect over the hitchhikers aboard (ship["hikers"]), e.g. "fuel_trim".
static func crew_sum(ship: Dictionary, data, key: String) -> float:
	var total := 0.0
	for h in ship.get("hikers", []):
		total += float(data.favours.get("hitchhikers", {}).get("trades", {}).get(h["trade"], {}).get(key, 0.0))
	return total


## Product of a trade multiplier over the hitchhikers aboard (1.0 if none has it).
static func crew_mult(ship: Dictionary, data, key: String) -> float:
	var m := 1.0
	for h in ship.get("hikers", []):
		m *= float(data.favours.get("hitchhikers", {}).get("trades", {}).get(h["trade"], {}).get(key, 1.0))
	return m


## How many days the crew can be kept alive between ports (INF for uncrewed ships).
static func life_support_days(ship: Dictionary, data) -> float:
	for m in modules_of(ship, data):
		if m.get("crewless", false):
			return INF
	var days := _sum(ship, data, "life_support_days") * crew_mult(ship, data, "life_support_mult")
	return days if days > 0.0 else INF


static func berths(ship: Dictionary, data) -> int:
	return int(round(_sum(ship, data, "berths")))


static func has_docking_computer(ship: Dictionary, data) -> bool:
	for m in modules_of(ship, data):
		if m.get("docking_computer", false):
			return true
	return false


## Heat the drives make (MW) and the radiators can reject (MW, after damage).
static func heat_mw(ship: Dictionary, data) -> float:
	return _sum(ship, data, "heat_mw")


static func reject_mw(ship: Dictionary, data) -> float:
	return _sum(ship, data, "reject_mw")


## Electrical figures (kW, kWh), for sim/power.gd. Supply stats fall with damage;
## load stats do not (UNDAMAGED).
static func solar_kw_1au(ship: Dictionary, data) -> float:
	return _sum(ship, data, "solar_kw")


static func battery_kwh(ship: Dictionary, data) -> float:
	return _sum(ship, data, "battery_kwh")


static func reactor_kw(ship: Dictionary, data) -> float:
	return _sum(ship, data, "reactor_kw")


static func load_kw(ship: Dictionary, data, key: String) -> float:
	return _sum(ship, data, key)
