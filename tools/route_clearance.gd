## Route clearance check: does any route pass through a body, its atmosphere or
## Saturn's main rings?
##   godot --headless --path . --script res://tools/route_clearance.gd -- [days=0,97,211] [options=1]
## For every pair of ports, at each departure day, it plans the trip the way the
## game does:
##   - the quick plan (Navigation.plan), which NPC traffic and contracts use too
##   - with options=1, the co-pilot's gravity-flown options (express, economy and
##     flybys) for trips inside the Earth-Moon system
## Then it walks the path at 600 points, checking each against every body.
##   - Each body is cleared by its radius plus its visible atmosphere (look.atmosphere
##     thickness, as the renderer draws it), and at least 20 km above the ground
##     (the Moon's highest peaks are about 11 km).
##   - Near a surface port the body it stands on is left out: the descent has to
##     touch it.
##   - Any crossing of Saturn's ring plane between 1.11 and 2.27 radii counts.
## Prints one line per violation, then ROUTES_CLEAR or ROUTES_BLOCKED n.
extends SceneTree

const Sim := preload("res://sim/sim.gd")
const Navigation := preload("res://sim/navigation.gd")
const TravelSystem := preload("res://sim/systems/travel_system.gd")
const V := preload("res://sim/v3.gd")
const Interplanetary := preload("res://sim/interplanetary.gd")
const ShipStats := preload("res://sim/ship_stats.gd")

const SAMPLES := 600
const MIN_CLEAR_M := 20.0e3
const RING_IN := 1.11
const RING_OUT := 2.27
const OBLIQUITY := deg_to_rad(23.4393)

var sim: Sim
var clear_r := {}
var violations := 0
var checked := 0


func _initialize() -> void:
	var days := [0.0, 97.0, 211.0]
	var options := true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("days="):
			days = []
			for d in a.trim_prefix("days=").split(","):
				days.append(float(d))
		if a.begins_with("options="):
			options = a.trim_prefix("options=") == "1"
	sim = Sim.new()
	sim.new_game(7)
	var data = sim.data
	for id in data.bodies:
		var b = data.bodies[id]
		if not (b is Dictionary) or not b.has("radius_m"):
			continue
		var r := float(b["radius_m"])
		var atm: Dictionary = b.get("look", {}).get("atmosphere", {})
		clear_r[id] = maxf(r * (1.0 + float(atm.get("thickness", 0.0))), r + MIN_CLEAR_M)
	# A ship that can fly everywhere: the deep freighter's hull and modules, tanks full.
	var hull: Dictionary = data.ships["deep_freighter"]
	var ship := {"hull": "deep_freighter", "modules": hull["modules"].duplicate(), "cargo": {}, "fuel_t": 400.0, "name": "Clearance"}
	var ports := []
	for id in data.places:
		var p: Dictionary = data.places[id]
		if not p.has("foot_of"):
			ports.append(id)
	var t0: float = sim.state.time_s
	for day in days:
		var t: float = t0 + float(day) * 86400.0
		for a in ports:
			for b in ports:
				if a == b:
					continue
				var plan := Navigation.plan(ship, data, sim.ephemeris, a, b, t)
				if plan.has("from_pos"):
					_check(_location(plan, a, b, t), "quick", a, b, day)
				if options and plan.get("frame", "") == "earth":
					for o in TravelSystem.plan_for(ship, data, sim.ephemeris, a, b, t):
						if o.get("samples") != null:
							_check(_sampled(o, a, b, t, ship), String(o["id"]), a, b, day)
	print("checked %d routes" % checked)
	print("ROUTES_CLEAR" if violations == 0 else "ROUTES_BLOCKED %d" % violations)
	quit(0 if violations == 0 else 1)


func _location(plan: Dictionary, a: String, b: String, t: float) -> Dictionary:
	var loc := {
		"status": "transit", "from": a, "to": b, "frame": plan["frame"], "depart_t": t, "arrive_t": plan["arrive_t"],
		"burn_s": plan["burn_s"], "from_pos": plan["from_pos"], "to_pos": plan["to_pos"],
		"from_vel": plan.get("from_vel"), "to_vel": plan.get("to_vel"), "from_rot": plan.get("from_rot"),
		"to_rot": plan.get("to_rot"), "rot_axis": plan.get("rot_axis"), "rot_angle": plan.get("rot_angle", 0.0),
		"samples": plan.get("samples"), "around": plan.get("around"), "around_r": plan.get("around_r", 0.0), "avoid": plan.get("avoid"),
	}
	if plan.get("samples") == null:
		var duration := float(plan["arrive_t"]) - t
		var start := t + (duration - float(plan["burn_s"])) * 0.5
		var tracks := Navigation.port_tracks(sim.ephemeris, a, b, plan["frame"], t, start, start + float(plan["burn_s"]), float(plan["arrive_t"]))
		loc["pre_track"] = tracks[0]
		loc["post_track"] = tracks[1]
	return loc


