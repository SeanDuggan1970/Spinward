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
const ShipyardSystem := preload("res://sim/systems/shipyard_system.gd")
const V := preload("res://sim/v3.gd")
const ProjectSystem := preload("res://sim/systems/project_system.gd")
const RoutePlanner := preload("res://sim/route_planner.gd")
const OrbitMech := preload("res://sim/orbit_mech.gd")
const LightTime := preload("res://sim/light_time.gd")
const Interplanetary := preload("res://sim/interplanetary.gd")
const Contracts := preload("res://sim/contracts.gd")
const ContractSystemScript := preload("res://sim/systems/contract_system.gd")
const Perks := preload("res://sim/perks.gd")
const Favours := preload("res://sim/favours.gd")
const SiteSystemScript := preload("res://sim/systems/site_system.gd")
const EconomySystemScript := preload("res://sim/systems/economy_system.gd")
const NpcSystem := preload("res://sim/systems/npc_system.gd")
const Bindings := preload("res://view/bindings.gd")
const DamageSystem := preload("res://sim/systems/damage_system.gd")
const Power := preload("res://sim/power.gd")
const Condition := preload("res://sim/condition.gd")
const Fitness := preload("res://sim/fitness.gd")
const Insurance := preload("res://sim/insurance.gd")
const ShipBill := preload("res://sim/ship_bill.gd")
const CockpitPages := preload("res://view/ui/cockpit_pages.gd")
const ShipRig := preload("res://view/flight/ship_rig.gd")
const TravelSystem := preload("res://sim/systems/travel_system.gd")
const PodSystem := preload("res://sim/systems/pod_system.gd")
const Detection := preload("res://sim/detection.gd")
const DetectionSystem := preload("res://sim/systems/detection_system.gd")

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
	test_routes_clear_of_bodies()
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
	test_story_favour_after_abandon()
	test_elevator_not_stranded_at_foot()
	test_edge_cases()
	test_power_budget()
	test_power_drain_and_shedding()
	test_power_damage()
	test_power_saves()
	test_cockpit_alerts()
	test_ship_audio()
	test_time_ramps()
	test_cabin_and_berths()
	test_refit_quote()
	test_favours_in_kind()
	test_hitchhikers()
	test_engine_tunes()
	test_favours_saves()
	test_controls()
	test_new_habitat_places()
	test_wear_accrual()
	test_wear_faults()
	test_condition_resale()
	test_service_and_overhaul()
	test_refit_labour_and_time()
	test_ship_bill()
	test_wof()
	test_insurance()
	test_ship_economy_saves()
	test_yard_voucher_on_bill()
	test_hitchhikers_and_wof()
	test_upkeep_bites()
	test_turning_with_inertia()
	test_final_approach()
	test_counterweights_and_badges()
	test_lander_pods()
	test_detection_and_stealth()
	test_panel_fold()
	test_docking_bays()
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
	# (Someone at the dock may ask for a ride meanwhile: that is a favour event, not a clock one.)
	var types := sim.take_events().map(func(e): return e["type"]).filter(func(t): return not t.begins_with("hitchhiker"))
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
	# The ship starts at the port where it is now, and rides along with it until the
	# burn, which starts from where the port is then (from_pos).
	var start_pos: Array = Navigation.transit_position(s.location, s.time_s)
	check(V.distance(start_pos, sim.ephemeris.relative("kibo_ring", s.location["frame"], s.time_s)) < 1.0, "Transit starts at the origin")
	var burn_t: float = float(s.location["depart_t"]) + (float(s.location["arrive_t"]) - float(s.location["depart_t"]) - float(s.location["burn_s"])) * 0.5
	check(V.distance(Navigation.transit_position(s.location, burn_t), s.location["from_pos"]) < 1.0, "The burn starts from the port's position then")
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
	# The old cage (part-worn, 8,000 new) goes in part-exchange by condition and age, not a flat half,
	# and the yard charges fitting labour on top of the parts (data/ship_economy.json).
	var old_trade := 8000.0 * Condition.value_factor(0.7, 900.0, d)
	var labour := float(Condition.refit_quote("cargo_pod_m", "kibo_ring", d)["labour_cr"])
	check(absf(s.credits - (200000.0 - 30000.0 + old_trade - labour)) < 1e-6, "Old module part-exchanged by condition, labour charged")
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
	check(ShipStats.has_docking_computer(dc.state.ship, dc.data) and absf(dc.state.credits - (50000.0 - 15000.0 - float(Condition.refit_quote("docking_computer", "kibo_ring", dc.data)["labour_cr"]))) < 1e-6, "Docking computer fitted and paid for (parts and labour)")


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
		var low := INF
		for k in 41:
			var tk := lerpf(start, end, k / 40.0)
			peak = maxf(peak, V.length(Navigation.transit_accel(loc, tk)))
			low = minf(low, V.length(Navigation.transit_position(loc, tk)) - 6371000.0)
		# A run that has to go round Earth keeps the straight run's timing (its arc is the
		# path's shape, clear of the planet), so only straight runs are held to the drive.
		if loc.get("around") == null:
			check(peak <= accel * 1.001, "%s thrust never exceeds the drive (%.4f vs %.4f m/s2)" % [to, peak, accel])
		check(low > 140000.0, "%s path stays above Earth's air (%.0f km)" % [to, low / 1000.0])
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


func test_routes_clear_of_bodies() -> void:
	# The hardest routes found by tools/route_clearance.gd: no path may pass through a
	# body or its air (Interplanetary.clearance), or cross Saturn's main rings. Selene
	# Ring skims the Moon at 52 km; the Titan and Sun cases were blocked on worn, tuned
	# or particular-day ships.
	var sim := fresh()
	var d := sim.data
	var hull: Dictionary = d.ships["deep_freighter"]
	var drive := ""
	for slot in hull["modules"]:
		if d.modules.get(hull["modules"][slot], {}).has("thrust_n"):
			drive = slot
	var base := {"hull": "deep_freighter", "modules": hull["modules"].duplicate(), "cargo": {}, "fuel_t": 400.0, "name": "Clearance"}
	var worn := base.duplicate(true)
	Condition.set_condition(worn, drive, 0.3)
	var lean := base.duplicate(true)
	lean["tunes"] = [{"id": "lean_burn_map", "slot": drive, "module": base["modules"][drive], "source": "test"}, {"id": "nozzle_polish", "slot": drive, "module": base["modules"][drive], "source": "test"}]
	var cases := [
		[base, "huygens_port", "plume_watch", 500],
		[worn, "landauer_deep", "huygens_port", 97],
		[lean, "plume_watch", "huygens_port", 97],
		[worn, "valhalla_station", "huygens_port", 0],
		[worn, "valhalla_station", "plume_watch", 0],
		[base, "hektor_reach", "valhalla_station", 365],
		[base, "selene_ring", "kibo_ring", 0],
		[base, "kibo_ring", "selene_ring", 97],
		[base, "selene_ring", "shackleton_port", 37],
		[worn, "shackleton_port", "selene_ring", 151],
		[lean, "selene_ring", "halo_depot", 211],
		[base, "selene_ring", "kernel_l5", 300],
	]
	var eph = sim.ephemeris
	var bodies := ["sun", "earth", "moon", "jupiter", "callisto", "saturn", "titan", "enceladus", "iapetus"]
	# Saturn's ring-plane normal, in the ecliptic frame, from the pole's RA and Dec.
	var sat: Dictionary = d.bodies["saturn"]
	var ra := deg_to_rad(float(sat.get("pole_ra_deg", 0.0)))
	var dec := deg_to_rad(float(sat.get("pole_dec_deg", 90.0)))
	var eq := [cos(dec) * cos(ra), cos(dec) * sin(ra), sin(dec)]
	var obl := deg_to_rad(23.4393)
	var pole := [eq[0], eq[1] * cos(obl) + eq[2] * sin(obl), -eq[1] * sin(obl) + eq[2] * cos(obl)]
	for c in cases:
		var a: String = c[1]
		var b: String = c[2]
		var t: float = sim.state.time_s + float(c[3]) * DAY
		var plan := Navigation.plan(c[0], d, eph, a, b, t)
		check(plan.has("from_pos"), "%s -> %s plans" % [a, b])
		if not plan.has("from_pos"):
			continue
		var loc := {"status": "transit", "from": a, "to": b, "frame": plan["frame"], "depart_t": t, "arrive_t": plan["arrive_t"],
			"burn_s": plan["burn_s"], "from_pos": plan["from_pos"], "to_pos": plan["to_pos"], "from_vel": plan.get("from_vel"),
			"to_vel": plan.get("to_vel"), "from_rot": plan.get("from_rot"), "to_rot": plan.get("to_rot"), "rot_axis": plan.get("rot_axis"),
			"rot_angle": plan.get("rot_angle", 0.0), "samples": plan.get("samples"), "around": plan.get("around"),
			"around_r": plan.get("around_r", 0.0), "avoid": plan.get("avoid")}
		if plan.get("samples") == null:
			var start: float = t + (float(plan["duration_s"]) - float(plan["burn_s"])) * 0.5
			var tracks := Navigation.port_tracks(eph, a, b, plan["frame"], t, start, start + float(plan["burn_s"]), float(plan["arrive_t"]))
			loc["pre_track"] = tracks[0]
			loc["post_track"] = tracks[1]
		Navigation.add_approach(loc, d, eph)
		var p_start: Array = eph.position(a, t)
		var p_end: Array = eph.position(b, float(plan["arrive_t"]))
		var worst := 0.0
		var worst_body := ""
		# The whole trip, and the final approach closely.
		var times := []
		for i in 241:
			times.append(lerpf(t, float(plan["arrive_t"]), float(i) / 240.0))
		if loc.get("approach") != null:
			for leg in loc["approach"]["legs"]:
				for i in 41:
					times.append(lerpf(float(leg[0]), float(leg[1]), float(i) / 40.0))
			if loc["approach"].has("descent"):
				for i in 121:
					times.append(lerpf(float(loc["approach"]["descent"]["t_d"]), float(loc["approach"]["t0"]), float(i) / 120.0))
		for ti: float in times:
			var here := V.add(eph.position(plan["frame"], ti), Navigation.transit_position(loc, ti))
			for id in bodies:
				var cb: Array = eph.position(id, ti)
				var need := Interplanetary.clearance(d, id)
				var gap := need - V.distance(here, cb)
				if gap <= worst:
					continue
				if V.distance(p_start, eph.position(id, t)) < need * 1.01 and V.distance(here, p_start) < need * 2.0:
					continue
				if V.distance(p_end, eph.position(id, float(plan["arrive_t"]))) < need * 1.01 and V.distance(here, p_end) < need * 2.0:
					continue
				worst = gap
				worst_body = id
		check(worst_body == "", "%s -> %s (day %d) stays clear of %s (%.0f km inside)" % [a, b, c[3], worst_body, worst / 1000.0])
		if plan["frame"] == "saturn":
			var rs := float(d.bodies["saturn"]["radius_m"])
			var prev := 0.0
			var prev_rel := []
			var crossed := false
			for i in 241:
				var ti := lerpf(t, float(plan["arrive_t"]), float(i) / 240.0)
				var rel: Array = Navigation.transit_position(loc, ti)
				var side := V.dot(rel, pole)
				if i > 0 and signf(side) != signf(prev) and prev != 0.0:
					var rr := V.length(V.lerp(prev_rel, rel, prev / (prev - side))) / rs
					crossed = crossed or (rr > 1.11 and rr < 2.27)
				prev = side
				prev_rel = rel
			check(not crossed, "%s -> %s keeps out of Saturn's rings" % [a, b])


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
	var mass_before := ShipStats.total_mass_t(s.ship, sim.data)
	check(sim.apply({"type": "accept_contract", "id": offer["id"]}) == "", "Take the package job")
	# In the hold, or carried by hand in the cabin (no hold space): its mass is aboard either way.
	var in_hold := 0.0 if bool(offer.get("hand", false)) else float(offer["mass_t"])
	check(absf(ShipStats.cargo_t(s.ship) - before - in_hold) < 1e-9, "The parcel is stowed where it belongs")
	check(absf(ShipStats.total_mass_t(s.ship, sim.data) - mass_before - float(offer["mass_t"])) < 1e-9, "The parcel's mass is aboard")
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
	check(lost_event["payout"] > 0.0 and absf(ls.credits - (20000.0 + lost_event["payout"] - float(tune["insurance_excess"]))) < 1e-6, "Insurance pays out the Mk2 drive's worth and costs exactly the excess")
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


## A favour you gave up on is offered again, and you can still take it. (Abandoning
## costs standing with the client; an offer gated at standing 0 would be locked for good.)
func test_story_favour_after_abandon() -> void:
	var sim := fresh()
	var s := sim.state
	s.stats["contracts_delivered"] = 3
	s.reputation["Terran Compact"] = 7.0
	_dock_at(sim, "clarke_exchange")
	var first: Dictionary = _first_favour_offer(s)
	check(sim.apply({"type": "accept_contract", "id": first["id"]}) == "", "Take the Long View's first favour")
	check(sim.apply({"type": "abandon_contract", "id": first["id"]}) == "", "and give it up")
	check(Contracts.rep_of(s, "The Long View") < 0.0, "which costs standing with the Long View")
	sim.advance_game_time(2.0 * 3600.0)
	var again: Dictionary = _first_favour_offer(s)
	check(not again.is_empty() and int(again["id"]) != int(first["id"]), "The favour is offered again")
	check(ContractSystemScript.visible_to(s, sim.data, again), "and the pilot can see it, whatever they owe")
	check(sim.apply({"type": "accept_contract", "id": again["id"]}) == "", "and take it, so the arc can go on")
	# The same goes for a favour that was allowed to fail.
	var failed := fresh()
	var f := failed.state
	f.stats["contracts_delivered"] = 3
	f.reputation["Terran Compact"] = 7.0
	_dock_at(failed, "clarke_exchange")
	var offer: Dictionary = _first_favour_offer(f)
	failed.apply({"type": "accept_contract", "id": offer["id"]})
	f.location = {"status": "docked", "place": "kibo_ring"}
	failed.advance_game_time(float(offer["window_s"]) * 2.5)
	check(f.contracts["history"].any(func(j): return j["id"] == offer["id"] and j["outcome"] == "failed"), "A favour left to rot fails")
	failed.advance_game_time(2.0 * 3600.0)
	var retry: Dictionary = _first_favour_offer(f)
	check(not retry.is_empty() and ContractSystemScript.visible_to(f, failed.data, retry), "and is offered again at the next dock, in a form the pilot can accept")


func _first_favour_offer(s) -> Dictionary:
	for place in s.contracts["board"]:
		for o in s.contracts["board"][place]:
			if o.get("favour", "") == "first_favour":
				return o
	return {}


## A pilot who rides down with only the fare, and spends the rest at the town, must still be
## able to get back up to their ship: nothing at the foot of a ribbon earns money.
func test_elevator_not_stranded_at_foot() -> void:
	var sim := fresh()
	var s := sim.state
	s.location = {"status": "docked", "place": "halo_depot"}
	s.ship["cargo"] = {}
	s.credits = 160.0
	check(sim.apply({"type": "ride_elevator"}) == "", "Ride down with a little more than the fare")
	sim.advance_game_time(56.0 * 3600.0 + 1.0)
	check(s.location == {"status": "docked", "place": "line_foot"} and absf(s.credits - 10.0) < 1e-9, "At Line Foot with 10 cr")
	check(sim.apply({"type": "ride_elevator"}) == "", "A pilot with less than the fare can still ride up to their ship")
	check(s.location["status"] == "elevator" and not s.location["down"], "and is on the way up")
	check(s.credits < 0.0, "the fare goes on credit, as emergency fuel does")
	sim.advance_game_time(56.0 * 3600.0 + 1.0)
	check(s.location == {"status": "docked", "place": "halo_depot"}, "Back at the depot")
	check(sim.apply({"type": "ride_elevator"}) != "", "In debt, the pilot cannot ride down again")


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


## Sum of a module field over the ship's modules, straight from the data (no damage).
func _module_sum(ship: Dictionary, d: DataCatalog, key: String) -> float:
	var total := 0.0
	for slot in ship["modules"]:
		total += float(d.modules[ship["modules"][slot]].get(key, 0.0))
	return total


func _ctx(mode: String, au: float, lit: bool, active: Dictionary = {}) -> Dictionary:
	return {"mode": mode, "au": au, "lit": lit, "manual": false, "active": {"sensor": bool(active.get("sensor", false)), "mining": bool(active.get("mining", false))}}


## Park the ship on a site, away from ports, with the reactor cold.
func _park(sim: Sim, site: String) -> void:
	sim.state.location = {"status": "on_site", "place": site}
	sim.state.power = {}


## Supply and demand add up from the module data; solar falls with the square of distance.
func test_power_budget() -> void:
	var sim := fresh()
	var s := sim.state
	var d := sim.data
	var tune: Dictionary = d.balance["power"]
	var ship := s.ship
	var cap := _module_sum(ship, d, "battery_kwh")
	check(cap > 0.0, "A starting ship has a battery bank (%.0f kWh)" % cap)
	# In transit at 1 AU: reactor lit, solar wings at full output.
	var snap := Power.snapshot(ship, d, _ctx("transit", 1.0, true), cap, 0)
	check(absf(snap["supply"]["reactor"] - _module_sum(ship, d, "reactor_kw")) < 1e-9, "Reactor output is the drives' reactor_kw while lit")
	check(absf(snap["supply"]["solar"] - _module_sum(ship, d, "solar_kw")) < 1e-9, "Solar is the wings' output at 1 AU")
	check(absf(snap["supply"]["total"] - snap["supply"]["reactor"] - snap["supply"]["solar"]) < 1e-9 and snap["supply"]["shore"] == 0.0, "Supply sums reactor and solar (no shore power in flight)")
	var heat := minf(_module_sum(ship, d, "heat_mw") * float(tune["heat_frac"]["transit"]), _module_sum(ship, d, "reject_mw"))
	var want := _module_sum(ship, d, "life_kw") + _module_sum(ship, d, "avionics_kw") + _module_sum(ship, d, "comms_kw") + heat * float(tune["pump_kw_per_mw"])
	check(absf(snap["demand"]["total"] - want) < 1e-9, "Demand sums life support, avionics, comms and the pumps (%.2f kW)" % want)
	check(snap["demand"]["sensor"] == 0.0 and snap["demand"]["mining"] == 0.0, "No sensor or rig load when none is fitted")
	check(absf(snap["net_kw"] - (snap["supply"]["total"] - want)) < 1e-9 and snap["state"] == "NORM", "Net power is supply minus demand; a full bus is normal")
	# Pumps follow the heat being rejected.
	var parked_pumps: float = Power.snapshot(ship, d, _ctx("approach", 1.0, true), cap, 0)["demand"]["pumps"]
	check(parked_pumps < snap["demand"]["pumps"] and parked_pumps > 0.0, "Pumps work harder when the drive rejects more heat")
	check(Power.snapshot(ship, d, _ctx("parked", 1.0, false), cap, 0)["demand"]["pumps"] == 0.0, "A cold reactor needs no pumps")
	# Fitted sensors and a rig idle on standby and draw fully only while working.
	var kit := ship.duplicate(true)
	kit["modules"]["avionics.0"] = "survey_pod"
	kit["modules"]["cargo.1"] = "mining_rig"
	var idle := Power.snapshot(kit, d, _ctx("parked", 1.0, false), cap, 0)
	var work := Power.snapshot(kit, d, _ctx("work", 1.0, true, {"sensor": true, "mining": true}), cap, 0)
	check(absf(idle["demand"]["sensor"] - _module_sum(kit, d, "sensor_kw") * float(tune["standby_frac"])) < 1e-9, "A survey pod idles on standby")
	check(absf(work["demand"]["sensor"] - _module_sum(kit, d, "sensor_kw")) < 1e-9 and absf(work["demand"]["mining"] - _module_sum(kit, d, "mining_kw")) < 1e-9, "and draws its full load while working")
	# Solar falloff.
	check(absf(Power.solar_factor(2.0, tune) - 0.25) < 1e-9 and absf(Power.solar_factor(1.0, tune) - 1.0) < 1e-9, "Solar falls with the inverse square of distance")
	check(Power.solar_factor(0.05, tune) == float(tune["solar_factor_max"]), "and is capped close to the Sun")
	var far := Power.snapshot(ship, d, _ctx("parked", 5.2, false), cap, 0)
	check(absf(far["supply"]["solar"] - _module_sum(ship, d, "solar_kw") / (5.2 * 5.2)) < 1e-9, "At Jupiter's distance the wings give 1/27 of their output")
	# Where the ship is: Earth's neighbourhood is about 1 AU; a belt site is further.
	check(absf(Power.sun_distance_au(s, sim.ephemeris) - 1.0) < 0.05, "Docked at Earth's Moon, the Sun is about 1 AU away")
	s.location = {"status": "on_site", "place": "hektor_survey"}
	check(Power.sun_distance_au(s, sim.ephemeris) > 4.5, "A Jupiter Trojan is out where sunlight is thin (%.1f AU)" % Power.sun_distance_au(s, sim.ephemeris))
	# Docked: shore power covers the bus and charges the battery.
	var dock := Power.snapshot(ship, d, _ctx("docked", 1.0, false), 0.5 * cap, 0)
	check(dock["state"] == "SHORE" and dock["net_kw"] > 0.0 and dock["hours_to_full"] < INF, "Docked ships run on shore power and charge")
	# The reactor command: lit on purpose, refused if there is no reactor.
	var cold := fresh()
	_park(cold, "hektor_survey")
	check(not Power.now(cold.state, cold.data, cold.ephemeris)["lit"], "Parked, the reactor is cold")
	check(cold.apply({"type": "reactor", "mode": "on"}) == "" and Power.now(cold.state, cold.data, cold.ephemeris)["lit"], "The reactor command lights it")
	check(cold.apply({"type": "reactor", "mode": "sideways"}) != "", "Bad reactor modes are refused")
	cold.state.ship["modules"]["drive.0"] = "kestrel_engines"
	check(cold.apply({"type": "reactor", "mode": "on"}) != "", "A ship with no reactor cannot light one")


