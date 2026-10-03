## Headless sim tests: godot --headless --path . --script res://tests/run_tests.gd
extends SceneTree

const Sim := preload("res://sim/sim.gd")
const SaveIO := preload("res://sim/save_io.gd")
const GameState := preload("res://sim/game_state.gd")
const DataCatalog := preload("res://sim/data_catalog.gd")
const Ephemeris := preload("res://sim/ephemeris.gd")
const Market := preload("res://sim/market.gd")
const Navigation := preload("res://sim/navigation.gd")
const ShipStats := preload("res://sim/ship_stats.gd")
const V := preload("res://sim/v3.gd")
const ProjectSystem := preload("res://sim/systems/project_system.gd")
const RoutePlanner := preload("res://sim/route_planner.gd")
const OrbitMech := preload("res://sim/orbit_mech.gd")

const AU := 1.495978707e11
const DAY := 86400.0

var checks := 0
var failures := 0


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)


func fresh() -> Sim:
	var sim := Sim.new()
	sim.new_game(42)
	return sim


func _initialize() -> void:
	test_data()
	test_clock_and_commands()
	test_orbits()
	test_economy()
	test_travel()
	test_shipyard()
	test_npcs()
	test_projects()
	test_review_regressions()
	test_tips()
	test_docking_help()
	test_trajectories()
	test_gravity_routes()
	test_saves_and_determinism()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_data() -> void:
	var problems: Array = DataCatalog.load_default().validate()
	for p in problems:
		push_error("DATA: " + p)
	check(problems.is_empty(), "Data files cross-reference cleanly")


func test_clock_and_commands() -> void:
	var sim := fresh()
	check(sim.state.date_string() == "2061-03-01T00:00:00", "Start date from balance.json")
	check(sim.state.credits == float(sim.data.balance["start"]["credits"]), "Start credits from balance.json")
	sim.take_events()
	check(sim.apply({"type": "nonsense"}) != "", "Unknown command rejected")
	check(sim.apply({"type": "set_time_scale", "scale": 7}) != "", "Disallowed time scale rejected")
	check(sim.apply({"type": "set_time_scale", "scale": 1000}) == "", "Allowed time scale accepted")
	var before := sim.state.time_s
	sim.tick(2.0)
	check(is_equal_approx(sim.state.time_s - before, 2000.0), "Time compression scales the clock")
	sim.apply({"type": "set_paused", "paused": true})
	before = sim.state.time_s
	sim.tick(5.0)
	check(sim.state.time_s == before, "Paused clock does not move")
	check(sim.state.command_count == 2, "Only accepted commands are counted")
	var types := sim.take_events().map(func(e): return e["type"])
	check(types == ["rejected", "rejected", "time_scale_changed", "paused_changed"], "Events emitted for the view")
	check(sim.take_events().is_empty(), "Events drain once")


func test_orbits() -> void:
	var data = DataCatalog.load_default()
	var eph := Ephemeris.new(data.bodies, data.places)
	# Earth-Sun distance stays within perihelion/aphelion over a year.
	var lo := INF
	var hi := 0.0
	for d in range(0, 366, 5):
		var r := V.length(eph.position("earth", d * DAY))
		lo = minf(lo, r)
		hi = maxf(hi, r)
	check(lo > 0.982 * AU and lo < 0.985 * AU and hi > 1.015 * AU and hi < 1.018 * AU, "Earth orbit spans 0.983-1.017 AU")
	# Perihelion falls in early January (J2000 epoch is 1 Jan 2000).
	var best_day := 0
	var best := INF
	for d in range(0, 30):
		var r := V.length(eph.position("earth", d * DAY))
		if r < best:
			best = r
			best_day = d
	check(best_day >= 1 and best_day <= 6, "Earth perihelion in early January (day %d)" % best_day)
	# Moon distance stays within its real range.
	lo = INF
	hi = 0.0
	for h in range(0, 24 * 60, 6):
		var r := V.length(eph.relative("moon", "earth", h * 3600.0))
		lo = minf(lo, r)
		hi = maxf(hi, r)
	check(lo > 3.55e8 and lo < 3.65e8 and hi > 4.03e8 and hi < 4.08e8, "Moon distance spans ~362,000-405,000 km")
	# Lagrange points: L1 about 326,000 km from Earth on the Moon side; L4 equilateral.
	var t := 7.0 * DAY
	var moon := eph.relative("moon", "earth", t)
	var l1 := eph.relative("halo_depot", "earth", t)
	var l1_ratio := V.length(l1) / V.length(moon)
	check(l1_ratio > 0.845 and l1_ratio < 0.853 and V.dot(l1, moon) > 0.0, "L1 at ~0.849 of the Earth-Moon distance")
	var l4 := eph.relative("trojan_yards", "earth", t)
	check(absf(V.length(l4) - V.length(moon)) < 1.0 and absf(V.distance(l4, moon) - V.length(moon)) < 1.0, "L4 is equilateral")
	var l2 := eph.relative("farside_array", "earth", t)
	var l2_ratio := V.length(l2) / V.length(moon)
	check(l2_ratio > 1.15 and l2_ratio < 1.18 and V.dot(l2, moon) > 0.0, "L2 sits ~1.167 Earth-Moon distances out, behind the Moon")
	var kalpana := eph.relative("kalpana_one", "earth", t)
	check(absf(V.length(kalpana) - 6.878e6) < 1000.0, "Kalpana One orbits at 500 km")
	var l5 := eph.relative("kernel_l5", "earth", t)
	check(V.distance(l4, l5) > 1.7 * V.length(moon), "L4 and L5 are on opposite sides of the Moon")
	# Low Earth orbit station: 420 km altitude, ~92 minute period.
	var leo := V.length(eph.relative("kibo_ring", "earth", t))
	check(absf(leo - 6.791e6) < 5000.0, "Kibo Ring orbit radius")
	var p0 := eph.relative("kibo_ring", "earth", 0.0)
	var period := TAU * sqrt(pow(6.791e6, 3) / 3.986004418e14)
	check(V.distance(p0, eph.relative("kibo_ring", "earth", period)) < 1.0, "Kibo Ring returns after one period")
	# Geostationary: equatorial orbit is inclined 23.44 degrees to the ecliptic.
	var geo := eph.relative("clarke_exchange", "earth", 3600.0)
	var normal := V.normalized(V.cross(eph.relative("clarke_exchange", "earth", 0.0), geo))
	check(absf(rad_to_deg(acos(absf(normal[2]))) - 23.44) < 0.05, "GEO lies in Earth's equatorial plane")


