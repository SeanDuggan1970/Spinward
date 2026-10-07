## Headless balance probe: the numbers the greedy bot cannot give. Prints tables (markdown
## rows, prefixed with the section name) for docs/balance reports; writes nothing.
##   godot --headless --path . --script res://tools/balance_probe.gd -- [sections=a,b,c] [seed=1]
## Sections: modules, elevators, shuttle, collisions, projects, outer, loops. Default is all of them.
##   modules    price of every buyable module, and a stock Mule's cargo capacity with each fit
##   elevators  what a hold of the best good earns riding each ribbon, against the fare
##   shuttle    a stock Mule teleported to Piazzi Station, riding the Stalk and trading both ends for 60 days
##   collisions damage and repair cost by impact speed and zone; the speed that wrecks a ship;
##              when the insurance excess beats a repair
##   projects   passive completion day, stage demand premium, what the backers' perks are worth
##   outer      interplanetary freight with a Mars runner and a freighter fit: days, fuel, profit/day;
##              courier boards and surveys per day
##   loops      same-port round trips (must lose the spread), two-way arbitrage on one good,
##              ports with nothing to sell on
extends SceneTree

const Sim := preload("res://sim/sim.gd")
const SaveIO := preload("res://sim/save_io.gd")
const Market := preload("res://sim/market.gd")
const Navigation := preload("res://sim/navigation.gd")
const Interplanetary := preload("res://sim/interplanetary.gd")
const ShipStats := preload("res://sim/ship_stats.gd")
const DamageSystem := preload("res://sim/systems/damage_system.gd")
const ProjectSystem := preload("res://sim/systems/project_system.gd")
const ElevatorSystem := preload("res://sim/systems/elevator_system.gd")
const Perks := preload("res://sim/perks.gd")

const DAY := 86400.0

var sim: Sim
var seed_value := 1


func _initialize() -> void:
	var args := {"sections": "modules,elevators,shuttle,collisions,projects,outer,loops", "seed": "1"}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	seed_value = int(args["seed"])
	sim = Sim.new()
	sim.new_game(seed_value)
	for section in String(args["sections"]).split(","):
		call("section_" + section)
	quit()


func row(section: String, cells: Array) -> void:
	print("%s | %s" % [section, " | ".join(cells.map(func(c): return str(c)))])


func fit_ship(fit: Dictionary) -> Dictionary:
	var ship: Dictionary = sim.state.ship.duplicate(true)
	for slot in fit:
		ship["modules"][slot] = fit[slot]
	ship["fuel_t"] = ShipStats.fuel_capacity_t(ship, sim.data)
	ship["cargo"] = {}
	return ship


func fit_cost(ship: Dictionary) -> float:
	var total := 0.0
	for slot in ship["modules"]:
		total += float(sim.data.modules[ship["modules"][slot]]["price"])
	return total


func section_modules() -> void:
	var d := sim.data
	var rows := []
	for id in d.modules:
		var m: Dictionary = d.modules[id]
		if float(m["price"]) > 0.0:
			rows.append([id, m["kind"], int(m["price"])])
	rows.sort_custom(func(a, b): return a[2] < b[2])
	for r in rows:
		row("modules", r)
	var fits := {
		"stock": {}, "pod_m x2": {"cargo.0": "cargo_pod_m", "cargo.1": "cargo_pod_m"}, "pod_l x2": {"cargo.0": "cargo_pod_l", "cargo.1": "cargo_pod_l"},
		"mk2": {"drive.0": "pathfinder_mk2"}, "mk3 + arrays": {"drive.0": "pathfinder_mk3", "radiator.0": "radiator_array", "radiator.1": "radiator_array"},
	}
	for name in fits:
		var ship := fit_ship(fits[name])
		row("modules_fit", [name, "cargo %.0f t" % ShipStats.cargo_capacity_t(ship, d), "fuel %.1f t" % ShipStats.fuel_capacity_t(ship, d),
			"accel %.2f milli-g" % (ShipStats.accel_mps2(ship, d) / 9.80665 * 1000.0), "modules value %d" % int(fit_cost(ship))])


## Best good to carry from a to b with a hold of `cap` t at the current prices: margin per
## tonne after the exact integral prices, tonnes limited by the source's stock.
func best_haul(a: String, b: String, cap: float) -> Dictionary:
	var best := {"good": "", "profit": 0.0, "tonnes": 0.0}
	for good in sim.data.places[a]["market"]:
		if not Market.trades(sim.data, b, good):
			continue
		var t := minf(cap, Market.stock(sim.state, a, good) * 0.5)
		if t < 0.1:
			continue
		var profit := Market.sell_price(sim.state, sim.data, b, good, t) * t - Market.buy_cost(sim.state, sim.data, a, good, t)
		if profit > best["profit"]:
			best = {"good": good, "profit": profit, "tonnes": t}
	return best