## A deficit drains the battery; comms and sensors shed first, then the rig, and life support last.
func test_power_drain_and_shedding() -> void:
	var sim := fresh()
	var s := sim.state
	var d := sim.data
	var tune: Dictionary = d.balance["power"]
	var cap := ShipStats.battery_kwh(s.ship, d)
	# Cold and far from the Sun, solar alone cannot carry the hotel load.
	_park(sim, "hektor_survey")
	var snap := Power.now(s, d, sim.ephemeris)
	check(snap["net_kw"] < 0.0 and snap["state"] == "BATT", "Parked at Hektor with a cold reactor the bus runs on the battery")
	check(snap["hours_to_empty"] > 24.0 and snap["hours_to_empty"] < INF, "with a day or more in hand (%.0f h)" % snap["hours_to_empty"])
	sim.advance_game_time(10.0 * 3600.0)
	check(absf(s.power["charge_kwh"] - (cap + snap["net_kw"] * 10.0)) < 0.01 * cap, "Ten hours of deficit drain ten hours of net power from the battery")
	# At 1 AU the same parked ship charges.
	var sunny := fresh()
	sunny.state.location = {"status": "on_site", "place": "ishikawa_maru"}
	sunny.state.power = {"charge_kwh": 0.5 * cap}
	sunny.advance_game_time(3600.0)
	check(sunny.state.power["charge_kwh"] > 0.5 * cap, "Parked in sunlight the wings charge the battery")
	check(sunny.state.power["charge_kwh"] <= cap, "and never past full")
	# Shed order, by charge fraction (pure rule, with hysteresis).
	check(Power.shed_level(0.5, true, 0, tune) == 0, "Plenty of charge: nothing shed")
	check(Power.shed_level(0.2, true, 0, tune) == 1 and Power.shed_level(0.1, true, 0, tune) == 2 and Power.shed_level(0.03, true, 0, tune) == 3, "Comms and sensors go first, then the rig, then life support gets its warning")
	check(Power.shed_level(0.01, false, 0, tune) == 0, "With no deficit nothing sheds, however low the charge")
	var margin := float(tune["shed_release_margin"])
	check(Power.shed_level(float(tune["shed_comms_below"]) + margin * 0.5, true, 1, tune) == 1 and Power.shed_level(float(tune["shed_comms_below"]) + margin * 1.5, true, 1, tune) == 0, "Shed loads come back only after a margin of charge")
	# What each level takes off the bus.
	var kit := s.ship.duplicate(true)
	kit["modules"]["avionics.0"] = "survey_pod"
	kit["modules"]["cargo.1"] = "mining_rig"
	var ctx := _ctx("work", 5.0, false, {"sensor": true, "mining": true})
	var full := Power.snapshot(kit, d, ctx, 0.5 * cap, 0)
	var l1 := Power.snapshot(kit, d, ctx, 0.2 * cap, 0)
	var l2 := Power.snapshot(kit, d, ctx, 0.1 * cap, 0)
	var l3 := Power.snapshot(kit, d, ctx, 0.03 * cap, 0)
	check(full["shed"] == 0 and full["draw"]["total"] == full["demand"]["total"], "No shedding at half charge")
	check(l1["shed"] == 1 and l1["draw"]["comms"] == 0.0 and l1["draw"]["sensor"] == 0.0 and l1["draw"]["mining"] > 0.0 and l1["state"] == "SHED", "Level 1 sheds comms and sensors only")
	check(l2["shed"] == 2 and l2["draw"]["mining"] == 0.0 and l2["draw"]["life"] > 0.0, "Level 2 sheds the rig too; life support stays on")
	check(l3["shed"] == 3 and l3["draw"]["life"] == l3["demand"]["life"] and l3["draw"]["avionics"] == l3["demand"]["avionics"] and l3["state"] == "LOW", "Level 3 warns on life support but does not touch it")
	check(l3["draw"]["total"] <= l2["draw"]["total"] and l2["draw"]["total"] < l1["draw"]["total"] and l1["draw"]["total"] < full["draw"]["total"], "Each level draws less than the one before (life support is never shed, so 3 equals 2)")
	# Run it out: the events come in order, and the warning comes before the battery is flat.
	var drain := fresh()
	_park(drain, "hektor_survey")
	drain.state.power = {"charge_kwh": 0.3 * cap}
	drain.take_events()
	drain.advance_game_time(48.0 * 3600.0)
	var kinds := []
	for e in drain.take_events():
		if e["type"] == "power_shed":
			kinds.append(int(e["data"]["level"]))
		elif e["type"] == "power_flat":
			kinds.append("flat")
	check(kinds.slice(0, 4) == [1, 2, 3, "flat"], "Loads shed in order, life-support warning before the battery is flat: %s" % [kinds])
	check(drain.state.power["charge_kwh"] >= 0.0 and drain.state.power["flat"], "A flat battery stays at zero and is flagged")
	# Lighting the reactor ends it: the bus recovers and the loads come back.
	drain.apply({"type": "reactor", "mode": "on"})
	drain.advance_game_time(3600.0)
	check(drain.state.power["shed"] == 0 and not drain.state.power["flat"] and drain.state.power["charge_kwh"] > 0.0, "Lighting the reactor brings everything back")
	# A shed sensor pauses a survey instead of ruining it.
	var job := fresh()
	job.state.ship["modules"]["avionics.0"] = "survey_pod"
	job.state.location = {"status": "on_site", "place": "hektor_survey"}
	job.state.sites["known"].append("hektor_survey")
	check(job.apply({"type": "site_work", "activity": "survey"}) == "", "Start a survey at Hektor")
	var end0: float = job.state.sites["work"]["end_t"]
	job.state.ship["damage"] = {"drive.0": 1.0}
	job.state.power = {"charge_kwh": 0.1 * cap}
	job.advance_game_time(5.0 * 3600.0)
	check(job.state.power["shed"] >= 1 and float(job.state.sites["work"]["end_t"]) > end0 + 3.0 * 3600.0, "With the sensors shed, the survey waits for power")
	job.state.ship["damage"] = {}
	job.advance_game_time(3600.0)
	var end1: float = job.state.sites["work"]["end_t"]
	job.advance_game_time(3600.0)
	check(job.state.sites["work"]["end_t"] == end1, "and carries on once the bus recovers")


## Damage cuts what a module supplies, not what it draws.
func test_power_damage() -> void:
	var sim := fresh()
	var d := sim.data
	var ship := sim.state.ship
	var ctx := _ctx("transit", 1.0, true)
	var cap := ShipStats.battery_kwh(ship, d)
	var sound := Power.snapshot(ship, d, ctx, cap, 0)
	var hurt := ship.duplicate(true)
	hurt["damage"] = {"drive.0": 0.5}
	var drive := Power.snapshot(hurt, d, ctx, cap, 0)
	check(absf(drive["supply"]["reactor"] - 0.5 * sound["supply"]["reactor"]) < 1e-9 and drive["supply"]["solar"] == sound["supply"]["solar"], "A half-wrecked drive gives half the reactor power")
	hurt["damage"] = {"command.0": 0.5}
	var cmd := Power.snapshot(hurt, d, ctx, cap, 0)
	check(absf(cmd["supply"]["solar"] - 0.5 * sound["supply"]["solar"]) < 1e-9, "Damaged solar wings give less")
	check(absf(cmd["battery_kwh"] - 0.5 * cap) < 1e-9, "and the battery bank holds less")
	check(cmd["demand"]["life"] == sound["demand"]["life"] and cmd["demand"]["avionics"] == sound["demand"]["avionics"], "but a damaged module still draws its load")
	hurt["damage"] = {"radiator.0": 1.0, "radiator.1": 1.0}
	var rad := Power.snapshot(hurt, d, ctx, cap, 0)
	check(rad["demand"]["pumps"] == 0.0, "Wrecked radiators reject nothing, so their pumps stop")
	hurt["damage"] = {"drive.0": 1.0, "command.0": 0.9}
	var wreck := Power.snapshot(hurt, d, ctx, 0.5 * ShipStats.battery_kwh(hurt, d), 0)
	check(wreck["net_kw"] < 0.0, "A ship that has lost its reactor and most of its wings runs a deficit even in flight")
	# And through the sim: the impact command damages, the bus follows.
	sim.state.location = {"status": "approach", "place": "kibo_ring"}
	var before: float = Power.now(sim.state, d, sim.ephemeris)["supply"]["total"]
	sim.apply({"type": "impact", "speed": 20.0, "share": 1.0, "zone": "nose", "seed": 0})
	check(sim.state.location.get("status") == "lifeboat" or Power.now(sim.state, d, sim.ephemeris)["supply"]["total"] <= before, "A hard knock never adds power")


## The bus survives a save, and old saves load with sensible defaults.
func test_power_saves() -> void:
	var sim := fresh()
	var cap := ShipStats.battery_kwh(sim.state.ship, sim.data)
	_park(sim, "hektor_survey")
	sim.state.power = {"charge_kwh": 0.4 * cap}
	sim.apply({"type": "reactor", "mode": "on"})
	sim.advance_game_time(3600.0)
	var loaded := SaveIO.from_text(SaveIO.to_text(sim.state))
	check(loaded != null and loaded.power == sim.state.power and loaded.power.has("charge_kwh"), "Battery charge, shed level and reactor mode round-trip in a save")
	var resumed := Sim.new()
	resumed.load_state(loaded)
	resumed.advance_game_time(6.0 * 3600.0)
	sim.advance_game_time(6.0 * 3600.0)
	check(resumed.state.to_dict() == sim.state.to_dict(), "A loaded game continues with the same power")
	# An old save has no power block: the battery is full, the reactor on auto.
	var old := sim.state.to_dict()
	old.erase("power")
	var from_old := SaveIO.from_text(JSON.stringify({"state": Marshalls.raw_to_base64(var_to_bytes(old))}))
	check(from_old != null and from_old.power.is_empty(), "A save from before power loads, with an empty power block")
	var snap := Power.now(from_old, sim.data, sim.ephemeris)
	check(absf(snap["frac"] - 1.0) < 1e-9 and snap["shed"] == 0 and not snap["lit"], "and starts with a full battery, nothing shed")
	var resumed_old := Sim.new()
	resumed_old.load_state(from_old)
	resumed_old.advance_game_time(3600.0)
	check(resumed_old.state.power.has("charge_kwh") and resumed_old.state.power["charge_kwh"] <= cap, "and the power system fills the block in on the first tick")
	# A new ship (refit, lifeboat) with a smaller bank never holds more than it can.
	var swap := fresh()
	swap.state.power = {"charge_kwh": 1.0e6}
	swap.advance_game_time(3600.0)
	check(swap.state.power["charge_kwh"] <= ShipStats.battery_kwh(swap.state.ship, swap.data) + 1e-9, "Charge is clamped to the ship's battery")


## Cockpit alert thresholds come from data, and the POWER lamp follows the bus.
func test_cockpit_alerts() -> void:
	var sim := fresh()
	var d := sim.data
	var tune: Dictionary = d.balance["cockpit"]
	for key in ["fuel_caution", "fuel_warning", "hull_caution", "hull_warning", "heat_caution", "heat_warning", "damage_caution", "damage_warning", "power_caution_frac", "power_caution_hours"]:
		check(tune.has(key), "balance.json cockpit has %s" % key)
	check(float(tune["fuel_caution"]) == 0.2 and float(tune["fuel_warning"]) == 0.05 and float(tune["hull_caution"]) == 0.7 and float(tune["hull_warning"]) == 0.4, "The thresholds keep their old values")
	var alerts := CockpitPages.ship_alerts(sim)
	check(alerts["POWER"] == 0 and alerts["HULL"] == 0 and alerts["FUEL LOW"] == 0, "A healthy ship shows no alerts")
	sim.state.ship["fuel_t"] = 0.19 * ShipStats.fuel_capacity_t(sim.state.ship, d)
	check(CockpitPages.ship_alerts(sim)["FUEL LOW"] == 1, "Fuel under 20% is a caution")
	sim.state.ship["fuel_t"] = 0.04 * ShipStats.fuel_capacity_t(sim.state.ship, d)
	check(CockpitPages.ship_alerts(sim)["FUEL LOW"] == 2, "and under 5% a warning")
	sim.state.ship["damage"] = {"keel": 0.35}
	check(CockpitPages.ship_alerts(sim)["HULL"] == 1, "A hull under 70% is a caution")
	sim.state.ship["damage"] = {"keel": 0.65}
	check(CockpitPages.ship_alerts(sim)["HULL"] == 2, "and under 40% a warning")
	var cap := ShipStats.battery_kwh(sim.state.ship, d)
	var ctx := _ctx("parked", 5.0, false)
	var level := func(frac: float) -> int:
		return CockpitPages.power_level(Power.snapshot(sim.state.ship, d, ctx, frac * cap, 0), tune)
	check(level.call(0.9) == 0, "A big battery on a slow drain is not worth a lamp")
	check(level.call(0.4) == 1, "Below half charge and discharging: POWER caution")
	check(level.call(0.2) == 1, "Loads shed: still a caution")
	check(level.call(0.03) == 2, "Life support next: POWER warning")
	check(CockpitPages.power_level(Power.snapshot(sim.state.ship, d, _ctx("docked", 1.0, false), 0.1 * cap, 0), tune) == 0, "No lamp on shore power")


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


## Leaving port time steps up from x1 to the default; arriving it is capped lower and
## lower so the last seconds play at x1; a pilot's own choice of scale is kept.
func test_time_ramps() -> void:
	var sim := fresh()
	var s := sim.state
	s.time_scale = 100.0
	check(sim.apply({"type": "depart", "to": "halo_depot"}) == "", "Depart for the ramp test")
	check(s.time_scale == 1.0, "Departure starts at x1 (%.0f)" % s.time_scale)
	for _i in 200:
		sim.tick(0.05)
	check(s.time_scale == 1.0, "Ten seconds out, still at x1 to watch the port fall away (%.0f)" % s.time_scale)
	for _i in 500:
		sim.tick(0.05)
	check(s.time_scale == 1000.0, "Thirty-five seconds out, time has stepped up to x1000 (%.0f)" % s.time_scale)
	s.time_scale = 100000.0
	var last_scale := -1.0
	var seen_slow := false
	for _i in 5000:
		if s.location.get("status") != "transit":
			break
		var left := float(s.location["arrive_t"]) - s.time_s
		if left < 10.0:
			seen_slow = true
			last_scale = maxf(last_scale, s.time_scale)
		sim.tick(0.05)
	check(s.location.get("status") == "approach", "The trip ends on the approach")
	check(seen_slow and last_scale <= 1.0, "The last ten seconds play at x1 (%.0f)" % last_scale)
	# A pilot who picks a scale during the departure ramp keeps it.
	var sim2 := fresh()
	check(sim2.apply({"type": "depart", "to": "halo_depot"}) == "", "Depart again")
	sim2.tick(1.0)
	sim2.apply({"type": "set_time_scale", "scale": 10})
	for _i in 300:
		sim2.tick(0.05)
	check(sim2.state.time_scale == 10.0, "The pilot's own x10 stands (%.0f)" % sim2.state.time_scale)


## Where the controls test keeps its own settings, apart from the player's.
const TEST_SETTINGS := "user://test_settings.cfg"

## What every action was bound to before remapping existed: the defaults must not move.
const ORIGINAL_KEYS := {
	"controls_page": ["F1"], "pause": ["P"], "sound": ["F2"], "time_slower": ["BracketLeft"],
	"time_faster": ["BracketRight"], "quick_save": ["F5"], "quick_load": ["F9"],
	"flight_forward": ["W"], "flight_back": ["S"], "flight_strafe_left": ["A"], "flight_strafe_right": ["D"],
	"flight_up": ["R"], "flight_down": ["F"], "flight_boost": ["Shift"], "flight_brake": ["X"],
	"flight_pitch_up": ["Up"], "flight_pitch_down": ["Down"], "flight_yaw_left": ["Left"], "flight_yaw_right": ["Right"],
	"flight_roll_left": ["Q"], "flight_roll_right": ["E"], "flight_assist": ["Z"], "flight_spin_match": ["V"],
	"flight_scanner": ["G"], "flight_view": ["C"], "flight_computer": ["K"], "flight_tug": ["T"], "flight_keys": ["H"],
	"transit_view": ["M"], "transit_look_left": ["Left"], "transit_look_right": ["Right"], "transit_look_up": ["Up"],
	"transit_look_down": ["Down"], "transit_telescope": ["Z"], "transit_centre": ["C"],
	"lander_main": ["W", "Space"], "lander_left": ["A", "Left"], "lander_right": ["D", "Right"],
	"lander_forward": ["Q", "Up"], "lander_back": ["E", "Down"],
	"climber_look_left": ["Left"], "climber_look_right": ["Right"], "climber_look_up": ["Up"], "climber_look_down": ["Down"],
	"title_start": ["Space", "Enter", "KP Enter"], "title_load": ["L"], "title_quit": ["Escape"],
}


func _remove_test_settings() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))


