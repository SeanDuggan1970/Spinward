## Simulation core. Owns the state, the loaded data and the systems.
##
## Everything that changes the game goes through apply(command): a plain Dictionary
## with a "type" key, so commands can be logged, replayed, sent by bots or, later,
## sent over the network. Systems register handlers for the types they own.
## Systems never call each other; they share state and emit events for the view.
extends RefCounted

const GameState := preload("res://sim/game_state.gd")
const DataCatalog := preload("res://sim/data_catalog.gd")
const CalendarSystem := preload("res://sim/systems/calendar_system.gd")

var state: GameState
var data: DataCatalog
var systems: Array = []
var _handlers: Dictionary = {}
var _events: Array[Dictionary] = []


func _init(catalog: DataCatalog = null) -> void:
	data = catalog if catalog else DataCatalog.load_default()
	state = GameState.new()
	systems = [CalendarSystem.new()]
	for system in systems:
		system.setup(self)


func new_game(seed_value: int) -> void:
	state = GameState.new()
	state.seed = seed_value
	var start: Dictionary = data.balance["start"]
	state.time_s = GameState.from_unix(Time.get_unix_time_from_datetime_string(start["date_utc"]))
	state.credits = float(start["credits"])
	emit("new_game", {"seed": seed_value})


func register(command_type: String, handler: Callable) -> void:
	assert(not _handlers.has(command_type), "Duplicate command handler: " + command_type)
	_handlers[command_type] = handler


## Returns "" on success, otherwise a reason the command was rejected.
func apply(command: Dictionary) -> String:
	var type: String = command.get("type", "")
	if not _handlers.has(type):
		return "unknown command: " + type
	var error: String = _handlers[type].call(command)
	if error == "":
		state.command_count += 1
	return error


## Advance by real seconds; systems scale by time_scale themselves.
func tick(real_dt: float) -> void:
	if state.paused:
		return
	for system in systems:
		system.tick(real_dt)


func emit(event_type: String, payload: Dictionary = {}) -> void:
	_events.append({"type": event_type, "time_s": state.time_s, "data": payload})


## The view drains events once per frame.
func take_events() -> Array[Dictionary]:
	var out := _events
	_events = []
	return out