func test_economy() -> void:
	var sim := fresh()
	var s := sim.state
	s.npcs = []  # Market flows on their own; NPC traffic is tested separately.
	var d := sim.data
	check(s.markets["kibo_ring"]["food"] > 160.0 and s.markets["shackleton_port"]["food"] < 60.0, "Warm-up leaves surpluses and shortages on day one")
	var mid := Market.mid_price_at(d, "kibo_ring", "food", 160.0)
	check(is_equal_approx(mid, 600.0), "Price equals base at target")
	check(Market.mid_price_at(d, "kibo_ring", "food", 40.0) > mid, "Scarcity raises price")
	check(Market.mid_price_at(d, "kibo_ring", "food", 1e6) == 600.0 * float(d.balance["economy"]["price_min_mult"]), "Glut price is floored")
	check(Market.buy_price(s, d, "kibo_ring", "food") > Market.sell_price(s, d, "kibo_ring", "food"), "Buy above sell (spread)")

	var credits := s.credits
	var food_stock: float = s.markets["kibo_ring"]["food"]
	check(sim.apply({"type": "buy", "good": "food", "tonnes": 5}) == "", "Buy food")
	check(s.ship["cargo"]["food"] == 5.0 and s.credits < credits and is_equal_approx(s.markets["kibo_ring"]["food"], food_stock - 5.0), "Buying moves credits, cargo and stock")
	check(sim.apply({"type": "buy", "good": "regolith", "tonnes": 1}) != "", "Cannot buy a good not traded here")
	check(sim.apply({"type": "buy", "good": "food", "tonnes": 50}) != "", "Cargo capacity enforced")
	s.credits = 10.0
	check(sim.apply({"type": "buy", "good": "medical", "tonnes": 1}) != "", "Credits enforced")
	check(sim.apply({"type": "sell", "good": "food", "tonnes": 6}) != "", "Cannot sell more than aboard")
	check(sim.apply({"type": "sell", "good": "food", "tonnes": 5}) == "" and not s.ship["cargo"].has("food"), "Sell all food")
	check(s.stats["trade_profit"] < 0.0, "Round trip at one market loses the spread")

	# Producers fill up, consumers drain, and recipes convert, all within bounds.
	sim.advance_game_time(30 * DAY)
	var shack: Dictionary = s.markets["shackleton_port"]
	check(shack["water_ice"] > 400.0 and shack["food"] < 60.0, "Producer gluts, consumer runs short")
	var yards: Dictionary = s.markets["trojan_yards"]
	check(yards["refined_metals"] > 0.0 and yards["habitat_modules"] > 0.0, "Recipes keep producing")
	var bounded := true
	for place in s.markets:
		for good in s.markets[place]:
			var v: float = s.markets[place][good]
			bounded = bounded and v >= 0.0 and v <= Market.target(d, place, good) * float(d.balance["economy"]["max_stock_mult"])
	check(bounded, "All stocks stay within [0, max]")
	check(Market.sell_price(s, d, "kibo_ring", "helium3") > Market.buy_price(s, d, "shackleton_port", "helium3"), "Helium-3 run is profitable at equilibrium")

	s.credits = 5000.0
	s.ship["fuel_t"] = 1.0
	check(sim.apply({"type": "refuel", "fill": true}) == "" and is_equal_approx(s.ship["fuel_t"], 3.0), "Refuel fills the tank")
	check(sim.apply({"type": "refuel", "fill": true}) != "", "Full tank refuel rejected")
	check(sim.apply({"type": "emergency_refuel"}) != "", "No emergency fuel where normal fuel is sold")
	s.location = {"status": "docked", "place": "kernel_l5"}
	s.ship["fuel_t"] = 0.0
	check(sim.apply({"type": "refuel", "fill": true}) != "", "The Kernel sells no fuel")
	var before := s.credits
	check(sim.apply({"type": "emergency_refuel", "tonnes": 1}) == "" and s.ship["fuel_t"] == 1.0, "Emergency fuel delivery")
	check(before - s.credits == 120.0 * 6.0, "Emergency fuel costs six times base")


