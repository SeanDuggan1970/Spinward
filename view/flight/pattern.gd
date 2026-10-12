## Ships in a port's traffic pattern (sim/traffic.gd), drawn about the station's
## docking axis, in the station's own frame (axis along Z, the bay's mouth facing +Z).
## Inbound ships close along the axis to the gate (balance.traffic.gate_m off the bay's
## doors), wait there while the doors open, and go in. Outbound ships back out of the
## hall to the gate and peel away off the axis. View-only: where a ship is follows
## from its scheduled movement and the time, except for movements `held` behind the
## pilot's own use of the bay, which wait outside, keeping their distance behind the
## pilot's ship.
extends RefCounted

const Traffic := preload("res://sim/traffic.gd")
const Models := preload("res://view/flight/models.gd")
const Livery := preload("res://view/flight/livery.gd")
const ShipRig := preload("res://view/flight/ship_rig.gd")
const Kit := preload("res://view/flight/kit.gd")
const Bay := preload("res://view/flight/bay.gd")

var sim
var place: String
var station: Dictionary
var parent: Node3D
var cfg: Dictionary
var door_s := 12.0
## Movement key -> {m, node, ship, rig, radius, nose_z, fits, d (held: metres off the
## mouth), layer}.
var ships: Dictionary = {}
## Movement keys waiting behind the pilot's use of the bay.
var held: Dictionary = {}
## Movements seen so far (key -> movement), newest schedule.
var known: Dictionary = {}
var _synced := -INF


func _init(owner_sim, place_id: String, station_model: Dictionary, holder: Node3D) -> void:
	sim = owner_sim
	place = place_id
	station = station_model
	parent = holder
	cfg = sim.data.balance["traffic"]
	door_s = float(sim.data.balance["bays"]["door_s"])


static func key(m: Dictionary) -> String:
	return String(m["npc"]) if m.has("npc") else "local.%d" % int(m["local"])


## Who is flying a movement: {name, hull, operator, ship (a ship state for Models.ship)}.
## Local craft get a name and hull from data/npcs.json local_traffic, by hash.
static func who(sim_ref, place_id: String, m: Dictionary) -> Dictionary:
	if m.has("npc"):
		for npc in sim_ref.state.npcs:
			if npc["id"] == m["npc"]:
				return {"name": npc["name"], "hull": npc["ship"]["hull"], "operator": sim_ref.data.npcs["fleets"][npc["fleet"]]["operator"], "ship": npc["ship"]}
		return {}
	var lt: Dictionary = sim_ref.data.npcs["local_traffic"]
	var h := absi(hash("%s:%d" % [place_id, int(m["local"])]))
	var names: Array = lt["names"]
	var hulls: Array = lt["hulls"]
	var hull: String = hulls[(h / 7) % hulls.size()]
	return {"name": names[h % names.size()], "hull": hull, "operator": sim_ref.data.places[place_id].get("operator", ""),
		"ship": {"hull": hull, "modules": sim_ref.data.ships[hull]["modules"].duplicate(), "cargo": {}, "fuel_t": 0.0}}


## "the Moth (Kernel passenger shuttle)", for radio lines.
static func describe(sim_ref, place_id: String, m: Dictionary) -> String:
	var w := who(sim_ref, place_id, m)
	if w.is_empty():
		return "a ship"
	return "the %s (%s)" % [w["name"], String(sim_ref.data.ships[w["hull"]]["name"])]


## Movements at this port in a window about t, refreshed once a second.
func schedule(t: float) -> Array:
	var horizon := float(cfg["horizon_s"])
	var list: Array = Traffic.movements(sim.state, sim.data, place, t - float(cfg["cycle_s"]) - float(cfg["peel_s"]), t + horizon)
	for m in list:
		known[key(m)] = m
	return list