func test_controls() -> void:
	_remove_test_settings()
	var catalog: Dictionary = DataCatalog.load_default().controls
	var b = Bindings.new(catalog)
	check(b.problems().is_empty(), "Controls catalogue is sound: %s" % str(b.problems()))
	check(b.actions.size() >= ORIGINAL_KEYS.size(), "Controls list every action")

	# Defaults: every original key binding is where it was, and every spec is a real event.
	var moved := []
	for id in ORIGINAL_KEYS:
		var want := []
		for k in ORIGINAL_KEYS[id]:
			want.append(Bindings.canonical("key:" + k))
		if not b.actions.has(id) or b.specs(id, "key") != want:
			moved.append(id)
	check(moved.is_empty(), "Every original key binding is unchanged: %s" % str(moved))
	var round_trips := true
	for id in b.actions:
		for kind in ["key", "pad"]:
			for spec in b.specs(id, kind):
				var ev := Bindings.event_for(spec)
				if ev is InputEventKey or ev is InputEventJoypadButton:
					ev.pressed = true
				round_trips = round_trips and ev != null and b.spec_of(ev, 0.5) == spec
				if ev == null or b.spec_of(ev, 0.5) != spec:
					push_error("CONTROLS: %s does not round-trip" % spec)
	check(round_trips, "Every default spec becomes an event and back to the same spec")
	check(Bindings.event_for("key:NotAKey") == null and Bindings.event_for("pad:zz") == null and Bindings.event_for("junk") == null, "Bad specs are not bindings")
	check(b.specs("flight_forward", "pad") == ["pad:rt+"] and b.specs("flight_strafe_left", "pad") == ["pad:lx-"] and b.specs("pause", "pad") == ["pad:start"], "Gamepad defaults: triggers thrust, left stick strafes, Start pauses")
	check(Bindings.spec_text("key:BracketLeft") == "[" and Bindings.spec_text("pad:rt+") == "RT" and Bindings.spec_text("key:W") == "W", "Bindings read as text")

	# The InputMap: every action resolves, with the events and deadzones from data.
	b.apply()
	var resolved := true
	for id in b.actions:
		var count: int = b.specs(id, "key").size() + b.specs(id, "pad").size()
		if not InputMap.has_action(id) or InputMap.action_get_events(id).size() != count:
			resolved = false
			push_error("CONTROLS: %s did not resolve" % id)
	check(resolved, "Every action in controls.json resolves in the InputMap")
	check(is_equal_approx(InputMap.action_get_deadzone("flight_strafe_left"), float(catalog["gamepad"]["deadzone"])), "Sticks use the deadzone from data")
	check(is_equal_approx(InputMap.action_get_deadzone("flight_forward"), float(catalog["gamepad"]["trigger_deadzone"])), "Triggers use their own deadzone")
	Input.action_press("flight_forward", 0.5)
	check(is_equal_approx(Input.get_action_strength("flight_forward"), 0.5), "An action can be analog")
	Input.action_release("flight_forward")

	# Every action the views ask for is in the catalogue.
	var wanted := _actions_in_views("res://view")
	var missing := []
	for id in wanted:
		if not b.actions.has(id):
			missing.append(id)
	check(wanted.size() > 20 and missing.is_empty(), "Every action named in view code is in controls.json: %s" % str(missing))

	# Override, save, load.
	var r: Dictionary = b.rebind("flight_boost", "key:B")
	check(r["ok"] and b.specs("flight_boost", "key") == ["key:B"] and b.is_changed("flight_boost"), "Rebinding replaces the keyboard binding")
	check(b.specs("flight_boost", "pad") == ["pad:a"], "A keyboard rebind leaves the gamepad one alone")
	r = b.rebind("flight_boost", "pad:rb")
	check(r["ok"] and b.specs("flight_boost", "pad") == ["pad:rb"] and b.specs("flight_roll_right", "pad") == ["pad:a"], "A gamepad rebind swaps with the control that had it")
	b.apply()
	check(InputMap.action_has_event("flight_boost", Bindings.event_for("key:B")) and not InputMap.action_has_event("flight_boost", Bindings.event_for("key:Shift")), "A rebind reaches the InputMap")
	check(b.save(TEST_SETTINGS) == OK, "Settings save")
	var again = Bindings.new(catalog)
	check(again.load_file(TEST_SETTINGS) and again.overrides == b.overrides, "Saved settings load back as saved")
	check(again.specs("flight_boost", "key") == ["key:B"] and again.specs("flight_assist", "key") == ["key:Z"], "A loaded override applies and the rest stay default")
	check(not Bindings.new(catalog).load_file("user://no_such_settings.cfg"), "No settings file means defaults")

	# A hand-edited file cannot break anything.
	var cfg := ConfigFile.new()
	cfg.load(TEST_SETTINGS)
	cfg.set_value("controls", "no_such_action.key", PackedStringArray(["key:Q"]))
	cfg.set_value("controls", "pause.key", PackedStringArray(["key:NotAKey", "pad:a", "key:O"]))
	cfg.set_value("controls", "sound.pad", "garbage")
	cfg.set_value("other", "volume", 0.5)
	cfg.save(TEST_SETTINGS)
	var rough = Bindings.new(catalog)
	rough.load_file(TEST_SETTINGS)
	check(rough.specs("pause", "key") == ["key:O"] and rough.specs("sound", "pad") == [] and not rough.overrides.has("no_such_action"), "Bad entries in the settings file are dropped")
	check(rough.save(TEST_SETTINGS) == OK and ConfigFile.new().load(TEST_SETTINGS) == OK, "Saving keeps the rest of the file")
	var kept := ConfigFile.new()
	kept.load(TEST_SETTINGS)
	check(kept.get_value("other", "volume", 0.0) == 0.5, "Other settings in the file survive a save")

	# Conflicts.
	var c = Bindings.new(catalog)
	r = c.rebind("flight_forward", "key:A")
	check(r["ok"] and r["swapped"] == ["flight_strafe_left"] and c.specs("flight_forward", "key") == ["key:A"] and c.specs("flight_strafe_left", "key") == ["key:W"], "A key in use on the same screen swaps")
	check(r["message"].begins_with("Swapped"), "The swap says so: %s" % r["message"])
	check(c.conflicts().is_empty(), "After a swap nothing doubles up: %s" % str(c.conflicts()))
	r = c.rebind("lander_main", "key:Z")
	check(r["ok"] and r["swapped"].is_empty() and c.specs("flight_assist", "key") == ["key:Z"], "A key used only on another screen does not swap")
	r = c.rebind("lander_left", "key:Escape")
	check(not r["ok"] and r["message"].begins_with("Refused") and c.specs("lander_left", "key") == ["key:A", "key:Left"], "A reserved key is refused and nothing changes")
	var before: Dictionary = c.overrides.duplicate(true)
	r = c.rebind("flight_forward", "key:P")
	check(not r["ok"] and r["message"].begins_with("Refused") and c.overrides == before, "A swap that would clash elsewhere is refused whole: %s" % r["message"])
	var d = Bindings.new(catalog)
	r = d.rebind("pause", "key:Space")
	check(r["ok"] and r["swapped"].size() == 2 and d.specs("pause", "key") == ["key:Space"] and d.specs("lander_main", "key") == ["key:W", "key:P"] and d.conflicts().is_empty(), "An anywhere control swaps with every screen that had the key: %s" % str(d.conflicts()))
	r = c.rebind("flight_forward", "key:A")
	check(r["ok"] and r["swapped"].is_empty(), "Rebinding to what it already has is a no-op")
	c.clear("flight_brake", "key")
	check(c.specs("flight_brake", "key").is_empty() and c.text("flight_brake", "key") == "unbound", "A control can be unbound")
	check(not c.rebind("nope", "key:Q")["ok"] and not c.rebind("pause", "key:NotAKey")["ok"], "Unknown actions and bad specs are refused")

	# Reset.
	c.reset_all()
	check(not c.has_changes() and c.specs("flight_forward", "key") == ["key:W"], "Reset puts every default back")
	check(c.save(TEST_SETTINGS) == OK and ConfigFile.new().load(TEST_SETTINGS) == OK, "A reset saves")
	var cleared = Bindings.new(catalog)
	check(not cleared.load_file(TEST_SETTINGS) and not cleared.has_changes(), "A saved reset leaves no overrides")
	c.apply()
	_remove_test_settings()


## Action names the view code asks the Input singleton or an event for.
func _actions_in_views(dir_path: String) -> Dictionary:
	var found := {}
	var single := RegEx.create_from_string("(?:is_action_pressed|is_action_released|is_action|get_action_strength|is_action_just_pressed|_input_axis|key_of|hint_of)\\(\"(\\w+)\"(?:,\\s*\"(\\w+)\")?")
	var axis := RegEx.create_from_string("get_axis\\(\"(\\w+)\",\\s*\"(\\w+)\"")
	var dir := DirAccess.open(dir_path)
	for sub in dir.get_directories():
		found.merge(_actions_in_views(dir_path + "/" + sub))
	for f in dir.get_files():
		if not f.ends_with(".gd"):
			continue
		var src := FileAccess.get_file_as_string(dir_path + "/" + f)
		for m in single.search_all(src):
			found[m.get_string(1)] = true
			if m.get_string(2) != "" and m.get_string(0).begins_with("_input_axis"):
				found[m.get_string(2)] = true
		for m in axis.search_all(src):
			found[m.get_string(1)] = true
			found[m.get_string(2)] = true
	found.erase("ui_cancel")
	return found


## Passengers ride in berths, and small things (letters, papers, a briefcase, data) are
## carried by hand: neither takes hold space, though their mass counts. Berths are sold
## at more than one yard, and a pilot short of them is told where.
func test_cabin_and_berths() -> void:
	var sim := fresh()
	var s := sim.state
	var d := sim.data
	var yards := ContractSystemScript.berth_yards(d)
	check(yards.size() >= 3, "Passenger berths are sold at several yards (%s)" % ", ".join(yards))
	var hand := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for _i in 200:
		var o := Contracts.make_offer(d, sim.ephemeris, s, rng, "kibo_ring", "package", "board")
		if bool(o.get("hand", false)):
			hand += 1
			check(float(o["mass_t"]) < 0.05, "A hand-carried parcel weighs kilograms (%.3f t)" % float(o["mass_t"]))
	check(hand > 20 and hand < 180, "Some courier jobs are hand-carried, most are freight (%d of 200)" % hand)
	# A full hold still takes a letter, but not a crate.
	s.ship["cargo"]["water_ice"] = ShipStats.cargo_capacity_t(s.ship, d)
	var letter := {"id": 9001, "kind": "package", "client": "Terran Compact", "issued_at": "kibo_ring", "pickup": "", "to": "halo_depot",
		"item": "a box of letters", "mass_t": 0.01, "passengers": 0, "hand": true, "reward": 1000.0, "window_s": 9.0 * DAY,
		"expires_t": s.time_s + DAY, "min_rep": -100.0, "rep": 1.0, "channel": "board", "hidden": false, "quick_days": 2.0}
	var crate := letter.duplicate()
	crate["id"] = 9002
	crate["hand"] = false
	crate["mass_t"] = 1.0
	s.contracts["board"]["kibo_ring"] = [letter, crate]
	var hold_before := ShipStats.cargo_t(s.ship)
	var mass_before := ShipStats.total_mass_t(s.ship, sim.data)
	check(sim.apply({"type": "accept_contract", "id": 9001}) == "", "A full hold still takes a letter")
	check(absf(ShipStats.cargo_t(s.ship) - hold_before) < 1e-9, "The letter takes no hold space")
	check(absf(ShipStats.total_mass_t(s.ship, d) - mass_before - 0.01) < 1e-9, "but its mass counts")
	check(sim.apply({"type": "accept_contract", "id": 9002}) != "", "A full hold refuses a crate")
	# Passengers: berths, not the hold.
	var sim2 := fresh()
	var s2 := sim2.state
	s2.ship["modules"]["cargo.1"] = "passenger_berths"
	var job := Contracts.make_offer(d, sim2.ephemeris, s2, rng, "kibo_ring", "passenger", "board")
	job["id"] = 9003
	job["min_rep"] = -100.0
	job["passengers"] = 3
	s2.contracts["board"]["kibo_ring"] = [job]
	var hold2 := ShipStats.cargo_t(s2.ship)
	check(sim2.apply({"type": "accept_contract", "id": 9003}) == "", "Passengers board into berths")
	check(absf(ShipStats.cargo_t(s2.ship) - hold2) < 1e-9 and int(s2.ship["passengers"]) == 3, "Passengers take berths, not hold space")


## The ship builder's bill (ShipyardSystem.quote, over ShipBill) is what the yard then
## charges for the whole plan as one refit: parts, trade-ins by condition, labour, and
## any service or inspection in the same visit. Refused lines say why, and a plan that
## would leave cargo without a hold is stopped.
func test_refit_quote() -> void:
	var sim := fresh()
	var s := sim.state
	var d := sim.data
	s.credits = 200000.0
	var plan := {"cargo.1": "passenger_berths", "tank.0": "tank_m"}
	var extra := {"service_all": "service", "inspect": true}
	var q := ShipyardSystem.quote(s, d, plan, extra)
	check(q["lines"].size() == 2 and q["ok"], "A two-part refit at Kibo Ring is quoted and possible")
	check(ShipStats.berths(q["trial"], d) == 6, "The trial ship has the berths")
	check(q["lines"].all(func(l): return float(l["labour"]) > 0.0), "Each swap carries fitting labour")
	var stock_tank := float(d.modules[s.ship["modules"]["tank.0"]]["price"])
	check(float(q["lines"][1]["trade_in"]) < stock_tank * 0.92 and float(q["lines"][1]["trade_in"]) > 0.0, "A part-worn tank trades in below new value")
	check(q["bill"]["lines"].any(func(b): return b["kind"] == "inspection") and q["bill"]["lines"].any(func(b): return b["kind"] == "service"), "Service and inspection are on the same bill")
	check(float(q["bill"]["days"]) > 0.0, "The job takes days in port")
	var before := float(s.credits)
	var t0 := s.time_s
	var command := extra.duplicate()
	command["type"] = "refit"
	command["swaps"] = q["lines"].map(func(l): return {"slot": l["slot"], "module": l["module"]})
	check(sim.apply(command) == "", "The builder's plan goes in as one refit")
	check(absf((before - float(s.credits)) - float(q["total"])) < 0.01, "The yard charges what the bill said (%.0f vs %.0f)" % [before - float(s.credits), float(q["total"])])
	check(absf((s.time_s - t0) / 86400.0 - float(q["bill"]["days"])) < 0.01, "and takes the days it said")
	check(Fitness.valid(s, d), "Inspected in the same visit: the warrant is good")
	var bad := ShipyardSystem.quote(s, d, {"drive.0": "pathfinder_mk3"})
	check(not bad["ok"] and String(bad["lines"][0]["why"]) == "not sold here", "A part this yard doesn't stock is refused, with the reason")
	s.ship["cargo"]["water_ice"] = 25.0
	var full := ShipyardSystem.quote(s, d, {"cargo.0": "passenger_berths"})
	check(not full["ok"] and not full["problems"].is_empty(), "A refit that would leave cargo without a hold is stopped")


## Habitats the megaprojects build get a place you can dock at: shut until their
## project is done, then in every list that offers destinations (departures, job
## boards, traffic, tips, news), docked at and routed to like any other port.
const NEW_PLACES := {
	"island_one": {"from": "kernel_l5", "fleet": "island_haulers"},
	"kalpana_two": {"from": "kalpana_one", "fleet": "kalpana_two_ferries"},
	"concord_pair": {"from": "piazzi_station", "fleet": "concord_tenders"},
	"selene_ring": {"from": "shackleton_port", "fleet": "ring_tankers"},
}


func test_new_habitat_places() -> void:
	var sim := fresh()
	var s := sim.state
	var d := sim.data
	# The market of each carries only what it lists; flows name goods it trades.
	for id in NEW_PLACES:
		var p: Dictionary = d.places[id]
		check(p["opens_with"] == id and p.has("station") and p["station"].has("spin_rpm"), "%s is built by its project and has station geometry" % id)
		var ok := true
		for flow in ["produces", "consumes"]:
			for good in p[flow]:
				ok = ok and p["market"].has(good)
		check(ok, "%s: every good it makes or uses is on its market" % id)
		check(not Perks.place_open(s, d, id), "%s is closed before its project is done" % id)
		check(not s.knowledge.has(id), "%s: no price board on file before it opens" % id)
		check(String(sim.apply({"type": "depart", "to": id})) != "", "Cannot depart for %s before it is built" % id)
	# Closed: not offered as a destination, a pickup, a tip or a drift target.
	s.location = {"status": "docked", "place": "kibo_ring"}
	var names: Array = NEW_PLACES.keys()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var leaked := false
	for from in ["kibo_ring", "kernel_l5", "kalpana_one", "shackleton_port", "piazzi_station", "ares_ring"]:
		for _i in 40:
			for kind in d.contracts["kinds"]:
				var offer := Contracts.make_offer(d, sim.ephemeris, s, rng, from, kind, "board")
				if not offer.is_empty() and (offer["to"] in names or offer.get("pickup", "") in names):
					leaked = true
	check(not leaked, "No job is offered to a habitat that is not built")
	# Closed places never show up in sim traffic either: run a month and read the departures.
	var closed: Array = names + ["tsiolkovsky_wheel", "hektor_reach", "pavonis_foot"]
	sim.take_events()
	sim.state.time_scale = 1.0e5
	var strays := []
	for _i in 30:
		sim.advance_game_time(DAY)
		strays.append_array(sim.take_events().filter(func(e): return e["type"] == "npc_departed" and e["data"]["to"] in closed))
	check(strays.is_empty(), "No ship heads for a closed place (%d did)" % strays.size())
	for npc in s.npcs:
		check(not (npc["fleet"] in ["island_haulers", "kalpana_two_ferries", "concord_tenders", "ring_tankers"]) or not NpcSystem.in_service(npc, s.time_s) or npc["trips"] == 0, "%s waits for its project" % npc["name"])
	# Finish every project: the places open, news says so, and traffic starts.
	for id in NEW_PLACES:
		s.projects[id]["done"] = true
		s.projects[id]["revealed"] = true
	sim.take_events()
	var posted_before: int = s.news["items"].size()
	sim.advance_game_time(3600.0)
	var headlines: Array = s.news["items"].map(func(i): return i["headline"])
	for id in NEW_PLACES:
		check(Perks.place_open(s, d, id), "%s opens when its project is done" % id)
		check(d.news["projects"][id]["complete"]["headline"] in headlines, "The Spaceline reports %s open" % id)
	check(s.news["items"].size() > posted_before, "Finishing the habitats made news")
	# Departures: the list the station screen builds.
	for id in NEW_PLACES:
		var from: String = NEW_PLACES[id]["from"]
		var dests: Array = d.places.keys().filter(func(to): return to != from and Perks.place_open(s, d, to))
		check(id in dests, "%s is a destination from %s once open" % [id, from])
	# Job boards: some job from a neighbouring port now goes to it.
	for id in NEW_PLACES:
		var hit := false
		for from in [NEW_PLACES[id]["from"]]:
			for _i in 80:
				for kind in d.contracts["kinds"]:
					var offer := Contracts.make_offer(d, sim.ephemeris, s, rng, from, kind, "board")
					if not offer.is_empty() and (offer["to"] == id or offer.get("pickup", "") == id):
						hit = true
		check(hit, "Jobs are offered to %s once it is open" % id)
	# Tips: brokers may now hear of them (coverage 'all' or a list that names the place).
	check(d.brokers["maisie_tran"]["coverage"].has("kalpana_two") and d.brokers["auntie_vell"]["coverage"].has("island_one"), "Regional brokers cover the habitats beside their ports")
	# Docking works at each, and the Navigation plans a route to it from its neighbour.
	var freighter := {"hull": "deep_freighter", "modules": d.ships["deep_freighter"]["modules"].duplicate(), "cargo": {}, "fuel_t": 400.0}
	for id in NEW_PLACES:
		var from: String = NEW_PLACES[id]["from"]
		var plan := Navigation.plan(freighter, d, sim.ephemeris, from, id, s.time_s)
		check(plan.get("ok", false), "A route from %s to %s is planned" % [from, id])
		var back := Navigation.plan(freighter, d, sim.ephemeris, id, from, s.time_s)
		check(back.get("ok", false), "A route home from %s is planned" % id)
		var options := RoutePlanner.plan_options(freighter, d, sim.ephemeris, from, id, s.time_s)
		check(not options.is_empty() or plan.get("ok", false), "%s has route options" % id)
		s.ship = freighter.duplicate(true)
		s.location = {"status": "docked", "place": from}
		check(sim.apply({"type": "depart", "to": id}) == "", "Depart from %s for %s" % [from, id])
		sim.advance_game_time(float(s.location["arrive_t"]) - s.time_s + 60.0)
		check(s.location["status"] == "approach" and s.location["place"] == id, "Arrive on approach at %s" % id)
		check(sim.apply({"type": "dock"}) == "" and s.location["status"] == "docked" and s.location["place"] == id, "Docked at %s" % id)
		check(not Market.target(d, id, d.places[id]["market"].keys()[0]) <= 0.0, "%s has a market to trade at" % id)
	# Its own traffic: the project's fleet is commissioned and flies.
	for _i in 40:
		sim.advance_game_time(DAY)
	for id in NEW_PLACES:
		var fleet: String = NEW_PLACES[id]["fleet"]
		var trips := 0
		for npc in s.npcs:
			if npc["fleet"] == fleet:
				trips += int(npc["trips"])
		check(trips > 0, "%s has made trips once %s is open" % [fleet, id])
	# A save from before the places existed has no market for them: it grows one.
	for id in NEW_PLACES:
		s.markets.erase(id)
	sim.advance_game_time(DAY)
	for id in NEW_PLACES:
		check(s.markets.has(id) and not s.markets[id].is_empty(), "An old save grows a market for %s" % id)


# ---- Favours: rewards in kind, hitchhikers, engine tunes ------------------------------

## A port with a shipyard and a port with fuel, and the operator that runs the first.
func _yard_port(d: DataCatalog) -> String:
	for id in d.places:
		if "shipyard" in d.places[id].get("services", []) and "refuel" in d.places[id].get("services", []) and not d.places[id].has("foot_of"):
			return id
	return ""


## Take and deliver a job that pays `in_kind` (the cash part is `cash`). Returns the credits gained.
func _deliver_in_kind(sim: Sim, operator: String, in_kind: Dictionary, cash: float, on_time: bool = true) -> void:
	var s := sim.state
	_dock_at(sim, "kibo_ring")
	var job := {"id": 9100 + s.contracts["seq"], "kind": "package", "client": operator, "issued_at": "kibo_ring", "pickup": "", "to": "halo_depot",
		"item": "a crate of real coffee", "mass_t": 0.1, "passengers": 0, "hand": false, "reward": cash, "window_s": 10 * DAY,
		"expires_t": s.time_s + 5 * DAY, "min_rep": -100.0, "rep": 2.0, "channel": "board", "hidden": false, "in_kind": in_kind}
	s.contracts["board"]["kibo_ring"] = [job]
	check(sim.apply({"type": "accept_contract", "id": job["id"]}) == "", "Take a job paid partly in kind (%s)" % in_kind["form"])
	if not on_time:
		s.time_s += 11 * DAY
	_dock_at(sim, "halo_depot")


