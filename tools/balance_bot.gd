## Headless balance bot. Plays the trading game through the same commands as the
## player and writes docs/balance/report.md.
##   godot --headless --path . --script res://tools/balance_bot.gd -- [days=180] [upgrade=1] [seeds=5]
##        [out=res://docs/balance/report.md] [upkeep=1] [credits=N] [fit=slot:module,slot:module] [legs=1] [nofleets=a,b] [take=0.5]
## upkeep: 1 (default) the bot keeps its ship: at a yard it services modules under 55% condition,
## overhauls those under 30%, and renews its Warrant of Fitness inside 14 days of expiry;
## 0 lets wear, faults and the WoF run down (what neglect costs); 2 only renews the WoF and
## overhauls what the inspection would fail (a lazy but legal pilot). Insurance renews itself.
## jobs=1: takes courier/package jobs on the board bound for the leg's destination, and spends
## yard vouchers on service when at a yard. hikers=1: takes any hitchhiker with a free berth
## (use fit=cargo.1:passenger_berths to have berths). seed0=N: first seed (to run seeds in parallel
## processes). tsv=1: print one machine-readable ECON_RUN line per seed.
## out: where the report goes (use another path to keep report.md). credits: start credits.
## fit: free module swaps before the run, e.g. fit=cargo.0:cargo_pod_m,drive.0:pathfinder_mk2
## (to measure what a module is worth: run with and without it). legs=1: print every leg.
## nofleets: NPC fleets (data/npcs.json ids) to leave out, to measure what they do to the player.
## take: the share of a port's stock the bot will buy in one go (0.5: it leaves the rest for the market).
## Runs one game per seed (NPC choices differ per seed) and reports the spread; the
## detailed sections come from the first seed.
##
## Strategy (deliberately simple and greedy, so the numbers are a floor on what a
## thoughtful player earns): at each dock, sell everything, refuel, then pick the
## single-good trade with the best profit per game day. If nothing pays, reposition
## to wherever the best next trade starts. Optionally buys upgrades from a fixed list.
extends SceneTree

const Sim := preload("res://sim/sim.gd")
const Market := preload("res://sim/market.gd")
const Navigation := preload("res://sim/navigation.gd")
const ShipStats := preload("res://sim/ship_stats.gd")
const ShipyardSystem := preload("res://sim/systems/shipyard_system.gd")
const ShipBill := preload("res://sim/ship_bill.gd")
const Condition := preload("res://sim/condition.gd")
const Fitness := preload("res://sim/fitness.gd")
const Favours := preload("res://sim/favours.gd")

const DAY := 86400.0
## Upgrade wish list in order, with a cash reserve kept for trading.
const UPGRADES := [
	["cargo.0", "cargo_pod_m"], ["cargo.1", "cargo_pod_m"], ["tank.0", "tank_m"],
	["radiator.0", "radiator_panel_l"], ["radiator.1", "radiator_panel_l"], ["drive.0", "pathfinder_mk2"],
	["cargo.0", "cargo_pod_l"], ["cargo.1", "cargo_pod_l"],
]
const UPGRADE_RESERVE := 15000.0

var sim: Sim
var log_rows: Array = []
var route_profit: Dictionary = {}
var milestones: Array = []
var credit_curve: Array = []
var first_upgrade_day := -1.0
var show_legs := false
var take_share := 0.5
var report_path := "res://docs/balance/report.md"
var upkeep_on := true
var upkeep_spent := 0.0
var yard_days := 0.0
var upkeep_mode := 1
var jobs_on := false
var hikers_on := false
var cost := {}
var counts := {}
var min_credits := 0.0
var voucher_cr := 0.0
var kind_value := {}
var job_values := {}
var days_total := 0.0


