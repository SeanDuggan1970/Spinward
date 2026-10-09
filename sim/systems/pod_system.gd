## The lander's pods (data/pods.json): the lander bay carries one pod, fitted at a
## shipyard. On site the lander can set its pod down, with whatever you leave in it
## (cargo, or propellant in a tank pod), and pick up any pod lying there: pods stay
## where they are, in the saved game, until collected. A pod dropped empty is still
## worth coming back for. state.sites["pods"] is {site: [{pod, cargo, fuel_t, t}]}.
extends "res://sim/systems/system.gd"

const ShipStats := preload("res://sim/ship_stats.gd")


func setup(owner) -> void:
	super.setup(owner)
	owner.register("fit_pod", _fit)
	owner.register("drop_pod", _drop)
	owner.register("pick_up_pod", _pick_up)


## Pods lying at a site.
static func at_site(state, site: String) -> Array:
	return state.sites.get("pods", {}).get(site, [])


static func has_mount(ship: Dictionary, data) -> bool:
	return ShipStats.modules_of(ship, data).any(func(m): return m.get("pod_mount", false))


## What a pod costs to fit here, after the old one is taken back.
static func fit_cost(state, data, pod: String) -> float:
	var cfg: Dictionary = data.pods
	var old := ShipStats.pod_of(state.ship, data)
	var back := float(cfg["pods"].get(old, {}).get("price", 0.0)) * float(cfg.get("trade_in", 0.5)) if old != "" else 0.0
	return float(cfg["pods"][pod]["price"]) - back


## Why the ship could not carry what it has aboard with `pod` in place of its pod (""
## if it can).
static func _wont_fit(state, data, pod: String) -> String:
	var trial: Dictionary = state.ship.duplicate(true)
	trial["pod"] = pod
	if ShipStats.cargo_t(trial) > ShipStats.cargo_capacity_t(trial, data) + 1e-6:
		return "the hold would not hold what you carry"
	if float(trial.get("fuel_t", 0.0)) > ShipStats.fuel_capacity_t(trial, data) + 1e-6:
		return "the tanks would not hold the propellant aboard"
	if int(trial.get("passengers", 0)) > ShipStats.berths(trial, data):
		return "there would be too few seats for the passengers aboard"
	return ""


## {pod}: fit a pod at a shipyard, the old one taken back.
func _fit(command: Dictionary) -> String:
	var s = sim().state
	var data = sim().data
	var pod: String = command.get("pod", "")
	if s.location.get("status") != "docked" or not "shipyard" in data.places.get(s.location.get("place", ""), {}).get("services", []):
		return "pods are fitted at a shipyard"
	if not has_mount(s.ship, data):
		return "no lander bay to carry a pod"
	if not data.pods.get("pods", {}).has(pod):
		return "unknown pod"
	if ShipStats.pod_of(s.ship, data) == pod:
		return "that pod is already fitted"
	if float(s.ship.get("payload_load_t", 0.0)) > 0.0:
		return "there's a satellite in the payload carrier"
	var why := _wont_fit(s, data, pod)
	if why != "":
		return why
	var cost := fit_cost(s, data, pod)
	if s.credits < cost:
		return "a %s costs %d cr" % [String(data.pods["pods"][pod]["name"]).to_lower(), int(ceil(cost))]
	s.credits -= cost
	s.ship["pod"] = pod
	sim().emit("pod_fitted", {"pod": pod, "credits": -cost})
	return ""


