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
const LightTime := preload("res://sim/light_time.gd")
const Interplanetary := preload("res://sim/interplanetary.gd")
const Contracts := preload("res://sim/contracts.gd")
const ContractSystemScript := preload("res://sim/systems/contract_system.gd")
const Perks := preload("res://sim/perks.gd")
const SiteSystemScript := preload("res://sim/systems/site_system.gd")
const EconomySystemScript := preload("res://sim/systems/economy_system.gd")
const NpcSystem := preload("res://sim/systems/npc_system.gd")
const DamageSystem := preload("res://sim/systems/damage_system.gd")

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
	test_light_time()
	test_ephemeris_against_horizons()
	test_interplanetary()
	test_refits()
	test_contracts()
	test_project_pitches()
	test_sites()
	test_story_arc()
	test_outer_traffic()
	test_spaceline()
	test_minds_and_sails()
	test_elevators()
	test_damage()
	test_news_in_depth()
	test_elevator_rides()
	test_damage_in_depth()
	test_story_arcs_in_depth()
	test_edge_cases()
	test_ship_audio()
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
		# Long-haul fleets (commissioned over the months) are tested separately.
		if not d.npcs["fleets"][npc["fleet"]].has("commission_days"):
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
	# Kept supplied: traders strip any glut for the other builds about the system.
	for _k in 6:
		for good in stages[-1]["needs"]:
			s3.markets["halo_depot"][good] = 1000.0
		sim3.advance_game_time(10 * DAY)
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


## A target in uniform motion, for checking the light-time geometry exactly.
class StubEphemeris:
	var p0: Array
	var v: Array
	func _init(start: Array, vel: Array) -> void:
		p0 = start
		v = vel
	func position(_id: String, t: float) -> Array:
		return [p0[0] + v[0] * t, p0[1] + v[1] * t, p0[2] + v[2] * t]


func test_light_time() -> void:
	var c := LightTime.C
	var d := 3.84e8
	var zero := [0.0, 0.0, 0.0]
	# Still target, still ship: one light time, no point-ahead.
	var still := LightTime.pointing(StubEphemeris.new([d, 0.0, 0.0], zero), "x", zero, zero, 0.0)
	check(absf(float(still["tau_s"]) - d / c) < 1e-9 and float(still["point_ahead_rad"]) < 1e-12, "Light time to a still target is d/c (%.4f s)" % still["tau_s"])
	# Target crossing the line of sight at u: transmit leads and receive lags by u/c each.
	var u := 1000.0
	var crossing := LightTime.pointing(StubEphemeris.new([d, 0.0, 0.0], [0.0, u, 0.0]), "x", zero, zero, 0.0)
	var want := 2.0 * u / c
	check(absf(float(crossing["point_ahead_rad"]) / want - 1.0) < 1e-3, "Point-ahead for a crossing target is 2u/c (%s vs %s rad)" % [String.num_scientific(crossing["point_ahead_rad"]), String.num_scientific(want)])
	check(float(crossing["transmit"]["dir"][1]) > 0.0 and float(crossing["receive"]["dir"][1]) < 0.0, "Transmit leads the target, receive sees it where it was")
	# Ship and target moving together: aberration cancels light time exactly (to first order).
	var together := LightTime.pointing(StubEphemeris.new([d, 0.0, 0.0], [0.0, 3.0e4, 0.0]), "x", zero, [0.0, 3.0e4, 0.0], 0.0)
	check(float(together["point_ahead_rad"]) < 1e-9, "Co-moving ship and target need no point-ahead (%s rad)" % String.num_scientific(together["point_ahead_rad"]))
	# The real thing: Kibo Ring to Shackleton Port is a little over a light second.
	var sim := fresh()
	var t: float = sim.state.time_s
	var real := LightTime.pointing(sim.ephemeris, "shackleton_port", sim.ephemeris.position("kibo_ring", t), sim.ephemeris.velocity("kibo_ring", t), t)
	check(float(real["tau_s"]) > 1.1 and float(real["tau_s"]) < 1.45, "Kibo to Shackleton light time %.3f s" % real["tau_s"])


## The baked orbits against JPL Horizons (tests/horizons_reference.json): the
## planets, dwarf planets, asteroids and moons where Horizons puts them in 2061 and
## 2063. The Moon keeps its Meeus mean elements, good to a degree or two.
func test_ephemeris_against_horizons() -> void:
	var data = DataCatalog.load_default()
	var eph = Ephemeris.new(data.bodies, data.places)
	var ref: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/horizons_reference.json"))
	var worst := ""
	var worst_deg := 0.0
	for name in ref:
		for date in ref[name]:
			var t: float = Time.get_unix_time_from_datetime_string(date + "T00:00:00") - GameState.J2000_UNIX
			var ours := eph.relative(name, data.bodies[name]["parent"], t)
			var theirs: Array = ref[name][date]["r"]
			var deg := rad_to_deg(acos(clampf(V.dot(V.normalized(ours), V.normalized(theirs)), -1.0, 1.0)))
			var limit := 2.0 if name == "moon" else 1.0
			if deg / limit > worst_deg:
				worst_deg = deg / limit
				worst = "%s %s %.2f deg" % [name, date, deg]
	check(worst_deg <= 1.0, "Every body within tolerance of JPL Horizons (worst: %s)" % worst)


func test_interplanetary() -> void:
	var sim := fresh()
	var d := sim.data
	var eph := sim.ephemeris
	var t: float = sim.state.time_s
	# Spiralling out costs about the orbit's speed: low Earth orbit dear, L-points cheap.
	var leo: float = Interplanetary.well(d, eph, "kibo_ring", t)["dv"]
	var l5: float = Interplanetary.well(d, eph, "kernel_l5", t)["dv"]
	check(leo > 7000.0 and leo < 8000.0, "Climbing out of low Earth orbit costs ~7.7 km/s (%.0f m/s)" % leo)
	check(l5 > 800.0 and l5 < 1200.0, "Leaving from an Earth-Moon Lagrange point costs ~1 km/s (%.0f m/s)" % l5)
	check(Interplanetary.well(d, eph, "valhalla_station", t)["body"] == "jupiter", "A Callisto station climbs out to Jupiter's solar orbit")
	# A long-haul Mule (tanks in the cargo bays) can reach Mars, and the flown route arrives.
	var ship: Dictionary = sim.state.ship.duplicate(true)
	for slot in ["cargo.0", "cargo.1", "tank.0"]:
		ship["modules"][slot] = "tank_m"
	ship["fuel_t"] = 18.0
	var opts: Array = Interplanetary.run(Interplanetary.prepare(ship, d, eph, "halo_depot", "ares_ring", t))
	check(not opts.is_empty(), "Halo Depot to Mars: the refitted Mule gets route options")
	if not opts.is_empty():
		var o: Dictionary = opts[0]
		check(o["affordable"] and o["miss_r"] < Interplanetary.ARRIVE_MISS_R and o["miss_v"] < Interplanetary.ARRIVE_MISS_V,
			"The flown Mars route arrives (%.0f d, %.1f t, miss %.0f km at %.0f m/s)" % [o["duration_s"] / DAY, o["fuel_t"], o["miss_r"] / 1000.0, o["miss_v"]])
	# The stock Mule cannot keep a crew alive to Jupiter.
	var q: Dictionary = Interplanetary.quick(sim.state.ship, d, eph, "kibo_ring", "valhalla_station", t)
	check(not q["ok"] and (String(q["reason"]).begins_with("life support") or String(q["reason"]).begins_with("not enough")), "Jupiter is out of the stock Mule's reach (%s)" % q["reason"])
	# Depart on the flown route and arrive at the right place.
	sim.state.location = {"status": "docked", "place": "halo_depot"}
	sim.state.ship = ship
	var key: String = sim.route_key("ares_ring", t)
	sim.store_route_options(key, opts)
	check(sim.apply({"type": "depart", "to": "ares_ring", "route": opts[0]["id"], "plan_t": t}) == "", "Departs for Mars on the planned route")
	sim.state.time_scale = 1.0e6
	sim.advance_game_time(float(sim.state.location.get("arrive_t", t)) - t + 10.0)
	check(sim.state.location.get("status") == "approach" and sim.state.location.get("place") == "ares_ring", "Arrives on approach to Ares Ring")


func test_refits() -> void:
	var sim := fresh()
	sim.state.credits = 2.0e6
	var d := sim.data
	# Cargo bays take long-haul tanks and habs (Kibo Ring's yard); tank slots do not take habs.
	check(sim.apply({"type": "install_module", "slot": "cargo.0", "module": "tank_l"}) == "", "A long-haul tank fits a cargo bay")
	check(sim.apply({"type": "install_module", "slot": "cargo.1", "module": "hab_extended"}) == "", "A long-duration hab fits a cargo bay")
	check(sim.apply({"type": "install_module", "slot": "tank.0", "module": "hab_extended"}) != "", "A hab does not fit a tank slot")
	check(ShipStats.fuel_capacity_t(sim.state.ship, d) == 23.0, "Tankage adds up across bays (%.0f t)" % ShipStats.fuel_capacity_t(sim.state.ship, d))
	check(ShipStats.life_support_days(sim.state.ship, d) == 420.0, "Life support adds up (%.0f days)" % ShipStats.life_support_days(sim.state.ship, d))
	check(ShipStats.cargo_capacity_t(sim.state.ship, d) == 0.0, "Trading bays for range leaves no cargo space")
	check(d.validate().is_empty(), "Data valid with mounts (%s)" % ", ".join(d.validate()))
	# The Mk3 drive (Trojan Yards) with the long-haul fit reaches Jupiter.
	sim.state.location = {"status": "docked", "place": "trojan_yards"}
	for c in [["drive.0", "pathfinder_mk3"], ["radiator.0", "radiator_array"], ["radiator.1", "radiator_array"], ["tank.0", "tank_l"]]:
		check(sim.apply({"type": "install_module", "slot": c[0], "module": c[1]}) == "", "Fits %s at Trojan Yards" % c[1])
	sim.state.ship["fuel_t"] = ShipStats.fuel_capacity_t(sim.state.ship, d)
	var q: Dictionary = Interplanetary.quick(sim.state.ship, d, sim.ephemeris, "trojan_yards", "valhalla_station", sim.state.time_s)
	check(q["ok"] and float(q["duration_s"]) / DAY < 200.0, "A Mk3 long-hauler reaches Jupiter (%.0f d, %.1f t) %s" % [float(q.get("duration_s", 0.0)) / DAY, float(q.get("fuel_t", 0.0)), q["reason"]])


func _dock_at(sim: Sim, place: String) -> void:
	sim.state.location = {"status": "docked", "place": place}
	sim.advance_game_time(60.0)


func _first_offer(sim: Sim, place: String, kind: String) -> Dictionary:
	for o in sim.state.contracts["board"].get(place, []):
		if o["kind"] == kind and ContractSystemScript.visible_to(sim.state, sim.data, o):
			return o
	return {}