func _initialize() -> void:
	var args := {"days": "180", "upgrade": "1", "out": "res://docs/balance/report.md", "credits": "", "fit": "", "legs": "0", "nofleets": "", "take": "0.5", "upkeep": "1", "jobs": "0", "hikers": "0", "seed0": "1", "tsv": "0"}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	var days := float(args["days"])
	var upgrade: bool = args["upgrade"] == "1"
	var seeds := int(args.get("seeds", "5"))
	show_legs = args["legs"] == "1"
	take_share = float(args["take"])
	report_path = args["out"]
	upkeep_mode = int(args["upkeep"])
	upkeep_on = upkeep_mode != 0
	jobs_on = args["jobs"] == "1"
	hikers_on = args["hikers"] == "1"
	days_total = days
	var runs := []
	var detail := {}
	for seed_value in range(int(args["seed0"]), int(args["seed0"]) + seeds):
		route_profit = {}
		milestones = []
		credit_curve = []
		first_upgrade_day = -1.0
		upkeep_spent = 0.0
		yard_days = 0.0
		cost = {"service": 0.0, "overhaul": 0.0, "inspection": 0.0, "labour": 0.0, "parts": 0.0, "voucher": 0.0}
		counts = {}
		kind_value = {}
		job_values = {}
		sim = Sim.new()
		for fleet in String(args["nofleets"]).split(",", false):
			sim.data.npcs["fleets"].erase(fleet)
		sim.new_game(seed_value)
		if args["credits"] != "":
			sim.state.credits = float(args["credits"])
		for pair in String(args["fit"]).split(",", false):
			var kv2 := pair.split(":")
			sim.state.ship["modules"][kv2[0]] = kv2[1]
		if args["fit"] != "":
			sim.state.ship["fuel_t"] = ShipStats.fuel_capacity_t(sim.state.ship, sim.data)
		var start_matrix := route_matrix()
		var t0 := sim.state.time_s
		min_credits = sim.state.credits
		var next_sample := t0
		while sim.state.time_s - t0 < days * DAY:
			if sim.state.time_s >= next_sample:
				credit_curve.append([(sim.state.time_s - t0) / DAY, sim.state.credits])
				next_sample += 10.0 * DAY
			min_credits = minf(min_credits, sim.state.credits)
			if not do_leg(upgrade):
				milestones.append("Day %.1f: bot stuck at %s, stopping" % [(sim.state.time_s - t0) / DAY, sim.state.location.get("place")])
				break
		credit_curve.append([(sim.state.time_s - t0) / DAY, sim.state.credits])
		runs.append({"seed": seed_value, "credits": sim.state.credits, "trips": int(sim.state.stats["trips"]), "first_upgrade": first_upgrade_day, "upkeep": upkeep_spent, "yard_days": yard_days, "premiums": float(sim.state.stats.get("premiums_paid", 0.0)), "surcharges": float(sim.state.stats.get("unfit_surcharges", 0.0))})
		if args["tsv"] == "1":
			print("ECON_RUN " + JSON.stringify(econ_row(seed_value)))
		print("BOT_RUN seed=%d credits=%d trips=%d first_upgrade_day=%.1f" % [seed_value, int(sim.state.credits), int(sim.state.stats["trips"]), first_upgrade_day])
		if detail.is_empty():
			detail = {"start": start_matrix, "end": route_matrix(), "routes": route_profit, "milestones": milestones, "curve": credit_curve, "state": sim.state, "sim": sim}
	route_profit = detail["routes"]
	milestones = detail["milestones"]
	credit_curve = detail["curve"]
	sim = detail["sim"]
	write_report(days, upgrade, detail["start"], detail["end"], runs)
	quit()