func test_travel() -> void:
	var sim := fresh()
	var s := sim.state
	var d := sim.data
	check(Navigation.frame_body(d, "kibo_ring", "shackleton_port") == "earth", "Cislunar trips use the Earth frame")
	var accel_empty := ShipStats.accel_mps2(s.ship, d)
	check(accel_empty / 9.80665 > 0.002 and accel_empty / 9.80665 < 0.005, "Starter ship accelerates at a few milli-g")
	var plan := Navigation.plan(s.ship, d, sim.ephemeris, "kibo_ring", "halo_depot", s.time_s)
	check(plan["ok"] and plan["distance_m"] > 3.0e8 and plan["distance_m"] < 3.4e8, "Route to L1 is about 320,000 km")
	var days: float = plan["duration_s"] / DAY
	check(days > 1.5 and days < 3.5, "Empty trip to L1 takes a couple of days (%.2f d)" % days)
	check(plan["fuel_t"] > 0.1 and plan["fuel_t"] < 1.0, "Trip burns a fraction of the tank (%.2f t)" % plan["fuel_t"])
	check(not plan["strand_risk"], "No strand risk going to a fuel depot")
	var full_tank := Navigation.plan(s.ship, d, sim.ephemeris, "kibo_ring", "kernel_l5", s.time_s)
	check(full_tank["ok"] and not full_tank["strand_risk"], "A full tank reaches The Kernel and back")
	s.ship["fuel_t"] = float(full_tank["fuel_t"]) * 1.5
	var to_kernel := Navigation.plan(s.ship, d, sim.ephemeris, "kibo_ring", "kernel_l5", s.time_s)
	check(to_kernel["ok"] and to_kernel["strand_risk"], "Warn when heading somewhere without fuel on a thin tank")
	s.ship["fuel_t"] = 3.0

	sim.apply({"type": "buy", "good": "water_ice", "tonnes": 20})
	var loaded := Navigation.plan(s.ship, d, sim.ephemeris, "kibo_ring", "halo_depot", s.time_s)
	check(loaded["duration_s"] > plan["duration_s"], "Cargo mass slows the trip")

	s.ship["fuel_t"] = 0.01
	check(sim.apply({"type": "depart", "to": "halo_depot"}) != "", "Cannot depart without enough propellant")
	s.ship["fuel_t"] = 3.0
	check(sim.apply({"type": "depart", "to": "kibo_ring"}) != "", "Cannot depart to where you are")
	check(sim.apply({"type": "depart", "to": "halo_depot"}) == "", "Depart for Halo Depot")
	check(s.location["status"] == "transit" and s.ship["fuel_t"] < 3.0, "In transit, fuel spent")
	check(sim.apply({"type": "buy", "good": "food", "tonnes": 1}) != "", "No trading in transit")
	var start_pos: Array = Navigation.transit_position(s.location, s.time_s)
	check(V.distance(start_pos, s.location["from_pos"]) < 1.0, "Transit starts at the origin")
	sim.apply({"type": "set_time_scale", "scale": 10000})
	sim.advance_game_time(float(s.location["arrive_t"]) - s.time_s - 60.0)
	check(s.location["status"] == "transit", "Still travelling just before arrival")
	sim.advance_game_time(120.0)
	check(s.location["status"] == "approach" and s.location["place"] == "halo_depot", "Arrive on approach")
	check(s.time_scale == 1.0, "Time compression drops on arrival")
	var credits := s.credits
	check(sim.apply({"type": "dock"}) == "" and s.location["status"] == "docked", "Auto dock")
	check(s.credits == credits - float(d.balance["docking"]["auto_dock_fee"]), "Auto dock charges the fee")
	check(sim.apply({"type": "sell", "good": "water_ice", "tonnes": 20}) == "", "Sell ice at the depot")
	check(s.stats["trips"] == 1 and s.stats["auto_docks"] == 1, "Trip stats recorded")


func test_shipyard() -> void:
	var sim := fresh()
	var s := sim.state
	var d := sim.data
	check(ShipStats.cargo_capacity_t(s.ship, d) == 20.0 and ShipStats.fuel_capacity_t(s.ship, d) == 3.0, "Mule starts with 20 t cargo and 3 t tank")
	check(s.ship["fuel_t"] == 3.0, "Starts fully fuelled")
	check(sim.apply({"type": "install_module", "slot": "cargo.0", "module": "cargo_pod_m"}) != "", "Cannot afford a 20 t container yet")
	s.credits = 200000.0
	check(sim.apply({"type": "install_module", "slot": "tank.0", "module": "cargo_pod_m"}) != "", "Module kind must match slot")
	check(sim.apply({"type": "install_module", "slot": "cargo.5", "module": "cargo_pod_m"}) != "", "Slot must exist")
	check(sim.apply({"type": "install_module", "slot": "drive.0", "module": "pathfinder_mk2"}) != "", "Kibo Ring does not sell Mk2 drives")
	check(sim.apply({"type": "install_module", "slot": "cargo.0", "module": "cargo_pod_m"}) == "", "Fit a 20 t container")
	check(ShipStats.cargo_capacity_t(s.ship, d) == 30.0, "Capacity grows")
	check(s.credits == 200000.0 - 30000.0 + 4000.0, "Old module resold at half price")
	sim.apply({"type": "buy", "good": "water_ice", "tonnes": 25})
	check(sim.apply({"type": "install_module", "slot": "cargo.0", "module": "cargo_pod_s"}) != "", "Cannot shrink below cargo aboard")
	# Heat: a Mk2 drive (4 MW) on two 1.5 MW panels runs throttled.
	var hot: Dictionary = s.ship.duplicate(true)
	hot["modules"]["drive.0"] = "pathfinder_mk2"
	check(is_equal_approx(ShipStats.thrust_n(hot, d), float(d.modules["pathfinder_mk2"]["thrust_n"]) * 3.0 / 4.0), "Radiators limit thrust")