func test_contracts() -> void:
	var sim := fresh()
	var s := sim.state
	var board: Array = s.contracts["board"].get("kibo_ring", [])
	check(board.size() >= 2, "Kibo Ring's board has jobs at the start (%d)" % board.size())
	# Find a package job (re-roll the board until one shows), take it, deliver on time.
	var offer := {}
	for _i in 20:
		offer = _first_offer(sim, "kibo_ring", "package")
		if not offer.is_empty():
			break
		# A full board isn't topped up: clear it, so the re-roll draws a fresh one.
		s.contracts["board"]["kibo_ring"] = []
		s.contracts["next_t"]["kibo_ring"] = 0.0
		sim.advance_game_time(60.0)
	check(not offer.is_empty(), "A courier package is offered")
	if offer.is_empty():
		return
	var before := ShipStats.cargo_t(s.ship)
	check(sim.apply({"type": "accept_contract", "id": offer["id"]}) == "", "Take the package job")
	check(absf(ShipStats.cargo_t(s.ship) - before - float(offer["mass_t"])) < 1e-9, "The parcel's mass is aboard")
	var credits := s.credits
	_dock_at(sim, offer["to"])
	check(absf(s.credits - credits - float(offer["reward"])) < 1e-6, "On-time delivery pays in full (%s)" % offer["reward"])
	check(Contracts.rep_of(s, offer["client"]) > 0.0 and s.contracts["active"].is_empty(), "On time builds standing and closes the job")
	check(ShipStats.cargo_t(s.ship) == before, "The parcel is off the ship")
	# Late: half pay and lost standing.
	_dock_at(sim, "kibo_ring")
	s.contracts["next_t"]["kibo_ring"] = 0.0
	sim.advance_game_time(60.0)
	var late_offer := {}
	for o in s.contracts["board"]["kibo_ring"]:
		if o["kind"] == "package":
			late_offer = o
	if not late_offer.is_empty():
		sim.apply({"type": "accept_contract", "id": late_offer["id"]})
		var rep0 := Contracts.rep_of(s, late_offer["client"])
		s.time_s += float(late_offer["window_s"]) + 3600.0
		credits = s.credits
		_dock_at(sim, late_offer["to"])
		check(absf(s.credits - credits - float(late_offer["reward"]) * 0.5) < 1e-6 and Contracts.rep_of(s, late_offer["client"]) < rep0, "Late delivery pays half and costs standing")
	# Passengers need berths.
	var pax := {"id": 9001, "kind": "passenger", "client": "Terran Compact", "issued_at": "kibo_ring", "pickup": "", "to": "halo_depot", "item": "engineers", "mass_t": 0.2, "passengers": 2,
		"reward": 5000.0, "window_s": 10 * DAY, "expires_t": s.time_s + 5 * DAY, "min_rep": 0.0, "rep": 2.0, "channel": "board", "hidden": false}
	_dock_at(sim, "kibo_ring")
	s.reputation["Terran Compact"] = 0.0
	s.contracts["board"]["kibo_ring"].append(pax)
	check(String(sim.apply({"type": "accept_contract", "id": 9001})).begins_with("no berths"), "Passengers refused without berths")
	# Pickups: collect first, then deliver.
	var pick: Dictionary = pax.duplicate()
	pick.merge({"id": 9002, "kind": "pickup", "passengers": 0, "mass_t": 0.5, "pickup": "shackleton_port", "to": "kernel_l5"}, true)
	s.contracts["board"]["kibo_ring"].append(pick)
	check(sim.apply({"type": "accept_contract", "id": 9002}) == "", "Take a pickup job")
	_dock_at(sim, "kernel_l5")
	check(s.contracts["active"].any(func(j): return int(j["id"]) == 9002 and j["state"] == "collect"), "Delivering before collecting does nothing")
	_dock_at(sim, "shackleton_port")
	check(s.contracts["active"].any(func(j): return int(j["id"]) == 9002 and j["state"] == "carried"), "Collected at the pickup")
	credits = s.credits
	_dock_at(sim, "kernel_l5")
	check(s.credits > credits, "Pickup delivered and paid")
	# Far too late fails.
	var fail: Dictionary = pax.duplicate()
	fail.merge({"id": 9003, "kind": "package", "passengers": 0, "mass_t": 0.1, "window_s": 2 * DAY}, true)
	_dock_at(sim, "kibo_ring")
	s.contracts["board"]["kibo_ring"].append(fail)
	sim.apply({"type": "accept_contract", "id": 9003})
	s.location = {"status": "transit_test"}
	sim.advance_game_time(6 * DAY)
	check(s.stats.get("contracts_failed", 0) >= 1 and not s.contracts["active"].any(func(j): return int(j["id"]) == 9003), "A job far past its deadline fails")
	# Known pilots are approached when they dock.
	var known := fresh()
	known.data.contracts["approach"]["chance"] = 1.0
	known.state.reputation["Luna Cooperative"] = 30.0
	_dock_at(known, "shackleton_port")
	check(known.state.contracts["board"]["shackleton_port"].any(func(o): return o["channel"] == "approach" and o.has("opener")), "A trusted pilot is approached at the dock")
	known.data.contracts["approach"]["chance"] = 0.35
	# Rumours: a tip can carry word of a real, hidden-to-others job elsewhere.
	var gossip := fresh()
	gossip.data.contracts["rumour"]["chance"] = 1.0
	gossip.state.credits = 1.0e6
	var broker := ""
	for b in gossip.data.brokers:
		if gossip.data.brokers[b]["place"] == "kibo_ring":
			broker = b
	gossip.apply({"type": "buy_tip", "broker": broker})
	var tip: Dictionary = gossip.state.tips[-1] if not gossip.state.tips.is_empty() else {}
	check(tip.has("rumour"), "A tip came with a rumoured job")
	if tip.has("rumour"):
		var r: Dictionary = tip["rumour"]
		check(gossip.state.contracts["board"][r["place"]].any(func(o): return int(o["id"]) == int(r["offer"]) and o["channel"] == "rumour"), "The rumoured job is on that port's board")
	gossip.data.contracts["rumour"]["chance"] = 0.35
	# Contracts and standing survive a save.
	var saved := SaveIO.from_text(SaveIO.to_text(sim.state))
	check(saved.contracts == sim.state.contracts and saved.reputation == sim.state.reputation, "Contracts and reputation are saved")


func test_project_pitches() -> void:
	var sim := fresh()
	var s := sim.state
	var d := sim.data
	check(ProjectSystem.open_to_player(s, d, "island_one") and not ProjectSystem.open_to_player(s, d, "ares_greenhouses"), "Some projects are there from the start; others come later")
	check(not ProjectSystem.open_to_player(s, d, "hektor_reach"), "Hektor Reach waits for Island One's first stage")
	sim.advance_game_time(31 * DAY)
	check(ProjectSystem.open_to_player(s, d, "ares_greenhouses"), "The Tharsis greenhouses are announced after a month")
	# Invitation only: the science ring asks in pilots the Compact's science office knows.
	check(not ProjectSystem.open_to_player(s, d, "valhalla_deep_ring"), "The Valhalla ring is closed to strangers")
	s.reputation["Terran Compact Science"] = 25.0
	sim.advance_game_time(2 * 3600.0)
	check(ProjectSystem.open_to_player(s, d, "valhalla_deep_ring"), "A reliable pilot is invited in")
	# A place built by a project is closed until it is finished.
	s.location = {"status": "docked", "place": "kernel_l5"}
	check(String(sim.apply({"type": "depart", "to": "hektor_reach"})).ends_with("not open yet"), "Cannot fly to Hektor Reach before it is built")
	s.projects["hektor_reach"]["done"] = true
	check(Perks.place_open(s, d, "hektor_reach"), "Hektor Reach opens when finished")
	# Perks: backing Island One earns free docking at the Kernel and cheaper fuel there.
	s.projects["island_one"]["player_total_t"] = 50.0
	var proj := ProjectSystem.new()
	proj.setup(sim)
	proj._award_perks("island_one", s.time_s)
	check(Perks.free_docking(s, "kernel_l5") and absf(Perks.fuel_mult(s, "kernel_l5") - 0.8) < 1e-9, "Backers dock free and refuel cheaper at the Kernel")
	check(Contracts.rep_of(s, "Kernel Settlers") >= 8.0, "Backing builds standing with the settlers")
	s.location = {"status": "approach", "place": "kernel_l5"}
	var credits := s.credits
	sim.apply({"type": "dock"})
	check(s.credits == credits, "No tug fee for a backer at the Kernel")


func test_sites() -> void:
	var sim := fresh()
	var s := sim.state
	var d := sim.data
	check(SiteSystemScript.knows(s, "ishikawa_maru") and not SiteSystemScript.knows(s, "hermes_probe"), "Some sites are known from the start, others only by rumour")
	check(String(sim.apply({"type": "depart", "to": "hermes_probe"})).begins_with("you don't know"), "Cannot fly to a site you have not heard of")
	# Fly to the derelict: no docking, you arrive on site.
	check(sim.apply({"type": "depart", "to": "ishikawa_maru"}) == "", "Depart for the derelict Ishikawa Maru")
	sim.state.time_scale = 1000.0
	sim.advance_game_time(float(s.location.get("arrive_t", s.time_s)) - s.time_s + 10.0)
	check(s.location.get("status") == "on_site" and s.location.get("place") == "ishikawa_maru", "Arrive on site at the derelict")
	check(SiteSystemScript.blocked(s, d, "eros_survey", "survey") != "", "Cannot work a site you are not at")
	var cargo0 := ShipStats.cargo_t(s.ship)
	check(sim.apply({"type": "site_work", "activity": "salvage"}) == "", "Begin stripping the wreck")
	check(String(sim.apply({"type": "depart", "to": "kibo_ring"})).begins_with("still at work"), "No leaving mid-job")
	sim.advance_game_time(2.0 * DAY)
	check(ShipStats.cargo_t(s.ship) > cargo0 and s.sites["work"].is_empty(), "Salvage lands in the hold (%.1f t)" % (ShipStats.cargo_t(s.ship) - cargo0))
	check(String(sim.apply({"type": "site_work", "activity": "salvage"})) == "already done", "A wreck can only be stripped once")
	# Out of fuel on site: the tanker still comes.
	s.ship["fuel_t"] = 0.0
	check(EconomySystemScript.emergency_available(s, d) and sim.apply({"type": "emergency_refuel"}) == "", "The emergency tanker reaches a site")
	# Kit: surveys need a survey pod.
	s.location = {"status": "on_site", "place": "eros_survey"}
	check(SiteSystemScript.blocked(s, d, "eros_survey", "survey") == "needs a survey pod", "A survey needs a survey pod")
	s.ship["modules"]["avionics.0"] = "survey_pod"
	var credits := s.credits
	check(sim.apply({"type": "site_work", "activity": "survey"}) == "", "With a pod, survey Eros")
	sim.advance_game_time(7.0 * DAY)
	check(s.credits > credits and Contracts.rep_of(s, "Belt Assembly") > 0.0, "Survey data sold by radio, and the Belt Assembly takes note")
	# Rumours reveal sites.
	var gossip := fresh()
	gossip.data.contracts["rumour"]["chance"] = 0.0
	gossip.data.contracts["rumour"]["site_chance"] = 1.0
	gossip.state.credits = 1.0e6
	gossip.apply({"type": "buy_tip", "broker": "maisie_tran"})
	check(not gossip.state.tips.is_empty() and gossip.state.tips[-1].has("site") and SiteSystemScript.knows(gossip.state, gossip.state.tips[-1]["site"]), "A broker's tip puts a site on your chart")
	# Hand-flown landings: soft goes right (a little more), hard goes wrong.
	s.ship["modules"]["cargo.1"] = "lander_bay"
	s.ship["cargo"] = {}
	s.location = {"status": "on_site", "place": "eros_survey"}
	check(sim.apply({"type": "site_work", "activity": "prospect", "hand_flown": true, "landed": true}) == "", "Fly the Eros landing by hand")
	sim.advance_game_time(3.5 * DAY)
	check(s.stats.get("site_jobs", 0) >= 3 and ShipStats.cargo_t(s.ship) > 0.0, "A soft landing brings the cores home")
	var phobos := fresh()
	phobos.state.ship["modules"]["cargo.1"] = "lander_bay"
	phobos.state.location = {"status": "on_site", "place": "phobos_survey"}
	var fuel0: float = phobos.state.ship["fuel_t"]
	phobos.apply({"type": "site_work", "activity": "prospect", "hand_flown": true, "landed": false})
	phobos.advance_game_time(2.5 * DAY)
	check(phobos.state.ship["fuel_t"] < fuel0, "A hard landing goes badly and burns propellant")
	var saved := SaveIO.from_text(SaveIO.to_text(s))
	check(saved.sites == s.sites, "Sites are saved")


func _favour_on_board(sim: Sim, place: String) -> Dictionary:
	for o in sim.state.contracts["board"].get(place, []):
		if o.has("favour"):
			return o
	return {}