## One dock-to-dock leg. Returns false if the bot cannot move.
func do_leg(upgrade: bool) -> bool:
	var s := sim.state
	var here: String = s.location["place"]
	for good in s.ship["cargo"].keys():
		if Market.trades(sim.data, here, good):
			sim.apply({"type": "sell", "good": good, "tonnes": s.ship["cargo"][good]})
	if upkeep_on:
		keep_ship()
	if upgrade:
		try_upgrades()
	if sim.apply({"type": "refuel", "fill": true}) != "" and float(s.ship["fuel_t"]) < 0.5:
		sim.apply({"type": "emergency_refuel"})
		milestones.append("Day %.1f: emergency fuel at %s" % [day(), here])

	var best := best_trade(here, true)
	if best.is_empty():
		return false
	if hikers_on:
		take_hikers()
	if jobs_on:
		take_jobs(here, best["to"])
	if best["good"] != "":
		var tonnes: float = best["tonnes"]
		while tonnes > 0.05 and sim.apply({"type": "buy", "good": best["good"], "tonnes": tonnes}) != "":
			tonnes *= 0.9
	var credits_before := s.credits + cargo_value_paid()
	var err := sim.apply({"type": "depart", "to": best["to"]})
	if err != "":
		for good in s.ship["cargo"].keys():
			sim.apply({"type": "sell", "good": good, "tonnes": s.ship["cargo"][good]})
		err = sim.apply({"type": "depart", "to": best["to"]})
		if err != "":
			return false
	sim.advance_game_time(float(s.location["arrive_t"]) - s.time_s + 1.0)
	sim.apply({"type": "dock"})
	# A real pilot spends a moment docked: the sim ticks (insurance renews, hitchhikers ask).
	sim.advance_game_time(60.0)
	count_events()
	var to: String = s.location["place"]
	var income := 0.0
	for good in s.ship["cargo"].keys():
		var before := s.credits
		if sim.apply({"type": "sell", "good": good, "tonnes": s.ship["cargo"][good]}) == "":
			income += s.credits - before
	var key := "%s → %s (%s)" % [name_of(here), name_of(to), sim.data.goods[best["good"]]["name"] if best["good"] != "" else "empty"]
	var leg_profit := s.credits - credits_before
	if not route_profit.has(key):
		route_profit[key] = {"legs": 0, "profit": 0.0, "days": 0.0}
	route_profit[key]["legs"] += 1
	route_profit[key]["profit"] += leg_profit
	route_profit[key]["days"] += float(best["days"])
	if show_legs:
		print("LEG day=%.1f %s tonnes=%.1f profit=%d credits=%d planned=%d days=%.1f" % [day(), key, float(best["tonnes"]), int(leg_profit), int(s.credits), int(best["profit"]), float(best["days"])])
	return true


func cargo_value_paid() -> float:
	var total := 0.0
	for g in sim.state.ship["cargo_paid"]:
		total += float(sim.state.ship["cargo_paid"][g])
	return total


## The bot trades its own planet's neighbourhood, like the NPC traders: it is the
## benchmark for the cislunar economy, not an interplanetary planner.
func _in_reach(here: String, to: String) -> bool:
	return Navigation.frame_body(sim.data, here, to) != "sun" and preload("res://sim/perks.gd").place_open(sim.state, sim.data, to)


