## The player's ship: starting hull and module swaps at shipyards.
extends "res://sim/systems/system.gd"

const ShipStats := preload("res://sim/ship_stats.gd")
const Perks := preload("res://sim/perks.gd")


func setup(owner) -> void:
	super.setup(owner)
	owner.register("install_module", _install)


func start_game() -> void:
	var start: Dictionary = sim().data.balance["start"]
	var hull: Dictionary = sim().data.ships[start["ship"]]
	var ship := {
		"name": start["ship_name"], "hull": start["ship"], "modules": hull["modules"].duplicate(),
		"cargo": {}, "cargo_paid": {}, "fuel_t": 0.0,
	}
	ship["fuel_t"] = ShipStats.fuel_capacity_t(ship, sim().data)
	sim().state.ship = ship


## Modules the current yard sells (empty when not docked at a shipyard).
static func yard_stock(state, data) -> Array:
	if state.location.get("status") != "docked":
		return []
	var place: Dictionary = data.places[state.location["place"]]
	return place.get("shipyard_stock", []) if "shipyard" in place.get("services", []) else []


static func slot_count(state, data, kind: String) -> int:
	var spine: Dictionary = data.modules[data.ships[state.ship["hull"]]["spine"]]
	return int(spine["slots"].get(kind, 0))


## The exact slot keys a hull's spine offers for a module kind, e.g. ["cargo.0", "cargo.1"].
## Only these names are accepted, so "cargo.01" or "cargo.-1" cannot add phantom slots.
static func slot_names(state, data, kind: String) -> Array:
	var names := []
	for i in slot_count(state, data, kind):
		names.append("%s.%d" % [kind, i])
	return names


## The slot kinds a module fits: its own kind, or the list in its data ("mounts"), so
## a cargo bay can carry a long-haul tank, a hab, a lander or a rig.
static func mounts(module: Dictionary) -> Array:
	return module.get("mounts", [module["kind"]])


static func fits(module: Dictionary, slot: String) -> bool:
	return slot.split(".")[0] in mounts(module)


## {slot: "cargo.1", module: "cargo_pod_m"}. The old module is sold back at resale value.
func _install(command: Dictionary) -> String:
	var s = sim().state
	var data = sim().data
	var module_id: String = command.get("module", "")
	if not module_id in yard_stock(s, data):
		return "not sold here"
	var slot: String = command.get("slot", "")
	var module: Dictionary = data.modules[module_id]
	if not fits(module, slot) or not slot in slot_names(s, data, slot.split(".")[0]):
		return "that module does not fit that slot"
	var old_id: String = s.ship["modules"].get(slot, "")
	if old_id == module_id:
		return "already fitted"
	var refund := 0.0
	if old_id != "":
		refund = float(data.modules[old_id]["price"]) * float(data.balance["shipyard"]["resale_fraction"])
	var cost := float(module["price"]) * Perks.yard_mult(s, s.location["place"]) - refund
	if cost > s.credits + 1e-6:
		return "not enough credits"
	var trial: Dictionary = s.ship.duplicate(true)
	trial["modules"][slot] = module_id
	if ShipStats.cargo_t(trial) > ShipStats.cargo_capacity_t(trial, data) + 1e-9:
		return "sell some cargo first"
	trial["fuel_t"] = minf(float(trial["fuel_t"]), ShipStats.fuel_capacity_t(trial, data))
	s.ship = trial
	s.credits -= cost
	sim().emit("module_installed", {"slot": slot, "module": module_id, "replaced": old_id, "credits": -cost})
	return ""