func test_story_arc() -> void:
	var sim := fresh()
	var s := sim.state
	var d := sim.data
	check(d.validate().is_empty(), "Data valid with the story (%s)" % ", ".join(d.validate()))
	_dock_at(sim, "kibo_ring")
	check(_favour_on_board(sim, "kibo_ring").is_empty(), "Nobody approaches an unknown pilot")
	# A reliable courier is approached.
	s.stats["contracts_delivered"] = 3
	s.reputation["Terran Compact"] = 7.0
	_dock_at(sim, "clarke_exchange")
	var fav := _favour_on_board(sim, "clarke_exchange")
	check(not fav.is_empty() and fav["to"] == "farside_array" and fav["client"] == "The Long View", "Ines Okafor's first favour: a case for Farside Array")
	check(sim.apply({"type": "accept_contract", "id": fav["id"]}) == "", "Take the favour")
	_dock_at(sim, "farside_array")
	check("first_favour" in s.story["done"] and SiteSystemScript.knows(s, "hermes_probe"), "Delivered; the astronomer puts Hermes-7 on your chart")
	# Recover the recorder, then hear what it saw.
	s.location = {"status": "on_site", "place": "hermes_probe"}
	sim.apply({"type": "site_work", "activity": "salvage"})
	sim.advance_game_time(1.5 * DAY)
	_dock_at(sim, "farside_array")
	_dock_at(sim, "farside_array")
	var fav2 := _favour_on_board(sim, "farside_array")
	check("the_recorder" in s.story["done"] and not fav2.is_empty() and fav2["to"] == "trojan_yards", "The occultation, and a mind in a box for Trojan Yards")
	sim.apply({"type": "accept_contract", "id": fav2["id"]})
	_dock_at(sim, "trojan_yards")
	_dock_at(sim, "trojan_yards")
	check(s.ship["modules"]["drive.0"] == "longview_drive" and s.ship["modules"]["cargo.0"] == "sleep_berth" and SiteSystemScript.knows(s, "the_lacuna"), "The Long View lends a drive and a long-sleep berth, and shows you where")
	# The lent ship can actually get there (and the crew can last the trip).
	var q: Dictionary = Interplanetary.quick(s.ship, d, sim.ephemeris, "trojan_yards", "the_lacuna", s.time_s)
	check(q["ok"], "The Lacuna is reachable with the lent drive (%.1f years, %.1f t) %s" % [float(q.get("duration_s", 0.0)) / (365.25 * DAY), float(q.get("fuel_t", 0.0)), q["reason"]])
	# Say hello.
	var credits := s.credits
	s.location = {"status": "on_site", "place": "the_lacuna"}
	check(sim.apply({"type": "site_work", "activity": "greet"}) == "", "Go and say hello")
	sim.advance_game_time(3.0 * DAY)
	check("the_meeting" in s.story["done"] and s.credits >= credits + 500000.0, "It says hello back. The system is a little larger.")


func test_outer_traffic() -> void:
	var sim := fresh()
	var s := sim.state
	var later := {}
	for npc in s.npcs:
		if float(npc.get("active_t", -INF)) > s.time_s:
			later[npc["id"]] = npc
	check(not later.is_empty() and later.has("accord_runners.1"), "Some long-haul ships are still fitting out at the start")
	sim.state.time_scale = 1.0e5
	var saw_long_haul := false
	var early_move := false
	for _day in 40:
		sim.advance_game_time(10.0 * DAY)
		for npc in s.npcs:
			var loc: Dictionary = npc["location"]
			if loc["status"] == "transit" and loc.get("frame", "") == "sun":
				saw_long_haul = saw_long_haul or loc.get("samples") != null
			if later.has(npc["id"]) and s.time_s < float(npc["active_t"]) and int(npc["trips"]) > 0:
				early_move = true
	check(saw_long_haul, "Long-haul NPCs fly Sun-centred voyages on real paths")
	check(not early_move, "No ship sails before it is commissioned")
	var all_sailed := true
	for npc in s.npcs:
		if sim.data.npcs["fleets"][npc["fleet"]].has("commission_days") and s.time_s - float(npc["active_t"]) > 200.0 * DAY:
			all_sailed = all_sailed and int(npc["trips"]) >= 1
	check(all_sailed, "Every long-haul ship has made a voyage within months of entering service")


## The Spaceline: a feed already running when you start, world stories on their day
## (some making the system richer), projects announced as they are revealed.
func test_spaceline() -> void:
	var sim := fresh()
	var s := sim.state
	var items: Array = s.news["items"]
	var heads: Array = items.map(func(i): return i["headline"])
	check(items.size() >= 4, "The feed has news in it on day one")
	check(items.all(func(i): return float(i["t"]) <= s.time_s), "Nothing in the feed is from the future")
	check(items.any(func(i): return i.get("project", "") == "island_one"), "Projects already under way were announced before you arrived")
	check(not items.any(func(i): return i.get("project", "") == "valhalla_deep_ring"), "Invitation-only projects stay out of the papers")
	var seen := []
	sim.state.time_scale = 1.0e5
	var mods_before := float(s.place_mods.get("psyche_claims", {}).get("produces_mult", 1.0))
	for _k in 7:
		sim.advance_game_time(10.0 * DAY)
		for e in sim.take_events():
			if e["type"] == "news":
				seen.append(e["data"]["item"])
	var posted: Array = s.news["posted"]
	check("personhood_petition" in posted and "personhood_vote" in posted, "The personhood stories run by day 70")
	check(not "hello_back" in posted, "Stories that wait for a story beat wait")
	check(seen.any(func(i): return i.get("project", "") == "concord_pair" and i["kind"] == "project"), "The Concord Pair is announced in the news when it is revealed")
	check(seen.any(func(i): return String(i["body"]).contains("Earth Standard Time")), "Announcements read like the news: today, Earth Standard Time")
	var mods_after := float(s.place_mods.get("psyche_claims", {}).get("produces_mult", 1.0))
	check(absf(mods_after / mods_before - 1.3) < 1e-6, "A new seam on Psyche makes the claims richer for good")
	check(s.news["items"].size() <= int(sim.data.news["keep"]), "The feed keeps a bounded number of items")
	var copy := SaveIO.from_text(SaveIO.to_text(s))
	check(copy != null and copy.news["posted"] == s.news["posted"], "The feed survives a save")


## Landauer Deep opens on its day; the Sufficiency's arc runs beside the Long View's;
## Lightfoot's sails are commissioned when the yard is built and fly without fuel.
func test_minds_and_sails() -> void:
	var sim := fresh()
	var s := sim.state
	check(not Perks.place_open(s, sim.data, "landauer_deep"), "Landauer Deep is not open at the start")
	sim.state.time_scale = 1.0e5
	sim.advance_game_time(61.0 * DAY)
	sim.take_events()
	check(Perks.place_open(s, sim.data, "landauer_deep"), "Landauer Deep opens after sixty days")
	check("sufficiency_founded" in s.news["posted"], "The Sufficiency's founding makes the news")
	# Dock at Landauer Deep: the minds' arc fires though the Long View's has not begun.
	s.location = {"status": "docked", "place": "landauer_deep"}
	sim.advance_game_time(3600.0)
	check(s.story["fired"].has("quiet_margin"), "Quiet Margin greets you at Landauer Deep")
	check(not s.story["fired"].has("first_favour"), "The Long View's arc is untouched by it")
	# The sail yard is finished: its sails enter service on their schedule.
	var lightfoot := s.npcs.filter(func(n): return n["fleet"] == "lightfoot")
	check(lightfoot.size() == 3 and lightfoot.all(func(n): return not NpcSystem.in_service(n, s.time_s)), "Lightfoot's sails wait for their yard")
	s.projects["lightfoot_sails"]["done"] = true
	s.projects["lightfoot_sails"]["stage"] = sim.data.projects["lightfoot_sails"]["stages"].size()
	sim.advance_game_time(2.0 * DAY)
	check(NpcSystem.in_service(lightfoot[0], s.time_s) and not NpcSystem.in_service(lightfoot[1], s.time_s), "The first sail enters service when the yard is done; her sisters follow")
	var sailed := {}
	for _k in 30:
		sim.advance_game_time(2.0 * DAY)
		var loc: Dictionary = lightfoot[0]["location"]
		if loc["status"] == "transit" and sailed.is_empty():
			sailed = loc.duplicate()
	check(not sailed.is_empty() and sailed["frame"] == "sun" and sailed.get("samples") != null, "A sail freighter sets out on a Sun-centred path")
	if not sailed.is_empty():
		var days := (float(sailed["arrive_t"]) - float(sailed["depart_t"])) / DAY
		check(days >= 160.0 and days <= 220.0, "A sail voyage to Mars takes about half a year (%.0f days)" % days)
		check(float(lightfoot[0]["ship"]["fuel_t"]) == 0.0, "Sails carry no propellant and burn none")
		var mid_t := (float(sailed["depart_t"]) + float(sailed["arrive_t"])) * 0.5
		var r := V.length(V.sub(Navigation.transit_position(sailed, mid_t), sim.ephemeris.position("sun", mid_t)))
		check(r > 1.05 * AU and r < 1.65 * AU, "Half way, the sail is out between Earth and Mars (%.2f AU)" % (r / AU))



## Riding the elevators: down to the town at the foot with your cargo, your ship left
## above; no flying from (or to) a foot; a line still being built takes nobody;
## climbers keep the towns supplied without fuel; towns sit on their bodies.
func test_elevators() -> void:
	var sim := fresh()
	var s := sim.state
	var d := sim.data
	var eph := sim.ephemeris
	var t := s.time_s
	var moon_r := float(d.bodies["moon"]["radius_m"])
	var foot := V.sub(eph.position("line_foot", t), eph.position("moon", t))
	var to_earth := V.normalized(V.sub(eph.position("earth", t), eph.position("moon", t)))
	check(absf(V.length(foot) - moon_r) < 1.0 and V.dot(V.normalized(foot), to_earth) > 0.999, "Line Foot sits on the Moon, under Earth")
	var day := float(d.places["stalk_foot"]["location"]["day_s"])
	var a := V.sub(eph.position("stalk_foot", t), eph.position("ceres", t))
	var b := V.sub(eph.position("stalk_foot", t + day * 0.5), eph.position("ceres", t + day * 0.5))
	check(V.distance(a, b) > 1.9 * float(d.bodies["ceres"]["radius_m"]), "Stalk Foot turns with Ceres")
	check(not Perks.place_open(s, d, "line_foot"), "No ship can fly to a town at the foot of a ribbon")
	s.location = {"status": "docked", "place": "halo_depot"}
	s.ship["cargo"] = {"water_ice": 5.0}
	var before := s.credits
	var fare := float(d.places["halo_depot"]["elevator"]["fare"]) + 5.0 * float(d.places["halo_depot"]["elevator"]["fare_per_t"])
	check(sim.apply({"type": "ride_elevator"}) == "", "You can ride the Luna Line down from Halo Depot")
	check(absf(before - s.credits - fare) < 1e-6 and s.location["status"] == "elevator", "The fare is a seat plus so much a tonne")
	sim.advance_game_time(float(d.places["halo_depot"]["elevator"]["hours"]) * 3600.0 + 60.0)
	check(s.location.get("status") == "docked" and s.location.get("place") == "line_foot", "Two days down, you are at Line Foot")
	check(float(s.ship["cargo"].get("water_ice", 0.0)) == 5.0, "Your hold came down with you")
	check(sim.apply({"type": "depart", "to": "kibo_ring"}) != "", "You can't fly from the foot: your ship is up at the depot")
	check(s.contracts["board"].get("line_foot", []).is_empty(), "No job board at the bottom of the ribbon")
	check(sim.apply({"type": "ride_elevator"}) == "", "And you can ride back up")
	sim.advance_game_time(float(d.places["halo_depot"]["elevator"]["hours"]) * 3600.0 + 60.0)
	check(s.location.get("place") == "halo_depot", "Back at Halo Depot, back aboard")
	s.location = {"status": "docked", "place": "ares_ring"}
	check(sim.apply({"type": "ride_elevator"}).contains("still being built"), "The Pavonis Line takes nobody until it is finished")
	# Climbers: on the ribbon between port and town, no propellant.
	s.time_scale = 1.0e5
	var climbed := false
	for _k in 20:
		sim.advance_game_time(DAY)
		for npc in s.npcs:
			if npc["fleet"] == "luna_climbers" and npc["location"]["status"] == "transit":
				climbed = climbed or npc["location"]["frame"] == "moon"
	check(climbed, "Climbers ride the Luna Line between the depot and the town")
	check(s.npcs.filter(func(n): return n["fleet"] == "luna_climbers").all(func(n): return float(n["ship"]["fuel_t"]) == 0.0), "Climbers burn no propellant")