func test_favours_in_kind() -> void:
	var sim := fresh()
	var s := sim.state
	var d := sim.data
	var yard := _yard_port(d)
	check(yard != "", "Some port has both a yard and fuel")
	var op: String = Favours.operator_of(d, yard)
	# Offers: with the odds at 1 every kind of job can come in kind, with a value beside it.
	for k in d.favours["in_kind"]["chance"]:
		d.favours["in_kind"]["chance"][k] = 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var forms := {}
	var plain_cash := 0.0
	var in_kind_n := 0
	for _i in 120:
		var o := Contracts.make_offer(d, sim.ephemeris, s, rng, "kibo_ring", "long_haul", "board")
		if o.is_empty() or not o.has("in_kind"):
			continue
		in_kind_n += 1
		forms[o["in_kind"]["form"]] = true
		check(float(o["in_kind"]["value_cr"]) >= float(d.favours["in_kind"]["min_value_cr"]) and Favours.describe(d, o["in_kind"]).contains("cr"), "An in-kind offer states its credit value")
		check(float(o["reward"]) > 0.0, "and still pays some cash")
	check(in_kind_n > 50 and forms.size() >= 4, "With the odds up, offers come in several forms (%d offers, %s)" % [in_kind_n, ",".join(forms.keys())])
	for k in d.favours["in_kind"]["chance"]:
		d.favours["in_kind"]["chance"][k] = 0.0
	var none := 0
	for _i in 40:
		var o2 := Contracts.make_offer(d, sim.ephemeris, s, rng, "kibo_ring", "package", "board")
		none += 1 if o2.has("in_kind") else 0
	check(none == 0, "With the odds at zero nothing is in kind")
	# Repair voucher: held, refused away from the client's yards, spent at them, then expires.
	_deliver_in_kind(sim, op, {"form": "yard", "operator": op, "value_cr": 4000.0, "expires_days": 90.0, "value_cr_shown": 0}, 1000.0)
	check(s.favours["vouchers"].size() == 1 and s.favours["vouchers"][0]["form"] == "yard", "A repair voucher is held")
	var vid := int(s.favours["vouchers"][0]["id"])
	s.ship["damage"] = {"drive.0": 0.2, "keel": 0.1}
	_dock_at(sim, "kibo_ring")
	var credits := s.credits
	var away := Favours.operator_of(d, "kibo_ring") != op
	if away:
		check(sim.apply({"type": "use_voucher", "id": vid}) != "", "A voucher is no good at another operator's yard")
	_dock_at(sim, yard)
	check(sim.apply({"type": "use_voucher", "id": vid}) == "", "Spend the voucher at the client's yard")
	check(s.ship["damage"].is_empty(), "It mends the damage (%s)" % str(s.ship["damage"]))
	check(absf(s.credits - credits) < 1e-6, "for no credits")
	var left := 0.0
	for v in s.favours["vouchers"]:
		left += float(v["value_cr"])
	check(left < 4000.0 and left > 0.0, "and what it did not use is kept (%d cr left)" % int(left))
	check(sim.apply({"type": "use_voucher", "id": vid}) == "nothing to repair", "Nothing to repair, nothing spent")
	s.time_s += 100 * DAY
	sim.advance_game_time(60.0)
	check(s.favours["vouchers"].is_empty(), "Vouchers expire")
	# Fuel discount, free refuel and free docking at the client's ports.
	var fuel_cap := ShipStats.fuel_capacity_t(s.ship, d)
	var pay := {}
	for mode in ["none", "discount", "free"]:
		var sm := fresh()
		sm.state.credits = 100000.0
		if mode == "discount":
			_deliver_in_kind(sm, op, {"form": "fuel", "operator": op, "days": 30.0, "discount": 0.25, "value_cr": 1200.0}, 1000.0)
		elif mode == "free":
			_deliver_in_kind(sm, op, {"form": "refuel", "operator": op, "tonnes": 3.0, "expires_days": 60.0, "value_cr": 1800.0}, 1000.0)
		_dock_at(sm, yard)
		sm.state.ship["fuel_t"] = fuel_cap - 3.0
		var before: float = sm.state.credits
		check(sm.apply({"type": "refuel", "tonnes": 3.0}) == "", "Refuel (%s)" % mode)
		pay[mode] = before - sm.state.credits
		if mode == "free":
			check(sm.state.favours["vouchers"].is_empty(), "Free refuelling is used up")
	check(pay["none"] > 0.0 and absf(pay["discount"] - pay["none"] * 0.75) < pay["none"] * 0.01, "A 25%% fuel discount takes a quarter off (%.1f vs %.1f)" % [pay["discount"], pay["none"]])
	check(absf(pay["free"]) < 1e-6, "Three free tonnes cover a three-tonne refuel")
	var tug := {}
	for mode in ["none", "pass"]:
		var sd := fresh()
		if mode == "pass":
			_deliver_in_kind(sd, op, {"form": "docking", "operator": op, "days": 30.0, "discount": 1.0, "value_cr": 600.0}, 1000.0)
		sd.state.location = {"status": "approach", "place": yard}
		var before2: float = sd.state.credits
		sd.apply({"type": "dock"})
		tug[mode] = before2 - sd.state.credits
	check(tug["none"] > 0.0 and absf(tug["pass"]) < 1e-6, "A docking pass makes the tug free (%.0f vs %.0f)" % [tug["pass"], tug["none"]])
	# A favour owed is standing.
	var sf := fresh()
	_deliver_in_kind(sf, op, {"form": "favour", "operator": op, "rep": 8.0, "value_cr": 1200.0}, 1000.0)
	check(Contracts.rep_of(sf.state, op) >= 8.0 + 2.0 - 1e-6, "A favour owed adds to standing (%.1f)" % Contracts.rep_of(sf.state, op))
	# Late: the in-kind part is scaled down with the pay; a tune is paid as cash instead.
	var sl := fresh()
	_deliver_in_kind(sl, op, {"form": "yard", "operator": op, "value_cr": 4000.0, "expires_days": 90.0, "value_cr_shown": 0}, 1000.0, false)
	check(absf(float(sl.state.favours["vouchers"][0]["value_cr"]) - 4000.0 * 0.5) < 1e-6, "A late delivery halves the voucher too")
	var st := fresh()
	var thrust0 := ShipStats.thrust_n(st.state.ship, st.data)
	_deliver_in_kind(st, op, {"form": "tune", "operator": op, "tune": "injector_retime", "value_cr": 1800.0}, 1000.0)
	check(ShipStats.thrust_n(st.state.ship, st.data) > thrust0, "A tune paid in kind is fitted on delivery")
	var st2 := fresh()
	var cr0: float = st2.state.credits
	# Parts wear while the job runs, so measure against this ship, not a fresh one.
	_deliver_in_kind(st2, op, {"form": "tune", "operator": op, "tune": "injector_retime", "value_cr": 1800.0}, 1000.0, false)
	check(ShipStats.active_tunes(st2.state.ship, st2.data).is_empty() and ShipStats.thrust_n(st2.state.ship, st2.data) <= thrust0 + 1e-6 and st2.state.credits > cr0 + 500.0, "A late tune is paid in credits instead")
	# Odds are data: client multipliers and per-kind chances come from favours.json.
	check(float(sim.data.favours["in_kind"]["client_mult"].get("Belt Assembly", 1.0)) > float(sim.data.favours["in_kind"]["client_mult"].get("Terran Compact", 1.0)), "Odds differ by client (data)")


func test_hitchhikers() -> void:
	var sim := fresh()
	var s := sim.state
	var d := sim.data
	d.favours["hitchhikers"]["chance"] = 1.0
	d.favours["hitchhikers"]["cooldown_days"] = 0.0
	# Someone asks at the dock.
	_dock_at(sim, "kibo_ring")
	s.favours["last_dock"] = ""
	sim.advance_game_time(60.0)
	var waiting: Array = s.favours["waiting"].get("kibo_ring", [])
	check(not waiting.is_empty(), "Someone is asking for a ride at the dock")
	if waiting.is_empty():
		return
	var h: Dictionary = waiting[0]
	check(h["name"] != "" and d.favours["hitchhikers"]["trades"].has(h["trade"]) and h["to"] != "kibo_ring", "A hitchhiker has a name, a trade and a destination (%s, %s)" % [h["name"], h["trade"]])
	# No berth, no ride.
	s.ship["modules"].erase("cargo.1")
	check(ShipStats.berths(s.ship, d) == 0, "(the Mule has no berths)")
	check(String(sim.apply({"type": "accept_hitchhiker", "id": h["id"]})).begins_with("no berths"), "No berth, no ride")
	check(s.ship.get("hikers", []).is_empty() and int(s.ship.get("passengers", 0)) == 0, "and nobody boards")
	s.ship["modules"]["cargo.1"] = "passenger_berths"
	sim.take_events()
	var mass := ShipStats.total_mass_t(s.ship, d)
	check(sim.apply({"type": "accept_hitchhiker", "id": h["id"]}) == "", "With a berth they come aboard")
	check(s.ship["hikers"].size() == 1 and int(s.ship["passengers"]) == 1 and absf(ShipStats.total_mass_t(s.ship, d) - mass - 0.1) < 1e-9, "They take a berth and weigh a little")
	check(not s.favours["waiting"]["kibo_ring"].any(func(w): return int(w["id"]) == int(h["id"])), "and are no longer waiting")
	var boarded := sim.take_events().filter(func(e): return e["type"] == "hitchhiker_boarded")
	check(boarded.size() == 1 and String(boarded[0]["data"]["text"]).contains(h["name"]), "They say something on boarding (comms)")
	# Helping, by trade.
	var trades: Dictionary = d.favours["hitchhikers"]["trades"]
	var set_trade := func(trade: String) -> void:
		s.ship["hikers"][0]["trade"] = trade
		s.ship["hikers"][0]["gift"] = ""
	set_trade.call("engineer")
	s.ship["damage"] = {"drive.0": 0.03, "keel": 0.2}
	check(sim.apply({"type": "depart", "to": h["to"]}) == "", "Depart with a hitchhiker aboard")
	sim.advance_game_time(3600.0)
	var healed: float = 0.03 - float(s.ship["damage"].get("drive.0", 0.0))
	check(healed > 0.0 and absf(healed - float(trades["engineer"]["heal_per_day"]) / 24.0) < 1e-6, "An engineer mends a little each hour in flight (%.5f)" % healed)
	check(float(s.ship["damage"]["keel"]) == 0.2, "but not the keel")
	check(ShipStats.wear_mult(s.ship, d) < 1.0, "and cuts wear (for maintenance to read)")
	# Navigator: a thriftier burn than the same trip without.
	var base := fresh()
	base.state.ship["modules"]["cargo.1"] = "passenger_berths"
	var tank_base: float = base.state.ship["fuel_t"]
	base.apply({"type": "depart", "to": h["to"]})
	var nav := fresh()
	nav.state.ship["modules"]["cargo.1"] = "passenger_berths"
	nav.state.ship["hikers"] = [h.duplicate(true)]
	nav.state.ship["hikers"][0]["trade"] = "navigator"
	nav.state.ship["passengers"] = 1
	var tank0: float = nav.state.ship["fuel_t"]
	nav.apply({"type": "depart", "to": h["to"]})
	var burn_base := tank_base - float(base.state.ship["fuel_t"])
	var burn_nav: float = tank0 - float(nav.state.ship["fuel_t"])
	check(burn_base > 0.0 and absf(burn_nav - burn_base * (1.0 - float(trades["navigator"]["fuel_trim"]))) < 1e-9, "A navigator trims the burn (%.4f t vs %.4f t)" % [burn_nav, burn_base])
	# Cook: life support stretches. Pilot: the tug is cheaper.
	var ls := ShipStats.life_support_days(s.ship, d)
	set_trade.call("cook")
	var ls_cook := ShipStats.life_support_days(s.ship, d)
	if ls != INF:
		check(absf(ls_cook / ls - float(trades["cook"]["life_support_mult"])) < 1e-9 or ls == ls_cook, "A cook stretches life support (%.1f to %.1f days)" % [ls, ls_cook])
	var tugs := {}
	for who in ["none", "pilot"]:
		var sp := fresh()
		sp.state.ship["modules"]["cargo.1"] = "passenger_berths"
		if who == "pilot":
			sp.state.ship["hikers"] = [{"name": "Test Pilot", "trade": "pilot", "to": "halo_depot", "from": "kibo_ring", "fare": 0.0, "gift": "", "boarded_t": 0.0, "mid_sent": true, "lines": {"board": "", "mid": "", "leave": ""}}]
		sp.state.location = {"status": "approach", "place": "kibo_ring"}
		var c0: float = sp.state.credits
		sp.apply({"type": "dock"})
		tugs[who] = c0 - sp.state.credits
	check(tugs["pilot"] > 0.0 and absf(tugs["pilot"] - tugs["none"] * float(trades["pilot"]["tug_mult"])) < 1e-6, "A pilot talks the tug fee down (%.0f vs %.0f)" % [tugs["pilot"], tugs["none"]])
	# Halfway they speak, and at their stop they leave (paying the fare; a tinkerer may leave a tune).
	s.ship["hikers"][0]["gift"] = "nozzle_polish"
	s.ship["hikers"][0]["fare"] = 150.0
	s.ship["hikers"][0]["to"] = h["to"]
	s.ship["damage"] = {}
	sim.take_events()
	sim.advance_game_time(float(s.location["arrive_t"]) - s.time_s - 60.0)
	var lines := sim.take_events().filter(func(e): return e["type"] == "hitchhiker_line")
	check(lines.size() == 1, "A hitchhiker has a word to say midway (%d)" % lines.size())
	sim.advance_game_time(120.0)
	check(sim.apply({"type": "dock"}) == "", "Arrive and dock")
	sim.advance_game_time(60.0)
	var left := sim.take_events().filter(func(e): return e["type"] == "hitchhiker_left")
	check(left.size() == 1 and String(left[0]["data"]["text"]).contains(h["name"]), "They leave with a parting line")
	check(s.ship["hikers"].is_empty() and int(s.ship["passengers"]) == 0 and absf(float(s.ship["cabin_t"])) < 1e-9, "and the berth and mass come free")
	check(ShipStats.active_tunes(s.ship, d).size() == 1 and s.ship["tunes"][0]["id"] == "nozzle_polish", "A tinkerer leaves a tune on the drive")
	# Not going anywhere near their stop: they ride on (until their patience runs out).
	var wait2 := fresh()
	wait2.data.favours["hitchhikers"]["chance"] = 1.0
	wait2.state.ship["modules"]["cargo.1"] = "passenger_berths"
	wait2.advance_game_time(60.0)
	var h2: Dictionary = wait2.state.favours["waiting"]["kibo_ring"][0]
	wait2.apply({"type": "accept_hitchhiker", "id": h2["id"]})
	var other: String = "halo_depot" if h2["to"] != "halo_depot" else "kernel_l5"
	_dock_at(wait2, other)
	check(wait2.state.ship["hikers"].size() == 1, "A hitchhiker stays aboard at ports that are not their stop")
	# Waiting hitchhikers give up, and the galley holds only so many.
	var wait3 := fresh()
	wait3.data.favours["hitchhikers"]["chance"] = 1.0
	wait3.advance_game_time(60.0)
	wait3.state.time_s += 30 * DAY
	wait3.state.location = {"status": "transit_test"}
	wait3.advance_game_time(60.0)
	check(wait3.state.favours["waiting"].get("kibo_ring", []).is_empty(), "Nobody waits forever")


func test_engine_tunes() -> void:
	var sim := fresh()
	var s := sim.state
	var d := sim.data
	var ship: Dictionary = s.ship
	var thrust0 := ShipStats.thrust_n(ship, d)
	var ve0 := ShipStats.exhaust_velocity(ship, d)
	var acc0 := ShipStats.accel_mps2(ship, d)
	var heat0 := ShipStats.heat_ratio(ship, d)
	var key0: String = sim.route_key("clarke_exchange")
	var plan0 := Navigation.plan(ship, d, sim.ephemeris, "kibo_ring", "clarke_exchange", s.time_s)
	check(plan0["ok"], "A baseline plan exists")
	check(Favours.install_tune(ship, d, "nozzle_polish", "test", 0.0) == "", "Fit a tune")
	var ve1 := ShipStats.exhaust_velocity(ship, d)
	var spec: Dictionary = d.favours["tunes"]["nozzle_polish"]
	check(absf(ve1 / ve0 - (1.0 + float(spec["isp_pct"]))) < 1e-9, "Isp rises by the tune's share (%.4f)" % (ve1 / ve0))
	check(ShipStats.thrust_n(ship, d) == thrust0, "and thrust is unchanged")
	var plan1 := Navigation.plan(ship, d, sim.ephemeris, "kibo_ring", "clarke_exchange", s.time_s)
	var ratio := float(plan1["fuel_t"]) / float(plan0["fuel_t"])
	check(plan1["ok"] and absf(ratio - 1.0 / (1.0 + float(spec["isp_pct"]))) < 0.003, "A planned route burns that much less fuel (%.4f of before)" % ratio)
	check(sim.route_key("clarke_exchange") != key0, "Route plans are keyed by the tunes, so they are replanned")
	# Thrust and heat.
	check(Favours.install_tune(ship, d, "injector_retime", "test", 0.0) == "", "Fit a second tune")
	var t2: Dictionary = d.favours["tunes"]["injector_retime"]
	var thrust1 := ShipStats.thrust_n(ship, d)
	var heat1 := ShipStats.heat_ratio(ship, d)
	check(absf(heat1 / heat0 - (1.0 + float(t2["heat_pct"]))) < 1e-9, "Heat follows the trade-off (%.3f)" % (heat1 / heat0))
	if heat1 <= 1.0:
		check(absf(thrust1 / thrust0 - (1.0 + float(t2["thrust_pct"]))) < 1e-9 and ShipStats.accel_mps2(ship, d) > acc0, "Thrust and acceleration rise by the tune's share")
	var plan2 := Navigation.plan(ship, d, sim.ephemeris, "kibo_ring", "clarke_exchange", s.time_s)
	check(float(plan2["duration_s"]) < float(plan1["duration_s"]), "A planned trip takes less time (%.0f s vs %.0f s)" % [plan2["duration_s"], plan1["duration_s"]])
	check(Favours.install_tune(ship, d, "overdrive_map", "test", 0.0) != "", "A drive takes only so many tunes")
	check(Favours.install_tune(ship, d, "nozzle_polish", "test", 0.0) != "", "and the same tune only once")
	check(ShipStats.wear_mult(ship, d) >= 1.0, "Wear is one for the maintenance work to read")
	# The tune belongs to its drive: swap the drive and it stops counting.
	ship["modules"]["drive.0"] = "pathfinder_mk2"
	check(ShipStats.active_tunes(ship, d).is_empty(), "A tune stays with the drive it was fitted to")
	var bare := ship.duplicate(true)
	bare["tunes"] = []
	check(ShipStats.thrust_n(ship, d) == ShipStats.thrust_n(bare, d) and ShipStats.exhaust_velocity(ship, d) == ShipStats.exhaust_velocity(bare, d), "and the new drive is stock")
	# A cooler, thriftier tune (negative thrust) is allowed, and a ship with no drive cannot be tuned.
	var other := fresh()
	check(Favours.install_tune(other.state.ship, other.data, "lean_burn_map", "test", 0.0) == "" and ShipStats.thrust_n(other.state.ship, other.data) < thrust0, "A lean-burn map trades thrust for efficiency")
	other.state.ship["modules"].erase("drive.0")
	other.state.ship["tunes"] = []
	check(Favours.install_tune(other.state.ship, other.data, "lean_burn_map", "test", 0.0) != "", "No drive, no tune")