func test_npcs() -> void:
	var sim := fresh()
	var s := sim.state
	var d := sim.data
	var expected := 0
	for f in d.npcs["fleets"]:
		expected += int(d.npcs["fleets"][f]["count"])
	check(s.npcs.size() == expected and expected >= 10, "NPC fleets spawn (%d ships)" % s.npcs.size())
	var with_npcs := fresh()
	var without := fresh()
	without.state.npcs = []
	with_npcs.advance_game_time(30 * DAY)
	without.advance_game_time(30 * DAY)
	var everyone_moved := true
	var min_stock := INF
	for npc in with_npcs.state.npcs:
		everyone_moved = everyone_moved and int(npc["trips"]) >= 1
	for place in with_npcs.state.markets:
		for good in with_npcs.state.markets[place]:
			min_stock = minf(min_stock, with_npcs.state.markets[place][good])
	check(everyone_moved, "Every NPC completes at least one trip in 30 days")
	check(min_stock >= 0.0, "NPC trading never drives stock negative")
	var ice_with: float = with_npcs.state.markets["halo_depot"]["water_ice"]
	var ice_without: float = without.state.markets["halo_depot"]["water_ice"]
	check(ice_with > ice_without, "Coop tankers deliver ice to Halo Depot (%.0f vs %.0f t)" % [ice_with, ice_without])
	var in_transit := 0
	for npc in with_npcs.state.npcs:
		if npc["location"]["status"] == "transit":
			in_transit += 1
			check(float(npc["next_t"]) == float(npc["location"]["arrive_t"]), "Transit NPC wakes on arrival")
	check(in_transit > 0, "Some NPCs are in flight at any moment (%d)" % in_transit)
	# NPC randomness replays identically from a save, even with different tick sizes ahead.
	var saved := SaveIO.from_text(SaveIO.to_text(with_npcs.state))
	var resumed := Sim.new()
	resumed.load_state(saved)
	resumed.advance_game_time(5 * DAY)
	with_npcs.advance_game_time(5 * DAY)
	check(resumed.state.to_dict() == with_npcs.state.to_dict(), "NPC traffic continues identically after load")
	var events := with_npcs.take_events().filter(func(e): return e["type"] in ["npc_departed", "npc_arrived"])
	check(events.size() > 0, "NPC movements emit events for the comms feed")


func test_projects() -> void:
	var sim := fresh()
	var s := sim.state
	var d := sim.data
	check(s.projects.size() == d.projects.size() and ProjectSystem.progress(s, d, "island_one") == 0.0, "Projects start at zero")
	sim.advance_game_time(60 * DAY)
	var p60 := ProjectSystem.progress(s, d, "island_one")
	check(p60 > 0.0, "Island One advances on its own (%.0f%% after 60 days)" % (p60 * 100.0))
	# The player hauls refined metals to The Kernel while stage 1 needs them.
	var sim2 := fresh()
	var s2 := sim2.state
	s2.location = {"status": "docked", "place": "kernel_l5"}
	s2.ship["cargo"] = {"refined_metals": 15.0}
	s2.ship["cargo_paid"] = {"refined_metals": 3000.0}
	check(sim2.apply({"type": "sell", "good": "refined_metals", "tonnes": 15.0}) == "", "Sell metals at The Kernel")
	sim2.advance_game_time(2 * DAY)
	check(is_equal_approx(float(s2.projects["island_one"]["player_t"]), 15.0), "Player credited for hauling project goods")
	# Finishing a project changes the world.
	var sim3 := fresh()
	var s3 := sim3.state
	var stages: Array = d.projects["luna_line_2"]["stages"]
	s3.projects["luna_line_2"]["stage"] = stages.size() - 1
	for good in stages[-1]["needs"]:
		s3.markets["halo_depot"][good] = 1000.0
	sim3.advance_game_time(60 * DAY)
	check(s3.projects["luna_line_2"]["done"], "Luna Line 2 completes when supplied")
	check(float(s3.place_mods.get("halo_depot", {}).get("produces_mult", 1.0)) == 2.0, "Completion doubles Halo Depot output")
	var events := sim3.take_events().map(func(e): return e["type"])
	check("project_stage" in events and "project_complete" in events, "Project events for news")
	var loaded := SaveIO.from_text(SaveIO.to_text(s3))
	check(loaded.to_dict() == s3.to_dict(), "Projects round-trip through saves")


