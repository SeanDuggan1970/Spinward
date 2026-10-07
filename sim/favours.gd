## Favours: rewards in kind, hitchhikers and engine tunes (data/favours.json). Pure
## helpers shared by the contract system (which makes and pays offers in kind), the
## favour system (vouchers, hitchhikers), and the economy and travel systems (which
## ask what vouchers and crew change about fuel, docking and the burn).
##
## state.favours: {vouchers: [{id, form, operator, expires_t, value_cr | discount | tonnes}],
## waiting: {place: [hiker]}, next_t: {place: t}, last_dock, seq}. Hitchhikers aboard
## are in ship["hikers"]; engine tunes in ship["tunes"] (ShipStats reads them).
extends RefCounted

const ShipStats := preload("res://sim/ship_stats.gd")
const Navigation := preload("res://sim/navigation.gd")
const Perks := preload("res://sim/perks.gd")
const DamageSystem := preload("res://sim/systems/damage_system.gd")

const DAY := 86400.0


static func empty() -> Dictionary:
	return {"vouchers": [], "waiting": {}, "next_t": {}, "last_dock": "", "seq": 0}


## A save from before favours has none: give it the empty set.
static func ensure(state) -> void:
	if state.favours.is_empty():
		state.favours = empty()


## The operator a place works for (as Contracts.client_of; not shared to keep the preloads one-way).
static func operator_of(data, place: String) -> String:
	return String(data.places[place].get("operator", "Independent"))


## Ports an operator runs, optionally only those with a service ("shipyard", "refuel").
static func ports_of(data, operator: String, service: String = "") -> Array:
	var out := []
	for id in data.places:
		var place: Dictionary = data.places[id]
		if String(place.get("operator", "Independent")) == operator and (service == "" or service in place.get("services", [])):
			out.append(id)
	out.sort()
	return out


static func yard_names(data, operator: String) -> Array:
	return ports_of(data, operator, "shipyard").map(func(p): return String(data.places[p]["name"]))


# ---- Offers in kind -----------------------------------------------------------------

## Maybe turn part of an offer's reward into something in kind. Always draws the same
## number of values up to the first roll, so a replay stays in step. Sets offer["in_kind"]
## ({form, operator, value_cr, ...}) and lowers offer["reward"] (the cash part).
static func maybe_in_kind(data, rng: RandomNumberGenerator, offer: Dictionary) -> void:
	var cfg: Dictionary = data.favours.get("in_kind", {})
	if cfg.is_empty():
		return
	var chance := float(cfg["chance"].get(offer["kind"], 0.0)) * float(cfg["client_mult"].get(offer["client"], 1.0))
	if rng.randf() >= chance:
		return
	var forms: Dictionary = cfg["forms"]
	var weights := {}
	var total := 0.0
	for f in forms:
		if f == "yard" and yard_names(data, offer["client"]).is_empty():
			continue
		var w := float(cfg.get("client_forms", {}).get(offer["client"], {}).get(f, forms[f]["weight"]))
		weights[f] = w
		total += w
	if total <= 0.0:
		return
	var roll := rng.randf() * total
	var form := ""
	for f in weights:
		form = f
		roll -= float(weights[f])
		if roll <= 0.0:
			break
	var spec: Dictionary = forms[form]
	var reward := float(offer["reward"])
	var share := rng.randf_range(float(cfg["kind_share"][0]), float(cfg["kind_share"][1]))
	var target := reward * share
	var ik := {"form": form, "operator": offer["client"]}
	var value := 0.0
	match form:
		"yard":
			value = snappedf(target, 50.0)
			ik["expires_days"] = snappedf(_range(rng, spec["expires_days"]), 1.0)
		"docking", "fuel":
			var days := clampf(roundf(target / float(spec["value_per_unit"])), float(spec["unit_range"][0]), float(spec["unit_range"][1]))
			ik["days"] = days
			ik["discount"] = float(spec["discount"])
			value = days * float(spec["value_per_unit"])
		"refuel":
			var t := clampf(snappedf(target / float(spec["value_per_unit"]), 0.5), float(spec["unit_range"][0]), float(spec["unit_range"][1]))
			ik["tonnes"] = t
			ik["expires_days"] = snappedf(_range(rng, spec["expires_days"]), 1.0)
			value = t * float(spec["value_per_unit"])
		"favour":
			var rep := clampf(roundf(target / float(spec["value_per_unit"])), float(spec["unit_range"][0]), float(spec["unit_range"][1]))
			ik["rep"] = rep
			value = rep * float(spec["value_per_unit"])
		"tune":
			var ids: Array = data.favours["tunes"].keys()
			ids.sort()
			ik["tune"] = ids[rng.randi() % ids.size()]
			value = float(data.favours["tunes"][ik["tune"]]["value_cr"])
	if value < float(cfg["min_value_cr"]):
		return
	ik["value_cr"] = value
	var cash := maxf(reward * float(cfg["min_cash_share"]), reward - value * float(cfg["cash_offset"]))
	offer["reward"] = snappedf(cash, 50.0)
	offer["in_kind"] = ik