func _sampled(o: Dictionary, a: String, b: String, t: float, ship: Dictionary) -> Dictionary:
	var frame: String = o.get("frame", "earth")
	var arrive := float(o["arrive_t"])
	var samples: Array = o["samples"]
	if frame == "sun":
		samples = Interplanetary.dress(samples, sim.data, sim.ephemeris, a, b, t, arrive, ShipStats.accel_mps2(ship, sim.data))
	return {"status": "transit", "from": a, "to": b, "frame": frame, "depart_t": t, "arrive_t": arrive,
		"burn_s": 0.0, "from_pos": sim.ephemeris.relative(a, frame, t), "to_pos": sim.ephemeris.relative(b, frame, arrive),
		"samples": samples, "avoid": Navigation.sampled_avoid(sim.data, sim.ephemeris, a, b, frame, t, arrive) if frame != "sun" else null}


## The Saturn ring plane's normal in the ecliptic frame, from the pole's RA and Dec.
func _pole(body: Dictionary) -> Array:
	var ra := deg_to_rad(float(body.get("pole_ra_deg", 0.0)))
	var dec := deg_to_rad(float(body.get("pole_dec_deg", 90.0)))
	var eq := [cos(dec) * cos(ra), cos(dec) * sin(ra), sin(dec)]
	return [eq[0], eq[1] * cos(OBLIQUITY) + eq[2] * sin(OBLIQUITY), -eq[1] * sin(OBLIQUITY) + eq[2] * cos(OBLIQUITY)]


func _check(loc: Dictionary, kind: String, a: String, b: String, day: float) -> void:
	checked += 1
	var eph = sim.ephemeris
	var data = sim.data
	var t0 := float(loc["depart_t"])
	var t1 := float(loc["arrive_t"])
	var frame: String = loc["frame"]
	var start: Array = eph.position(a, t0)
	var end: Array = eph.position(b, t1)
	var worst := {}
	var saturn_pole := _pole(data.bodies["saturn"])
	var prev_side := 0.0
	var prev_rel := []
	for i in SAMPLES + 1:
		var t := lerpf(t0, t1, float(i) / float(SAMPLES))
		var here := V.add(eph.position(frame, t), Navigation.transit_position(loc, t))
		for id in clear_r:
			var c: Array = eph.position(id, t)
			var d := V.distance(here, c)
			var need: float = clear_r[id]
			if d >= need:
				continue
			# A surface port's own body: the climb out and the descent touch it.
			if V.distance(start, c) < need * 1.01 and V.distance(here, start) < need * 2.0:
				continue
			if V.distance(end, eph.position(id, t1)) < need * 1.01 and V.distance(here, end) < need * 2.0:
				continue
			var depth := need - d
			if worst.is_empty() or depth > float(worst["depth"]):
				worst = {"body": id, "depth": depth, "alt": d - float(data.bodies[id]["radius_m"]), "f": float(i) / float(SAMPLES)}
		# Saturn's main rings: a crossing of the ring plane inside them.
		var rel := V.sub(here, eph.position("saturn", t))
		var side := V.dot(rel, saturn_pole)
		if i > 0 and signf(side) != signf(prev_side) and prev_side != 0.0:
			var f := prev_side / (prev_side - side)
			var cross := V.lerp(prev_rel, rel, f)
			var rs := float(data.bodies["saturn"]["radius_m"])
			var rr := V.length(cross) / rs
			if rr > RING_IN and rr < RING_OUT:
				worst = {"body": "saturn rings", "depth": 0.0, "alt": rr, "f": float(i) / float(SAMPLES)}
		prev_side = side
		prev_rel = rel
	if not worst.is_empty():
		violations += 1
		if worst["body"] == "saturn rings":
			print("BLOCKED %-8s day %3d  %s -> %s crosses Saturn's rings at %.2f Rs (%.0f%% of the way)" % [kind, int(day), a, b, worst["alt"], worst["f"] * 100.0])
		else:
			print("BLOCKED %-8s day %3d  %s -> %s through %s: %.0f km altitude, %.0f km inside clearance (%.0f%% of the way)" % [kind, int(day), a, b, worst["body"], worst["alt"] / 1000.0, worst["depth"] / 1000.0, worst["f"] * 100.0])