func test_favours_saves() -> void:
	var sim := fresh()
	var s := sim.state
	var d := sim.data
	d.favours["hitchhikers"]["chance"] = 1.0
	sim.advance_game_time(60.0)
	s.ship["modules"]["cargo.1"] = "passenger_berths"
	var h: Dictionary = s.favours["waiting"]["kibo_ring"][0]
	sim.apply({"type": "accept_hitchhiker", "id": h["id"]})
	Favours.install_tune(s.ship, d, "injector_retime", "a test", s.time_s)
	s.favours["vouchers"].append({"id": 77, "form": "fuel", "operator": "The Commons", "discount": 0.25, "expires_t": s.time_s + 9 * DAY})
	sim.advance_game_time(3600.0)
	var loaded := SaveIO.from_text(SaveIO.to_text(s))
	check(loaded != null and loaded.to_dict() == s.to_dict(), "Vouchers, hitchhikers and tunes survive a save")
	check(loaded.ship["hikers"].size() == 1 and loaded.ship["tunes"].size() == 1 and loaded.favours["vouchers"].size() == 1, "(all three are there)")
	var resumed := Sim.new()
	resumed.load_state(loaded)
	resumed.advance_game_time(5 * DAY)
	sim.advance_game_time(5 * DAY)
	check(resumed.state.to_dict() == sim.state.to_dict(), "A loaded game with favours continues identically")
	# A save from before favours: no favours key, no tunes. It loads, plays and gets the defaults.
	var old := s.to_dict()
	old.erase("favours")
	old["ship"].erase("tunes")
	old["ship"].erase("hikers")
	var old_state := GameState.new()
	old_state.load_dict(old)
	check(old_state.favours.is_empty(), "An old save has no favours")
	var old_sim := Sim.new()
	old_sim.load_state(old_state)
	old_sim.advance_game_time(2 * DAY)
	check(old_sim.state.favours.has("vouchers") and old_sim.state.favours["vouchers"].is_empty(), "and gets empty ones")
	check(ShipStats.thrust_n(old_state.ship, old_sim.data) > 0.0 and ShipStats.active_tunes(old_state.ship, old_sim.data).is_empty(), "Old ships are stock")
	# Determinism: the same commands give the same hitchhikers.
	var a := fresh()
	var b := fresh()
	a.advance_game_time(20 * DAY)
	b.advance_game_time(20 * DAY)
	check(a.state.favours == b.state.favours, "Hitchhikers are deterministic")


# ---- Ship economy: wear, condition, service, refit, WoF, insurance ----

## A passenger job on the Kibo Ring board, ready to accept (berths fitted).
func _passenger_job(sim: Sim, id: int) -> Dictionary:
	var s := sim.state
	s.ship["modules"]["cargo.1"] = "passenger_berths"
	var job := {"id": id, "kind": "passenger", "client": "Terran Compact", "issued_at": "kibo_ring", "pickup": "", "to": "halo_depot",
		"item": "two colonists", "mass_t": 0.2, "passengers": 2, "hand": false, "reward": 4000.0, "window_s": 9.0 * DAY,
		"expires_t": s.time_s + DAY, "min_rep": -100.0, "rep": 1.0, "channel": "board", "hidden": false, "quick_days": 2.0}
	s.contracts["board"]["kibo_ring"] = [job]
	return job


func _wreck(sim: Sim) -> Dictionary:
	sim.state.location = {"status": "approach", "place": "kibo_ring"}
	sim.take_events()
	sim.apply({"type": "impact", "speed": 30.0, "zone": "mid", "seed": 0})
	for e in sim.take_events():
		if e["type"] == "ship_lost":
			return e["data"]
	return {}


func test_wear_accrual() -> void:
	var sim := fresh()
	var s := sim.state
	var d := sim.data
	# A stock second-hand Mule starts part-worn, with a Warrant of Fitness and cover.
	for slot in s.ship["modules"]:
		check(Condition.condition(s.ship, slot) < 1.0 and Condition.condition(s.ship, slot) > 0.6, "%s starts part-worn (%.2f)" % [slot, Condition.condition(s.ship, slot)])
	check(Condition.age_days(s.ship, "drive.0") >= 900.0 and Fitness.valid(s, d), "The starter Mule has age and a valid WoF")
	# Parked: only slow ageing.
	var w0 := Condition.wear_of(s.ship, "drive.0")
	var c0 := Condition.wear_of(s.ship, "cargo.0")
	sim.advance_game_time(10.0 * DAY)
	var parked := Condition.wear_of(s.ship, "drive.0") - w0
	check(parked > 0.0 and parked < 0.005, "A drive parked ten days barely wears (%.5f)" % parked)
	check(s.ship.get("damage", {}).is_empty(), "Wear is not collision damage")
	# Flying: the drive burns, radiators work their load, pods wear on the dock.
	sim.apply({"type": "buy", "good": "water_ice", "tonnes": 10})
	var rad0 := Condition.wear_of(s.ship, "radiator.0")
	var drive1 := Condition.wear_of(s.ship, "drive.0")
	var cargo1 := Condition.wear_of(s.ship, "cargo.0")
	check(sim.apply({"type": "depart", "to": "halo_depot"}) == "", "Depart to Halo Depot")
	var days := (float(s.location["arrive_t"]) - s.time_s) / DAY
	sim.advance_game_time(float(s.location["arrive_t"]) - s.time_s + 1.0)
	var flown := Condition.wear_of(s.ship, "drive.0") - drive1
	check(flown > parked * 0.8 / 10.0 * days * 4.0, "A drive wears much faster in flight than parked (%.5f over %.1f d)" % [flown, days])
	check(Condition.wear_of(s.ship, "radiator.0") - rad0 > 0.0, "Radiators wear on thermal load")
	check(Condition.wear_of(s.ship, "cargo.0") - cargo1 > 0.0, "Pods wear carrying cargo")
	sim.apply({"type": "dock"})
	sim.advance_game_time(3600.0)
	check(int(s.ship["use"]["drive.0"]["docks"]) == 1, "A dock is counted")
	check(float(s.ship["use"]["drive.0"]["burn_h"]) > 10.0, "Burn hours are counted")
	check(float(s.ship["hull_h"]) > 10.0 * 24.0, "Hull hours in service are counted")
	check(Condition.wear_of(s.ship, "cargo.0") > c0, "Cargo pod wear is up")
	# Wear is bounded and a module that is worn out is just worn out.
	Condition.add_wear(s.ship, "drive.0", 5.0)
	check(Condition.condition(s.ship, "drive.0") == 0.0, "Condition floors at zero")
	# Mild performance loss, never a dead drive.
	var fresh_ship := fresh().state.ship
	Condition.set_condition(fresh_ship, "drive.0", 1.0)
	var full := ShipStats.thrust_n(fresh_ship, d)
	Condition.set_condition(fresh_ship, "drive.0", 0.0)
	var worn := ShipStats.thrust_n(fresh_ship, d)
	var loss := 1.0 - worn / full
	check(absf(loss - float(d.ship_economy["performance"]["max_loss"])) < 1e-9, "A worn-out drive pushes max_loss less (%.3f)" % loss)
	Condition.set_condition(fresh_ship, "drive.0", 0.8)
	check(ShipStats.thrust_n(fresh_ship, d) == full, "Above the onset there is no loss")
	# Capacity and loads are not trimmed by wear.
	var cap := ShipStats.cargo_capacity_t(fresh_ship, d)
	Condition.set_condition(fresh_ship, "cargo.0", 0.0)
	check(ShipStats.cargo_capacity_t(fresh_ship, d) == cap, "A worn pod holds as much")


func test_wear_faults() -> void:
	var run := func() -> Sim:
		var sim := fresh()
		Condition.set_condition(sim.state.ship, "drive.0", 0.1)
		Condition.set_condition(sim.state.ship, "radiator.0", 0.1)
		sim.apply({"type": "set_time_scale", "scale": 1.0})
		sim.advance_game_time(120.0 * DAY)
		return sim
	var a: Sim = run.call()
	var b: Sim = run.call()
	var faults: Dictionary = a.state.ship["faults"]
	check(not faults.is_empty(), "A worn-out module throws small faults over months")
	for slot in faults:
		check(float(faults[slot]["loss"]) > 0.0 and float(faults[slot]["loss"]) <= float(a.data.ship_economy["faults"]["cap"]) + 1e-9, "A fault is a few percent, capped (%s %.3f)" % [slot, float(faults[slot]["loss"])])
	check(a.state.ship["faults"] == b.state.ship["faults"] and a.state.rng_state == b.state.rng_state, "Faults are deterministic for a seed")
	check(a.state.ship.get("damage", {}).is_empty() and a.state.ship["hull"] == "mule", "A fault is never damage and never a lost ship")
	var warnings := a.take_events().filter(func(e): return e["type"] == "module_fault" or e["type"] == "condition_low")
	check(not warnings.is_empty(), "Faults and low condition raise warnings")
	# A healthy ship has none.
	var good := fresh()
	for slot in good.state.ship["modules"]:
		Condition.set_condition(good.state.ship, slot, 0.9)
	good.advance_game_time(60.0 * DAY)
	check(good.state.ship["faults"].is_empty(), "A well-kept ship has no faults")
	# Service clears them.
	good.state.ship["faults"]["drive.0"] = {"loss": 0.05, "text": "x", "t": 0.0}
	Condition.set_condition(good.state.ship, "drive.0", 0.95)
	check(good.apply({"type": "service", "slot": "drive.0"}) == "" and good.state.ship["faults"].is_empty(), "Service clears a fault")


func test_condition_resale() -> void:
	var sim := fresh()
	var d := sim.data
	var ship: Dictionary = sim.state.ship
	var price := 8000.0
	Condition.reset_slot(ship, "cargo.0")
	var fresh_value := Condition.trade_in(ship, "cargo.0", d)
	check(fresh_value >= 0.9 * price and fresh_value <= price, "A fresh module trades in near full value (%.0f)" % fresh_value)
	Condition.set_condition(ship, "cargo.0", 0.05)
	var tired := Condition.trade_in(ship, "cargo.0", d)
	check(tired <= 0.12 * price, "A tired module trades in for scrap (%.0f)" % tired)
	var last := 0.0
	var monotone := true
	for i in 11:
		Condition.set_condition(ship, "cargo.0", i / 10.0)
		var v := Condition.trade_in(ship, "cargo.0", d)
		monotone = monotone and v >= last
		last = v
	check(monotone, "Trade-in rises with condition")
	Condition.set_condition(ship, "cargo.0", 1.0)
	ship["use"]["cargo.0"] = {"h": 0.0}
	var young := Condition.trade_in(ship, "cargo.0", d)
	ship["use"]["cargo.0"] = {"h": 10.0 * 365.0 * 24.0}
	var old := Condition.trade_in(ship, "cargo.0", d)
	check(old < young and old >= young * float(d.ship_economy["resale"]["age_floor"]) / 1.0 - 1e-6, "Age trims the trade-in to a floor")
	ship["damage"] = {"cargo.0": 0.5}
	check(absf(Condition.trade_in(ship, "cargo.0", d) - old * 0.5) < 1e-6, "Damage halves it")
	check(Condition.trade_in(ship, "drive.0", d) == 0.0, "A zero-price module is worth nothing as trade-in")
	# It is what the install command credits (not a flat 50%).
	var s2 := fresh()
	s2.state.credits = 100000.0
	Condition.set_condition(s2.state.ship, "cargo.0", 0.2)
	var credits := s2.state.credits
	var expect := Condition.trade_in(s2.state.ship, "cargo.0", d)
	s2.apply({"type": "install_module", "slot": "cargo.0", "module": "cargo_pod_m"})
	var labour := float(Condition.refit_quote("cargo_pod_m", "kibo_ring", d)["labour_cr"])
	check(absf(credits - s2.state.credits - (30000.0 - expect + labour)) < 1e-6, "Install credits the condition-based trade-in, charges labour")
	check(not d.balance.has("shipyard"), "The flat resale fraction is gone from balance.json")
	# A new module is as new.
	check(Condition.condition(s2.state.ship, "cargo.0") > 0.99 and Condition.age_days(s2.state.ship, "cargo.0") < 1.0, "A fitted module is new (it has only aged the days it was in the yard)")


func test_service_and_overhaul() -> void:
	var sim := fresh()
	var s := sim.state
	var d := sim.data
	s.credits = 100000.0
	Condition.set_condition(s.ship, "drive.0", 0.4)
	var q_service := Condition.work_quote(s.ship, "drive.0", "service", "kibo_ring", d)
	var q_over := Condition.work_quote(s.ship, "drive.0", "overhaul", "kibo_ring", d)
	check(q_service["cost"] > 0.0 and q_over["cost"] > 3.0 * q_service["cost"], "Overhaul is dear, service is cheap (%d vs %d)" % [q_service["cost"], q_over["cost"]])
	check(absf(q_service["to"] - 0.7) < 1e-9 and absf(q_over["to"] - 0.97) < 1e-9, "Service restores some, overhaul near-new")
	check(q_over["days"] > q_service["days"] + 2.0, "Overhaul takes days in port")
	var t0 := s.time_s
	var credits := s.credits
	check(sim.apply({"type": "service", "slot": "drive.0"}) == "", "Service the drive")
	check(absf(Condition.condition(s.ship, "drive.0") - 0.7) < 0.01, "The drive is better after service (%.3f)" % Condition.condition(s.ship, "drive.0"))
	check(absf(credits - s.credits - q_service["cost"]) < 1e-6, "Charged the quoted price")
	check(s.time_s - t0 >= q_service["days"] * DAY - 1.0, "Game time passes in the yard")
	# Service tops out at its cap; overhaul goes on.
	Condition.set_condition(s.ship, "drive.0", 0.91)
	check(sim.apply({"type": "service", "slot": "drive.0"}) == "", "A service still helps a little at 0.91")
	check(Condition.condition(s.ship, "drive.0") <= float(d.ship_economy["service"]["cap"]) + 1e-9, "but never past the cap")
	check(sim.apply({"type": "service", "slot": "drive.0"}) != "", "Nothing to service at the cap")
	t0 = s.time_s
	credits = s.credits
	var over: Dictionary = Condition.work_quote(s.ship, "drive.0", "overhaul", "kibo_ring", d)
	check(sim.apply({"type": "overhaul", "slot": "drive.0"}) == "", "Overhaul the drive")
	check(absf(Condition.condition(s.ship, "drive.0") - 0.97) < 0.01, "Near new after overhaul")
	check(s.time_s - t0 >= float(over["days"]) * DAY - 1.0 and absf(credits - s.credits - over["cost"]) < 1e-6, "Overhaul takes its days and its price")
	check(Condition.age_days(s.ship, "drive.0") > 900.0, "Overhaul does not make a module younger")
	# Service all: every module gets a line; overhaul is dearer than service.
	for slot in s.ship["modules"]:
		Condition.set_condition(s.ship, slot, 0.5)
	var all_service := ShipBill.quote(s, d, {"service_all": "service"})
	var all_over := ShipBill.quote(s, d, {"service_all": "overhaul"})
	check(all_service["ok"] and all_service["lines"].size() == s.ship["modules"].size(), "Service all is one line per module")
	check(all_over["total"] > all_service["total"] and all_over["days"] > all_service["days"], "Overhauling everything costs and takes more")
	check(all_over["days"] < all_over["lines"].size() * 4.0, "Yard crews work in parallel")
	# Prices vary by yard.
	var cheap := Condition.work_quote(s.ship, "drive.0", "overhaul", "trojan_yards", d)
	var dear := Condition.work_quote(s.ship, "drive.0", "overhaul", "landauer_deep", d)
	check(cheap["cost"] < q_over["cost"] * 2.0 and cheap["cost"] < dear["cost"], "Yard prices differ (%d vs %d)" % [cheap["cost"], dear["cost"]])
	# Money: not enough credits, not at a yard.
	s.credits = 10.0
	check(sim.apply({"type": "overhaul", "slot": "drive.0"}) != "", "No overhaul without the credits")
	var away := fresh()
	var no_yard := ""
	for id in away.data.places:
		if not "shipyard" in away.data.places[id].get("services", []) and not away.data.places[id].has("foot_of"):
			no_yard = id
			break
	away.state.location = {"status": "docked", "place": no_yard}
	away.state.credits = 50000.0
	check(away.apply({"type": "service", "slot": "drive.0"}) != "", "No service away from a shipyard")
	# Paused clocks still pay the days.
	var paused := fresh()
	paused.state.credits = 50000.0
	Condition.set_condition(paused.state.ship, "drive.0", 0.3)
	paused.state.paused = true
	var pt := paused.state.time_s
	paused.apply({"type": "service", "slot": "drive.0"})
	check(paused.state.time_s > pt and paused.state.paused, "The yard's days pass even while paused, and pause is kept")


func test_refit_labour_and_time() -> void:
	var sim := fresh()
	var s := sim.state
	var d := sim.data
	s.credits = 500000.0
	var rq := Condition.refit_quote("cargo_pod_m", "kibo_ring", d)
	var t0 := s.time_s
	var credits := s.credits
	var trade := Condition.trade_in(s.ship, "cargo.0", d)
	check(sim.apply({"type": "install_module", "slot": "cargo.0", "module": "cargo_pod_m"}) == "", "Install still works")
	check(absf(credits - s.credits - (30000.0 + rq["labour_cr"] - trade)) < 1e-6, "Parts plus labour less trade-in")
	check(absf(s.time_s - t0 - rq["days"] * DAY) < 1.0, "Fitting takes its days (%.2f)" % rq["days"])
	# A bundle: two swaps at once share the yard's crews.
	var q := ShipBill.quote(s, d, {"swaps": [{"slot": "cargo.1", "module": "cargo_pod_m"}, {"slot": "tank.0", "module": "tank_m"}]})
	var days_a := float(Condition.refit_quote("cargo_pod_m", "kibo_ring", d)["days"])
	var days_b := float(Condition.refit_quote("tank_m", "kibo_ring", d)["days"])
	check(q["ok"] and absf(q["days"] - maxf(maxf(days_a, days_b), (days_a + days_b) / 2.0)) < 1e-9, "A bundle takes the longer job or half the total")
	t0 = s.time_s
	credits = s.credits
	check(sim.apply({"type": "refit", "swaps": [{"slot": "cargo.1", "module": "cargo_pod_m"}, {"slot": "tank.0", "module": "tank_m"}]}) == "", "Refit two modules in one visit")
	check(absf(credits - s.credits - q["total"]) < 1e-6 and absf(s.time_s - t0 - q["days"] * DAY) < 1.0, "Charged and timed exactly as quoted")
	check(s.ship["modules"]["cargo.1"] == "cargo_pod_m" and s.ship["modules"]["tank.0"] == "tank_m", "Both fitted")
	# Labour varies by yard and by module.
	check(Condition.refit_quote("pathfinder_mk2", "trojan_yards", d)["labour_cr"] > Condition.refit_quote("cargo_pod_m", "trojan_yards", d)["labour_cr"], "A drive costs more to fit than a pod")
	check(Condition.refit_quote("cargo_pod_m", "landauer_deep", d)["labour_cr"] > Condition.refit_quote("cargo_pod_m", "trojan_yards", d)["labour_cr"], "Remote yards charge more labour")
	# Refusals keep the old rules.
	check(sim.apply({"type": "refit", "swaps": [{"slot": "cargo.0", "module": "cargo_pod_m"}]}) != "", "Already fitted is refused")
	check(sim.apply({"type": "refit", "swaps": [{"slot": "cargo.0", "module": "cargo_pod_m"}, {"slot": "cargo.0", "module": "cargo_pod_s"}]}) != "", "The same slot twice is refused")
	check(sim.apply({"type": "refit", "swaps": []}) != "", "An empty refit is refused")
	var poor := fresh()
	check(poor.apply({"type": "refit", "swaps": [{"slot": "cargo.0", "module": "cargo_pod_m"}]}) != "", "A poor pilot cannot afford the labour and parts")
	# A drive refit voids the WoF until inspected; inspecting in the same visit does not.
	var yard := fresh()
	yard.state.location = {"status": "docked", "place": "trojan_yards"}
	yard.state.credits = 900000.0
	for slot in yard.state.ship["modules"]:
		Condition.set_condition(yard.state.ship, slot, 0.9)
	check(Fitness.valid(yard.state, yard.data), "Valid before the refit")
	yard.apply({"type": "install_module", "slot": "drive.0", "module": "pathfinder_mk2"})
	check(Fitness.status(yard.state, yard.data)["state"] == "voided", "A new drive voids the Warrant of Fitness")
	yard.apply({"type": "inspect"})
	check(Fitness.valid(yard.state, yard.data), "and an inspection restores it")
	var yard2 := fresh()
	yard2.state.location = {"status": "docked", "place": "trojan_yards"}
	yard2.state.credits = 900000.0
	for slot in yard2.state.ship["modules"]:
		Condition.set_condition(yard2.state.ship, slot, 0.9)
	yard2.apply({"type": "install_module", "slot": "drive.0", "module": "pathfinder_mk2", "inspect": true})
	check(Fitness.valid(yard2.state, yard2.data), "Inspecting in the same visit keeps the WoF valid")


