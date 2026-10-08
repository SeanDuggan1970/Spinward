## Detection (sim/detection.gd, balance.detection): in transit, every check_s of game
## time, each port with a station looks for the ship; state.detection.seen_by lists
## the ports that can see it now (with "seen"/"unseen" events as that changes).
## Running dark (dark_running) turns the transponder and lights off; the first port
## that sees a dark ship inside its control zone fines it (once a trip: ports share
## word). The heat sink fills while dark and dumps otherwise. Arriving, the
## transponder comes back on (ports don't dock a dark ship). coat_hull, at a stealth
## yard, applies the low-observable coating. Honest physics: nobody hides while burning.
extends "res://sim/systems/system.gd"

const Detection := preload("res://sim/detection.gd")
const ShipStats := preload("res://sim/ship_stats.gd")
const Navigation := preload("res://sim/navigation.gd")
const Power := preload("res://sim/power.gd")
const V := preload("res://sim/v3.gd")

## At most this many sensor sweeps in one tick (a very long tick skips ahead).
const MAX_SWEEPS := 64


func setup(owner) -> void:
	super.setup(owner)
	owner.register("dark_running", _dark)
	owner.register("coat_hull", _coat)


static func ensure(state) -> void:
	if state.detection.is_empty():
		state.detection = {"dark": false, "sink_mj": 0.0, "seen_by": [], "fined": [], "next_t": 0.0, "range_m": 0.0, "loudest": "", "offences": 0}


func tick(dt: float) -> void:
	var s = sim().state
	var data = sim().data
	ensure(s)
	var det: Dictionary = s.detection
	var loc: Dictionary = s.location
	var transit: bool = loc.get("status") == "transit"
	var burning := transit and V.length(Navigation.transit_accel(loc, s.time_s)) > 1e-6
	# The sink soaks up heat while dark, and dumps it through the radiators otherwise.
	var cap := Detection.sink_capacity_mj(s.ship, data)
	if bool(det["dark"]) and cap > 0.0:
		det["sink_mj"] = minf(cap, float(det["sink_mj"]) + Detection.heat_kw(s.ship, data, burning) * dt / 1000.0)
	else:
		det["sink_mj"] = maxf(0.0, float(det["sink_mj"]) - float(data.balance["detection"]["sink_dump_kw"]) * dt / 1000.0)
	if not transit:
		if bool(det["dark"]) and loc.get("status") in ["approach", "docked"]:
			det["dark"] = false
			sim().emit("transponder_on", {"place": loc.get("place", "")})
		if not (det["seen_by"] as Array).is_empty():
			det["seen_by"] = []
		det["fined"] = []
		det["next_t"] = s.time_s
		return
	var check := float(data.balance["detection"]["check_s"])
	var sweeps := 0
	while float(det["next_t"]) <= s.time_s and sweeps < MAX_SWEEPS:
		_sweep(float(det["next_t"]))
		det["next_t"] = float(det["next_t"]) + check
		sweeps += 1
	if float(det["next_t"]) <= s.time_s:
		det["next_t"] = s.time_s + check


## Who sees the ship at time t.
func _sweep(t: float) -> void:
	var s = sim().state
	var data = sim().data
	var eph = sim().ephemeris
	var det: Dictionary = s.detection
	var loc: Dictionary = s.location
	var cfg: Dictionary = data.balance["detection"]
	var here: Array = V.add(eph.position(loc["frame"], t), Navigation.transit_position(loc, t))
	var burning := V.length(Navigation.transit_accel(loc, t)) > 1e-6
	var au := V.distance(here, eph.position("sun", t)) / Power.AU_M
	var ch := Detection.channels(s.ship, data, det, burning, au)
	var top := Detection.loudest(ch)
	det["range_m"] = top[1]
	det["loudest"] = top[0]
	var seen := []
	for place in data.places:
		if not data.places[place].has("station") or data.places[place].has("foot_of"):
			continue
		var d := V.distance(here, eph.position(place, t))
		if d < float(top[1]) * Detection.sensors(data, place):
			seen.append(place)
			if bool(det["dark"]) and d < float(cfg["control_zone_m"]) and (det["fined"] as Array).is_empty():
				det["fined"].append(place)
				# Counted for later: repeat offenders risk impound (docs/ROADMAP.md, step 7).
				det["offences"] = int(det.get("offences", 0)) + 1
				s.credits -= float(cfg["dark_fine_cr"])
				var op: String = data.places[place].get("operator", "")
				if op != "":
					s.reputation[op] = float(s.reputation.get(op, 0.0)) - float(cfg["dark_fine_rep"])
				sim().emit("dark_running_fined", {"place": place, "credits": -float(cfg["dark_fine_cr"]), "operator": op}, t)
	var before: Array = det["seen_by"]
	for p in seen:
		if not p in before:
			sim().emit("seen", {"place": p, "by": top[0]}, t)
	for p in before:
		if not p in seen:
			sim().emit("unseen", {"place": p}, t)
	det["seen_by"] = seen


## {on}: run dark (transponder and lights off), or light up again.
func _dark(command: Dictionary) -> String:
	var s = sim().state
	ensure(s)
	if s.location.get("status") in ["approach", "elevator"]:
		return "not while you're coming in"
	var on := bool(command.get("on", not bool(s.detection["dark"])))
	if on and s.location.get("status") == "docked":
		return "traffic control won't let a ship sit dark at the berth"
	s.detection["dark"] = on
	sim().emit("dark_running", {"on": on})
	return ""


## Apply the low-observable coating at a stealth yard: so much a tonne of dry mass.
func _coat(_command: Dictionary) -> String:
	var s = sim().state
	var data = sim().data
	var cfg: Dictionary = data.balance["detection"]
	if s.location.get("status") != "docked" or not s.location.get("place", "") in cfg["stealth_yards"]:
		return "only a few yards do that work"
	if s.ship.get("coating", "") == "low_obs":
		return "she's already coated"
	var cost := coat_cost(s, data)
	if s.credits < cost:
		return "the coating costs %d cr" % int(ceil(cost))
	s.credits -= cost
	s.ship["coating"] = "low_obs"
	sim().emit("hull_coated", {"credits": -cost})
	return ""


static func coat_cost(state, data) -> float:
	return float(data.balance["detection"]["coat_cr_per_t"]) * ShipStats.dry_mass_t(state.ship, data)