func section_elevators() -> void:
	var d := sim.data
	var cap := ShipStats.cargo_capacity_t(sim.state.ship, d)
	for day in [0, 60]:
		if day > 0:
			sim.advance_game_time(float(day) * DAY)
		for port in ["halo_depot", "piazzi_station", "ares_ring"]:
			var line: Dictionary = d.places[port]["elevator"]
			var foot: String = line["foot"]
			var down := best_haul(port, foot, cap)
			var up := best_haul(foot, port, cap)
			var fare: float = float(line["fare"]) + float(line["fare_per_t"]) * cap
			row("elevators", ["day %d" % day, line["name"], "%d h" % int(line["hours"]), "fare full hold %d" % int(fare),
				"down: %s %.1f t %d" % [down["good"], down["tonnes"], int(down["profit"])], "up: %s %.1f t %d" % [up["good"], up["tonnes"], int(up["profit"])],
				"round trip net %d" % int(down["profit"] + up["profit"] - 2.0 * fare)])
	# The same cargo flown instead: the foot is not flyable, so the ribbon is the only way. Compare with the best flight from the port.
	var s := sim.state
	for port in ["halo_depot"]:
		var best := {"to": "", "profit": 0.0, "days": 1.0}
		for to in d.places:
			if to == port or not Perks.place_open(s, d, to) or Navigation.frame_body(d, port, to) == "sun":
				continue
			var plan := Navigation.plan(s.ship, d, sim.ephemeris, port, to, s.time_s)
			if not plan["ok"]:
				continue
			var h := best_haul(port, to, cap)
			var rate := (float(h["profit"]) - float(plan["fuel_t"]) * 200.0) / (float(plan["duration_s"]) / DAY)
			if rate > float(best["profit"]) / float(best["days"]):
				best = {"to": to, "profit": float(h["profit"]) - float(plan["fuel_t"]) * 200.0, "days": float(plan["duration_s"]) / DAY}
		row("elevators_vs_flight", [port, "best flight", best["to"], "%.1f d" % best["days"], "%d per day" % int(float(best["profit"]) / float(best["days"]))])


## The Piazzi Stalk as a trade loop: ride down with the best hold, sell, buy the best way back, ride up,
## sell, and repeat, for 60 days. Teleports a stock ship to the station (the trip there takes months).
func section_shuttle() -> void:
	var s := sim.state
	var d := sim.data
	var port := "piazzi_station"
	var foot: String = d.places[port]["elevator"]["foot"]
	s.location = {"status": "docked", "place": port}
	s.credits = 20000.0
	var t0 := s.time_s
	var rides := 0
	var next_print := 0.0
	while s.time_s - t0 < 60.0 * DAY:
		for leg in [[port, foot], [foot, port]]:
			for g in s.ship["cargo"].keys():
				sim.apply({"type": "sell", "good": g, "tonnes": s.ship["cargo"][g]})
			var h := best_haul(leg[0], leg[1], ShipStats.cargo_capacity_t(s.ship, d))
			if h["good"] != "":
				var tonnes: float = h["tonnes"]
				while tonnes > 0.05 and sim.apply({"type": "buy", "good": h["good"], "tonnes": tonnes}) != "":
					tonnes *= 0.9
			if sim.apply({"type": "ride_elevator"}) != "":
				row("shuttle", ["stopped", "day %.1f" % ((s.time_s - t0) / DAY), "credits %d" % int(s.credits)])
				return
			rides += 1
			sim.advance_game_time(float(s.location["arrive_t"]) - s.time_s + 1.0)
		if (s.time_s - t0) / DAY >= next_print:
			row("shuttle", ["day %.1f" % ((s.time_s - t0) / DAY), "rides %d" % rides, "credits %d" % int(s.credits)])
			next_print += 10.0
	for g in s.ship["cargo"].keys():
		sim.apply({"type": "sell", "good": g, "tonnes": s.ship["cargo"][g]})
	row("shuttle_end", ["60 days", "rides %d" % rides, "credits %d" % int(s.credits), "gain per day %d" % int((s.credits - 20000.0) / 60.0)])


