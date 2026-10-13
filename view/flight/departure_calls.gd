## The co-pilot talks the ship out of port, whichever transit view is up: a line at
## each of the departure's moments (Departure.cues, data/npcs.json
## chatter.copilot_undock). Presentation only; lines are picked by hashing the trip.
extends Node

const Models := preload("res://view/flight/models.gd")
const Departure := preload("res://view/flight/departure.gd")
const StorySystem := preload("res://sim/systems/story_system.gd")
## A moment passed longer ago than this (game seconds, the clock sped past it) goes unsaid.
const STALE_S := 30.0

signal said(text: String)

var sim
var _departure := Departure.new()
var _cues: Array = []
var _last := INF


func _init(owner_sim) -> void:
	sim = owner_sim


func _ready() -> void:
	var loc: Dictionary = sim.state.location
	# Well out on a voyage there is nothing left to say.
	if loc.get("status") != "transit" or sim.state.time_s - float(loc["depart_t"]) > 900.0:
		return
	var model := Models.ship(sim.state.ship, sim.data)
	_departure.setup(model, sim.data, loc)
	(model["node"] as Node).free()
	_cues = _departure.cues()


func _process(_dt: float) -> void:
	var loc: Dictionary = sim.state.location
	if _cues.is_empty() or loc.get("status") != "transit" or sim.asleep():
		return
	var elapsed: float = sim.state.time_s - float(loc["depart_t"])
	# Opened part way out (a load, a view change): only what happens from here on.
	if _last == INF:
		_last = elapsed
		return
	var due := ""
	for cue in _cues:
		if float(cue[0]) > _last and float(cue[0]) <= elapsed and elapsed - float(cue[0]) < STALE_S:
			due = cue[1]
	_last = elapsed
	if due != "":
		said.emit(line(sim, due))


## The co-pilot's line for a departure moment ("wake", "doors", "backing", "clear", "free").
static func line(owner_sim, key: String) -> String:
	var loc: Dictionary = owner_sim.state.location
	var options: Array = owner_sim.data.npcs["chatter"]["copilot_undock"][key]
	var template: String = options[absi(hash(str(loc["depart_t"]) + loc["from"])) % options.size()]
	return template.format({"name": StorySystem.copilot_name(owner_sim.state, owner_sim.data),
		"from": owner_sim.data.locations[loc["from"]]["name"], "to": owner_sim.data.locations[loc["to"]]["name"]})