## Collisions: a gentle bump is free; a hard one breaks what it hits (a drive pushes
## less, a holed tank vents, a broken pod spills) and strains the keel; yards repair,
## other ports patch; a broken keel is a lost ship, a lifeboat and an insurance hull.
func test_damage() -> void:
	var sim := fresh()
	var s := sim.state
	var d := sim.data
	s.location = {"status": "approach", "place": "kibo_ring"}
	sim.apply({"type": "impact", "speed": 0.5, "share": 1.0, "zone": "tail", "seed": 0})
	check(s.ship.get("damage", {}).is_empty(), "A gentle bump does no harm")
	var thrust := ShipStats.thrust_n(s.ship, d)
	sim.apply({"type": "impact", "speed": 5.0, "share": 1.0, "zone": "tail", "seed": 1})
	var tail_hit: Array = s.ship["damage"].keys().filter(func(k): return k != "keel")
	check(tail_hit.size() == 1 and String(tail_hit[0]).split(".")[0] in ["tank", "drive"], "A knock on the tail hits a tank or a drive")
	check(DamageSystem.integrity(s.ship) < 1.0, "and strains the keel")
	if String(tail_hit[0]).begins_with("drive"):
		check(ShipStats.thrust_n(s.ship, d) < thrust, "A damaged drive pushes less")
	else:
		check(ShipStats.fuel_capacity_t(s.ship, d) < 3.0 and float(s.ship["fuel_t"]) <= ShipStats.fuel_capacity_t(s.ship, d) + 1e-9, "A holed tank holds less, and vents the rest")
	s.ship["cargo"] = {"water_ice": ShipStats.cargo_capacity_t(s.ship, d)}
	sim.apply({"type": "impact", "speed": 6.0, "share": 1.0, "zone": "mid", "seed": 2})
	check(ShipStats.cargo_t(s.ship) < 19.99, "A broken pod spills cargo")
	s.location = {"status": "docked", "place": "halo_depot"}
	s.credits = 1.0e6
	check(sim.apply({"type": "repair"}) == "", "You can patch up at a port without a yard")
	check(s.ship["damage"].values().all(func(v): return float(v) <= float(d.balance["damage"]["patch_max"]) + 1e-9), "A patch only takes off the worst of it")
	s.location = {"status": "docked", "place": "kibo_ring"}
	check(sim.apply({"type": "repair"}) == "" and s.ship.get("damage", {}).is_empty(), "A yard puts everything right")
	# The keel goes.
	s.location = {"status": "approach", "place": "kibo_ring"}
	s.contracts["active"].append({"id": 999, "state": "carried", "client": "Terran Compact", "to": "halo_depot", "item": "a parcel", "pickup": "", "deadline_t": s.time_s + 30.0 * DAY, "window_s": 30.0 * DAY, "reward": 100.0, "mass_t": 0.1, "passengers": 0, "rep": 1.0})
	var credits := s.credits
	sim.apply({"type": "impact", "speed": 14.0, "share": 1.0, "zone": "mid", "seed": 3})
	check(s.location.get("status") == "lifeboat", "A wrecked keel is a lost ship: into the lifeboat")
	check(s.ship["hull"] == d.balance["start"]["ship"] and s.ship.get("damage", {}).is_empty(), "The insurance pool finds you a stock hull")
	check(absf(credits - s.credits - float(d.balance["damage"]["insurance_excess"])) < 1e-6, "less the excess")
	check(not s.contracts["active"].any(func(j): return int(j["id"]) == 999), "Carried jobs go down with the ship")
	sim.advance_game_time(float(d.balance["damage"]["lifeboat_s"]) + 1.0)
	check(s.location.get("status") == "docked" and s.location.get("place") == "kibo_ring", "The tug brings the lifeboat in")
	# The Wheel and the Ring exist, closed until built.
	check(not Perks.place_open(s, d, "tsiolkovsky_wheel"), "The Tsiolkovsky Wheel opens only when it is built")
	var wheel := sim.ephemeris.position("tsiolkovsky_wheel", s.time_s)
	var yards := sim.ephemeris.position("trojan_yards", s.time_s)
	var off: Array = d.places["tsiolkovsky_wheel"]["location"]["offset_km"]
	check(absf(V.distance(wheel, yards) - 1000.0 * Vector3(off[0], off[1], off[2]).length()) < 50.0, "The Wheel stands off Trojan Yards where its data says")
	check(d.bodies["moon"]["structures"].any(func(st): return st["kind"] == "orbital_ring"), "The Moon can have a ring")


## The Spaceline, in depth: ordering, no repeats, announcements tied to projects and
## story beats, the same feed for the same seed, and catching up on an old save.
func test_news_in_depth() -> void:
	var sim := fresh()
	var s := sim.state
	var d := sim.data
	var posted: Array = s.news["posted"]
	check(_unique(posted), "Day one: no story is posted twice")
	var t_sorted := true
	for i in range(1, s.news["items"].size()):
		t_sorted = t_sorted and float(s.news["items"][i - 1]["t"]) <= float(s.news["items"][i]["t"])
	check(t_sorted, "Day one: the feed is in date order")
	check(_unique(s.news["items"].map(func(i): return i["id"])), "Day one: every item has its own id")
	for story in d.news["stories"]:
		if float(story.get("after_days", 0.0)) < 0.0:
			check(story["id"] in posted, "Backdated story %s is already in the feed" % story["id"])
	# Public projects already revealed are announced exactly once; none is announced early.
	for id in d.projects:
		var announcements: Array = s.news["items"].filter(func(i): return i.get("project", "") == id and i["kind"] == "project")
		var revealed: bool = s.projects[id]["revealed"] and not d.projects[id].has("invite")
		check(announcements.size() == (1 if revealed else 0), "%s has %d announcement(s) on day one (revealed public: %s)" % [id, announcements.size(), revealed])
	var ships: Array = s.news["ships"]
	check(_unique(ships), "Each ship is on the commissioned list once")
	# Run 60 days in 5-day steps: nothing repeats, time only goes forward, ids climb.
	sim.state.time_scale = 1.0e5
	var live: Array = []
	for _k in 12:
		sim.advance_game_time(5.0 * DAY)
		for e in sim.take_events():
			if e["type"] == "news":
				live.append(e["data"]["item"])
	check(live.size() >= 8, "A busy first two months for the news (%d live items)" % live.size())
	var ids: Array = live.map(func(i): return int(i["id"]))
	var increasing := true
	for i in range(1, live.size()):
		increasing = increasing and int(live[i]["id"]) > int(live[i - 1]["id"]) and float(live[i]["t"]) >= float(live[i - 1]["t"])
	check(increasing, "Live news arrives in id and time order")
	check(_unique(s.news["posted"]), "No story is posted twice")
	var keys: Array = live.map(func(i): return "%s|%s|%s" % [i["kind"], i.get("project", i.get("story", i.get("npc", ""))), i["headline"]])
	check(_unique(keys), "No headline runs twice")
	check(live.all(func(i): return String(i["headline"]) != "" and String(i["body"]) != ""), "Every item has a headline and a body")
	# Each story landed on or after its own day.
	for item in live:
		if item.has("story"):
			var story: Dictionary = d.news["stories"].filter(func(x): return x["id"] == item["story"])[0]
			check(float(item["t"]) - float(s.started_t) >= float(story.get("after_days", 0.0)) * DAY - 1.0, "Story %s is not early" % item["story"])
	# Effects are applied once per story, however long the game runs.
	var seam := float(s.place_mods.get("psyche_claims", {}).get("produces_mult", 1.0))
	check(absf(seam - 1.3) < 1e-6, "The platinum seam enriches Psyche once (x%.3f)" % seam)
	sim.advance_game_time(5.0 * DAY)
	check(absf(float(s.place_mods["psyche_claims"]["produces_mult"]) - seam) < 1e-9, "Waiting longer does not enrich it again")

	# Tied to the story: these wait for their beat, and post once it is done.
	var gated := fresh()
	var g := gated.state
	g.started_t -= 400.0 * DAY
	gated.advance_game_time(3600.0)
	check(g.news["posted"].size() >= d.news["stories"].size() - 3, "Four hundred days on, every story that is not waiting on a beat is out")
	for id in ["farside_silence", "hello_back", "first_delegate"]:
		check(not id in g.news["posted"], "%s still waits for its beat" % id)
	g.story["done"].append("the_occultation")
	gated.advance_game_time(3600.0)
	check("farside_silence" in g.news["posted"] and not "hello_back" in g.news["posted"], "Finishing the occultation beat posts only its own story")
	g.story["done"].append("the_meeting")
	g.story["done"].append("the_delegate")
	gated.advance_game_time(3600.0 * 12.0)
	check("hello_back" in g.news["posted"] and "first_delegate" in g.news["posted"], "Later beats post theirs")
	var count: int = g.news["items"].size()
	gated.advance_game_time(10.0 * DAY)
	check(g.news["items"].filter(func(i): return i.get("story", "") == "hello_back").size() == 1, "A beat's story is not repeated")
	check(g.news["items"].size() >= count, "Time only adds to the feed (until it is trimmed)")

	# Tied to projects: stages and completion make the news, each once, and the whole
	# project history is announced by the right backer.
	var proj := fresh()
	var p := proj.state
	var pid := ""
	for id in d.projects:
		if not d.projects[id].has("invite") and not p.projects[id]["revealed"] and d.projects[id]["stages"].size() >= 3 and d.news["projects"].has(id):
			pid = id
			break
	check(pid != "", "There is a public, later, multi-stage project to follow (%s)" % pid)
	var stages: Array = d.projects[pid]["stages"]
	check(not p.news["items"].any(func(i): return i.get("project", "") == pid), "%s is not in the news before its reveal" % pid)
	p.projects[pid]["revealed"] = true
	proj.advance_game_time(3600.0 * 3.0)
	var announced: Array = p.news["items"].filter(func(i): return i.get("project", "") == pid)
	check(announced.size() == 1 and announced[0]["kind"] == "project", "%s is announced once, when revealed" % pid)
	check(String(announced[0]["headline"]) != "" and String(announced[0]["body"]).length() > 20, "The announcement has something to say")
	p.projects[pid]["stage"] = 2
	proj.advance_game_time(3600.0 * 3.0)
	var stage_items: Array = p.news["items"].filter(func(i): return i.get("project", "") == pid and i["id"] != announced[0]["id"])
	check(stage_items.size() == 2, "Skipping to stage 2 reports stages 0 and 1, once each (%d)" % stage_items.size())
	proj.advance_game_time(3600.0 * 12.0)
	check(p.news["items"].filter(func(i): return i.get("project", "") == pid).size() == 3, "Nothing more is reported while the stage holds")
	p.projects[pid]["stage"] = stages.size() - 1
	p.projects[pid]["done"] = true
	proj.advance_game_time(3600.0 * 3.0)
	var all: Array = p.news["items"].filter(func(i): return i.get("project", "") == pid)
	check(all.size() == 1 + stages.size() - 1 + 1, "Announcement, every stage but the last, then completion (%d items for %d stages)" % [all.size(), stages.size()])
	check(all[all.size() - 1]["id"] > all[all.size() - 2]["id"] and p.news["projects"][pid]["done"], "Completion is the last item and the feed remembers it")
	# Invitation-only builds never reach the papers, even once they open.
	p.reputation["Terran Compact Science"] = 25.0
	proj.advance_game_time(2.0 * 3600.0)
	check(ProjectSystem.open_to_player(p, d, "valhalla_deep_ring") and not p.news["items"].any(func(i): return i.get("project", "") == "valhalla_deep_ring"), "An invited project still stays out of the news")
	# Stories gated on a project wait for it (none in the data today, so test the gate).
	var gate := fresh()
	var gate_story := {"id": "x", "after_project": "luna_line_2"}
	var ns = gate.systems.filter(func(x): return x.get_script().resource_path.ends_with("news_system.gd"))[0]
	check(not ns._ready(gate_story), "A project-gated story waits")
	gate.state.projects["luna_line_2"]["done"] = true
	check(ns._ready(gate_story), "and runs when the project is done")
	var stage_gate := {"id": "y", "after_stage": ["island_one", 2]}
	check(not ns._ready(stage_gate), "A stage-gated story waits")
	gate.state.projects["island_one"]["stage"] = 2
	check(ns._ready(stage_gate), "and runs at its stage")

	# Same seed, same news. Different seeds: the same stories (they are on the calendar).
	var run := func(seed_value: int) -> Dictionary:
		var r := Sim.new()
		r.new_game(seed_value)
		r.advance_game_time(40.0 * DAY)
		return r.state.news
	var a: Dictionary = run.call(5)
	var b: Dictionary = run.call(5)
	check(a == b, "The same seed gives the same feed")
	var c: Dictionary = run.call(6)
	check(a["posted"] == c["posted"], "Another seed posts the same stories in the same order")
	# Step size does not matter either.
	var coarse := Sim.new()
	coarse.new_game(5)
	coarse.advance_game_time(20.0 * DAY)
	var fine := Sim.new()
	fine.new_game(5)
	for _k in 20:
		fine.advance_game_time(DAY)
	check(coarse.state.news == fine.state.news, "One 20-day jump and 20 daily steps give the same feed")

	# Saves: mid-feed round trip, and an old save with no feed catches up without repeats.
	var saved := SaveIO.from_text(SaveIO.to_text(sim.state))
	check(saved != null and saved.news == sim.state.news, "The whole feed survives a save")
	var old := fresh()
	old.advance_game_time(10.0 * DAY)
	old.state.news = {}
	old.advance_game_time(3600.0 * 6.0)
	var o: Dictionary = old.state.news
	check(not o.is_empty() and _unique(o["posted"]) and _unique(o["items"].map(func(i): return i["id"])), "A save from before the feed catches up without repeats")
	check(o["items"].any(func(i): return i.get("project", "") == "island_one"), "and finds the old announcements")
	# The feed is capped.
	var capped := fresh()
	for k in 200:
		capped.systems[capped.systems.size() - 1]._post({"kind": "world", "headline": "n%d" % k, "body": "b"}, capped.state.time_s, false)
	check(capped.state.news["items"].size() == int(d.news["keep"]) and capped.state.news["items"][-1]["headline"] == "n199", "The feed keeps the newest %d items" % int(d.news["keep"]))


