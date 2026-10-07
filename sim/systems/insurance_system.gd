## Insurance policies over time and the commands to buy one (sim/insurance.gd).
##
## state.insurance = {policy, claims, loan_cr}. A policy is paid by the period; with
## auto_renew it is renewed when the ship is docked and the credits cover it, otherwise
## it lapses (and pays nothing). The Commons fallback loan (what a ship lost with no cover
## owes) is repaid at a gentle rate whenever the pilot has credits above a floor.
extends "res://sim/systems/system.gd"

const Insurance := preload("res://sim/insurance.gd")

const DAY := 86400.0


func setup(owner) -> void:
	super.setup(owner)
	owner.register("buy_insurance", _buy)
	owner.register("cancel_insurance", _cancel)


func start_game() -> void:
	var s = sim().state
	var data = sim().data
	var st: Dictionary = data.ship_economy["start"]
	s.insurance = {"policy": {
		"plan": st["insurance_plan"], "start_t": s.time_s,
		"paid_until_t": s.time_s + float(st["insurance_paid_days"]) * DAY, "auto_renew": true,
	}, "claims": [], "loan_cr": 0.0}


func tick(game_dt: float) -> void:
	var s = sim().state
	var data = sim().data
	if s.insurance.is_empty():
		# An old save: the same starter cover a new game gets.
		start_game()
	var pol: Dictionary = s.insurance.get("policy", {})
	if not pol.is_empty():
		var window: float = float(Insurance.rules(data)["renew_window_days"]) * DAY
		var docked: bool = s.location.get("status") == "docked"
		if docked and bool(pol.get("auto_renew", false)) and float(pol["paid_until_t"]) - s.time_s <= window:
			var prem := float(Insurance.premium(s, data, pol["plan"])["per_period"])
			if s.credits >= prem:
				s.credits -= prem
				s.stats["premiums_paid"] = float(s.stats.get("premiums_paid", 0.0)) + prem
				pol["paid_until_t"] = maxf(float(pol["paid_until_t"]), s.time_s) + float(Insurance.rules(data)["period_days"]) * DAY
				sim().emit("insurance_renewed", {"plan": pol["plan"], "premium": prem})
		var was: String = String(s.insurance.get("seen", ""))
		var st := Insurance.status(s, data)
		if st["state"] != was:
			s.insurance["seen"] = st["state"]
			if st["state"] in ["lapsed", "void"]:
				sim().emit("insurance_" + String(st["state"]), {"plan": pol["plan"], "reason": st["reason"]})
	var loan := float(s.insurance.get("loan_cr", 0.0))
	if loan > 0.0:
		var fb: Dictionary = Insurance.rules(data)["fallback"]
		var pay := minf(loan, minf(float(fb["loan_repay_cr_per_day"]) * game_dt / DAY, maxf(0.0, s.credits - float(fb["loan_keep_cr"]))))
		if pay > 0.0:
			s.credits -= pay
			s.insurance["loan_cr"] = loan - pay
			if loan - pay <= 1e-6:
				s.insurance["loan_cr"] = 0.0
				sim().emit("loan_repaid", {})


## {plan, auto_renew?}: buy (or renew, or change to) a policy at any port.
func _buy(command: Dictionary) -> String:
	var s = sim().state
	var data = sim().data
	if s.location.get("status") != "docked":
		return "not docked"
	var id: String = command.get("plan", "")
	var why := Insurance.buy_block(s, data, id)
	if why != "":
		return why
	var prem := float(Insurance.premium(s, data, id)["per_period"])
	if prem > s.credits + 1e-6:
		return "the premium is %d cr" % int(prem)
	var old: Dictionary = s.insurance.get("policy", {})
	# Renewing the same plan before it runs out adds a period; anything else starts afresh.
	var start: float = s.time_s
	var base: float = s.time_s
	if not old.is_empty() and old["plan"] == id and float(old["paid_until_t"]) > s.time_s:
		base = float(old["paid_until_t"])
		start = float(old.get("start_t", s.time_s))
	s.credits -= prem
	s.stats["premiums_paid"] = float(s.stats.get("premiums_paid", 0.0)) + prem
	s.insurance["policy"] = {"plan": id, "start_t": start, "paid_until_t": base + float(Insurance.rules(data)["period_days"]) * DAY, "auto_renew": bool(command.get("auto_renew", old.get("auto_renew", true)))}
	s.insurance["seen"] = ""
	sim().emit("insurance_bought", {"plan": id, "premium": prem})
	return ""


func _cancel(_command: Dictionary) -> String:
	var s = sim().state
	if s.insurance.get("policy", {}).is_empty():
		return "no policy"
	s.insurance["policy"] = {}
	sim().emit("insurance_cancelled", {})
	return ""
