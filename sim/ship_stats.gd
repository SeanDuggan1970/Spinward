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
	for m in modules_of(ship, data):
		total += float(m["mass_t"])
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
	for m in modules_of(ship, data):
		if m.has("thrust_n"):
			thrust += float(m["thrust_n"])
			weighted += float(m["thrust_n"]) * float(m["isp_s"])
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
	for slot in ship.get("modules", {}):
		var m: Dictionary = data.modules[ship["modules"][slot]]
		var left := 1.0 if key in UNDAMAGED else 1.0 - clampf(float(damage.get(slot, 0.0)), 0.0, 1.0)
		# Wear and small faults shave a little off supply and rating stats (Condition.perf).
		total += float(m.get(key, 0.0)) * left * Condition.perf(ship, slot, key, data)
	return total


## How many days the crew can be kept alive between ports (INF for uncrewed ships).
static func life_support_days(ship: Dictionary, data) -> float:
	for m in modules_of(ship, data):
		if m.get("crewless", false):
			return INF
	var days := _sum(ship, data, "life_support_days")
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
