## Regression for traffic in the docking scene (sim/traffic.gd, view/flight/pattern.gd):
## a ship ahead in the pattern goes through the bay first while we hold, a ship behind
## waits for us, and the radio says so, at a port with a tower and at one without.
extends SceneTree

const Sim := preload("res://sim/sim.gd")
const FlightScene := preload("res://view/flight/flight_scene.gd")
const Autopilot := preload("res://view/flight/autopilot.gd")
const Traffic := preload("res://sim/traffic.gd")
const Pattern := preload("res://view/flight/pattern.gd")
const Models := preload("res://view/flight/models.gd")

var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)


## The first local inbound movement at `place` an hour or more from now.
func _inbound(sim, place: String) -> Dictionary:
	var t0: float = sim.state.time_s + 3600.0
	for m in Traffic.movements(sim.state, sim.data, place, t0, t0 + 86400.0):
		if m.has("local") and m["kind"] == "in":
			# Nobody else in the bay for a while either side.
			var near: Array = Traffic.movements(sim.state, sim.data, place, float(m["t"]) - 400.0, float(m["t"]) + 400.0)
			if near.size() == 1:
				return m
	return {}


## Fly the approach on the docking computer with the world running at x1, starting
## `lead` seconds before movement m. Returns what happened.
func _fly(place: String, lead: float, m_pick := {}) -> Dictionary:
	var sim := Sim.new()
	sim.new_game(42)
	var m: Dictionary = m_pick if not m_pick.is_empty() else _inbound(sim, place)
	check(not m.is_empty(), place + ": a quiet hour with one local ship coming in")
	sim.state.time_s = float(m["t"]) - lead
	sim.state.location = {"status": "approach", "place": place}
	var flight: FlightScene = FlightScene.new(sim)
	root.add_child(flight)
	var k := Pattern.key(m)
	var out := {"m": m, "key": k, "flight": flight, "saw": false, "npc_doors": 0.0, "cleared_t": INF, "ahead": false, "held": false, "behind_ok": true}
	out["ahead"] = flight.tc["ahead"].any(func(x): return Pattern.key(x) == k)
	out["held"] = flight._pattern.held.has(k)
	var steps := 0
	while not flight.docked and steps < 60 * 900:
		flight.control_override = Autopilot.controls(flight)
		sim.tick(1.0 / 60.0)
		flight._physics_process(1.0 / 60.0)
		var t: float = sim.state.time_s
		if flight._pattern.ships.has(k):
			out["saw"] = true
			var e: Dictionary = flight._pattern.ships[k]
			if flight._pattern.held.has(k) and (e["ship"] as Node3D).position.z < flight.ship_node.position.z:
				out["behind_ok"] = false
		if not flight.cleared():
			out["npc_doors"] = maxf(float(out["npc_doors"]), flight._pattern.door_open(t))
		elif out["cleared_t"] == INF:
			out["cleared_t"] = t
		steps += 1
	out["docked"] = flight.docked
	out["radio"] = "\n".join(flight.radio_log)
	print("TRAFFIC %s lead=%.0f docked=%s held_for=%.0f s hits=%d contacts=%d\n%s" % [place, lead, flight.docked, float(out["cleared_t"]) - (float(m["t"]) - lead), flight.hits, flight.bumps, out["radio"]])
	return out


func _run() -> void:
	# A tower: a ship a minute ahead of us goes in first; we're number 2.
	var a := _fly("kibo_ring", 60.0)
	var name: String = Pattern.who(a["flight"].sim, "kibo_ring", a["m"])["name"]
	check(a["ahead"] and not a["held"], "Kibo Ring: the ship already closer in goes first")
	check(String(a["radio"]).contains("number 2 for the bay"), "Kibo Ring: the tower gives us our number")
	check(String(a["radio"]).contains("%s, cleared in." % name), "Kibo Ring: and clears the %s in" % name)
	check(a["saw"], "Kibo Ring: the %s is seen flying the pattern" % name)
	check(float(a["npc_doors"]) > 0.99, "Kibo Ring: the doors open for it while we hold")
	check(float(a["cleared_t"]) >= float(a["m"]["end"]) - 0.01, "Kibo Ring: we're cleared only once it's in and the doors are shut")
	check(a["docked"] and a["flight"].hits == 0 and a["flight"].bumps == 0, "Kibo Ring: then we dock, touching nothing")
	# A ship well behind us waits its turn, behind us.
	var b := _fly("kibo_ring", 330.0)
	check(b["held"] and not b["ahead"], "Kibo Ring: a ship further out than us is held behind")
	check(b["behind_ok"], "Kibo Ring: and stays behind us on the axis")
	check(b["docked"] and b["flight"].hits == 0 and b["flight"].bumps == 0, "Kibo Ring: we dock first, touching nothing")
	# No tower: the other pilot calls it, we give way, then take the bay ourselves.
	var c := _fly("piazzi_station", 30.0)
	var cname: String = Pattern.who(c["flight"].sim, "piazzi_station", c["m"])["name"]
	check(String(c["radio"]).contains("Piazzi Station traffic, %s, inbound for the bay." % cname), "Piazzi Station: the %s calls its approach" % cname)
	check(String(c["radio"]).contains("going in"), "Piazzi Station: we call ours")
	check(not String(c["radio"]).contains("Control"), "Piazzi Station: no tower")
	check(float(c["cleared_t"]) >= float(c["m"]["end"]) - 0.01, "Piazzi Station: we take the bay once the %s is through" % cname)
	check(c["docked"] and c["flight"].hits == 0 and c["flight"].bumps == 0, "Piazzi Station: then we dock, touching nothing")
	_queue_without_collisions()
	_group_craft()
	print("%d checks, %d failures (traffic view)" % [checks, failures])
	quit(1 if failures > 0 else 0)