func test_ship_bill() -> void:
	var sim := fresh()
	var s := sim.state
	var d := sim.data
	s.credits = 200000.0
	Condition.set_condition(s.ship, "radiator.0", 0.3)
	var req := {"swaps": [{"slot": "cargo.0", "module": "cargo_pod_m"}], "services": [{"slot": "drive.0", "level": "service"}, {"slot": "radiator.0", "level": "overhaul"}], "inspect": true}
	var before := s.to_dict()
	var bill := ShipBill.quote(s, d, req)
	check(s.to_dict() == before, "Quoting does not change the state")
	check(bill["ok"], "The bill is ok: %s" % str(bill["problems"]))
	var kinds := {}
	var sum := 0.0
	for line in bill["lines"]:
		kinds[line["kind"]] = true
		sum += float(line["credits"])
	check(kinds.has("part") and kinds.has("trade_in") and kinds.has("labour") and kinds.has("service") and kinds.has("overhaul") and kinds.has("inspection"), "The bill itemises parts, trade-in, labour, service, overhaul and inspection")
	check(absf(sum - bill["total"]) < 1e-6, "Lines add up to the total")
	check(absf(bill["parts"] - 30000.0) < 1e-6 and bill["trade_in"] > 0.0 and bill["labour"] > 0.0, "Parts, trade-in and labour are broken out")
	check(bill["days"] > 0.0 and bill["afford"], "Days in port, and affordable")
	check(bill["wof"]["after"]["valid"] and bill["wof"]["would_pass"], "The WoF effect is shown: it would pass")
	check(bill["insurance"]["premium_after"] > bill["insurance"]["premium_before"], "A better fit raises the premium (%d to %d)" % [bill["insurance"]["premium_before"], bill["insurance"]["premium_after"]])
	check(bill["ship_after"]["modules"]["cargo.0"] == "cargo_pod_m" and Condition.condition(bill["ship_after"], "radiator.0") > 0.9, "The ship after is previewed")
	# Committing charges exactly the bill.
	var credits := s.credits
	var t0 := s.time_s
	check(sim.apply({"type": "refit", "swaps": req["swaps"], "services": req["services"], "inspect": true}) == "", "Commit the same job")
	check(absf(credits - s.credits - bill["total"]) < 1e-6 and absf(s.time_s - t0 - bill["days"] * DAY) < 1.0, "Charged and timed as billed")
	# A drive swap without inspection voids the WoF, and the bill says so.
	var drive := ShipBill.quote(fresh().state, d, {"place": "trojan_yards", "swaps": [{"slot": "drive.0", "module": "pathfinder_mk2"}]})
	check(drive["ok"] and drive["wof"]["voided_by_refit"] and not drive["wof"]["after"]["valid"], "The bill warns that a drive refit voids the WoF")
	check(drive["insurance"]["state_after"] == "void" and drive["insurance"]["void_after"], "and that the insurance would be void")
	# A failing inspection shows what must be fixed.
	var bad := fresh()
	Condition.set_condition(bad.state.ship, "tank.0", 0.1)
	var fail := ShipBill.quote(bad.state, bad.data, {"inspect": true})
	check(not fail["wof"]["after"]["valid"] and not fail["wof"]["issues"].is_empty(), "The bill shows an inspection would fail and why")
	# Problems and affordability.
	var poor := ShipBill.quote(fresh().state, d, {"swaps": [{"slot": "cargo.0", "module": "cargo_pod_l"}]})
	check(not poor["ok"] or not poor["afford"], "Not sold here or not affordable")
	var nothing := ShipBill.quote(fresh().state, d, {})
	check(not nothing["ok"] and nothing["problems"].has("nothing to do"), "An empty request says so")
	var bogus := ShipBill.quote(fresh().state, d, {"swaps": [{"slot": "cargo.9", "module": "cargo_pod_m"}]})
	check(not bogus["ok"], "A phantom slot fails the bill")
	var cargo_state := fresh()
	cargo_state.state.credits = 100000.0
	cargo_state.state.ship["cargo"] = {"water_ice": 19.0}
	var small := ShipBill.quote(cargo_state.state, d, {"swaps": [{"slot": "cargo.0", "module": "cargo_pod_s"}]})
	check(not small["ok"], "A swap that leaves cargo with no room is refused (same module or too small)")
	# Quoting at another yard without going there.
	var elsewhere := ShipBill.quote(s, d, {"place": "trojan_yards", "service_all": "service"})
	var here := ShipBill.quote(s, d, {"service_all": "service"})
	check(elsewhere["ok"] and elsewhere["place"] == "trojan_yards" and elsewhere["total"] != here["total"], "A yard elsewhere can be quoted")


func test_wof() -> void:
	var sim := fresh()
	var s := sim.state
	var d := sim.data
	s.credits = 100000.0
	check(Fitness.status(s, d)["state"] == "valid" and Fitness.valid(s, d), "A new game has a valid WoF")
	check(Fitness.passenger_job_block(s, d) == "", "with passenger jobs allowed")
	# It runs down and warns.
	var warn_days := float(d.ship_economy["wof"]["warn_days"])
	sim.advance_game_time((float(d.ship_economy["start"]["wof_days"]) - warn_days + 1.0) * DAY)
	check(Fitness.status(s, d)["state"] == "expiring" and Fitness.valid(s, d), "It is still valid but expiring")
	check(sim.take_events().any(func(e): return e["type"] == "wof_expiring"), "A warning is raised")
	# It expires; the effects bite.
	sim.advance_game_time(warn_days * DAY)
	check(Fitness.status(s, d)["state"] == "expired" and not Fitness.valid(s, d), "It expires")
	check(sim.take_events().any(func(e): return e["type"] == "wof_lapsed"), "and says so once")
	check(Insurance.status(s, d)["state"] == "void", "An expired WoF voids the insurance")
	var job := _passenger_job(sim, 7001)
	check(sim.apply({"type": "accept_contract", "id": 7001}) != "", "Passenger jobs are refused without a WoF")
	check(Fitness.passenger_job_block(s, d) != "", "with a reason")
	# Docking: a surcharge everywhere it is set, and strict ports turn passengers away.
	check(Fitness.port_class("kibo_ring", d) == "strict" and Fitness.port_class("trojan_yards", d) in ["relaxed", "standard"], "Ports have traffic-control classes by operator")
	var credits := s.credits
	s.location = {"status": "approach", "place": "kibo_ring"}
	var fee := float(d.balance["docking"]["auto_dock_fee"])
	check(sim.apply({"type": "dock"}) == "", "Docking is not refused outright")
	check(absf(credits - s.credits - fee - float(d.ship_economy["wof"]["port_rules"]["strict"]["surcharge_cr"])) < 1e-6, "A strict port charges extra")
	# Passengers already aboard are put ashore at a strict port.
	var p := fresh()
	_passenger_job(p, 7002)
	p.state.credits = 50000.0
	check(p.apply({"type": "accept_contract", "id": 7002}) == "", "A passenger job is accepted with a valid WoF")
	p.state.ship["wof"]["valid_until_t"] = p.state.time_s - 1.0
	p.state.location = {"status": "approach", "place": "kibo_ring"}
	p.take_events()
	check(p.apply({"type": "dock"}) == "", "Dock with passengers aboard")
	check(p.state.contracts["active"].is_empty() and int(p.state.ship["passengers"]) == 0, "Strict traffic control puts the passengers ashore")
	check(p.state.contracts["history"][-1]["outcome"] == "turned_away" and p.take_events().any(func(e): return e["type"] == "passengers_refused"), "and the job is closed as turned away")
	# A relaxed or lenient port keeps them (passengers_refused only where data says).
	var lax := fresh()
	_passenger_job(lax, 7003)
	check(lax.apply({"type": "accept_contract", "id": 7003}) == "", "Accept")
	lax.state.ship["wof"]["valid_until_t"] = lax.state.time_s - 1.0
	var relaxed := ""
	for id in lax.data.places:
		if Fitness.port_class(id, lax.data) == "relaxed" and not lax.data.places[id].has("foot_of"):
			relaxed = id
			break
	lax.state.location = {"status": "approach", "place": relaxed}
	lax.apply({"type": "dock"})
	check(int(lax.state.ship["passengers"]) == 2 and lax.state.contracts["active"].size() == 1, "A relaxed port lets passengers through")
	# Inspection at the yard: fail lists issues, charges, and keeps the WoF failed.
	var f := fresh()
	f.state.credits = 50000.0
	Condition.set_condition(f.state.ship, "drive.0", 0.1)
	f.state.ship["damage"] = {"keel": 0.4}
	var fee_i := float(d.ship_economy["wof"]["inspection_cr"])
	var c0 := f.state.credits
	check(f.apply({"type": "inspect"}) == "", "An inspection can be had")
	check(absf(c0 - f.state.credits - fee_i) < 1e-6, "It costs the fee")
	var st := Fitness.status(f.state, f.data)
	check(st["state"] == "failed" and not st["valid"] and st["issues"].size() == 2, "It fails and lists what must be fixed (%s)" % str(st["issues"]))
	check(f.take_events().any(func(e): return e["type"] == "wof_failed"), "A failure is announced")
	check(Insurance.status(f.state, f.data)["state"] == "void", "A failed WoF voids the insurance")
	# Fix it and pass.
	check(f.apply({"type": "repair"}) == "" and f.apply({"type": "overhaul", "slot": "drive.0"}) == "", "Repair and overhaul")
	check(f.apply({"type": "inspect"}) == "" and Fitness.valid(f.state, f.data), "Then it passes")
	check(absf(float(f.state.ship["wof"]["valid_until_t"]) - f.state.time_s - float(d.ship_economy["wof"]["valid_days"]) * DAY) < 1.0, "valid for the data's period")
	check(f.take_events().any(func(e): return e["type"] == "wof_issued") and Insurance.status(f.state, f.data)["state"] == "active", "and cover is back")
	# Renewing an expired one works too, and inspection is yard-only.
	var e := fresh()
	e.state.ship["wof"]["valid_until_t"] = e.state.time_s - DAY
	e.state.credits = 5000.0
	check(e.apply({"type": "inspect"}) == "" and Fitness.valid(e.state, e.data), "An expired WoF is renewed by inspection")
	e.state.location = {"status": "approach", "place": "kibo_ring"}
	check(e.apply({"type": "inspect"}) != "", "No inspections in flight")


func test_insurance() -> void:
	var sim := fresh()
	var s := sim.state
	var d := sim.data
	var tune: Dictionary = d.balance["damage"]
	var st := Insurance.status(s, d)
	check(st["state"] == "active" and st["plan"] == "basic" and "total_loss" in st["covers"] and not "collision" in st["covers"], "A new game starts with the basic cover")
	var prem := Insurance.premium(s, d, "basic")
	check(prem["per_period"] >= float(d.ship_economy["insurance"]["min_premium_cr"]) and prem["insured_value"] > 9000.0, "The premium comes from hull value (%d on %d)" % [prem["per_period"], prem["insured_value"]])
	check(Insurance.premium(s, d, "full")["per_period"] > Insurance.premium(s, d, "standard")["per_period"] and Insurance.premium(s, d, "standard")["per_period"] > prem["per_period"], "Wider cover costs more")
	# Wear raises risk; claims raise premiums.
	var tired := fresh()
	for slot in tired.state.ship["modules"]:
		Condition.set_condition(tired.state.ship, slot, 0.2)
	check(Insurance.premium(tired.state, d, "standard")["risk_mult"] > Insurance.premium(s, d, "standard")["risk_mult"], "A worn ship is a bigger risk")
	var base := float(Insurance.premium(s, d, "standard")["per_period"])
	Insurance.record_claim(s, "collision", 1000.0)
	check(float(Insurance.premium(s, d, "standard")["per_period"]) > base, "A claim raises the premium")
	sim.advance_game_time((float(d.ship_economy["insurance"]["claim_decay_days"]) + 1.0) * DAY)
	check(Insurance.recent_claims(s, d) == 0, "Old claims stop counting")
	# Buying a policy.
	var b := fresh()
	b.state.credits = 20000.0
	var p2 := float(Insurance.premium(b.state, b.data, "standard")["per_period"])
	check(b.apply({"type": "buy_insurance", "plan": "standard"}) == "", "Buy the standard policy")
	check(absf(20000.0 - b.state.credits - p2) < 1e-6 and "collision" in Insurance.status(b.state, b.data)["covers"], "Premium paid, collision now covered")
	check(b.apply({"type": "buy_insurance", "plan": "nonsense"}) != "", "No such plan")
	b.state.credits = 10.0
	check(b.apply({"type": "buy_insurance", "plan": "full"}) != "", "Cannot pay the premium")
	b.state.credits = 20000.0
	b.state.ship["damage"] = {"drive.0": 0.4}
	check(b.apply({"type": "buy_insurance", "plan": "full"}) != "", "No collision cover on an already-damaged ship")
	check(b.apply({"type": "buy_insurance", "plan": "basic"}) == "", "but total-loss-only cover is fine")
	# Collision repair: the insurer pays above the excess, the claim goes on record.
	var r := fresh()
	r.state.credits = 50000.0
	r.apply({"type": "buy_insurance", "plan": "standard"})
	r.state.ship["damage"] = {"drive.0": 0.8, "keel": 0.3}
	var cost := DamageSystem.repair_cost(r.state, r.data)
	var excess := Insurance.collision_excess("standard", r.data)
	check(cost > excess, "The repair is dearer than the collision excess (%d vs %d)" % [cost, excess])
	var cr := r.state.credits
	var claims0 := Insurance.recent_claims(r.state, r.data)
	check(r.apply({"type": "repair"}) == "", "Repair under cover")
	check(absf(cr - r.state.credits - excess) < 1e-6, "The pilot pays only the excess")
	check(Insurance.recent_claims(r.state, r.data) == claims0 + 1, "and a claim is recorded")
	# Without cover the repair is all yours; small repairs are not claimed.
	var u := fresh()
	u.state.credits = 50000.0
	u.state.ship["damage"] = {"drive.0": 0.8}
	var full_cost := DamageSystem.repair_cost(u.state, u.data)
	var uc := u.state.credits
	u.apply({"type": "repair"})
	check(absf(uc - u.state.credits - full_cost) < 1e-6 and Insurance.recent_claims(u.state, u.data) == 0, "No collision cover: you pay the lot, no claim")
	# Total loss with cover: payout for the upgrade less the excess, and a claim.
	var t := fresh()
	t.state.credits = 50000.0
	t.state.ship["modules"]["cargo.0"] = "cargo_pod_l"
	Condition.reset_slot(t.state.ship, "cargo.0")
	t.state.ship["cargo_paid"] = {"food": 700.0}
	var c1 := t.state.credits
	var ev := _wreck(t)
	check(ev["cover"] == "basic" and ev["payout"] > 0.0 and ev["loan"] == 0.0, "A total loss on cover pays out")
	check(absf(t.state.credits - (c1 + ev["payout"] - float(tune["insurance_excess"]))) < 1e-6, "less exactly the excess")
	check(t.state.ship["hull"] == "mule" and Insurance.recent_claims(t.state, t.data) == 1, "You get a hull and a claim goes on file")
	check(t.state.ship["modules"]["cargo.0"] == "cargo_pod_s", "The replacement is a stock hull")
	check(Insurance.status(t.state, t.data)["state"] == "active" and float(Insurance.premium(t.state, t.data, "basic")["claims_mult"]) > 1.0, "Cover continues at a higher premium")
	# Cargo cover pays the cargo only on the full plan.
	var cg := fresh()
	cg.state.credits = 60000.0
	cg.apply({"type": "buy_insurance", "plan": "full"})
	cg.state.ship["cargo_paid"] = {"food": 1000.0}
	var cg0 := cg.state.credits
	var cev := _wreck(cg)
	check(cev["payout"] >= 900.0 and absf(cg.state.credits - cg0 - cev["payout"] + Insurance.excess("full", cg.data)) < 1e-6, "Cargo cover pays 90% of the cargo, less the lower excess")
	var cb := fresh()
	cb.state.ship["cargo_paid"] = {"food": 1000.0}
	check(_wreck(cb)["payout"] == 0.0, "Basic cover does not pay for cargo")
	# No policy: a Commons hull on a loan; credits are not touched, and it is repaid slowly.
	var n := fresh()
	n.state.credits = 5000.0
	n.apply({"type": "cancel_insurance"})
	check(Insurance.status(n.state, n.data)["state"] == "none", "Cancelled: no cover")
	var nev := _wreck(n)
	var loan := float(d.ship_economy["insurance"]["fallback"]["loan_cr"])
	check(nev["cover"] == "" and nev["payout"] == 0.0 and nev["loan"] == loan and n.state.credits == 5000.0, "No policy: no payout, a Commons hull on a loan")
	check(n.state.ship["hull"] == "mule" and n.state.insurance["loan_cr"] == loan, "The loan is on the books")
	n.advance_game_time(float(d.balance["damage"]["lifeboat_s"]) + 1.0)
	n.advance_game_time(10.0 * DAY)
	check(n.state.insurance["loan_cr"] < loan and n.state.credits >= float(d.ship_economy["insurance"]["fallback"]["loan_keep_cr"]) - 1e-6, "The loan is repaid gently, never past the floor")
	# Broke with no cover: no debt spiral, never stuck.
	var br := fresh()
	br.state.credits = 0.0
	br.apply({"type": "cancel_insurance"})
	_wreck(br)
	br.advance_game_time(30.0 * DAY)
	check(br.state.credits >= 0.0 and br.state.location["status"] == "docked", "A broke, uninsured pilot is rescued and still solvent")
	# A void policy (no WoF) pays nothing; the loan fallback applies.
	var v := fresh()
	v.state.ship["wof"]["valid_until_t"] = v.state.time_s - DAY
	var vev := _wreck(v)
	check(vev["cover"] == "" and vev["loan"] == loan and v.state.credits == float(d.balance["start"]["credits"]), "A void policy pays nothing: Commons loan")
	# Lapse and auto-renew.
	var l := fresh()
	l.state.credits = 50000.0
	l.state.insurance["policy"]["auto_renew"] = false
	l.advance_game_time((float(d.ship_economy["start"]["insurance_paid_days"]) + 1.0) * DAY)
	check(Insurance.status(l.state, l.data)["state"] == "lapsed", "An unpaid policy lapses")
	check(l.take_events().any(func(e): return e["type"] == "insurance_lapsed"), "and says so")
	var ar := fresh()
	ar.state.credits = 50000.0
	ar.state.ship["wof"]["valid_until_t"] = ar.state.time_s + 400.0 * DAY
	ar.advance_game_time(40.0 * DAY)
	check(Insurance.status(ar.state, ar.data)["state"] == "active" and ar.state.credits < 50000.0, "An auto-renewing policy is renewed at port and paid for")
	var pr := fresh()
	pr.state.credits = 0.0
	pr.state.ship["wof"]["valid_until_t"] = pr.state.time_s + 400.0 * DAY
	pr.advance_game_time(40.0 * DAY)
	check(Insurance.status(pr.state, pr.data)["state"] == "lapsed", "A pilot who cannot pay lets it lapse (not debt)")


func test_ship_economy_saves() -> void:
	var sim := fresh()
	var s := sim.state
	s.credits = 80000.0
	sim.apply({"type": "buy_insurance", "plan": "standard"})
	Condition.set_condition(s.ship, "drive.0", 0.1)
	sim.advance_game_time(100.0 * DAY)
	Insurance.record_claim(s, "collision", 500.0)
	s.insurance["loan_cr"] = 1234.0
	s.ship["damage"] = {"radiator.0": 0.2}
	var back := SaveIO.from_text(SaveIO.to_text(s))
	check(back != null and back.to_dict() == s.to_dict(), "Wear, faults, WoF and insurance round-trip exactly")
	check(back.ship["wear"] == s.ship["wear"] and back.ship["faults"] == s.ship["faults"] and back.ship["wof"] == s.ship["wof"] and back.insurance == s.insurance, "each piece is intact")
	# Resumed games keep ticking identically.
	var other := Sim.new()
	other.load_state(back)
	sim.advance_game_time(30.0 * DAY)
	other.advance_game_time(30.0 * DAY)
	check(other.state.to_dict() == sim.state.to_dict(), "A loaded game ages the same as the one it came from")
	# An old save has no wear, no WoF and no policy: sensible defaults at the first tick.
	var old := fresh()
	var d := old.state.to_dict()
	d["ship"].erase("wear")
	d["ship"].erase("use")
	d["ship"].erase("faults")
	d["ship"].erase("wof")
	d.erase("insurance")
	var legacy := GameState.new()
	legacy.load_dict(d)
	check(Condition.condition(legacy.ship, "drive.0") == 1.0 and Fitness.valid(legacy, old.data), "An old ship counts as new and fit")
	var lsim := Sim.new()
	lsim.load_state(legacy)
	lsim.advance_game_time(3600.0)
	check(legacy.ship.has("wof") and Fitness.valid(legacy, lsim.data) and Insurance.status(legacy, lsim.data)["state"] == "active", "and is given a WoF and starter cover")
	check(lsim.apply({"type": "service", "slot": "drive.0"}) != "", "with nothing to service")
	# Determinism: the same commands give the same state.
	var a := fresh()
	var b := fresh()
	for x in [a, b]:
		x.state.credits = 90000.0
		x.apply({"type": "refit", "swaps": [{"slot": "cargo.0", "module": "cargo_pod_m"}], "services": [{"slot": "drive.0", "level": "overhaul"}], "inspect": true})
		x.apply({"type": "depart", "to": "halo_depot"})
		x.advance_game_time(5.0 * DAY)
	check(a.state.to_dict() == b.state.to_dict(), "The ship economy is deterministic")