## Best trade from `here`: {to, good, tonnes, profit, days, rate}. good "" means reposition empty.
func best_trade(here: String, allow_reposition: bool) -> Dictionary:
	var s := sim.state
	var d := sim.data
	var best := {}
	var capacity := ShipStats.cargo_capacity_t(s.ship, d) - ShipStats.cargo_t(s.ship)
	for to in d.places:
		if to == here or not _in_reach(here, to):
			continue
		var plan := Navigation.plan(s.ship, d, sim.ephemeris, here, to, s.time_s)
		if not plan["ok"] or plan["strand_risk"]:
			continue
		var days: float = plan["duration_s"] / DAY
		var fuel_cost: float = plan["fuel_t"] * float(d.goods["propellant"]["base_price"])
		var fixed := fuel_cost + float(d.balance["docking"]["auto_dock_fee"])
		for good in d.places[here]["market"]:
			if not Market.trades(d, to, good):
				continue
			var tonnes := minf(capacity, Market.stock(s, here, good) * take_share)
			tonnes = minf(tonnes, (s.credits - fixed) / maxf(Market.buy_price(s, d, here, good, tonnes), 1.0))
			if tonnes < 0.1:
				continue
			# Re-plan with the cargo mass aboard: heavier ships are slower and thirstier.
			var loaded: Dictionary = s.ship.duplicate(true)
			loaded["cargo"][good] = float(loaded["cargo"].get(good, 0.0)) + tonnes
			var lplan := Navigation.plan(loaded, d, sim.ephemeris, here, to, s.time_s)
			if not lplan["ok"] or lplan["strand_risk"]:
				continue
			var ldays: float = lplan["duration_s"] / DAY
			var margin := Market.sell_price(s, d, to, good, tonnes) - Market.buy_price(s, d, here, good, tonnes)
			var profit: float = margin * tonnes - lplan["fuel_t"] * float(d.goods["propellant"]["base_price"]) - float(d.balance["docking"]["auto_dock_fee"])
			var rate: float = profit / ldays
			if profit > 0.0 and (best.is_empty() or rate > best["rate"]):
				best = {"to": to, "good": good, "tonnes": tonnes, "profit": profit, "days": ldays, "rate": rate}
	if best.is_empty() and allow_reposition:
		# Nothing pays from here: go empty to the place whose best trade is richest.
		var target := ""
		var target_rate := -INF
		for to in d.places:
			if to == here or not _in_reach(here, to):
				continue
			var plan := Navigation.plan(s.ship, d, sim.ephemeris, here, to, s.time_s)
			if not plan["ok"] or plan["strand_risk"]:
				continue
			var saved: Dictionary = s.location
			s.location = {"status": "docked", "place": to}
			var onward := best_trade(to, false)
			s.location = saved
			var r: float = onward.get("profit", 0.0) / (float(plan["duration_s"]) / DAY + onward.get("days", 1.0))
			if r > target_rate:
				target_rate = r
				target = to
				best = {"to": to, "good": "", "tonnes": 0.0, "profit": 0.0, "days": float(plan["duration_s"]) / DAY, "rate": 0.0}
	return best


func try_upgrades() -> void:
	var s := sim.state
	var stock := ShipyardSystem.yard_stock(s, sim.data)
	for u in UPGRADES:
		if s.ship["modules"].get(u[0]) == u[1] or not u[1] in stock:
			continue
		if _already_better(u[0], u[1]):
			continue
		var price := float(sim.data.modules[u[1]]["price"]) + float(Condition.refit_quote(u[1], s.location["place"], sim.data)["labour_cr"])
		if s.credits - price < UPGRADE_RESERVE:
			return
		var t0 := s.time_s
		var uq := ShipBill.quote(s, sim.data, {"swaps": [{"slot": u[0], "module": u[1]}], "inspect": upkeep_on})
		if sim.apply({"type": "install_module", "slot": u[0], "module": u[1], "inspect": upkeep_on}) == "":
			cost["labour"] += float(uq["labour"])
			cost["parts"] += float(uq["parts"]) - float(uq["trade_in"])
			cost["inspection"] += float(uq["inspection"])
			counts["refits"] = int(counts.get("refits", 0)) + 1
			counts["premium_after_refit"] = float(uq["insurance"]["premium_after"])
			counts["premium_before_refit"] = float(uq["insurance"]["premium_before"])
			yard_days += (s.time_s - t0) / DAY
			if first_upgrade_day < 0.0:
				first_upgrade_day = day()
			milestones.append("Day %.1f: fitted %s at %s (credits %d)" % [day(), sim.data.modules[u[1]]["name"], name_of(s.location["place"]), int(s.credits)])


