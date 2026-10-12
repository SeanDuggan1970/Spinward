## Regression for traffic in the docking scene (sim/traffic.gd, view/flight/pattern.gd):
## a ship ahead in the pattern goes through the bay first while we hold, a ship behind
## waits for us, and the radio says so, at a port with a tower and at one without.
extends SceneTree

const Sim := preload("res://sim/sim.gd")
const FlightScene := preload("res://view/flight/flight_scene.gd")
const Autopilot := preload("res://view/flight/autopilot.gd")
const Traffic := preload("res://sim/traffic.gd")
const Pattern := preload("res://view/flight/pattern.gd")

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
	print("%d checks, %d failures (traffic view)" % [checks, failures])
	quit(1 if failures > 0 else 0)
