## Simulation core. Owns the state, the loaded data and the systems.
##
## Everything that changes the game goes through apply(command): a plain Dictionary
## with a "type" key, so commands can be logged, replayed, sent by bots or, later,
## sent over the network. Systems register handlers for the types they own.
## Systems never call each other; they share state and emit events for the view.
extends RefCounted

const GameState := preload("res://sim/game_state.gd")
const DataCatalog := preload("res://sim/data_catalog.gd")
const Ephemeris := preload("res://sim/ephemeris.gd")
const CalendarSystem := preload("res://sim/systems/calendar_system.gd")
const EconomySystem := preload("res://sim/systems/economy_system.gd")
const ShipyardSystem := preload("res://sim/systems/shipyard_system.gd")
const TravelSystem := preload("res://sim/systems/travel_system.gd")
const NpcSystem := preload("res://sim/systems/npc_system.gd")
const ProjectSystem := preload("res://sim/systems/project_system.gd")
const TipSystem := preload("res://sim/systems/tip_system.gd")
const ContractSystem := preload("res://sim/systems/contract_system.gd")
const SiteSystem := preload("res://sim/systems/site_system.gd")
const StorySystem := preload("res://sim/systems/story_system.gd")
const NewsSystem := preload("res://sim/systems/news_system.gd")
const ElevatorSystem := preload("res://sim/systems/elevator_system.gd")
const DamageSystem := preload("res://sim/systems/damage_system.gd")
const PowerSystem := preload("res://sim/systems/power_system.gd")
const WearSystem := preload("res://sim/systems/wear_system.gd")
const FitnessSystem := preload("res://sim/systems/fitness_system.gd")
const InsuranceSystem := preload("res://sim/systems/insurance_system.gd")

## Undrained events are capped so headless runs (bots, tests) cannot grow without bound.
const MAX_PENDING_EVENTS := 2000

var state: GameState
var data: DataCatalog
var ephemeris: Ephemeris
var systems: Array = []
var _handlers: Dictionary = {}
var _events: Array[Dictionary] = []
## Route options planned for a departure (not saved: plans are a pure function of
## their inputs, so a replay recomputes them). Key: route_key().
var route_cache: Dictionary = {}


func _init(catalog: DataCatalog = null) -> void:
	data = catalog if catalog else DataCatalog.load_default()
	ephemeris = Ephemeris.new(data.bodies, data.locations)
	state = GameState.new()
	# Order matters within a tick: the clock moves first, then everything catches up to it.
	systems = [CalendarSystem.new(), EconomySystem.new(), ShipyardSystem.new(), WearSystem.new(), FitnessSystem.new(), InsuranceSystem.new(), TravelSystem.new(), NpcSystem.new(), ProjectSystem.new(), TipSystem.new(), ContractSystem.new(), SiteSystem.new(), StorySystem.new(), ElevatorSystem.new(), DamageSystem.new(), PowerSystem.new(), NewsSystem.new()]
	for system in systems:
		system.setup(self)


func new_game(seed_value: int) -> void:
	state = GameState.new()
	state.seed = seed_value
	var start: Dictionary = data.balance["start"]
	state.time_s = GameState.from_unix(Time.get_unix_time_from_datetime_string(start["date_utc"]))
	state.credits = float(start["credits"])
	for system in systems:
		system.start_game()
	emit("new_game", {"seed": seed_value})


func load_state(loaded: GameState) -> void:
	state = loaded
	emit("loaded", {})


## The cache key for route options from where the ship is now to `to`, planned at
## game time `plan_t` (defaults to now) for the ship's current mass.
func route_key(to: String, plan_t: float = NAN) -> String:
	const ShipStats := preload("res://sim/ship_stats.gd")
	var t := state.time_s if is_nan(plan_t) else plan_t
	return "%s>%s@%.3f#%.6f" % [state.location.get("place", ""), to, t, ShipStats.total_mass_t(state.ship, data)]


func store_route_options(key: String, options: Array) -> void:
	route_cache[key] = options
	# Keep only recent plans (each holds hundreds of trajectory samples).
	while route_cache.size() > 16:
		route_cache.erase(route_cache.keys()[0])


func register(command_type: String, handler: Callable) -> void:
	assert(not _handlers.has(command_type), "Duplicate command handler: " + command_type)
	_handlers[command_type] = handler


## Returns "" on success, otherwise a reason the command was rejected.
func apply(command: Dictionary) -> String:
	var type: String = command.get("type", "")
	var error: String = _handlers[type].call(command) if _handlers.has(type) else "unknown command: " + type
	if error == "":
		state.command_count += 1
	else:
		emit("rejected", {"command": type, "reason": error})
	return error


## Advance by real seconds at the current time compression. Time compression is
## re-read after every chunk (arrival drops it to x1), and a chunk never runs past
## the player's arrival, so the clock does not race on after reaching port.
func tick(real_dt: float) -> void:
	var real_left := real_dt
	var step := float(data.balance["economy"]["step_hours"]) * 3600.0
	while real_left > 1e-9 and not state.paused:
		var scale := state.time_scale
		var game := minf(real_left * scale, step)
		if state.location.get("status") == "transit":
			var to_arrival := float(state.location["arrive_t"]) - state.time_s
			if to_arrival > 1e-6:
				game = minf(game, to_arrival)
		advance_game_time(game)
		real_left -= game / scale


## Advance game time by exactly `game_seconds` (bots and tests use this directly).
func advance_game_time(game_seconds: float) -> void:
	if state.paused or game_seconds <= 0.0:
		return
	# Long advances are cut into economy-step-sized chunks, and every system ticks
	# each chunk in turn. Otherwise one system would run days ahead of the others
	# (markets settling before projects or NPCs act), and the outcome would depend
	# on tick size: a bot jumping days at a time must see the same world as play at x1.
	var chunk := float(data.balance["economy"]["step_hours"]) * 3600.0
	var remaining := game_seconds
	while remaining > 0.0:
		var dt := minf(remaining, chunk)
		remaining -= dt
		for system in systems:
			system.tick(dt)


## at_time: when it happened, if not now (systems that process scheduled events in a long tick).
func emit(event_type: String, payload: Dictionary = {}, at_time: float = NAN) -> void:
	_events.append({"type": event_type, "time_s": state.time_s if is_nan(at_time) else at_time, "data": payload})
	if _events.size() > MAX_PENDING_EVENTS:
		_events = _events.slice(_events.size() - MAX_PENDING_EVENTS)


## The view drains events once per frame.
func take_events() -> Array[Dictionary]:
	var out := _events
	_events = []
	return out