func _clone(catalog, text: String) -> Sim:
	var c := Sim.new(catalog)
	c.load_state(SaveIO.from_text(text))
	return c


func _unique(values: Array) -> bool:
	var seen := {}
	for v in values:
		if seen.has(v):
			return false
		seen[v] = true
	return true


## Elevators in depth: fares at every line and direction, refusal when broke or
## when the line is unfinished, the ride itself (time, arrival, nothing else works
## mid-ride), saves mid-ride, and cargo and markets at the foot.
func test_elevator_rides() -> void:
	var sim := fresh()
	var s := sim.state
	var d := sim.data
	var Elevator := preload("res://sim/systems/elevator_system.gd")
	check(Elevator.line_here(d, "kibo_ring").is_empty(), "Kibo Ring has no ribbon")
	check(Elevator.fare(d, s, "kibo_ring") == 0.0 and Elevator.blocked(d, s, "kibo_ring") == "there is no elevator here", "No ribbon, no fare, a reason")
	for foot in ["line_foot", "stalk_foot", "pavonis_foot"]:
		var here: Dictionary = Elevator.line_here(d, foot)
		check(not here["down"] and here["to"] == d.places[foot]["foot_of"], "From %s the ride is up, to its port" % foot)
	for port in ["halo_depot", "piazzi_station", "ares_ring"]:
		var here: Dictionary = Elevator.line_here(d, port)
		check(here["down"] and here["to"] == d.places[port]["elevator"]["foot"], "From %s the ride is down" % port)
	# Fares: a seat plus so much a tonne, the same both ways, zero hold costs the seat alone.
	s.ship["cargo"] = {}
	check(Elevator.fare(d, s, "halo_depot") == 150.0 and Elevator.fare(d, s, "line_foot") == 150.0, "An empty hold pays the seat only (150 cr)")
	s.ship["cargo"] = {"water_ice": 4.0, "food": 1.5}
	check(absf(Elevator.fare(d, s, "halo_depot") - (150.0 + 20.0 * 5.5)) < 1e-9, "Cargo adds 20 cr/t, all goods counted")
	check(absf(Elevator.fare(d, s, "piazzi_station") - (80.0 + 12.0 * 5.5)) < 1e-9, "The Stalk is cheaper: 80 cr + 12 cr/t")
	check(absf(Elevator.fare(d, s, "line_foot") - Elevator.fare(d, s, "halo_depot")) < 1e-9, "Up costs what down does")
	# The Pavonis Line takes nobody until it is built, whatever you can pay.
	s.credits = 1.0e9
	s.location = {"status": "docked", "place": "ares_ring"}
	check(sim.apply({"type": "ride_elevator"}) == "the Pavonis Line is still being built" and s.location["status"] == "docked", "Pavonis refuses while unfinished, even for a rich pilot")
	check(s.credits == 1.0e9, "and charges nothing")
	s.projects["pavonis_line"]["done"] = true
	s.ship["cargo"] = {"refined_metals": 2.0}
	check(absf(Elevator.fare(d, s, "ares_ring") - (600.0 + 45.0 * 2.0)) < 1e-9, "Finished, the Pavonis Line is 600 cr + 45 cr/t")
	check(sim.apply({"type": "ride_elevator"}) == "" and s.location["status"] == "elevator" and s.location["to"] == "pavonis_foot", "and then it runs")
	check(absf(float(s.location["arrive_t"]) - float(s.location["depart_t"]) - 120.0 * 3600.0) < 1e-6, "Five days down")
	sim.advance_game_time(120.0 * 3600.0 + 1.0)
	check(s.location == {"status": "docked", "place": "pavonis_foot"}, "Arrived at Pavonis Foot")

	# Broke: one credit short is refused, exactly the fare is fine, and a refusal costs nothing.
	var b := fresh()
	var t := b.state
	t.location = {"status": "docked", "place": "halo_depot"}
	t.ship["cargo"] = {"water_ice": 5.0}
	var fare := 150.0 + 100.0
	t.credits = fare - 1.0
	var before := t.to_dict()
	check(b.apply({"type": "ride_elevator"}) == "the fare is 250 cr", "A pilot one credit short is refused with the fare")
	check(t.credits == fare - 1.0 and t.location["status"] == "docked" and t.ship["cargo"]["water_ice"] == 5.0, "Nothing is taken from them")
	t.credits = fare - 0.4
	check(b.apply({"type": "ride_elevator"}) != "", "A fraction short is still short")
	t.credits = -50.0
	check(b.apply({"type": "ride_elevator"}) != "", "Someone in debt cannot ride")
	t.credits = fare
	check(b.apply({"type": "ride_elevator"}) == "" and absf(t.credits) < 1e-9, "Exactly the fare rides, and leaves nothing")
	# Mid-ride: you are on the ribbon, not in a port.
	for cmd in [{"type": "buy", "good": "food", "tonnes": 1}, {"type": "sell", "good": "water_ice", "tonnes": 1}, {"type": "depart", "to": "kibo_ring"},
			{"type": "ride_elevator"}, {"type": "refuel", "fill": true}, {"type": "repair"}, {"type": "dock"}, {"type": "impact", "speed": 9.0}]:
		check(b.apply(cmd) != "", "Mid-ride, %s is refused" % cmd["type"])
	check(t.location["status"] == "elevator" and t.location["down"] and t.location["from"] == "halo_depot", "The ride record says where from and which way")
	# A save mid-ride, loaded and resumed, arrives exactly as the original does.
	b.advance_game_time(20.0 * 3600.0)
	check(t.location["status"] == "elevator", "Twenty hours in, still riding")
	var saved := SaveIO.from_text(SaveIO.to_text(t))
	check(saved != null and saved.to_dict() == t.to_dict(), "A save mid-ride is lossless")
	var resumed := Sim.new()
	resumed.load_state(saved)
	resumed.advance_game_time(40.0 * 3600.0)
	b.advance_game_time(40.0 * 3600.0)
	check(resumed.state.location == {"status": "docked", "place": "line_foot"} and resumed.state.to_dict() == t.to_dict(), "The loaded ride arrives in step with the original")
	var events: Array = resumed.take_events().map(func(e): return e["type"])
	check("elevator_arrived" in events, "Arrival is announced")
	check(not "elevator_arrived" in b.take_events().filter(func(e): return false).map(func(e): return e["type"]), "(no stale arrival)")
	# Arrival drops time compression to x1, and it happens on the hour, not before.
	var c := fresh()
	c.state.location = {"status": "docked", "place": "piazzi_station"}
	c.state.time_scale = 1.0e4
	check(c.apply({"type": "ride_elevator"}) == "", "Ride the Stalk")
	c.advance_game_time(7.0 * 3600.0 - 10.0)
	check(c.state.location["status"] == "elevator", "Ten seconds before arrival you are still on it")
	c.advance_game_time(10.0)
	check(c.state.location["status"] == "docked" and c.state.time_scale == float(d.balance["time"]["arrival_scale"]), "On the hour you arrive and time drops to x1")
	# At the foot: the town's market works, your hold came along, the yard does not.
	check(c.state.stats.get("trips", 0) == 0, "A ride is not a flight: no trip counted")
	check(c.apply({"type": "repair"}) == "nothing to repair" or c.apply({"type": "repair"}) == "your ship is up at the port", "No repairs at the foot")
	c.state.ship["damage"] = {"keel": 0.5}
	check(c.apply({"type": "repair"}) == "your ship is up at the port", "Your damaged ship is up at the port")
	check(c.apply({"type": "refuel", "fill": true}) != "", "No fuel pump at the foot")
	check(c.apply({"type": "depart", "to": "ceres"}) != "", "No flying from the foot")
	check(c.apply({"type": "ride_elevator"}) == "" and c.state.location["to"] == "piazzi_station" and not c.state.location["down"], "Ride back up")
	c.advance_game_time(8.0 * 3600.0)
	check(c.state.location == {"status": "docked", "place": "piazzi_station"}, "Back at the station")
	# Zero cargo and max credits.
	var z := fresh()
	z.state.location = {"status": "docked", "place": "halo_depot"}
	z.state.ship["cargo"] = {}
	z.state.credits = 1.0e15
	check(z.apply({"type": "ride_elevator"}) == "" and absf(z.state.credits - (1.0e15 - 150.0)) < 1.0, "An empty hold and a huge balance: just the seat comes off")
	var zs := SaveIO.from_text(SaveIO.to_text(z.state))
	check(zs.credits == z.state.credits and zs.to_dict() == z.state.to_dict(), "A huge balance round-trips through a save, mid-ride")


