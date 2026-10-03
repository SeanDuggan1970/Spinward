## Megaprojects: collective builds that draw goods from their place's market,
## stage by stage, and change the world when finished (data/projects.json).
##
## A project takes what it needs from the local market's stock above a reserve,
## which creates real demand that traders (and the player) can profit from. The
## player's share is the net tonnage of needed goods they imported into that market
## while the stage was open (sold there minus bought there, from the economy system's
## stats), so buying and selling back at the same market earns no credit.
extends "res://sim/systems/system.gd"


func start_game() -> void:
	var s = sim().state
	s.projects = {}
	for id in sim().data.projects:
		s.projects[id] = {"stage": 0, "delivered": {}, "player_t": 0.0, "player_total_t": 0.0, "done": false, "seen": {}}
	s.place_mods = {}
	s.project_t = s.time_s


func tick(_game_dt: float) -> void:
	var s = sim().state
	var step := float(sim().data.balance["economy"]["step_hours"]) * 3600.0
	while s.project_t + step <= s.time_s:
		s.project_t += step
		for id in sim().data.projects:
			_advance(id, step / 86400.0, s.project_t)


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
		var sold := _net_imported(s, place, good)
		var seen := float(p["seen"].get(good, 0.0))
		if sold > seen and remaining > 0.0:
			p["player_t"] += minf(sold - seen, remaining)
			p["player_total_t"] += minf(sold - seen, remaining)
		p["seen"][good] = sold
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
