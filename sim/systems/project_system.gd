## Megaprojects: collective builds that draw goods from their place's market,
## stage by stage, and change the world when finished (data/projects.json).
##
## A project takes what it needs from the local market's stock above a reserve,
## which creates real demand that traders (and the player) can profit from. The
## player's share is the net tonnage of needed goods they imported into that market
## while the stage was open (sold there minus bought there, from the economy system's
## stats), so buying and selling back at the same market earns no credit.
##
## Projects pitch for backers (data "pitch"), reward hauled tonnage with perks
## (sim/perks.gd), and are not all there from the start: some are revealed later
## ("reveal"), and some only invite pilots the backer knows ("invite"); until then a
## project neither draws on its market nor credits the player.
extends "res://sim/systems/system.gd"

const Perks := preload("res://sim/perks.gd")


func start_game() -> void:
	var s = sim().state
	s.projects = {}
	for id in sim().data.projects:
		s.projects[id] = {"stage": 0, "delivered": {}, "player_t": 0.0, "player_total_t": 0.0, "done": false, "seen": {}, "revealed": false, "invited": false}
	s.place_mods = {}
	s.perks = {}
	s.project_t = s.time_s
	s.started_t = s.time_s
	_reveal_due(s.time_s)


func tick(_game_dt: float) -> void:
	var s = sim().state
	# Saves from before a project existed (or a project added to data later) get a
	# fresh entry, rather than failing on every tick.
	for id in sim().data.projects:
		if not s.projects.has(id):
			var seen := {}
			for good in sim().data.projects[id]["stages"][0]["needs"]:
				seen[good] = _net_imported(s, sim().data.projects[id]["place"], good)
			s.projects[id] = {"stage": 0, "delivered": {}, "player_t": 0.0, "player_total_t": 0.0, "done": false, "seen": seen, "revealed": false, "invited": false}
	var step := float(sim().data.balance["economy"]["step_hours"]) * 3600.0
	while s.project_t + step <= s.time_s:
		s.project_t += step
		_reveal_due(s.project_t)
		for id in sim().data.projects:
			if s.projects[id].get("revealed", true):
				_advance(id, step / 86400.0, s.project_t)


## Announce projects whose time has come, and ask in the pilots a backer knows.
func _reveal_due(t: float) -> void:
	var s = sim().state
	var data = sim().data
	for id in data.projects:
		var project: Dictionary = data.projects[id]
		var p: Dictionary = s.projects[id]
		if not p.get("revealed", true):
			var reveal: Dictionary = project.get("reveal", {})
			var ok := t - float(s.started_t) >= float(reveal.get("after_days", 0.0)) * 86400.0
			var after: Array = reveal.get("after_stage", [])
			if not after.is_empty():
				var other: Dictionary = s.projects.get(after[0], {})
				ok = ok and (other.get("done", false) or int(other.get("stage", 0)) >= int(after[1]))
			if ok:
				p["revealed"] = true
				_open_stage(id)
				# What is there from the start needs no announcement.
				if not project.has("invite") and t > float(s.started_t) + 3600.0:
					sim().emit("project_announced", {"project": id}, t)
		if p.get("revealed", true) and not p.get("invited", false):
			var invite: Dictionary = project.get("invite", {})
			if invite.is_empty() or float(s.reputation.get(invite["operator"], 0.0)) >= float(invite["min_rep"]):
				p["invited"] = true
				if not invite.is_empty():
					sim().emit("project_invite", {"project": id, "operator": invite["operator"]}, t)


## Can the player see (and back) a project now?
static func open_to_player(state, data, id: String) -> bool:
	var p: Dictionary = state.projects.get(id, {})
	return p.get("revealed", true) and (p.get("invited", true) or not data.projects[id].has("invite"))


func _open_stage(id: String) -> void:
	var s = sim().state
	var p: Dictionary = s.projects[id]
	p["seen"] = {}
	var project: Dictionary = sim().data.projects[id]
	for good in project["stages"][int(p["stage"])]["needs"]:
		p["seen"][good] = _net_imported(s, project["place"], good)