## Each check here pins a defect found in code review.
func test_review_regressions() -> void:
	# 1. Buying in one go and selling back in slices must lose money (exact integral pricing).
	for good in ["medical", "electronics", "helium3"]:
		var sim := fresh()
		var s := sim.state
		s.npcs = []
		s.credits = 1e7
		s.ship["modules"]["cargo.0"] = "cargo_pod_l"
		s.ship["modules"]["cargo.1"] = "cargo_pod_l"
		s.markets["kibo_ring"][good] = Market.target(sim.data, "kibo_ring", good)
		var start := s.credits
		var tonnes := minf(12.0, Market.stock(s, "kibo_ring", good) * 0.9)
		check(sim.apply({"type": "buy", "good": good, "tonnes": tonnes}) == "", "Bulk buy %s" % good)
		var left: float = s.ship["cargo"][good]
		while left > 1e-9:
			var slice := minf(0.05, left)
			sim.apply({"type": "sell", "good": good, "tonnes": slice})
			left = float(s.ship["cargo"].get(good, 0.0))
		check(s.credits < start, "No money from buy-big, sell-in-slices (%s: %+.0f cr)" % [good, s.credits - start])
	# Exact pricing: the cost of t tonnes equals the sum of buying it in small pieces.
	var sp := fresh()
	sp.state.npcs = []
	var one := Market.buy_cost(sp.state, sp.data, "kibo_ring", "food", 10.0)
	var pieces := 0.0
	var s0: float = sp.state.markets["kibo_ring"]["food"]
	for i in 100:
		sp.state.markets["kibo_ring"]["food"] = s0 - 0.1 * i
		pieces += Market.buy_cost(sp.state, sp.data, "kibo_ring", "food", 0.1)
	check(absf(one - pieces) < 1e-6 * one, "Trade cost is path independent (exact integral)")
	# 2. Only real slot names are accepted.
	var sy := fresh()
	sy.state.credits = 1e6
	for bad in ["cargo.01", "cargo.-1", "cargo.x", "cargo.2", "cargo", "cargo.1.0"]:
		check(sy.apply({"type": "install_module", "slot": bad, "module": "cargo_pod_s"}) != "", "Phantom slot %s refused" % bad)
	check(ShipStats.cargo_capacity_t(sy.state.ship, sy.data) == 20.0, "No phantom cargo capacity")
	# 3. NPC refuelling respects the market reserve.
	var nr := fresh()
	nr.advance_game_time(60 * DAY)
	var lowest := INF
	for place in nr.state.markets:
		if nr.state.markets[place].has("propellant"):
			lowest = minf(lowest, nr.state.markets[place]["propellant"] / Market.target(nr.data, place, "propellant"))
	check(lowest >= float(nr.data.npcs["reserve_fraction"]) * 0.5, "Propellant never stripped far below reserve by NPCs (lowest %.0f%%)" % (lowest * 100.0))
	# 4. Broke and stranded: the tanker still comes, on credit.
	var br := fresh()
	br.state.location = {"status": "docked", "place": "kernel_l5"}
	br.state.ship["fuel_t"] = 0.0
	br.state.credits = 3.0
	check(br.apply({"type": "emergency_refuel"}) == "" and br.state.ship["fuel_t"] >= 1.0 and br.state.credits < 0.0, "Rescue load on credit at a no-fuel port")
	var br2 := fresh()
	br2.state.ship["fuel_t"] = 0.0
	br2.state.credits = 0.0
	check(br2.apply({"type": "emergency_refuel"}) == "", "Rescue available at a fuel port when broke")
	var rich := fresh()
	rich.state.ship["fuel_t"] = 0.0
	check(rich.apply({"type": "emergency_refuel"}) != "", "No emergency tanker for those who can pay")
	# 5. Ephemeris results do not depend on call history.
	var data = DataCatalog.load_default()
	var e1 := Ephemeris.new(data.bodies, data.places)
	var e2 := Ephemeris.new(data.bodies, data.places)
	var t := 123456.0
	e2.position("trojan_yards", t)
	e2.position("moon", t - 30.0)
	check(e1.position("kernel_l5", t) == e2.position("kernel_l5", t) and e1.position("trojan_yards", t) == e2.position("trojan_yards", t), "Ephemeris independent of call history")
	# 6. Partial refuel is priced on what is actually bought.
	var pr := fresh()
	pr.state.ship["fuel_t"] = 0.0
	pr.state.credits = 150.0
	var stock_before: float = pr.state.markets["kibo_ring"]["propellant"]
	check(pr.apply({"type": "refuel", "fill": true}) == "", "Partial refuel")
	var bought: float = pr.state.ship["fuel_t"]
	pr.state.markets["kibo_ring"]["propellant"] = stock_before
	check(absf((150.0 - pr.state.credits) - Market.buy_cost(pr.state, pr.data, "kibo_ring", "propellant", bought)) < 1e-6, "Partial refuel charged its exact cost")
	# 8. Wash trading at a project's own market earns no credit.
	var wt := fresh()
	var w := wt.state
	w.credits = 1e6
	w.location = {"status": "docked", "place": "kernel_l5"}
	for _i in 5:
		wt.apply({"type": "buy", "good": "refined_metals", "tonnes": 5.0})
		wt.apply({"type": "sell", "good": "refined_metals", "tonnes": 5.0})
	wt.advance_game_time(DAY)
	check(float(w.projects["island_one"]["player_t"]) == 0.0, "Wash trading earns no project credit")
	# Second review: wash trading split across ticks also earns nothing.
	var wt2 := fresh()
	wt2.state.credits = 1e6
	wt2.state.location = {"status": "docked", "place": "halo_depot"}
	for _i in 5:
		wt2.apply({"type": "buy", "good": "refined_metals", "tonnes": 5.0})
		wt2.advance_game_time(3600.0)
		wt2.apply({"type": "sell", "good": "refined_metals", "tonnes": 5.0})
		wt2.advance_game_time(3600.0)
	check(float(wt2.state.projects["luna_line_2"]["player_t"]) == 0.0, "Wash trading across ticks earns no credit")
	# Saves without project entries keep working and grow them back.
	var old := fresh()
	old.state.projects = {}
	old.advance_game_time(2 * 3600.0)
	check(old.state.projects.size() == old.data.projects.size(), "Missing project entries are recreated")
	# Credit covers one rescue load only.
	var debt := fresh()
	debt.state.ship["fuel_t"] = 0.0
	debt.state.credits = 0.0
	debt.apply({"type": "emergency_refuel"})
	var after_one: float = debt.state.ship["fuel_t"]
	check(debt.apply({"type": "emergency_refuel"}) != "" and debt.state.ship["fuel_t"] == after_one, "No second rescue load on credit")
	# Real-time ticks stop at arrival and drop to x1 for the rest of the frame.
	var arr := fresh()
	arr.apply({"type": "depart", "to": "clarke_exchange"})
	arr.apply({"type": "set_time_scale", "scale": 10000})
	var arrive: float = arr.state.location["arrive_t"]
	arr.advance_game_time(arrive - arr.state.time_s - 100.0)
	arr.tick(1.0)
	check(arr.state.location["status"] == "approach" and arr.state.time_s - arrive < 2.0, "Clock stops racing at arrival (%.1f s past)" % (arr.state.time_s - arrive))