## {cargo?: {good: t}, fuel_t?}: set the lander's pod down on site, leaving in it the
## cargo (up to its hold) or propellant (up to its tank) given. What stays aboard must
## fit without it.
func _drop(command: Dictionary) -> String:
	var s = sim().state
	var data = sim().data
	if s.location.get("status") != "on_site":
		return "pods are set down on site"
	var pod := ShipStats.pod_of(s.ship, data)
	if pod == "":
		return "no pod to set down"
	if not s.sites.get("work", {}).is_empty():
		return "still at work"
	if float(s.ship.get("payload_load_t", 0.0)) > 0.0:
		return "there's a satellite in the payload carrier"
	var spec: Dictionary = data.pods["pods"][pod]
	var cargo: Dictionary = command.get("cargo", {})
	var load := 0.0
	for g in cargo:
		if float(cargo[g]) < 0.0 or float(cargo[g]) > float(s.ship["cargo"].get(g, 0.0)) + 1e-6:
			return "you don't have that much %s" % g
		load += float(cargo[g])
	if load > float(spec.get("cargo_t", 0.0)) + 1e-6:
		return "the pod holds %d t" % int(spec.get("cargo_t", 0.0))
	var fuel := float(command.get("fuel_t", 0.0))
	if fuel < 0.0 or fuel > float(spec.get("fuel_t", 0.0)) + 1e-6 or fuel > float(s.ship["fuel_t"]) + 1e-6:
		return "the pod's tank can't take that"
	# What stays aboard must fit the ship without the pod.
	var after: Dictionary = s.ship.duplicate(true)
	after["pod"] = ""
	for g in cargo:
		after["cargo"][g] = float(after["cargo"][g]) - float(cargo[g])
	after["fuel_t"] = float(after["fuel_t"]) - fuel
	if ShipStats.cargo_t(after) > ShipStats.cargo_capacity_t(after, data) + 1e-6:
		return "the rest of the hold won't take what stays aboard"
	if float(after["fuel_t"]) > ShipStats.fuel_capacity_t(after, data) + 1e-6:
		return "the ship's tanks won't take the rest of the propellant"
	if int(after.get("passengers", 0)) > ShipStats.berths(after, data):
		return "passengers are aboard in the pod"
	for g in cargo:
		if float(after["cargo"][g]) < 1e-6:
			after["cargo"].erase(g)
	s.ship = after
	var site: String = s.location["place"]
	var pods: Dictionary = s.sites.get("pods", {})
	var here: Array = pods.get(site, [])
	here.append({"pod": pod, "cargo": cargo.duplicate(), "fuel_t": fuel, "t": s.time_s})
	pods[site] = here
	s.sites["pods"] = pods
	sim().emit("pod_dropped", {"site": site, "pod": pod, "cargo_t": load, "fuel_t": fuel})
	return ""


## {index}: pick up a pod lying on site (the lander's clamp must be empty); what is in
## it comes aboard.
func _pick_up(command: Dictionary) -> String:
	var s = sim().state
	var data = sim().data
	if s.location.get("status") != "on_site":
		return "pods are picked up on site"
	if not has_mount(s.ship, data):
		return "no lander to pick it up"
	if ShipStats.pod_of(s.ship, data) != "":
		return "set your own pod down first"
	if not s.sites.get("work", {}).is_empty():
		return "still at work"
	var site: String = s.location["place"]
	var here: Array = at_site(s, site)
	var i := int(command.get("index", 0))
	if i < 0 or i >= here.size():
		return "no such pod here"
	var found: Dictionary = here[i]
	var after: Dictionary = s.ship.duplicate(true)
	after["pod"] = found["pod"]
	for g in found["cargo"]:
		after["cargo"][g] = float(after["cargo"].get(g, 0.0)) + float(found["cargo"][g])
	after["fuel_t"] = float(after["fuel_t"]) + float(found["fuel_t"])
	if ShipStats.cargo_t(after) > ShipStats.cargo_capacity_t(after, data) + 1e-6:
		return "no room in the hold for what's in it"
	if float(after["fuel_t"]) > ShipStats.fuel_capacity_t(after, data) + 1e-6:
		return "no room in the tanks for its propellant"
	s.ship = after
	here.remove_at(i)
	if here.is_empty():
		s.sites["pods"].erase(site)
	sim().emit("pod_picked_up", {"site": site, "pod": found["pod"], "cargo": found["cargo"], "fuel_t": found["fuel_t"]})
	return ""
