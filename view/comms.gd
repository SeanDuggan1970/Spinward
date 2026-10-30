## Turns NPC movement events into comms chatter from data/npcs.json templates.
## Presentation only: the line is picked by hashing the event, never from sim RNG.
extends RefCounted

const V := preload("res://sim/v3.gd")
const Navigation := preload("res://sim/navigation.gd")
const StorySystem := preload("res://sim/systems/story_system.gd")
## Speed of light, m/s.
const C := 299792458.0


static func line(sim, event: Dictionary) -> String:
	var d: Dictionary = event["data"]
	var npc := _npc(sim, d["npc"])
	if npc.is_empty():
		return ""
	var fleet: Dictionary = sim.data.npcs["fleets"][npc["fleet"]]
	var chatter: Dictionary = sim.data.npcs["chatter"]
	var key := "arrive"
	var cargo := ""
	var to := ""
	var from := ""
	var alt := "%d" % int(round(float(d.get("alt", 0.0))))
	if event["type"] == "npc_flyby_plan":
		key = "flyby_depart"
		from = sim.data.places[d["from"]]["name"]
		to = sim.data.places[d["to"]]["name"]
	elif event["type"] == "npc_flyby":
		key = "flyby_pass"
	elif event["type"] == "npc_departed":
		cargo = cargo_text(sim, d["cargo"])
		from = sim.data.places[d["from"]]["name"]
		to = sim.data.places[d["to"]]["name"]
		match "climb" if fleet.get("elevator", false) else ("sail" if fleet.get("sail", false) else fleet["behaviour"]):
			"climb":
				key = "climb_depart"
			"sail":
				key = "sail_depart"
			"shuttle":
				key = "shuttle_depart"
			"trader":
				key = "trader_depart" if cargo != "" else "empty_depart"
			_:
				key = "route_depart" if cargo != "" else "empty_depart"
	else:
		to = sim.data.places[d["place"]]["name"]
	var options: Array = chatter[key]
	# A travelling group says its own piece as it leaves.
	if event["type"] == "npc_departed" and not fleet.get("lines", []).is_empty():
		options = fleet["lines"]
	var template: String = options[absi(hash(str(d["npc"]) + str(event["time_s"]))) % options.size()]
	return template.format({"ship": npc["name"], "operator": fleet["operator"], "from": from, "to": to, "cargo": cargo, "alt": alt})


## Overheard on the lanes (data/npcs.json chatter.overheard): the line for the
## every_hours slot holding time t, from a ship in transit then, or "" when nobody is
## out there. Picked by hashing the slot, never from sim RNG.
static func overheard(sim, t: float) -> String:
	var cfg: Dictionary = sim.data.npcs["chatter"].get("overheard", {})
	if cfg.is_empty():
		return ""
	var slot := int(floor(t / (float(cfg["every_hours"]) * 3600.0)))
	var out: Array = sim.state.npcs.filter(func(n): return n["location"].get("status") == "transit")
	if out.is_empty():
		return ""
	var h := absi(hash("overheard:%d" % slot))
	var npc: Dictionary = out[h % out.size()]
	var other: Dictionary = out[(h / 7 + 1) % out.size()] if out.size() > 1 else npc
	var lines: Array = cfg["lines"]
	var template: String = lines[(h / 131) % lines.size()]
	if template.contains("{other}") and other["id"] == npc["id"]:
		# Nobody else out there to answer: pick a line for one ship.
		var solo: Array = lines.filter(func(l): return not String(l).contains("{other}"))
		template = solo[(h / 131) % solo.size()]
	return template.format({"ship": npc["name"], "other": other["name"], "to": sim.data.locations[npc["location"]["to"]]["name"]})


## The slot overheard() uses for time t.
static func overheard_slot(sim, t: float) -> int:
	var cfg: Dictionary = sim.data.npcs["chatter"].get("overheard", {})
	return -1 if cfg.is_empty() else int(floor(t / (float(cfg["every_hours"]) * 3600.0)))


## The co-pilot's line for the player's own flyby: "copilot_near" or "copilot_pass".
static func copilot(sim, key: String, alt_m: float, in_s: float = 0.0) -> String:
	var bands: Dictionary = sim.data.npcs["chatter"][key]
	var km := alt_m / 1000.0
	var band := "high" if km > 200.0 else ("mid" if km > 60.0 else "low")
	var options: Array = bands[band]
	var template: String = options[absi(hash(str(alt_m))) % options.size()]
	var minutes := int(in_s / 60.0)
	return template.format({"alt": "%d" % int(round(km)), "in": "%d h %02d min" % [minutes / 60, minutes % 60]})


## Out of the Lanes' reach (data/npcs.json chatter.copilot_alone): true when the ship
## is in transit at t and every port is further off than far_light_s of light, too far
## for the co-pilot to ask anyone anything in good time. coming_back: measure against the
## nearer back_share of that, so a ship skirting the edge doesn't flicker in and out.
static func beyond_lanes(sim, t: float, coming_back := false) -> bool:
	var cfg: Dictionary = sim.data.npcs["chatter"].get("copilot_alone", {})
	var loc: Dictionary = sim.state.location
	if cfg.is_empty() or loc.get("status") != "transit":
		return false
	var eph = sim.ephemeris
	var ship := V.add(eph.position(loc["frame"], t), Navigation.transit_position(loc, t))
	var reach := float(cfg["far_light_s"]) * C * (float(cfg["back_share"]) if coming_back else 1.0)
	for p in sim.data.places:
		if sim.data.places[p].has("market") and sim.data.locations.has(p) and V.distance(eph.position(p, t), ship) < reach:
			return false
	return true


## The co-pilot's line on leaving the Lanes' reach ("out") or coming back into it
## ("back"), picked by hashing the trip.
static func copilot_alone(sim, key: String) -> String:
	var options: Array = sim.data.npcs["chatter"]["copilot_alone"][key]
	var loc: Dictionary = sim.state.location
	var template: String = options[absi(hash("%s:%s:%s" % [key, loc.get("to", ""), loc.get("depart_t", 0.0)])) % options.size()]
	return template.format({"name": StorySystem.copilot_name(sim.state, sim.data), "to": sim.data.locations[loc["to"]]["name"] if sim.data.locations.has(loc.get("to", "")) else ""})


static func cargo_text(sim, cargo: Dictionary) -> String:
	var bits := []
	for good in cargo:
		bits.append("%d t %s" % [int(round(float(cargo[good]))), String(sim.data.goods[good]["name"]).to_lower()])
	return " and ".join(bits)


static func _npc(sim, id: String) -> Dictionary:
	for npc in sim.state.npcs:
		if npc["id"] == id:
			return npc
	return {}