## One impact on a clone of a game, and what it did.
func hit(text: String, speed: float, zone: String, seed_hit: int, fit: Dictionary = {}) -> Dictionary:
	var c := Sim.new(sim.data)
	c.load_state(SaveIO.from_text(text))
	for slot in fit:
		c.state.ship["modules"][slot] = fit[slot]
	c.state.location = {"status": "approach", "place": "kibo_ring"}
	c.take_events()
	c.apply({"type": "impact", "speed": speed, "share": 1.0, "zone": zone, "seed": seed_hit})
	var out := {"module": "", "amount": 0.0, "wrecked": c.state.location.get("status") == "lifeboat", "keel": 0.0, "yard": 0.0, "patch": 0.0, "lost_value": 0.0}
	for e in c.take_events():
		if e["type"] == "impact":
			out["module"] = e["data"]["module"]
			out["amount"] = e["data"]["amount"]
	out["keel"] = DamageSystem.damage_of(c.state.ship, "keel")
	c.state.location = {"status": "docked", "place": "kibo_ring"}
	out["yard"] = DamageSystem.repair_cost(c.state, c.data)
	c.state.location = {"status": "docked", "place": "halo_depot"}
	out["patch"] = DamageSystem.repair_cost(c.state, c.data)
	return out


func section_collisions() -> void:
	var text := SaveIO.to_text(sim.state)
	var tune: Dictionary = sim.data.balance["damage"]
	row("collisions_params", ["safe_mps %s" % tune["safe_mps"], "full_j_per_kg %s" % tune["full_j_per_kg"], "keel_share %s" % tune["keel_share"],
		"insurance_excess %s" % tune["insurance_excess"], "keel_value %s" % tune["keel_value"], "repair_cr_per_point %s" % tune["repair_cr_per_point"]])
	for zone in ["nose", "mid", "tail", "side"]:
		for speed in [1.0, 2.0, 3.0, 5.0, 8.0, 10.0, 12.0, 14.0]:
			var h := hit(text, speed, zone, 0)
			row("collisions", [zone, "%.0f m/s" % speed, h["module"], "module dmg %.2f" % h["amount"], "keel %.2f" % h["keel"], "wrecked" if h["wrecked"] else "ok",
				"yard %d cr" % int(h["yard"]), "patch %d cr" % int(h["patch"])])
	# The single-hit wreck speed per zone, for the stock ship and a fitted-out one.
	var rich := {"drive.0": "pathfinder_mk2", "cargo.0": "cargo_pod_l", "cargo.1": "cargo_pod_l", "tank.0": "tank_m"}
	for label in ["stock", "fitted"]:
		for zone in ["nose", "mid", "tail", "side"]:
			var found := -1.0
			for k in range(8, 400):
				var speed := float(k) / 10.0
				if hit(text, speed, zone, 0, rich if label == "fitted" else {})["wrecked"]:
					found = speed
					break
			row("collisions_wreck_speed", [label, zone, "%.1f m/s" % found])
	var ship_value := fit_cost(fit_ship(rich))
	row("collisions_value", ["fitted ship modules (sold back at resale)", int(ship_value), "insurance gives a stock Mule for", int(tune["insurance_excess"])])
	# When is a wreck cheaper than a repair? Yard cost of damage d on the keel alone, for a stock ship.
	var break_even := float(tune["insurance_excess"]) / (float(tune["keel_value"]) * float(tune["repair_cr_per_point"]))
	row("collisions_breakeven", ["keel damage at which the yard costs more than the excess", "%.2f" % break_even])