## Bring the drawn ships in line with the schedule: add the ones now in view, drop the
## ones gone (inside with the doors shut, or away down the lanes).
func sync(t: float) -> Array:
	var list := schedule(t)
	var want := {}
	for m in list:
		var k := key(m)
		if _visible(m, t, held.has(k)):
			want[k] = m
	for k in ships.keys():
		if not want.has(k):
			ships[k]["node"].queue_free()
			ships.erase(k)
	for k in want:
		if ships.has(k):
			ships[k]["m"] = want[k]
			continue
		var m: Dictionary = want[k]
		var w := who(sim, place, m)
		if w.is_empty():
			continue
		var model := Models.ship(w["ship"], sim.data, Livery.for_ship(sim.data, w["operator"], w["name"]))
		var node: Node3D = model["node"]
		var plume := node.find_child("DrivePlume", true, false)
		if plume:
			plume.visible = false
		# A bright running light so the pattern reads from far out.
		node.add_child(Kit.sphere(1.6, Kit.glow(Color("ffe0a0"), 4.0), Vector3(0, 3.0, 0)))
		parent.add_child(node)
		var bay: Dictionary = station.get("bay", {})
		var fits: bool = not bay.is_empty() and ShipRig.stowed_radius(model) + float(sim.data.balance["bays"]["clearance_m"]) <= float(bay["r"])
		ShipRig.set_fold(model["rig"], 1.0, true)
		ships[k] = {"m": m, "node": node, "ship": node, "rig": model["rig"], "radius": float(model["radius"]), "nose_z": float(model["nose_z"]),
			"fits": fits, "d": INF, "layer": 1, "name": w["name"]}
	return list


## Shown: inbound from horizon_s before the movement until it is in and the doors are
## shut; outbound from when it starts backing out until peel_s after.
func _visible(m: Dictionary, t: float, is_held: bool) -> bool:
	var ts := float(m["t"])
	var te := float(m["end"])
	if m["kind"] == "in":
		if m.has("npc") and not _npc_inbound(m["npc"]):
			return false
		return is_held or (t >= ts - float(cfg["horizon_s"]) and t < te)
	# A long-haul ship leaving is in its cradle until the sim lets it go.
	if is_held or (m.has("npc") and not _npc_left(m["npc"])):
		return false
	return t >= ts + door_s * 0.8 and t < te + float(cfg["peel_s"])


func _npc_inbound(id: String) -> bool:
	for npc in sim.state.npcs:
		if npc["id"] == id:
			return npc["location"].get("status") == "transit" and npc["location"].get("to") == place
	return false


func _npc_left(id: String) -> bool:
	for npc in sim.state.npcs:
		if npc["id"] == id:
			return npc["location"].get("status") == "transit" and npc["location"].get("from") == place
	return false


## Is this long-haul ship flying the pattern now (so the lanes leave it alone)?
func flying(id: String) -> bool:
	return ships.has(id)


## How far open the doors must be for the ships moving now (0 to 1).
func door_open(t: float) -> float:
	var want := 0.0
	for k in known:
		if held.has(k):
			continue
		var m: Dictionary = known[k]
		var ts := float(m["t"])
		var te := float(m["end"])
		if t < ts or t >= te or (ships.has(k) and not ships[k]["fits"]):
			continue
		want = maxf(want, minf(clampf((t - ts) / door_s, 0.0, 1.0), clampf((te - t) / door_s, 0.0, 1.0)))
	return want


## The movement using the bay at t (doors opening, open or closing for it), or {}.
func busy(t: float, lead := 0.0) -> Dictionary:
	for k in known:
		if held.has(k):
			continue
		var m: Dictionary = known[k]
		if t >= float(m["t"]) - lead and t < float(m["end"]):
			return m
	return {}


