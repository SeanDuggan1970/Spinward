## Who can see a ship (balance.detection): pure functions of ship state and data,
## shared by the detection system and the HUD.
##
## A ship shows on several channels, each with the range at which a standard sensor
## sees it: its lit drive (enormous: nobody hides while burning), its waste heat, its
## transponder and running lights (off when running dark), and the sunlight it
## reflects (less with the low-observable coating). A heat sink soaks up waste heat
## while running dark, until it is full. A port sees the ship within its largest
## range times the port's sensors.
extends RefCounted

const ShipStats := preload("res://sim/ship_stats.gd")

const LOAD_KEYS := ["life_kw", "avionics_kw", "comms_kw", "sensor_kw", "mining_kw"]


## The drive's jet power, MW: half thrust times exhaust velocity.
static func jet_mw(ship: Dictionary, data) -> float:
	return 0.5 * ShipStats.thrust_n(ship, data) * ShipStats.exhaust_velocity(ship, data) / 1.0e6


## Waste heat the ship radiates, kW: the drive's while it burns, and its electrical loads.
static func heat_kw(ship: Dictionary, data, burning: bool) -> float:
	var kw := ShipStats.heat_mw(ship, data) * 1000.0 if burning else 0.0
	for key in LOAD_KEYS:
		kw += ShipStats._sum(ship, data, key)
	return kw


static func sink_capacity_mj(ship: Dictionary, data) -> float:
	return ShipStats._sum(ship, data, "sink_mj")


## {channel: range m}: drive, heat, transponder, lights, sunlight. det is
## state.detection (dark, sink_mj); au, the distance from the Sun.
static func channels(ship: Dictionary, data, det: Dictionary, burning: bool, au: float) -> Dictionary:
	var cfg: Dictionary = data.balance["detection"]
	var dark := bool(det.get("dark", false))
	var soaking := dark and float(det.get("sink_mj", 0.0)) < sink_capacity_mj(ship, data) - 1e-6
	var albedo := float(cfg["coated_albedo"]) if ship.get("coating", "") == "low_obs" else float(cfg["albedo"])
	var area := float(cfg["area_m2_per_t23"]) * pow(ShipStats.dry_mass_t(ship, data), 2.0 / 3.0)
	return {
		"drive": float(cfg["drive_m_per_sqrt_mw"]) * sqrt(jet_mw(ship, data)) if burning else 0.0,
		"heat": 0.0 if soaking else float(cfg["heat_m_per_sqrt_kw"]) * sqrt(heat_kw(ship, data, burning)),
		"transponder": 0.0 if dark else float(cfg["transponder_m"]),
		"lights": 0.0 if dark else float(cfg["lights_m"]),
		"sunlight": float(cfg["light_m"]) * sqrt(area * albedo) / maxf(au, 0.1),
	}


## The channel that carries furthest, and its range: [name, metres].
static func loudest(ch: Dictionary) -> Array:
	var best := ""
	var r := 0.0
	for k in ch:
		if float(ch[k]) > r:
			r = float(ch[k])
			best = k
	return [best, r]


## How far a port sees (its sensors).
static func sensors(data, place: String) -> float:
	return float(data.places.get(place, {}).get("sensors", data.balance["detection"]["port_sensors"]))