static func _range(rng: RandomNumberGenerator, pair: Array) -> float:
	return rng.randf_range(float(pair[0]), float(pair[1]))


## The offer's in-kind reward in words, with its credit value beside it.
static func describe(data, ik: Dictionary) -> String:
	var op: String = ik["operator"]
	var yards := ", ".join(yard_names(data, op))
	var text := ""
	match ik["form"]:
		"yard":
			text = "a repair voucher at %s yards (%s), good for %d days" % [op, yards, int(ik.get("expires_days", 0))]
		"docking":
			text = "free docking tugs at %s ports for %d days" % [op, int(ik["days"])]
		"fuel":
			text = "%d%% off propellant at %s ports for %d days" % [int(round(float(ik["discount"]) * 100.0)), op, int(ik["days"])]
		"refuel":
			text = "%.1f t of free propellant at %s ports (%d days)" % [float(ik["tonnes"]), op, int(ik.get("expires_days", 0))]
		"favour":
			text = "a favour owed: %s will think the better of you" % op
		"tune":
			text = "an engine tune: %s (%s)" % [tune_name(data, ik["tune"]), tune_effects(data, ik["tune"])]
	return "%s  ·  worth about %d cr" % [text, int(round(float(ik["value_cr"])))]


static func tune_name(data, id: String) -> String:
	return String(data.favours["tunes"][id]["name"])


## "+3% thrust, +2% heat" for a tune.
static func tune_effects(data, id: String) -> String:
	var spec: Dictionary = data.favours["tunes"][id]
	var bits := []
	for pair in [["thrust_pct", "thrust"], ["isp_pct", "fuel efficiency"], ["heat_pct", "heat"], ["wear_pct", "wear"]]:
		var v := float(spec.get(pair[0], 0.0))
		if absf(v) > 1e-9:
			bits.append("%+d%% %s" % [int(round(v * 100.0)), pair[1]])
	return ", ".join(bits)


## Pay out a delivered job's in-kind reward. scale is 1 on time, or the late pay
## fraction. Returns {form, text, rep, credits}: rep is for the caller to add to the
## client's standing; credits is cash in lieu (a tune the ship cannot take, or a tune
## on a late delivery). Vouchers and tunes are put straight into the state.
static func grant(state, data, job: Dictionary, scale: float) -> Dictionary:
	var ik: Dictionary = job.get("in_kind", {})
	if ik.is_empty():
		return {}
	ensure(state)
	var out := {"form": ik["form"], "text": "", "rep": 0.0, "credits": 0.0}
	var cfg: Dictionary = data.favours["in_kind"]
	var op: String = ik["operator"]
	match ik["form"]:
		"yard":
			_add_voucher(state, {"form": "yard", "operator": op, "value_cr": float(ik["value_cr"]) * scale,
				"expires_t": state.time_s + float(ik["expires_days"]) * DAY})
			out["text"] = "%s gave you a repair voucher worth %d cr." % [op, int(float(ik["value_cr"]) * scale)]
		"docking", "fuel":
			var days := maxf(1.0, roundf(float(ik["days"]) * scale))
			_add_voucher(state, {"form": ik["form"], "operator": op, "discount": float(ik["discount"]), "expires_t": state.time_s + days * DAY})
			out["text"] = "%s: %s at their ports for %d days." % [op, "free docking tugs" if ik["form"] == "docking" else "%d%% off propellant" % int(round(float(ik["discount"]) * 100.0)), int(days)]
		"refuel":
			var t := snappedf(float(ik["tonnes"]) * scale, 0.1)
			_add_voucher(state, {"form": "refuel", "operator": op, "tonnes": t, "expires_t": state.time_s + float(ik["expires_days"]) * DAY})
			out["text"] = "%s will refuel you for free: %.1f t at their ports." % [op, t]
		"favour":
			out["rep"] = float(ik["rep"]) * scale
			out["text"] = "%s owes you a favour." % op
		"tune":
			var value := float(ik["value_cr"])
			if scale < 1.0:
				out["credits"] = value * scale
				out["text"] = "Late, so %s paid the tune's value in credits instead." % op
			else:
				var why := install_tune(state.ship, data, ik["tune"], "%s yards, for a job well done" % op, state.time_s)
				if why == "":
					out["text"] = "%s's yard fitted a tune to your drive: %s (%s)." % [op, tune_name(data, ik["tune"]), tune_effects(data, ik["tune"])]
				else:
					out["credits"] = value * float(cfg["cash_offset"])
					out["text"] = "%s could not tune your drive (%s), so paid cash instead." % [op, why]
	return out