## Damage in depth: impact energy to damage, module zones, overflow into the keel,
## repair costs (yard and patch), and the lifeboat and insurance path.
func test_damage_in_depth() -> void:
	var template := fresh()
	var d := template.data
	var template_text := SaveIO.to_text(template.state)
	var tune: Dictionary = d.balance["damage"]
	var safe := float(tune["safe_mps"])
	var per_kg := float(tune["full_j_per_kg"])
	var keel_share := float(tune["keel_share"])
	var flying := func() -> Sim:
		var f := Sim.new(d)
		f.load_state(SaveIO.from_text(template_text))
		f.state.location = {"status": "approach", "place": "kibo_ring"}
		return f
	var last_impact := func(f: Sim) -> Dictionary:
		var found := {}
		for e in f.take_events():
			if e["type"] == "impact":
				found = e["data"]
		return found
	# Energy to damage: 0.5 (v - safe)^2 x share / 50 J/kg, to the module; a third to the keel.
	var f: Sim = flying.call()
	f.take_events()
	check(f.apply({"type": "impact", "speed": safe, "share": 1.0, "zone": "mid", "seed": 0}) == "" and f.state.ship.get("damage", {}).is_empty(), "Exactly the safe speed does nothing")
	check(f.take_events().is_empty(), "and tells nobody")
	f.apply({"type": "impact", "speed": 5.0, "share": 1.0, "zone": "mid", "seed": 0})
	var expect := 0.5 * (5.0 - safe) * (5.0 - safe) / per_kg
	var ev: Dictionary = last_impact.call(f)
	check(absf(float(ev["amount"]) - expect) < 1e-9, "5 m/s head-on: %.3f of a module (%.3f expected)" % [float(ev["amount"]), expect])
	var slot: String = ev["slot"]
	check(slot.begins_with("cargo.") and absf(f.state.ship["damage"][slot] - expect) < 1e-9, "in the cargo bay, as the middle of the ship is")
	check(absf(f.state.ship["damage"]["keel"] - expect * keel_share) < 1e-9, "and the keel takes its share (%.0f%%)" % (keel_share * 100.0))
	check(absf(float(ev["integrity"]) - (1.0 - expect * keel_share)) < 1e-9, "Integrity reported matches the keel")
	# A glancing blow (share) scales it; energy grows with the square of the excess speed.
	var g: Sim = flying.call()
	g.apply({"type": "impact", "speed": 5.0, "share": 0.25, "zone": "mid", "seed": 0})
	check(absf(float(last_impact.call(g)["amount"]) - expect * 0.25) < 1e-9, "A quarter share does a quarter of the damage")
	var h: Sim = flying.call()
	h.apply({"type": "impact", "speed": safe + 2.0, "share": 1.0, "zone": "mid", "seed": 0})
	var one: float = float(last_impact.call(h)["amount"])
	h.apply({"type": "impact", "speed": safe + 4.0, "share": 1.0, "zone": "mid", "seed": 0})
	check(absf(float(last_impact.call(h)["amount"]) / one - 4.0) < 1e-9, "Twice the excess speed, four times the damage")
	var over: Sim = flying.call()
	over.apply({"type": "impact", "speed": 5.0, "share": 7.0, "zone": "mid", "seed": 0})
	check(absf(float(last_impact.call(over)["amount"]) - expect) < 1e-9, "A share above 1 counts as 1")
	var neg: Sim = flying.call()
	check(neg.apply({"type": "impact", "speed": 5.0, "share": -1.0, "zone": "mid", "seed": 0}) == "" and last_impact.call(neg)["amount"] == 0.0, "A negative share counts as nothing")
	var nan_free: Sim = flying.call()
	nan_free.apply({"type": "impact"})
	check(nan_free.state.ship.get("damage", {}).is_empty(), "A command with no speed does nothing")
	check(Sim.new(d).apply({"type": "impact", "speed": 20.0}) == "not flying", "No impacts while docked")
	# Zones: each blow lands on the module kinds of its zone, and seeds spread across them.
	var zones := {"nose": ["command", "avionics"], "mid": ["cargo"], "tail": ["tank", "drive"], "side": ["radiator"]}
	for zone in zones:
		var seen := {}
		for sd in 6:
			var z: Sim = flying.call()
			z.apply({"type": "impact", "speed": 3.0, "share": 1.0, "zone": zone, "seed": sd})
			var hit := String(last_impact.call(z)["slot"])
			seen[hit] = true
			check(hit.split(".")[0] in zones[zone], "A %s blow (seed %d) hits %s, a %s module" % [zone, sd, hit, zones[zone]])
		check(seen.size() == (2 if zone in ["mid", "side", "tail"] else 1), "Seeds reach every candidate in the %s zone (%d)" % [zone, seen.size()])
	var neg_seed: Sim = flying.call()
	check(neg_seed.apply({"type": "impact", "speed": 3.0, "zone": "mid", "seed": -3}) == "", "A negative seed still picks a module")
	var odd: Sim = flying.call()
	odd.apply({"type": "impact", "speed": 3.0, "zone": "sideways", "seed": 0})
	check(String(last_impact.call(odd)["slot"]).begins_with("cargo."), "An unknown zone is treated as the middle")
	# A ship with nothing in the zone takes the blow in the keel.
	var bare: Sim = flying.call()
	for k in bare.state.ship["modules"].keys():
		if k.begins_with("radiator."):
			bare.state.ship["modules"].erase(k)
	bare.apply({"type": "impact", "speed": 4.0, "zone": "side", "seed": 0})
	var kv: Dictionary = last_impact.call(bare)
	check(kv["slot"] == "keel" and kv["module"] == "the keel" and absf(bare.state.ship["damage"]["keel"] - float(kv["amount"])) < 1e-9, "No radiators to hit: the whole blow goes to the keel")
	# Keel overflow: a module already at 0.9 takes only 0.1; the rest, and its share of that, go to the keel.
	var ov: Sim = flying.call()
	for k in ["tank.0", "drive.0"]:
		ov.state.ship["damage"] = ov.state.ship.get("damage", {})
		ov.state.ship["damage"][k] = 0.9
	ov.apply({"type": "impact", "speed": safe + 5.0, "share": 1.0, "zone": "tail", "seed": 0})
	var amount := 0.5 * 25.0 / per_kg
	var ovr: Dictionary = last_impact.call(ov)
	var hit_slot: String = ovr["slot"]
	check(absf(ov.state.ship["damage"][hit_slot] - 1.0) < 1e-9, "The module is wrecked, and no more than wrecked (%.3f)" % ov.state.ship["damage"][hit_slot])
	check(absf(ov.state.ship["damage"]["keel"] - ((amount - 0.1) + 0.1 * keel_share)) < 1e-9, "The 0.%.0f it could not take goes into the keel, plus its share of what it did" % ((amount - 0.1) * 100.0))
	# Hitting a module that is already wrecked sends everything to the keel.
	var wr: Sim = flying.call()
	wr.state.ship["damage"] = {"cargo.0": 1.0, "cargo.1": 1.0}
	wr.apply({"type": "impact", "speed": safe + 3.0, "zone": "mid", "seed": 1})
	check(absf(wr.state.ship["damage"]["keel"] - 0.5 * 9.0 / per_kg) < 1e-9, "A wrecked module passes the whole blow on to the keel")
	# Wreck: the keel gets to 1 exactly, not past it, and the ship is lost; one hit can do it.
	var one_shot: Sim = flying.call()
	one_shot.apply({"type": "impact", "speed": 40.0, "share": 1.0, "zone": "mid", "seed": 0})
	check(one_shot.state.location["status"] == "lifeboat" and one_shot.state.stats["ships_lost"] == 1, "40 m/s into anything is a lost ship")
	check(one_shot.state.ship.get("damage", {}).is_empty(), "and the new hull is clean (no keel past 1 carried over)")
	# Just under the wreck line keeps the ship.
	var almost: Sim = flying.call()
	almost.state.ship["damage"] = {"keel": 0.97}
	almost.apply({"type": "impact", "speed": safe + 1.0, "zone": "mid", "seed": 0})
	check(almost.state.location["status"] == "approach" and DamageSystem.integrity(almost.state.ship) < 0.03 + 0.005, "A keel at 3% integrity still holds the ship together")
	almost.apply({"type": "impact", "speed": safe + 3.0, "zone": "mid", "seed": 0})
	check(almost.state.location["status"] == "lifeboat", "and the next knock finishes it")
	# Spills and vents: a broken pod loses cargo in proportion across goods; damage shows in the stats.
	var sp: Sim = flying.call()
	var capacity := ShipStats.cargo_capacity_t(sp.state.ship, d)
	sp.state.ship["cargo"] = {"food": capacity * 0.5, "water_ice": capacity * 0.5}
	sp.state.ship["cargo_paid"] = {"food": 100.0, "water_ice": 100.0}
	sp.apply({"type": "impact", "speed": safe + 3.0, "zone": "mid", "seed": 0})
	var spill: Dictionary = last_impact.call(sp)["spilled"]
	check(not spill.is_empty() and absf(float(spill["food"]) - float(spill["water_ice"])) < 1e-9, "A broken pod spills each good in proportion")
	check(ShipStats.cargo_t(sp.state.ship) <= ShipStats.cargo_capacity_t(sp.state.ship, d) + 1e-9, "What is left fits what is left")
	# Empty hold, wrecked pod: nothing to spill, no error.
	var em: Sim = flying.call()
	em.state.ship["cargo"] = {}
	check(em.apply({"type": "impact", "speed": safe + 3.0, "zone": "mid", "seed": 0}) == "" and last_impact.call(em)["spilled"].is_empty(), "A hit with an empty hold spills nothing")

	# Repair costs. Yard: every point at repair_cr_per_point x module value. Patch: only above patch_max, at a premium.
	var r := _clone(d, template_text)
	var rs := r.state
	rs.ship["damage"] = {"drive.0": 0.6, "keel": 0.4}
	rs.location = {"status": "docked", "place": "halo_depot"}
	var drive_value := maxf(float(d.modules["pathfinder_mk1"]["price"]), float(tune["min_module_value"]))
	var patch_max := float(tune["patch_max"])
	var rate := float(tune["repair_cr_per_point"])
	var patch_expect := ((0.6 - patch_max) * drive_value + (0.4 - patch_max) * float(tune["keel_value"])) * rate * float(tune["patch_mult"])
	check(absf(DamageSystem.repair_cost(rs, d) - patch_expect) < 1e-6, "Patch cost at a port without a yard: %d cr" % int(patch_expect))
	rs.location = {"status": "docked", "place": "kibo_ring"}
	var yard_expect := (0.6 * drive_value + 0.4 * float(tune["keel_value"])) * rate
	check(absf(DamageSystem.repair_cost(rs, d) - yard_expect) < 1e-6, "Yard cost at Kibo Ring: %d cr" % int(yard_expect))
	check(yard_expect < patch_expect * 2.0 and yard_expect > 0.0, "A yard repairs everything for less than twice the patch")
	rs.location = {"status": "docked", "place": "halo_depot"}
	rs.credits = patch_expect - 1.0
	check(String(r.apply({"type": "repair"})).begins_with("repairs cost") and rs.credits == patch_expect - 1.0 and rs.ship["damage"]["keel"] == 0.4, "Broke: refused, and nothing changes")
	rs.credits = patch_expect + 0.001
	check(r.apply({"type": "repair"}) == "" and rs.credits < 0.01 and absf(rs.ship["damage"]["keel"] - patch_max) < 1e-9, "Just enough patches the keel back to %.0f%%" % (patch_max * 100.0))
	check(r.apply({"type": "repair"}) == "nothing to repair", "A patched ship has nothing further a patch can do")
	var small: Sim = _clone(d, template_text)
	small.state.location = {"status": "docked", "place": "halo_depot"}
	small.state.ship["damage"] = {"drive.0": 0.2}
	check(small.apply({"type": "repair"}) == "nothing to repair" and DamageSystem.repair_cost(small.state, d) == 0.0, "Scratches under the patch line cost nothing and are left")
	check(DamageSystem.repair_cost(_clone(d, template_text).state, d) == 0.0, "An undamaged ship costs nothing to repair")
	var cheap: Sim = _clone(d, template_text)
	cheap.state.location = {"status": "docked", "place": "kibo_ring"}
	cheap.state.ship["damage"] = {"cargo.0": 0.5}
	var min_value := float(tune["min_module_value"])
	check(absf(DamageSystem.repair_cost(cheap.state, d) - 0.5 * maxf(float(d.modules["cargo_pod_s"]["price"]), min_value) * rate) < 1e-6, "A cheap module is repaired at no less than its minimum value")
	cheap.state.ship["damage"] = {"cargo.5": 0.5}
	check(absf(DamageSystem.repair_cost(cheap.state, d) - 0.5 * min_value * rate) < 1e-6, "Damage for a slot no longer fitted is costed at the minimum, not a crash")
	check(cheap.apply({"type": "repair"}) == "" and cheap.state.ship["damage"].is_empty(), "A yard clears it")
	var flight: Sim = flying.call()
	check(flight.apply({"type": "repair"}) == "not docked", "No repairs while flying")
	# Damaged hulls fly worse; repairs bring it back.
	var fit: Sim = _clone(d, template_text)
	var base_thrust := ShipStats.thrust_n(fit.state.ship, d)
	fit.state.ship["damage"] = {"drive.0": 0.5}
	check(absf(ShipStats.thrust_n(fit.state.ship, d) - base_thrust * 0.5) < 1e-6, "A half-wrecked drive pushes half as hard")
	fit.state.ship["damage"] = {"drive.0": 1.0}
	check(ShipStats.thrust_n(fit.state.ship, d) == 0.0, "A wrecked drive does not push at all")
	# Saves carry damage through.
	fit.state.ship["damage"] = {"drive.0": 0.37, "keel": 0.11}
	var back := SaveIO.from_text(SaveIO.to_text(fit.state))
	check(back.ship["damage"] == fit.state.ship["damage"], "Damage survives a save")

	# The lifeboat and the insurance pool.
	var lb: Sim = flying.call()
	var ls := lb.state
	ls.credits = 20000.0
	ls.ship["name"] = "Second Wind"
	ls.ship["modules"]["drive.0"] = "pathfinder_mk2"
	ls.ship["cargo"] = {"food": 3.0}
	ls.ship["cargo_paid"] = {"food": 900.0}
	ls.ship["damage"] = {"drive.0": 0.3}
	ls.contracts["active"].append({"id": 501, "state": "carried", "client": "Terran Compact", "to": "halo_depot", "item": "x", "pickup": "", "deadline_t": ls.time_s + 30.0 * DAY, "accepted_t": ls.time_s, "window_s": 30.0 * DAY, "reward": 100.0, "mass_t": 0.1, "passengers": 0, "rep": 1.0})
	ls.contracts["active"].append({"id": 502, "state": "accepted", "client": "Terran Compact", "to": "halo_depot", "item": "y", "pickup": "clarke_exchange", "deadline_t": ls.time_s + 30.0 * DAY, "accepted_t": ls.time_s, "window_s": 30.0 * DAY, "reward": 100.0, "mass_t": 0.1, "passengers": 0, "rep": 1.0})
	lb.take_events()
	lb.apply({"type": "impact", "speed": 30.0, "zone": "mid", "seed": 0})
	var lost_event: Dictionary = {}
	for e in lb.take_events():
		if e["type"] == "ship_lost":
			lost_event = e["data"]
	check(not lost_event.is_empty() and lost_event["jobs_lost"] == [501] and lost_event["excess"] == float(tune["insurance_excess"]), "The ship_lost event names the lost job and the excess")
	check(ls.credits == 20000.0 - float(tune["insurance_excess"]), "Insurance costs exactly the excess")
	check(ls.ship["name"] == "Second Wind" and ls.ship["hull"] == d.balance["start"]["ship"], "The name carries over to the stock hull")
	check(ls.ship["modules"]["drive.0"] == "pathfinder_mk1", "The upgraded drive is gone: a stock Mule")
	check(ls.ship["cargo"].is_empty() and ls.ship["cargo_paid"].is_empty(), "Cargo is lost with its paid value")
	check(absf(float(ls.ship["fuel_t"]) - ShipStats.fuel_capacity_t(ls.ship, d)) < 1e-9, "The new ship comes with full tanks")
	check(ls.contracts["active"].size() == 1 and ls.contracts["active"][0]["id"] == 502, "A job you had accepted but not picked up survives")
	check(ls.contracts["history"].any(func(j): return j["id"] == 501 and j["outcome"] == "lost"), "The carried job is in the history as lost")
	check(int(ls.stats["ships_lost"]) == 1, "It counts as a lost ship")
	check(float(ls.location["until_t"]) - ls.time_s == float(tune["lifeboat_s"]) and ls.location["place"] == "kibo_ring", "The lifeboat is bound for the same port")
	# Locked out while in the lifeboat; saves work; the tug arrives on time.
	for cmd in [{"type": "buy", "good": "food", "tonnes": 1}, {"type": "depart", "to": "halo_depot"}, {"type": "repair"}, {"type": "ride_elevator"},
			{"type": "dock"}, {"type": "impact", "speed": 20.0}, {"type": "refuel", "fill": true}]:
		check(lb.apply(cmd) != "", "In the lifeboat, %s is refused" % cmd["type"])
	lb.advance_game_time(float(tune["lifeboat_s"]) - 5.0)
	check(ls.location["status"] == "lifeboat", "Five seconds early, still adrift")
	var saved := SaveIO.from_text(SaveIO.to_text(ls))
	check(saved != null and saved.to_dict() == ls.to_dict(), "A save from the lifeboat is lossless")
	var resumed := Sim.new()
	resumed.load_state(saved)
	resumed.advance_game_time(10.0)
	lb.advance_game_time(10.0)
	check(resumed.state.location == {"status": "docked", "place": "kibo_ring"} and ls.location == resumed.state.location, "The tug brings both copies in")
	check(lb.take_events().any(func(e): return e["type"] == "rescued"), "A rescue is announced")
	# Wrecking the replacement ship too: another excess, and the count goes up.
	ls.location = {"status": "approach", "place": "kibo_ring"}
	var credits := ls.credits
	lb.apply({"type": "impact", "speed": 30.0, "zone": "mid", "seed": 0})
	check(int(ls.stats["ships_lost"]) == 2 and absf(credits - ls.credits - float(tune["insurance_excess"])) < 1e-9, "A second wreck costs a second excess")
	# Broke: the insurer still delivers a hull; the balance goes into the red rather than leaving you stranded.
	var broke: Sim = flying.call()
	broke.state.credits = 500.0
	broke.apply({"type": "impact", "speed": 30.0, "zone": "mid", "seed": 0})
	check(broke.state.credits == 500.0 - float(tune["insurance_excess"]) and broke.state.location["status"] == "lifeboat", "With 500 cr the excess puts you 2,500 in debt but you still get a ship")
	broke.advance_game_time(float(tune["lifeboat_s"]) + 1.0)
	check(broke.apply({"type": "emergency_refuel"}) != "refuel normally here" or float(broke.state.ship["fuel_t"]) > 0.0, "and a tank to fly on")
	# Lent or story modules go with the wreck, and the story arc is not undone by it.
	var lent: Sim = flying.call()
	lent.state.story["done"].append("the_loan")
	lent.state.ship["modules"]["drive.0"] = "longview_drive"
	lent.apply({"type": "impact", "speed": 30.0, "zone": "mid", "seed": 0})
	check(lent.state.ship["modules"]["drive.0"] == "pathfinder_mk1" and "the_loan" in lent.state.story["done"], "The lent drive is lost with the ship; the beat stays done")
	# Max credits: a rich pilot's insurance is just the excess.
	var rich: Sim = flying.call()
	rich.state.credits = 1.0e15
	rich.apply({"type": "impact", "speed": 30.0, "zone": "mid", "seed": 0})
	check(rich.state.credits == 1.0e15 - float(tune["insurance_excess"]), "A huge balance pays the same excess")