func test_tips() -> void:
	var sim := fresh()
	var s := sim.state
	var d := sim.data
	check(s.knowledge["kibo_ring"]["source"] == "seen" and s.knowledge["clarke_exchange"]["source"] == "logbook", "Fresh board where you start, the old logbook elsewhere")
	check(s.time_s - float(s.knowledge["clarke_exchange"]["t"]) >= 2.9 * DAY, "The logbook is days old")
	check(sim.apply({"type": "buy_tip", "broker": "lamplighter"}) != "", "Brokers sell only where they work")
	var credits := s.credits
	check(sim.apply({"type": "buy_tip", "broker": "maisie_tran"}) == "", "Buy a tip from Maisie at Kibo")
	check(s.credits == credits - float(d.brokers["maisie_tran"]["price"]) and s.tips.size() == 1, "Tips cost money and go in the book")
	var tip: Dictionary = s.tips[0]
	check(tip["place"] != "kibo_ring" and tip["place"] in d.brokers["maisie_tran"]["coverage"], "Tips are about other places the broker hears of")
	# Reliability shows up statistically: an expensive AI vs a cheap enthusiast.
	var truthful := {"lamplighter": 0, "dusty_okafor": 0}
	for broker in truthful:
		var bs := fresh()
		bs.state.credits = 1e7
		bs.state.location = {"status": "docked", "place": d.brokers[broker]["place"]}
		for _i in 60:
			bs.apply({"type": "buy_tip", "broker": broker})
			if bs.state.tips[-1]["truthful"]:
				truthful[broker] += 1
	check(truthful["lamplighter"] >= 48 and truthful["dusty_okafor"] <= 42, "Lamplighter is mostly right, Dusty is a coin toss (%d vs %d of 60)" % [truthful["lamplighter"], truthful["dusty_okafor"]])
	# A true tip about Clarke Exchange is checked when you dock there.
	var v := fresh()
	v.state.npcs = []
	v.state.tips = [{"id": 1, "broker": "maisie_tran", "place": "clarke_exchange", "good": "food", "kind": "short",
		"price": Market.sell_price(v.state, v.data, "clarke_exchange", "food") * 0.95, "t": v.state.time_s,
		"expires_t": v.state.time_s + 5 * DAY, "verified": null, "truthful": true, "template": 0}]
	v.apply({"type": "depart", "to": "clarke_exchange"})
	v.advance_game_time(float(v.state.location["arrive_t"]) - v.state.time_s + 1.0)
	v.apply({"type": "dock"})
	v.advance_game_time(60.0)
	check(v.state.tips[0]["verified"] == true and v.state.broker_record["maisie_tran"]["good"] == 1, "Tip checked on arrival and the broker credited")
	check(v.state.knowledge.has("clarke_exchange"), "Docking updates your knowledge of that board")
	# An invented tip is exposed.
	var f := fresh()
	f.state.npcs = []
	f.state.tips = [{"id": 1, "broker": "dusty_okafor", "place": "clarke_exchange", "good": "food", "kind": "short",
		"price": 5000.0, "t": f.state.time_s, "expires_t": f.state.time_s + 5 * DAY, "verified": null, "truthful": false, "template": 0}]
	f.state.location = {"status": "docked", "place": "clarke_exchange"}
	f.advance_game_time(60.0)
	check(f.state.tips[0]["verified"] == false and f.state.broker_record["dusty_okafor"]["bad"] == 1, "A bad tip is found out")
	# Tips expire, and everything survives a save.
	var e := fresh()
	e.apply({"type": "buy_tip", "broker": "maisie_tran"})
	e.advance_game_time(6 * DAY)
	check(e.state.tips[0].get("expired", false), "Unchecked tips expire")
	check(SaveIO.from_text(SaveIO.to_text(e.state)).to_dict() == e.state.to_dict(), "Tips and knowledge round-trip through saves")
	var a := fresh()
	var b := fresh()
	for x in [a, b]:
		x.apply({"type": "buy_tip", "broker": "maisie_tran"})
		x.apply({"type": "buy_tip", "broker": "maisie_tran"})
	check(a.state.tips == b.state.tips, "Same seed, same tips")


func test_docking_help() -> void:
	var sim := fresh()
	var s := sim.state
	s.location = {"status": "approach", "place": "kibo_ring"}
	s.credits = 10.0
	check(sim.apply({"type": "dock"}) == "" and s.location["status"] == "docked" and s.credits < 0.0, "Broke pilots are towed in on credit")
	check(sim.apply({"type": "buy", "good": "food", "tonnes": 1}) != "", "No buying while in debt")
	var dc := fresh()
	dc.state.credits = 50000.0
	check(dc.apply({"type": "install_module", "slot": "avionics.0", "module": "docking_computer"}) == "", "Fit a docking computer at Kibo Ring")
	check(ShipStats.has_docking_computer(dc.state.ship, dc.data) and dc.state.credits == 35000.0, "Docking computer fitted and paid for")