static func _add_voucher(state, v: Dictionary) -> void:
	state.favours["seq"] = int(state.favours["seq"]) + 1
	v["id"] = int(state.favours["seq"])
	state.favours["vouchers"].append(v)


static func live_vouchers(state, form: String, operator: String) -> Array:
	return state.favours.get("vouchers", []).filter(func(v): return v["form"] == form and v["operator"] == operator and float(v["expires_t"]) > state.time_s)


## What vouchers change about buying propellant at a port: {mult, free_t}.
static func fuel_terms(state, data, place: String) -> Dictionary:
	var op := operator_of(data, place)
	var best := 0.0
	for v in live_vouchers(state, "fuel", op):
		best = maxf(best, float(v["discount"]))
	var free := 0.0
	for v in live_vouchers(state, "refuel", op):
		free += float(v["tonnes"])
	return {"mult": 1.0 - best, "free_t": free}


## Use up free refuelling (soonest-expiring first) for tonnes taken at a port.
static func spend_free_fuel(state, data, place: String, tonnes: float) -> void:
	var live := live_vouchers(state, "refuel", operator_of(data, place))
	live.sort_custom(func(a, b): return float(a["expires_t"]) < float(b["expires_t"]))
	var left := tonnes
	for v in live:
		var take := minf(left, float(v["tonnes"]))
		v["tonnes"] = float(v["tonnes"]) - take
		left -= take
		if float(v["tonnes"]) <= 1e-6:
			state.favours["vouchers"].erase(v)


## What the auto-dock tug costs, as a multiple of the usual fee: a docking pass at this
## port's operator and a pilot aboard both cut it.
static func dock_mult(state, data, place: String) -> float:
	var best := 0.0
	for v in live_vouchers(state, "docking", operator_of(data, place)):
		best = maxf(best, float(v["discount"]))
	return (1.0 - best) * ShipStats.crew_mult(state.ship, data, "tug_mult")


## The propellant a planned burn really takes, after a navigator's trims.
static func route_fuel(ship: Dictionary, data, fuel_t: float) -> float:
	return fuel_t * (1.0 - clampf(ShipStats.crew_sum(ship, data, "fuel_trim"), 0.0, 0.5))


## PLUG-IN POINT for maintenance and repairs: spend up to value_cr of service at a
## yard, mending damage by the repair rates in balance.json "damage". Returns the credits
## of service used. The maintenance work can extend what this mends (wear, warrant of
## fitness) here without touching voucher bookkeeping.
static func repair_service(state, data, value_cr: float) -> float:
	var cost := DamageSystem.repair_cost(state, data)
	if cost <= 0.0 or value_cr <= 0.0:
		return 0.0
	var share := minf(1.0, value_cr / cost)
	var patch := float(data.balance["damage"]["patch_max"])
	var full: bool = state.location.get("status") == "docked" and "shipyard" in data.places[state.location["place"]].get("services", [])
	for slot in state.ship.get("damage", {}).keys():
		var d := float(state.ship["damage"][slot])
		var fix := d if full else maxf(0.0, d - patch)
		var left := d - fix * share
		if left <= 0.0005:
			state.ship["damage"].erase(slot)
		else:
			state.ship["damage"][slot] = left
	return cost * share