## Some of a port's own craft belong to the cap's-off groups that call it home, flying
## their colours; none at a port no group calls home.
func _group_craft() -> void:
	var sim := Sim.new()
	sim.new_game(42)
	var d = sim.data
	var Livery := preload("res://view/flight/livery.gd")
	var home: Array = d.groups_at("kibo_ring").map(func(g): return g["name"])
	var theirs := 0
	var fit := true
	for k in 400:
		var w := Pattern.who(sim, "kibo_ring", {"local": k})
		if w["operator"] in home:
			theirs += 1
			var g: Dictionary = d.group_named(w["operator"])
			fit = fit and w["name"] in g["ships"] and Livery.for_ship(d, w["operator"], w["name"])["hull"] == Color(g["colours"]["hull"])
	var share := float(theirs) / 400.0
	check(absf(share - float(d.groups_meta["traffic_share"])) < 0.1, "Kibo Ring: about %.0f%% of its craft are the groups' (%.0f%%)" % [100.0 * float(d.groups_meta["traffic_share"]), 100.0 * share])
	check(fit, "Kibo Ring: a group's craft carries one of its names and its colours")
	var bare: String = d.places.keys().filter(func(p): return d.places[p].has("station") and d.groups_at(p).is_empty())[0]
	var none := range(100).all(func(k): return Pattern.who(sim, bare, {"local": k})["operator"] == d.places[bare].get("operator", ""))
	check(none, "%s: no group calls it home, so all its craft are the port's" % bare)


## A busy spell at Kibo Ring: two long-haul ships due at once, one leaving just before
## and the local craft. Outside the bay, no drawn ship ever passes through another, and
## ships held for the bay queue one behind another.
func _queue_without_collisions() -> void:
	var sim := Sim.new()
	sim.new_game(42)
	var d = sim.data
	var cycle := float(d.balance["traffic"]["cycle_s"])
	var t0: float = sim.state.time_s
	var due := t0 + 1800.0
	var npcs: Array = sim.state.npcs.filter(func(n): return not d.npcs["fleets"][n["fleet"]].get("sail", false) and not d.npcs["fleets"][n["fleet"]].get("elevator", false)).slice(0, 3)
	for i in 2:
		npcs[i]["location"] = {"status": "transit", "from": "halo_depot", "to": "kibo_ring", "depart_t": t0 - 86400.0, "arrive_t": due + cycle}
	npcs[2]["location"] = {"status": "transit", "from": "kibo_ring", "to": "halo_depot", "depart_t": due - 20.0, "arrive_t": due + 86400.0}
	var holder := Node3D.new()
	root.add_child(holder)
	var st := Models.station(d.places["kibo_ring"]["station"], "", {}, d.balance["bays"], 5.0)
	holder.add_child(st["node"])
	var pattern = Pattern.new(sim, "kibo_ring", st, st["node"])
	var z_mouth := float(st["bay"]["z_mouth"])
	var worst := INF
	var pair := ""
	var t := due - 600.0
	while t < due + 900.0:
		sim.state.time_s = t
		pattern.sync(t)
		pattern.update(t, 1.0, 0.0, Vector3.UP)
		var keys: Array = pattern.ships.keys()
		for i in keys.size():
			for j in range(i + 1, keys.size()):
				var a: Dictionary = pattern.ships[keys[i]]
				var b: Dictionary = pattern.ships[keys[j]]
				var na: Vector3 = (a["node"] as Node3D).position + Vector3(0, 0, float(a["nose_z"]))
				var nb: Vector3 = (b["node"] as Node3D).position + Vector3(0, 0, float(b["nose_z"]))
				if na.z < z_mouth or nb.z < z_mouth:
					continue
				var margin := na.distance_to(nb) - float(a["radius"]) - float(b["radius"])
				if margin < worst:
					worst = margin
					pair = "%s and %s at %+.0f s" % [a["name"], b["name"], t - due]
		t += 1.0
	check(worst > 0.0, "Kibo Ring: queued traffic never flies through itself (closest %s, %.0f m clear)" % [pair, worst])
	# Held for the bay (a ship using it), two inbound ships queue apart.
	pattern.clear()
	pattern.held.clear()
	sim.state.time_s = due
	for m in pattern.sync(due):
		if m["kind"] == "in":
			pattern.held[Pattern.key(m)] = true
	pattern.sync(due)
	for _i in 120:
		pattern.update(due, 1.0, 0.0, Vector3.UP, 300.0)
	var waiting: Array = pattern.ships.keys().filter(func(k): return pattern.held.has(k))
	var spaced := waiting.size() >= 2
	for i in waiting.size():
		for j in range(i + 1, waiting.size()):
			spaced = spaced and (pattern.ships[waiting[i]]["node"] as Node3D).position.distance_to((pattern.ships[waiting[j]]["node"] as Node3D).position) > float(d.balance["traffic"]["separation_m"]) * 0.9
	check(spaced, "Kibo Ring: %d ships held behind us wait one behind another" % waiting.size())
	pattern.clear()
	holder.free()
