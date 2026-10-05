## The Spaceline (data/news.json): the system's news feed.
##
## World stories post on their day (from the start of the game), some waiting for a
## story beat, a project stage or a finished project; some change a place for good
## (more output after a new seam, a refit, a seed factory), so the system gets richer
## as it goes. Projects make the news when they are announced (backers wanted: see
## Projects), at each stage and when they finish; new ships make it when they enter
## service. Invitation-only projects stay out of the papers.
##
## The feed watches state rather than other systems' events (systems never call each
## other), so it also catches up after loading an older save.
extends "res://sim/systems/system.gd"

const DAY := 86400.0


func start_game() -> void:
	var s = sim().state
	var data = sim().data
	s.news = {"items": [], "posted": [], "projects": {}, "ships": [], "seq": 0}
	# What was already in the feed when you arrived: stories from before the start, and
	# the announcements of projects already under way.
	for story in data.news.get("stories", []):
		if float(story.get("after_days", 0.0)) < 0.0 and _ready(story):
			_post_story(story, float(s.started_t) + float(story["after_days"]) * DAY + _hour_of(story["id"]), false)
	for id in data.projects:
		if s.projects.get(id, {}).get("revealed", false) and _public(id):
			var text: Dictionary = data.news.get("projects", {}).get(id, {})
			_announce(id, s.time_s - float(text.get("backdate_days", 30.0)) * DAY + _hour_of(id) - 24.0 * 3600.0, false)
	_note_projects()
	for npc in s.npcs:
		if npc.get("commissioned", true):
			s.news["ships"].append(npc["id"])
	s.news["items"].sort_custom(func(a, b): return float(a["t"]) < float(b["t"]))


func tick(_game_dt: float) -> void:
	var s = sim().state
	if s.news.is_empty():
		start_game()
	var data = sim().data
	for story in data.news.get("stories", []):
		if story["id"] in s.news["posted"]:
			continue
		if s.time_s - float(s.started_t) < float(story.get("after_days", 0.0)) * DAY or not _ready(story):
			continue
		_post_story(story, s.time_s, true)
	for id in data.projects:
		var p: Dictionary = s.projects.get(id, {})
		if p.is_empty() or not _public(id):
			continue
		var rec: Dictionary = s.news["projects"].get(id, {})
		if rec.is_empty():
			rec = {"announced": false, "stage": 0, "done": false}
			s.news["projects"][id] = rec
		if p.get("revealed", true) and not rec["announced"]:
			_announce(id, s.time_s, true)
			rec["announced"] = true
		while int(rec["stage"]) < int(p["stage"]) and int(rec["stage"]) < data.projects[id]["stages"].size() - 1:
			_stage_item(id, int(rec["stage"]))
			rec["stage"] = int(rec["stage"]) + 1
		if p.get("done", false) and not rec["done"]:
			rec["stage"] = int(p["stage"])
			rec["done"] = true
			_complete_item(id)
	for npc in s.npcs:
		if npc.get("commissioned", true) and not npc["id"] in s.news["ships"]:
			s.news["ships"].append(npc["id"])
			_ship_item(npc)


## A steady time of day for a backdated item, so the old news doesn't all land at midnight.
func _hour_of(id: String) -> float:
	return float(absi(hash(id)) % 1080 + 240) * 60.0


## Is this story's moment here (its beat done, its project far enough along)?
func _ready(story: Dictionary) -> bool:
	var s = sim().state
	if story.has("after_beat") and not story["after_beat"] in s.story.get("done", []):
		return false
	if story.has("after_project") and not s.projects.get(story["after_project"], {}).get("done", false):
		return false
	if story.has("after_stage"):
		var p: Dictionary = s.projects.get(story["after_stage"][0], {})
		if not (p.get("done", false) or int(p.get("stage", 0)) >= int(story["after_stage"][1])):
			return false
	return true


## Projects that are open to everyone are news; invitations are private.
func _public(id: String) -> bool:
	return not sim().data.projects[id].has("invite")