# ---- Engine tunes ---------------------------------------------------------------------

## Fit a tune to the least-tuned drive that can take it. Returns "" or why not.
static func install_tune(ship: Dictionary, data, id: String, source: String, t: float) -> String:
	if not data.favours.get("tunes", {}).has(id):
		return "no such tune"
	var slots := []
	for slot in ship.get("modules", {}):
		var m: Dictionary = data.modules[ship["modules"][slot]]
		if m.has("thrust_n") and m.has("isp_s"):
			slots.append(slot)
	if slots.is_empty():
		return "this ship has no drive to tune"
	slots.sort()
	var cap := int(data.favours.get("max_tunes_per_drive", 2))
	var best := ""
	var best_n := 1 << 30
	for slot in slots:
		var mine := ShipStats.active_tunes(ship, data).filter(func(x): return x["slot"] == slot)
		if mine.any(func(x): return x["id"] == id) or mine.size() >= cap:
			continue
		if mine.size() < best_n:
			best = slot
			best_n = mine.size()
	if best == "":
		return "every drive already has that tune or is fully tuned"
	if not ship.has("tunes"):
		ship["tunes"] = []
	ship["tunes"].append({"id": id, "slot": best, "module": ship["modules"][best], "source": source, "t": t})
	return ""


# ---- Hitchhikers ----------------------------------------------------------------------

## Someone at `place` asking for a ride. All randomness comes from rng.
static func make_hiker(data, state, rng: RandomNumberGenerator, place: String) -> Dictionary:
	var cfg: Dictionary = data.favours["hitchhikers"]
	var trades: Dictionary = cfg["trades"]
	var keys: Array = trades.keys()
	keys.sort()
	var total := 0.0
	for k in keys:
		total += float(trades[k]["weight"])
	var roll := rng.randf() * total
	var trade := ""
	for k in keys:
		trade = k
		roll -= float(trades[k]["weight"])
		if roll <= 0.0:
			break
	var names: Dictionary = cfg["names"]
	var hname := "%s %s" % [names["first"][rng.randi() % names["first"].size()], names["last"][rng.randi() % names["last"].size()]]
	var open: Array = data.places.keys().filter(func(p): return p != place and Perks.place_open(state, data, p))
	var local: Array = open.filter(func(p): return Navigation.frame_body(data, place, p) != "sun")
	var far: Array = open.filter(func(p): return Navigation.frame_body(data, place, p) == "sun")
	var pool := far if (local.is_empty() or (rng.randf() < float(cfg["long_haul_chance"]) and not far.is_empty())) else local
	pool.sort()
	var to: String = pool[rng.randi() % pool.size()]
	var spec: Dictionary = trades[trade]
	var fare := snappedf(rng.randf_range(float(cfg["fare_cr"][0]), float(cfg["fare_cr"][1])), float(cfg["fare_step_cr"]))
	var lines := {}
	for stage in ["board", "mid", "leave"]:
		var options: Array = spec[stage]
		lines[stage] = String(options[rng.randi() % options.size()]).replace("{name}", hname).replace("{to}", String(data.places[to]["name"]))
	var gift := ""
	if spec.has("tune_ids") and rng.randf() < float(spec.get("tune_chance", 0.0)):
		gift = spec["tune_ids"][rng.randi() % spec["tune_ids"].size()]
	var wait: Array = cfg["wait_days"]
	state.favours["seq"] = int(state.favours["seq"]) + 1
	return {"id": int(state.favours["seq"]), "name": hname, "trade": trade, "from": place, "to": to, "fare": fare, "gift": gift,
		"lines": lines, "expires_t": state.time_s + rng.randf_range(float(wait[0]), float(wait[1])) * DAY, "mid_sent": false}


## Free berths aboard (hitchhikers and contract passengers both sit in them).
static func free_berths(state, data) -> int:
	return ShipStats.berths(state.ship, data) - int(state.ship.get("passengers", 0))


static func hiker_blurb(data, hiker: Dictionary) -> String:
	var spec: Dictionary = data.favours["hitchhikers"]["trades"][hiker["trade"]]
	return "%s, %s: %s" % [hiker["name"], spec["label"], spec["blurb"]]
