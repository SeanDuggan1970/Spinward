## Turns NPC movement events into comms chatter from data/npcs.json templates.
## Presentation only: the line is picked by hashing the event, never from sim RNG.
extends RefCounted


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
	if event["type"] == "npc_departed":
		cargo = cargo_text(sim, d["cargo"])
		from = sim.data.places[d["from"]]["name"]
		to = sim.data.places[d["to"]]["name"]
		match fleet["behaviour"]:
			"shuttle":
				key = "shuttle_depart"
			"trader":
				key = "trader_depart" if cargo != "" else "empty_depart"
			_:
				key = "route_depart" if cargo != "" else "empty_depart"
	else:
		to = sim.data.places[d["place"]]["name"]
	var options: Array = chatter[key]
	var template: String = options[absi(hash(str(d["npc"]) + str(event["time_s"]))) % options.size()]
	return template.format({"ship": npc["name"], "operator": fleet["operator"], "from": from, "to": to, "cargo": cargo})


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