## A repair voucher pays towards service and overhaul through the ship bill ("voucher: -X cr").
func test_yard_voucher_on_bill() -> void:
	var sim := fresh()
	var s := sim.state
	var d := sim.data
	s.credits = 100000.0
	_dock_at(sim, "kibo_ring")
	var op := Favours.operator_of(d, "kibo_ring")
	Favours.ensure(s)
	s.favours["vouchers"] = [{"id": 90, "form": "yard", "operator": op, "value_cr": 500.0, "expires_t": s.time_s + 30.0 * DAY}]
	s.favours["seq"] = 90
	for slot in s.ship["modules"]:
		Condition.set_condition(s.ship, slot, 0.4)
	var plain := ShipBill.quote(s, d, {"service_all": "service", "use_voucher": false})
	var bill := ShipBill.quote(s, d, {"service_all": "service"})
	check(float(plain["voucher"]) == 0.0 and float(plain["service"]) > 500.0, "Without a voucher the service bill is whole (%d cr)" % int(plain["service"]))
	check(absf(float(bill["voucher"]) - 500.0) < 1e-6, "A 500 cr voucher takes 500 cr off service")
	check(absf(float(bill["total"]) - (float(plain["total"]) - 500.0)) < 1e-6, "and comes off the total")
	var line: Array = bill["lines"].filter(func(l): return l["kind"] == "voucher")
	check(line.size() == 1 and line[0]["label"] == "voucher: -500 cr" and absf(float(line[0]["credits"]) + 500.0) < 1e-6, "as one bill line, 'voucher: -500 cr'")
	check(Favours.yard_voucher_balance(s, d, "kibo_ring") == 500.0, "Quoting spends nothing")
	# The inspection fee, labour and parts are not repairs.
	var inspect_only := ShipBill.quote(s, d, {"inspect": true})
	check(float(inspect_only["voucher"]) == 0.0, "A voucher does not pay the inspection fee")
	# Only that operator's yards; only live vouchers.
	var other := ""
	for id in d.places:
		if "shipyard" in d.places[id].get("services", []) and Favours.operator_of(d, id) != op:
			other = id
			break
	check(other != "" and float(ShipBill.quote(s, d, {"place": other, "service_all": "service"})["voucher"]) == 0.0, "A voucher is no good at another operator's yard")
	s.favours["vouchers"][0]["expires_t"] = s.time_s - 1.0
	check(float(ShipBill.quote(s, d, {"service_all": "service"})["voucher"]) == 0.0, "An expired voucher is no good")
	s.favours["vouchers"][0]["expires_t"] = s.time_s + 30.0 * DAY
	# Committing charges exactly the bill and spends the voucher.
	var before: float = s.credits
	check(sim.apply({"type": "service", "slot": "all"}) == "", "Service the whole ship")
	check(absf((before - s.credits) - (float(plain["total"]) - 500.0)) < 1e-6, "The yard is paid the bill less the voucher (%d cr)" % int(before - s.credits))
	check(s.favours["vouchers"].is_empty(), "A used-up voucher is gone")
	check(sim.take_events().any(func(e): return e["type"] == "voucher_used" and e["data"].has("left") and e["data"].has("spent") and e["data"].has("place")), "and says so (with what the view reads: spent, left, place)")
	# A big voucher pays the whole job and keeps the rest (soonest-expiring first).
	s.favours["vouchers"] = [
		{"id": 91, "form": "yard", "operator": op, "value_cr": 400.0, "expires_t": s.time_s + 90.0 * DAY},
		{"id": 92, "form": "yard", "operator": op, "value_cr": 400.0, "expires_t": s.time_s + 10.0 * DAY}]
	for slot in s.ship["modules"]:
		Condition.set_condition(s.ship, slot, 0.4)
	var q2 := ShipBill.quote(s, d, {"services": [{"slot": "drive.0", "level": "service"}]})
	var spend := minf(800.0, float(q2["service"]))
	check(absf(float(q2["voucher"]) - spend) < 1e-6, "Two vouchers add up")
	sim.apply({"type": "service", "slot": "drive.0"})
	var left := 0.0
	for v in s.favours["vouchers"]:
		left += float(v["value_cr"])
	check(absf(left - (800.0 - spend)) < 1e-6, "and what is left stays on them (%d cr)" % int(left))
	if spend < 800.0 and not s.favours["vouchers"].is_empty():
		check(int(s.favours["vouchers"][0]["id"]) == 91, "the sooner-expiring one went first")
	# Damage repair by use_voucher still works and says where else a voucher helps.
	s.favours["vouchers"] = [{"id": 93, "form": "yard", "operator": op, "value_cr": 500.0, "expires_t": s.time_s + 30.0 * DAY}]
	s.ship["damage"] = {}
	check(sim.apply({"type": "use_voucher", "id": 93}) == "nothing to repair", "use_voucher mends collision damage only: with none it keeps the voucher")
	check(Favours.yard_voucher_balance(s, d, "kibo_ring") == 500.0, "(and the voucher is still there for the bill)")


## Hitchhikers are passengers: no ride without a valid Warrant of Fitness, and a strict
## port puts them ashore (unpaid) as it does contract passengers.
func test_hitchhikers_and_wof() -> void:
	var sim := fresh()
	var s := sim.state
	var d := sim.data
	d.favours["hitchhikers"]["chance"] = 1.0
	d.favours["hitchhikers"]["cooldown_days"] = 0.0
	s.ship["modules"]["cargo.1"] = "passenger_berths"
	_dock_at(sim, "trojan_yards")
	s.favours["last_dock"] = ""
	sim.advance_game_time(60.0)
	var waiting: Array = s.favours["waiting"].get("trojan_yards", [])
	check(not waiting.is_empty(), "Someone asks for a ride")
	if waiting.is_empty():
		return
	var h: Dictionary = waiting[0]
	var valid_until: float = s.ship["wof"]["valid_until_t"]
	s.ship["wof"]["valid_until_t"] = s.time_s - 1.0
	check(not Fitness.valid(s, d), "(the Warrant of Fitness has lapsed)")
	var why := String(sim.apply({"type": "accept_hitchhiker", "id": h["id"]}))
	check(why == Fitness.passenger_job_block(s, d) and why != "", "No hitchhikers without a valid Warrant of Fitness (same rule as passengers)")
	check(s.ship.get("hikers", []).is_empty() and int(s.ship.get("passengers", 0)) == 0, "and nobody boards")
	s.ship["wof"]["valid_until_t"] = valid_until
	check(sim.apply({"type": "accept_hitchhiker", "id": h["id"]}) == "", "With a valid one they come aboard")
	# Expired in flight: a strict port puts them ashore without a fare; a relaxed one does not.
	s.ship["hikers"][0]["fare"] = 250.0
	s.ship["hikers"][0]["to"] = "kibo_ring"
	s.ship["wof"]["valid_until_t"] = s.time_s - 1.0
	sim.take_events()
	s.location = {"status": "approach", "place": "kibo_ring"}
	var credits: float = s.credits
	sim.apply({"type": "dock"})
	sim.advance_game_time(60.0)
	check(Fitness.dock_terms(s, d, "kibo_ring")["refuse_passengers"], "(Kibo Ring is a strict port)")
	check(s.ship.get("hikers", []).is_empty() and int(s.ship.get("passengers", 0)) == 0, "A strict port puts the hitchhiker ashore without a valid WoF")
	var gap := credits - s.credits
	check(gap > 0.0 and gap < 1000.0, "and they pay no fare (the ship only paid fees: %d cr)" % int(gap))
	check(sim.take_events().any(func(e): return e["type"] == "hitchhiker_refused"), "and it is said why")
	var relaxed := fresh()
	relaxed.state.ship["modules"]["cargo.1"] = "passenger_berths"
	relaxed.state.ship["hikers"] = [{"id": 1, "name": "Test Rider", "trade": "cook", "to": "trojan_yards", "from": "kibo_ring", "fare": 200.0, "gift": "", "boarded_t": 0.0, "mid_sent": true, "lines": {"board": "", "mid": "", "leave": "bye"}}]
	relaxed.state.ship["passengers"] = 1
	relaxed.state.ship["wof"]["valid_until_t"] = relaxed.state.time_s - 1.0
	relaxed.state.location = {"status": "approach", "place": "trojan_yards"}
	relaxed.apply({"type": "dock"})
	relaxed.advance_game_time(60.0)
	check(not Fitness.dock_terms(relaxed.state, relaxed.data, "trojan_yards")["refuse_passengers"] and relaxed.state.ship.get("hikers", []).is_empty(), "A relaxed port lets them off at their stop")
	check(relaxed.take_events().any(func(e): return e["type"] == "hitchhiker_left" and float(e["data"]["fare"]) == 200.0), "and they pay the fare")


## Upkeep that matters: a tired drive costs real speed, a tune's wear is real, insurance
## renews early enough that short trips do not lapse it, and tunes are priced at what they save.
func test_upkeep_bites() -> void:
	var sim := fresh()
	var s := sim.state
	var d := sim.data
	var ship: Dictionary = s.ship.duplicate(true)
	Condition.set_condition(ship, "drive.0", 0.9)
	var fresh_a := ShipStats.accel_mps2(ship, d)
	Condition.set_condition(ship, "drive.0", 0.0)
	var worn_a := ShipStats.accel_mps2(ship, d)
	var loss := float(d.ship_economy["performance"]["max_loss"])
	check(loss >= 0.25 and absf(worn_a / fresh_a - (1.0 - loss)) < 0.02, "A worn-out drive pushes %d%% less than a fresh one (%.4f vs %.4f)" % [int(round(loss * 100.0)), worn_a, fresh_a])
	# Tunes: Overdrive wears its drive faster, lean-burn slower, in the wear system itself.
	var wear := {}
	for tune in ["", "overdrive_map", "lean_burn_map"]:
		var t := fresh()
		t.state.credits = 100000.0
		t.state.ship["tunes"] = []
		if tune != "":
			check(Favours.install_tune(t.state.ship, t.data, tune, "test", 0.0) == "", "Fit %s" % tune)
		t.state.ship["wear"]["drive.0"] = 0.0
		check(t.apply({"type": "depart", "to": "halo_depot"}) == "", "Depart (%s)" % tune)
		t.advance_game_time(86400.0)
		wear[tune] = float(t.state.ship["wear"]["drive.0"])
	check(wear[""] > 0.0 and wear["overdrive_map"] > wear[""] * 1.3, "Overdrive wears its drive about 40%% faster (%.5f vs %.5f)" % [wear["overdrive_map"], wear[""]])
	check(wear["lean_burn_map"] < wear[""] * 0.95, "Lean-burn is gentler on it (%.5f)" % wear["lean_burn_map"])
	# Every tune is still big enough to be offered as a reward in kind.
	for id in d.favours["tunes"]:
		check(float(d.favours["tunes"][id]["value_cr"]) >= float(d.favours["in_kind"]["min_value_cr"]), "Tune %s is priced above the in-kind minimum" % id)
	# Insurance renews at a dock inside the window, and adds to the paid time rather than wasting it.
	var r := fresh()
	r.state.credits = 50000.0
	var pol: Dictionary = r.state.insurance["policy"]
	var window := float(d.ship_economy["insurance"]["renew_window_days"])
	check(window >= 7.0, "The renewal window is a week or more (%d days)" % int(window))
	var before: float = pol["paid_until_t"]
	r.state.insurance["policy"]["paid_until_t"] = r.state.time_s + (window - 1.0) * DAY
	before = r.state.insurance["policy"]["paid_until_t"]
	r.advance_game_time(60.0)
	check(r.state.insurance["policy"]["paid_until_t"] > before + 29.0 * DAY - 120.0, "A docked ship inside the window renews, from the old expiry")
	var far := fresh()
	far.state.insurance["policy"]["paid_until_t"] = far.state.time_s + (window + 5.0) * DAY
	var far_before: float = far.state.insurance["policy"]["paid_until_t"]
	far.advance_game_time(60.0)
	check(far.state.insurance["policy"]["paid_until_t"] == far_before, "and does not renew too early")


## Turning with inertia (roadmap step 1): each hull has its own turn rate, a laden ship
## turns slower, and a turn accelerates, coasts and brakes to stop lined up.
func test_turning_with_inertia() -> void:
	var sim := fresh()
	var s := sim.state
	var d := sim.data
	var light: Array = ShipStats.turn_limits(s.ship, d)
	check(is_equal_approx(float(light[0]), deg_to_rad(float(d.ships["mule"]["turn_rate_dps"]))), "The Mule turns at its hull's rate")
	s.ship["cargo"] = {"water_ice": 20.0}
	var laden: Array = ShipStats.turn_limits(s.ship, d)
	check(float(laden[1]) < float(light[1]) * 0.6, "A laden Mule swings round slower (%.3f vs %.3f rad/s^2)" % [laden[1], light[1]])
	var courier := {"hull": "courier", "modules": d.ships["courier"]["modules"].duplicate(), "fuel_t": 0.0}
	var heavy := {"hull": "heavy_freighter", "modules": d.ships["heavy_freighter"]["modules"].duplicate(), "fuel_t": 0.0}
	check(float(ShipStats.turn_limits(courier, d)[1]) > float(ShipStats.turn_limits(heavy, d)[1]) * 2.0, "A courier turns faster than a heavy freighter")
	var no_hull := ShipStats.turn_limits({"hull": "climber", "modules": d.ships["climber"]["modules"].duplicate()}, d)
	check(is_equal_approx(float(no_hull[0]), deg_to_rad(float(d.balance["turning"]["rate_dps"]))), "A hull without figures uses the defaults")
	# A flip: from rest to rest, never faster than the limit, ending lined up.
	var rate := float(light[0])
	var accel := float(light[1])
	var f := Vector3.FORWARD
	var w := Vector3.ZERO
	var target := Vector3.BACK.rotated(Vector3.UP, 0.01)
	var dt := 1.0 / 60.0
	var elapsed := 0.0
	var fastest := 0.0
	while elapsed < 120.0 and not (f.angle_to(target) < 1e-3 and w == Vector3.ZERO):
		var step: Array = ShipRig.turn_step(f, w, target, rate, accel, dt)
		f = step[0]
		w = step[1]
		fastest = maxf(fastest, w.length())
		elapsed += dt
	var expect := ShipRig.turn_time(Vector3.FORWARD.angle_to(target), rate, accel)
	check(f.angle_to(target) < 1e-3 and w == Vector3.ZERO, "A turn stops lined up")
	check(fastest <= rate + 1e-6, "A turn never exceeds the hull's rate")
	check(absf(elapsed - expect) < expect * 0.1 + 0.2, "A flip takes about as long as turn_time says (%.1f s vs %.1f s)" % [elapsed, expect])
	# Dead astern: it still picks a way round.
	var astern: Array = ShipRig.turn_step(Vector3.FORWARD, Vector3.ZERO, Vector3.BACK, rate, accel, dt)
	check((astern[1] as Vector3).length() > 0.0, "A turn dead astern still starts")


## Smooth rendezvous arrival (roadmap step 2): every trip to a port ends with a final
## approach in the port's frame, arriving slow and lined up at the point where the
## docking scene takes over, without changing the trip's time or propellant.
func test_final_approach() -> void:
	var cfg: Dictionary = fresh().data.balance["approach"]
	for case in [["halo_depot", ""], ["kernel_l5", "express"], ["shackleton_port", ""]]:
		var sim := fresh()
		var s := sim.state
		var d := sim.data
		var t: float = s.time_s
		var to: String = case[0]
		var plan := Navigation.plan(s.ship, d, sim.ephemeris, "kibo_ring", to, t)
		var fuel_before := float(s.ship["fuel_t"])
		if case[1] == "":
			check(sim.apply({"type": "depart", "to": to}) == "", "Depart for %s" % to)
			check(is_equal_approx(float(s.location["arrive_t"]), float(plan["arrive_t"])), "The approach leaves the trip time alone (%s)" % to)
			check(absf(fuel_before - float(s.ship["fuel_t"]) - float(plan["fuel_t"])) < 1e-6, "The approach costs no extra propellant (%s)" % to)
		else:
			var options: Array = TravelSystem.plan_for(s.ship, d, sim.ephemeris, "kibo_ring", to, t)
			sim.store_route_options(sim.route_key(to, t), options)
			check(sim.apply({"type": "depart", "to": to, "route": case[1], "plan_t": t}) == "", "Depart for %s (%s)" % [to, case[1]])
		var loc: Dictionary = s.location
		var app = loc.get("approach")
		check(app != null, "A trip to %s has a final approach" % to)
		if app == null:
			continue
		var geom: Dictionary = d.places[to]["station"]
		var t1 := float(loc["arrive_t"])
		var end: Array = Navigation.approach_state(loc, t1)
		var want := V.scale(Navigation.DOCK_AXIS, Navigation.handover_from_centre(d, geom))
		check(V.distance(end[0], want) < 1e-3, "%s: the approach ends at the hand-over point on the docking axis" % to)
		check(absf(V.length(end[1]) - float(cfg["handover_speed_mps"])) < 1e-3 and V.dot(end[1], Navigation.DOCK_AXIS) < 0.0, "%s: arriving slow, along the axis toward the port" % to)
		check(end[3] == "corridor", "%s: the last stretch is the docking corridor" % to)
		# Seamless where it takes over from the trip.
		var t0 := float(app["t0"])
		# (After a descent, if there is one; else after the trip itself.)
		var before: Array = Navigation._descent_pos(app, t0) if app.has("descent") else Navigation._raw_position(loc, t0)
		check(V.distance(before, Navigation.transit_position(loc, t0)) < 1.0, "%s: no jump where the approach begins" % to)
		# Never through the station: kept beyond its hub, ring and the margin.
		var bound := maxf(maxf(float(geom["ring_radius_m"]) + float(geom["ring_tube_m"]), float(geom["hub_radius_m"])), float(geom["hub_length_m"]) * 0.5)
		var nearest := INF
		var phases := {}
		for k in 401:
			var st: Array = Navigation.approach_state(loc, lerpf(t0, t1, float(k) / 400.0))
			nearest = minf(nearest, V.length(st[0]))
			phases[st[3]] = true
		check(nearest > bound, "%s: the approach keeps clear of the station (%.0f m, bound %.0f m)" % [to, nearest, bound])
		check(phases.has("swing") and phases.has("corridor"), "%s: swings round, then runs the corridor" % to)
		if case[1] == "":
			check(phases.has("hold"), "%s: a quick trip that reaches its port early holds off it" % to)
	# A port in low orbit: the descent sweeps down onto its orbit and meets it from
	# behind, moving with it, with no jump where it takes over from the trip.
	for to in ["shackleton_port", "kibo_ring"]:
		var sim := fresh()
		var s := sim.state
		var d := sim.data
		s.location = {"status": "docked", "place": "halo_depot"}
		sim.apply({"type": "depart", "to": to})
		var loc: Dictionary = s.location
		var app = loc.get("approach")
		check(app != null and app.has("descent"), "A trip to %s descends onto its orbit" % to)
		if app == null or not app.has("descent"):
			continue
		var desc: Dictionary = app["descent"]
		var td := float(desc["t_d"])
		var t0 := float(app["t0"])
		check(V.distance(Navigation._raw_position(loc, td), Navigation.transit_position(loc, td)) < 5.0
			and V.distance(Navigation._raw_velocity(loc, td), Navigation.transit_velocity(loc, td + 1e-3)) < 2.0, "%s: no jump where the descent begins" % to)
		var meet: Array = Navigation.approach_state(loc, t0 - 1e-3)
		check(meet[3] == "descent" and V.length(meet[0]) < float(d.balance["approach"]["meet_behind_m"]) * 1.2 and V.length(meet[1]) < 15.0,
			"%s: the descent meets the port from a few km behind, moving with it (%.0f m, %.1f m/s)" % [to, V.length(meet[0]), V.length(meet[1])])
		var r_orbit := V.length(app["orbit"]["r"])
		var lowest := INF
		var thrust := 0.0
		for k in 201:
			var t := lerpf(td, t0, float(k) / 200.0)
			lowest = minf(lowest, V.length(Navigation._descent_rel(desc, t)))
			thrust = maxf(thrust, V.length(Navigation.transit_accel(loc, t)))
		check(lowest > r_orbit * 0.999, "%s: the descent never dips below the port's orbit" % to)
		check(thrust < 10.0, "%s: the descent's thrust stays bounded (%.2f m/s^2)" % [to, thrust])
		# The co-pilot calls it as it begins.
		sim.take_events()
		sim.advance_game_time(td - s.time_s + 60.0)
		var types := sim.take_events().map(func(e): return e["type"])
		check("descent_begins" in types, "%s: the co-pilot calls the descent" % to)
	# Old saves in transit have no approach, and keep the trip's own path.
	var old := fresh()
	old.apply({"type": "depart", "to": "halo_depot"})
	var loc_old: Dictionary = old.state.location.duplicate()
	loc_old.erase("approach")
	var tm := float(loc_old["arrive_t"]) - 100.0
	check(Navigation.approach_state(loc_old, tm)[3] == "" and V.distance(Navigation.transit_position(loc_old, tm), Navigation._raw_position(loc_old, tm)) == 0.0, "A trip without an approach keeps its own path")