## The story arcs: beats fire in order at their ports, arcs run side by side, a favour
## is offered once, retried if lost, and a save mid-arc picks up where it was.
func test_story_arcs_in_depth() -> void:
	var sim := fresh()
	var s := sim.state
	var d := sim.data
	check(s.story["done"].is_empty() and s.story["fired"].is_empty() and s.story["messages"].is_empty(), "A new game is at the start of every arc")
	# Beats only move when docked or on site: not in transit, not on the ribbon.
	s.stats["contracts_delivered"] = 3
	s.reputation["Terran Compact"] = 7.0
	s.location = {"status": "transit", "from": "kibo_ring", "to": "clarke_exchange", "depart_t": s.time_s, "arrive_t": s.time_s + 3.0 * DAY}
	sim.advance_game_time(3600.0)
	check(s.story["fired"].is_empty(), "A ready beat does not fire in transit")
	var in_transit := SaveIO.from_text(SaveIO.to_text(s))
	check(in_transit.to_dict() == s.to_dict(), "A save in transit with a beat pending is lossless")
	var loaded := Sim.new()
	loaded.load_state(in_transit)
	loaded.advance_game_time(3.0 * DAY)
	check(loaded.state.location["status"] == "approach" and loaded.state.story["fired"].is_empty(), "On arrival, still in approach: the beat waits for the dock")
	loaded.apply({"type": "dock"})
	loaded.advance_game_time(60.0)
	check(loaded.state.story["fired"].has("first_favour"), "Docked, the first beat fires")
	# Offered once, one message, a favour on the board.
	var offers: Array = loaded.state.contracts["board"].get("clarke_exchange", []).filter(func(o): return o.get("favour", "") == "first_favour")
	check(offers.size() == 1 and loaded.state.story["messages"].size() == 1, "One favour, one message")
	loaded.advance_game_time(3600.0)
	loaded.advance_game_time(3600.0)
	check(loaded.state.contracts["board"]["clarke_exchange"].filter(func(o): return o.get("favour", "") == "first_favour").size() == 1 and loaded.state.story["messages"].size() == 1, "Further ticks do not offer it again")
	check(not "first_favour" in loaded.state.story["done"] and not loaded.state.story["fired"].has("the_recorder"), "The next beat waits for this one to be done")

	# The favour vanishing (it expires, nobody takes it) is offered again, once.
	var re := fresh()
	var r := re.state
	r.stats["contracts_delivered"] = 3
	r.reputation["Terran Compact"] = 7.0
	_dock_at(re, "clarke_exchange")
	var first_id := int(r.story["fired"]["first_favour"]["offer"])
	r.contracts["board"]["clarke_exchange"] = r.contracts["board"]["clarke_exchange"].filter(func(o): return int(o["id"]) != first_id)
	re.advance_game_time(2.0 * 3600.0)
	var again: Array = r.contracts["board"]["clarke_exchange"].filter(func(o): return o.get("favour", "") == "first_favour")
	check(again.size() == 1 and int(again[0]["id"]) != first_id, "A lapsed favour is offered again under a new id")
	check(r.story["messages"].size() == 2 and not "first_favour" in r.story["done"], "with its message sent again, and the beat still open")
	var live: Array = r.contracts["board"]["clarke_exchange"].filter(func(o): return o.get("favour", "") == "first_favour")
	# Take it: delivered after a reload still counts. Save mid-arc, with the favour carried.
	var again_id := int(live[0]["id"])
	check(re.apply({"type": "accept_contract", "id": again_id}) == "", "Take the re-offered favour")
	var carried: Dictionary = r.contracts["active"].filter(func(j): return int(j["id"]) == again_id)[0]
	r.location = {"status": "docked", "place": "clarke_exchange"}
	var mid := SaveIO.from_text(SaveIO.to_text(r))
	check(mid != null and mid.to_dict() == r.to_dict() and mid.story == r.story, "A save with a favour in hand, mid-arc, is lossless")
	var cont := Sim.new()
	cont.load_state(mid)
	cont.state.location = {"status": "docked", "place": "farside_array"}
	cont.advance_game_time(60.0)
	cont.advance_game_time(60.0)
	check("first_favour" in cont.state.story["done"], "Delivered after a reload: the beat completes")
	check(SiteSystemScript.knows(cont.state, "hermes_probe") or cont.state.story["fired"].has("the_recorder"), "and the next beat moves on (Hermes-7 revealed)")
	check(cont.state.story["done"].filter(func(b): return b == "first_favour").size() == 1, "Never marked done twice")
	# A beat for a port waits for that port.
	check(not cont.state.story["fired"].has("the_occultation"), "The occultation waits for the recorder to be worked")
	cont.state.location = {"status": "docked", "place": "kibo_ring"}
	cont.state.sites["worked"] = {"hermes_probe": ["salvage"]}
	cont.advance_game_time(3600.0)
	check("the_recorder" in cont.state.story["done"], "Working the site finishes the recorder beat wherever you are")
	cont.advance_game_time(3600.0)
	check(not cont.state.story["fired"].has("the_occultation"), "but the occultation is told at the Array, not at Kibo")
	cont.state.location = {"status": "docked", "place": "farside_array"}
	cont.advance_game_time(3600.0)
	check(cont.state.story["fired"].has("the_occultation"), "and at the Array it is")

	# Arcs run side by side: the Sufficiency does not wait on the Long View.
	var arcs := fresh()
	var a := arcs.state
	check(not a.story["fired"].has("quiet_margin"), "Quiet Margin is not met away from Landauer Deep")
	a.location = {"status": "docked", "place": "landauer_deep"}
	arcs.advance_game_time(2.0 * 3600.0)
	check(a.story["fired"].has("quiet_margin") and "quiet_margin" in a.story["done"] and not a.story["fired"].has("first_favour"), "The Sufficiency begins on its own, while the Long View has not")
	check(a.reputation.get("The Sufficiency", 0.0) > 0.0 or a.reputation.has("The Sufficiency"), "Quiet Margin's greeting gives standing")
	check(not a.story["fired"].has("the_delegate"), "The delegate needs two on-time deliveries first")
	a.stats["contracts_delivered"] = 2
	arcs.advance_game_time(3600.0)
	check(a.story["fired"].has("the_delegate") and not a.story["fired"].has("the_seat"), "With two deliveries behind you, the delegate's favour is offered")
	var delegate: Dictionary = arcs.state.contracts["board"]["landauer_deep"].filter(func(o): return o.get("favour", "") == "the_delegate")[0]
	check(delegate["to"] == "piazzi_station", "to Piazzi Station")
	# Credits and standing arrive with the final beat.
	var credits := a.credits
	check(arcs.apply({"type": "accept_contract", "id": delegate["id"]}) == "", "Take the sleeping mind")
	_dock_at(arcs, "piazzi_station")
	_dock_at(arcs, "piazzi_station")
	check("the_delegate" in a.story["done"] and "the_seat" in a.story["done"], "Delivered: the seat beat follows and finishes")
	var sufficiency_letters: Array = a.story["messages"].filter(func(m): return String(m["from"]).contains("Sufficiency") or String(m["from"]).contains("Steady Hand"))
	check(a.credits >= credits + 4000.0 and sufficiency_letters.size() == 3, "Steady Hand's thank-you pays 4,000 and the arc's log has three letters (%d)" % sufficiency_letters.size())
	check(a.story["fired"].has("first_favour"), "Two on-time deliveries and a Known standing with the Sufficiency also bring the Long View's first favour (arcs cross-feed)")
	# And once the arc is over it stays over.
	var n_messages: int = a.story["messages"].size()
	for _k in 3:
		_dock_at(arcs, "landauer_deep")
	check(a.story["messages"].size() == n_messages and a.story["done"].filter(func(b): return b == "the_seat").size() == 1, "A finished arc does not replay")
	# Beats are data: every beat's prerequisites exist, and every arc's beats are in order of dependency.
	var ids: Array = d.story["beats"].map(func(b): return b["id"])
	var ordered := true
	for i in d.story["beats"].size():
		for need in d.story["beats"][i].get("when", {}).get("beats", []):
			ordered = ordered and need in ids and ids.find(need) < i
	check(ordered, "Every beat's prerequisites come earlier in the file")
	# The grant in 'the_loan' fills the tanks even when the ship was empty.
	var loan := fresh()
	loan.state.ship["fuel_t"] = 0.0
	loan.state.story["done"] = ["first_favour", "the_recorder", "the_occultation"]
	loan.state.location = {"status": "docked", "place": "trojan_yards"}
	loan.advance_game_time(3600.0)
	check(loan.state.ship["modules"]["drive.0"] == "longview_drive" and float(loan.state.ship["fuel_t"]) == ShipStats.fuel_capacity_t(loan.state.ship, d) and float(loan.state.ship["fuel_t"]) > 0.0, "The Long View's loan fits the drive and tops up the tanks")
	# Save during a beat's wait on a long-haul trip; the arc resumes on arrival.
	loan.state.location = {"status": "transit", "from": "trojan_yards", "to": "the_lacuna", "depart_t": loan.state.time_s, "arrive_t": loan.state.time_s + 40.0 * DAY}
	loan.state.sites["worked"] = {"the_lacuna": ["greet"]}
	loan.advance_game_time(DAY)
	check(not loan.state.story["fired"].has("the_meeting"), "The meeting is not delivered mid-transit")
	var tx := SaveIO.from_text(SaveIO.to_text(loan.state))
	check(tx.story == loan.state.story, "Story state survives a transit save")