func test_trajectories() -> void:
	var sim := fresh()
	var s := sim.state
	var d := sim.data
	var accel := ShipStats.accel_mps2(s.ship, d)
	var lines := []
	for to in ["halo_depot", "kernel_l5", "shackleton_port", "clarke_exchange"]:
		var plan := Navigation.plan(s.ship, d, sim.ephemeris, "kibo_ring", to, s.time_s)
		check(plan["ok"], "Plan to %s" % to)
		var loc: Dictionary = plan.duplicate(true)
		loc["depart_t"] = s.time_s
		var start: float = s.time_s + (float(plan["duration_s"]) - float(plan["burn_s"])) * 0.5
		var end: float = start + float(plan["burn_s"])
		check(V.distance(Navigation.transit_position(loc, start), plan["from_pos"]) < 1.0, "%s path starts at the origin" % to)
		check(V.distance(Navigation.transit_position(loc, end), plan["to_pos"]) < 1.0, "%s path ends at the intercept" % to)
		check(V.distance(Navigation.transit_velocity(loc, end), plan["to_vel"]) < 0.01, "%s path arrives matching the destination's motion" % to)
		var peak := 0.0
		for k in 41:
			peak = maxf(peak, V.length(Navigation.transit_accel(loc, lerpf(start, end, k / 40.0))))
		check(peak <= accel * 1.001, "%s thrust never exceeds the drive (%.4f vs %.4f m/s2)" % [to, peak, accel])
		# Curvature: how far the midpoint sits off the straight chord.
		var mid := Navigation.transit_position(loc, (start + end) * 0.5)
		var chord := V.sub(plan["to_pos"], plan["from_pos"])
		var rel := V.sub(mid, plan["from_pos"])
		var along := V.dot(rel, V.normalized(chord))
		var off := V.length(V.sub(rel, V.scale(V.normalized(chord), along)))
		lines.append("%s: %.2f d, %.2f t, bow %.0f km" % [to, plan["duration_s"] / DAY, plan["fuel_t"], off / 1000.0])
		if to == "kernel_l5" or to == "shackleton_port":
			check(off > 5.0e6, "Trips to moving targets curve (%s bows %.0f km)" % [to, off / 1000.0])
		check(plan["throttle"] > 0.0 and plan["throttle"] <= 1.0, "%s throttle in range" % to)
	print("TRAJECTORIES  " + "  |  ".join(lines))