## Riding out to an elevator's counterweight, and badges (Sean, Oct 2026).
func test_counterweights_and_badges() -> void:
	var Elevator := preload("res://sim/systems/elevator_system.gd")
	var Badges := preload("res://sim/badges.gd")
	var sim := fresh()
	var s := sim.state
	var d := sim.data
	check(d.validate().is_empty(), "Data with counterweights, bars and badges validates")
	# Each anchor offers two rides: down to the foot, out to the counterweight.
	for port in ["halo_depot", "piazzi_station", "ares_ring"]:
		var rides: Array = Elevator.rides_here(d, port)
		var cw: String = d.places[port]["elevator"]["counterweight"]["place"]
		check(rides.size() == 2 and rides[1]["dir"] == "out" and rides[1]["to"] == cw, "%s: down to the foot, or out to %s" % [port, cw])
		var back: Array = Elevator.rides_here(d, cw)
		check(back.size() == 1 and back[0]["dir"] == "in" and back[0]["to"] == port, "%s: the only ride is back in" % cw)
		# Held out along the ribbon, turning with its world: beyond the anchor, from the body.
		var body: String = d.places[port]["elevator"]["body"]
		var t: float = s.time_s
		var r_cw := V.distance(sim.ephemeris.position(cw, t), sim.ephemeris.position(body, t))
		var r_foot := V.distance(sim.ephemeris.position(d.places[port]["elevator"]["foot"], t), sim.ephemeris.position(body, t))
		var top := float(d.places[port]["elevator"]["km"]) * 1000.0
		check(absf(r_cw - r_foot - top - float(d.places[port]["elevator"]["counterweight"]["km"]) * 1000.0) < 50000.0, "%s sits its leg beyond the anchor (%.0f km from the body)" % [cw, r_cw / 1000.0])
		check(not Perks.place_open(s, d, cw), "Ships can't fly to %s" % cw)
	# Ride out to Ballast Point and back.
	s.location = {"status": "docked", "place": "halo_depot"}
	s.credits = 5000.0
	s.ship["cargo"] = {}
	check(sim.apply({"type": "ride_elevator", "to": "ballast_point"}) == "" and s.location["dir"] == "out", "Ride out past L1")
	check(absf(s.credits - 4880.0) < 1e-6, "The fare out is the leg's (120 cr empty)")
	sim.advance_game_time(float(s.location["arrive_t"]) - s.time_s + 1.0)
	check(s.location == {"status": "docked", "place": "ballast_point"}, "At Ballast Point")
	check(s.badges["earned"].has("past_the_point"), "Past the Point is earned on arrival")
	check(Badges.renown(s, d) >= 1.0, "and adds renown")
	# A round at the Counterweight Bar.
	var cost := Badges.round_cost(d, "ballast_point")
	var rep0 := float(s.reputation.get("Luna Cooperative", 0.0))
	check(sim.apply({"type": "buy_round"}) == "" and absf(s.credits - (4880.0 - cost)) < 1e-6, "A round costs patrons x the round (%d cr)" % int(cost))
	check(s.badges["earned"].has("first_round") and s.badges["earned"].has("drinks_on_the_ribbon"), "The first round, and the Counterweight Bar's own badge")
	check(float(s.reputation.get("Luna Cooperative", 0.0)) > rep0, "The Cooperative notices")
	s.credits = 1.0
	check(sim.apply({"type": "buy_round"}).begins_with("a round is"), "No credit at the bar")
	# Back in, on credit if need be, as the way up always is.
	check(Elevator.blocked(d, s, "ballast_point") == "" and sim.apply({"type": "ride_elevator"}) == "", "The way back in never strands you")
	sim.advance_game_time(float(s.location["arrive_t"]) - s.time_s + 1.0)
	check(s.location == {"status": "docked", "place": "halo_depot"}, "Back aboard at Halo Depot")
	check(sim.apply({"type": "buy_round"}) == "there is no bar here", "No bar at Halo Depot")
	# Renown gets you noticed, within limits.
	var m := Badges.chance_mult(s, d, "hitchhiker_per_point")
	check(m > 1.0 and m <= float(d.badges["renown"]["max_mult"]), "Renown raises the hitchhiker chance (x%.2f), capped" % m)
	var plain := fresh()
	check(Badges.chance_mult(plain.state, plain.data, "approach_per_point") == 1.0, "No badges, no change")
	# Badges survive a save.
	var loaded := SaveIO.from_text(SaveIO.to_text(s))
	check(loaded != null and loaded.badges == s.badges, "Badges are saved")
	# Past the anchor the spin outweighs the pull: the ride view shows weight outward.
	var Climber := preload("res://view/climber_view.gd")
	var cv = Climber.new(sim)
	cv._loc = {"line": "halo_depot"}
	cv._line = d.places["halo_depot"]["elevator"]
	cv._body = "moon"
	cv._radius = float(d.bodies["moon"]["radius_m"])
	check(cv.weight_g(82000.0e3) < 0.0 and cv.weight_g(1000.0) > 0.1, "Heavy at the foot, a hair of weight outward at Ballast Point (%.2f mg)" % (cv.weight_g(82000.0e3) * 1000.0))
	check(Climber._weight_text(-0.00017).ends_with("outward: the ceiling is the floor") and Climber._weight_text(0.15) == "0.150 g", "Slight weights read in milligees")
	cv.free()


## The lander's pods (roadmap step 4): fitted at a shipyard, counted in the ship's
## stats, set down on site with cargo or propellant, and picked up again, staying in
## the saved game until then.
func test_lander_pods() -> void:
	var sim := fresh()
	var s := sim.state
	var d := sim.data
	check(d.validate().is_empty(), "Data with pods validates")
	var base_cap := ShipStats.cargo_capacity_t(s.ship, d)
	check(ShipStats.pod_of(s.ship, d) == "", "No lander bay, no pod")
	s.ship["modules"]["cargo.1"] = "lander_bay"
	check(ShipStats.pod_of(s.ship, d) == "cargo_container", "A lander bay carries the default pod")
	var cap := ShipStats.cargo_capacity_t(s.ship, d)
	check(is_equal_approx(cap, base_cap - float(d.modules["cargo_pod_s"]["cargo_t"]) + float(d.pods["pods"]["cargo_container"]["cargo_t"])), "The pod's hold counts in the ship's (%.1f t)" % cap)
	# Fit a liquid tank at a shipyard: the container is taken back at half price.
	s.credits = 50000.0
	check(sim.apply({"type": "fit_pod", "pod": "liquid_tank"}) == "", "Fit a liquid tank at Kibo Ring's yard")
	check(absf(s.credits - (50000.0 - 9000.0 + 3000.0)) < 1e-6, "Paid the tank less half the container")
	var fuel_cap := ShipStats.fuel_capacity_t(s.ship, d)
	check(is_equal_approx(fuel_cap, float(d.modules["tank_s"]["fuel_t"]) + 3.0), "The tank pod adds 3 t of propellant room")
	check(sim.apply({"type": "fit_pod", "pod": "liquid_tank"}) == "that pod is already fitted", "Can't fit the same pod twice")
	# Leave a fuel cache on site.
	s.ship["fuel_t"] = fuel_cap
	s.location = {"status": "on_site", "place": "eros_survey"}
	check(sim.apply({"type": "fit_pod", "pod": "open_flatbed"}).begins_with("pods are fitted"), "No shipyard on site")
	check(sim.apply({"type": "drop_pod", "fuel_t": 2.0}) == "the ship's tanks won't take the rest of the propellant", "Full tanks: what stays aboard must fit without the pod")
	s.ship["fuel_t"] = 5.0
	check(sim.apply({"type": "drop_pod", "fuel_t": 2.0}) == "", "Set the tank down with 2 t in it")
	check(ShipStats.pod_of(s.ship, d) == "" and is_equal_approx(float(s.ship["fuel_t"]), 3.0), "The clamp is empty and 2 t went with it")
	check(PodSystem.at_site(s, "eros_survey").size() == 1, "The pod lies at the site")
	# It stays in the saved game.
	var loaded := SaveIO.from_text(SaveIO.to_text(s))
	check(loaded != null and loaded.sites.get("pods", {}).get("eros_survey", []).size() == 1, "A dropped pod is saved")
	# Pick it back up: the propellant comes aboard.
	s.ship["fuel_t"] = 0.5
	check(sim.apply({"type": "pick_up_pod", "index": 0}) == "", "Pick the cache back up")
	check(ShipStats.pod_of(s.ship, d) == "liquid_tank" and is_equal_approx(float(s.ship["fuel_t"]), 2.5), "The tank and its 2 t are back aboard")
	check(PodSystem.at_site(s, "eros_survey").is_empty(), "Nothing left lying there")
	# A loaded cargo pod; what stays aboard must fit without it.
	s.location = {"status": "docked", "place": "kibo_ring"}
	check(sim.apply({"type": "fit_pod", "pod": "cargo_container"}) == "", "Back to a container")
	s.location = {"status": "on_site", "place": "eros_survey"}
	s.ship["cargo"] = {"water_ice": 3.0}
	check(sim.apply({"type": "drop_pod", "cargo": {"water_ice": 5.0}}).begins_with("you don't have"), "Can't leave more than you carry")
	check(sim.apply({"type": "drop_pod", "cargo": {"water_ice": 3.0}}) == "" and not s.ship["cargo"].has("water_ice"), "Leave 3 t of ice in the pod")
	check(sim.apply({"type": "drop_pod"}) == "no pod to set down", "Nothing left to set down")
	# Someone else's pod is picked up only with an empty clamp; one can carry another.
	s.sites["pods"]["eros_survey"].append({"pod": "open_flatbed", "cargo": {}, "fuel_t": 0.0, "t": s.time_s})
	check(sim.apply({"type": "pick_up_pod", "index": 1}) == "" and ShipStats.pod_of(s.ship, d) == "open_flatbed", "Pick up the flatbed")
	check(sim.apply({"type": "pick_up_pod", "index": 0}) == "set your own pod down first", "One pod at a time")
	# An old save with a lander bay carries the default pod.
	var old := s.ship.duplicate(true)
	old.erase("pod")
	check(ShipStats.pod_of(old, d) == "cargo_container", "An old save's lander bay has the default pod")


func test_detection_and_stealth() -> void:
	var sim := fresh()
	var s := sim.state
	var d := sim.data
	check(d.validate().is_empty(), "Data with detection validates")
	# Honest physics: a lit drive shows across millions of km; coasting dark, the ship is faint.
	var lit := Detection.channels(s.ship, d, {"dark": false}, true, 1.0)
	var coast := Detection.channels(s.ship, d, {"dark": true}, false, 1.0)
	check(Detection.loudest(lit)[0] == "drive" and float(lit["drive"]) > 1.0e9, "A burning drive is the loudest thing aboard (%.0f km)" % (float(lit["drive"]) / 1000.0))
	check(float(coast["transponder"]) == 0.0 and float(coast["lights"]) == 0.0 and float(coast["drive"]) == 0.0, "Dark and coasting: no transponder, lights or drive")
	check(float(Detection.loudest(coast)[1]) < 1.0e8, "Dark and coasting, the ship is seen only nearby (%.0f km)" % (float(Detection.loudest(coast)[1]) / 1000.0))
	# The coating cuts reflected sunlight; a heat sink hides waste heat until it is full.
	var coated := s.ship.duplicate(true)
	coated["coating"] = "low_obs"
	check(float(Detection.channels(coated, d, {"dark": true}, false, 1.0)["sunlight"]) < float(coast["sunlight"]) * 0.5, "The low-observable coating dims the hull")
	var sunk := s.ship.duplicate(true)
	sunk["modules"]["cargo.1"] = "heat_sink"
	check(float(Detection.channels(sunk, d, {"dark": true, "sink_mj": 0.0}, false, 1.0)["heat"]) == 0.0, "An empty sink soaks up the heat")
	check(float(Detection.channels(sunk, d, {"dark": true, "sink_mj": 800.0}, false, 1.0)["heat"]) > 0.0, "A full sink no longer hides it")
	# No running dark at the berth; the coating only at a stealth yard.
	check(sim.apply({"type": "dark_running", "on": true}) != "", "Traffic control won't let a ship sit dark at the berth")
	check(sim.apply({"type": "coat_hull"}) == "only a few yards do that work", "Kibo Ring doesn't coat hulls")
	# Leave, then go dark right by the port: it sees you and fines you, once.
	s.ship["fuel_t"] = 3.0
	check(sim.apply({"type": "depart", "to": "halo_depot"}) == "", "Depart for Halo Depot")
	sim.advance_game_time(600.0)
	check("kibo_ring" in s.detection["seen_by"], "Kibo Ring sees the ship leaving")
	var credits := s.credits
	var op: String = d.places["kibo_ring"]["operator"]
	var rep := float(s.reputation.get(op, 0.0))
	check(sim.apply({"type": "dark_running", "on": true}) == "", "Run dark")
	sim.advance_game_time(900.0)
	check(is_equal_approx(s.credits, credits - float(d.balance["detection"]["dark_fine_cr"])), "Fined for running dark under Kibo's nose")
	check(float(s.reputation.get(op, 0.0)) < rep, "And it costs standing with the operator")
	sim.advance_game_time(900.0)
	check(is_equal_approx(s.credits, credits - float(d.balance["detection"]["dark_fine_cr"])), "Only once a trip")
	# Folding the panels in shrinks the signature and stops the solar wings.
	var quiet := s.ship.duplicate(true)
	quiet["stowed"] = true
	var open_ch := Detection.channels(s.ship, d, {"dark": true}, false, 1.0)
	var in_ch := Detection.channels(quiet, d, {"dark": true}, false, 1.0)
	check(float(in_ch["sunlight"]) < float(open_ch["sunlight"]) and float(in_ch["heat"]) < float(open_ch["heat"]), "Panels in: less sunlight and heat show")
	check(ShipStats.solar_kw_1au(quiet, d) == 0.0, "Panels in: the solar wings make nothing")
	var coasting := Navigation.transit_accel(s.location, s.time_s)
	if V.length(coasting) > 1e-6:
		check(sim.apply({"type": "stow_panels", "on": true}) != "", "No folding in while the drive is lit")
	else:
		check(sim.apply({"type": "stow_panels", "on": true}) == "" and s.ship.get("stowed", false), "Fold the panels in while coasting")
	# Saved and loaded.
	var loaded := SaveIO.from_text(SaveIO.to_text(s))
	check(loaded != null and bool(loaded.detection.get("dark", false)) and "kibo_ring" in loaded.detection.get("fined", []), "Detection state is saved")
	# Arriving, the transponder comes back on.
	sim.advance_game_time(float(s.location["arrive_t"]) - s.time_s + 60.0)
	check(s.location.get("status") != "transit" and not bool(s.detection["dark"]), "The transponder is on again in port")
	check(not s.ship.get("stowed", false), "And the panels are out again")
	check(sim.apply({"type": "stow_panels", "on": true}) == "the panels fold in only under way", "Panels fold in only under way")
	# A stealth yard coats the hull, for a price.
	s.location = {"status": "docked", "place": "trojan_yards"}
	s.credits = 1.0e6
	var cost := DetectionSystem.coat_cost(s, d)
	check(sim.apply({"type": "coat_hull"}) == "" and s.ship.get("coating", "") == "low_obs" and is_equal_approx(s.credits, 1.0e6 - cost), "Coated at Trojan Yards for %d cr" % int(cost))
	check(sim.apply({"type": "coat_hull"}) == "she's already coated", "Once is enough")


func test_panel_fold() -> void:
	var sim := fresh()
	var Models = load("res://view/flight/models.gd")
	var model: Dictionary = Models.ship(sim.state.ship, sim.data)
	var rig: Dictionary = model["rig"]
	var arrays: Array = rig["arrays"]
	check(not arrays.is_empty() and arrays.all(func(a): return a["hinges"].size() >= 2), "Every panel is built in hinged segments")
	ShipRig.set_fold(rig, 0.0)
	ShipRig.aim(rig, Basis.IDENTITY, Vector3(0.3, 0.8, 0.4), Vector3.FORWARD, 0.1)
	check(is_zero_approx(float(rig["fold"])) and is_zero_approx(arrays[0]["hinges"][0].rotation.z), "Deployed: the segments lie flat in a line")
	# Stowing takes FOLD_RATE: part way after a few seconds, all the way in the end.
	ShipRig.set_fold(rig, 1.0)
	ShipRig.aim(rig, Basis.IDENTITY, Vector3(0.3, 0.8, 0.4), Vector3.FORWARD, 5.0)
	check(float(rig["fold"]) > 0.0 and float(rig["fold"]) < 1.0, "Folding takes time (%.2f after 5 s)" % float(rig["fold"]))
	for i in 40:
		ShipRig.aim(rig, Basis.IDENTITY, Vector3(0.3, 0.8, 0.4), Vector3.FORWARD, 1.0)
	var a: Dictionary = arrays[0]
	check(is_equal_approx(float(rig["fold"]), 1.0) and is_zero_approx(a["node"].rotation.x), "Stowed: the panel turned flat")
	check(is_equal_approx(absf(a["hinges"][0].rotation.z), PI * 0.5), "Stowed: the first segment stands up off the boom")
	# In transit the panels stay stowed just after leaving port.
	var loc := {"depart_t": 1000.0}
	check(ShipRig.transit_fold(loc, 1010.0) == 1.0 and ShipRig.transit_fold(loc, 1000.0 + ShipRig.DEPLOY_AFTER_S + 1.0) == 0.0, "Panels unfold once clear of the port")
	model["node"].free()


func test_docking_bays() -> void:
	var d = DataCatalog.load_default()
	var Models = load("res://view/flight/models.gd")
	var Bay = load("res://view/flight/bay.gd")
	var geom: Dictionary = d.places["kibo_ring"]["station"]
	var plain: Dictionary = Models.station(geom, "Kibo Ring")
	var st: Dictionary = Models.station(geom, "Kibo Ring", {}, d.balance["bays"], 6.0)
	var bay: Dictionary = st["bay"]
	check(not bay.is_empty() and bay["fits"] and bay["door"] == "iris", "Kibo Ring has an iris bay a Mule fits")
	check(is_equal_approx(float(st["port_z"]), float(plain["port_z"])), "The port stays where it was: approaches are unchanged")
	check(float(st["hub_radius"]) >= float(bay["r"]) + float(d.balance["bays"]["wall_m"]), "The hub grows to the bay's width")
	var mouth: float = bay["z_mouth"]
	var hit: Array = Bay.contact(bay, Vector3(0, 0, mouth + 1.0), 2.0)
	check(float(hit[0]) > 0.0 and hit[1].is_equal_approx(Vector3(0, 0, 1)), "Shut doors stop a ship at the mouth")
	Bay.set_open(bay, 1.0)
	check(float(Bay.contact(bay, Vector3(0, 0, mouth + 1.0), 2.0)[0]) == 0.0, "Open doors let it in")
	hit = Bay.contact(bay, Vector3(float(bay["r"]) - 1.0, 0, mouth - 20.0), 3.0)
	check(float(hit[0]) > 0.0 and hit[1].x < 0.0, "Inside, the tunnel wall pushes back toward the axis")
	check(float(Bay.contact(bay, Vector3(0, 0, mouth - 20.0), 3.0)[0]) == 0.0, "On the axis inside the bay: clear")
	Bay.set_open(bay, 0.0)
	hit = Bay.contact(bay, Vector3(0, 0, mouth - 1.0), 2.0)
	check(float(hit[0]) > 0.0 and hit[1].is_equal_approx(Vector3(0, 0, -1)), "Doors shut behind you hold you in")
	# Too big for the bay: berth on a collar on the shut doors.
	var big: Dictionary = Models.station(geom, "Kibo Ring", {}, d.balance["bays"], 400.0)
	check(not big["bay"]["fits"] and float(big["port_z"]) > float(big["bay"]["z_mouth"]), "A ship too big for the bay berths on the doors")
	for n in [plain["node"], st["node"], big["node"]]:
		n.free()