## Keep the ship at a yard: overhaul the worn-out, service the tired, renew the WoF.
func keep_ship() -> void:
	var s := sim.state
	if not "shipyard" in sim.data.places[s.location["place"]].get("services", []):
		return
	var slots: Array = s.ship["modules"].keys()
	slots.sort()
	var work := []
	for slot in slots:
		var cond := Condition.condition(s.ship, slot)
		if upkeep_mode == 2:
			# lazy but legal: only what an inspection would fail
			if cond < float(sim.data.ship_economy["wof"]["min_condition"]) + 0.03:
				work.append({"slot": slot, "level": "overhaul"})
		elif cond < 0.30:
			work.append({"slot": slot, "level": "overhaul"})
		elif cond < 0.55:
			work.append({"slot": slot, "level": "service"})
	# A repair voucher is only good at this operator's yards: use it on whatever is tired.
	if upkeep_mode == 1 and Favours.yard_voucher_balance(s, sim.data, s.location["place"]) >= 300.0:
		for slot in slots:
			var c2 := Condition.condition(s.ship, slot)
			if c2 >= 0.30 and c2 < 0.85:
				work.append({"slot": slot, "level": "service"})
	var wof := Fitness.status(s, sim.data)
	var inspect: bool = (not wof["valid"]) or float(wof["days_left"]) < 14.0
	if work.is_empty() and not inspect:
		return
	var request := {"services": work, "inspect": inspect}
	var bill := ShipBill.quote(s, sim.data, request)
	# Keep a trading reserve: drop the dearest jobs until the bill fits.
	while not bill["ok"] or s.credits - float(bill["total"]) < 2000.0:
		if work.is_empty():
			return
		work.pop_back()
		request = {"services": work, "inspect": inspect}
		bill = ShipBill.quote(s, sim.data, request)
		if work.is_empty() and not inspect:
			return
	var t0 := s.time_s
	if sim.apply({"type": "refit", "swaps": [], "services": work, "inspect": inspect}) == "":
		upkeep_spent += float(bill["total"])
		for k in ["service", "overhaul", "inspection"]:
			cost[k] += float(bill[k])
		cost["voucher"] += float(bill["voucher"])
		counts["yard_visits"] = int(counts.get("yard_visits", 0)) + 1
		yard_days += (s.time_s - t0) / DAY
		milestones.append("Day %.1f: yard visit at %s: %d jobs%s, %d cr, %.1f days" % [day(), name_of(s.location["place"]), work.size(), " + WoF" if inspect else "", int(bill["total"]), float(bill["days"])])


func count_events() -> void:
	for e in sim.take_events():
		var ty: String = e["type"]
		if ty in ["module_fault", "wof_lapsed", "insurance_lapsed", "insurance_void", "hitchhiker_asks", "hitchhiker_boarded", "hitchhiker_left", "hitchhiker_refused", "favour_granted", "voucher_used", "unfit_surcharge", "passengers_refused", "condition_low"]:
			counts[ty] = int(counts.get(ty, 0)) + 1
		if ty == "contract_delivered" and job_values.has(int(e["data"].get("id", -1))):
			var iv: Dictionary = job_values[int(e["data"]["id"])]
			kind_value[iv["form"]] = float(kind_value.get(iv["form"], 0.0)) + float(iv["value_cr"])
			counts["jobs_delivered"] = int(counts.get("jobs_delivered", 0)) + 1
		elif ty == "contract_delivered":
			counts["jobs_delivered"] = int(counts.get("jobs_delivered", 0)) + 1
		if ty == "hitchhiker_left" and float(e["data"].get("fare", 0.0)) > 0.0:
			counts["hiker_fares"] = float(counts.get("hiker_fares", 0.0)) + float(e["data"]["fare"])


func take_hikers() -> void:
	var s := sim.state
	for h in s.favours.get("waiting", {}).get(s.location["place"], []).duplicate():
		if sim.apply({"type": "accept_hitchhiker", "id": h["id"]}) == "":
			continue