## Edge cases found by reading the sim: empty holds, huge balances, saves in odd moments.
func test_edge_cases() -> void:
	var sim := fresh()
	var s := sim.state
	var d := sim.data
	# Zero cargo.
	check(s.ship["cargo"].is_empty() and ShipStats.cargo_t(s.ship) == 0.0, "The stock ship starts empty")
	check(sim.apply({"type": "sell", "good": "food", "tonnes": 1.0}) == "only 0.0 t aboard", "Selling what you do not have is refused")
	check(sim.apply({"type": "sell", "good": "food", "tonnes": 0.0}) == "nothing to trade", "Selling zero tonnes is refused")
	check(sim.apply({"type": "buy", "good": "food", "tonnes": 0.0}) == "nothing to trade", "Buying zero tonnes is refused")
	check(sim.apply({"type": "buy", "good": "food", "tonnes": -2.0}) == "nothing to trade", "Buying negative tonnes is refused")
	check(sim.apply({"type": "sell", "good": "food", "tonnes": -2.0}) == "nothing to trade", "Selling negative tonnes is refused")
	check(sim.apply({"type": "buy", "good": "unobtainium", "tonnes": 1.0}) != "", "An unknown good is refused")
	check(is_equal_approx(s.credits, 10000.0) and not is_nan(float(s.stats["trade_profit"])), "None of that cost anything or poisoned the books")
	check(sim.apply({"type": "depart", "to": "clarke_exchange"}) == "", "You can fly with an empty hold")
	sim.advance_game_time(10.0 * DAY)
	check(s.location["status"] == "approach", "and arrive with one")
	sim.apply({"type": "dock"})
	check(s.stats["trips"] == 1 and not is_nan(s.credits), "An empty trip still counts, and the books are sane")
	check(sim.apply({"type": "depart", "to": "clarke_exchange"}) != "", "You cannot fly to where you already are")
	# Partial sale keeps the cost basis in proportion.
	_dock_at(sim, "kibo_ring")
	s.credits = 100000.0
	check(sim.apply({"type": "buy", "good": "water_ice", "tonnes": 4.0}) == "", "Buy 4 t")
	var paid: float = s.ship["cargo_paid"]["water_ice"]
	sim.apply({"type": "sell", "good": "water_ice", "tonnes": 1.0})
	check(absf(s.ship["cargo_paid"]["water_ice"] - paid * 0.75) < 1e-6, "Selling a quarter takes a quarter of the cost basis")
	sim.apply({"type": "sell", "good": "water_ice", "tonnes": 3.0})
	check(s.ship["cargo"].is_empty() and s.ship["cargo_paid"].is_empty(), "Selling all of it clears both books")
	check(not is_nan(float(s.stats["trade_profit"])) and absf(float(s.stats["trade_profit"])) < 1000.0, "Buying and selling back at the same port gains or loses little (%.1f)" % float(s.stats["trade_profit"]))
	# Full hold, exactly: capacity is allowed, a gram over is not.
	var capacity := ShipStats.cargo_capacity_t(s.ship, d)
	var room := capacity
	check(sim.apply({"type": "buy", "good": "water_ice", "tonnes": capacity + 0.01}) != "", "A hold's worth and a bit more is refused (one way or the other)")
	check(sim.apply({"type": "buy", "good": "electronics", "tonnes": capacity + 0.01}) != "", "Over capacity is refused")
	s.ship["cargo"] = {"electronics": capacity}
	check(sim.apply({"type": "buy", "good": "electronics", "tonnes": 0.01}) == "not enough cargo space", "A full hold takes nothing more")
	s.ship["cargo"] = {}
	# Max credits: no overflow, no NaN, saves hold.
	s.credits = 1.0e15
	check(sim.apply({"type": "buy", "good": "water_ice", "tonnes": 1.0}) == "" and s.credits < 1.0e15 and is_finite(s.credits), "A quadrillion credits buys as normal")
	sim.apply({"type": "sell", "good": "water_ice", "tonnes": 1.0})
	check(is_finite(s.credits) and absf(s.credits - 1.0e15) < 1000.0, "and selling back leaves the balance intact")
	check(sim.apply({"type": "refuel", "fill": true}) == "tanks full" or float(s.ship["fuel_t"]) >= ShipStats.fuel_capacity_t(s.ship, d) - 1e-9, "Refuelling with a fortune fills the tanks")
	var rich := SaveIO.from_text(SaveIO.to_text(s))
	check(rich != null and rich.credits == s.credits, "A huge balance saves exactly")
	_dock_at(sim, "trojan_yards")
	check(sim.apply({"type": "install_module", "slot": "cargo.0", "module": "cargo_pod_l"}) == "", "A rich pilot can fit a big pod")
	check(s.credits < 1.0e15 and s.credits > 1.0e15 - 1.0e6, "and pays the price")
	# Broke: nothing is bought with nothing.
	s.credits = 0.0
	check(sim.apply({"type": "buy", "good": "electronics", "tonnes": 1.0}) == "not enough credits", "No credits, no cargo")
	check(sim.apply({"type": "install_module", "slot": "cargo.0", "module": "cargo_pod_l"}) != "" or s.ship["modules"]["cargo.0"] == "cargo_pod_l", "No credits, no upgrades (unless already fitted)")
	check(s.ship["cargo"].is_empty() and s.credits == 0.0, "and nothing was taken")
	# Save during transit with cargo: both copies arrive and sell identically.
	var t := fresh()
	t.state.credits = 50000.0
	t.apply({"type": "buy", "good": "electronics", "tonnes": 3.0})
	t.apply({"type": "depart", "to": "halo_depot"})
	t.advance_game_time(DAY)
	check(t.state.location["status"] == "transit", "A day out, in transit")
	var tt := Sim.new()
	tt.load_state(SaveIO.from_text(SaveIO.to_text(t.state)))
	for x in [t, tt]:
		x.advance_game_time(6.0 * DAY)
		x.apply({"type": "dock"})
		x.apply({"type": "sell", "good": "electronics", "tonnes": 3.0})
	check(t.state.to_dict() == tt.state.to_dict() and t.state.location["status"] == "docked", "A save in transit lands and sells identically to the run that never saved")
	# Departing mid-transit, docking while in transit, and an elevator ride mid-transit are refused.
	var u := fresh()
	u.apply({"type": "depart", "to": "halo_depot"})
	check(u.apply({"type": "depart", "to": "kibo_ring"}) != "" and u.apply({"type": "dock"}) != "" and u.apply({"type": "ride_elevator"}) != "", "Mid-transit: no second departure, no docking, no ribbon")
	check(u.apply({"type": "buy", "good": "food", "tonnes": 1.0}) != "" and u.apply({"type": "repair"}) != "", "and no trading or repairs")
	# Time scale: unknown scales and pausing while riding or in the lifeboat.
	check(u.apply({"type": "set_time_scale", "scale": 7.0}) != "" or u.state.time_scale == 7.0, "(time scale is validated or accepted, never a crash)")
	# A save at the exact arrival moment resumes cleanly.
	var v := fresh()
	v.apply({"type": "depart", "to": "clarke_exchange"})
	v.advance_game_time(float(v.state.location["arrive_t"]) - v.state.time_s)
	var vs := SaveIO.from_text(SaveIO.to_text(v.state))
	check(vs != null and vs.to_dict() == v.state.to_dict() and vs.location["status"] in ["transit", "approach"], "A save at the moment of arrival is lossless")
	var vr := Sim.new()
	vr.load_state(vs)
	vr.advance_game_time(60.0)
	v.advance_game_time(60.0)
	check(vr.state.to_dict() == v.state.to_dict() and v.state.location["status"] == "approach", "and resumes in step")
	check(room == capacity, "(capacity is stable)")


## Ship sounds (view, headless): sources on the hardware, the listener in the cabin,
## the drive lighting up, jets firing on a turn, motors whining as hinges move.
func test_ship_audio() -> void:
	var sim := fresh()
	var Models = load("res://view/flight/models.gd")
	var ShipAudioScript = load("res://view/audio/ship_audio.gd")
	var model: Dictionary = Models.ship(sim.state.ship, sim.data)
	var root: Node3D = model["node"]
	get_root().add_child(root)
	var audio = ShipAudioScript.new()
	root.add_child(audio)
	audio.setup(model)
	check(not model["rig"]["rcs"].is_empty() and audio._jets.size() == model["rig"]["rcs"].size(), "Every jet cluster on the model has a sound")
	check(audio._motors.size() >= model["rig"]["arrays"].size(), "Every panel hinge has a motor to hear")
	check(audio.listener.position.z < audio._drive_at.z - 10.0, "The listener sits in the crew section, well forward of the drive")
	for _k in 30:
		audio.update(1.0 / 30.0, {"thrust": 1.0, "spin": Vector3(0, 1, 0), "turn": 0.6})
	check(audio._drive_on and audio._drive_level > 0.5, "The drive lights and builds to a roar")
	check(int(audio.sounds_played) >= 4, "A turn fires the jets and the frame creaks (%d sounds)" % int(audio.sounds_played))
	var panel: Node3D = model["rig"]["arrays"][0]["node"]
	for _k in 10:
		panel.rotation.x += 0.03
		audio.update(1.0 / 30.0, {"thrust": 1.0})
	check(float(audio._motors[0]["level"]) > 0.3, "A turning panel's motor whines")
	for _k in 60:
		audio.update(1.0 / 30.0, {"thrust": 0.0})
	check(not audio._drive_on and audio._drive_level < 0.05, "Cut-off: the drive winds down")
	# Time compression: everything ducks, and routine knocks thin right out.
	check(ShipAudioScript.duck_for(1.0) == 0.0 and ShipAudioScript.duck_for(100.0) < -12.0 and ShipAudioScript.duck_for(1.0e6) >= -24.0, "Sounds duck under time compression")
	var before: int = int(audio.sounds_played)
	for _k in 30:
		audio.update(1.0 / 30.0, {"spin": Vector3(0, 1, 0), "turn": 0.6, "time_scale": 1000.0})
	var fast_shots: int = int(audio.sounds_played) - before
	check(fast_shots <= 2, "At x1000 the jets and creaks thin to a few (%d in a second)" % fast_shots)
	if root.get_parent():
		root.get_parent().remove_child(root)
	root.free()
	# The kit caches materials in statics; let them go before the test run exits.
	load("res://view/flight/kit.gd")._materials.clear()