func section_projects() -> void:
	var d := sim.data
	var s := sim.state
	var done_day := {}
	var premium := {}
	var checkpoints := [30, 90, 180, 365]
	var day := 0
	for cp in checkpoints:
		sim.advance_game_time(float(cp - day) * DAY)
		day = cp
		for id in d.projects:
			if s.projects[id]["done"] and not done_day.has(id):
				done_day[id] = "by day %d" % cp
			var place: String = d.projects[id]["place"]
			var stage: int = mini(int(s.projects[id]["stage"]), d.projects[id]["stages"].size() - 1)
			for good in d.projects[id]["stages"][stage]["needs"]:
				if Market.trades(d, place, good):
					var mult := Market.sell_price(s, d, place, good, 1.0) / float(d.goods[good]["base_price"])
					premium[id] = maxf(float(premium.get(id, 0.0)), mult) if cp == day else premium.get(id, 0.0)
		for id in d.projects:
			row("projects_day", ["day %d" % cp, id, "stage %d/%d" % [int(s.projects[id]["stage"]), d.projects[id]["stages"].size()], "%.0f%%" % (ProjectSystem.progress(s, d, id) * 100.0),
				"revealed" if s.projects[id]["revealed"] else "hidden", "done" if s.projects[id]["done"] else ""])
	# Why the stalled ones stall: the current stage's needs, what has come in, what the market holds above the reserve.
	for id in d.projects:
		if s.projects[id]["done"] or not s.projects[id]["revealed"]:
			continue
		var stage: Dictionary = d.projects[id]["stages"][int(s.projects[id]["stage"])]
		var parts := []
		for good in stage["needs"]:
			var place: String = d.projects[id]["place"]
			var target := Market.target(d, place, good) if Market.trades(d, place, good) else 0.0
			var spare := maxf(0.0, Market.stock(s, place, good) - target * float(d.projects_reserve_fraction)) if target > 0.0 else 0.0
			parts.append("%s %.0f/%.0f (spare %.1f)" % [good, float(s.projects[id]["delivered"].get(good, 0.0)), float(stage["needs"][good]), spare])
		row("projects_stage_needs", ["day 365", id, "stage %d" % int(s.projects[id]["stage"]), ", ".join(parts)])
	for id in d.projects:
		var total := 0.0
		var value := 0.0
		for st in d.projects[id]["stages"]:
			for g in st["needs"]:
				total += float(st["needs"][g])
				value += float(st["needs"][g]) * float(d.goods[g]["base_price"])
		row("projects", [id, d.projects[id]["place"], "%d t" % int(total), "goods at base price %d cr" % int(value), "draw %.1f t/day" % float(d.projects[id]["draw_t_per_day"]),
			"passive: %s" % done_day.get(id, "after day 365"), "needs-price peak %.2fx" % float(premium.get(id, 0.0)),
			"perks min_t %s" % str(d.projects[id].get("perks", []).map(func(p): return int(p["min_t"])))])
	row("projects_docking", ["auto dock fee %d cr" % int(d.balance["docking"]["auto_dock_fee"]), "yard price for a 90k pod -20%% = %d cr" % int(90000 * 0.2)])


## An interplanetary freight run from `a` to `b` and back with a fit, at today's prices.
func freight(ship: Dictionary, a: String, b: String) -> Dictionary:
	var s := sim.state
	var d := sim.data
	var cap := ShipStats.cargo_capacity_t(ship, d)
	var go := Interplanetary.quick(ship, d, sim.ephemeris, a, b, s.time_s)
	if not go["ok"]:
		return {"ok": false, "why": String(go.get("reason", ""))}
	var back_ship := ship.duplicate(true)
	var back := Interplanetary.quick(back_ship, d, sim.ephemeris, b, a, s.time_s + float(go["duration_s"]))
	if not back["ok"]:
		return {"ok": false, "why": "no way home: " + String(back.get("reason", ""))}
	var out := best_haul(a, b, cap)
	var home := best_haul(b, a, cap)
	var fuel_cost := (float(go["fuel_t"]) + float(back["fuel_t"])) * float(d.goods["propellant"]["base_price"])
	var days := (float(go["duration_s"]) + float(back["duration_s"])) / DAY
	return {"ok": true, "days": days, "fuel_t": float(go["fuel_t"]) + float(back["fuel_t"]), "out": out, "home": home,
		"profit": float(out["profit"]) + float(home["profit"]) - fuel_cost - 2.0 * float(d.balance["docking"]["auto_dock_fee"]), "cap": cap}


