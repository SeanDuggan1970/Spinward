## The itemised bill for any proposed refit, service or inspection: a pure function of
## the state, the data and a request, so a GUI can show the bill before the player
## commits, and the shipyard commands charge exactly what it says.
##
## request = {
##   place: yard id (default: where the ship is docked),
##   swaps: [{slot, module}],               modules to fit (parts, trade-in, labour, days)
##   services: [{slot, level}],             level "service" or "overhaul"
##   service_all: "service" | "overhaul",   the same for every module not being swapped
##   inspect: bool,                         a Warrant of Fitness inspection after the work
## }
## quote() returns {
##   ok, problems: [text], place, lines: [{kind, slot, label, credits}],   credits > 0 is paid by the player
##   parts, trade_in, labour, service, overhaul, inspection, total,        total = what the player pays net
##   days,                                                                 days in port, game time passes
##   afford,                                                               total <= credits
##   wof: {before, after, would_pass, issues, voided_by_refit},
##   insurance: {state_before, state_after, premium_before, premium_after, plan, void_after},
##   ship_after,                                                           the ship as it would be
## }
extends RefCounted

const Condition := preload("res://sim/condition.gd")
const Fitness := preload("res://sim/fitness.gd")
const Insurance := preload("res://sim/insurance.gd")
const Perks := preload("res://sim/perks.gd")
const ShipStats := preload("res://sim/ship_stats.gd")


