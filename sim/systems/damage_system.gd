## Collisions, damage, repair and the lifeboat (balance.json "damage").
##
## The flight view reports an impact: how fast you closed, how much of the energy
## your ship took (all of it against a station, less against a small rock), and
## where on the ship it landed. The sim decides which module that was, and what it
## costs:
##   - Drives lose thrust, and tanks and cargo pods lose capacity, venting and
##     spilling whatever no longer fits.
##   - Radiators reject less heat, and habs keep you alive for less long
##     (ShipStats reads ship["damage"]).
##   - Some of every hit goes into the keel, and a wrecked keel is a lost ship.
##
## A lost ship: the crew gets out in the lifeboat, the port's tug brings it in, and
## the insurance pool finds you a stock hull for the excess. Cargo and carried jobs
## are gone. Shipyards repair everything; other ports can patch the worst of it.
extends "res://sim/systems/system.gd"

const ShipStats := preload("res://sim/ship_stats.gd")

## Which modules can be hit where: nose, middle, tail, or out on the flanks.
const ZONES := {
	"nose": ["command", "avionics"],
	"mid": ["cargo"],
	"tail": ["tank", "drive"],
	"side": ["radiator"],
}


func setup(owner) -> void:
	super.setup(owner)
	owner.register("impact", _impact)
	owner.register("repair", _repair)


func tick(_game_dt: float) -> void:
	var s = sim().state
	if s.location.get("status") == "lifeboat" and s.time_s >= float(s.location["until_t"]):
		var place: String = s.location["place"]
		s.location = {"status": "docked", "place": place}
		sim().emit("rescued", {"place": place})


## Damage a module (0..1) and the keel (ship["damage"]["keel"]).
static func damage_of(ship: Dictionary, slot: String) -> float:
	return float(ship.get("damage", {}).get(slot, 0.0))


## How sound the keel is, 1 (new) to 0 (gone).
static func integrity(ship: Dictionary) -> float:
	return 1.0 - clampf(damage_of(ship, "keel"), 0.0, 1.0)


## {speed (closing, m/s), share (0..1 of the energy this ship takes), zone, seed}
func _impact(command: Dictionary) -> String:
	var s = sim().state
	var data = sim().data
	if s.location.get("status") != "approach":
		return "not flying"
	var tune: Dictionary = data.balance["damage"]
	var speed := float(command.get("speed", 0.0))
	if speed <= float(tune["safe_mps"]):
		return ""
	var share := clampf(float(command.get("share", 1.0)), 0.0, 1.0)
	var excess := speed - float(tune["safe_mps"])
	var amount := 0.5 * excess * excess * share / float(tune["full_j_per_kg"])
	var zone: String = command.get("zone", "mid")
	var kinds: Array = ZONES.get(zone, ["cargo"])
	var hit := []
	for slot in s.ship["modules"]:
		if String(slot).split(".")[0] in kinds:
			hit.append(slot)
	hit.sort()
	var slot: String = "keel" if hit.is_empty() else hit[absi(int(command.get("seed", 0))) % hit.size()]
	var ship: Dictionary = s.ship
	if not ship.has("damage"):
		ship["damage"] = {}
	var cap_before := ShipStats.cargo_capacity_t(ship, data)
	var fuel_cap_before := ShipStats.fuel_capacity_t(ship, data)
	# The module takes the blow; what a wrecked module can't absorb goes into the keel.
	var to_keel := amount
	if slot != "keel":
		var before := damage_of(ship, slot)
		var taken := minf(amount, 1.0 - before)
		ship["damage"][slot] = before + taken
		to_keel = (amount - taken) + taken * float(tune["keel_share"])
	ship["damage"]["keel"] = minf(1.0, damage_of(ship, "keel") + to_keel)
	# A breached tank vents what it can no longer hold, and a little more; a broken
	# pod spills what no longer fits, good by good.
	var fuel_lost := 0.0
	var cap := ShipStats.fuel_capacity_t(ship, data)
	if cap < fuel_cap_before - 1e-9:
		var keep := minf(float(ship["fuel_t"]), cap) * (1.0 - minf(amount, 1.0) * 0.3)
		fuel_lost = float(ship["fuel_t"]) - keep
		ship["fuel_t"] = keep
	var spilled := {}
	var cargo_cap := ShipStats.cargo_capacity_t(ship, data)
	if cargo_cap < cap_before - 1e-9:
		var over := ShipStats.cargo_t(ship) - cargo_cap
		if over > 0.0:
			var total := 0.0
			for g in ship["cargo"]:
				total += float(ship["cargo"][g])
			for g in ship["cargo"].keys():
				var lose := minf(float(ship["cargo"][g]), over * float(ship["cargo"][g]) / maxf(total, 1e-9))
				ship["cargo"][g] = float(ship["cargo"][g]) - lose
				spilled[g] = lose
				if float(ship["cargo"][g]) <= 1e-6:
					ship["cargo"].erase(g)
	var destroyed := damage_of(ship, "keel") >= 1.0
	var module_name: String = "the keel" if slot == "keel" else String(data.modules[ship["modules"][slot]]["name"])
	sim().emit("impact", {"speed": speed, "slot": slot, "module": module_name, "amount": amount,
		"integrity": integrity(ship), "fuel_lost": fuel_lost, "spilled": spilled, "destroyed": destroyed})
	if destroyed:
		_lose_ship(s.location["place"])
	return ""