func _note_projects() -> void:
	var s = sim().state
	for id in sim().data.projects:
		var p: Dictionary = s.projects.get(id, {})
		s.news["projects"][id] = {"announced": p.get("revealed", false), "stage": int(p.get("stage", 0)), "done": p.get("done", false)}


func _post_story(story: Dictionary, t: float, live: bool) -> void:
	var s = sim().state
	s.news["posted"].append(story["id"])
	for target in story.get("effects", {}):
		var mods: Dictionary = s.place_mods.get(target, {})
		for key in story["effects"][target]:
			mods[key] = float(mods.get(key, 1.0)) * float(story["effects"][target][key])
		s.place_mods[target] = mods
	_post({"kind": "world", "dateline": story.get("dateline", ""), "headline": story["headline"], "body": story.get("body", ""),
		"story": story["id"], "places": story.get("effects", {}).keys()}, t, live)


func _announce(id: String, t: float, live: bool) -> void:
	var data = sim().data
	var project: Dictionary = data.projects[id]
	var place: String = data.places[project["place"]]["name"]
	var text: Dictionary = data.news.get("projects", {}).get(id, {}).get("announce", {})
	var backer: String = project.get("backer", "Builders")
	var body: String = text.get("body", "Today, Earth Standard Time, %s announced %s at %s. %s They are looking for backers: see Projects." % [
		backer, project["name"], place, project.get("pitch", {}).get("why", "")])
	_post({"kind": "project", "dateline": text.get("dateline", place), "headline": text.get("headline", "%s announce %s" % [backer, project["name"]]),
		"body": body, "project": id}, t, live)


func _stage_item(id: String, stage: int) -> void:
	var data = sim().data
	var project: Dictionary = data.projects[id]
	var stages: Array = project["stages"]
	var left := stages.size() - stage - 1
	_post({"kind": "project", "dateline": data.places[project["place"]]["name"],
		"headline": "%s: %s" % [project["name"], String(stages[stage]["name"]).to_lower()],
		"body": "%s report the stage complete. %s Haulers wanted for what comes next: see Projects." % [
			project.get("backer", "The builders"), "One stage to go." if left == 1 else "%d stages to go." % left],
		"project": id}, sim().state.time_s, true)


func _complete_item(id: String) -> void:
	var data = sim().data
	var project: Dictionary = data.projects[id]
	var text: Dictionary = data.news.get("projects", {}).get(id, {}).get("complete", {})
	_post({"kind": "project", "dateline": text.get("dateline", data.places[project["place"]]["name"]),
		"headline": text.get("headline", "%s is finished" % project["name"]),
		"body": text.get("body", "%s is complete. The system just got a little bigger." % project["name"]), "project": id}, sim().state.time_s, true)


func _ship_item(npc: Dictionary) -> void:
	var data = sim().data
	var fleet: Dictionary = data.npcs["fleets"][npc["fleet"]]
	var hull: Dictionary = data.ships[fleet["hull"]]
	var home: String = npc["location"].get("place", npc["location"].get("from", ""))
	_post({"kind": "fleet", "dateline": data.places[home]["name"] if data.places.has(home) else "",
		"headline": "%s commissions the %s" % [fleet["operator"], npc["name"]],
		"body": "%s enters service at %s. %s" % [String(hull["name"]).capitalize(), data.places[home]["name"] if data.places.has(home) else "port", hull.get("description", "")],
		"npc": npc["id"]}, sim().state.time_s, true)


func _post(item: Dictionary, t: float, live: bool) -> void:
	var s = sim().state
	s.news["seq"] = int(s.news["seq"]) + 1
	item["id"] = int(s.news["seq"])
	item["t"] = t
	s.news["items"].append(item)
	var keep := int(sim().data.news.get("keep", 80))
	while s.news["items"].size() > keep:
		s.news["items"].pop_front()
	if live:
		sim().emit("news", {"item": item}, t)
