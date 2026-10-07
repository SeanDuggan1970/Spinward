## Wear and small faults (data/ship_economy.json "wear" and "faults").
##
## Every module wears on what it actually does: drives on burn hours and a lit reactor,
## radiators on thermal load, cargo pods on hours spent loaded and on docking, landers on
## landings, rigs and sensors on site work, and everything a little on the hours in
## service. Docking and landing are counted from the ship's phase changing. Wear is
## apart from collision damage. A worn module gives a mild, honest performance loss
## (Condition.perf), and a tired one an hourly chance of a small fault: a warning and a
## few percent off until it is serviced. Never a lost ship.
extends "res://sim/systems/system.gd"

const Condition := preload("res://sim/condition.gd")
const ShipStats := preload("res://sim/ship_stats.gd")

var _rng := RandomNumberGenerator.new()


func tick(game_dt: float) -> void:
	var s = sim().state
	var ship: Dictionary = s.ship
	if ship.is_empty() or not ship.has("modules"):
		return
	var data = sim().data
	var e: Dictionary = data.ship_economy
	var w: Dictionary = e["wear"]
	for key in ["wear", "use", "faults", "warned"]:
		if not ship.has(key):
			ship[key] = {}
	var hours := game_dt / 3600.0
	var status: String = String(s.location.get("status", "docked"))
	# Phase changes: a dock, a landing.
	var prev: String = ship.get("last_status", status)
	var docks := 1 if (prev in ["approach", "transit"] and status == "docked") else 0
	var landings := 1 if (prev == "transit" and status == "on_site") else 0
	ship["last_status"] = status
	ship["hull_h"] = float(ship.get("hull_h", 0.0)) + hours

	var working: bool = status == "on_site" and not s.sites.get("work", {}).is_empty()
	var lit: bool = status in ["transit", "approach"] or working or String(s.power.get("reactor", "auto")) == "on"
	var docked: bool = status in ["docked", "lifeboat"]
	var in_service := hours * (float(w["docked_hours_frac"]) if docked else 1.0)
	var burn := hours * float(w["burn_frac"].get(status, 0.0))
	var heat := ShipStats.heat_mw(ship, data)
	var reject := ShipStats.reject_mw(ship, data)
	var heat_frac := 1.0 if status == "transit" else (0.3 if status == "approach" else (0.15 if working else 0.0))
	var load := minf(float(w["thermal_load_cap"]), heat * heat_frac / maxf(reject, 1e-9)) if lit else 0.0
	var drivers := {
		"hours": in_service, "burn_h": burn, "lit_h": hours if lit else 0.0, "thermal_h": hours * load,
		"loaded_h": hours * clampf(ShipStats.cargo_t(ship) / maxf(ShipStats.cargo_capacity_t(ship, data), 1e-9), 0.0, 1.0),
		"work_h": hours if working else 0.0, "dock": float(docks), "landing": float(landings),
	}
	var fault_cfg: Dictionary = e["faults"]
	var seeded := false
	var slots: Array = ship["modules"].keys()
	slots.sort()
	for slot in slots:
		var m: Dictionary = data.modules[ship["modules"][slot]]
		var rates: Dictionary = w["kinds"].get(m.get("kind", ""), w["kinds"]["default"])
		var mult := float(e["module_overrides"].get(ship["modules"][slot], {}).get("wear_mult", 1.0))
		var add := 0.0
		for driver in drivers:
			if not rates.has(driver):
				continue
			if driver == "burn_h" and not m.has("thrust_n"):
				continue
			if driver == "lit_h" and not m.has("reactor_kw"):
				continue
			add += float(rates[driver]) * float(drivers[driver])
		Condition.add_wear(ship, slot, add * mult)
		var use: Dictionary = ship["use"].get(slot, {})
		use["h"] = float(use.get("h", 0.0)) + hours
		use["burn_h"] = float(use.get("burn_h", 0.0)) + (burn if m.has("thrust_n") else 0.0)
		use["docks"] = int(use.get("docks", 0)) + docks
		use["landings"] = int(use.get("landings", 0)) + landings
		ship["use"][slot] = use
		var cond := Condition.condition(ship, slot)
		if cond < float(fault_cfg["warn_condition"]) and not ship["warned"].has(slot):
			ship["warned"][slot] = true
			sim().emit("condition_low", {"slot": slot, "module": m["name"], "condition": cond})
		# A tired module may throw a small fault. Randomness only from the shared sim generator.
		var below := float(fault_cfg["below"])
		if cond < below and hours > 0.0:
			if not seeded:
				_rng.seed = hash(s.seed) ^ 0xFA017
				_rng.state = s.rng_state
				seeded = true
			var p := float(fault_cfg["rate_per_hour"]) * pow((below - cond) / below, 2.0) * hours
			if _rng.randf() < p:
				_fault(ship, slot, m, fault_cfg)
	if seeded:
		s.rng_state = _rng.state


func _fault(ship: Dictionary, slot: String, m: Dictionary, cfg: Dictionary) -> void:
	var have := Condition.fault_loss(ship, slot)
	if have >= float(cfg["cap"]) - 1e-9:
		return
	var loss := minf(_rng.randf_range(float(cfg["loss_min"]), float(cfg["loss_max"])), float(cfg["cap"]) - have)
	var texts: Array = cfg["texts"].get(m.get("kind", ""), cfg["texts"]["default"])
	var text: String = texts[_rng.randi_range(0, texts.size() - 1)]
	ship["faults"][slot] = {"loss": have + loss, "text": text, "t": sim().state.time_s}
	sim().emit("module_fault", {"slot": slot, "module": m["name"], "loss": loss, "text": text})