## Perks earned by the player's tonnage over the whole build.
func _award_perks(id: String, t: float) -> void:
	var s = sim().state
	var project: Dictionary = sim().data.projects[id]
	var p: Dictionary = s.projects[id]
	var earned: Array = s.perks.get("_earned", [])
	var perks: Array = project.get("perks", [])
	for i in perks.size():
		var perk: Dictionary = perks[i]
		var key := "%s/%d" % [id, i]
		if key in earned or float(p["player_total_t"]) < float(perk["min_t"]):
			continue
		earned.append(key)
		match perk["kind"]:
			"free_docking":
				_set_perk(perk["place"], "free_docking", true)
			"fuel_discount", "yard_discount":
				_set_perk(perk["place"], perk["kind"], maxf(float(Perks.at(s, perk["place"], perk["kind"], 0.0)), float(perk["value"])))
			"standing":
				s.reputation[perk["operator"]] = float(s.reputation.get(perk["operator"], 0.0)) + float(perk["value"])
			"promise":
				var promises: Array = s.perks.get("_promises", [])
				promises.append(perk["text"])
				s.perks["_promises"] = promises
		sim().emit("perk_earned", {"project": id, "text": perk["text"]}, t)
	s.perks["_earned"] = earned


func _set_perk(place: String, kind: String, value) -> void:
	var s = sim().state
	var at: Dictionary = s.perks.get(place, {})
	at[kind] = value
	s.perks[place] = at


## Fraction complete in [0, 1], counting partial progress through the current stage.
static func progress(state, data, id: String) -> float:
	var p: Dictionary = state.projects.get(id, {})
	if p.is_empty():
		return 0.0
	var stages: Array = data.projects[id]["stages"]
	if p["done"]:
		return 1.0
	var needs: Dictionary = stages[int(p["stage"])]["needs"]
	var need_total := 0.0
	var got := 0.0
	for good in needs:
		need_total += float(needs[good])
		got += minf(float(p["delivered"].get(good, 0.0)), float(needs[good]))
	return (float(p["stage"]) + (got / need_total if need_total > 0.0 else 0.0)) / float(stages.size())


func _advance(id: String, days: float, t: float) -> void:
	var s = sim().state
	var data = sim().data
	var project: Dictionary = data.projects[id]
	var p: Dictionary = s.projects[id]
	if p["done"]:
		return
	var place: String = project["place"]
	var stage: Dictionary = project["stages"][int(p["stage"])]
	var needs: Dictionary = stage["needs"]
	var reserve_fraction := float(data.projects_reserve_fraction)
	var complete := true
	for good in needs:
		var remaining := float(needs[good]) - float(p["delivered"].get(good, 0.0))
		# Credit the player for needed goods they hauled here since we last looked.
		# High-water mark on net imports: buying then selling back only returns the net
		# to where it was, so it earns nothing; only new net imports are credited.
		var net := _net_imported(s, place, good)
		var high := float(p["seen"].get(good, 0.0))
		if net > high:
			if remaining > 0.0 and open_to_player(s, data, id):
				p["player_t"] += minf(net - high, remaining)
				p["player_total_t"] += minf(net - high, remaining)
				_award_perks(id, t)
			p["seen"][good] = net
		if remaining <= 1e-6:
			continue
		var stock: float = s.markets[place][good]
		var reserve: float = float(data.places[place]["market"][good]) * reserve_fraction
		var take := minf(minf(remaining, float(project["draw_t_per_day"]) * days), maxf(0.0, stock - reserve))
		s.markets[place][good] = stock - take
		p["delivered"][good] = float(p["delivered"].get(good, 0.0)) + take
		if remaining - take > 1e-6:
			complete = false
	if not complete:
		return
	var need_total := 0.0
	for good in needs:
		need_total += float(needs[good])
	var share := clampf(float(p["player_t"]) / need_total, 0.0, 1.0) if need_total > 0.0 else 0.0
	sim().emit("project_stage", {"project": id, "stage": int(p["stage"]), "name": stage["name"], "player_share": share}, t)
	p["stage"] = int(p["stage"]) + 1
	p["delivered"] = {}
	p["player_t"] = 0.0
	# Only sales made after a stage opens count toward it.
	p["seen"] = {}
	if int(p["stage"]) < project["stages"].size():
		for good in project["stages"][int(p["stage"])]["needs"]:
			p["seen"][good] = _net_imported(s, place, good)
	if int(p["stage"]) >= project["stages"].size():
		p["done"] = true
		for target in project.get("effects", {}):
			var mods: Dictionary = s.place_mods.get(target, {})
			for key in project["effects"][target]:
				mods[key] = float(mods.get(key, 1.0)) * float(project["effects"][target][key])
			s.place_mods[target] = mods
		sim().emit("project_complete", {"project": id, "player_total_t": p["player_total_t"]}, t)


static func _net_imported(state, place: String, good: String) -> float:
	var sold := float(state.stats.get("player_sold", {}).get(place, {}).get(good, 0.0))
	var bought := float(state.stats.get("player_bought", {}).get(place, {}).get(good, 0.0))
	return sold - bought