static func quote(state, data, request: Dictionary) -> Dictionary:
	var problems := []
	var place: String = request.get("place", state.location.get("place", ""))
	var yard: Dictionary = data.places.get(place, {})
	var at_yard: bool = "shipyard" in yard.get("services", [])
	if not request.has("place") and state.location.get("status") != "docked":
		problems.append("not docked at a shipyard")
	elif not at_yard:
		problems.append("no shipyard here")
	elif yard.has("foot_of"):
		problems.append("your ship is up at the port")
	var stock: Array = yard.get("shipyard_stock", []) if at_yard else []
	var trial: Dictionary = state.ship.duplicate(true)
	var lines := []
	var totals := {"parts": 0.0, "trade_in": 0.0, "labour": 0.0, "service": 0.0, "overhaul": 0.0, "inspection": 0.0}
	var job_days := []
	var touched := {}
	var voids := false
	var void_kinds: Array = Fitness.rules(data)["refit_voids"]

	for swap in request.get("swaps", []):
		var slot: String = swap.get("slot", "")
		var module_id: String = swap.get("module", "")
		if touched.has(slot):
			problems.append("slot %s is listed twice" % slot)
			continue
		touched[slot] = true
		if not module_id in stock:
			problems.append("not sold here: %s" % module_id)
			continue
		var module: Dictionary = data.modules[module_id]
		if not _fits(state, data, module, slot):
			problems.append("that module does not fit that slot")
			continue
		var old_id: String = trial["modules"].get(slot, "")
		if old_id == module_id:
			problems.append("already fitted")
			continue
		var parts: float = float(module["price"]) * Perks.yard_mult(state, place)
		var credit := Condition.trade_in(trial, slot, data) if old_id != "" else 0.0
		var rq := Condition.refit_quote(module_id, place, data)
		lines.append({"kind": "part", "slot": slot, "label": module["name"], "credits": parts})
		if old_id != "":
			lines.append({"kind": "trade_in", "slot": slot, "label": "%s, condition %d%%" % [data.modules[old_id]["name"], int(round(Condition.condition(trial, slot) * 100.0))], "credits": -credit})
		lines.append({"kind": "labour", "slot": slot, "label": "fitting %s" % module["name"], "credits": rq["labour_cr"]})
		totals["parts"] += parts
		totals["trade_in"] += credit
		totals["labour"] += rq["labour_cr"]
		job_days.append(rq["days"])
		if String(module.get("kind", "")) in void_kinds or (old_id != "" and String(data.modules[old_id].get("kind", "")) in void_kinds):
			voids = true
		trial["modules"][slot] = module_id
		Condition.reset_slot(trial, slot)
		if trial.has("damage"):
			trial["damage"].erase(slot)

	var work := []
	for sv in request.get("services", []):
		work.append([String(sv.get("slot", "")), String(sv.get("level", "service"))])
	if request.get("service_all", "") != "":
		var all_slots: Array = trial["modules"].keys()
		all_slots.sort()
		for slot in all_slots:
			var listed := touched.has(slot)
			for w in work:
				listed = listed or w[0] == slot
			if not listed:
				work.append([slot, String(request["service_all"])])
	var did_work := false
	for w in work:
		var slot: String = w[0]
		var level: String = w[1]
		if not trial["modules"].has(slot) or not level in ["service", "overhaul"]:
			problems.append("cannot %s %s" % [level, slot])
			continue
		if touched.has(slot):
			problems.append("slot %s is listed twice" % slot)
			continue
		touched[slot] = true
		var wq := Condition.work_quote(trial, slot, level, place, data)
		if float(wq["cost"]) <= 0.0:
			continue
		var name: String = data.modules[trial["modules"][slot]]["name"]
		lines.append({"kind": level, "slot": slot, "label": "%s of %s, condition %d%% to %d%%" % [level, name, int(round(Condition.condition(trial, slot) * 100.0)), int(round(float(wq["to"]) * 100.0))], "credits": wq["cost"]})
		totals[level] += wq["cost"]
		job_days.append(wq["days"])
		Condition.apply_work(trial, slot, level, data)
		did_work = true

	var days := Condition.batch_days(job_days, data) if not job_days.is_empty() else 0.0
	var inspect: bool = bool(request.get("inspect", false))
	var w_before := Fitness.status(state, data)
	if voids:
		Fitness.void_for_refit(trial, state.time_s, data)
	var would := Fitness.inspect(trial, data)
	if inspect:
		var rates := Condition.yard_rates(place, data)
		var fee := ceilf(float(Fitness.rules(data)["inspection_cr"]) * float(rates["inspection"]))
		lines.append({"kind": "inspection", "slot": "", "label": "Warrant of Fitness inspection", "credits": fee})
		totals["inspection"] = fee
		days += float(Fitness.rules(data)["inspection_days"])
		Fitness.certify(trial, state.time_s + days * 86400.0, data)
	if lines.is_empty() and problems.is_empty():
		problems.append("nothing to do")
	var total: float = totals["parts"] - totals["trade_in"] + totals["labour"] + totals["service"] + totals["overhaul"] + totals["inspection"]
	if ShipStats.cargo_t(trial) > ShipStats.cargo_capacity_t(trial, data) + 1e-9:
		problems.append("sell some cargo first")
	trial["fuel_t"] = minf(float(trial.get("fuel_t", 0.0)), ShipStats.fuel_capacity_t(trial, data))

	# What it does to the Warrant of Fitness and to the insurance.
	var probe = _Probe.new(state, trial)
	var w_after := Fitness.status(probe, data)
	var ins_before := Insurance.status(state, data)
	var ins_after := Insurance.status(probe, data)
	var plan_id: String = state.insurance.get("policy", {}).get("plan", "")
	var prem_before := float(Insurance.premium(state, data, plan_id)["per_period"]) if plan_id != "" else 0.0
	var prem_after := float(Insurance.premium(state, data, plan_id, trial)["per_period"]) if plan_id != "" else 0.0
	return {
		"ok": problems.is_empty(), "problems": problems, "place": place, "lines": lines,
		"parts": totals["parts"], "trade_in": totals["trade_in"], "labour": totals["labour"], "service": totals["service"],
		"overhaul": totals["overhaul"], "inspection": totals["inspection"], "total": total, "days": days,
		"afford": total <= state.credits + 1e-6,
		"wof": {"before": w_before, "after": w_after, "would_pass": would["pass"], "issues": would["issues"], "voided_by_refit": voids and not inspect},
		"insurance": {"state_before": ins_before["state"], "state_after": ins_after["state"], "plan": plan_id, "premium_before": prem_before, "premium_after": prem_after, "void_after": ins_after["state"] == "void"},
		"ship_after": trial,
	}


static func _fits(state, data, module: Dictionary, slot: String) -> bool:
	var kind := slot.split(".")[0]
	if not kind in module.get("mounts", [module["kind"]]):
		return false
	var spine: Dictionary = data.modules[data.ships[state.ship["hull"]]["spine"]]
	var n := int(spine["slots"].get(kind, 0))
	for i in n:
		if slot == "%s.%d" % [kind, i]:
			return true
	return false


## A stand-in for the game state with a different ship (what-if quotes): the same
## clock, credits, insurance and location, and the proposed ship.
class _Probe extends RefCounted:
	var time_s: float
	var credits: float
	var insurance: Dictionary
	var ship: Dictionary
	var location: Dictionary

	func _init(state, trial: Dictionary) -> void:
		time_s = state.time_s
		credits = state.credits
		insurance = state.insurance
		location = state.location
		ship = trial