func test_gravity_routes() -> void:
	# Orbital mechanics: a circular orbit returns after one period; Lambert inverts Kepler.
	var mu := 3.986004418e14
	var r0 := [4.2e7, 0.0, 0.0]
	var v0 := [0.0, sqrt(mu / 4.2e7), 0.0]
	var period := TAU * sqrt(pow(4.2e7, 3) / mu)
	var back := OrbitMech.kepler(r0, v0, period, mu)
	check(V.distance(back[0], r0) < 10.0, "Kepler propagation closes a circular orbit")
	# Less than one revolution (the solver is single-revolution by design).
	var later := OrbitMech.kepler(r0, [300.0, 2800.0, 50.0], 3.0e4, mu)
	var sol := OrbitMech.lambert(r0, later[0], 3.0e4, mu, [0.0, 0.0, 1.0])
	check(not sol.is_empty() and V.distance(sol[0], [300.0, 2800.0, 50.0]) < 0.5, "Lambert recovers the departure velocity")

	var sim := fresh()
	var s := sim.state
	var d := sim.data
	var quick := Navigation.plan(s.ship, d, sim.ephemeris, "kibo_ring", "halo_depot", s.time_s)
	var job := RoutePlanner.prepare(s.ship, d, sim.ephemeris, "kibo_ring", "halo_depot", s.time_s)
	var opts := RoutePlanner.options_or_quick(job, quick)
	var ids := opts.map(func(o): return o["id"])
	check("express" in ids and "economy" in ids, "Gravity routes offer Express and Economy (%s)" % [ids])
	var express: Dictionary = opts[ids.find("express")]
	var economy: Dictionary = opts[ids.find("economy")]
	check(economy["fuel_t"] < express["fuel_t"] and economy["duration_s"] > express["duration_s"], "Economy is slower and cheaper (%.2f vs %.2f t)" % [economy["fuel_t"], express["fuel_t"]])
	check(RoutePlanner.options_or_quick(RoutePlanner.prepare(s.ship, d, sim.ephemeris, "kibo_ring", "halo_depot", s.time_s), quick) == opts, "Route planning is deterministic")

	# Fly the economy route: starts at the station, follows its samples, arrives on time.
	sim.store_route_options(sim.route_key("halo_depot"), opts)
	var fuel_before: float = s.ship["fuel_t"]
	check(sim.apply({"type": "depart", "to": "halo_depot", "route": "economy", "plan_t": s.time_s}) == "", "Depart on the economy route")
	var loc: Dictionary = s.location
	check(loc.has("samples") and is_equal_approx(fuel_before - float(s.ship["fuel_t"]), float(economy["fuel_t"])), "Route fuel is spent")
	check(V.distance(Navigation.transit_position(loc, s.time_s), sim.ephemeris.relative("kibo_ring", "earth", s.time_s)) < 1.0, "Gravity trip starts at the station")
	var mid: float = (float(loc["depart_t"]) + float(loc["arrive_t"])) * 0.5
	var jump := V.distance(Navigation.transit_position(loc, mid), Navigation.transit_position(loc, mid + 60.0))
	check(jump < 60.0 * 5000.0, "Path is continuous between samples (%.0f m in 60 s)" % jump)
	var saved := SaveIO.from_text(SaveIO.to_text(s))
	check(saved.to_dict() == s.to_dict(), "Gravity trips round-trip through saves")
	sim.advance_game_time(float(loc["arrive_t"]) - s.time_s + 1.0)
	check(s.location["status"] == "approach" and s.location["place"] == "halo_depot", "Gravity trip arrives on approach")

	# A replay without the planner's cache recomputes the same trajectory.
	var a := fresh()
	var b := fresh()
	a.store_route_options(a.route_key("halo_depot"), opts)
	a.apply({"type": "depart", "to": "halo_depot", "route": "economy", "plan_t": a.state.time_s})
	b.apply({"type": "depart", "to": "halo_depot", "route": "economy", "plan_t": b.state.time_s})
	check(a.state.location == b.state.location, "A replay without the cache flies the same path")
	var stale := fresh()
	check(stale.apply({"type": "depart", "to": "halo_depot", "route": "economy", "plan_t": stale.state.time_s - 7200.0}) != "", "Out-of-date route plans are refused")

	# A flyby trip (beyond the Moon to Farside) slows time for the pass and restores it.
	var fb := fresh()
	var fq := Navigation.plan(fb.state.ship, fb.data, fb.ephemeris, "kibo_ring", "farside_array", fb.state.time_s)
	var fopts := RoutePlanner.options_or_quick(RoutePlanner.prepare(fb.state.ship, fb.data, fb.ephemeris, "kibo_ring", "farside_array", fb.state.time_s), fq)
	var flyby := {}
	for o in fopts:
		if o["kind"] == "flyby":
			flyby = o
	check(not flyby.is_empty(), "Farside routes include a lunar flyby")
	if not flyby.is_empty():
		check(float(flyby["peri_alt"]) > 5.0e3 and float(flyby["peri_alt"]) < 6.0e5, "Flyby periapsis near its target (%.0f km)" % (float(flyby["peri_alt"]) / 1000.0))
		fb.store_route_options(fb.route_key("farside_array"), fopts)
		check(fb.apply({"type": "depart", "to": "farside_array", "route": flyby["id"], "plan_t": fb.state.time_s}) == "", "Depart on a flyby")
		fb.apply({"type": "set_time_scale", "scale": 10000})
		var peri: float = fb.state.location["peri_t"]
		fb.advance_game_time(peri - fb.state.time_s - 1800.0)
		check(fb.state.time_scale <= 100.0, "Time slows for the run-in to periapsis")
		fb.advance_game_time(1800.0 + 10.0)
		var types := fb.take_events().map(func(e): return e["type"])
		check("periapsis_near" in types and "periapsis" in types, "Periapsis events for the pass")
		fb.advance_game_time(1200.0)
		check(fb.state.time_scale == 10000.0, "Time compression restored after the pass")


func test_saves_and_determinism() -> void:
	var sim := fresh()
	sim.apply({"type": "buy", "good": "electronics", "tonnes": 1})
	sim.apply({"type": "depart", "to": "clarke_exchange"})
	sim.advance_game_time(3600.0 * 5)
	var text := SaveIO.to_text(sim.state)
	var loaded := SaveIO.from_text(text)
	check(loaded != null and loaded.to_dict() == sim.state.to_dict(), "Save round-trip is lossless mid-transit")
	var resumed := Sim.new()
	resumed.load_state(loaded)
	resumed.advance_game_time(3 * DAY)
	sim.advance_game_time(3 * DAY)
	check(resumed.state.to_dict() == sim.state.to_dict(), "A loaded game continues identically")
	var future := sim.state.to_dict()
	future["schema_version"] = 999
	check(SaveIO.from_text(JSON.stringify({"state": Marshalls.raw_to_base64(var_to_bytes(future))})) == null, "Future save version refused")
	check(SaveIO.from_text("not json") == null, "Corrupt save refused")

	# Tick size must not change the outcome: one 10-day jump equals many small steps.
	var big := fresh()
	var small := fresh()
	big.advance_game_time(10 * DAY)
	for _i in 240:
		small.advance_game_time(3600.0)
	var same := absf(big.state.credits - small.state.credits) < 1e-6 and big.state.npcs.size() == small.state.npcs.size()
	for place in big.state.markets:
		for good in big.state.markets[place]:
			same = same and absf(big.state.markets[place][good] - small.state.markets[place][good]) < 1e-6
	for i in big.state.npcs.size():
		same = same and big.state.npcs[i]["location"]["status"] == small.state.npcs[i]["location"]["status"]
	check(same, "Tick size does not change the world (10 days in one jump vs 240 hourly steps)")

	var run := func() -> Dictionary:
		var r := fresh()
		for c in [{"type": "buy", "good": "food", "tonnes": 4}, {"type": "depart", "to": "shackleton_port"}]:
			r.apply(c)
		r.advance_game_time(10 * DAY)
		r.apply({"type": "dock"})
		r.apply({"type": "sell", "good": "food", "tonnes": 4})
		return r.state.to_dict()
	check(run.call() == run.call(), "Same seed and commands give the same state")
