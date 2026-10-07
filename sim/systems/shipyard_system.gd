## The player's ship: starting hull, module swaps, service, overhaul and inspection at
## shipyards. Every yard job is itemised by ShipBill.quote and takes days in port.
extends "res://sim/systems/system.gd"

const ShipStats := preload("res://sim/ship_stats.gd")
const Perks := preload("res://sim/perks.gd")
const ShipBill := preload("res://sim/ship_bill.gd")
const Favours := preload("res://sim/favours.gd")
const Condition := preload("res://sim/condition.gd")
const StockShip := preload("res://sim/stock_ship.gd")


func setup(owner) -> void:
	super.setup(owner)
	owner.register("install_module", _install)
	owner.register("refit", _refit)
	owner.register("service", _service)
	owner.register("overhaul", _overhaul)
	owner.register("inspect", _inspect)


func start_game() -> void:
	var start: Dictionary = sim().data.balance["start"]
	var ship: Dictionary = StockShip.make(sim().data, start["ship_name"], sim().state.time_s)
	ship.erase("damage")
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


## The ship builder's bill for a set of proposed changes {slot: module_id} at this yard,
## before any is made: ShipBill.quote (the bill the refit command charges), arranged one
## line per slot. Each line has the part at this yard's price, the trade-in for what
## comes out (by its condition and age), the fitting labour, the net, and why it can't
## be done here if it can't (such a line is left out of the total). `extra` adds yard
## work to the same visit: {services, service_all, inspect} as ShipBill takes them.
## Returns {lines, total, trial, problems, ok, bill}: `bill` is the whole ShipBill quote
## (days in port, the Warrant of Fitness and insurance after, the work lines).
static func quote(state, data, changes: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var stock := yard_stock(state, data)
	var lines := []
	var swaps := []
	var slots := changes.keys()
	slots.sort()
	for slot in slots:
		var module_id: String = changes[slot]
		var old_id: String = state.ship["modules"].get(slot, "")
		if module_id == old_id:
			continue
		var module: Dictionary = data.modules[module_id]
		var line := {"slot": slot, "module": module_id, "replaced": old_id,
			"part": float(module["price"]) * Perks.yard_mult(state, String(state.location.get("place", ""))),
			"trade_in": Condition.trade_in(state.ship, slot, data) if old_id != "" else 0.0, "labour": 0.0, "why": ""}
		if not module_id in stock:
			line["why"] = "not sold here"
		elif not fits(module, slot) or not slot in slot_names(state, data, slot.split(".")[0]):
			line["why"] = "does not fit that slot"
		else:
			swaps.append({"slot": slot, "module": module_id})
		lines.append(line)
	var request := extra.duplicate()
	request["swaps"] = swaps
	var bill := ShipBill.quote(state, data, request)
	# The bill's own figures for the swaps it took.
	for line in lines:
		for b in bill["lines"]:
			if b["slot"] == line["slot"]:
				match String(b["kind"]):
					"part":
						line["part"] = float(b["credits"])
					"trade_in":
						line["trade_in"] = -float(b["credits"])
					"labour":
						line["labour"] = float(b["credits"])
		line["net"] = float(line["part"]) - float(line["trade_in"]) + float(line["labour"])
	var problems := []
	for problem in bill["problems"]:
		var text := String(problem)
		if text == "nothing to do" or text.begins_with("not sold here") or text == "that module does not fit that slot":
			continue
		if text == "sell some cargo first":
			text = "sell some cargo first: the new layout holds %.0f t" % ShipStats.cargo_capacity_t(bill["ship_after"], data)
		problems.append(text)
	var work := lines.filter(func(l): return l["why"] == "")
	return {"lines": lines, "total": float(bill["total"]) if not (work.is_empty() and extra.is_empty()) else 0.0,
		"trial": bill["ship_after"], "problems": problems, "bill": bill,
		"ok": problems.is_empty() and lines.all(func(l): return l["why"] == "") and (not work.is_empty() or not extra.is_empty()) and bool(bill["afford"])}


## {slot: "cargo.1", module: "cargo_pod_m", inspect?: bool}. The old module goes in
## part-exchange at its trade-in value (by condition, age and damage), and the yard charges
## fitting labour and takes days (data/ship_economy.json "refit"). A single swap; "refit"
## takes several at once. Both charge exactly what ShipBill.quote itemises.
func _install(command: Dictionary) -> String:
	return _commit({"swaps": [{"slot": command.get("slot", ""), "module": command.get("module", "")}], "inspect": bool(command.get("inspect", false))})


## {swaps: [{slot, module}], services: [{slot, level}], service_all, inspect}: see ShipBill.
func _refit(command: Dictionary) -> String:
	return _commit(command)


## {slot: "drive.0" | "all", level?: "service" | "overhaul"}.
func _service(command: Dictionary) -> String:
	return _service_level(command, String(command.get("level", "service")))


func _overhaul(command: Dictionary) -> String:
	return _service_level(command, "overhaul")


func _service_level(command: Dictionary, level: String) -> String:
	var slot: String = command.get("slot", "all")
	if slot == "all":
		return _commit({"service_all": level, "inspect": bool(command.get("inspect", false))})
	return _commit({"services": [{"slot": slot, "level": level}], "inspect": bool(command.get("inspect", false))})


## A Warrant of Fitness inspection: passes and issues a certificate, or lists what must be fixed.
func _inspect(_command: Dictionary) -> String:
	return _commit({"inspect": true})


func _commit(request: Dictionary) -> String:
	var s = sim().state
	var data = sim().data
	if s.location.get("status") != "docked":
		return "not docked"
	var bill: Dictionary = ShipBill.quote(s, data, request)
	if not bill["ok"]:
		return String(bill["problems"][0])
	if float(bill["total"]) > s.credits + 1e-6:
		return "not enough credits: %d cr needed" % int(ceil(float(bill["total"])))
	var before: Dictionary = s.ship
	s.ship = bill["ship_after"]
	s.credits -= float(bill["total"])
	if float(bill["voucher"]) > 0.0:
		var used := Favours.spend_yard_vouchers(s, data, String(bill["place"]), float(bill["voucher"]))
		sim().emit("voucher_used", {"spent": used, "place": bill["place"], "for": "yard work"})
	for swap in request.get("swaps", []):
		var net := 0.0
		for line in bill["lines"]:
			if line["slot"] == swap["slot"] and line["kind"] in ["part", "trade_in", "labour"]:
				net += float(line["credits"])
		sim().emit("module_installed", {"slot": swap["slot"], "module": swap["module"], "replaced": before["modules"].get(swap["slot"], ""), "credits": -net})
	for line in bill["lines"]:
		if line["kind"] in ["service", "overhaul"]:
			sim().emit("yard_work", {"slot": line["slot"], "level": line["kind"], "credits": -float(line["credits"])})
	if request.get("inspect", false):
		var w: Dictionary = s.ship["wof"]
		sim().emit("wof_issued" if w["result"] == "pass" else "wof_failed", {"issues": w["issues"], "valid_until_t": w["valid_until_t"], "credits": -float(bill["inspection"])})
		s.ship["wof_seen"] = ""
	sim().emit("yard_bill", {"total": bill["total"], "days": bill["days"]})
	# Days in port: game time passes (even if the pilot had paused), and the clock runs
	# every system. State is settled first, so what ticks sees the finished job.
	if float(bill["days"]) > 0.0:
		var was_paused: bool = s.paused
		s.paused = false
		sim().advance_game_time(float(bill["days"]) * 86400.0)
		s.paused = was_paused
	return ""