## Takes a package/courier job bound where the bot is going anyway, if it fits.
func take_jobs(here: String, to: String) -> void:
	var s := sim.state
	for o in s.contracts["board"].get(here, []).duplicate():
		if o["to"] != to or o["pickup"] != "" or int(o.get("passengers", 0)) > 0:
			continue
		# A courier bot: no satellites, devices or secret work.
		if o.get("covert", false) or o.get("release", false) or o.get("plant", false):
			continue
		counts["jobs_seen"] = int(counts.get("jobs_seen", 0)) + 1
		var has_kind: bool = o.has("in_kind")
		if has_kind:
			counts["jobs_in_kind_offered"] = int(counts.get("jobs_in_kind_offered", 0)) + 1
		if sim.apply({"type": "accept_contract", "id": o["id"]}) == "":
			counts["jobs_taken"] = int(counts.get("jobs_taken", 0)) + 1
			counts["job_cash"] = float(counts.get("job_cash", 0.0)) + float(o["reward"])
			if has_kind:
				job_values[int(o["id"])] = o["in_kind"]


func econ_row(seed_value: int) -> Dictionary:
	var st := sim.state
	var row := {"seed": seed_value, "days": days_total, "credits": int(st.credits), "min_credits": int(min_credits), "trips": int(st.stats["trips"]),
		"premiums": int(st.stats.get("premiums_paid", 0.0)), "surcharges": int(st.stats.get("unfit_surcharges", 0.0)), "yard_days": snappedf(yard_days, 0.1),
		"first_upgrade": first_upgrade_day, "loan": int(st.insurance.get("loan_cr", 0.0)), "kind_value": kind_value.duplicate()}
	for k in cost:
		row["cost_" + k] = int(cost[k])
	for k in counts:
		row[k] = counts[k]
	var m := {}
	for slot in st.ship["modules"]:
		m[slot] = snappedf(Condition.condition(st.ship, slot), 0.01)
	row["end_condition"] = m
	return row


func _already_better(slot: String, module_id: String) -> bool:
	var current: String = sim.state.ship["modules"].get(slot, "")
	if current == "":
		return false
	# Berths the pilot fitted on purpose (fit=) stay: the bot does not swap them for a bigger pod.
	if int(sim.data.modules[current].get("berths", 0)) > 0:
		return true
	return float(sim.data.modules[current]["price"]) >= float(sim.data.modules[module_id]["price"])


## Best single-good trade per route right now, empty ship, full credits ignored.
func route_matrix() -> Array:
	var s := sim.state
	var d := sim.data
	var rows := []
	for from in d.places:
		for to in d.places:
			if from == to:
				continue
			var best_good := ""
			var best_margin := 0.0
			for good in d.places[from]["market"]:
				if not Market.trades(d, to, good):
					continue
				var m := Market.sell_price(s, d, to, good) - Market.buy_price(s, d, from, good)
				if m > best_margin:
					best_margin = m
					best_good = good
			if best_good != "":
				rows.append([name_of(from), name_of(to), d.goods[best_good]["name"], best_margin, best_margin / float(d.goods[best_good]["base_price"])])
	rows.sort_custom(func(a, b): return a[4] > b[4])
	return rows


func day() -> float:
	return (sim.state.time_s - _t0()) / DAY


func _t0() -> float:
	return Time.get_unix_time_from_datetime_string(sim.data.balance["start"]["date_utc"]) - 946728000.0


func name_of(place: String) -> String:
	return sim.data.places[place]["name"]


