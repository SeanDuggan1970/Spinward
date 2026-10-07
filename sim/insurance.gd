## Ship insurance: pure functions of state and data/ship_economy.json "insurance".
##
## state.insurance = {policy: {plan, start_t, paid_until_t, auto_renew} | {}, claims: [{t, kind, paid}],
## loan_cr}. A policy is paid by the period; it pays out nothing when it has lapsed or
## is void (no valid Warrant of Fitness, if data says so). With no working cover a lost
## ship still comes back as a Commons hull on a loan (see damage_system), so a pilot is
## never stuck for good.
extends RefCounted

const Condition := preload("res://sim/condition.gd")
const Fitness := preload("res://sim/fitness.gd")


static func rules(data) -> Dictionary:
	return data.ship_economy["insurance"]


static func plan(data, id: String) -> Dictionary:
	return rules(data)["plans"].get(id, {})


## The excess on a total loss for a plan (credits).
static func excess(plan_id: String, data) -> float:
	return float(data.balance["damage"]["insurance_excess"]) * float(plan(data, plan_id).get("excess_mult", 1.0))


## What a collision repair costs the player before the insurer pays (credits).
static func collision_excess(plan_id: String, data) -> float:
	return excess(plan_id, data) * float(plan(data, plan_id).get("collision_excess_mult", 0.0))


## Claims still counting against the premium.
static func recent_claims(state, data) -> int:
	var horizon: float = float(rules(data)["claim_decay_days"]) * 86400.0
	var n := 0
	for c in state.insurance.get("claims", []):
		if state.time_s - float(c["t"]) <= horizon:
			n += 1
	return n


## Premium for one period on `ship` under plan `plan_id`:
## {per_period, insured_value, risk_mult, claims_mult, claims}.
static func premium(state, data, plan_id: String, ship: Dictionary = {}) -> Dictionary:
	var r := rules(data)
	var s: Dictionary = ship if not ship.is_empty() else state.ship
	var value := Condition.insured_value(s, data)
	var risk := 1.0 + float(r["risk_wear_weight"]) * (1.0 - Condition.mean_condition(s))
	var n := recent_claims(state, data)
	var claims_mult := minf(float(r["max_claim_mult"]), 1.0 + float(r["claim_surcharge"]) * n)
	var per := maxf(float(r["min_premium_cr"]), value * float(plan(data, plan_id).get("rate", 0.0)) * risk * claims_mult)
	return {"per_period": ceilf(per), "insured_value": value, "risk_mult": risk, "claims_mult": claims_mult, "claims": n}


## {state: none | active | lapsed | void, plan, covers, reason, paid_until_t, days_left, excess}.
## "void": paid up, but the Warrant of Fitness is not valid (when data says that voids it).
static func status(state, data) -> Dictionary:
	var pol: Dictionary = state.insurance.get("policy", {})
	if pol.is_empty():
		return {"state": "none", "plan": "", "covers": [], "reason": "no policy", "paid_until_t": 0.0, "days_left": 0.0, "excess": 0.0}
	var id: String = pol["plan"]
	var p := plan(data, id)
	var days_left: float = (float(pol["paid_until_t"]) - state.time_s) / 86400.0
	var out := {"plan": id, "covers": p.get("covers", []).duplicate(), "paid_until_t": float(pol["paid_until_t"]), "days_left": days_left, "excess": excess(id, data), "reason": ""}
	if days_left <= 0.0:
		out["state"] = "lapsed"
		out["covers"] = []
		out["reason"] = "the policy lapsed: renew it at any port"
	elif bool(Fitness.rules(data)["effects"].get("insurance_void", false)) and not Fitness.valid(state, data):
		out["state"] = "void"
		out["covers"] = []
		out["reason"] = "void without a valid Warrant of Fitness"
	else:
		out["state"] = "active"
	return out


static func covers(state, data, kind: String) -> bool:
	return kind in status(state, data)["covers"]


## A total loss: what the insurer pays and what the excess costs, given the lost ship and
## its replacement. {cover: plan id or "", excess, payout, cargo_payout, net}.
static func total_loss_settlement(state, data, lost: Dictionary, replacement: Dictionary) -> Dictionary:
	var st := status(state, data)
	if not "total_loss" in st["covers"]:
		return {"cover": "", "excess": 0.0, "payout": 0.0, "cargo_payout": 0.0, "net": 0.0, "reason": st["reason"]}
	var p := plan(data, st["plan"])
	var payout := maxf(0.0, Condition.insured_value(lost, data) - Condition.insured_value(replacement, data)) * float(p["payout_frac"])
	var cargo := 0.0
	if "cargo" in st["covers"]:
		for g in lost.get("cargo_paid", {}):
			cargo += float(lost["cargo_paid"][g])
		cargo *= float(p["cargo_payout_frac"])
	return {"cover": st["plan"], "excess": st["excess"], "payout": payout, "cargo_payout": cargo, "net": payout + cargo - float(st["excess"]), "reason": ""}


## A yard repair costing `cost`: {player, insurer, claim: bool}. Collision cover pays what is
## above its excess.
static func repair_split(state, data, cost: float) -> Dictionary:
	var st := status(state, data)
	if not "collision" in st["covers"]:
		return {"player": cost, "insurer": 0.0, "claim": false}
	var own := minf(cost, collision_excess(st["plan"], data))
	return {"player": own, "insurer": cost - own, "claim": cost - own > 0.0}


static func record_claim(state, kind: String, paid: float) -> void:
	if not state.insurance.has("claims"):
		state.insurance["claims"] = []
	state.insurance["claims"].append({"t": state.time_s, "kind": kind, "paid": paid})


## Why a plan can't be bought for this ship now, or "".
static func buy_block(state, data, plan_id: String) -> String:
	if plan(data, plan_id).is_empty():
		return "no such plan"
	if "collision" in plan(data, plan_id).get("covers", []):
		var limit := float(rules(data)["buy_max_damage"])
		for slot in state.ship.get("damage", {}):
			if float(state.ship["damage"][slot]) > limit:
				return "the insurer won't cover collision damage on a ship that is already damaged: repair it first"
	return ""