## Place every ship for time t. pilot_d: the pilot's nose's distance off the mouth
## along the axis (INF with no pilot about); held ships keep separation_m behind it.
## aside: held inbound ships wait this far off the axis (giving way to a ship leaving).
func update(t: float, dt: float, spin_angle: float, sun: Vector3, pilot_d := INF, aside := 0.0) -> void:
	var bay: Dictionary = station.get("bay", {})
	if bay.is_empty():
		return
	var z_mouth := float(bay["z_mouth"])
	var z_mid := float(bay.get("z_mid", bay["z_back"]))
	var gate := float(cfg["gate_m"])
	var in_speed := float(cfg["in_speed_mps"])
	var lane_r: float = maxf(float(station["ring_radius"]) + float(station["ring_tube"]), float(station["hub_radius"])) + 60.0
	for k in ships:
		var e: Dictionary = ships[k]
		var m: Dictionary = e["m"]
		var node: Node3D = e["node"]
		var ts := float(m["t"])
		var te := float(m["end"])
		var nose_z := float(e["nose_z"])
		var spin_matched := false
		var pos := Vector3.ZERO
		var fold := 1.0
		var d := 0.0
		if m["kind"] == "in":
			var run_from := ts + door_s * 0.6
			var run_to := te - door_s - 2.0
			if held.has(k) or t < run_from:
				# Closing on the gate; held, waiting a separation behind the pilot.
				d = gate + in_speed * maxf(ts - t, 0.0)
				if held.has(k):
					d = maxf(gate, pilot_d + float(cfg["separation_m"])) if pilot_d < INF else maxf(d, gate)
				if e["d"] < INF and dt > 0.0:
					d = move_toward(float(e["d"]), d, float(cfg["max_shuffle_mps"]) * dt)
				e["d"] = d
				pos = Vector3(0, 0, z_mouth + d - nose_z)
				if held.has(k) and aside > 0.0:
					var a := float(absi(hash(k)) % 360) * PI / 180.0
					pos += Vector3(cos(a), sin(a), 0.0) * aside
				spin_matched = d < gate * 1.5
				fold = 1.0 if d < gate * 4.0 else 0.0
			elif not e["fits"]:
				# Too big for the bay: in to a collar on the shut doors.
				var f := _ease((t - run_from) / maxf(run_to - run_from, 1.0))
				pos = Vector3(0, 0, z_mouth + lerpf(gate, 2.4, f) - nose_z)
				spin_matched = true
			else:
				var f := _ease((t - run_from) / maxf(run_to - run_from, 1.0))
				pos = Vector3(0, 0, lerpf(z_mouth + gate - nose_z, z_mid, f))
				spin_matched = true
		else:
			var back_from := ts + door_s * 0.8
			var back_to := te - door_s - 2.0
			var out_z := z_mouth + gate - nose_z
			if t < back_to:
				var f := _ease((t - back_from) / maxf(back_to - back_from, 1.0))
				pos = Vector3(0, 0, lerpf(z_mid, out_z, f))
				spin_matched = true
			else:
				# Clear of the doors: off the axis and away, panels out.
				var tau := t - back_to
				var a := float(absi(hash(k)) % 360) * PI / 180.0
				var off := Vector3(cos(a), sin(a), 0.0) * lane_r * _ease(tau / 40.0)
				pos = off + Vector3(0, 0, out_z + 2.0 * tau + 0.08 * tau * tau)
				fold = 1.0 if tau < 15.0 else 0.0
				spin_matched = tau < 6.0
		node.position = pos
		node.basis = Basis(Vector3.BACK, spin_angle) if spin_matched else ShipRig.roll_to_sun(Vector3.FORWARD, sun)
		# Inside the hall only the hall's lamps light it.
		var layer := Bay.INTERIOR_LAYER if pos.z + nose_z < z_mouth - 2.0 else 1
		if layer != int(e["layer"]):
			e["layer"] = layer
			for g in node.find_children("*", "GeometryInstance3D", true, false):
				(g as GeometryInstance3D).layers = layer
		ShipRig.set_fold(e["rig"], fold)
		ShipRig.aim(e["rig"], node.basis, sun, -node.position if m["kind"] == "in" else Vector3.BACK * 1.0e6, dt)


static func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func clear() -> void:
	for k in ships:
		ships[k]["node"].queue_free()
	ships.clear()