func write_report(days: float, upgrade: bool, start_matrix: Array, end_matrix: Array, runs: Array) -> void:
	var s := sim.state
	var lines := PackedStringArray()
	lines.append("# Balance bot report")
	lines.append("")
	lines.append("Generated by `tools/balance_bot.gd` on %s. Do not edit by hand; re-run the bot after changing `data/`." % Time.get_date_string_from_system())
	lines.append("")
	lines.append("Run: %d game days, upgrades %s, yard upkeep %s, greedy single-good trader, always auto-docks (pays the fee). This is a **floor**: a player who docks manually, carries mixed cargo or plans two legs ahead will do better." % [int(days), "on" if upgrade else "off", "on" if upkeep_on else "off"])
	lines.append("")
	lines.append("## Across seeds")
	lines.append("")
	lines.append("| Seed | End credits | Trips | First upgrade (game day) | Yard upkeep (cr) | Days in yards | Premiums (cr) | Unfit surcharges (cr) |")
	lines.append("|---|---|---|---|---|---|---|---|")
	var total := 0.0
	var ups := []
	for r in runs:
		total += float(r["credits"])
		if r["first_upgrade"] >= 0.0:
			ups.append(r["first_upgrade"])
		lines.append("| %d | %d | %d | %s | %d | %.1f | %d | %d |" % [r["seed"], int(r["credits"]), r["trips"], "%.1f" % r["first_upgrade"] if r["first_upgrade"] >= 0.0 else "none", int(r["upkeep"]), r["yard_days"], int(r["premiums"]), int(r["surcharges"])])
	ups.sort()
	lines.append("| **mean / median** | **%d** | | **%s** |" % [int(total / maxf(1.0, runs.size())), "%.1f" % ups[ups.size() / 2] if not ups.is_empty() else "none"])
	lines.append("")
	lines.append("## Outcome (seed 1)")
	lines.append("")
	var start_credits := float(sim.data.balance["start"]["credits"])
	lines.append("| Measure | Value |")
	lines.append("|---|---|")
	lines.append("| Start credits | %d |" % int(start_credits))
	lines.append("| End credits | %d |" % int(s.credits))
	lines.append("| Net worth gain per game day | %d |" % int((s.credits - start_credits) / days))
	lines.append("| Trips | %d |" % int(s.stats["trips"]))
	lines.append("| Average trip | %.2f game days |" % (days / maxf(1.0, float(s.stats["trips"]))))
	lines.append("| Cargo capacity at end | %d t |" % int(ShipStats.cargo_capacity_t(s.ship, sim.data)))
	lines.append("")
	lines.append("## Credits over time")
	lines.append("")
	lines.append("| Day | Credits |")
	lines.append("|---|---|")
	for p in credit_curve:
		lines.append("| %d | %d |" % [int(p[0]), int(p[1])])
	lines.append("")
	lines.append("## Milestones")
	lines.append("")
	if milestones.is_empty():
		lines.append("None.")
	for m in milestones:
		lines.append("- " + m)
	lines.append("")
	lines.append("## Routes the bot used")
	lines.append("")
	lines.append("| Route (good) | Legs | Total profit | Profit per leg | Profit per game day |")
	lines.append("|---|---|---|---|---|")
	var keys := route_profit.keys()
	keys.sort_custom(func(a, b): return route_profit[a]["profit"] > route_profit[b]["profit"])
	for k in keys:
		var r: Dictionary = route_profit[k]
		lines.append("| %s | %d | %d | %d | %d |" % [k, r["legs"], int(r["profit"]), int(r["profit"] / r["legs"]), int(r["profit"] / maxf(r["days"], 0.01))])
	for pair in [["Best margin per route at start (prices at target stock)", start_matrix], ["Best margin per route at the end", end_matrix]]:
		lines.append("")
		lines.append("## " + pair[0])
		lines.append("")
		lines.append("Top 12 by margin as a fraction of base price.")
		lines.append("")
		lines.append("| From | To | Good | Margin (cr/t) | Margin / base |")
		lines.append("|---|---|---|---|---|")
		for row in pair[1].slice(0, 12):
			lines.append("| %s | %s | %s | %d | %.0f%% |" % [row[0], row[1], row[2], int(row[3]), row[4] * 100.0])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(report_path.get_base_dir()))
	var f := FileAccess.open(report_path, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	print("BOT_DONE mean_credits=%d median_first_upgrade=%s" % [int(total / maxf(1.0, runs.size())), "%.1f" % ups[ups.size() / 2] if not ups.is_empty() else "none"])