## The ship is gone. The crew is in the lifeboat; the insurance pool pays out a stock
## hull at the port, less the excess. Cargo and carried jobs go with the wreck.
func _lose_ship(place: String) -> void:
	var s = sim().state
	var data = sim().data
	var tune: Dictionary = data.balance["damage"]
	var start: Dictionary = data.balance["start"]
	var name: String = s.ship.get("name", start["ship_name"])
	var hull: Dictionary = data.ships[start["ship"]]
	var ship := {"name": name, "hull": start["ship"], "modules": hull["modules"].duplicate(), "cargo": {}, "cargo_paid": {}, "fuel_t": 0.0, "damage": {}}
	ship["fuel_t"] = ShipStats.fuel_capacity_t(ship, data)
	s.ship = ship
	s.credits -= float(tune["insurance_excess"])
	var lost := []
	for job in s.contracts.get("active", []).duplicate():
		if job.get("state", "") == "carried":
			s.contracts["active"].erase(job)
			job["outcome"] = "lost"
			job["closed_t"] = s.time_s
			s.contracts["history"].append(job)
			lost.append(job["id"])
	s.stats["ships_lost"] = int(s.stats.get("ships_lost", 0)) + 1
	s.location = {"status": "lifeboat", "place": place, "until_t": s.time_s + float(tune["lifeboat_s"])}
	sim().emit("ship_lost", {"place": place, "excess": float(tune["insurance_excess"]), "jobs_lost": lost})


## What it costs to make good every scratch (or, away from a yard, the worst of them).
static func repair_cost(state, data) -> float:
	var tune: Dictionary = data.balance["damage"]
	var full := _yard_here(state, data)
	var total := 0.0
	for slot in state.ship.get("damage", {}):
		var d := float(state.ship["damage"][slot])
		var fix := d if full else maxf(0.0, d - float(tune["patch_max"]))
		var value := float(tune["keel_value"]) if slot == "keel" else maxf(float(data.modules[state.ship["modules"][slot]]["price"]) if state.ship["modules"].has(slot) else 0.0, float(tune["min_module_value"]))
		total += fix * value * float(tune["repair_cr_per_point"]) * (1.0 if full else float(tune["patch_mult"]))
	return total


static func _yard_here(state, data) -> bool:
	return state.location.get("status") == "docked" and "shipyard" in data.places[state.location["place"]].get("services", [])


func _repair(_command: Dictionary) -> String:
	var s = sim().state
	var data = sim().data
	if s.location.get("status") != "docked":
		return "not docked"
	if data.places[s.location["place"]].has("foot_of"):
		return "your ship is up at the port"
	var cost := repair_cost(s, data)
	if cost <= 0.0:
		return "nothing to repair"
	if cost > s.credits + 1e-6:
		return "repairs cost %d cr" % int(ceil(cost))
	var full := _yard_here(s, data)
	var patch := float(data.balance["damage"]["patch_max"])
	for slot in s.ship["damage"].keys():
		s.ship["damage"][slot] = 0.0 if full else minf(float(s.ship["damage"][slot]), patch)
		if float(s.ship["damage"][slot]) <= 0.0:
			s.ship["damage"].erase(slot)
	s.credits -= cost
	sim().emit("repaired", {"credits": -cost, "full": full})
	return ""