func section_outer() -> void:
	var d := sim.data
	var s := sim.state
	var fits := {
		"Mars runner (tank_l, pod_m, tank_m)": {"cargo.0": "tank_l", "cargo.1": "cargo_pod_m", "tank.0": "tank_m"},
		"Freighter (pod_l x2, tank_l, Mk3, arrays)": {"cargo.0": "cargo_pod_l", "cargo.1": "cargo_pod_l", "tank.0": "tank_l", "drive.0": "pathfinder_mk3", "radiator.0": "radiator_array", "radiator.1": "radiator_array"},
		"Hauler (pod_l, hab, tank_l, Mk3, arrays)": {"cargo.0": "cargo_pod_l", "cargo.1": "hab_extended", "tank.0": "tank_l", "drive.0": "pathfinder_mk3", "radiator.0": "radiator_array", "radiator.1": "radiator_array"},
	}
	var hubs := ["kibo_ring", "trojan_yards"]
	for name in fits:
		var ship := fit_ship(fits[name])
		row("outer_fit", [name, "cost of modules %d" % int(fit_cost(ship)), "cargo %.0f t" % ShipStats.cargo_capacity_t(ship, d), "fuel %.0f t" % ShipStats.fuel_capacity_t(ship, d),
			"life %d d" % int(ShipStats.life_support_days(ship, d))])
		var rows := []
		for hub in hubs:
			for to in d.places:
				if to == hub or not Perks.place_open(s, d, to) or Navigation.frame_body(d, hub, to) != "sun":
					continue
				var f := freight(ship, hub, to)
				if not f["ok"]:
					rows.append([hub, to, "no", String(f["why"]).left(60), -1.0e9])
					continue
				rows.append([hub, to, "%.0f d" % float(f["days"]), "fuel %.1f t | out %s %d | home %s %d | profit %d | %d per day" % [float(f["fuel_t"]), f["out"]["good"], int(f["out"]["profit"]),
					f["home"]["good"], int(f["home"]["profit"]), int(f["profit"]), int(float(f["profit"]) / float(f["days"]))], float(f["profit"]) / float(f["days"])])
		rows.sort_custom(func(a, b): return a[4] > b[4])
		for r in rows:
			row("outer_routes", [name.split(" ")[0]] + r.slice(0, 4))
	# Courier boards: reward per quick-plan day, on every board after a month.
	sim.advance_game_time(30.0 * DAY)
	var offers := []
	for place in s.contracts["board"]:
		for o in s.contracts["board"][place]:
			if not o.get("hidden", false):
				var days := float(o.get("quick_days", 0.0))
				offers.append([place, o["kind"], o["to"], int(o["reward"]), days])
	offers.sort_custom(func(a, b): return a[3] > b[3])
	for o in offers.slice(0, 20):
		row("outer_boards", [o[0], o[1], "to " + String(o[2]), "%d cr" % o[3], "%.1f d quick" % o[4], "%d per day" % int(float(o[3]) / maxf(o[4], 0.5))])
	row("outer_boards_n", [offers.size(), "offers on boards"])
	for id in d.sites:
		var site: Dictionary = d.sites[id]
		for act in site["activities"]:
			var a: Dictionary = site["activities"][act]
			row("outer_sites", [id, act, "credits %d" % int(a.get("credits", 0)), "%.0f d on site" % float(a.get("days", 0.0)), "needs %s" % str(a.get("needs", [])), "yields %s" % str(a.get("yields", {}).keys())])


func section_loops() -> void:
	var d := sim.data
	var s := sim.state
	# Same-port round trip: buy t, sell t straight back. Must lose.
	var worst_loss := 1.0e9
	var worst := ""
	for place in d.places:
		for good in d.places[place]["market"]:
			var stock := Market.stock(s, place, good)
			if stock < 1.0:
				continue
			var t := minf(5.0, stock)
			var cost := Market.buy_cost(s, d, place, good, t)
			s.markets[place][good] -= t
			var income := Market.sell_price(s, d, place, good, t) * t
			s.markets[place][good] += t
			var loss := (cost - income) / maxf(cost, 1.0)
			if loss < worst_loss:
				worst_loss = loss
				worst = "%s %s" % [place, good]
	row("loops_same_port", ["smallest round-trip loss on 5 t", "%.1f%%" % (worst_loss * 100.0), worst])
	# One good, both ways between two ports (a free money loop if both margins are positive).
	var loops := 0
	var listed := 0
	var places: Array = d.places.keys()
	for i in places.size():
		for j in range(i + 1, places.size()):
			var a: String = places[i]
			var b: String = places[j]
			for good in d.places[a]["market"]:
				if not Market.trades(d, b, good):
					continue
				var ab := Market.sell_price(s, d, b, good, 1.0) - Market.buy_price(s, d, a, good, 1.0)
				var ba := Market.sell_price(s, d, a, good, 1.0) - Market.buy_price(s, d, b, good, 1.0)
				if ab > 0.0 and ba > 0.0:
					loops += 1
					if listed < 10:
						listed += 1
						row("loops_two_way", [a, b, good, "%d" % int(ab), "%d" % int(ba)])
	row("loops_two_way_n", [loops, "pairs where one good pays both ways"])
	# Ports with nothing worth carrying out: for each, how many (destination, good) pairs have a positive margin.
	for a in places:
		if Perks.place_open(s, d, a) == false:
			continue
		var n := 0
		var best := 0.0
		for b in places:
			if a == b or not Perks.place_open(s, d, b):
				continue
			for good in d.places[a]["market"]:
				if Market.trades(d, b, good):
					var m := Market.sell_price(s, d, b, good, 1.0) - Market.buy_price(s, d, a, good, 1.0)
					if m > 0.0:
						n += 1
						best = maxf(best, m / float(d.goods[good]["base_price"]))
		row("loops_exports", [a, "%d paying (dest, good) pairs" % n, "best margin %.0f%% of base" % (best * 100.0)])
