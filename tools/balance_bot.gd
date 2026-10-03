## Headless balance bot. Plays the trading game through the same commands as the
## player and writes docs/balance/report.md.
##   godot --headless --path . --script res://tools/balance_bot.gd -- [days=180] [upgrade=1] [seeds=5]
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


func _initialize() -> void:
	var args := {"days": "180", "upgrade": "1"}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	var days := float(args["days"])
	var upgrade: bool = args["upgrade"] == "1"
	var seeds := int(args.get("seeds", "5"))
	var runs := []
	var detail := {}
	for seed_value in range(1, seeds + 1):
		route_profit = {}
		milestones = []
		credit_curve = []
		first_upgrade_day = -1.0
		sim = Sim.new()
		sim.new_game(seed_value)
		var start_matrix := route_matrix()
		var t0 := sim.state.time_s
		var next_sample := t0
		while sim.state.time_s - t0 < days * DAY:
			if sim.state.time_s >= next_sample:
				credit_curve.append([(sim.state.time_s - t0) / DAY, sim.state.credits])
				next_sample += 10.0 * DAY
			if not do_leg(upgrade):
				milestones.append("Day %.1f: bot stuck at %s, stopping" % [(sim.state.time_s - t0) / DAY, sim.state.location.get("place")])
				break
		credit_curve.append([(sim.state.time_s - t0) / DAY, sim.state.credits])
		runs.append({"seed": seed_value, "credits": sim.state.credits, "trips": int(sim.state.stats["trips"]), "first_upgrade": first_upgrade_day})
		print("BOT_RUN seed=%d credits=%d trips=%d first_upgrade_day=%.1f" % [seed_value, int(sim.state.credits), int(sim.state.stats["trips"]), first_upgrade_day])
		if seed_value == 1:
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
	if upgrade:
		try_upgrades()
	if sim.apply({"type": "refuel", "fill": true}) != "" and float(s.ship["fuel_t"]) < 0.5:
		sim.apply({"type": "emergency_refuel"})
		milestones.append("Day %.1f: emergency fuel at %s" % [day(), here])

	var best := best_trade(here, true)
	if best.is_empty():
		return false
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
	return true


func cargo_value_paid() -> float:
	var total := 0.0
	for g in sim.state.ship["cargo_paid"]:
		total += float(sim.state.ship["cargo_paid"][g])
	return total


## Best trade from `here`: {to, good, tonnes, profit, days, rate}. good "" means reposition empty.
func best_trade(here: String, allow_reposition: bool) -> Dictionary:
	var s := sim.state
	var d := sim.data
	var best := {}
	var capacity := ShipStats.cargo_capacity_t(s.ship, d) - ShipStats.cargo_t(s.ship)
	for to in d.places:
		if to == here:
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
			var tonnes := minf(capacity, Market.stock(s, here, good) * 0.5)
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
			if to == here:
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
		var price := float(sim.data.modules[u[1]]["price"])
		if s.credits - price < UPGRADE_RESERVE:
			return
		if sim.apply({"type": "install_module", "slot": u[0], "module": u[1]}) == "":
			if first_upgrade_day < 0.0:
				first_upgrade_day = day()
			milestones.append("Day %.1f: fitted %s at %s (credits %d)" % [day(), sim.data.modules[u[1]]["name"], name_of(s.location["place"]), int(s.credits)])


func _already_better(slot: String, module_id: String) -> bool:
	var current: String = sim.state.ship["modules"].get(slot, "")
	if current == "":
		return false
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
	lines.append("Run: %d game days, upgrades %s, greedy single-good trader, always auto-docks (pays the fee). This is a **floor**: a player who docks manually, carries mixed cargo or plans two legs ahead will do better." % [int(days), "on" if upgrade else "off"])
	lines.append("")
	lines.append("## Across seeds")
	lines.append("")
	lines.append("| Seed | End credits | Trips | First upgrade (game day) |")
	lines.append("|---|---|---|---|")
	var total := 0.0
	var ups := []
	for r in runs:
		total += float(r["credits"])
		if r["first_upgrade"] >= 0.0:
			ups.append(r["first_upgrade"])
		lines.append("| %d | %d | %d | %s |" % [r["seed"], int(r["credits"]), r["trips"], "%.1f" % r["first_upgrade"] if r["first_upgrade"] >= 0.0 else "none"])
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
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/balance"))
	var f := FileAccess.open("res://docs/balance/report.md", FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	print("BOT_DONE mean_credits=%d median_first_upgrade=%s" % [int(total / maxf(1.0, runs.size())), "%.1f" % ups[ups.size() / 2] if not ups.is_empty() else "none"])
